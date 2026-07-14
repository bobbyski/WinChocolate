/// The methods a window delegate uses to participate in window lifecycle.
public protocol NSWindowDelegate: AnyObject {
    /// Returns whether the window may close; false vetoes a title-bar close.
    func windowShouldClose(_ sender: NSWindow) -> Bool

    /// Tells the delegate the window is closing.
    func windowWillClose(_ notification: NSNotification)

    /// Tells the delegate the window was resized (by the user or the system).
    func windowDidResize(_ notification: NSNotification)

    /// Tells the delegate the window was moved.
    func windowDidMove(_ notification: NSNotification)

    /// Tells the delegate the window was minimized.
    func windowDidMiniaturize(_ notification: NSNotification)

    /// Tells the delegate the window was restored from the minimized state.
    func windowDidDeminiaturize(_ notification: NSNotification)

    /// Tells the delegate the window is about to enter full screen.
    func windowWillEnterFullScreen(_ notification: NSNotification)

    /// Tells the delegate the window has entered full screen.
    func windowDidEnterFullScreen(_ notification: NSNotification)

    /// Tells the delegate the window is about to exit full screen.
    func windowWillExitFullScreen(_ notification: NSNotification)

    /// Tells the delegate the window has exited full screen.
    func windowDidExitFullScreen(_ notification: NSNotification)
}

extension NSWindowDelegate {
    /// Default: windows may always close.
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        true
    }

    /// Default no-op so delegates only implement the callbacks they need.
    public func windowWillClose(_ notification: NSNotification) {}

    /// Default no-op so delegates only implement the callbacks they need.
    public func windowDidResize(_ notification: NSNotification) {}

    /// Default no-op so delegates only implement the callbacks they need.
    public func windowDidMove(_ notification: NSNotification) {}

    /// Default no-op so delegates only implement the callbacks they need.
    public func windowDidMiniaturize(_ notification: NSNotification) {}

    /// Default no-op so delegates only implement the callbacks they need.
    public func windowDidDeminiaturize(_ notification: NSNotification) {}

    /// Default no-op so delegates only implement the callbacks they need.
    public func windowWillEnterFullScreen(_ notification: NSNotification) {}

    /// Default no-op so delegates only implement the callbacks they need.
    public func windowDidEnterFullScreen(_ notification: NSNotification) {}

    /// Default no-op so delegates only implement the callbacks they need.
    public func windowWillExitFullScreen(_ notification: NSNotification) {}

    /// Default no-op so delegates only implement the callbacks they need.
    public func windowDidExitFullScreen(_ notification: NSNotification) {}
}

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

        /// Utility-panel window style with compact tool-window chrome.
        public static let utilityWindow = StyleMask(rawValue: 1 << 4)

        /// Content view fills the whole frame, including under the title bar.
        public static let fullSizeContentView = StyleMask(rawValue: 1 << 5)

        /// A panel that does not become key/activate when shown.
        public static let nonactivatingPanel = StyleMask(rawValue: 1 << 6)

        /// A heads-up-display style panel (dark translucent chrome on
        /// AppKit; the classic backend renders a standard utility panel).
        public static let hudWindow = StyleMask(rawValue: 1 << 7)

        /// Present while the window occupies the full screen. AppKit adds this
        /// to `styleMask` for the duration of full-screen mode; WinChocolate
        /// does the same (see `toggleFullScreen`).
        public static let fullScreen = StyleMask(rawValue: 1 << 7)
    }

    /// How a window participates in spaces and full screen, matching AppKit's
    /// `NSWindow.CollectionBehavior`. WinChocolate stores the value for API
    /// fidelity; only the full-screen flags affect behavior on Windows.
    public struct CollectionBehavior: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        /// The window can enter full screen as a primary full-screen window.
        public static let fullScreenPrimary = CollectionBehavior(rawValue: 1 << 7)

        /// The window can join another window's full-screen space.
        public static let fullScreenAuxiliary = CollectionBehavior(rawValue: 1 << 8)

        /// The window cannot be made full screen.
        public static let fullScreenNone = CollectionBehavior(rawValue: 1 << 9)
    }

    /// Whether the window shows its title text.
    public enum TitleVisibility: Sendable {
        /// The title is shown in the title bar (default).
        case visible

        /// The title text is hidden while the title bar remains.
        case hidden
    }

    /// The standard title-bar buttons AppKit can vend.
    public enum ButtonType: Sendable {
        case closeButton
        case miniaturizeButton
        case zoomButton
        case toolbarButton
        case documentIconButton
    }

    /// Window z-ordering levels matching AppKit names.
    public struct Level: RawRepresentable, Equatable, Hashable, Sendable {
        /// Raw level value; higher levels order above lower ones.
        public let rawValue: Int

        /// Creates a level from a raw value.
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// The default level for document windows.
        public static let normal = Level(rawValue: 0)

        /// The level for floating utility panels above document windows.
        public static let floating = Level(rawValue: 3)

        /// The level for modal panels.
        public static let modalPanel = Level(rawValue: 8)

        /// The level for status-bar items, above floating panels.
        public static let statusBar = Level(rawValue: 25)
    }

    /// Whether closing releases the window (AppKit memory management).
    /// Stored for source compatibility — Swift/ARC owns WinChocolate
    /// windows, so the flag changes nothing here.
    open var isReleasedWhenClosed: Bool = true

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

    private var standardButtons: [ButtonType: NSButton] = [:]

    /// The style mask the window was created with (without the transient
    /// full-screen flag).
    private let baseStyleMask: StyleMask

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

    private var winIsFullScreen = false

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
    public private(set) var nativeHandle: NativeHandle?

    /// The responder currently receiving keyboard focus in this window.
    public private(set) weak var firstResponder: NSResponder? {
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

    /// The sheet currently attached to this window, if any (AppKit's
    /// `attachedSheet`). While a sheet is attached, additional `beginSheet`
    /// calls queue behind it.
    open internal(set) var attachedSheet: NSWindow?

    /// The window this window is a sheet of, if any (AppKit's `sheetParent`).
    open internal(set) weak var sheetParent: NSWindow?

    // Sheets requested while another sheet is attached, presented FIFO as each
    // preceding sheet ends — matching AppKit's sheet queue.
    private var winQueuedSheets: [(NSWindow, ((NSApplication.ModalResponse) -> Void)?)] = []

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

    private func winPresentSheet(_ sheetWindow: NSWindow, completionHandler handler: ((NSApplication.ModalResponse) -> Void)?) {
        let sheetSize = sheetWindow.frame.size
        sheetWindow.setFrame(NSRect(origin: winSheetOrigin(for: sheetSize), size: sheetSize), display: true)
        attachedSheet = sheetWindow
        sheetWindow.sheetParent = self
        let response = NSApplication.shared.runModal(for: sheetWindow)
        handler?(response)
    }

    /// Ends a sheet session presented with `beginSheet(_:completionHandler:)`,
    /// unlinks it, and presents the next queued sheet if one is waiting.
    open func endSheet(_ sheetWindow: NSWindow, returnCode: NSApplication.ModalResponse = .OK) {
        NSApplication.shared.stopModal(withCode: returnCode)
        sheetWindow.close()
        if attachedSheet === sheetWindow {
            attachedSheet = nil
        }
        sheetWindow.sheetParent = nil
        if !winQueuedSheets.isEmpty {
            let (next, handler) = winQueuedSheets.removeFirst()
            winPresentSheet(next, completionHandler: handler)
        }
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

        // A modal window closed from its title bar ends its session, so
        // `runModal(for:)` callers unwind instead of leaking a nested loop.
        NSApplication.shared.windowWillClose(self)
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

    /// Centers the window in the screen's visible (work) area.
    open func center() {
        let workArea = nativeBackend.screenDescriptions().first?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1024, height: 768)
        let origin = NSPoint(
            x: NSMidX(workArea) - frame.size.width / 2,
            y: NSMidY(workArea) - frame.size.height / 2
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
        nativeBackend.registerWindowShouldCloseHandler(for: handle) { [weak self] in
            guard let self else {
                return true
            }
            return self.delegate?.windowShouldClose(self) ?? true
        }
        nativeBackend.registerWindowResizeAction(for: handle) { [weak self] size in
            self?.nativeWindowDidResize(to: size)
        }
        nativeBackend.registerWindowMoveAction(for: handle) { [weak self] origin in
            self?.nativeWindowDidMove(to: origin)
        }
        if level != .normal {
            nativeBackend.setWindowLevel(level, for: handle)
        }
        applySizeLimits()
        NSApplication.shared.addWindowsItem(self)
        applyTitleVisibility()
        applyStandardButtonVisibility()
        installToolbarHost()
        layoutToolbarAndContent()
        contentView?.realizeNativePeer(in: nativeBackend, parent: handle)
        if isMovableByWindowBackground {
            applyMovableByWindowBackground()
        }
        return handle
    }

    /// Pushes the effective caption text to the native window, honoring
    /// `titleVisibility`.
    private func applyTitleVisibility() {
        guard let nativeHandle else {
            return
        }

        nativeBackend.setText(titleVisibility == .hidden ? "" : title, for: nativeHandle)
    }

    /// Returns the AppKit-style proxy for a standard title-bar button.
    ///
    /// The proxy lets client code query and toggle `isHidden`/`isEnabled` the
    /// way AppKit apps do. Reflecting the state onto the native Win32 caption
    /// (which does not separate the caption buttons the way Cocoa does) is
    /// tracked as later window-chrome work; borderless windows vend no buttons.
    open func standardWindowButton(_ type: ButtonType) -> NSButton? {
        guard styleMask.contains(.titled) else {
            return nil
        }

        if let existing = standardButtons[type] {
            return existing
        }

        let button = StandardWindowButtonProxy(frame: NSMakeRect(0, 0, 14, 14))
        switch type {
        case .closeButton:
            button.title = "Close"
        case .miniaturizeButton:
            button.title = "Minimize"
        case .zoomButton:
            button.title = "Zoom"
        case .toolbarButton:
            button.title = "Toolbar"
        case .documentIconButton:
            button.title = ""
        }
        // Hiding a caption button (close/minimize/zoom) reflects onto the
        // native title bar.
        button.onVisibilityChanged = { [weak self] in
            self?.applyStandardButtonVisibility()
        }
        standardButtons[type] = button
        return button
    }

    /// Reflects the standard-button proxies' `isHidden` onto the native caption.
    private func applyStandardButtonVisibility() {
        guard let nativeHandle else {
            return
        }

        nativeBackend.setWindowButtonsHidden(
            closeHidden: standardButtons[.closeButton]?.isHidden ?? false,
            minimizeHidden: standardButtons[.miniaturizeButton]?.isHidden ?? false,
            zoomHidden: standardButtons[.zoomButton]?.isHidden ?? false,
            for: nativeHandle
        )
    }

    private func applyMovableByWindowBackground() {
        guard let contentHandle = contentView?.nativeHandle else {
            return
        }

        nativeBackend.setViewDragsParentWindow(isMovableByWindowBackground, for: contentHandle)
    }

    private func applySizeLimits() {
        guard let nativeHandle else {
            return
        }

        func positive(_ size: NSSize) -> NSSize? {
            (size.width > 0 || size.height > 0) ? size : nil
        }

        nativeBackend.setWindowContentSizeLimits(
            minSize: positive(contentMinSize) ?? positive(minSize),
            maxSize: positive(contentMaxSize) ?? positive(maxSize),
            for: nativeHandle
        )
    }

    /// Closes the window after asking the delegate, like the close button.
    open func performClose(_ sender: Any?) {
        if delegate?.windowShouldClose(self) ?? true {
            close()
        }
    }

    private func nativeWindowDidClose() {
        toolbarHostView?.destroyNativePeer()
        toolbarHostView = nil
        nativeHandle = nil
        NSApplication.shared.removeWindowsItem(self)
        delegate?.windowWillClose(NSNotification(name: "NSWindowWillCloseNotification", object: self))
    }

    private func nativeWindowDidResize(to size: NSSize) {
        frame = NSRect(origin: frame.origin, size: size)
        layoutToolbarAndContent()
        // Run the layout pass synchronously so live resize tracks the new
        // size instead of waiting for the next pump tick.
        contentView?.layoutSubtreeIfNeeded()
        delegate?.windowDidResize(NSNotification(name: "NSWindowDidResizeNotification", object: self))
    }

    private func nativeWindowDidMove(to origin: NSPoint) {
        // Track the native origin without pushing it back to the backend.
        frame.origin = origin
        delegate?.windowDidMove(NSNotification(name: "NSWindowDidMoveNotification", object: self))
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

    private func intersectionArea(of rect: NSRect) -> CGFloat {
        let overlap = frame.intersection(rect)
        return overlap.width * overlap.height
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
        delegate?.windowDidMiniaturize(NSNotification(name: "NSWindowDidMiniaturizeNotification", object: self))
    }

    /// Restores the window from the minimized state.
    open func deminiaturize(_ sender: Any?) {
        let handle = realizeNativePeer()
        nativeBackend.setWindowMinimized(false, for: handle)
        delegate?.windowDidDeminiaturize(NSNotification(name: "NSWindowDidDeminiaturizeNotification", object: self))
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
        guard !collectionBehavior.contains(.fullScreenNone) else {
            return
        }

        let handle = realizeNativePeer()
        let entering = !winIsFullScreen
        let willName = entering ? "NSWindowWillEnterFullScreenNotification" : "NSWindowWillExitFullScreenNotification"
        let didName = entering ? "NSWindowDidEnterFullScreenNotification" : "NSWindowDidExitFullScreenNotification"

        if entering {
            delegate?.windowWillEnterFullScreen(NSNotification(name: willName, object: self))
        } else {
            delegate?.windowWillExitFullScreen(NSNotification(name: willName, object: self))
        }

        winIsFullScreen = entering
        nativeBackend.setWindowFullScreen(entering, for: handle)
        // The toolbar/content re-layout for the new frame (the toolbar remains
        // the top strip — no title-bar merge on Windows).
        layoutToolbarAndContent()

        if entering {
            delegate?.windowDidEnterFullScreen(NSNotification(name: didName, object: self))
        } else {
            delegate?.windowDidExitFullScreen(NSNotification(name: didName, object: self))
        }
    }

    /// Moves the window to the back of the z-order without activating it.
    open func orderBack(_ sender: Any?) {
        let handle = realizeNativePeer()
        nativeBackend.orderWindowBack(handle)
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
