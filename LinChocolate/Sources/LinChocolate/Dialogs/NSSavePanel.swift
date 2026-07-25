import Foundation

/// AppKit modal responses for panels.
/// The user confirmed the panel (clicked Save/Open).
public let NSModalResponseOK = 1
/// The user cancelled the panel.
public let NSModalResponseCancel = 0

/// AppKit-shaped save panel (GtkFileDialog, save mode). Configure, call
/// `runModal()` (blocks), then read `url`.
public class NSSavePanel {

    /// Directory the panel starts in.
    public var directoryURL: URL?
    /// The panel's title (accepted for parity).
    public var title: String = ""

    /// Suggested file name shown in the name field.
    public var nameFieldStringValue = ""

    /// The chosen destination after `runModal` returns OK.
    public private(set) var url: URL?

    /// Creates an unconfigured save panel.
    public init() {}

    func setResult(path: String?) {
        url = path.map { URL(fileURLWithPath: $0) }
    }

    /// Shows the panel modally; returns `NSModalResponseOK` or `…Cancel`.
    @discardableResult
    public func runModal() -> Int {
        let path = NSApplication.shared.nativeBackend.runSavePanel(
            directory: directoryURL?.path,
            suggestedName: nameFieldStringValue.isEmpty ? nil : nameFieldStringValue,
            for: NSApplication.shared.windows.first?.handle
        )
        setResult(path: path)
        return url != nil ? NSModalResponseOK : NSModalResponseCancel
    }
}

/// AppKit-shaped open panel. Single file selection in this slice
/// (`canChooseFiles`/`allowsMultipleSelection` are accepted but the native
/// dialog currently opens one file).
public final class NSOpenPanel: NSSavePanel {

    /// Whether files may be selected (accepted for parity).
    public var canChooseFiles = true
    /// Whether directories may be selected (accepted for parity).
    public var canChooseDirectories = false
    /// Whether multiple items may be selected (accepted for parity; the native
    /// dialog currently opens one file).
    public var allowsMultipleSelection = false

    /// The chosen files after `runModal` returns OK.
    public private(set) var urls: [URL] = []

    /// Shows the panel modally; returns `NSModalResponseOK` or `…Cancel`.
    @discardableResult
    public override func runModal() -> Int {
        let path = NSApplication.shared.nativeBackend.runOpenPanel(
            directory: directoryURL?.path,
            for: NSApplication.shared.windows.first?.handle
        )
        setResult(path: path)
        urls = url.map { [$0] } ?? []
        return url != nil ? NSModalResponseOK : NSModalResponseCancel
    }
}
