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

        /// Borderless window style.
        public static var borderless: StyleMask { [] }

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

    /// Relative ordering used when inserting views.
    public enum OrderingMode: Sendable {
        /// Place above the reference object.
        case above

        /// Place below the reference object.
        case below

        /// Remove from ordering.
        case out
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
            layoutToolbarAndContent()
        }
    }

    /// The toolbar attached to this window.
    open var toolbar: NSToolbar? {
        didSet {
            oldValue?.attach(to: nil)
            toolbar?.attach(to: self)
            installToolbarHost()
            layoutToolbarAndContent()
        }
    }

    /// Height reserved for the window-owned toolbar strip.
    open var toolbarHeight: CGFloat = NSToolbarView.preferredHeight(for: nil) {
        didSet {
            if !isUpdatingToolbarHeight {
                usesAutomaticToolbarHeight = false
            }
            layoutToolbarAndContent()
        }
    }

    /// The backend-created native handle, if realized.
    public private(set) var nativeHandle: NativeHandle?

    /// The responder currently receiving keyboard focus in this window.
    public private(set) weak var firstResponder: NSResponder?

    /// Rebuilds a view's cursor rectangles and pushes them to its native peer.
    open func invalidateCursorRects(for view: NSView) {
        view.updateCursorRegions()
    }

    /// Gives the window's view hierarchy a chance to consume a key equivalent.
    open func performKeyEquivalent(with event: NSEvent) -> Bool {
        contentView?.performKeyEquivalent(with: event) ?? false
    }

    private var storedUndoManager: NSUndoManager?

    /// The undo manager shared by this window's views.
    ///
    /// Created lazily on first access, matching how AppKit windows vend an
    /// undo manager when nothing more specific provides one.
    open var undoManager: NSUndoManager? {
        if storedUndoManager == nil {
            storedUndoManager = NSUndoManager()
        }
        return storedUndoManager
    }

    /// Backend used for native work.
    public let nativeBackend: NativeControlBackend

    private var toolbarHostView: NSToolbarView?
    private var usesAutomaticToolbarHeight = true
    private var isUpdatingToolbarHeight = false

    /// Whether this window is the application's key window.
    open var isKeyWindow: Bool {
        NSApplication.shared.keyWindow === self
    }

    /// Whether this window is the application's main window.
    open var isMainWindow: Bool {
        NSApplication.shared.mainWindow === self
    }

    /// The rectangle available for content in window coordinates.
    open var contentLayoutRect: NSRect {
        let reservedHeight = toolbar?.isVisible == true ? resolvedToolbarHeight : 0
        return NSRect(
            x: 0,
            y: reservedHeight,
            width: frame.size.width,
            height: max(0, frame.size.height - reservedHeight)
        )
    }

    /// Whether this top-level window should receive the application's menu bar.
    open var usesMainMenu: Bool {
        true
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

    /// Presents a window as a sheet attached to this window.
    ///
    /// The classic backend runs sheets as application-modal sessions
    /// positioned under this window's title area; the handler receives the
    /// code passed to `endSheet(_:returnCode:)`. Window-modal sheets with
    /// slide animation arrive with the modern appearance.
    open func beginSheet(_ sheetWindow: NSWindow, completionHandler handler: ((NSApplication.ModalResponse) -> Void)? = nil) {
        let sheetSize = sheetWindow.frame.size
        let origin = NSMakePoint(
            frame.origin.x + max((frame.size.width - sheetSize.width) / 2, 0),
            frame.origin.y + 56
        )
        sheetWindow.setFrame(NSRect(origin: origin, size: sheetSize), display: true)
        let response = NSApplication.shared.runModal(for: sheetWindow)
        handler?(response)
    }

    /// Ends a sheet session presented with `beginSheet(_:completionHandler:)`.
    open func endSheet(_ sheetWindow: NSWindow, returnCode: NSApplication.ModalResponse = .OK) {
        NSApplication.shared.stopModal(withCode: returnCode)
        sheetWindow.close()
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
        toolbarHostView?.destroyNativePeer()
        toolbarHostView = nil
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
        layoutToolbarAndContent()
    }

    /// Sets the window content size while preserving its origin.
    open func setContentSize(_ size: NSSize) {
        let reservedHeight = toolbar?.isVisible == true ? resolvedToolbarHeight : 0
        setFrame(NSRect(origin: frame.origin, size: NSSize(width: size.width, height: size.height + reservedHeight)), display: true)
        layoutToolbarAndContent()
    }

    /// Centers the window in a conservative default desktop area.
    open func center() {
        let defaultScreen = NSRect(x: 0, y: 0, width: 1024, height: 768)
        let origin = NSPoint(
            x: NSMidX(defaultScreen) - frame.size.width / 2,
            y: NSMidY(defaultScreen) - frame.size.height / 2
        )
        setFrame(NSRect(origin: origin, size: frame.size), display: true)
    }

    /// Ensures the window and content hierarchy have native peers.
    @discardableResult
    open func realizeNativePeer() -> NativeHandle {
        if let nativeHandle {
            return nativeHandle
        }

        let handle = nativeBackend.createWindow(title: title, frame: frame, styleMask: styleMask, usesMainMenu: usesMainMenu)
        nativeHandle = handle
        nativeBackend.registerWindowCloseAction(for: handle) { [weak self] in
            self?.nativeWindowDidClose()
        }
        nativeBackend.registerWindowResizeAction(for: handle) { [weak self] size in
            self?.nativeWindowDidResize(to: size)
        }
        NSApplication.shared.addWindowsItem(self)
        installToolbarHost()
        layoutToolbarAndContent()
        contentView?.realizeNativePeer(in: nativeBackend, parent: handle)
        return handle
    }

    private func nativeWindowDidClose() {
        toolbarHostView?.destroyNativePeer()
        toolbarHostView = nil
        nativeHandle = nil
        NSApplication.shared.removeWindowsItem(self)
    }

    private func nativeWindowDidResize(to size: NSSize) {
        frame = NSRect(origin: frame.origin, size: size)
        layoutToolbarAndContent()
    }

    private func installToolbarHost() {
        guard let toolbar else {
            toolbarHostView?.destroyNativePeer()
            toolbarHostView = nil
            return
        }

        syncAutomaticToolbarHeight()

        let host = toolbarHostView ?? NSToolbarView(frame: NSMakeRect(0, 0, frame.size.width, resolvedToolbarHeight))
        toolbarHostView = host
        host.nextResponder = self
        host.toolbar = toolbar
        host.visibilityChanged = { [weak self] _ in
            self?.layoutToolbarAndContent()
        }
        host.preferredHeightChanged = { [weak self] _ in
            self?.syncAutomaticToolbarHeight()
            self?.layoutToolbarAndContent()
        }

        if let nativeHandle, host.nativeHandle == nil {
            host.realizeNativePeer(in: nativeBackend, parent: nativeHandle)
        }
    }

    private func layoutToolbarAndContent() {
        syncAutomaticToolbarHeight()

        if let toolbarHostView {
            toolbarHostView.frame = NSMakeRect(0, 0, frame.size.width, resolvedToolbarHeight)
            if let handle = toolbarHostView.nativeHandle {
                nativeBackend.setFrame(toolbarHostView.frame, for: handle)
                toolbarHostView.reloadItems()
            }
        }

        guard let contentView else {
            return
        }

        contentView.frame = contentLayoutRect
        if let handle = contentView.nativeHandle {
            nativeBackend.setFrame(contentView.frame, for: handle)
        }
    }

    private var resolvedToolbarHeight: CGFloat {
        if usesAutomaticToolbarHeight {
            return NSToolbarView.preferredHeight(for: toolbar)
        }

        return toolbarHeight
    }

    private func syncAutomaticToolbarHeight() {
        guard usesAutomaticToolbarHeight else {
            return
        }

        let preferredHeight = NSToolbarView.preferredHeight(for: toolbar)
        guard toolbarHeight != preferredHeight else {
            return
        }

        isUpdatingToolbarHeight = true
        toolbarHeight = preferredHeight
        isUpdatingToolbarHeight = false
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

            if candidate.acceptsFirstResponder && !isHiddenInHierarchy(candidate) {
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

            if candidate.acceptsFirstResponder && !isHiddenInHierarchy(candidate) {
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

        if isHiddenInHierarchy(view) {
            return nil
        }

        if view.acceptsFirstResponder {
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

        if isHiddenInHierarchy(view) {
            return nil
        }

        for subview in view.subviews.reversed() {
            if let focusable = lastFocusableView(in: subview) {
                return focusable
            }
        }

        return view.acceptsFirstResponder ? view : nil
    }

    private func isHiddenInHierarchy(_ view: NSView) -> Bool {
        var current: NSView? = view
        while let candidate = current {
            if candidate.isHidden {
                return true
            }
            current = candidate.superview
        }
        return false
    }
}

/// AppKit-compatible backing store alias.
public typealias NSBackingStoreType = NSWindow.BackingStoreType
