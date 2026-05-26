/// A top-level application window.
///
/// `NSWindow` owns an optional content view and a backend-created native window.
/// Showing the window realizes the content hierarchy into native Windows
/// controls through `NativeControlBackend`.
open class NSWindow: NSObject {
    /// Window style options matching AppKit names.
    public struct StyleMask: OptionSet, Sendable {
        /// Raw option value.
        public let rawValue: UInt

        /// Creates a style mask from a raw value.
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// Titled window style.
        public static let titled = StyleMask(rawValue: 1 << 0)

        /// Closable window style.
        public static let closable = StyleMask(rawValue: 1 << 1)

        /// Miniaturizable window style.
        public static let miniaturizable = StyleMask(rawValue: 1 << 2)

        /// Resizable window style.
        public static let resizable = StyleMask(rawValue: 1 << 3)
    }

    /// Window backing store strategy.
    public enum BackingStoreType: Sendable {
        /// Buffered backing store.
        case buffered
    }

    /// The window frame rectangle.
    open var frame: NSRect

    /// The window title.
    open var title: String = "" {
        didSet {
            guard let nativeHandle else {
                return
            }

            nativeBackend.setText(title, for: nativeHandle)
        }
    }

    /// The window style mask.
    public let styleMask: StyleMask

    /// The window backing store type.
    public let backingType: BackingStoreType

    /// Whether native creation should be deferred until first display.
    public let isDeferred: Bool

    /// The root content view.
    open var contentView: NSView?

    /// The backend-created native handle, if realized.
    public private(set) var nativeHandle: NativeHandle?

    /// Backend used for native work.
    public let nativeBackend: NativeControlBackend

    /// Creates a window using AppKit's designated initializer shape.
    public init(
        contentRect: NSRect,
        styleMask style: StyleMask,
        backing backingStoreType: BackingStoreType,
        defer flag: Bool
    ) {
        self.frame = contentRect
        self.styleMask = style
        self.backingType = backingStoreType
        self.isDeferred = flag
        self.nativeBackend = NSApplication.shared.nativeBackend
        super.init()
    }

    /// Creates a window using an explicit backend.
    public init(
        contentRect: NSRect,
        styleMask style: StyleMask,
        backing backingStoreType: BackingStoreType,
        defer flag: Bool,
        nativeBackend: NativeControlBackend
    ) {
        self.frame = contentRect
        self.styleMask = style
        self.backingType = backingStoreType
        self.isDeferred = flag
        self.nativeBackend = nativeBackend
        super.init()
    }

    /// Shows the window and makes it the key window.
    open func makeKeyAndOrderFront(_ sender: Any?) {
        let handle = realizeNativePeer()
        nativeBackend.showWindow(handle)
    }

    /// Closes the native window.
    open func close() {
        guard let nativeHandle else {
            return
        }

        nativeBackend.closeWindow(nativeHandle)
        self.nativeHandle = nil
    }

    /// Sets the window frame and optionally requests display.
    open func setFrame(_ frameRect: NSRect, display flag: Bool) {
        frame = frameRect

        guard let nativeHandle else {
            return
        }

        nativeBackend.setFrame(frameRect, for: nativeHandle)
    }

    /// Ensures the window and content hierarchy have native peers.
    @discardableResult
    open func realizeNativePeer() -> NativeHandle {
        if let nativeHandle {
            return nativeHandle
        }

        let handle = nativeBackend.createWindow(title: title, frame: frame, styleMask: styleMask)
        nativeHandle = handle
        contentView?.realizeNativePeer(in: nativeBackend, parent: handle)
        return handle
    }
}

/// AppKit-compatible backing store alias.
public typealias NSBackingStoreType = NSWindow.BackingStoreType
