import Foundation

/// AppKit-shaped top-level window.
///
/// Frames are treated as content-area sizes. Closing the window terminates the
/// application by default (a single-window convenience for this slice; the
/// AppKit `applicationShouldTerminateAfterLastWindowClosed` policy is a later
/// parity item).
public final class NSWindow {

    /// Window style options. A subset of AppKit's, matching WinChocolate's shape.
    public struct StyleMask: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }

        public static let titled = StyleMask(rawValue: 1 << 0)
        public static let closable = StyleMask(rawValue: 1 << 1)
        public static let miniaturizable = StyleMask(rawValue: 1 << 2)
        public static let resizable = StyleMask(rawValue: 1 << 3)
        public static var borderless: StyleMask { [] }
    }

    /// AppKit backing-store compatibility placeholder (GTK manages buffering).
    public enum BackingStoreType { case retained, nonretained, buffered }

    /// Opaque backend handle for this window. Exposed for advanced/testing use.
    public let handle: NativeHandle
    let backend: NativeControlBackend

    /// The window's title-bar text.
    public var title: String {
        didSet { backend.setWindowTitle(title, for: handle) }
    }

    /// The window's content view.
    public var contentView: NSView? {
        didSet {
            guard let contentView else { return }
            backend.setContentView(contentView.handle, for: handle)
        }
    }

    /// Creates a window with the given content rect and style.
    public init(contentRect: NSRect, styleMask: StyleMask, backing: BackingStoreType, defer flag: Bool) {
        self.backend = NSApplication.shared.nativeBackend
        self.title = ""
        self.handle = backend.createWindow(title: "", frame: contentRect, styleMask: styleMask)
        backend.registerWindowCloseAction(for: handle) {
            NSApplication.shared.terminate(nil)
        }
    }

    /// Shows the window and orders it to the front.
    public func makeKeyAndOrderFront(_ sender: Any?) {
        backend.showWindow(handle)
    }
}
