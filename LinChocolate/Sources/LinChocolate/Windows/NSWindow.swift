import Foundation

/// AppKit-shaped top-level window.
///
/// Frames are treated as content-area sizes. Closing a window closes THAT
/// window, as on Apple; the application terminates when the last visible
/// window closes (GTK has no menu-bar-only mode, so Apple's
/// delegate-driven stay-alive policy has nothing to keep alive — documented
/// divergence until `applicationShouldTerminateAfterLastWindowClosed` lands).
open class NSWindow {

    /// Window style options. A subset of AppKit's, matching WinChocolate's shape.
    public struct StyleMask: OptionSet, Sendable {
        /// The raw bit-mask value.
        public let rawValue: UInt
        /// Creates a style mask from raw bits.
        public init(rawValue: UInt) { self.rawValue = rawValue }

        /// The window has a title bar.
        public static let titled = StyleMask(rawValue: 1 << 0)
        /// The window has a close control.
        public static let closable = StyleMask(rawValue: 1 << 1)
        /// The window has a minimize control.
        public static let miniaturizable = StyleMask(rawValue: 1 << 2)
        /// The window is resizable.
        public static let resizable = StyleMask(rawValue: 1 << 3)
        /// A borderless window (no chrome).
        public static var borderless: StyleMask { [] }
    }

    /// AppKit backing-store compatibility placeholder (GTK manages buffering).
    public enum BackingStoreType {
        /// AppKit's retained backing store.
        case retained
        /// AppKit's non-retained backing store.
        case nonretained
        /// AppKit's buffered backing store (the default).
        case buffered
    }

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

    /// Delegate + content-size constraints + key-view root (accepted for parity).
    public weak var delegate: NSWindowDelegate?
    /// The minimum size of the content area (accepted for parity).
    public var contentMinSize: NSSize = .zero
    /// The maximum size of the content area (accepted for parity).
    public var contentMaxSize: NSSize = NSMakeSize(100000, 100000)
    /// The view that becomes first responder when the window is shown.
    public weak var initialFirstResponder: NSView?

    /// Whether the window is on screen (AppKit's `isVisible`).
    public private(set) var isVisible = false

    /// Creates a window with the given content rect and style.
    public init(contentRect: NSRect, styleMask: StyleMask, backing: BackingStoreType, defer flag: Bool) {
        self.backend = NSApplication.shared.nativeBackend
        self.title = ""
        self.handle = backend.createWindow(title: "", frame: contentRect, styleMask: styleMask)
        backend.registerWindowCloseAction(for: handle) { [weak self] in
            // The title-bar close button — AppKit routes it through
            // `performClose`.
            self?.performClose(nil)
        }
        NSApplication.shared.windows.append(self)
        NSApplication.shared.installMainMenuIfNeeded(on: self)
    }

    /// Shows the window and orders it to the front.
    public func makeKeyAndOrderFront(_ sender: Any?) {
        contentView?.layoutSubtreeIfNeeded()
        isVisible = true
        backend.showWindow(handle)
    }

    /// Closes the window (AppKit's `close()`): orders it out. The native
    /// window survives — under ARC an NSWindow the app still references can be
    /// re-presented with `makeKeyAndOrderFront`/`orderFrontRegardless`, which
    /// is exactly what the demo's reusable inspector panel does.
    public func close() {
        isVisible = false
        backend.hideWindow(handle)
    }

    /// Removes the window from the screen without closing it (AppKit's
    /// `orderOut(_:)`).
    public func orderOut(_ sender: Any?) {
        isVisible = false
        backend.hideWindow(handle)
    }

    /// Simulates the user clicking the close button (AppKit's `performClose`) —
    /// the title-bar X routes through here. Apple: closing a window closes THAT
    /// window; a floating panel's X must not take the application down (it used
    /// to call `terminate` outright, and GTK then destroyed the window, so
    /// re-opening the demo's reused panel crashed).
    ///
    /// Apple keeps an app alive at zero windows (menu-bar-only, per
    /// `applicationShouldTerminateAfterLastWindowClosed`). GTK has no
    /// menu-bar-only mode — in-window menus die with the last window — so the
    /// last VISIBLE window closing quits, matching every desktop Linux app.
    /// Documented divergence until the delegate policy lands.
    public func performClose(_ sender: Any?) {
        close()
        if !NSApplication.shared.windows.contains(where: { $0.isVisible }) {
            NSApplication.shared.terminate(nil)
        }
    }

    /// Resizes the window's content area.
    public func setContentSize(_ size: NSSize) {
        backend.setFrame(NSMakeRect(0, 0, size.width, size.height), for: handle)
    }

    /// The window's toolbar (the deliberate Apple-look exception). Assigning
    /// docks it under the menu bar.
    public var toolbar: NSToolbar? {
        didSet {
            toolbar?.window = self
            reinstallToolbar()
        }
    }

    /// Rebuilds the native toolbar from the current items.
    func reinstallToolbar() {
        guard let toolbar else { return }
        backend.installToolbar(toolbar.specs(), displayMode: toolbar.nativeDisplayMode, on: handle)
    }
}
