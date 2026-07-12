import WinFoundation

/// The system pasteboard.
///
/// This slice keeps AppKit's `NSPasteboard` surface — the `general`
/// pasteboard, typed string and data access, `changeCount`, and the
/// old-style `declareTypes(_:owner:)` — over the platform clipboard, so copy
/// and paste interoperate with other applications. Plain text, rich text
/// (`.rtf` over the platform "Rich Text Format"), and PNG images (`.png`)
/// are the supported types. Writes after `clearContents()` accumulate, so
/// one logical copy can offer several representations at once, matching
/// AppKit's write pattern.
open class NSPasteboard: NSObject {
    /// A pasteboard data type.
    public struct PasteboardType: RawRepresentable, Hashable, Sendable {
        /// The type's raw identifier.
        public let rawValue: String

        /// Creates a pasteboard type from a raw identifier.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// Creates a pasteboard type from a string, matching AppKit's
        /// unlabeled convenience spelling.
        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }

        /// Plain text.
        public static let string = PasteboardType(rawValue: "public.utf8-plain-text")

        /// Rich Text Format data.
        public static let rtf = PasteboardType(rawValue: "public.rtf")

        /// PNG image data.
        public static let png = PasteboardType(rawValue: "public.png")

        /// A file URL (backed by the platform file-list clipboard format).
        public static let fileURL = PasteboardType(rawValue: "public.file-url")

        /// The platform clipboard format name for a data type, when defined.
        var winClipboardFormatName: String? {
            switch self {
            case .rtf:
                return "Rich Text Format"
            case .png:
                return "PNG"
            default:
                return nil
            }
        }
    }

    nonisolated(unsafe) private static var sharedGeneral: NSPasteboard?

    /// The shared general pasteboard, backed by the system clipboard.
    open class var general: NSPasteboard {
        if let sharedGeneral {
            return sharedGeneral
        }

        let pasteboard = NSPasteboard()
        sharedGeneral = pasteboard
        return pasteboard
    }

    /// Representations staged since the last `clearContents()`.
    ///
    /// Each write replays the whole set as one clipboard update, so a copy
    /// offering text plus RTF plus PNG stays a single logical change.
    private var stagedText: String?
    private var stagedData: [String: [UInt8]] = [:]
    private var stagedFilePaths: [String] = []

    /// Creates a pasteboard over the application's backend clipboard.
    public override init() {
        super.init()
    }

    /// A counter that changes whenever the pasteboard contents change,
    /// including changes made by other applications.
    open var changeCount: Int {
        NSApplication.shared.nativeBackend.clipboardChangeCount()
    }

    /// The types currently readable from the pasteboard.
    open var types: [PasteboardType]? {
        let backend = NSApplication.shared.nativeBackend
        var available: [PasteboardType] = []
        if backend.clipboardString() != nil {
            available.append(.string)
        }
        for dataType in [PasteboardType.rtf, .png] {
            if let formatName = dataType.winClipboardFormatName, backend.clipboardHasData(forFormat: formatName) {
                available.append(dataType)
            }
        }
        if !backend.clipboardFilePaths().isEmpty {
            available.append(.fileURL)
        }
        return available.isEmpty ? nil : available
    }

    /// Clears the pasteboard, returning the new change count.
    @discardableResult
    open func clearContents() -> Int {
        stagedText = nil
        stagedData = [:]
        stagedFilePaths = []
        NSApplication.shared.nativeBackend.clearClipboard()
        return changeCount
    }

    /// Declares types before writing, matching AppKit's older API shape.
    ///
    /// The classic clipboard has no ownership protocol, so this clears the
    /// pasteboard and returns the new change count.
    @discardableResult
    open func declareTypes(_ newTypes: [PasteboardType], owner: Any?) -> Int {
        clearContents()
    }

    /// Writes a string for a type, returning whether the type is supported.
    @discardableResult
    open func setString(_ string: String, forType dataType: PasteboardType) -> Bool {
        guard dataType == .string else {
            return false
        }

        stagedText = string
        flushStagedContents()
        return true
    }

    /// Writes data for a type, returning whether the type is supported.
    @discardableResult
    open func setData(_ data: Data, forType dataType: PasteboardType) -> Bool {
        guard let formatName = dataType.winClipboardFormatName else {
            return false
        }

        stagedData[formatName] = Array(data)
        flushStagedContents()
        return true
    }

    /// Reads the string for a type, when present.
    open func string(forType dataType: PasteboardType) -> String? {
        guard dataType == .string else {
            return nil
        }

        return NSApplication.shared.nativeBackend.clipboardString()
    }

    /// Reads the data for a type, when present.
    open func data(forType dataType: PasteboardType) -> Data? {
        guard let formatName = dataType.winClipboardFormatName else {
            return nil
        }

        guard let bytes = NSApplication.shared.nativeBackend.clipboardData(forFormat: formatName) else {
            return nil
        }

        return Data(bytes)
    }

    // MARK: - Object-level readers and writers

    /// The pasteboard contents as items.
    ///
    /// A file-list clipboard yields one item per file (each carrying a
    /// `.fileURL` string); otherwise the available text/RTF/PNG
    /// representations form a single item, matching how AppKit groups one
    /// logical copy.
    open var pasteboardItems: [NSPasteboardItem]? {
        let backend = NSApplication.shared.nativeBackend

        let filePaths = backend.clipboardFilePaths()
        if !filePaths.isEmpty {
            return filePaths.map { path in
                let item = NSPasteboardItem()
                item.setString(URL(fileURLWithPath: path).absoluteString, forType: .fileURL)
                return item
            }
        }

        let item = NSPasteboardItem()
        var hasContent = false
        if let text = backend.clipboardString() {
            item.setString(text, forType: .string)
            hasContent = true
        }
        for dataType in [PasteboardType.rtf, .png] {
            if let data = data(forType: dataType) {
                item.setData(data, forType: dataType)
                hasContent = true
            }
        }
        return hasContent ? [item] : nil
    }

    /// Writes objects to the pasteboard, matching AppKit's `writeObjects`.
    ///
    /// Supported objects: `URL` (file URLs join the platform file list),
    /// `String` (plain text), `NSAttributedString` (text + RTF), and
    /// `NSPasteboardItem` (each stored type). All writes stage into the same
    /// clipboard update.
    @discardableResult
    open func writeObjects(_ objects: [Any]) -> Bool {
        var wroteAny = false
        for object in objects {
            switch object {
            case let url as URL:
                if url.isFileURL {
                    stagedFilePaths.append(url.path)
                    wroteAny = true
                }
            case let string as String:
                stagedText = string
                wroteAny = true
            case let attributed as NSAttributedString:
                stagedText = attributed.string
                if let rtfData = attributed.rtf(from: NSRange(location: 0, length: attributed.length)),
                   let formatName = PasteboardType.rtf.winClipboardFormatName {
                    stagedData[formatName] = Array(rtfData)
                }
                wroteAny = true
            case let item as NSPasteboardItem:
                for type in item.types {
                    if type == .string, let text = item.string(forType: .string) {
                        stagedText = text
                        wroteAny = true
                    } else if type == .fileURL, let urlString = item.string(forType: .fileURL), let url = URL(string: urlString), url.isFileURL {
                        stagedFilePaths.append(url.path)
                        wroteAny = true
                    } else if let formatName = type.winClipboardFormatName, let data = item.data(forType: type) {
                        stagedData[formatName] = Array(data)
                        wroteAny = true
                    }
                }
            default:
                break
            }
        }
        if wroteAny {
            flushStagedContents()
        }
        return wroteAny
    }

    /// Reads objects of the given types, matching AppKit's `readObjects`.
    ///
    /// Pass `URL.self` (or `NSURL.self`) for file URLs, `String.self` for
    /// plain text, and `NSAttributedString.self` for rich text parsed from
    /// the clipboard's RTF.
    open func readObjects(forClasses classes: [Any.Type], options: [String: Any]? = nil) -> [Any]? {
        let backend = NSApplication.shared.nativeBackend
        var results: [Any] = []

        for readClass in classes {
            if readClass == URL.self {
                results.append(contentsOf: backend.clipboardFilePaths().map { URL(fileURLWithPath: $0) })
            } else if readClass == String.self {
                if let text = backend.clipboardString() {
                    results.append(text)
                }
            } else if readClass == NSAttributedString.self {
                if let rtfData = data(forType: .rtf), let attributed = NSAttributedString(rtf: rtfData) {
                    results.append(attributed)
                }
            }
        }
        return results.isEmpty ? nil : results
    }

    private func flushStagedContents() {
        NSApplication.shared.nativeBackend.setClipboardContents(text: stagedText, dataRepresentations: stagedData, filePaths: stagedFilePaths)
    }
}

/// One item on the pasteboard carrying typed representations, matching
/// AppKit's `NSPasteboardItem`.
open class NSPasteboardItem: NSObject {
    private var strings: [NSPasteboard.PasteboardType: String] = [:]
    private var datas: [NSPasteboard.PasteboardType: Data] = [:]
    private var typeOrder: [NSPasteboard.PasteboardType] = []

    /// Creates an empty pasteboard item.
    public override init() {
        super.init()
    }

    /// The types this item holds, in the order they were set.
    open var types: [NSPasteboard.PasteboardType] {
        typeOrder
    }

    /// Stores a string representation for a type.
    @discardableResult
    open func setString(_ string: String, forType type: NSPasteboard.PasteboardType) -> Bool {
        if !typeOrder.contains(type) {
            typeOrder.append(type)
        }
        strings[type] = string
        return true
    }

    /// Stores a data representation for a type.
    @discardableResult
    open func setData(_ data: Data, forType type: NSPasteboard.PasteboardType) -> Bool {
        if !typeOrder.contains(type) {
            typeOrder.append(type)
        }
        datas[type] = data
        return true
    }

    /// Reads the string representation for a type, when present.
    open func string(forType type: NSPasteboard.PasteboardType) -> String? {
        strings[type]
    }

    /// Reads the data representation for a type, when present.
    open func data(forType type: NSPasteboard.PasteboardType) -> Data? {
        if let data = datas[type] {
            return data
        }
        if let string = strings[type] {
            return Data(Array(string.utf8))
        }
        return nil
    }
}
