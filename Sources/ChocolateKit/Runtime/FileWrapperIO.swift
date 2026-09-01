// `FileWrapper`'s disk and serialization half.
//
// Kept apart from the model in `FileWrapper.swift` because it is a different
// responsibility with a different failure mode: everything here talks to the
// file system or to a byte stream, and everything here can fail.

#if USE_WIN_FOUNDATION || os(WASI)

extension FileWrapper {
    // MARK: - Reading

    /// Replaces this wrapper's contents by reading a file or directory tree.
    ///
    /// Directories are read recursively. `options` is accepted for source
    /// compatibility; this implementation always reads immediately, which is
    /// the behaviour `.immediate` requests.
    ///
    /// - Throws: An `NSError` in `NSCocoaErrorDomain` describing why the item
    ///   could not be read.
    public func read(from url: URL, options: ReadingOptions = []) throws {
        // A substitute store (a browser tab) has no directories, so a hit is
        // always a regular file. See Runtime/ChocolateFileAccess.swift.
        if ChocolateFileAccess.usesSubstitute {
            guard let bytes = ChocolateFileAccess.contents(atPath: url.path) else {
                throw CocoaFileError.error(CocoaFileError.readNoSuchFile, url: url,
                                           reason: "The file doesn’t exist.")
            }
            contents = .regularFile(Data(bytes))
            filename = url.lastPathComponent
            if preferredFilename == nil {
                preferredFilename = url.lastPathComponent
            }
            return
        }

        let manager = FileManager.default
        var isDirectory = ObjCBool(false)
        guard manager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw CocoaFileError.error(CocoaFileError.readNoSuchFile, url: url,
                                 reason: "The file doesn’t exist.")
        }

        if isDirectory.boolValue {
            try readDirectory(from: url, options: options)
        } else {
            contents = .regularFile(try Data(contentsOf: url))
        }

        filename = url.lastPathComponent
        if preferredFilename == nil {
            preferredFilename = url.lastPathComponent
        }
    }

    /// Reads a directory's children into this wrapper, recursively.
    private func readDirectory(from url: URL, options: ReadingOptions) throws {
        let manager = FileManager.default
        contents = .directory([:])

        let names: [String]
        do {
            names = try manager.contentsOfDirectory(atPath: url.path)
        } catch {
            throw CocoaFileError.error(CocoaFileError.readUnknown, url: url,
                                 reason: "The folder’s contents couldn’t be listed.")
        }

        for name in names.sorted() {
            let child = FileWrapper(regularFileWithContents: Data())
            try child.read(from: url.appendingPathComponent(name), options: options)
            child.preferredFilename = name
            addFileWrapper(child)
        }
    }

    /// Whether this wrapper's contents match what is on disk at a URL.
    ///
    /// Foundation uses this to decide whether a save can be skipped. It
    /// compares structure and bytes; a mismatch of either answers false, and so
    /// does an item that cannot be read at all.
    public func matchesContents(of url: URL) -> Bool {
        guard let onDisk = try? FileWrapper(url: url, options: .immediate) else {
            return false
        }
        return matches(onDisk)
    }

    /// Structural comparison used by `matchesContents(of:)`.
    private func matches(_ other: FileWrapper) -> Bool {
        switch (contents, other.contents) {
        case (.regularFile(let ours), .regularFile(let theirs)):
            return ours == theirs

        case (.symbolicLink(let ours), .symbolicLink(let theirs)):
            return ours == theirs

        case (.directory(let ours), .directory(let theirs)):
            guard ours.count == theirs.count else {
                return false
            }
            return ours.allSatisfy { name, child in
                guard let counterpart = theirs[name] else {
                    return false
                }
                return child.matches(counterpart)
            }

        default:
            // Different kinds never match, whatever they contain.
            return false
        }
    }

    // MARK: - Writing

    /// Writes this wrapper to disk.
    ///
    /// - Parameters:
    ///   - url: Where to write. For a directory wrapper this becomes a folder.
    ///   - options: `.atomic` writes via a temporary location and moves the
    ///     result into place; `.withNameUpdating` sets each wrapper's
    ///     `filename` to the name it was written under.
    ///   - originalContentsURL: Where the previous version lives, when there is
    ///     one. Accepted for source compatibility; this implementation always
    ///     writes contents in full rather than hard-linking unchanged children.
    /// - Throws: An `NSError` in `NSCocoaErrorDomain` describing the failure.
    public func write(to url: URL,
                      options: WritingOptions = [],
                      originalContentsURL: URL?) throws {
        // Atomic staging is a filesystem trick — write beside, then move. A
        // substitute store has no such failure mode to protect against (a
        // dictionary assignment either happens or does not), so it writes
        // straight through.
        guard options.contains(.atomic), !ChocolateFileAccess.usesSubstitute else {
            try writeContents(to: url, options: options)
            return
        }

        // Atomic: build the whole tree beside the destination, then swap. A
        // sibling rather than the temp directory, so the move stays on one
        // volume and cannot fail part-way across a device boundary.
        let manager = FileManager.default
        let staging = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).writing")

        try? manager.removeItem(at: staging)
        try writeContents(to: staging, options: options)

        do {
            try? manager.removeItem(at: url)
            try manager.moveItem(at: staging, to: url)
        } catch {
            try? manager.removeItem(at: staging)
            throw CocoaFileError.error(CocoaFileError.writeUnknown, url: url,
                                 reason: "The finished file couldn’t be moved into place.")
        }
    }

    /// Writes this wrapper's contents to an exact location, without staging.
    private func writeContents(to url: URL, options: WritingOptions) throws {
        switch contents {
        case .regularFile(let data):
            if ChocolateFileAccess.usesSubstitute {
                ChocolateFileAccess.write([UInt8](data), toPath: url.path)
                break
            }
            do {
                try data.write(to: url)
            } catch {
                throw CocoaFileError.error(CocoaFileError.writeNoPermission, url: url,
                                     reason: "The file couldn’t be written.")
            }

        case .directory(let children):
            // A substitute store has no directories — children are written
            // under their full paths, which is enough for a document package
            // to round-trip through it.
            if !ChocolateFileAccess.usesSubstitute {
                let manager = FileManager.default
                do {
                    try manager.createDirectory(at: url, withIntermediateDirectories: true)
                } catch {
                    throw CocoaFileError.error(CocoaFileError.writeNoPermission, url: url,
                                         reason: "The folder couldn’t be created.")
                }
            }
            for (name, child) in children {
                // Children are written non-atomically whatever the caller asked
                // for: the parent's staging directory already gives the whole
                // tree its all-or-nothing guarantee, and staging each child
                // inside it would only add churn.
                var childOptions = options
                childOptions.remove(.atomic)
                try child.writeContents(to: url.appendingPathComponent(name),
                                        options: childOptions)
                if options.contains(.withNameUpdating) {
                    child.filename = name
                }
            }

        case .symbolicLink:
            // Documented boundary: creating a symbolic link needs a privilege
            // Windows does not grant by default, so this reports the failure
            // rather than silently writing something else.
            throw CocoaFileError.error(CocoaFileError.featureUnsupported, url: url,
                                 reason: "Symbolic links can’t be created on this platform.")
        }

        if options.contains(.withNameUpdating) {
            filename = url.lastPathComponent
        }
    }

    // MARK: - Serialization

    /// A byte representation of this wrapper, suitable for
    /// `init?(serializedRepresentation:)`.
    ///
    /// **Boundary:** Apple's representation is a private archive format, so
    /// these bytes are not interchangeable with a Mac's. They round-trip
    /// through this implementation, which is what the property is used for in
    /// practice — carrying a wrapper through a pasteboard or a document store.
    public var serializedRepresentation: Data? {
        var out = Data(FileWrapperArchive.magic.utf8)
        encode(into: &out)
        return out
    }

    /// Creates a wrapper from bytes produced by `serializedRepresentation`.
    ///
    /// Returns nil when the bytes are not in this implementation's format or
    /// are truncated.
    public convenience init?(serializedRepresentation: Data) {
        let bytes = [UInt8](serializedRepresentation)
        let magic = Array(FileWrapperArchive.magic.utf8)
        guard bytes.count > magic.count, Array(bytes[0..<magic.count]) == magic else {
            return nil
        }

        var cursor = magic.count
        guard let decoded = FileWrapper.decode(from: bytes, at: &cursor) else {
            return nil
        }

        self.init(regularFileWithContents: Data())
        contents = decoded.contents
        filename = decoded.filename
        preferredFilename = decoded.preferredFilename
    }

    /// Appends this wrapper's encoded form to a buffer.
    private func encode(into out: inout Data) {
        switch contents {
        case .regularFile(let data):
            out.append(FileWrapperArchive.regularFile)
            FileWrapperArchive.appendString(filename, to: &out)
            FileWrapperArchive.appendString(preferredFilename, to: &out)
            FileWrapperArchive.appendCount(data.count, to: &out)
            out.append(data)

        case .symbolicLink(let url):
            out.append(FileWrapperArchive.symbolicLink)
            FileWrapperArchive.appendString(filename, to: &out)
            FileWrapperArchive.appendString(preferredFilename, to: &out)
            FileWrapperArchive.appendString(url.path, to: &out)

        case .directory(let children):
            out.append(FileWrapperArchive.directory)
            FileWrapperArchive.appendString(filename, to: &out)
            FileWrapperArchive.appendString(preferredFilename, to: &out)
            FileWrapperArchive.appendCount(children.count, to: &out)
            // Sorted so the same tree always serializes to the same bytes,
            // which is what lets a caller compare two representations.
            for name in children.keys.sorted() {
                FileWrapperArchive.appendString(name, to: &out)
                children[name]?.encode(into: &out)
            }
        }
    }

    /// Decodes one wrapper, advancing the cursor past its bytes.
    private static func decode(from bytes: [UInt8], at cursor: inout Int) -> FileWrapper? {
        guard cursor < bytes.count else {
            return nil
        }

        let kind = bytes[cursor]
        cursor += 1
        guard let filename = FileWrapperArchive.readString(bytes, &cursor),
              let preferred = FileWrapperArchive.readString(bytes, &cursor) else {
            return nil
        }

        let wrapper: FileWrapper
        switch kind {
        case FileWrapperArchive.regularFile:
            guard let count = FileWrapperArchive.readCount(bytes, &cursor),
                  cursor + count <= bytes.count else {
                return nil
            }
            wrapper = FileWrapper(regularFileWithContents: Data(bytes[cursor..<cursor + count]))
            cursor += count

        case FileWrapperArchive.symbolicLink:
            guard let path = FileWrapperArchive.readString(bytes, &cursor), let path else {
                return nil
            }
            wrapper = FileWrapper(symbolicLinkWithDestinationURL: URL(fileURLWithPath: path))

        case FileWrapperArchive.directory:
            guard let count = FileWrapperArchive.readCount(bytes, &cursor) else {
                return nil
            }
            wrapper = FileWrapper(directoryWithFileWrappers: [:])
            for _ in 0..<count {
                guard let name = FileWrapperArchive.readString(bytes, &cursor), let name,
                      let child = decode(from: bytes, at: &cursor) else {
                    return nil
                }
                child.preferredFilename = child.preferredFilename ?? name
                wrapper.addFileWrapper(child)
            }

        default:
            return nil
        }

        wrapper.filename = filename ?? wrapper.filename
        wrapper.preferredFilename = preferred ?? wrapper.preferredFilename
        return wrapper
    }
}

/// The byte layout `FileWrapper.serializedRepresentation` produces.
///
/// ```
///   "CHOCFW01"                       magic, once at the front
///   node := kind : UInt8             1 regular · 2 directory · 3 symlink
///           filename    : string     length-prefixed, 0xFFFFFFFF = nil
///           preferred   : string
///           payload                  regular:  count : UInt32 + bytes
///                                    symlink:  string (destination path)
///                                    directory: count : UInt32
///                                               then count × (string, node)
/// ```
///
/// Counts and lengths are little-endian `UInt32`. Deliberately plain: it is
/// read and written by the two methods above and nothing else, so a format that
/// can be checked by eye is worth more here than a compact one.
internal enum FileWrapperArchive {
    /// Identifies the format and its version.
    static let magic = "CHOCFW01"

    /// Node tag for a regular file.
    static let regularFile: UInt8 = 1

    /// Node tag for a directory.
    static let directory: UInt8 = 2

    /// Node tag for a symbolic link.
    static let symbolicLink: UInt8 = 3

    /// Marks a nil string, distinguishing it from an empty one.
    static let nilLength: UInt32 = 0xFFFF_FFFF

    /// Appends a little-endian `UInt32` count.
    static func appendCount(_ value: Int, to out: inout Data) {
        appendRaw(UInt32(value), to: &out)
    }

    /// Appends a length-prefixed UTF-8 string, or a nil marker.
    static func appendString(_ value: String?, to out: inout Data) {
        guard let value else {
            appendRaw(nilLength, to: &out)
            return
        }
        let utf8 = Array(value.utf8)
        appendRaw(UInt32(utf8.count), to: &out)
        out.append(contentsOf: utf8)
    }

    /// Appends four little-endian bytes.
    private static func appendRaw(_ value: UInt32, to out: inout Data) {
        out.append(UInt8(truncatingIfNeeded: value))
        out.append(UInt8(truncatingIfNeeded: value >> 8))
        out.append(UInt8(truncatingIfNeeded: value >> 16))
        out.append(UInt8(truncatingIfNeeded: value >> 24))
    }

    /// Reads a little-endian `UInt32`, advancing the cursor.
    static func readRaw(_ bytes: [UInt8], _ cursor: inout Int) -> UInt32? {
        guard cursor + 4 <= bytes.count else {
            return nil
        }
        let value = UInt32(bytes[cursor])
            | UInt32(bytes[cursor + 1]) << 8
            | UInt32(bytes[cursor + 2]) << 16
            | UInt32(bytes[cursor + 3]) << 24
        cursor += 4
        return value
    }

    /// Reads a count, advancing the cursor.
    static func readCount(_ bytes: [UInt8], _ cursor: inout Int) -> Int? {
        guard let raw = readRaw(bytes, &cursor), raw != nilLength else {
            return nil
        }
        return Int(raw)
    }

    /// Reads a length-prefixed string, advancing the cursor.
    ///
    /// The double optional is meaningful: the outer nil is a malformed or
    /// truncated stream, the inner nil is a string that was written as nil.
    static func readString(_ bytes: [UInt8], _ cursor: inout Int) -> String?? {
        guard let length = readRaw(bytes, &cursor) else {
            return nil
        }
        if length == nilLength {
            return .some(nil)
        }
        let count = Int(length)
        guard cursor + count <= bytes.count else {
            return nil
        }
        let text = String(decoding: bytes[cursor..<cursor + count], as: UTF8.self)
        cursor += count
        return .some(text)
    }
}

#endif
