extension WinFoundationDataTask {
    func httpDestination(for url: URL) throws -> HTTPDestination {
        guard var host = url.host, !host.isEmpty else {
            throw URLError(.badURL)
        }
        let secure = url.scheme?.lowercased() == "https"
        var port: UInt16 = secure ? 443 : 80
        if host.filter({ $0 == ":" }).count == 1,
           let separator = host.lastIndex(of: ":"),
           let explicitPort = UInt16(host[host.index(after: separator)...]) {
            port = explicitPort
            host = String(host[..<separator])
        }

        var objectName = url.percentEncodedPath
        if objectName.isEmpty { objectName = "/" }
        if let query = url.percentEncodedQuery, !query.isEmpty {
            objectName += "?" + query
        }
        return HTTPDestination(host: host, port: port, objectName: objectName, secure: secure)
    }

    func openHTTPSession() throws -> UnsafeMutableRawPointer {
        let agent = Array("WinFoundation/1.0".utf16) + [0]
        let session = agent.withUnsafeBufferPointer {
            WinFoundationWinHttpOpen($0.baseAddress, 0, nil, nil, 0)
        }
        guard let session else { throw transportError() }
        let timeout = Int32(max(1, min(
            request.timeoutInterval * 1_000,
            Double(Int32.max)
        )))
        _ = WinFoundationWinHttpSetTimeouts(
            session,
            timeout,
            timeout,
            timeout,
            timeout
        )
        return session
    }

    func openHTTPConnection(
        session: UnsafeMutableRawPointer,
        destination: HTTPDestination
    ) throws -> UnsafeMutableRawPointer {
        let wideHost = Array(destination.host.utf16) + [0]
        let connection = wideHost.withUnsafeBufferPointer {
            WinFoundationWinHttpConnect(session, $0.baseAddress, destination.port, 0)
        }
        guard let connection else { throw transportError() }
        return connection
    }

    func openHTTPRequest(
        connection: UnsafeMutableRawPointer,
        destination: HTTPDestination
    ) throws -> UnsafeMutableRawPointer {
        let method = Array((request.httpMethod ?? "GET").utf16) + [0]
        let wideObjectName = Array(destination.objectName.utf16) + [0]
        let requestHandle = method.withUnsafeBufferPointer { methodBuffer in
            wideObjectName.withUnsafeBufferPointer { objectBuffer in
                WFWinHttpOpenRequest(
                    connection,
                    methodBuffer.baseAddress,
                    objectBuffer.baseAddress,
                    nil,
                    nil,
                    nil,
                    destination.secure ? 0x0080_0000 : 0
                )
            }
        }
        guard let requestHandle else { throw transportError() }
        return requestHandle
    }

    func addRequestHeaders(to requestHandle: UnsafeMutableRawPointer) throws {
        if let fields = request.allHTTPHeaderFields, !fields.isEmpty {
            let headerText = fields.map { "\($0.key): \($0.value)\r\n" }
                .joined()
            let headers = Array(headerText.utf16) + [0]
            let added = headers.withUnsafeBufferPointer {
                WinFoundationWinHttpAddRequestHeaders(
                    requestHandle,
                    $0.baseAddress,
                    UInt32.max,
                    0x2000_0000
                )
            }
            guard added != 0 else { throw transportError() }
        }
    }

    func sendRequest(to requestHandle: UnsafeMutableRawPointer) throws {
        var body = request.httpBody?.array ?? []
        let sent = body.withUnsafeMutableBytes { buffer in
            WFWinHttpSendRequest(
                requestHandle,
                nil,
                0,
                buffer.baseAddress,
                UInt32(buffer.count),
                UInt32(buffer.count),
                0
            )
        }
        guard sent != 0 else { throw transportError() }
        guard WinFoundationWinHttpReceiveResponse(requestHandle, nil) != 0 else {
            throw transportError()
        }
    }

    func responseStatusCode(from requestHandle: UnsafeMutableRawPointer) throws -> Int {
        var statusCode: UInt32 = 0
        var statusLength = UInt32(MemoryLayout<UInt32>.size)
        let queriedStatus = withUnsafeMutablePointer(to: &statusCode) {
            statusPointer in
            WFWinHttpQueryHeaders(
                requestHandle,
                19 | 0x2000_0000,
                nil,
                UnsafeMutableRawPointer(statusPointer),
                &statusLength,
                nil
            )
        }
        guard queriedStatus != 0 else { throw transportError() }
        return Int(statusCode)
    }

    func readResponseBody(from requestHandle: UnsafeMutableRawPointer) throws -> [UInt8] {
        var bytes: [UInt8] = []
        while true {
            var available: UInt32 = 0
            guard WinFoundationWinHttpQueryDataAvailable(
                requestHandle,
                &available
            ) != 0 else {
                throw transportError()
            }
            if available == 0 { break }
            var chunk = [UInt8](repeating: 0, count: Int(available))
            var read: UInt32 = 0
            let didRead = chunk.withUnsafeMutableBytes { buffer in
                WinFoundationWinHttpReadData(
                    requestHandle,
                    buffer.baseAddress,
                    available,
                    &read
                )
            }
            guard didRead != 0 else { throw transportError() }
            if read == 0 { break }
            bytes.append(contentsOf: chunk.prefix(Int(read)))
        }
        return bytes
    }

    func queryResponseHeaders(
        _ requestHandle: UnsafeMutableRawPointer
    ) -> [String: String] {
        var byteCount: UInt32 = 0
        _ = WFWinHttpQueryHeaders(
            requestHandle,
            22,
            nil,
            nil,
            &byteCount,
            nil
        )
        guard byteCount >= 2 else { return [:] }
        var buffer = [UInt16](
            repeating: 0,
            count: Int((byteCount + 1) / 2)
        )
        let queried = buffer.withUnsafeMutableBytes { rawBuffer in
                WFWinHttpQueryHeaders(
                requestHandle,
                22,
                nil,
                rawBuffer.baseAddress,
                &byteCount,
                nil
            )
        }
        guard queried != 0 else { return [:] }
        let terminator = buffer.firstIndex(of: 0) ?? buffer.endIndex
        let lines = buffer[..<terminator].split {
            $0 == 10 || $0 == 13
        }
        var fields: [String: String] = [:]
        for rawLine in lines.dropFirst() {
            let line = String(decoding: rawLine, as: UTF16.self)
            guard let separator = line.firstIndex(of: ":") else { continue }
            let name = String(line[..<separator])
            let value = String(line[line.index(after: separator)...])
                .drop { $0.isWhitespace }
            if let existing = fields[name] {
                fields[name] = existing + ", " + value
            } else {
                fields[name] = String(value)
            }
        }
        return fields
    }

    func transportError() -> URLError {
        if withState({ $0.phase == 2 }) { return URLError(.cancelled) }
        switch WinFoundationGetLastError() {
        case 12002:
            return URLError(.timedOut)
        case 12007:
            return URLError(.cannotFindHost)
        case 12017:
            return URLError(.cancelled)
        case 12029:
            return URLError(.cannotConnectToHost)
        case 12030:
            return URLError(.networkConnectionLost)
        case 12175:
            return URLError(.secureConnectionFailed)
        default:
            return URLError(.unknown)
        }
    }
}
