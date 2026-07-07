/// A Foundation-compatible file system manager subset.
///
/// This slice covers what document applications reach for: existence checks,
/// directory listing and creation, remove/copy/move (recursive for
/// directories), the temporary directory, and known-folder lookup through
/// `urls(for:in:)`. Attributes dictionaries, enumerators, and delegates are
/// future work.
open class FileManager {
    /// Errors thrown by file operations.
    ///
    /// Foundation reports these through `NSError`; the shim uses a Swift
    /// error enum carrying the path involved.
    public enum FileError: Error, Equatable {
        /// The path does not exist.
        case fileNotFound(String)

        /// The destination already exists.
        case alreadyExists(String)

        /// The underlying system call failed.
        case operationFailed(String)
    }

    /// Known directory locations for `urls(for:in:)`.
    public enum SearchPathDirectory: Sendable {
        /// The user's Documents folder.
        case documentDirectory

        /// The user's Desktop folder.
        case desktopDirectory

        /// Per-user application support data (roaming AppData on Windows).
        case applicationSupportDirectory

        /// Per-user cache data (local AppData on Windows).
        case cachesDirectory

        /// The user's home profile folder.
        case userDirectory
    }

    /// Domain masks for `urls(for:in:)`; only the user domain is meaningful
    /// on Windows.
    public struct SearchPathDomainMask: OptionSet, Sendable {
        /// The raw option value.
        public let rawValue: UInt

        /// Creates a mask from a raw value.
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// The current user's domain.
        public static let userDomainMask = SearchPathDomainMask(rawValue: 1)

        /// Every domain; treated as the user domain on Windows.
        public static let allDomainsMask = SearchPathDomainMask(rawValue: 0x0fff)
    }

    /// The process-wide shared file manager.
    nonisolated(unsafe) public static let `default` = FileManager()

    /// Creates a file manager.
    public init() {
    }

    // MARK: - Existence

    /// Returns whether a file or directory exists at a path.
    open func fileExists(atPath path: String) -> Bool {
        nativeAttributes(atPath: path) != nil
    }

    /// Returns whether a path exists, reporting whether it is a directory.
    open func fileExists(atPath path: String, isDirectory: UnsafeMutablePointer<ObjCBool>?) -> Bool {
        guard let attributes = nativeAttributes(atPath: path) else {
            return false
        }

        isDirectory?.pointee = ObjCBool((attributes & FileManager.directoryAttribute) != 0)
        return true
    }

    // MARK: - Listing

    /// Returns the names of the items inside a directory, sorted.
    open func contentsOfDirectory(atPath path: String) throws -> [String] {
        #if os(Windows)
        var isDirectory = ObjCBool(false)
        guard fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw FileError.fileNotFound(path)
        }

        var names: [String] = []
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: FileManager.findDataSize, alignment: 4)
        defer {
            buffer.deallocate()
        }

        let handle = withWidePath(joinPath(path, "*")) { pattern in
            WinFoundationFindFirstFileW(pattern, buffer)
        }
        guard isValidFindHandle(handle) else {
            return []
        }
        defer {
            _ = WinFoundationFindClose(handle)
        }

        repeat {
            let name = fileName(inFindData: buffer)
            if name != "." && name != ".." {
                names.append(name)
            }
        } while WinFoundationFindNextFileW(handle, buffer) != 0

        return names.sorted()
        #else
        throw FileError.operationFailed(path)
        #endif
    }

    /// Returns the URLs of the items inside a directory, sorted by name.
    open func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [String]? = nil) throws -> [URL] {
        try contentsOfDirectory(atPath: url.path).map { url.appendingPathComponent($0) }
    }

    // MARK: - Creation

    /// Creates a directory, optionally creating missing parents.
    open func createDirectory(atPath path: String, withIntermediateDirectories createIntermediates: Bool, attributes: [String: Any]? = nil) throws {
        #if os(Windows)
        let normalized = String(path.map { $0 == "/" ? "\\" : $0 })
        if createIntermediates {
            var partial = ""
            for component in normalized.split(separator: "\\", omittingEmptySubsequences: true) {
                partial = partial.isEmpty ? String(component) : "\(partial)\\\(component)"
                if partial.hasSuffix(":") {
                    continue
                }
                _ = withWidePath(partial) { widePath in
                    WinFoundationCreateDirectoryW(widePath, nil)
                }
            }
            var isDirectory = ObjCBool(false)
            guard fileExists(atPath: normalized, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw FileError.operationFailed(path)
            }
        } else {
            let created = withWidePath(normalized) { widePath in
                WinFoundationCreateDirectoryW(widePath, nil)
            }
            guard created != 0 else {
                throw fileExists(atPath: normalized) ? FileError.alreadyExists(path) : FileError.operationFailed(path)
            }
        }
        #else
        throw FileError.operationFailed(path)
        #endif
    }

    /// Creates a directory at a file URL, optionally creating missing parents.
    open func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [String: Any]? = nil) throws {
        try createDirectory(atPath: url.path, withIntermediateDirectories: createIntermediates, attributes: attributes)
    }

    // MARK: - Removal

    /// Removes a file, or a directory and everything inside it.
    open func removeItem(atPath path: String) throws {
        #if os(Windows)
        guard let attributes = nativeAttributes(atPath: path) else {
            throw FileError.fileNotFound(path)
        }

        if (attributes & FileManager.directoryAttribute) != 0 {
            for child in try contentsOfDirectory(atPath: path) {
                try removeItem(atPath: joinPath(path, child))
            }
            let removed = withWidePath(path) { widePath in
                WinFoundationRemoveDirectoryW(widePath)
            }
            guard removed != 0 else {
                throw FileError.operationFailed(path)
            }
        } else {
            let deleted = withWidePath(path) { widePath in
                WinFoundationDeleteFileW(widePath)
            }
            guard deleted != 0 else {
                throw FileError.operationFailed(path)
            }
        }
        #else
        throw FileError.operationFailed(path)
        #endif
    }

    /// Removes the item at a file URL.
    open func removeItem(at url: URL) throws {
        try removeItem(atPath: url.path)
    }

    // MARK: - Copy and move

    /// Copies a file, or a directory and everything inside it.
    ///
    /// The destination must not exist, matching Foundation.
    open func copyItem(atPath sourcePath: String, toPath destinationPath: String) throws {
        #if os(Windows)
        guard let attributes = nativeAttributes(atPath: sourcePath) else {
            throw FileError.fileNotFound(sourcePath)
        }
        guard !fileExists(atPath: destinationPath) else {
            throw FileError.alreadyExists(destinationPath)
        }

        if (attributes & FileManager.directoryAttribute) != 0 {
            try createDirectory(atPath: destinationPath, withIntermediateDirectories: false)
            for child in try contentsOfDirectory(atPath: sourcePath) {
                try copyItem(atPath: joinPath(sourcePath, child), toPath: joinPath(destinationPath, child))
            }
        } else {
            let copied = withWidePath(sourcePath) { source in
                withWidePath(destinationPath) { destination in
                    WinFoundationCopyFileW(source, destination, 1)
                }
            }
            guard copied != 0 else {
                throw FileError.operationFailed(destinationPath)
            }
        }
        #else
        throw FileError.operationFailed(sourcePath)
        #endif
    }

    /// Copies the item at a file URL to a destination URL.
    open func copyItem(at sourceURL: URL, to destinationURL: URL) throws {
        try copyItem(atPath: sourceURL.path, toPath: destinationURL.path)
    }

    /// Moves a file or directory.
    ///
    /// The destination must not exist, matching Foundation.
    open func moveItem(atPath sourcePath: String, toPath destinationPath: String) throws {
        #if os(Windows)
        guard fileExists(atPath: sourcePath) else {
            throw FileError.fileNotFound(sourcePath)
        }
        guard !fileExists(atPath: destinationPath) else {
            throw FileError.alreadyExists(destinationPath)
        }

        let moved = withWidePath(sourcePath) { source in
            withWidePath(destinationPath) { destination in
                WinFoundationMoveFileExW(source, destination, FileManager.moveCopyAllowed)
            }
        }
        guard moved != 0 else {
            throw FileError.operationFailed(destinationPath)
        }
        #else
        throw FileError.operationFailed(sourcePath)
        #endif
    }

    /// Moves the item at a file URL to a destination URL.
    open func moveItem(at sourceURL: URL, to destinationURL: URL) throws {
        try moveItem(atPath: sourceURL.path, toPath: destinationURL.path)
    }

    // MARK: - Well-known locations

    /// The user's temporary directory.
    open var temporaryDirectory: URL {
        #if os(Windows)
        var buffer = Array<UInt16>(repeating: 0, count: 261)
        let length = buffer.withUnsafeMutableBufferPointer { pointer in
            WinFoundationGetTempPathW(UInt32(pointer.count), pointer.baseAddress)
        }
        guard length > 0, Int(length) < buffer.count else {
            return URL(fileURLWithPath: "C:\\Windows\\Temp")
        }

        var path = String(decoding: buffer.prefix(Int(length)), as: UTF16.self)
        if path.hasSuffix("\\") {
            path.removeLast()
        }
        return URL(fileURLWithPath: path)
        #else
        return URL(fileURLWithPath: "/tmp")
        #endif
    }

    /// Returns the locations of a known directory, most specific first.
    ///
    /// Windows maps AppKit's usual requests onto shell known folders:
    /// Documents, Desktop, roaming AppData (application support), and local
    /// AppData (caches).
    open func urls(for directory: SearchPathDirectory, in domainMask: SearchPathDomainMask) -> [URL] {
        #if os(Windows)
        let folderIdentifier: Int32
        switch directory {
        case .documentDirectory:
            folderIdentifier = 0x0005
        case .desktopDirectory:
            folderIdentifier = 0x0010
        case .applicationSupportDirectory:
            folderIdentifier = 0x001a
        case .cachesDirectory:
            folderIdentifier = 0x001c
        case .userDirectory:
            folderIdentifier = 0x0028
        }

        var buffer = Array<UInt16>(repeating: 0, count: 261)
        let status = buffer.withUnsafeMutableBufferPointer { pointer in
            WinFoundationSHGetFolderPathW(nil, folderIdentifier, nil, 0, pointer.baseAddress)
        }
        guard status == 0 else {
            return []
        }

        let length = buffer.firstIndex(of: 0) ?? buffer.count
        return [URL(fileURLWithPath: String(decoding: buffer.prefix(length), as: UTF16.self))]
        #else
        return []
        #endif
    }

    // MARK: - Native helpers

    private static let directoryAttribute: UInt32 = 0x0000_0010
    private static let invalidAttributes: UInt32 = 0xffff_ffff
    private static let moveCopyAllowed: UInt32 = 0x0000_0002
    private static let findDataSize = 592
    private static let findDataNameOffset = 44
    private static let findDataNameCapacity = 260

    private func joinPath(_ base: String, _ component: String) -> String {
        base.hasSuffix("\\") || base.hasSuffix("/") ? "\(base)\(component)" : "\(base)\\\(component)"
    }

    private func nativeAttributes(atPath path: String) -> UInt32? {
        #if os(Windows)
        guard !path.isEmpty else {
            return nil
        }
        let attributes = withWidePath(path) { widePath in
            WinFoundationGetFileAttributesW(widePath)
        }
        return attributes == FileManager.invalidAttributes ? nil : attributes
        #else
        return nil
        #endif
    }

    #if os(Windows)
    private func withWidePath<Result>(_ path: String, _ body: (UnsafePointer<UInt16>?) -> Result) -> Result {
        var units = Array(String(path.map { $0 == "/" ? "\\" : $0 }).utf16)
        units.append(0)
        return units.withUnsafeBufferPointer { pointer in
            body(pointer.baseAddress)
        }
    }

    private func isValidFindHandle(_ handle: UnsafeMutableRawPointer?) -> Bool {
        guard let handle else {
            return false
        }
        return UInt(bitPattern: handle) != UInt(bitPattern: -1)
    }

    private func fileName(inFindData buffer: UnsafeMutableRawPointer) -> String {
        let namePointer = (buffer + FileManager.findDataNameOffset).assumingMemoryBound(to: UInt16.self)
        var units: [UInt16] = []
        for index in 0..<FileManager.findDataNameCapacity {
            let unit = namePointer[index]
            if unit == 0 {
                break
            }
            units.append(unit)
        }
        return String(decoding: units, as: UTF16.self)
    }
    #endif
}

#if os(Windows)
@_silgen_name("GetFileAttributesW")
private func WinFoundationGetFileAttributesW(_ path: UnsafePointer<UInt16>?) -> UInt32

@_silgen_name("CreateDirectoryW")
private func WinFoundationCreateDirectoryW(_ path: UnsafePointer<UInt16>?, _ securityAttributes: UnsafeMutableRawPointer?) -> Int32

@_silgen_name("RemoveDirectoryW")
private func WinFoundationRemoveDirectoryW(_ path: UnsafePointer<UInt16>?) -> Int32

@_silgen_name("DeleteFileW")
private func WinFoundationDeleteFileW(_ path: UnsafePointer<UInt16>?) -> Int32

@_silgen_name("CopyFileW")
private func WinFoundationCopyFileW(_ source: UnsafePointer<UInt16>?, _ destination: UnsafePointer<UInt16>?, _ failIfExists: Int32) -> Int32

@_silgen_name("MoveFileExW")
private func WinFoundationMoveFileExW(_ source: UnsafePointer<UInt16>?, _ destination: UnsafePointer<UInt16>?, _ flags: UInt32) -> Int32

@_silgen_name("FindFirstFileW")
private func WinFoundationFindFirstFileW(_ pattern: UnsafePointer<UInt16>?, _ findData: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?

@_silgen_name("FindNextFileW")
private func WinFoundationFindNextFileW(_ handle: UnsafeMutableRawPointer?, _ findData: UnsafeMutableRawPointer?) -> Int32

@_silgen_name("FindClose")
private func WinFoundationFindClose(_ handle: UnsafeMutableRawPointer?) -> Int32

@_silgen_name("GetTempPathW")
private func WinFoundationGetTempPathW(_ bufferLength: UInt32, _ buffer: UnsafeMutablePointer<UInt16>?) -> UInt32

@_silgen_name("SHGetFolderPathW")
private func WinFoundationSHGetFolderPathW(
    _ owner: UnsafeMutableRawPointer?,
    _ folder: Int32,
    _ token: UnsafeMutableRawPointer?,
    _ flags: UInt32,
    _ path: UnsafeMutablePointer<UInt16>?
) -> Int32
#endif
