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

        /// Plain text.
        public static let string = PasteboardType(rawValue: "public.utf8-plain-text")

        /// Rich Text Format data.
        public static let rtf = PasteboardType(rawValue: "public.rtf")

        /// PNG image data.
        public static let png = PasteboardType(rawValue: "public.png")

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
        return available.isEmpty ? nil : available
    }

    /// Clears the pasteboard, returning the new change count.
    @discardableResult
    open func clearContents() -> Int {
        stagedText = nil
        stagedData = [:]
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

    private func flushStagedContents() {
        NSApplication.shared.nativeBackend.setClipboardContents(text: stagedText, dataRepresentations: stagedData)
    }
}
