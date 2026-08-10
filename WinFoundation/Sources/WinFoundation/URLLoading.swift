/// Describes the public `URLRequest` struct.
public struct URLRequest: Equatable, Hashable, Sendable {
    /// Describes the public `CachePolicy` enum.
    public enum CachePolicy: UInt, Sendable {
        case useProtocolCachePolicy = 0
        case reloadIgnoringLocalCacheData = 1
        case reloadIgnoringLocalAndRemoteCacheData = 4
        case returnCacheDataElseLoad = 2
        case returnCacheDataDontLoad = 3
        case reloadRevalidatingCacheData = 5
    }

    /// The `url` value.
    public var url: URL?
    /// The `cachePolicy` value.
    public var cachePolicy: CachePolicy
    /// The `timeoutInterval` value.
    public var timeoutInterval: TimeInterval
    /// The `httpMethod` value.
    public var httpMethod: String?
    /// The `httpBody` value.
    public var httpBody: Data?
    /// The `allHTTPHeaderFields` value.
    public var allHTTPHeaderFields: [String: String]?
    /// The `mainDocumentURL` value.
    public var mainDocumentURL: URL?
    /// The `httpShouldHandleCookies` value.
    public var httpShouldHandleCookies = true
    /// The `httpShouldUsePipelining` value.
    public var httpShouldUsePipelining = false
    /// The `allowsCellularAccess` value.
    public var allowsCellularAccess = true
    /// The `allowsConstrainedNetworkAccess` value.
    public var allowsConstrainedNetworkAccess = true
    /// The `allowsExpensiveNetworkAccess` value.
    public var allowsExpensiveNetworkAccess = true

    /// Creates a value with the supplied arguments.
    public init(
        url: URL,
        cachePolicy: CachePolicy = .useProtocolCachePolicy,
        timeoutInterval: TimeInterval = 60.0
    ) {
        self.url = url
        self.cachePolicy = cachePolicy
        self.timeoutInterval = timeoutInterval
    }

    /// This declaration is part of the public API.
    public mutating func setValue(
        _ value: String?,
        forHTTPHeaderField field: String
    ) {
        let matchingKey = allHTTPHeaderFields?.keys.first {
            $0.lowercased() == field.lowercased()
        }
        if let matchingKey {
            allHTTPHeaderFields?.removeValue(forKey: matchingKey)
        }
        if let value {
            if allHTTPHeaderFields == nil { allHTTPHeaderFields = [:] }
            allHTTPHeaderFields?[field] = value
        }
    }

    /// This declaration is part of the public API.
    public mutating func addValue(
        _ value: String,
        forHTTPHeaderField field: String
    ) {
        if let existing = self.value(forHTTPHeaderField: field) {
            setValue(existing + "," + value, forHTTPHeaderField: field)
        } else {
            setValue(value, forHTTPHeaderField: field)
        }
    }

    /// Performs the `value` operation.
    public func value(forHTTPHeaderField field: String) -> String? {
        allHTTPHeaderFields?.first {
            $0.key.lowercased() == field.lowercased()
        }?.value
    }
}

/// Describes the public `URLResponse` class.
open class URLResponse: @unchecked Sendable {
    /// The `url` value.
    public let url: URL?
    /// The `mimeType` value.
    public let mimeType: String?
    /// The `expectedContentLength` value.
    public let expectedContentLength: Int64
    /// The `textEncodingName` value.
    public let textEncodingName: String?

    /// Creates a value with the supplied arguments.
    public init(
        url: URL,
        mimeType: String?,
        expectedContentLength: Int,
        textEncodingName: String?
    ) {
        self.url = url
        self.mimeType = mimeType
        self.expectedContentLength = Int64(expectedContentLength)
        self.textEncodingName = textEncodingName
    }

    /// The `suggestedFilename` value.
    public var suggestedFilename: String? {
        guard let component = url?.lastPathComponent, !component.isEmpty else {
            return nil
        }
        return component
    }
}

/// Describes the public `HTTPURLResponse` class.
open class HTTPURLResponse: URLResponse, @unchecked Sendable {
    /// The `statusCode` value.
    public let statusCode: Int
    /// The `allHeaderFields` value.
    public let allHeaderFields: [AnyHashable: Any]

    /// Creates a value with the supplied arguments.
    public init?(
        url: URL,
        statusCode: Int,
        httpVersion: String?,
        headerFields: [String: String]?
    ) {
        guard (100...999).contains(statusCode) else { return nil }
        self.statusCode = statusCode
        self.allHeaderFields = Dictionary(uniqueKeysWithValues:
            (headerFields ?? [:]).map { (AnyHashable($0.key), $0.value as Any) }
        )
        let contentType = headerFields?.first {
            $0.key.lowercased() == "content-type"
        }?.value
        var mimeType: String?
        var encoding: String?
        if let contentType {
            let fields = contentType.split(separator: ";")
            if let first = fields.first {
                mimeType = String(first).filter { !$0.isWhitespace }
            }
            for field in fields.dropFirst() {
                let text = String(field).filter { !$0.isWhitespace }
                if text.lowercased().hasPrefix("charset=") {
                    encoding = String(text.dropFirst("charset=".count))
                    break
                }
            }
        }
        let length = headerFields?.first {
            $0.key.lowercased() == "content-length"
        }.flatMap { Int($0.value) } ?? -1
        super.init(
            url: url,
            mimeType: mimeType,
            expectedContentLength: length,
            textEncodingName: encoding
        )
    }

    /// Performs the `value` operation.
    public func value(forHTTPHeaderField field: String) -> String? {
        allHeaderFields.first {
            String(describing: $0.key).lowercased() == field.lowercased()
        }?.value as? String
    }
}

/// Describes the public `URLError` struct.
public struct URLError: Error, Equatable, Hashable, Sendable {
    /// Describes the public `Code` enum.
    public enum Code: Int, Sendable {
        case unknown = -1
        case cancelled = -999
        case badURL = -1000
        case timedOut = -1001
        case unsupportedURL = -1002
        case cannotFindHost = -1003
        case cannotConnectToHost = -1004
        case networkConnectionLost = -1005
        case badServerResponse = -1011
        case secureConnectionFailed = -1200
    }

    /// The `code` value.
    public let code: Code

    /// Creates a value with the supplied arguments.
    public init(_ code: Code) {
        self.code = code
    }
}

/// Describes the public `URLSessionTask` class.
open class URLSessionTask: @unchecked Sendable {
    /// Creates a value with the supplied arguments.
    public init() {}

    /// Performs the `resume` operation.
    open func resume() {}
    /// Performs the `cancel` operation.
    open func cancel() {}
}

/// Describes the public `URLSessionDataTask` class.
open class URLSessionDataTask: URLSessionTask, @unchecked Sendable {
    public override init() {
        super.init()
    }
}

/// Describes the public `URLSession` class.
open class URLSession: @unchecked Sendable {
    /// The `` type-level value.
    public static let shared = URLSession()

    /// Creates a value with the supplied arguments.
    public init() {}

    /// Performs the `dataTask` operation.
    open func dataTask(
        with request: URLRequest,
        completionHandler: @escaping @Sendable (
            Data?,
            URLResponse?,
            (any Error)?
        ) -> Void
    ) -> URLSessionDataTask {
        WinFoundationDataTask(
            request: request,
            completionHandler: completionHandler
        )
    }

    /// Performs the `dataTask` operation.
    open func dataTask(
        with url: URL,
        completionHandler: @escaping @Sendable (
            Data?,
            URLResponse?,
            (any Error)?
        ) -> Void
    ) -> URLSessionDataTask {
        dataTask(with: URLRequest(url: url), completionHandler: completionHandler)
    }
}

private final class WinFoundationDataTask: URLSessionDataTask,
    @unchecked Sendable {
    private struct TaskState {
        var phase: Int32 = 0
        var activeRequest: UnsafeMutableRawPointer?
    }

    private let request: URLRequest
    private let completionHandler: @Sendable (
        Data?,
        URLResponse?,
        (any Error)?
    ) -> Void
    private let mutex: UnsafeMutableRawPointer?
    private var taskState = TaskState()

    init(
        request: URLRequest,
        completionHandler: @escaping @Sendable (
            Data?,
            URLResponse?,
            (any Error)?
        ) -> Void
    ) {
        self.request = request
        self.completionHandler = completionHandler
        mutex = WinFoundationCreateMutex(nil, 0, nil)
    }

    override func resume() {
        let shouldStart = withState { state -> Bool in
            guard state.phase == 0 else { return false }
            state.phase = 1
            return true
        }
        guard shouldStart else {
            return
        }
        OperationQueue().addOperation { [self] in
            guard withState({ $0.phase == 1 }) else {
                finish(data: nil, response: nil, error: URLError(.cancelled))
                return
            }
            guard let url = request.url else {
                finish(data: nil, response: nil, error: URLError(.badURL))
                return
            }
            if url.isFileURL {
                do {
                    let data = try Data(contentsOf: url)
                    let response = URLResponse(
                        url: url,
                        mimeType: nil,
                        expectedContentLength: data.count,
                        textEncodingName: nil
                    )
                    finish(data: data, response: response, error: nil)
                } catch {
                    finish(data: nil, response: nil, error: URLError(.badURL))
                }
                return
            }

            guard url.scheme?.lowercased() == "http" ||
                  url.scheme?.lowercased() == "https" else {
                finish(data: nil, response: nil, error: URLError(.unsupportedURL))
                return
            }
            do {
                let output = try performHTTPRequest(to: url)
                finish(data: output.data, response: output.response, error: nil)
            } catch let error as URLError {
                finish(data: nil, response: nil, error: error)
            } catch {
                finish(data: nil, response: nil, error: URLError(.unknown))
            }
        }
    }

    override func cancel() {
        let action = withState {
            state -> (Int32, UnsafeMutableRawPointer?) in
            let previous = state.phase
            if state.phase != 3 { state.phase = 2 }
            let request = state.activeRequest
            state.activeRequest = nil
            return (previous, request)
        }
        if let request = action.1 {
            _ = WinFoundationWinHttpCloseHandle(request)
        }
        if action.0 == 0 {
            finish(data: nil, response: nil, error: URLError(.cancelled))
        }
    }

    private func finish(
        data: Data?,
        response: URLResponse?,
        error: (any Error)?
    ) {
        let previous = withState { state -> Int32 in
            let previous = state.phase
            state.phase = 3
            return previous
        }
        guard previous != 3 else { return }
        if previous == 2 {
            completionHandler(nil, nil, URLError(.cancelled))
        } else {
            completionHandler(data, response, error)
        }
    }

    private func performHTTPRequest(
        to url: URL
    ) throws -> (data: Data, response: URLResponse) {
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

        let agent = Array("WinFoundation/1.0".utf16) + [0]
        let session = agent.withUnsafeBufferPointer {
            WinFoundationWinHttpOpen($0.baseAddress, 0, nil, nil, 0)
        }
        guard let session else { throw transportError() }
        defer { _ = WinFoundationWinHttpCloseHandle(session) }

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

        let wideHost = Array(host.utf16) + [0]
        let connection = wideHost.withUnsafeBufferPointer {
            WinFoundationWinHttpConnect(session, $0.baseAddress, port, 0)
        }
        guard let connection else { throw transportError() }
        defer { _ = WinFoundationWinHttpCloseHandle(connection) }

        let method = Array((request.httpMethod ?? "GET").utf16) + [0]
        let wideObjectName = Array(objectName.utf16) + [0]
        let requestHandle = method.withUnsafeBufferPointer { methodBuffer in
            wideObjectName.withUnsafeBufferPointer { objectBuffer in
                WinFoundationWinHttpOpenRequest(
                    connection,
                    methodBuffer.baseAddress,
                    objectBuffer.baseAddress,
                    nil,
                    nil,
                    nil,
                    secure ? 0x0080_0000 : 0
                )
            }
        }
        guard let requestHandle else { throw transportError() }

        let accepted = withState { state -> Bool in
            guard state.phase == 1 else { return false }
            state.activeRequest = requestHandle
            return true
        }
        guard accepted else {
            _ = WinFoundationWinHttpCloseHandle(requestHandle)
            throw URLError(.cancelled)
        }
        defer {
            let shouldClose = withState { state -> Bool in
                guard state.activeRequest == requestHandle else { return false }
                state.activeRequest = nil
                return true
            }
            if shouldClose {
                _ = WinFoundationWinHttpCloseHandle(requestHandle)
            }
        }

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

        var body = request.httpBody?.array ?? []
        let sent = body.withUnsafeMutableBytes { buffer in
            WinFoundationWinHttpSendRequest(
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

        var statusCode: UInt32 = 0
        var statusLength = UInt32(MemoryLayout<UInt32>.size)
        let queriedStatus = withUnsafeMutablePointer(to: &statusCode) {
            statusPointer in
            WinFoundationWinHttpQueryHeaders(
                requestHandle,
                19 | 0x2000_0000,
                nil,
                UnsafeMutableRawPointer(statusPointer),
                &statusLength,
                nil
            )
        }
        guard queriedStatus != 0 else { throw transportError() }

        let headers = queryResponseHeaders(requestHandle)
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

        guard let response = HTTPURLResponse(
            url: url,
            statusCode: Int(statusCode),
            httpVersion: "HTTP/1.1",
            headerFields: headers
        ) else {
            throw URLError(.badServerResponse)
        }
        return (Data(bytes), response)
    }

    private func queryResponseHeaders(
        _ requestHandle: UnsafeMutableRawPointer
    ) -> [String: String] {
        var byteCount: UInt32 = 0
        _ = WinFoundationWinHttpQueryHeaders(
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
            WinFoundationWinHttpQueryHeaders(
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

    private func transportError() -> URLError {
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

    private func withState<Result>(
        _ body: (inout TaskState) -> Result
    ) -> Result {
        _ = WinFoundationWaitForSingleObject(mutex, UInt32.max)
        defer { _ = WinFoundationReleaseMutex(mutex) }
        return body(&taskState)
    }

    deinit {
        _ = WinFoundationCloseNetworkingHandle(mutex)
    }
}

@_silgen_name("CreateMutexW")
private func WinFoundationCreateMutex(
    _ attributes: UnsafeMutableRawPointer?,
    _ initialOwner: Int32,
    _ name: UnsafePointer<UInt16>?
) -> UnsafeMutableRawPointer?

@_silgen_name("WaitForSingleObject")
private func WinFoundationWaitForSingleObject(
    _ object: UnsafeMutableRawPointer?,
    _ milliseconds: UInt32
) -> UInt32

@_silgen_name("ReleaseMutex")
private func WinFoundationReleaseMutex(
    _ mutex: UnsafeMutableRawPointer?
) -> Int32

@_silgen_name("CloseHandle")
private func WinFoundationCloseNetworkingHandle(
    _ object: UnsafeMutableRawPointer?
) -> Int32

@_silgen_name("WinHttpOpen")
private func WinFoundationWinHttpOpen(
    _ userAgent: UnsafePointer<UInt16>?,
    _ accessType: UInt32,
    _ proxyName: UnsafePointer<UInt16>?,
    _ proxyBypass: UnsafePointer<UInt16>?,
    _ flags: UInt32
) -> UnsafeMutableRawPointer?

@_silgen_name("WinHttpSetTimeouts")
private func WinFoundationWinHttpSetTimeouts(
    _ session: UnsafeMutableRawPointer?,
    _ resolveTimeout: Int32,
    _ connectTimeout: Int32,
    _ sendTimeout: Int32,
    _ receiveTimeout: Int32
) -> Int32

@_silgen_name("WinHttpConnect")
private func WinFoundationWinHttpConnect(
    _ session: UnsafeMutableRawPointer?,
    _ serverName: UnsafePointer<UInt16>?,
    _ serverPort: UInt16,
    _ reserved: UInt32
) -> UnsafeMutableRawPointer?

@_silgen_name("WinHttpOpenRequest")
private func WinFoundationWinHttpOpenRequest(
    _ connection: UnsafeMutableRawPointer?,
    _ verb: UnsafePointer<UInt16>?,
    _ objectName: UnsafePointer<UInt16>?,
    _ version: UnsafePointer<UInt16>?,
    _ referrer: UnsafePointer<UInt16>?,
    _ acceptTypes: UnsafePointer<UnsafePointer<UInt16>?>?,
    _ flags: UInt32
) -> UnsafeMutableRawPointer?

@_silgen_name("WinHttpAddRequestHeaders")
private func WinFoundationWinHttpAddRequestHeaders(
    _ request: UnsafeMutableRawPointer?,
    _ headers: UnsafePointer<UInt16>?,
    _ headersLength: UInt32,
    _ modifiers: UInt32
) -> Int32

@_silgen_name("WinHttpSendRequest")
private func WinFoundationWinHttpSendRequest(
    _ request: UnsafeMutableRawPointer?,
    _ headers: UnsafePointer<UInt16>?,
    _ headersLength: UInt32,
    _ optionalData: UnsafeMutableRawPointer?,
    _ optionalLength: UInt32,
    _ totalLength: UInt32,
    _ context: UInt
) -> Int32

@_silgen_name("WinHttpReceiveResponse")
private func WinFoundationWinHttpReceiveResponse(
    _ request: UnsafeMutableRawPointer?,
    _ reserved: UnsafeMutableRawPointer?
) -> Int32

@_silgen_name("WinHttpQueryHeaders")
private func WinFoundationWinHttpQueryHeaders(
    _ request: UnsafeMutableRawPointer?,
    _ infoLevel: UInt32,
    _ name: UnsafePointer<UInt16>?,
    _ buffer: UnsafeMutableRawPointer?,
    _ bufferLength: UnsafeMutablePointer<UInt32>?,
    _ index: UnsafeMutablePointer<UInt32>?
) -> Int32

@_silgen_name("WinHttpQueryDataAvailable")
private func WinFoundationWinHttpQueryDataAvailable(
    _ request: UnsafeMutableRawPointer?,
    _ available: UnsafeMutablePointer<UInt32>?
) -> Int32

@_silgen_name("WinHttpReadData")
private func WinFoundationWinHttpReadData(
    _ request: UnsafeMutableRawPointer?,
    _ buffer: UnsafeMutableRawPointer?,
    _ bytesToRead: UInt32,
    _ bytesRead: UnsafeMutablePointer<UInt32>?
) -> Int32

@_silgen_name("WinHttpCloseHandle")
private func WinFoundationWinHttpCloseHandle(
    _ handle: UnsafeMutableRawPointer?
) -> Int32

@_silgen_name("GetLastError")
private func WinFoundationGetLastError() -> UInt32
