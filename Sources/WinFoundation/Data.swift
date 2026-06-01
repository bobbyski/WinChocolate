/// A small Foundation-compatible byte buffer subset.
public struct Data: Equatable, Hashable, Sendable, RandomAccessCollection, MutableCollection, RangeReplaceableCollection {
    public typealias Element = UInt8
    public typealias Index = Int
    public typealias SubSequence = ArraySlice<UInt8>

    private var bytes: [UInt8]

    /// Creates empty data.
    public init() {
        self.bytes = []
    }

    /// Creates data with repeated bytes.
    public init(repeating repeatedValue: UInt8, count: Int) {
        self.bytes = Array(repeating: repeatedValue, count: count)
    }

    /// Creates data from a byte sequence.
    public init<S>(_ elements: S) where S: Sequence, S.Element == UInt8 {
        self.bytes = Array(elements)
    }

    /// Creates data from a byte collection.
    public init<C>(_ elements: C) where C: Collection, C.Element == UInt8 {
        self.bytes = Array(elements)
    }

    /// Creates data from any sequence of bytes.
    public init<S>(bytes elements: S) where S: Sequence, S.Element == UInt8 {
        self.bytes = Array(elements)
    }

    /// Creates data from a contiguous byte buffer.
    public init(buffer: UnsafeBufferPointer<UInt8>) {
        self.bytes = Array(buffer)
    }

    /// Creates data from raw bytes.
    public init(bytes: UnsafeRawPointer, count: Int) {
        let buffer = UnsafeRawBufferPointer(start: bytes, count: count)
        self.bytes = Array(buffer)
    }

    /// Creates data from a raw buffer.
    public init(_ buffer: UnsafeRawBufferPointer) {
        self.bytes = Array(buffer)
    }

    /// Loads data from a file URL.
    public init(contentsOf url: URL) throws {
        guard url.isFileURL else {
            throw DataFileError.nonFileURL
        }
        self.bytes = try Data.readFile(at: url.path)
    }

    /// The first valid index.
    public var startIndex: Int {
        bytes.startIndex
    }

    /// One past the final valid index.
    public var endIndex: Int {
        bytes.endIndex
    }

    /// Number of bytes.
    public var count: Int {
        bytes.count
    }

    /// Whether the buffer is empty.
    public var isEmpty: Bool {
        bytes.isEmpty
    }

    /// Returns the bytes as an array.
    public var array: [UInt8] {
        bytes
    }

    /// Accesses one byte by index.
    public subscript(position: Int) -> UInt8 {
        get {
            bytes[position]
        }
        set {
            bytes[position] = newValue
        }
    }

    /// Accesses a byte range.
    public subscript(bounds: Range<Int>) -> ArraySlice<UInt8> {
        get {
            bytes[bounds]
        }
        set {
            bytes.replaceSubrange(bounds, with: newValue)
        }
    }

    /// Appends one byte.
    public mutating func append(_ other: UInt8) {
        bytes.append(other)
    }

    /// Appends another data value.
    public mutating func append(_ other: Data) {
        bytes.append(contentsOf: other.bytes)
    }

    /// Appends a byte sequence.
    public mutating func append<S>(contentsOf elements: S) where S: Sequence, S.Element == UInt8 {
        bytes.append(contentsOf: elements)
    }

    /// Appends a byte collection.
    public mutating func append<C>(contentsOf elements: C) where C: Collection, C.Element == UInt8 {
        bytes.append(contentsOf: elements)
    }

    /// Removes all bytes.
    public mutating func removeAll(keepingCapacity keepCapacity: Bool = false) {
        bytes.removeAll(keepingCapacity: keepCapacity)
    }

    /// Writes data to a file URL.
    public func write(to url: URL) throws {
        guard url.isFileURL else {
            throw DataFileError.nonFileURL
        }
        try Data.writeFile(bytes, to: url.path)
    }

    /// Reserves storage capacity.
    public mutating func reserveCapacity(_ minimumCapacity: Int) {
        bytes.reserveCapacity(minimumCapacity)
    }

    /// Replaces a byte range.
    public mutating func replaceSubrange<C>(_ subrange: Range<Int>, with newElements: C) where C: Collection, C.Element == UInt8 {
        bytes.replaceSubrange(subrange, with: newElements)
    }

    /// Returns a copy of a byte range.
    public func subdata(in range: Range<Int>) -> Data {
        Data(bytes[range])
    }

    /// Calls a closure with an unsafe raw byte buffer.
    public func withUnsafeBytes<ResultType>(_ body: (UnsafeRawBufferPointer) throws -> ResultType) rethrows -> ResultType {
        try bytes.withUnsafeBytes(body)
    }

    /// Calls a closure with a mutable unsafe raw byte buffer.
    public mutating func withUnsafeMutableBytes<ResultType>(_ body: (UnsafeMutableRawBufferPointer) throws -> ResultType) rethrows -> ResultType {
        try bytes.withUnsafeMutableBytes(body)
    }

    private static func readFile(at path: String) throws -> [UInt8] {
        #if os(Windows)
        let handle = openFile(path: path, access: genericRead, shareMode: fileShareRead, creationDisposition: openExisting)
        guard isValidHandle(handle) else {
            throw DataFileError.openFailed(path)
        }
        defer {
            WinFoundationCloseHandle(handle)
        }

        var size: Int64 = 0
        guard WinFoundationGetFileSizeEx(handle, &size) != 0, size >= 0 else {
            throw DataFileError.sizeFailed(path)
        }

        var buffer = Array<UInt8>(repeating: 0, count: Int(size))
        guard !buffer.isEmpty else {
            return []
        }

        var bytesRead: UInt32 = 0
        let readSucceeded = buffer.withUnsafeMutableBufferPointer { pointer in
            WinFoundationReadFile(handle, pointer.baseAddress, UInt32(pointer.count), &bytesRead, nil)
        }
        guard readSucceeded != 0, Int(bytesRead) == buffer.count else {
            throw DataFileError.readFailed(path)
        }
        return buffer
        #else
        throw DataFileError.readFailed(path)
        #endif
    }

    private static func writeFile(_ bytes: [UInt8], to path: String) throws {
        #if os(Windows)
        let handle = openFile(path: path, access: genericWrite, shareMode: 0, creationDisposition: createAlways)
        guard isValidHandle(handle) else {
            throw DataFileError.openFailed(path)
        }
        defer {
            WinFoundationCloseHandle(handle)
        }

        var bytesWritten: UInt32 = 0
        let writeSucceeded = bytes.withUnsafeBufferPointer { pointer in
            WinFoundationWriteFile(handle, pointer.baseAddress, UInt32(pointer.count), &bytesWritten, nil)
        }
        guard writeSucceeded != 0, Int(bytesWritten) == bytes.count else {
            throw DataFileError.writeFailed(path)
        }
        #else
        throw DataFileError.writeFailed(path)
        #endif
    }

    #if os(Windows)
    private static let genericRead: UInt32 = 0x8000_0000
    private static let genericWrite: UInt32 = 0x4000_0000
    private static let fileShareRead: UInt32 = 0x0000_0001
    private static let createAlways: UInt32 = 2
    private static let openExisting: UInt32 = 3
    private static let fileAttributeNormal: UInt32 = 0x0000_0080

    private static func openFile(path: String, access: UInt32, shareMode: UInt32, creationDisposition: UInt32) -> UnsafeMutableRawPointer? {
        var widePath = Array(path.utf16)
        widePath.append(0)
        return widePath.withUnsafeBufferPointer { pointer in
            WinFoundationCreateFileW(
                pointer.baseAddress,
                access,
                shareMode,
                nil,
                creationDisposition,
                fileAttributeNormal,
                nil
            )
        }
    }

    private static func isValidHandle(_ handle: UnsafeMutableRawPointer?) -> Bool {
        guard let handle else {
            return false
        }
        return UInt(bitPattern: handle) != UInt.max
    }
    #endif
}

/// File I/O errors thrown by the WinFoundation `Data` shim.
public enum DataFileError: Error, Equatable {
    case nonFileURL
    case openFailed(String)
    case sizeFailed(String)
    case readFailed(String)
    case writeFailed(String)
}

#if os(Windows)
@_silgen_name("CreateFileW")
private func WinFoundationCreateFileW(
    _ fileName: UnsafePointer<UInt16>?,
    _ desiredAccess: UInt32,
    _ shareMode: UInt32,
    _ securityAttributes: UnsafeRawPointer?,
    _ creationDisposition: UInt32,
    _ flagsAndAttributes: UInt32,
    _ templateFile: UnsafeRawPointer?
) -> UnsafeMutableRawPointer?

@_silgen_name("GetFileSizeEx")
private func WinFoundationGetFileSizeEx(_ file: UnsafeMutableRawPointer?, _ fileSize: UnsafeMutablePointer<Int64>) -> Int32

@_silgen_name("ReadFile")
private func WinFoundationReadFile(
    _ file: UnsafeMutableRawPointer?,
    _ buffer: UnsafeMutableRawPointer?,
    _ numberOfBytesToRead: UInt32,
    _ numberOfBytesRead: UnsafeMutablePointer<UInt32>?,
    _ overlapped: UnsafeRawPointer?
) -> Int32

@_silgen_name("WriteFile")
private func WinFoundationWriteFile(
    _ file: UnsafeMutableRawPointer?,
    _ buffer: UnsafeRawPointer?,
    _ numberOfBytesToWrite: UInt32,
    _ numberOfBytesWritten: UnsafeMutablePointer<UInt32>?,
    _ overlapped: UnsafeRawPointer?
) -> Int32

@_silgen_name("CloseHandle")
@discardableResult
private func WinFoundationCloseHandle(_ object: UnsafeMutableRawPointer?) -> Int32
#endif
