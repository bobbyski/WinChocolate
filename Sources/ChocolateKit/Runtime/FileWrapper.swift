// A file or directory held in memory, matching Foundation's `FileWrapper`.
//
// This file owns the *model*: what a wrapper is, what it contains, and how
// children are named. Disk reading, writing, and serialization live next door
// in `FileWrapperIO.swift`, because they are a different responsibility with a
// different failure mode.
//
// ---------------------------------------------------------------------------
// Why this is gated, and why it lives here rather than in WinFoundation.
//
// `NSDocument`'s package API is written in terms of `FileWrapper`, so the type
// has to exist on every backend. Two of the four Foundations underneath this
// module already have it and two do not — measured, not assumed:
//
//     macOS    real Foundation            ✅ has FileWrapper
//     Linux    swift-corelibs-foundation  ✅ has FileWrapper
//     Windows  WinFoundation              ✗
//     WASI     the wasm SDK's Foundation  ✗  (it has FileManager, not this)
//
// Declaring it unconditionally would collide with the real one on the first
// two, so it is gated to the two that need it. It lives in the core rather
// than in WinFoundation because WinFoundation is a *Windows-only* dependency —
// a WASI build never sees it — and one implementation serving both gaps beats
// two copies of the same 450 lines.
// ---------------------------------------------------------------------------

#if USE_WIN_FOUNDATION || os(WASI)

/// An in-memory representation of a file, directory, or symbolic link.
///
/// `FileWrapper` is what `NSDocument`'s document-package API is written in
/// terms of: a document that saves as a bundle returns one wrapper containing
/// several children, and AppKit writes the tree to disk in one operation.
///
/// ```
///          FileWrapper(directory)              "MyNote.notebundle"
///                    │
///          ┌─────────┼──────────────┐
///          ▼         ▼              ▼
///     "text.rtf"  "meta.json"   FileWrapper(directory)  "Images"
///     (regular)   (regular)              │
///                                        ▼
///                                  "cover.png" (regular)
/// ```
///
/// A wrapper is exactly one of three kinds, which is why the contents are
/// modelled as an enum rather than three optional properties — a wrapper that
/// is both a directory and a symbolic link cannot be expressed.
///
/// **Boundaries on this platform.** Real Foundation can leave a wrapper's bytes
/// unread until they are needed (`ReadingOptions.withoutMapping` and lazy
/// mapping); this implementation always reads immediately, so the option is
/// accepted and has no effect. Symbolic links are modelled and serialized, but
/// creating one on disk needs a privilege Windows does not grant by default, so
/// writing one reports `NSFeatureUnsupportedError` rather than pretending.
open class FileWrapper {
    /// What a wrapper holds. Exactly one case is possible at a time, so a
    /// wrapper cannot claim to be two kinds at once.
    internal enum Contents {
        /// A regular file's bytes.
        case regularFile(Data)

        /// A directory's children, keyed by the name each is stored under.
        case directory([String: FileWrapper])

        /// A symbolic link's destination.
        case symbolicLink(URL)
    }

    /// Options controlling how a wrapper is read from disk.
    public struct ReadingOptions: OptionSet, Sendable {
        /// The raw option value.
        public let rawValue: UInt

        /// Creates options from a raw value.
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// Read the whole tree up front rather than on demand.
        ///
        /// Always in effect here: this implementation has no lazy mode.
        public static let immediate = ReadingOptions(rawValue: 1)

        /// Copy file contents rather than memory-mapping them.
        ///
        /// Always in effect here, for the same reason.
        public static let withoutMapping = ReadingOptions(rawValue: 2)
    }

    /// Options controlling how a wrapper is written to disk.
    public struct WritingOptions: OptionSet, Sendable {
        /// The raw option value.
        public let rawValue: UInt

        /// Creates options from a raw value.
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// Write to a temporary location and move into place, so a failure
        /// part-way through cannot leave a half-written file.
        public static let atomic = WritingOptions(rawValue: 1)

        /// Update each wrapper's `filename` to the name it was written under.
        public static let withNameUpdating = WritingOptions(rawValue: 2)
    }

    /// What this wrapper holds.
    internal var contents: Contents

    /// The name this wrapper was last read from or written to, if any.
    ///
    /// Set by a read, and by a write that passed `.withNameUpdating`.
    open var filename: String?

    /// The name this wrapper would like to be stored under.
    ///
    /// A parent directory honours it when the name is free, and disambiguates
    /// when it is not — see `addFileWrapper(_:)`.
    open var preferredFilename: String? {
        didSet {
            // Foundation keeps the parent's key in step with the preferred
            // name, so a rename does not orphan the child under its old key.
            guard let parent, let preferredFilename, preferredFilename != oldValue else {
                return
            }
            parent.rekeyChild(self, to: preferredFilename)
        }
    }

    /// File attributes such as modification date and POSIX permissions.
    ///
    /// Keyed by `FileAttributeKey`'s raw strings, matching Foundation, which
    /// imports this dictionary with `String` keys rather than typed ones.
    open var fileAttributes: [String: Any] = [:]

    /// The directory wrapper this one is a child of, if any.
    ///
    /// Weak: a parent owns its children through `fileWrappers`, so a strong
    /// link back would be a cycle that keeps whole trees alive.
    internal weak var parent: FileWrapper?

    // MARK: - Creating wrappers

    /// Creates a wrapper holding a regular file's bytes.
    public init(regularFileWithContents contents: Data) {
        self.contents = .regularFile(contents)
    }

    /// Creates a directory wrapper holding the given children, keyed by name.
    public init(directoryWithFileWrappers childrenByPreferredName: [String: FileWrapper]) {
        self.contents = .directory([:])
        for (name, child) in childrenByPreferredName {
            child.preferredFilename = child.preferredFilename ?? name
            adopt(child, as: name)
        }
    }

    /// Creates a wrapper representing a symbolic link to a destination.
    public init(symbolicLinkWithDestinationURL url: URL) {
        self.contents = .symbolicLink(url)
    }

    /// Creates a wrapper by reading a file or directory tree from disk.
    ///
    /// - Throws: An `NSError` in `NSCocoaErrorDomain` when the item cannot be
    ///   read — the same domain and code Foundation reports.
    public init(url: URL, options: ReadingOptions = []) throws {
        self.contents = .regularFile(Data())
        try read(from: url, options: options)
    }

    // MARK: - Kind

    /// Whether this wrapper represents a directory.
    open var isDirectory: Bool {
        if case .directory = contents {
            return true
        }
        return false
    }

    /// Whether this wrapper represents a regular file.
    open var isRegularFile: Bool {
        if case .regularFile = contents {
            return true
        }
        return false
    }

    /// Whether this wrapper represents a symbolic link.
    open var isSymbolicLink: Bool {
        if case .symbolicLink = contents {
            return true
        }
        return false
    }

    /// The bytes of a regular file, or nil for the other kinds.
    open var regularFileContents: Data? {
        if case .regularFile(let data) = contents {
            return data
        }
        return nil
    }

    /// A symbolic link's destination, or nil for the other kinds.
    open var symbolicLinkDestinationURL: URL? {
        if case .symbolicLink(let url) = contents {
            return url
        }
        return nil
    }

    /// A directory's children keyed by storage name, or nil for the other kinds.
    open var fileWrappers: [String: FileWrapper]? {
        if case .directory(let children) = contents {
            return children
        }
        return nil
    }

    // MARK: - Directory children

    /// Adds a child to this directory and returns the name it is stored under.
    ///
    /// The child's `preferredFilename` is used when it is free; otherwise a
    /// numeric suffix disambiguates, as Foundation's does. The returned key is
    /// the authority — it is not necessarily the preferred name.
    ///
    /// - Precondition: This wrapper is a directory.
    @discardableResult
    open func addFileWrapper(_ child: FileWrapper) -> String {
        precondition(isDirectory, "addFileWrapper(_:) requires a directory wrapper.")
        let key = availableKey(for: child.preferredFilename ?? "File")
        adopt(child, as: key)
        return key
    }

    /// Adds a regular file to this directory and returns its storage name.
    ///
    /// The convenience Foundation offers for the overwhelmingly common case of
    /// putting some bytes into a document package under a known name.
    ///
    /// - Precondition: This wrapper is a directory.
    @discardableResult
    open func addRegularFile(withContents data: Data, preferredFilename fileName: String) -> String {
        let child = FileWrapper(regularFileWithContents: data)
        child.preferredFilename = fileName
        return addFileWrapper(child)
    }

    /// Removes a child from this directory.
    ///
    /// Does nothing when the wrapper is not a child of this one.
    open func removeFileWrapper(_ child: FileWrapper) {
        guard case .directory(var children) = contents,
              let key = children.first(where: { $0.value === child })?.key else {
            return
        }

        children.removeValue(forKey: key)
        contents = .directory(children)
        child.parent = nil
    }

    /// Returns the name a child is stored under, or nil when it is not a child.
    open func keyForChildFileWrapper(_ child: FileWrapper) -> String? {
        guard case .directory(let children) = contents else {
            return nil
        }
        return children.first { $0.value === child }?.key
    }

    // MARK: - Internal child bookkeeping

    /// Stores a child under an exact key, replacing anything already there.
    private func adopt(_ child: FileWrapper, as key: String) {
        guard case .directory(var children) = contents else {
            return
        }

        children[key]?.parent = nil
        children[key] = child
        child.parent = self
        contents = .directory(children)
    }

    /// Moves a child to a new key after its preferred name changed.
    private func rekeyChild(_ child: FileWrapper, to preferred: String) {
        guard case .directory(var children) = contents,
              let oldKey = children.first(where: { $0.value === child })?.key,
              oldKey != preferred else {
            return
        }

        children.removeValue(forKey: oldKey)
        contents = .directory(children)
        adopt(child, as: availableKey(for: preferred))
    }

    /// Returns `preferred` when free, or the first free `name-2`, `name-3`, … .
    private func availableKey(for preferred: String) -> String {
        guard case .directory(let children) = contents else {
            return preferred
        }
        guard children[preferred] != nil else {
            return preferred
        }

        // Disambiguate before the extension, so "cover.png" becomes
        // "cover-2.png" rather than "cover.png-2".
        let (stem, ext) = Self.splitExtension(of: preferred)
        var index = 2
        while true {
            let candidate = ext.isEmpty ? "\(stem)-\(index)" : "\(stem)-\(index).\(ext)"
            if children[candidate] == nil {
                return candidate
            }
            index += 1
        }
    }

    /// Splits a file name into its stem and extension.
    ///
    /// A leading dot is part of the stem, so ".gitignore" keeps its whole name
    /// rather than being read as an extension with no stem.
    private static func splitExtension(of name: String) -> (stem: String, ext: String) {
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else {
            return (name, "")
        }
        return (String(name[name.startIndex..<dot]), String(name[name.index(after: dot)...]))
    }
}

#endif
