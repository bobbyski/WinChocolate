import Foundation

/// AppKit-shaped pasteboard. `NSPasteboard.general` is the copy/paste board;
/// transient boards carry drag-and-drop payloads.
///
/// This slice models UTF-8 string (and URL-as-string) content. Writes to the
/// general board also push text to the system clipboard (`GdkClipboard`);
/// reads come from the board's own contents, so in-app copy/paste and drag
/// payloads work fully. Inbound cross-application paste (async clipboard read)
/// is a later parity item.
public final class NSPasteboard {

    /// A uniform-type identifier for pasteboard content.
    public struct PasteboardType: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let string = PasteboardType(rawValue: "public.utf8-plain-text")
        public static let URL = PasteboardType(rawValue: "public.url")
        public static let fileURL = PasteboardType(rawValue: "public.file-url")
    }

    /// The shared general pasteboard (system copy/paste).
    nonisolated(unsafe) public static let general = NSPasteboard(name: "Apple CFPasteboard general", pushesToSystem: true)

    public let name: String
    private let pushesToSystem: Bool
    private var contents: [PasteboardType: String] = [:]
    /// Bumped on every `clearContents()` — AppKit's ownership change count.
    public private(set) var changeCount: Int = 0

    init(name: String, pushesToSystem: Bool = false) {
        self.name = name
        self.pushesToSystem = pushesToSystem
    }

    /// Builds a transient board holding a single string (drag payloads).
    static func transient(string: String, type: PasteboardType = .string) -> NSPasteboard {
        let board = NSPasteboard(name: "transient")
        board.contents[type] = string
        return board
    }

    /// Clears the board and takes ownership, as in AppKit. Returns the new change count.
    @discardableResult
    public func clearContents() -> Int {
        contents.removeAll()
        changeCount += 1
        return changeCount
    }

    /// Writes a string for a type. Returns whether it was written.
    @discardableResult
    public func setString(_ string: String, forType type: PasteboardType) -> Bool {
        contents[type] = string
        if pushesToSystem && type == .string {
            NSApplication.shared.nativeBackend.setClipboardString(string)
        }
        return true
    }

    /// Reads the string for a type, or nil if the board holds none.
    public func string(forType type: PasteboardType) -> String? {
        contents[type]
    }

    /// The types currently present on the board.
    public var types: [PasteboardType] {
        Array(contents.keys)
    }
}
