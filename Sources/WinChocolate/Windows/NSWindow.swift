/// A top-level application window.
///
/// `NSWindow` owns an optional content view and a backend-created native window.
/// Showing the window realizes the content hierarchy into native Windows
/// controls through `NativeControlBackend`.
open class NSWindow: NSResponder {
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
    open var contentView: NSView? {
        didSet {
            contentView?.nextResponder = self
        }
    }

    /// The backend-created native handle, if realized.
    public private(set) var nativeHandle: NativeHandle?

    /// The responder currently receiving keyboard focus in this window.
    public private(set) weak var firstResponder: NSResponder?

    /// Backend used for native work.
    public let nativeBackend: NativeControlBackend

    /// Whether this window is the application's key window.
    open var isKeyWindow: Bool {
        NSApplication.shared.keyWindow === self
    }

    /// Whether this window is the application's main window.
    open var isMainWindow: Bool {
        NSApplication.shared.mainWindow === self
    }

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
        makeMain()
        makeKey()
        nativeBackend.showWindow(handle)
    }

    /// Makes the window the key window.
    open func makeKey() {
        NSApplication.shared.makeKeyWindow(self)
    }

    /// Makes the window the main window.
    open func makeMain() {
        NSApplication.shared.makeMainWindow(self)
    }

    /// Selects the next view in the key-view loop.
    open func selectNextKeyView(_ sender: Any?) {
        guard let target = nextKeyView(after: firstResponder) else {
            return
        }

        _ = makeFirstResponder(target)
    }

    /// Selects the previous view in the key-view loop.
    open func selectPreviousKeyView(_ sender: Any?) {
        guard let target = previousKeyView(before: firstResponder) else {
            return
        }

        _ = makeFirstResponder(target)
    }

    /// Attempts to make a responder the window's first responder.
    @discardableResult
    open func makeFirstResponder(_ responder: NSResponder?) -> Bool {
        if responder === firstResponder {
            return true
        }

        if let firstResponder, !firstResponder.resignFirstResponder() {
            return false
        }

        guard let responder else {
            firstResponder = nil
            return true
        }

        guard responder.becomeFirstResponder() else {
            return false
        }

        firstResponder = responder

        if let view = responder as? NSView, let nativeHandle = view.nativeHandle {
            view.realizedBackend?.focusControl(nativeHandle)
        }

        return true
    }

    /// Closes the native window.
    open func close() {
        guard let nativeHandle else {
            return
        }

        nativeBackend.closeWindow(nativeHandle)
        self.nativeHandle = nil
        NSApplication.shared.removeWindowsItem(self)
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
        NSApplication.shared.addWindowsItem(self)
        contentView?.realizeNativePeer(in: nativeBackend, parent: handle)
        return handle
    }

    private func nextKeyView(after responder: NSResponder?) -> NSView? {
        if let view = responder as? NSView, let nextKeyView = firstFocusableNextKeyView(startingAt: view.nextKeyView) {
            return nextKeyView
        }

        return firstFocusableView(startingAt: contentView)
    }

    private func previousKeyView(before responder: NSResponder?) -> NSView? {
        if let view = responder as? NSView, let previousKeyView = firstFocusablePreviousKeyView(startingAt: view.previousKeyView) {
            return previousKeyView
        }

        return lastFocusableView(in: contentView)
    }

    private func firstFocusableNextKeyView(startingAt view: NSView?) -> NSView? {
        var visited: Set<ObjectIdentifier> = []
        var current = view

        while let candidate = current {
            let identifier = ObjectIdentifier(candidate)
            guard !visited.contains(identifier) else {
                return nil
            }

            visited.insert(identifier)

            if candidate.acceptsFirstResponder && !candidate.isHidden {
                return candidate
            }

            if let focusableChild = firstFocusableView(startingAt: candidate) {
                return focusableChild
            }

            current = candidate.nextKeyView
        }

        return nil
    }

    private func firstFocusablePreviousKeyView(startingAt view: NSView?) -> NSView? {
        var visited: Set<ObjectIdentifier> = []
        var current = view

        while let candidate = current {
            let identifier = ObjectIdentifier(candidate)
            guard !visited.contains(identifier) else {
                return nil
            }

            visited.insert(identifier)

            if candidate.acceptsFirstResponder && !candidate.isHidden {
                return candidate
            }

            if let focusableChild = lastFocusableView(in: candidate) {
                return focusableChild
            }

            current = candidate.previousKeyView
        }

        return nil
    }

    private func firstFocusableView(startingAt view: NSView?) -> NSView? {
        guard let view else {
            return nil
        }

        if view.acceptsFirstResponder && !view.isHidden {
            return view
        }

        for subview in view.subviews {
            if let focusable = firstFocusableView(startingAt: subview) {
                return focusable
            }
        }

        return nil
    }

    private func lastFocusableView(in view: NSView?) -> NSView? {
        guard let view else {
            return nil
        }

        for subview in view.subviews.reversed() {
            if let focusable = lastFocusableView(in: subview) {
                return focusable
            }
        }

        return view.acceptsFirstResponder && !view.isHidden ? view : nil
    }
}

/// AppKit-compatible backing store alias.
public typealias NSBackingStoreType = NSWindow.BackingStoreType
