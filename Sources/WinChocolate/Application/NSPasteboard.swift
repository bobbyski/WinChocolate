/// The system pasteboard.
///
/// This first slice keeps AppKit's `NSPasteboard` surface — the `general`
/// pasteboard, typed string access, `changeCount`, and the old-style
/// `declareTypes(_:owner:)` — over the platform clipboard, so copy and paste
/// interoperate with other applications. Plain text is the supported type;
/// rich text and image types are tracked work (plan item 3.17).
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
        NSApplication.shared.nativeBackend.clipboardString() != nil ? [.string] : nil
    }

    /// Clears the pasteboard, returning the new change count.
    @discardableResult
    open func clearContents() -> Int {
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

        NSApplication.shared.nativeBackend.setClipboardString(string)
        return true
    }

    /// Reads the string for a type, when present.
    open func string(forType dataType: PasteboardType) -> String? {
        guard dataType == .string else {
            return nil
        }

        return NSApplication.shared.nativeBackend.clipboardString()
    }
}
