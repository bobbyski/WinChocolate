/// Base class for visible rectangular content.
///
/// `NSView` owns a frame, a child hierarchy, and a lazily-created native peer.
/// Subclasses override `realizeNativePeer(in:)` to request a specific Windows
/// control kind while keeping AppKit-style view composition at the public API.
open class NSView: NSResponder {
    /// Autoresizing behavior flags matching AppKit names.
    public struct AutoresizingMask: OptionSet, Sendable {
        /// Raw option value.
        public let rawValue: UInt

        /// Creates an autoresizing mask from a raw value.
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// Left margin can change.
        public static let minXMargin = AutoresizingMask(rawValue: 1 << 0)

        /// Width can change.
        public static let width = AutoresizingMask(rawValue: 1 << 1)

        /// Right margin can change.
        public static let maxXMargin = AutoresizingMask(rawValue: 1 << 2)

        /// Bottom margin can change.
        public static let minYMargin = AutoresizingMask(rawValue: 1 << 3)

        /// Height can change.
        public static let height = AutoresizingMask(rawValue: 1 << 4)

        /// Top margin can change.
        public static let maxYMargin = AutoresizingMask(rawValue: 1 << 5)
    }

    /// Posted when a view's frame changes, for views that opted in through
    /// `postsFrameChangedNotifications`.
    public static let frameDidChangeNotification = Notification.Name("NSViewFrameDidChangeNotification")

    /// Posted when a view's bounds origin changes (scrolling), for views
    /// that opted in through `postsBoundsChangedNotifications`.
    public static let boundsDidChangeNotification = Notification.Name("NSViewBoundsDidChangeNotification")

    /// Whether frame changes post `frameDidChangeNotification`.
    open var postsFrameChangedNotifications: Bool = false

    /// Whether bounds-origin changes post `boundsDidChangeNotification`
    /// (clip views scroll by moving their bounds origin).
    open var postsBoundsChangedNotifications: Bool = false

    /// The view frame in its parent coordinate space.
    open var frame: NSRect {
        didSet {
            autoresizeSubviews(from: oldValue.size, to: frame.size)

            if postsFrameChangedNotifications, frame != oldValue {
                NotificationCenter.default.post(name: NSView.frameDidChangeNotification, object: self)
            }

            guard let nativeHandle else {
                return
            }

            realizedBackend?.setFrame(frame, for: nativeHandle)
        }
    }

    /// The view bounds in its own coordinate space.
    open var bounds: NSRect {
        NSRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height)
    }

    /// Application-defined integer tag used to find views in a hierarchy.
    open var tag: Int = 0

    /// Autoresizing behavior for legacy frame-based layouts.
    open var autoresizingMask: AutoresizingMask = []

    /// Whether child views should be autoresized by this view.
    open var autoresizesSubviews: Bool = true

    /// Whether this view requests layer-backed rendering.
    open var wantsLayer: Bool = false

    /// Informational tooltip text.
    open var toolTip: String? {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setToolTip(toolTip, for: nativeHandle)
        }
    }

    /// The view's appearance override; `nil` inherits from the ancestor
    /// chain (see `effectiveAppearance` in NSAppearance.swift).
    public var appearance: NSAppearance?

    /// The view's parent view.
    public private(set) weak var superview: NSView?

    /// The view's child views.
    public private(set) var subviews: [NSView] = []

    /// The next view in the keyboard focus loop.
    open weak var nextKeyView: NSView?

    /// The previous view in the keyboard focus loop.
    open weak var previousKeyView: NSView?

    /// The nearest containing window, when this view is attached to one.
    open var window: NSWindow? {
        if let superview {
            return superview.window
        }

        return nextResponder as? NSWindow
    }

    /// The backend-created native handle, if realized.
    public private(set) var nativeHandle: NativeHandle?

    /// Backend that created the native peer, if realized.
    public private(set) weak var realizedBackend: NativeControlBackend?

    /// Whether the view needs a redraw on the next paint pass.
    ///
    /// Setting `true` invalidates the realized native peer; the flag clears
    /// when the native paint pass calls `draw(_:)`.
    open var needsDisplay = false {
        didSet {
            guard needsDisplay, let nativeHandle else {
                return
            }

            realizedBackend?.invalidateControl(nativeHandle)
        }
    }

    /// Whether the view is hidden from display.
    open var isHidden: Bool = false {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setHidden(isHidden, for: nativeHandle)
        }
    }

    /// The view background color, when explicitly set.
    open var backgroundColor: NSColor? {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setBackgroundColor(backgroundColor, for: nativeHandle)
        }
    }

    /// The view's opacity from `0` (transparent) to `1` (opaque).
    ///
    /// Stored for source compatibility; the classic backend does not yet composite
    /// partial view opacity, so the value round-trips but does not blend.
    open var alphaValue: CGFloat = 1

    /// A string that identifies the view, matching AppKit's identifier.
    open var identifier: NSUserInterfaceItemIdentifier?

    /// Whether the view is opaque. Subclasses override to opt into opaque drawing.
    open var isOpaque: Bool { false }

    /// Whether the view uses a flipped (top-left origin) coordinate system.
    ///
    /// WinChocolate lays out and draws in top-left coordinates throughout, so
    /// views report `true` — custom drawing that branches on `isFlipped` gets the
    /// coordinate convention the backend actually uses.
    open var isFlipped: Bool { true }

    /// The view's natural size for layout, or `noIntrinsicMetric` when it has none.
    open var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: NSView.noIntrinsicMetric)
    }

    /// Sentinel used by `intrinsicContentSize` when a dimension has no natural size.
    public static let noIntrinsicMetric: CGFloat = -1

    /// Whether the view has been flagged as needing layout.
    ///
    /// Setting `true` schedules a coalesced layout pass for the containing
    /// window (see `NSLayoutPump`); the flag clears when
    /// `layoutSubtreeIfNeeded()` visits the view. Marks on views not yet in
    /// a window stay set and are honored by the window's next layout pass.
    open var needsLayout: Bool = false {
        didSet {
            guard needsLayout, let window else {
                return
            }

            NSLayoutPump.shared.scheduleLayout(for: window)
        }
    }

    /// Whether the view's frame is managed by autoresizing rather than
    /// constraints. When `false`, this view's frame is computed by the Auto
    /// Layout solver from the constraints on its container (see the Layout
    /// sources); when `true` (the default) the view keeps its explicit frame
    /// and contributes it to the solver as a fixed input.
    open var translatesAutoresizingMaskIntoConstraints: Bool = true

    /// Auto Layout constraints installed on this view — it acts as the layout
    /// container for these, solving its subviews' frames from them.
    var winActiveConstraints: [NSLayoutConstraint] = []

    /// Per-axis content-hugging priorities (how strongly the view resists
    /// growing past its intrinsic size); AppKit's default is `defaultLow` (250).
    var winContentHuggingPriority: (horizontal: Float, vertical: Float) = (250, 250)

    /// Per-axis compression-resistance priorities (how strongly the view resists
    /// shrinking below its intrinsic size); AppKit's default is `defaultHigh` (750).
    var winCompressionResistancePriority: (horizontal: Float, vertical: Float) = (750, 750)

    /// Invisible layout guides owned by this view (see `NSLayoutGuide`).
    var winLayoutGuides: [NSLayoutGuide] = []

    /// The view's writing-direction-relative layout margins, used by
    /// `layoutMarginsGuide`. AppKit's default is 8pt on every edge.
    public var directionalLayoutMargins = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8) {
        didSet { winUpdateLayoutMarginsConstraints() }
    }

    /// The lazily-created margins guide inset from the view's edges (see
    /// `layoutMarginsGuide`), and the four edge constraints positioning it.
    var winLayoutMarginsGuide: NSLayoutGuide?
    var winLayoutMarginsConstraints: [NSLayoutConstraint] = []

    /// Lays out the view's subviews. Subclasses override to position children.
    open func layout() {}

    /// The view's context menu, shown on right-click when set.
    open var menu: NSMenu?

    /// Shows the view's context menu on right-click, matching AppKit's
    /// default responder behavior; without a menu the event travels up the
    /// responder chain as before.
    open override func rightMouseDown(with event: NSEvent) {
        if let menu {
            _ = menu.popUp(positioning: nil, at: convert(event.locationInWindow, from: nil), in: self)
            return
        }
        super.rightMouseDown(with: event)
    }

    // Stored accessibility strings. Narrator/UIA wiring is a later slice;
    // storing them keeps AppKit-shaped consumers building and preserves the
    // values for when the backend exposes them.
    private var storedAccessibilityLabel: String?
    private var storedAccessibilityValue: String?
    private var storedAccessibilityHelp: String?

    /// Sets the accessibility label read by assistive technology.
    open func setAccessibilityLabel(_ label: String?) {
        storedAccessibilityLabel = label
    }

    /// The accessibility label read by assistive technology.
    open func accessibilityLabel() -> String? {
        storedAccessibilityLabel
    }

    /// Sets the accessibility value read by assistive technology.
    open func setAccessibilityValue(_ value: Any?) {
        storedAccessibilityValue = value.map { String(describing: $0) }
    }

    /// The accessibility value read by assistive technology.
    open func accessibilityValue() -> Any? {
        storedAccessibilityValue
    }

    /// Sets the accessibility help text read by assistive technology.
    open func setAccessibilityHelp(_ help: String?) {
        storedAccessibilityHelp = help
    }

    /// The accessibility help text read by assistive technology.
    open func accessibilityHelp() -> String? {
        storedAccessibilityHelp
    }

    /// The view's mouse-tracking areas.
    public private(set) var trackingAreas: [NSTrackingArea] = []

    // Tracking areas currently containing the cursor, by object identity.
    private var hoveredTrackingAreas: Set<ObjectIdentifier> = []

    /// Adds a tracking area to the view.
    open func addTrackingArea(_ trackingArea: NSTrackingArea) {
        trackingAreas.append(trackingArea)
    }

    /// Removes a tracking area from the view.
    open func removeTrackingArea(_ trackingArea: NSTrackingArea) {
        trackingAreas.removeAll { $0 === trackingArea }
        hoveredTrackingAreas.remove(ObjectIdentifier(trackingArea))
    }

    /// Called when the view's tracking areas need recomputation (resize,
    /// scroll). Subclasses override to remove and re-add their areas.
    open func updateTrackingAreas() {}

    /// Whether a tracking area is active for the current window state.
    private func isTrackingActive(_ area: NSTrackingArea) -> Bool {
        if area.options.contains(.activeAlways) {
            return true
        }
        if area.options.contains(.activeInKeyWindow) {
            return window?.isKeyWindow ?? false
        }
        // Areas created without an activity option track like key-window ones.
        return window?.isKeyWindow ?? true
    }

    /// Gesture recognizers attached through `addGestureRecognizer`; the
    /// view forwards its mouse events to each (see NSGestureRecognizer.swift).
    var winGestureRecognizers: [NSGestureRecognizer] = []

    /// Forwards a press to attached gesture recognizers, then up the chain.
    open override func mouseDown(with event: NSEvent) {
        for recognizer in winGestureRecognizers {
            recognizer.mouseDown(with: event)
        }
        super.mouseDown(with: event)
    }

    /// Forwards a drag to attached gesture recognizers, then up the chain.
    open override func mouseDragged(with event: NSEvent) {
        for recognizer in winGestureRecognizers {
            recognizer.mouseDragged(with: event)
        }
        super.mouseDragged(with: event)
    }

    /// Forwards a release to attached gesture recognizers, then up the chain.
    open override func mouseUp(with event: NSEvent) {
        for recognizer in winGestureRecognizers {
            recognizer.mouseUp(with: event)
        }
        super.mouseUp(with: event)
    }

    /// Resolves hover state against the tracking areas for a mouse position,
    /// sending `mouseEntered`/`mouseExited` to each area's owner — and
    /// `mouseMoved` to owners of areas that asked for movement.
    func resolveTrackingAreas(with event: NSEvent) {
        guard !trackingAreas.isEmpty else {
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        for area in trackingAreas where area.options.contains(.mouseMoved) {
            let region = area.options.contains(.inVisibleRect) ? bounds : area.rect
            if isTrackingActive(area), region.contains(point) {
                trackingResponder(for: area)?.mouseMoved(with: event)
            }
        }
        for area in trackingAreas where area.options.contains(.mouseEnteredAndExited) {
            let identity = ObjectIdentifier(area)
            let region = area.options.contains(.inVisibleRect) ? bounds : area.rect
            let inside = isTrackingActive(area) && region.contains(point)
            let wasInside = hoveredTrackingAreas.contains(identity)
            if inside && !wasInside {
                hoveredTrackingAreas.insert(identity)
                trackingResponder(for: area)?.mouseEntered(with: NSEvent(type: .mouseEntered, locationInWindow: event.locationInWindow, modifierFlags: event.modifierFlags))
            } else if !inside && wasInside {
                hoveredTrackingAreas.remove(identity)
                trackingResponder(for: area)?.mouseExited(with: NSEvent(type: .mouseExited, locationInWindow: event.locationInWindow, modifierFlags: event.modifierFlags))
            }
        }
    }

    /// Exits every hovered tracking area (the cursor left the view entirely).
    func exitAllTrackingAreas() {
        guard !hoveredTrackingAreas.isEmpty else {
            return
        }

        for area in trackingAreas where hoveredTrackingAreas.contains(ObjectIdentifier(area)) {
            hoveredTrackingAreas.remove(ObjectIdentifier(area))
            trackingResponder(for: area)?.mouseExited(with: NSEvent(type: .mouseExited, locationInWindow: NSPoint(x: -1, y: -1)))
        }
    }

    /// The responder that receives an area's tracking events.
    private func trackingResponder(for area: NSTrackingArea) -> NSResponder? {
        (area.owner as? NSResponder) ?? self
    }

    // MARK: - Drag and drop

    /// The drop types the view registered for (see `registerForDraggedTypes`).
    var winRegisteredDraggedTypes: [NSPasteboard.PasteboardType] = []

    /// The dragging info for the drag currently over the view, when any.
    var winActiveDragInfo: NSDraggingInfo?

    /// A drag entered the view; return the operation to signal, or `[]` to
    /// refuse. The default accepts a copy when the view registered types.
    open func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        winRegisteredDraggedTypes.isEmpty ? [] : .copy
    }

    /// The drag moved within the view; defaults to the entry decision.
    open func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        draggingEntered(sender)
    }

    /// The drag left the view without dropping.
    open func draggingExited(_ sender: NSDraggingInfo?) {}

    /// Last chance to refuse the drop; defaults to accepting.
    open func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        true
    }

    /// Performs the drop. Override to read `sender.draggingPasteboard`.
    open func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        false
    }

    /// The drop finished successfully.
    open func concludeDragOperation(_ sender: NSDraggingInfo?) {}

    /// Creates a view with a frame.
    /// Creates a view with a zero frame, matching AppKit's shape. ActiveUI
    /// and other frame-assigning consumers size views after creation.
    public convenience override init() {
        self.init(frame: .zero)
    }

    public init(frame frameRect: NSRect) {
        self.frame = frameRect
        super.init()
    }

    /// Plain WinChocolate views can accept keyboard focus.
    open override var acceptsFirstResponder: Bool {
        true
    }

    /// Adds a child view.
    open func addSubview(_ view: NSView) {
        addSubview(view, positioned: .above, relativeTo: nil)
    }

    /// Adds a child view at a position relative to another child view.
    open func addSubview(_ view: NSView, positioned place: NSWindow.OrderingMode, relativeTo otherView: NSView?) {
        view.removeFromSuperview()
        view.superview = self
        view.nextResponder = self
        insertSubview(view, positioned: place, relativeTo: otherView)

        guard let realizedBackend, let nativeHandle else {
            return
        }

        view.realizeNativePeer(in: realizedBackend, parent: nativeHandle)
    }

    /// Replaces one child view with another while preserving the child position.
    open func replaceSubview(_ oldView: NSView, with newView: NSView) {
        guard let index = subviews.firstIndex(where: { $0 === oldView }) else {
            addSubview(newView)
            return
        }

        oldView.superview = nil
        oldView.nextResponder = nil
        oldView.destroyNativePeer()
        newView.removeFromSuperview()
        newView.superview = self
        newView.nextResponder = self
        subviews[index] = newView

        guard let realizedBackend, let nativeHandle else {
            return
        }

        newView.realizeNativePeer(in: realizedBackend, parent: nativeHandle)
    }

    /// Removes the view from its parent hierarchy.
    open func removeFromSuperview() {
        guard let superview else {
            return
        }

        superview.subviews.removeAll { $0 === self }
        self.superview = nil
        self.nextResponder = nil
        destroyNativePeer()
    }

    /// Marks the view as needing display.
    open func setNeedsDisplay(_ needsDisplay: Bool) {
        self.needsDisplay = needsDisplay
    }

    private func autoresizeSubviews(from oldSize: NSSize, to newSize: NSSize) {
        guard autoresizesSubviews, oldSize != newSize else {
            return
        }

        let deltaWidth = newSize.width - oldSize.width
        let deltaHeight = newSize.height - oldSize.height
        guard deltaWidth != 0 || deltaHeight != 0 else {
            return
        }

        for subview in subviews {
            var newFrame = subview.frame
            let mask = subview.autoresizingMask

            if mask.contains(.width) {
                newFrame.size.width = max(0, newFrame.size.width + deltaWidth)
            } else if mask.contains(.minXMargin), !mask.contains(.maxXMargin) {
                newFrame.origin.x += deltaWidth
            } else if mask.contains(.minXMargin), mask.contains(.maxXMargin) {
                newFrame.origin.x += deltaWidth / 2
            }

            if mask.contains(.height) {
                newFrame.size.height = max(0, newFrame.size.height + deltaHeight)
            } else if mask.contains(.minYMargin), !mask.contains(.maxYMargin) {
                newFrame.origin.y += deltaHeight
            } else if mask.contains(.minYMargin), mask.contains(.maxYMargin) {
                newFrame.origin.y += deltaHeight / 2
            }

            subview.frame = newFrame
        }
    }

    /// Returns true when this view is contained by the given ancestor.
    open func isDescendant(of view: NSView) -> Bool {
        var current = superview
        while let candidate = current {
            if candidate === view {
                return true
            }
            current = candidate.superview
        }
        return false
    }

    /// Finds the first view in this hierarchy with the given tag.
    open func viewWithTag(_ tag: Int) -> NSView? {
        if self.tag == tag {
            return self
        }

        for subview in subviews {
            if let match = subview.viewWithTag(tag) {
                return match
            }
        }

        return nil
    }

    /// Converts a point from another view's coordinate space into this view's coordinate space.
    open func convert(_ point: NSPoint, from view: NSView?) -> NSPoint {
        let windowPoint = view?.convertPointToWindow(point) ?? point
        return convertPointFromWindow(windowPoint)
    }

    /// Converts a point from this view's coordinate space into another view's coordinate space.
    open func convert(_ point: NSPoint, to view: NSView?) -> NSPoint {
        let windowPoint = convertPointToWindow(point)
        return view?.convertPointFromWindow(windowPoint) ?? windowPoint
    }

    /// Converts a rectangle from another view's coordinate space into this view's coordinate space.
    open func convert(_ rect: NSRect, from view: NSView?) -> NSRect {
        NSRect(origin: convert(rect.origin, from: view), size: rect.size)
    }

    /// Converts a rectangle from this view's coordinate space into another view's coordinate space.
    open func convert(_ rect: NSRect, to view: NSView?) -> NSRect {
        NSRect(origin: convert(rect.origin, to: view), size: rect.size)
    }

    /// Returns the deepest visible subview containing the point, or this view.
    open func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, NSPointInRect(point, bounds) else {
            return nil
        }

        for subview in subviews.reversed() {
            let childPoint = subview.convert(point, from: self)
            if let hitView = subview.hitTest(childPoint) {
                return hitView
            }
        }

        return self
    }

    /// Ensures the view and its children have native peers.
    @discardableResult
    open func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        if let nativeHandle {
            return nativeHandle
        }

        let handle = createNativePeer(in: backend, parent: parent)
        nativeHandle = handle
        realizedBackend = backend
        backend.setHidden(isHidden, for: handle)
        backend.setBackgroundColor(backgroundColor, for: handle)
        backend.setToolTip(toolTip, for: handle)
        backend.registerMouseDownAction(for: handle) { [weak self] event in
            _ = self?.window?.makeFirstResponder(self)
            self?.mouseDown(with: event)
        }
        backend.registerMouseUpAction(for: handle) { [weak self] event in
            self?.mouseUp(with: event)
        }
        backend.registerMouseMovedAction(for: handle) { [weak self] event in
            self?.resolveTrackingAreas(with: event)
            self?.mouseMoved(with: event)
        }
        backend.registerMouseLeftAction(for: handle) { [weak self] in
            self?.exitAllTrackingAreas()
        }
        installDropTargetIfRealized()
        // AppKit calls updateTrackingAreas once a view joins a window; do the
        // same so views that install tracking areas there start receiving
        // mouseEntered/mouseExited.
        updateTrackingAreas()
        backend.registerMouseDraggedAction(for: handle) { [weak self] event in
            self?.mouseDragged(with: event)
        }
        backend.registerKeyDownAction(for: handle) { [weak self] event in
            self?.keyDown(with: event)
        }
        backend.registerKeyUpAction(for: handle) { [weak self] event in
            self?.keyUp(with: event)
        }
        backend.registerRightMouseDownAction(for: handle) { [weak self] event in
            self?.rightMouseDown(with: event)
        }
        backend.registerRightMouseUpAction(for: handle) { [weak self] event in
            self?.rightMouseUp(with: event)
        }
        backend.registerOtherMouseDownAction(for: handle) { [weak self] event in
            self?.otherMouseDown(with: event)
        }
        backend.registerOtherMouseUpAction(for: handle) { [weak self] event in
            self?.otherMouseUp(with: event)
        }
        backend.registerScrollWheelAction(for: handle) { [weak self] event in
            self?.scrollWheel(with: event)
        }
        backend.registerDrawAction(for: handle) { [weak self] nativeContext, dirtyRect in
            guard let self else {
                return
            }

            self.needsDisplay = false
            NSGraphicsContext(nativeContext: nativeContext).asCurrent {
                // The view's effective appearance is current for the draw
                // pass, so appearance-sensitive code (dynamic colors read
                // through `NSAppearance.currentDrawing()`) resolves per view.
                NSAppearance.winWithCurrentDrawing(self.effectiveAppearance) {
                    self.draw(dirtyRect)
                }
            }
        }
        updateCursorRegions()

        for subview in subviews {
            subview.realizeNativePeer(in: backend, parent: handle)
        }

        return handle
    }

    // MARK: - Cursor rectangles

    private var cursorRects: [(rect: NSRect, cursor: NSCursor)] = []

    /// Associates a hover cursor with a rectangle in local coordinates.
    ///
    /// Call from `resetCursorRects()`, matching AppKit's contract; rects
    /// added elsewhere are discarded on the next invalidation.
    open func addCursorRect(_ rect: NSRect, cursor: NSCursor) {
        cursorRects.append((rect, cursor))
    }

    /// Removes all of the view's cursor rectangles.
    open func discardCursorRects() {
        cursorRects.removeAll()
    }

    /// Override point: rebuild cursor rectangles with `addCursorRect`.
    open func resetCursorRects() {
    }

    /// Discards, rebuilds, and pushes cursor rectangles to the native peer.
    internal func updateCursorRegions() {
        discardCursorRects()
        resetCursorRects()
        guard let nativeHandle, let realizedBackend else {
            return
        }

        let regions = cursorRects.map { NativeCursorRegion(rect: $0.rect, cursorName: $0.cursor.cursorName) }
        realizedBackend.setCursorRegions(regions, for: nativeHandle)
    }

    /// The nearest ancestor scroll view containing this view, if any.
    open var enclosingScrollView: NSScrollView? {
        var ancestor = superview
        while let view = ancestor {
            if let scrollView = view as? NSScrollView {
                return scrollView
            }
            ancestor = view.superview
        }
        return nil
    }

    /// Scrolls the nearest enclosing scroll view to make a rect visible.
    ///
    /// The rectangle is in this view's coordinates. Returns whether any
    /// scrolling occurred, matching AppKit.
    @discardableResult
    open func scrollToVisible(_ rect: NSRect) -> Bool {
        guard let scrollView = enclosingScrollView, let documentView = scrollView.documentView else {
            return false
        }

        let clipView = scrollView.contentView
        // Work in document coordinates so the comparison matches
        // `documentVisibleRect`, which is expressed there too.
        let target = convert(rect, to: documentView)
        let visible = clipView.documentVisibleRect
        var origin = clipView.boundsOrigin

        if NSMinX(target) < NSMinX(visible) {
            origin.x = NSMinX(target)
        } else if NSMaxX(target) > NSMaxX(visible) {
            origin.x += NSMaxX(target) - NSMaxX(visible)
        }

        if NSMinY(target) < NSMinY(visible) {
            origin.y = NSMinY(target)
        } else if NSMaxY(target) > NSMaxY(visible) {
            origin.y += NSMaxY(target) - NSMaxY(visible)
        }

        let constrained = clipView.constrainBoundsRect(NSRect(origin: origin, size: visible.size)).origin
        guard constrained != clipView.boundsOrigin else {
            return false
        }

        clipView.scroll(to: constrained)
        return true
    }

    /// Gives this view and its subtree a chance to consume a key equivalent.
    ///
    /// Subviews are asked depth-first before the main menu sees the event,
    /// matching AppKit's dispatch order. The base implementation only
    /// forwards; views with their own shortcuts override and return `true`
    /// when they handle the event.
    open func performKeyEquivalent(with event: NSEvent) -> Bool {
        for subview in subviews where !subview.isHidden {
            if subview.performKeyEquivalent(with: event) {
                return true
            }
        }
        return false
    }

    /// Draws the view's custom content.
    ///
    /// Called during a native paint pass with `NSGraphicsContext.current`
    /// installed, after the view's `backgroundColor` has been painted.
    /// Subclasses override this and draw with `NSBezierPath`, `NSColor`, and
    /// `NSRectFill`; the base implementation draws nothing.
    open func draw(_ dirtyRect: NSRect) {
    }


    /// Creates the native peer for this specific view type.
    open func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createView(frame: frame, parent: parent)
    }

    /// Destroys the native peer for this view and its children.
    open func destroyNativePeer() {
        for subview in subviews {
            subview.destroyNativePeer()
        }

        guard let nativeHandle, let realizedBackend else {
            return
        }

        realizedBackend.destroyControl(nativeHandle)
        self.nativeHandle = nil
        self.realizedBackend = nil
    }

    private func convertPointToWindow(_ point: NSPoint) -> NSPoint {
        var converted = point
        var current: NSView? = self

        while let view = current {
            converted.x += view.frame.origin.x
            converted.y += view.frame.origin.y
            current = view.superview
        }

        return converted
    }

    private func convertPointFromWindow(_ point: NSPoint) -> NSPoint {
        var converted = point
        var chain: [NSView] = []
        var current: NSView? = self

        while let view = current {
            chain.append(view)
            current = view.superview
        }

        for view in chain {
            converted.x -= view.frame.origin.x
            converted.y -= view.frame.origin.y
        }

        return converted
    }

    private func insertSubview(_ view: NSView, positioned place: NSWindow.OrderingMode, relativeTo otherView: NSView?) {
        guard let otherView, let index = subviews.firstIndex(where: { $0 === otherView }) else {
            switch place {
            case .above:
                subviews.append(view)
            case .below:
                subviews.insert(view, at: 0)
            case .out:
                subviews.append(view)
            }
            return
        }

        switch place {
        case .above:
            subviews.insert(view, at: index + 1)
        case .below:
            subviews.insert(view, at: index)
        case .out:
            subviews.append(view)
        }
    }
}
