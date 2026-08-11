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
    /// Creates a data task in its initial suspended state.
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

final class WinFoundationDataTask: URLSessionDataTask,
    @unchecked Sendable {
    internal struct TaskState {
        var phase: Int32 = 0
        var activeRequest: UnsafeMutableRawPointer?
    }

    internal let request: URLRequest
    internal let completionHandler: @Sendable (
        Data?,
        URLResponse?,
        (any Error)?
    ) -> Void
    internal let mutex: UnsafeMutableRawPointer?
    internal var taskState = TaskState()

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

    internal func finish(
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

    internal func performHTTPRequest(
        to url: URL
    ) throws -> (data: Data, response: URLResponse) {
        let destination = try httpDestination(for: url)
        let session = try openHTTPSession()
        defer { _ = WinFoundationWinHttpCloseHandle(session) }

        let connection = try openHTTPConnection(session: session, destination: destination)
        defer { _ = WinFoundationWinHttpCloseHandle(connection) }

        let requestHandle = try openHTTPRequest(connection: connection, destination: destination)
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

        try addRequestHeaders(to: requestHandle)
        try sendRequest(to: requestHandle)
        let statusCode = try responseStatusCode(from: requestHandle)
        let headers = queryResponseHeaders(requestHandle)
        let bytes = try readResponseBody(from: requestHandle)

        guard let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        ) else {
            throw URLError(.badServerResponse)
        }
        return (Data(bytes), response)
    }

    internal struct HTTPDestination {
        let host: String
        let port: UInt16
        let objectName: String
        let secure: Bool
    }

    internal func withState<Result>(
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
internal func WinFoundationCreateMutex(
    _ attributes: UnsafeMutableRawPointer?,
    _ initialOwner: Int32,
    _ name: UnsafePointer<UInt16>?
) -> UnsafeMutableRawPointer?

@_silgen_name("WaitForSingleObject")
internal func WinFoundationWaitForSingleObject(
    _ object: UnsafeMutableRawPointer?,
    _ milliseconds: UInt32
) -> UInt32

@_silgen_name("ReleaseMutex")
internal func WinFoundationReleaseMutex(
    _ mutex: UnsafeMutableRawPointer?
) -> Int32

@_silgen_name("CloseHandle")
internal func WinFoundationCloseNetworkingHandle(
    _ object: UnsafeMutableRawPointer?
) -> Int32

@_silgen_name("WinHttpOpen")
internal func WinFoundationWinHttpOpen(
    _ userAgent: UnsafePointer<UInt16>?,
    _ accessType: UInt32,
    _ proxyName: UnsafePointer<UInt16>?,
    _ proxyBypass: UnsafePointer<UInt16>?,
    _ flags: UInt32
) -> UnsafeMutableRawPointer?

@_silgen_name("WinHttpSetTimeouts")
internal func WinFoundationWinHttpSetTimeouts(
    _ session: UnsafeMutableRawPointer?,
    _ resolveTimeout: Int32,
    _ connectTimeout: Int32,
    _ sendTimeout: Int32,
    _ receiveTimeout: Int32
) -> Int32

@_silgen_name("WinHttpConnect")
internal func WinFoundationWinHttpConnect(
    _ session: UnsafeMutableRawPointer?,
    _ serverName: UnsafePointer<UInt16>?,
    _ serverPort: UInt16,
    _ reserved: UInt32
) -> UnsafeMutableRawPointer?

@_silgen_name("WinHttpAddRequestHeaders")
internal func WinFoundationWinHttpAddRequestHeaders(
    _ request: UnsafeMutableRawPointer?,
    _ headers: UnsafePointer<UInt16>?,
    _ headersLength: UInt32,
    _ modifiers: UInt32
) -> Int32

@_silgen_name("WinHttpReceiveResponse")
internal func WinFoundationWinHttpReceiveResponse(
    _ request: UnsafeMutableRawPointer?,
    _ reserved: UnsafeMutableRawPointer?
) -> Int32

@_silgen_name("WinHttpQueryDataAvailable")
internal func WinFoundationWinHttpQueryDataAvailable(
    _ request: UnsafeMutableRawPointer?,
    _ available: UnsafeMutablePointer<UInt32>?
) -> Int32

@_silgen_name("WinHttpReadData")
internal func WinFoundationWinHttpReadData(
    _ request: UnsafeMutableRawPointer?,
    _ buffer: UnsafeMutableRawPointer?,
    _ bytesToRead: UInt32,
    _ bytesRead: UnsafeMutablePointer<UInt32>?
) -> Int32

@_silgen_name("WinHttpCloseHandle")
internal func WinFoundationWinHttpCloseHandle(
    _ handle: UnsafeMutableRawPointer?
) -> Int32

@_silgen_name("GetLastError")
internal func WinFoundationGetLastError() -> UInt32
import CWinFoundationCompat
