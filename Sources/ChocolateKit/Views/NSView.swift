/// Base class for visible rectangular content.
///
/// `NSView` owns a frame, a child hierarchy, and a lazily-created native peer.
/// Subclasses override `realizeNativePeer(in:)` to request a specific Windows
/// control kind while keeping AppKit-style view composition at the public API.
open class NSView: NSResponder {
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
            // Assigning the same frame is a no-op, as in AppKit. Layout runs
            // on every scroll/resize and re-assigns identical frames to views
            // that did not move; pushing those to the backend would repaint
            // (and flicker) every control each pass, so skip unchanged frames.
            guard frame != oldValue else {
                return
            }

            autoresizeSubviews(from: oldValue.size, to: frame.size)

            // AppKit runs layout after a frame-size change; container views
            // (scroll/split/browser) re-tile their children then. Fire an
            // internal hook so those subclasses re-lay out when their own frame
            // is resized by a layout system, not only at init/add.
            if frame.size != oldValue.size {
                winLayoutAfterFrameSizeChange()
            }

            if postsFrameChangedNotifications {
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
    /// The insets the system's own furniture claims from this view's bounds.
    ///
    /// Zero everywhere the Chocolate backends run, and that is the true answer
    /// rather than a placeholder: none of them has a notch, a home indicator or
    /// a full-height sidebar overlapping the content. The property exists so
    /// layout written against AppKit's safe area does the same arithmetic on
    /// every platform instead of branching around a missing name.
    open var safeAreaInsets: NSEdgeInsets { NSEdgeInsetsZero }

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
    public internal(set) weak var superview: NSView?

    /// The view's child views.
    public internal(set) var subviews: [NSView] = []

    /// The next view in the keyboard focus loop. Setting it maintains the
    /// reverse link, so `previousKeyView` is derived — matching AppKit, where
    /// only `nextKeyView` is settable.
    open weak var nextKeyView: NSView? {
        didSet {
            oldValue?.winPreviousKeyView = nil
            nextKeyView?.winPreviousKeyView = self
        }
    }

    /// Backing storage for the derived reverse key-loop link.
    weak var winPreviousKeyView: NSView?

    /// The link the window's focus walk follows. Composed containers
    /// (`NSForm`, `NSMatrix`) override this to route Tab into their child
    /// controls while `nextKeyView` keeps Apple's read-back semantics.
    var winEffectiveNextKeyView: NSView? {
        nextKeyView
    }

    /// Whether the focus walk may land on this view's focusable descendants
    /// when the view itself refuses focus. Composed containers that manage
    /// their own key loop (`NSForm`, `NSMatrix`) return `false` so the walk
    /// passes through them instead of re-entering their children.
    var winShouldDescendInKeyLoop: Bool {
        true
    }

    /// The previous view in the keyboard focus loop — **get-only**, as in
    /// AppKit (derived from the `nextKeyView` chain).
    open var previousKeyView: NSView? {
        winPreviousKeyView
    }

    /// The nearest containing window, when this view is attached to one.
    open var window: NSWindow? {
        if let superview {
            return superview.window
        }

        return nextResponder as? NSWindow
    }

    /// The backend-created native handle, if realized.
    public internal(set) var nativeHandle: NativeHandle?

    /// Backend that created the native peer, if realized.
    public internal(set) weak var realizedBackend: NativeControlBackend?

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

    /// The view's background fill, when explicitly set.
    ///
    /// Not public API: AppKit's `NSView` has no `winBackgroundColor` (18.2) —
    /// only concrete types like `NSTextField`, `NSTableRowView`, and
    /// `NSPathControl` expose one, and those forward here. `package` so the
    /// contract tests can probe framework chrome fills.
    package var winBackgroundColor: NSColor? {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setBackgroundColor(winBackgroundColor, for: nativeHandle)
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

    /// The distance from the view's bottom edge up to its text baseline, used
    /// by baseline anchors and baseline alignment. A plain view's baseline is
    /// its bottom edge (0), matching AppKit; text controls override with a
    /// descent-derived offset.
    open var baselineOffsetFromBottom: CGFloat { 0 }

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

    /// Framework-internal hook fired from `frame`'s observer when the view's
    /// *size* changes. Container views (`NSScrollView`, `NSSplitView`, …)
    /// override it to re-tile/re-layout their children on resize — AppKit does
    /// the equivalent by running `layout()`. Not public API (no consumer surface).
    func winLayoutAfterFrameSizeChange() {}

    /// Called after the view's effective appearance changes — a live system
    /// dark/light switch, or an `appearance` override taking effect. The base
    /// does nothing; subclasses override to refresh appearance-derived state.
    /// The framework's own windows and controls are already re-themed by the
    /// time this runs. `@MainActor` to match AppKit's annotation, so app
    /// overrides read the same on every target.
    @MainActor open func viewDidChangeEffectiveAppearance() {}

    /// Framework-internal: fans `viewDidChangeEffectiveAppearance()` out over
    /// this view and its whole subtree on a live theme switch.
    @MainActor func winPropagateEffectiveAppearanceChange() {
        viewDidChangeEffectiveAppearance()
        for subview in subviews {
            subview.winPropagateEffectiveAppearanceChange()
        }
    }

    /// The view's context menu, shown on right-click when set.
    open var menu: NSMenu?

    /// Shows the view's context menu on right-click, matching AppKit's
    /// default responder behavior; without a menu the event travels up the
    /// responder chain as before.
    open override func rightMouseDown(with event: NSEvent) {
        winRightMouseDown(with: event)
    }

    // MARK: - Accessibility (NSAccessibilityProtocol)
    //
    // Every view exposes AppKit's informal accessibility protocol. Each getter
    // returns the app's explicit override when one was set (via the matching
    // setter), otherwise the view's *intrinsic* value — the `winIntrinsic…`
    // hooks, which subclasses (controls, data views) override to describe
    // themselves. This mirrors AppKit, where `setAccessibilityRole(_:)` wins
    // over a subclass's built-in role and a plain override of `accessibilityRole()`
    // replaces both. The values feed the native UIA/WM_GETOBJECT bridge and the
    // deterministic `winAccessibilitySnapshot()` used by the contract tests.

    var storedAccessibilityLabel: String?
    private var storedAccessibilityTitle: String?
    private var storedAccessibilityValue: Any?
    private var storedAccessibilityHelp: String?
    private var storedAccessibilityRole: NSAccessibilityRole?
    private var storedAccessibilitySubrole: NSAccessibilitySubrole?
    private var storedAccessibilityRoleDescription: String?
    private var storedIsAccessibilityElement: Bool?
    private var storedIsAccessibilityEnabled: Bool?
    private var storedAccessibilityChildren: [NSAccessibilityProtocol]?
    private var storedAccessibilityIdentifier: String?

    // Intrinsic values a subclass supplies for itself. NSView is a generic
    // container: not an element, role .group, no title/value of its own.
    /// The role this view reports when the app has not overridden it.
    open var winIntrinsicAccessibilityRole: NSAccessibilityRole { .group }
    /// The subrole this view reports when the app has not overridden it.
    open var winIntrinsicAccessibilitySubrole: NSAccessibilitySubrole? { nil }
    /// The label this view reports when the app has not overridden it.
    open var winIntrinsicAccessibilityLabel: String? { nil }
    /// The title this view reports when the app has not overridden it.
    open var winIntrinsicAccessibilityTitle: String? { nil }
    /// The value this view reports when the app has not overridden it.
    open var winIntrinsicAccessibilityValue: Any? { nil }
    /// Whether this view is itself an accessibility element (a leaf assistive
    /// technology can land on). Containers return false; controls return true.
    open var winIsIntrinsicAccessibilityElement: Bool { false }

    /// Sets the accessibility label read by assistive technology. When the view
    /// is realized over a native control, the label is pushed to the backend so
    /// the OS accessibility layer (MSAA/UIA) reads the app's label rather than
    /// the control's window text.
    open func setAccessibilityLabel(_ label: String?) {
        storedAccessibilityLabel = label
        if let nativeHandle {
            realizedBackend?.setAccessibilityName(label, for: nativeHandle)
        }
    }

    /// The accessibility label read by assistive technology.
    open func accessibilityLabel() -> String? {
        storedAccessibilityLabel ?? winIntrinsicAccessibilityLabel
    }

    /// Sets the accessibility title (the element's own text, e.g. a button's).
    open func setAccessibilityTitle(_ title: String?) { storedAccessibilityTitle = title }

    /// The accessibility title read by assistive technology.
    open func accessibilityTitle() -> String? {
        storedAccessibilityTitle ?? winIntrinsicAccessibilityTitle
    }

    /// Sets the accessibility value read by assistive technology.
    open func setAccessibilityValue(_ value: Any?) { storedAccessibilityValue = value }

    /// The accessibility value read by assistive technology.
    open func accessibilityValue() -> Any? {
        storedAccessibilityValue ?? winIntrinsicAccessibilityValue
    }

    /// Sets the accessibility help text read by assistive technology.
    open func setAccessibilityHelp(_ help: String?) { storedAccessibilityHelp = help }

    /// The accessibility help text read by assistive technology.
    open func accessibilityHelp() -> String? {
        storedAccessibilityHelp ?? toolTip
    }

    /// Sets the accessibility role, overriding the view's intrinsic role.
    open func setAccessibilityRole(_ role: NSAccessibilityRole?) { storedAccessibilityRole = role }

    /// The accessibility role read by assistive technology.
    open func accessibilityRole() -> NSAccessibilityRole? {
        storedAccessibilityRole ?? winIntrinsicAccessibilityRole
    }

    /// Sets the accessibility subrole.
    open func setAccessibilitySubrole(_ subrole: NSAccessibilitySubrole?) { storedAccessibilitySubrole = subrole }

    /// The accessibility subrole read by assistive technology.
    open func accessibilitySubrole() -> NSAccessibilitySubrole? {
        storedAccessibilitySubrole ?? winIntrinsicAccessibilitySubrole
    }

    /// Sets a custom role description.
    open func setAccessibilityRoleDescription(_ description: String?) { storedAccessibilityRoleDescription = description }

    /// The human-readable role description assistive technology speaks.
    open func accessibilityRoleDescription() -> String? {
        storedAccessibilityRoleDescription ?? accessibilityRole()?.winDefaultRoleDescription
    }

    /// Overrides whether the view is an accessibility element.
    open func setAccessibilityElement(_ isElement: Bool) { storedIsAccessibilityElement = isElement }

    /// Whether assistive technology treats this view as a navigable element.
    open func isAccessibilityElement() -> Bool {
        storedIsAccessibilityElement ?? winIsIntrinsicAccessibilityElement
    }

    /// Overrides the element's enabled state as reported to assistive technology.
    open func setAccessibilityEnabled(_ enabled: Bool) { storedIsAccessibilityEnabled = enabled }

    /// Whether the element is enabled for assistive technology.
    open func isAccessibilityEnabled() -> Bool {
        storedIsAccessibilityEnabled ?? winIntrinsicAccessibilityEnabled
    }

    /// The intrinsic enabled state; controls override to reflect `isEnabled`.
    open var winIntrinsicAccessibilityEnabled: Bool { true }

    /// A stable identifier for the element (AppKit's `accessibilityIdentifier`).
    open var accessibilityIdentifier: String {
        get { storedAccessibilityIdentifier ?? identifier?.rawValue ?? "" }
        set { storedAccessibilityIdentifier = newValue }
    }

    /// Overrides the element's children in the accessibility tree.
    open func setAccessibilityChildren(_ children: [NSAccessibilityProtocol]?) {
        storedAccessibilityChildren = children
    }

    /// The app-set children override, if any (`nil` means "use the default
    /// tree"). Data views consult this so an explicit override still wins over
    /// their synthesized row/cell elements.
    public var winExplicitAccessibilityChildren: [NSAccessibilityProtocol]? {
        storedAccessibilityChildren
    }

    /// The element's children in the accessibility tree. By default these are
    /// the subviews that are visible; data views override this to synthesize
    /// row/cell elements for content they draw themselves.
    open func accessibilityChildren() -> [Any]? {
        if let storedAccessibilityChildren { return storedAccessibilityChildren }
        let kids = subviews.filter { !$0.isHidden }
        return kids.isEmpty ? nil : kids
    }

    /// The element's frame in screen/window coordinates for hit-testing by
    /// assistive technology. We report window-relative coordinates, which the
    /// native bridge maps to screen space.
    open func accessibilityFrame() -> NSRect {
        convert(bounds, to: nil)
    }

    /// The view's mouse-tracking areas.
    public private(set) var trackingAreas: [NSTrackingArea] = []

    // Tracking areas currently containing the cursor, by object identity.
    var hoveredTrackingAreas: Set<ObjectIdentifier> = []

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
    /// Gesture recognizers attached through `addGestureRecognizer`; the
    /// view forwards its mouse events to each (see NSGestureRecognizer.swift).
    var winGestureRecognizers: [NSGestureRecognizer] = []

    /// Forwards a press to attached gesture recognizers, then up the chain.
    open override func mouseDown(with event: NSEvent) {
        winMouseDown(with: event)
    }

    /// Forwards a drag to attached gesture recognizers, then up the chain.
    open override func mouseDragged(with event: NSEvent) {
        winMouseDragged(with: event)
    }

    /// Forwards a release to attached gesture recognizers, then up the chain.
    open override func mouseUp(with event: NSEvent) {
        winMouseUp(with: event)
    }

    /// Resolves hover state against the tracking areas for a mouse position,
    /// sending `mouseEntered`/`mouseExited` to each area's owner — and
    /// `mouseMoved` to owners of areas that asked for movement.
    /// Exits every hovered tracking area (the cursor left the view entirely).
    /// The responder that receives an area's tracking events.
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

    /// `required` so a view class registered with `NSCollectionView`'s
    /// `register(_:forSupplementaryViewOfKind:withIdentifier:)` can be built
    /// from its metatype in `makeSupplementaryView`, matching the same reason
    /// `NSCollectionViewItem.init()` is required.
    ///
    /// Apple's NSView does not need this: AppKit instantiates registered
    /// classes through the Objective-C runtime (`[[cls alloc] initWithFrame:]`),
    /// which has no Swift `required` rule. In pure Swift there is no such
    /// escape hatch, so the modifier is an implementation necessity rather than
    /// a divergence in the public API's shape — it constrains subclasses inside
    /// the framework, not callers. See Issue N in
    /// `Docs/AppKitFaithfulnessIssues.md`.
    public required init(frame frameRect: NSRect) {
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
        winAddSubview(view, positioned: place, relativeTo: otherView)
    }

    /// Replaces one child view with another while preserving the child position.
    open func replaceSubview(_ oldView: NSView, with newView: NSView) {
        winReplaceSubview(oldView, with: newView)
    }

    /// Removes the view from its parent hierarchy.
    open func removeFromSuperview() {
        winRemoveFromSuperview()
    }

    /// Marks the view as needing display.
    open func setNeedsDisplay(_ needsDisplay: Bool) {
        self.needsDisplay = needsDisplay
    }

    /// Returns true when this view is contained by the given ancestor.
    open func isDescendant(of view: NSView) -> Bool {
        winIsDescendant(of: view)
    }

    /// Finds the first view in this hierarchy with the given tag.
    open func viewWithTag(_ tag: Int) -> NSView? {
        winViewWithTag(tag)
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
        winHitTest(point)
    }

    /// Ensures the view and its children have native peers.
    @discardableResult
    open func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        winNSViewRealizeNativePeer(in: backend, parent: parent)
    }

    // MARK: - Cursor rectangles

    var cursorRects: [(rect: NSRect, cursor: NSCursor)] = []

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
    /// Rebuilds this view's cursor rectangles (via `resetCursorRects()`) and
    /// returns them as backend regions. Exposed so the cursor behavior can be
    /// verified without a realized native peer.
    public func winResolvedCursorRegions() -> [NativeCursorRegion] {
        discardCursorRects()
        resetCursorRects()
        return cursorRects.map { NativeCursorRegion(rect: $0.rect, cursorName: $0.cursor.cursorName) }
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
        winScrollToVisible(rect)
    }

    /// Gives this view and its subtree a chance to consume a key equivalent.
    ///
    /// Subviews are asked depth-first before the main menu sees the event,
    /// matching AppKit's dispatch order. The base implementation only
    /// forwards; views with their own shortcuts override and return `true`
    /// when they handle the event.
    open func performKeyEquivalent(with event: NSEvent) -> Bool {
        winPerformKeyEquivalent(with: event)
    }

    /// Draws the view's custom content.
    ///
    /// Called during a native paint pass with `NSGraphicsContext.current`
    /// installed, after the view's `winBackgroundColor` has been painted.
    /// Subclasses override this and draw with `NSBezierPath`, `NSColor`, and
    /// `NSRect.fill()`; the base implementation draws nothing.
    open func draw(_ dirtyRect: NSRect) {
    }


    /// Creates the native peer for this specific view type.
    open func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createView(frame: frame, parent: parent)
    }

    /// Destroys the native peer for this view and its children.
    open func destroyNativePeer() {
        winDestroyNativePeer()
    }

}
