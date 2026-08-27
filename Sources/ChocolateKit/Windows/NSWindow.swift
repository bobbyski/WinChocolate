/// The methods a window delegate uses to participate in window lifecycle.
public protocol NSWindowDelegate: NSObjectProtocol {
    /// Returns whether the window may close; false vetoes a title-bar close.
    func windowShouldClose(_ sender: NSWindow) -> Bool

    /// Tells the delegate the window is closing.
    func windowWillClose(_ notification: Notification)

    /// Tells the delegate the window was resized (by the user or the system).
    func windowDidResize(_ notification: Notification)

    /// Tells the delegate the window was moved.
    func windowDidMove(_ notification: Notification)

    /// Tells the delegate the window was minimized.
    func windowDidMiniaturize(_ notification: Notification)

    /// Tells the delegate the window was restored from the minimized state.
    func windowDidDeminiaturize(_ notification: Notification)

    /// Tells the delegate the window is about to enter full screen.
    func windowWillEnterFullScreen(_ notification: Notification)

    /// Tells the delegate the window has entered full screen.
    func windowDidEnterFullScreen(_ notification: Notification)

    /// Tells the delegate the window is about to exit full screen.
    func windowWillExitFullScreen(_ notification: Notification)

    /// Tells the delegate the window has exited full screen.
    func windowDidExitFullScreen(_ notification: Notification)
}

extension NSWindowDelegate {
    /// Default: windows may always close.
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        true
    }

    /// Default no-op so delegates only implement the callbacks they need.
    public func windowWillClose(_ notification: Notification) {}

    /// Default no-op so delegates only implement the callbacks they need.
    public func windowDidResize(_ notification: Notification) {}

    /// Default no-op so delegates only implement the callbacks they need.
    public func windowDidMove(_ notification: Notification) {}

    /// Default no-op so delegates only implement the callbacks they need.
    public func windowDidMiniaturize(_ notification: Notification) {}

    /// Default no-op so delegates only implement the callbacks they need.
    public func windowDidDeminiaturize(_ notification: Notification) {}

    /// Default no-op so delegates only implement the callbacks they need.
    public func windowWillEnterFullScreen(_ notification: Notification) {}

    /// Default no-op so delegates only implement the callbacks they need.
    public func windowDidEnterFullScreen(_ notification: Notification) {}

    /// Default no-op so delegates only implement the callbacks they need.
    public func windowWillExitFullScreen(_ notification: Notification) {}

    /// Default no-op so delegates only implement the callbacks they need.
    public func windowDidExitFullScreen(_ notification: Notification) {}
}

/// A top-level application window.
///
/// `NSWindow` owns an optional content view and a backend-created native window.
/// Showing the window realizes the content hierarchy into native Windows
/// controls through `NativeControlBackend`.
open class NSWindow: NSResponder {
    /// Whether closing releases the window (AppKit memory management).
    /// Stored for source compatibility — Swift/ARC owns WinChocolate
    /// windows, so the flag changes nothing here.
    open var isReleasedWhenClosed: Bool = true

    /// The window frame rectangle.
    open var frame: NSRect

    /// The autosave name, empty when the window does not autosave its frame.
    /// See `NSWindowFrameAutosave.swift`.
    internal var winFrameAutosaveName: String = ""

    /// True while a saved frame is being applied, so the restore does not
    /// immediately save what it just read.
    internal var winIsRestoringFrame = false

    /// The window title.
    open var title: String = "" {
        didSet {
            applyTitleVisibility()
        }
    }

    /// A secondary line shown under, or beside, the title.
    ///
    /// AppKit draws it small and dimmed next to the caption. Where the native
    /// title bar has one caption and no second line, it is appended to the
    /// title as ` — subtitle`, which is what the window would look like on
    /// macOS anyway once the two are read together.
    open var subtitle: String = "" {
        didSet {
            applyTitleVisibility()
        }
    }

    /// Whether the title text is shown in the title bar.
    ///
    /// Hiding the title keeps the title bar and its buttons but blanks the
    /// caption text, matching AppKit windows that show only a toolbar.
    open var titleVisibility: TitleVisibility = .visible {
        didSet {
            applyTitleVisibility()
        }
    }

    /// Whether the title bar blends into the content (drawn transparent).
    ///
    /// Stored for source compatibility; the transparent-titlebar appearance is
    /// applied with the window-appearance work.
    open var titlebarAppearsTransparent: Bool = false

    /// The window's appearance override; `nil` inherits the application's
    /// effective appearance (see `effectiveAppearance` in NSAppearance.swift).
    open var appearance: NSAppearance?

    internal var standardButtons: [ButtonType: NSButton] = [:]

    /// The style mask the window was created with (without the transient
    /// full-screen flag).
    internal let baseStyleMask: StyleMask

    /// The window style mask. Reports `.fullScreen` while in full-screen mode,
    /// matching AppKit (the base mask is preserved for restore).
    open var styleMask: StyleMask {
        winIsFullScreen ? baseStyleMask.union(.fullScreen) : baseStyleMask
    }

    /// Whether the window currently occupies the full screen.
    open private(set) var isFullScreen: Bool {
        get { winIsFullScreen }
        set { winIsFullScreen = newValue }
    }

    internal var winIsFullScreen = false

    /// How the window participates in full screen. Stored for API fidelity; on
    /// Windows only the presence of `.fullScreenPrimary`/`.fullScreenAuxiliary`
    /// (i.e. not `.fullScreenNone`) gates whether `toggleFullScreen` acts.
    open var collectionBehavior: CollectionBehavior = []

    /// The window's z-ordering level.
    ///
    /// Levels above `.normal` keep the window floating over the
    /// application's normal windows.
    open var level: Level = .normal {
        didSet {
            guard level != oldValue, let nativeHandle else {
                return
            }

            nativeBackend.setWindowLevel(level, for: nativeHandle)
        }
    }

    /// The window backing store type.
    public let backingType: BackingStoreType

    /// The minimum content size the user may resize the window to.
    ///
    /// Zero (the default) means unconstrained. Takes precedence over
    /// `minSize` when both are set.
    open var contentMinSize: NSSize = NSMakeSize(0, 0) {
        didSet {
            applySizeLimits()
        }
    }

    /// The maximum content size the user may resize the window to.
    open var contentMaxSize: NSSize = NSMakeSize(0, 0) {
        didSet {
            applySizeLimits()
        }
    }

    /// The minimum window frame size.
    ///
    /// The classic backend applies this as a content-size limit (a small
    /// title/border approximation); `contentMinSize` is exact.
    open var minSize: NSSize = NSMakeSize(0, 0) {
        didSet {
            applySizeLimits()
        }
    }

    /// The maximum window frame size.
    open var maxSize: NSSize = NSMakeSize(0, 0) {
        didSet {
            applySizeLimits()
        }
    }

    /// Whether the user can drag the window by clicking its background.
    ///
    /// Clicks that land on a control still act on the control; only clicks on
    /// the empty content area start a window move.
    open var isMovableByWindowBackground: Bool = false {
        didSet {
            applyMovableByWindowBackground()
        }
    }

    /// Whether native creation should be deferred until first display.
    public let isDeferred: Bool

    /// The root content view.
    open var contentView: NSView? {
        didSet {
            contentView?.nextResponder = self
            layoutToolbarAndContent()
            applyMovableByWindowBackground()
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

    /// Toggles the toolbar's visibility, matching AppKit's
    /// `toggleToolbarShown(_:)` (the View menu's Show/Hide Toolbar action).
    open func toggleToolbarShown(_ sender: Any?) {
        toolbar?.isVisible.toggle()
    }

    /// Opens the toolbar customization palette, matching AppKit's
    /// `runToolbarCustomizationPalette(_:)`.
    open func runToolbarCustomizationPalette(_ sender: Any?) {
        toolbar?.runCustomizationPalette(sender)
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
    public internal(set) var nativeHandle: NativeHandle?

    /// The responder currently receiving keyboard focus in this window.
    public internal(set) weak var firstResponder: NSResponder? {
        didSet {
            if firstResponder !== oldValue {
                onFirstResponderChange?(self)
            }
        }
    }

    /// Swift-native callback invoked after the first responder changes —
    /// the observation surface AppKit consumers get from KVO, which has no
    /// ObjC-runtime equivalent here.
    open var onFirstResponderChange: ((NSWindow) -> Void)?

    /// The window delegate, consulted for close decisions and lifecycle.
    open weak var delegate: NSWindowDelegate?

    /// Rebuilds a view's cursor rectangles and pushes them to its native peer.
    open func invalidateCursorRects(for view: NSView) {
        view.updateCursorRegions()
    }

    /// Gives the window's view hierarchy a chance to consume a key equivalent.
    open func performKeyEquivalent(with event: NSEvent) -> Bool {
        contentView?.performKeyEquivalent(with: event) ?? false
    }

    internal var storedUndoManager: NSUndoManager?

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

    internal var toolbarHostView: NSToolbarView?
    internal var usesAutomaticToolbarHeight = true
    internal var isUpdatingToolbarHeight = false

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

    /// The sheet currently attached to this window, if any (AppKit's
    /// `attachedSheet`). While a sheet is attached, additional `beginSheet`
    /// calls queue behind it.
    open internal(set) var attachedSheet: NSWindow?

    /// The window this window is a sheet of, if any (AppKit's `sheetParent`).
    open internal(set) weak var sheetParent: NSWindow?

    // Sheets requested while another sheet is attached, presented FIFO as each
    // preceding sheet ends — matching AppKit's sheet queue.
    internal var winQueuedSheets: [(NSWindow, ((NSApplication.ModalResponse) -> Void)?)] = []

    /// Creates a window using AppKit's designated initializer shape.
    public init(
        contentRect: NSRect,
        styleMask style: StyleMask,
        backing backingStoreType: BackingStoreType,
        defer flag: Bool
    ) {
        self.frame = contentRect
        self.baseStyleMask = style
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
        self.baseStyleMask = style
        self.backingType = backingStoreType
        self.isDeferred = flag
        self.nativeBackend = nativeBackend
        super.init()
    }

/// Whether the window can become the key window.
    open var canBecomeKey: Bool {
        true
    }

    /// Whether the window can become the application's main window.
    open var canBecomeMain: Bool {
        true
    }

    /// Shows the window and makes it the key window.
    open func makeKeyAndOrderFront(_ sender: Any?) {
        let handle = realizeNativePeer()
        makeMain()
        makeKey()
        nativeBackend.showWindow(handle)
    }

    /// Shows the window without changing the key window.
    open func orderFront(_ sender: Any?) {
        let handle = realizeNativePeer()
        nativeBackend.showWindow(handle)
    }

    /// Hides the window without closing it.
    open func orderOut(_ sender: Any?) {
        guard let nativeHandle else {
            return
        }

        if isKeyWindow {
            NSApplication.shared.mainWindow?.makeKey()
        }
        nativeBackend.setHidden(true, for: nativeHandle)
    }



    /// The vertical inset from this window's top at which an attached sheet
    /// hangs: the title area, plus the toolbar strip when a visible toolbar is
    /// docked, so the sheet drops below the toolbar rather than under the bare
    /// title bar (the positioning owned here, moved from 6.2).
    open var winSheetTopInset: CGFloat {
        var inset: CGFloat = 56
        if let toolbar, toolbar.isVisible {
            inset += toolbarHeight
        }
        return inset
    }

    /// The origin at which a sheet of the given size attaches: horizontally
    /// centered, dropped below the title area (and toolbar, if any).
    open func winSheetOrigin(for sheetSize: NSSize) -> NSPoint {
        NSMakePoint(
            frame.origin.x + max((frame.size.width - sheetSize.width) / 2, 0),
            frame.origin.y + winSheetTopInset
        )
    }

    /// Presents a window as a sheet attached to this window.
    ///
    /// The sheet attaches below the title area (and any docked toolbar), links
    /// to this window through `sheetParent`/`attachedSheet`, and runs a modal
    /// session that blocks this window; the handler receives the code passed to
    /// `endSheet(_:returnCode:)`. A second `beginSheet` while a sheet is
    /// attached queues behind it. Slide animation and parent dimming arrive
    /// with the modern appearance.
    open func beginSheet(_ sheetWindow: NSWindow, completionHandler handler: ((NSApplication.ModalResponse) -> Void)? = nil) {
        // A sheet is already up — queue this one behind it.
        if attachedSheet != nil {
            winQueuedSheets.append((sheetWindow, handler))
            return
        }
        winPresentSheet(sheetWindow, completionHandler: handler)
    }

    /// Ends a sheet session presented with `beginSheet(_:completionHandler:)`,
    /// unlinks it, and presents the next queued sheet if one is waiting.
    open func endSheet(_ sheetWindow: NSWindow, returnCode: NSApplication.ModalResponse = .OK) {
        winEndSheet(sheetWindow, returnCode: returnCode)
    }

    /// Makes the window the key window.
    open func makeKey() {
        guard canBecomeKey else {
            return
        }

        NSApplication.shared.makeKeyWindow(self)
    }

    /// Makes the window the main window.
    open func makeMain() {
        guard canBecomeMain else {
            return
        }

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
        return winMakeFirstResponder(responder)
    }

    /// Closes the native window.
    open func close() {
        winClose()
    }

/// Sets the window frame and optionally requests display.
    open func setFrame(_ frameRect: NSRect, display flag: Bool) {
        frame = frameRect

        guard let nativeHandle else {
            return
        }

        nativeBackend.setFrame(frameRect, for: nativeHandle)
        layoutToolbarAndContent()
        winAutosaveFrameIfNeeded()
    }

    /// Runs a tracking loop, handing each matching event to the handler until
    /// it sets `stop` or the timeout expires.
    ///
    /// AppKit re-enters the event loop here and does not return until the
    /// session ends. Whether that is possible depends on the backend, so this
    /// asks: `beginEventTracking` either takes the session or declines it
    /// (`Docs/EVENT_TRACKING.md`).
    ///
    /// **Where a backend tracks asynchronously — a browser cannot block — this
    /// returns before the session ends.** That is a real difference from
    /// AppKit and callers that read state set inside the handler must handle
    /// it. The tell is cheap and needs no new API: set a flag in the handler's
    /// terminal branch, and if it is still clear when this returns, the session
    /// is still running.
    ///
    /// Where no backend takes it, the handler is called once with `nil` — the
    /// "no more events" signal AppKit gives at timeout, which every correct
    /// caller already handles by stopping — and the reason is logged once.
    open func trackEvents(
        matching mask: NSEvent.EventTypeMask,
        timeout: TimeInterval,
        mode: RunLoop.Mode,
        using trackingHandler: @escaping (NSEvent?, UnsafeMutablePointer<ObjCBool>) -> Void
    ) {
        // The handler AppKit hands its caller writes through a pointer; the
        // backend's answers with a value. One translation, here, so no backend
        // has to know about `ObjCBool` and no caller has to stop using it.
        let adapt: (NSEvent?) -> NativeEventTrackingDisposition = { [weak self] event in
            var stamped = event
            if let self, stamped != nil {
                // The event's own window is what turns `locationInWindow` into
                // a screen point. The backend does not know which `NSWindow`
                // its handle belongs to; this object does, and it is the one
                // that asked for the session.
                stamped?.window = self
                NSEvent.mouseLocation = self.convertPoint(toScreen: stamped!.locationInWindow)
            }
            var stop = ObjCBool(false)
            withUnsafeMutablePointer(to: &stop) { trackingHandler(stamped, $0) }
            return stop.boolValue ? .stop : .continue
        }

        if let nativeHandle,
           nativeBackend.beginEventTracking(matching: mask, for: nativeHandle, handler: adapt) {
            return
        }

        chocolateBackendWarn("NSWindow.trackEvents: this backend has no event-tracking session, "
                             + "so the loop ends immediately. Drag-tracking written against it "
                             + "will not follow the pointer. See Docs/EVENT_TRACKING.md.")
        _ = adapt(nil)
    }

    /// Attaches a controller's view above or below the titlebar.
    ///
    /// Held rather than shown: no Chocolate backend draws content inside its
    /// window chrome, so the accessory has nowhere to go. It is kept so a
    /// window that configures one keeps the configuration, and so removing it
    /// works — a window that silently discarded accessories would make
    /// `remove` a crash waiting to happen.
    open func addTitlebarAccessoryViewController(_ controller: NSTitlebarAccessoryViewController) {
        winTitlebarAccessories.append(controller)
        chocolateBackendWarn("NSWindow.addTitlebarAccessoryViewController: no titlebar content area on this backend.")
    }

    /// Removes a titlebar accessory by index.
    open func removeTitlebarAccessoryViewController(at index: Int) {
        guard winTitlebarAccessories.indices.contains(index) else { return }
        winTitlebarAccessories.remove(at: index)
    }

    /// The accessories attached to the titlebar.
    open var titlebarAccessoryViewControllers: [NSTitlebarAccessoryViewController] {
        get { winTitlebarAccessories }
        set { winTitlebarAccessories = newValue }
    }

    /// Backing storage for the titlebar accessories.
    private var winTitlebarAccessories: [NSTitlebarAccessoryViewController] = []

    /// Converts a point in this window's coordinates to screen coordinates.
    ///
    /// A window's frame is already in screen space, so this is a translation by
    /// its origin — the same arithmetic AppKit does, and the reason drag code
    /// asks the *event's* window rather than the pointer where something is.
    open func convertPoint(toScreen point: NSPoint) -> NSPoint {
        NSMakePoint(frame.origin.x + point.x, frame.origin.y + point.y)
    }

    /// Converts a point in screen coordinates to this window's coordinates.
    open func convertPoint(fromScreen point: NSPoint) -> NSPoint {
        NSMakePoint(point.x - frame.origin.x, point.y - frame.origin.y)
    }

    /// Converts a rectangle in this window's coordinates to screen coordinates.
    open func convertToScreen(_ rect: NSRect) -> NSRect {
        NSRect(origin: convertPoint(toScreen: rect.origin), size: rect.size)
    }

    /// Converts a rectangle in screen coordinates to this window's coordinates.
    open func convertFromScreen(_ rect: NSRect) -> NSRect {
        NSRect(origin: convertPoint(fromScreen: rect.origin), size: rect.size)
    }

    /// Moves the window so its top-left corner lands on a point.
    ///
    /// AppKit's coordinate space puts the origin at the bottom-left, so this
    /// is `setFrameOrigin` with the height subtracted — the spelling exists
    /// because cascading and "place it under the last one" code is written in
    /// top-left terms and would otherwise do the arithmetic itself.
    open func setFrameTopLeftPoint(_ point: NSPoint) {
        setFrame(NSRect(x: point.x,
                        y: point.y - frame.height,
                        width: frame.width,
                        height: frame.height),
                 display: true)
    }

    /// Sets the window content size while preserving its origin.
    open func setContentSize(_ size: NSSize) {
        let reservedHeight = toolbar?.isVisible == true ? resolvedToolbarHeight : 0
        setFrame(NSRect(origin: frame.origin, size: NSSize(width: size.width, height: size.height + reservedHeight)), display: true)
        layoutToolbarAndContent()
    }

    /// Centers the window in the screen's visible (work) area.
    open func center() {
        winCenter()
    }

    /// Ensures the window and content hierarchy have native peers.
    @discardableResult
    open func realizeNativePeer() -> NativeHandle {
        return winRealizeNativePeer()
    }

    /// Returns the AppKit-style proxy for a standard title-bar button.
    ///
    /// The proxy lets client code query and toggle `isHidden`/`isEnabled` the
    /// way AppKit apps do. Reflecting the state onto the native Win32 caption
    /// (which does not separate the caption buttons the way Cocoa does) is
    /// tracked as later window-chrome work; borderless windows vend no buttons.
    open func standardWindowButton(_ type: ButtonType) -> NSButton? {
        return winStandardWindowButton(type)
    }

    /// Closes the window after asking the delegate, like the close button.
    open func performClose(_ sender: Any?) {
        if delegate?.windowShouldClose(self) ?? true {
            close()
        }
    }

    // MARK: - Window state

    /// The screen the window is on, approximated by the display whose frame
    /// intersects the window's frame the most (the primary when none do).
    open var screen: NSScreen? {
        let screens = nativeBackend.screenDescriptions().map { NSScreen(frame: $0.frame, visibleFrame: $0.visibleFrame) }
        let best = screens.max { first, second in
            intersectionArea(of: first.frame) < intersectionArea(of: second.frame)
        }
        return best ?? screens.first
    }

    /// Whether the window is on screen (ordered in and not minimized).
    open var isVisible: Bool {
        guard let nativeHandle else {
            return false
        }
        return nativeBackend.isWindowVisible(nativeHandle)
    }

    /// Whether the window is minimized to the taskbar.
    open var isMiniaturized: Bool {
        guard let nativeHandle else {
            return false
        }
        return nativeBackend.isWindowMinimized(nativeHandle)
    }

    /// Whether the window is zoomed (maximized).
    open var isZoomed: Bool {
        guard let nativeHandle else {
            return false
        }
        return nativeBackend.isWindowZoomed(nativeHandle)
    }

    /// Minimizes the window to the taskbar.
    open func miniaturize(_ sender: Any?) {
        let handle = realizeNativePeer()
        nativeBackend.setWindowMinimized(true, for: handle)
        delegate?.windowDidMiniaturize(Notification(name: Notification.Name("NSWindowDidMiniaturizeNotification"), object: self))
    }

    /// Restores the window from the minimized state.
    open func deminiaturize(_ sender: Any?) {
        let handle = realizeNativePeer()
        nativeBackend.setWindowMinimized(false, for: handle)
        delegate?.windowDidDeminiaturize(Notification(name: Notification.Name("NSWindowDidDeminiaturizeNotification"), object: self))
    }

    /// Toggles the window between zoomed (maximized) and its normal frame.
    open func zoom(_ sender: Any?) {
        let handle = realizeNativePeer()
        nativeBackend.toggleWindowZoom(handle)
    }

    /// Toggles full-screen mode.
    ///
    /// AppKit slides the title bar away and merges the toolbar into it; Windows
    /// has no equivalent title-bar merge, so WinChocolate presents the honest
    /// Windows full screen — a borderless window covering the display — and the
    /// toolbar stays put as the window's top strip (still fully functional).
    /// A window whose `collectionBehavior` is `.fullScreenNone` won't toggle.
    open func toggleFullScreen(_ sender: Any?) {
        winToggleFullScreen(sender)
    }

    /// Moves the window to the back of the z-order without activating it.
    open func orderBack(_ sender: Any?) {
        let handle = realizeNativePeer()
        nativeBackend.orderWindowBack(handle)
    }

internal func installToolbarHost() {
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
}

/// A standard title-bar button proxy that notifies its window when hidden.
final class StandardWindowButtonProxy: NSButton {
    /// Called whenever `isHidden` changes so the window updates its caption.
    var onVisibilityChanged: (() -> Void)?

    override var isHidden: Bool {
        didSet {
            onVisibilityChanged?()
        }
    }
}

/// AppKit-compatible backing store alias.
public typealias NSBackingStoreType = NSWindow.BackingStoreType
