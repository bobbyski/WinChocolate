import Foundation

/// AppKit modal responses for panels.
public let NSModalResponseOK = 1
public let NSModalResponseCancel = 0

/// AppKit-shaped save panel (GtkFileDialog, save mode). Configure, call
/// `runModal()` (blocks), then read `url`.
public class NSSavePanel {

    /// Directory the panel starts in.
    public var directoryURL: URL?

    /// Suggested file name shown in the name field.
    public var nameFieldStringValue = ""

    /// The chosen destination after `runModal` returns OK.
    public private(set) var url: URL?

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

    public var canChooseFiles = true
    public var canChooseDirectories = false
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
