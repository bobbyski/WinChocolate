import Foundation

/// AppKit-shaped view. A rectangular region backed by a native container that
/// can host subviews at absolute frames and draw custom content: subclass and
/// override `draw(_:)`, using `NSBezierPath`/`NSColor` in AppKit's bottom-left
/// coordinates.
///
/// Control subclasses (`NSButton`, `NSTextField`) create their own native
/// control through the backend and hand its handle to the designated
/// initializer (controls render natively and do not custom-draw).
open class NSView: NSResponder {

    /// The view's frame in its parent's coordinate space (AppKit bottom-left
    /// origin). Setting it repositions/resizes the native control.
    public var frame: NSRect {
        didSet {
            // A frame the NATIVE side just told us about must not be pushed back
            // as a size request: a request is a floor, so echoing the window's
            // current size would stop the user shrinking it again.
            if suppressFrameSync { return }
            // `isFlipped` is per-view and overridable, so a subclass may compute
            // it rather than return a constant. Re-read both flips that decide
            // this frame's placement (our parent's, for our own Y; and ours, for
            // our children's) instead of trusting what was cached when the view
            // was first added.
            refreshFlips()
            backend.setFrame(frame, for: handle)
            layout()
        }
    }

    private var suppressFrameSync = false

    /// Records a frame the native layout produced, without echoing it back to
    /// the backend. Used when the window resizes its content view.
    func adoptNativeFrame(_ newFrame: NSRect) {
        suppressFrameSync = true
        frame = newFrame
        suppressFrameSync = false
        layout()
    }

    /// Pushes this view's flip, and its parent's, to the backend. Cheap, and it
    /// keeps a dynamic `isFlipped` override honest.
    private func refreshFlips() {
        if let superview {
            backend.setViewFlipped(superview.isFlipped, for: superview.handle)
        }
        backend.setViewFlipped(isFlipped, for: handle)
    }

    /// Lays out subviews after a frame change (AppKit's `layout()`). The base
    /// implementation does nothing; containers that position their own children
    /// (e.g. `NSStackView`) override it.
    open func layout() {}

    /// The size the native side last laid this view out at. Some containers
    /// size their children natively rather than through `frame` — a split
    /// view's panes (AppKit sets pane frames during layout; GtkPaned allocates
    /// widgets directly). Recorded at draw time so `bounds` is truthful.
    var nativeLayoutSize: NSSize = .zero

    /// The view's bounds — its own coordinate space, origin at (0, 0). Falls
    /// back to the native allocation when the frame is zero (natively-sized
    /// children, e.g. split-view panes), so `draw(_:)` code that fills
    /// `bounds` — the demo's colored panes — sees the real size.
    open var bounds: NSRect {
        // The native allocation is the truth about how much space this view
        // actually occupies, so it wins whenever we know it. This matters for any
        // view the container GROWS beyond its frame — above all the window's
        // content view, which expands with the window exactly as AppKit's does
        // (AppKit resizes contentView to fill the window, so its bounds grow).
        // Reporting the frame there made `draw(_:)` paint only the original
        // 1120x760 while the widget was allocated the full window: the rest went
        // unpainted — the "toolbar resizes but the content doesn't" symptom.
        // Frame-placed children are allocated exactly their frame by
        // LinChocolateFixedLayout, so this is a no-op for them.
        if nativeLayoutSize != .zero {
            return NSMakeRect(0, 0, nativeLayoutSize.width, nativeLayoutSize.height)
        }
        return NSMakeRect(0, 0, frame.width, frame.height)
    }

    /// Whether the view is hidden.
    public var isHidden: Bool = false {
        didSet { backend.setHidden(isHidden, for: handle) }
    }

    /// The tooltip shown on hover.
    public var toolTip: String?

    /// Whether subviews are clipped to this view's bounds (AppKit's
    /// `clipsToBounds`). A clip view sets it so its oversized document doesn't
    /// spill past the viewport.
    public var clipsToBounds: Bool = false {
        didSet { backend.setClipsToBounds(clipsToBounds, for: handle) }
    }

    /// The key-view loop links (AppKit's focus chain). Stored for API parity;
    /// native focus traversal is a later item.
    public weak var nextKeyView: NSView?
    public weak var previousKeyView: NSView?

    /// The view's identifier — Apple's exact type (`NSUserInterfaceItemIdentifier?`,
    /// the `NSUserInterfaceItemIdentification` conformance). Was `String?`; the
    /// migration is what lets ONE shared demo source compare identifiers the
    /// same way on AppKit and here (the nib panel's manual wiring).
    public var identifier: NSUserInterfaceItemIdentifier?

    /// Opaque backend handle for this view. Exposed for advanced/testing use
    /// (e.g. simulating input against a specific control).
    public let handle: NativeHandle

    /// The backend that owns this view's native control.
    let backend: NativeControlBackend

    /// Views added via `addSubview(_:)`, in back-to-front order.
    public private(set) var subviews: [NSView] = []

    /// Whether the view is `view` or sits anywhere below it (AppKit's
    /// `isDescendant(of:)` — a view is a descendant of itself).
    public func isDescendant(of view: NSView) -> Bool {
        var current: NSView? = self
        while let candidate = current {
            if candidate === view {
                return true
            }
            current = candidate.superview
        }
        return false
    }


    /// The font for the control's text (nil = platform default).
    public var font: NSFont? {
        didSet {
            guard let font else { return }
            backend.setFont(font.spec, for: handle)
        }
    }

    /// Creates a plain container view (custom drawing enabled).
    ///
    /// `required` so a view class registered with `NSCollectionView`'s
    /// `register(_:forSupplementaryViewOfKind:withIdentifier:)` can be
    /// instantiated from its metatype in `makeSupplementaryView` — AppKit's
    /// contract. Every subclass declaring its own designated initializer must
    /// therefore provide `required init(frame:)` too.
    /// AppKit's parameterless initializer: a zero-frame view, sized later.
    public override convenience init() {
        self.init(frame: .zero)
    }

    /// Creates a view with the given frame.
    public required init(frame: NSRect) {
        self.frame = frame
        self.backend = NSApplication.shared.nativeBackend
        self.handle = backend.createView(frame: frame)
        super.init()
        backend.setDrawHandler(for: handle) { [weak self] native, width, height in
            guard let self else { return }
            self.nativeLayoutSize = NSMakeSize(width, height)
            NSGraphicsContext.setCurrent(NSGraphicsContext(native: native))
            self.draw(NSMakeRect(0, 0, width, height))
            NSGraphicsContext.setCurrent(nil)
        }
        // Pointer events reach the responder methods a subclass overrides
        // (hover box, drag handle, custom canvases). The base impls are no-ops,
        // so this is harmless for plain container views.
        backend.setMouseHandler(for: handle) { [weak self] event in
            guard let self else { return }
            let nsEvent = NSEvent()
            switch event {
            case .entered(let x, let y):
                nsEvent.locationInWindow = NSMakePoint(x, y)
                self.updateTrackingAreas()
                self.mouseEntered(with: nsEvent)
            case .exited:
                self.mouseExited(with: nsEvent)
            case .down(let x, let y, let clickCount, let rightButton):
                nsEvent.locationInWindow = NSMakePoint(x, y)
                nsEvent.clickCount = clickCount
                if rightButton { self.rightMouseDown(with: nsEvent) } else { self.mouseDown(with: nsEvent) }
            case .scroll(let deltaX, let deltaY):
                nsEvent.scrollingDeltaX = deltaX
                nsEvent.scrollingDeltaY = deltaY
                nsEvent.deltaX = deltaX
                nsEvent.deltaY = deltaY
                self.scrollWheel(with: nsEvent)
            }
        }
    }

    /// Draws the view's custom content. Override in subclasses; the default
    /// draws nothing. `NSGraphicsContext.current` is valid during the call.
    open func draw(_ dirtyRect: NSRect) {}

    /// Set to true to request a redraw of custom content.
    public var needsDisplay: Bool {
        get { false }
        set { if newValue { backend.setNeedsDisplay(handle) } }
    }

    /// Designated initializer for subclasses that create their own native
    /// control and already resolved the backend.
    init(frame: NSRect, handle: NativeHandle, backend: NativeControlBackend) {
        self.frame = frame
        self.handle = handle
        self.backend = backend
        super.init()
    }

    /// Adds `view` as a subview, placing it at its frame within this view.
    /// The view's parent in the hierarchy, or nil if unattached.
    public internal(set) weak var superview: NSView?

    /// App-wide default for `isFlipped`. AppKit's default is `false` (bottom-left
    /// origin, +Y up), which the native `LinChocolateDemo` is authored against.
    /// The shared WinChocolate demo is authored top-left (Win32/WinChocolate use
    /// a top-left origin), so `RealDemo` sets this to `true`.
    nonisolated(unsafe) public static var defaultIsFlipped = false

    /// Whether this view uses a top-left origin (AppKit's `NSView.isFlipped`).
    /// When true, a subview's `frame.origin.y` is measured from the top; when
    /// false, from the bottom (AppKit's default). Override in a subclass, or set
    /// `NSView.defaultIsFlipped` to change it app-wide.
    open var isFlipped: Bool { NSView.defaultIsFlipped }

    /// Adds `view` as a subview, placing it at its frame within this view.
    open func addSubview(_ view: NSView) {
        adoptSubview(view)
        backend.addSubview(view.handle, to: handle)
    }

    /// Records `view` in the hierarchy without placing it natively. Containers
    /// whose native side parents children itself (`NSSplitView`'s panes) call
    /// this instead of going through the generic child-area path.
    func adoptSubview(_ view: NSView) {
        subviews.append(view)
        view.superview = self
        // Record this parent's flip (for positioning children) and the child's
        // own flip (for its own drawing coordinate space).
        backend.setViewFlipped(isFlipped, for: handle)
        backend.setViewFlipped(view.isFlipped, for: view.handle)
    }

    /// Detaches the view from its parent. Native detach isn't modeled yet, so
    /// the widget is hidden; the logical hierarchy is updated.
    public func removeFromSuperview() {
        superview?.subviews.removeAll { $0 === self }
        superview = nil
        backend.setHidden(true, for: handle)
    }

    // MARK: - Auto Layout

    /// When true (the AppKit default), the view keeps its manual frame and is
    /// treated as a fixed constant by the solver. Set to false to lay the view
    /// out from constraints via its anchors.
    public var translatesAutoresizingMaskIntoConstraints = true

    /// The view's natural size, or `noIntrinsicMetric` in a dimension it has no
    /// opinion about. Override in content views; unconstrained dimensions fall
    /// back to the current frame rather than this value in the current solver.
    open var intrinsicContentSize: NSSize { NSMakeSize(-1, -1) }

    /// The leading-edge horizontal anchor.
    public var leadingAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: self, attribute: .leading) }
    /// The trailing-edge horizontal anchor.
    public var trailingAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: self, attribute: .trailing) }
    /// The left-edge horizontal anchor.
    public var leftAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: self, attribute: .left) }
    /// The right-edge horizontal anchor.
    public var rightAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: self, attribute: .right) }
    /// The horizontal center anchor.
    public var centerXAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: self, attribute: .centerX) }
    /// The top-edge vertical anchor.
    public var topAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor(item: self, attribute: .top) }
    /// The bottom-edge vertical anchor.
    public var bottomAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor(item: self, attribute: .bottom) }
    /// The vertical center anchor.
    public var centerYAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor(item: self, attribute: .centerY) }
    /// The width dimension anchor.
    public var widthAnchor: NSLayoutDimension { NSLayoutDimension(item: self, attribute: .width) }
    /// The height dimension anchor.
    public var heightAnchor: NSLayoutDimension { NSLayoutDimension(item: self, attribute: .height) }

    /// Adds and activates a constraint (AppKit stores it on the common ancestor;
    /// the process-wide active set makes that ancestor irrelevant here).
    public func addConstraint(_ constraint: NSLayoutConstraint) {
        constraint.isActive = true
    }

    /// Adds and activates several constraints.
    public func addConstraints(_ constraints: [NSLayoutConstraint]) {
        constraints.forEach { $0.isActive = true }
    }

    /// Marks the view as needing a layout pass. A no-op hook for now: layout is
    /// driven explicitly by `layoutSubtreeIfNeeded()` (and window presentation).
    func setNeedsLayout() {}

    /// Resolves active constraints for this view and its descendants, applying
    /// the computed frames.
    public func layoutSubtreeIfNeeded() {
        LayoutSolver.solve(container: self)
    }

    /// The appearance in effect for this view. Application-scoped for now
    /// (per-view overrides are a later parity item), so this follows the app.
    public var effectiveAppearance: NSAppearance {
        NSApplication.shared.effectiveAppearance
    }

    /// AppKit calls this after the view's effective appearance changes (a live
    /// system light/dark switch). Override to refresh appearance-derived colors;
    /// the base does nothing. `@MainActor`, matching AppKit — overrides may touch
    /// main-actor UI state.
    @MainActor
    open func viewDidChangeEffectiveAppearance() {}

    // MARK: - Drag & drop

    /// Called when a drag enters this destination; return the operation to
    /// allow (`.none` rejects the drop). AppKit's `draggingEntered(_:)`.
    public var onDraggingEntered: ((NSDraggingInfo) -> NSDragOperation)?

    /// Called to consume a drop; return whether it was accepted. AppKit's
    /// `performDragOperation(_:)`.
    public var onPerformDragOperation: ((NSDraggingInfo) -> Bool)?

    /// Registers this view as a drop destination for the given types (string
    /// types are honored in this slice). AppKit's `registerForDraggedTypes(_:)`.
    public func registerForDraggedTypes(_ types: [NSPasteboard.PasteboardType]) {
        backend.registerDropTarget(for: handle, types: types.map(\.rawValue)) { [weak self] string, x, y in
            guard let self else { return false }
            let info = DraggingInfo(pasteboard: .transient(string: string),
                                    location: NSMakePoint(x, y))
            // Honor whichever form the view uses: the `on…` closures or the
            // overridable `draggingEntered`/`performDragOperation` methods
            // (the demo's DemoDropWell overrides the methods).
            let op = self.onDraggingEntered?(info) ?? self.draggingEntered(info)
            if op == NSDragOperation.none { return false }
            if let closure = self.onPerformDragOperation { return closure(info) }
            return self.performDragOperation(info)
        }
    }

    /// Makes this view a drag source that carries the string returned by
    /// `provider` when the user drags it (`nil` cancels the drag). The
    /// pragmatic Linux shape of AppKit's `NSDraggingSource` /
    /// `beginDraggingSession` — GTK initiates the drag from the widget itself.
    public func registerDraggingSource(_ provider: @escaping () -> String?) {
        // GtkDragSource is a controller; installing it once is enough. Repeated
        // arming (each mouseDown re-calls beginDraggingSession) must not stack.
        guard !hasDraggingSource else { return }
        hasDraggingSource = true
        backend.registerDragSource(for: handle, provider: provider)
    }
    private var hasDraggingSource = false

    // MARK: - Responder / event surface (NSResponder)
    //
    // Override points so AppKit-shaped custom views compile and can be routed to
    // later. Native GTK controls handle their own input; actual delivery to
    // these is a later parity item — they exist so the same source builds.

    /// Whether the view can become the first responder (default `false`).
    open override var acceptsFirstResponder: Bool { false }
    /// Notifies the view that it became first responder; return `false` to reject.
    @discardableResult open func becomeFirstResponder() -> Bool { true }
    /// Notifies the view that it is losing first-responder status; return `false` to keep it.
    @discardableResult open func resignFirstResponder() -> Bool { true }

    /// Handles a left mouse-down (base: no-op).
    open func mouseDown(with event: NSEvent) {}
    /// Handles a left mouse-up (base: no-op).
    open func mouseUp(with event: NSEvent) {}
    /// Handles a mouse drag (base: no-op).
    open func mouseDragged(with event: NSEvent) {}
    /// Handles mouse movement without a button pressed (base: no-op).
    open func mouseMoved(with event: NSEvent) {}
    /// Handles a mouse-entered event (base: no-op).
    open func mouseEntered(with event: NSEvent) {}
    /// Handles a mouse-exited event (base: no-op).
    open func mouseExited(with event: NSEvent) {}
    /// Handles a right mouse-down (base: no-op).
    open func rightMouseDown(with event: NSEvent) {}
    /// Handles a scroll-wheel event (base: no-op).
    open func scrollWheel(with event: NSEvent) {}
    /// Handles a key-down event (base: no-op).
    open func keyDown(with event: NSEvent) {}
    /// Handles a key-up event (base: no-op).
    open func keyUp(with event: NSEvent) {}

    /// Reinstalls cursor rectangles (base: no-op).
    open func resetCursorRects() {}
    /// Registers a cursor rectangle (accepted for API parity; not implemented).
    open func addCursorRect(_ rect: NSRect, cursor: NSCursor) {}
    /// Rebuilds tracking areas (base: no-op).
    open func updateTrackingAreas() {}
    /// The tracking areas installed on this view.
    public private(set) var trackingAreas: [NSTrackingArea] = []
    /// Installs a tracking area.
    public func addTrackingArea(_ area: NSTrackingArea) { trackingAreas.append(area) }
    /// Removes a previously installed tracking area.
    public func removeTrackingArea(_ area: NSTrackingArea) { trackingAreas.removeAll { $0 === area } }

    /// Point conversion (identity stub — LinChocolate views currently share the
    /// window's coordinate space).
    public func convert(_ point: NSPoint, from view: NSView?) -> NSPoint { point }
    /// Identity stub converting `point` from this view's space to `view`'s space.
    public func convert(_ point: NSPoint, to view: NSView?) -> NSPoint { point }

    // Drag-destination method form (mirrors the `onDraggingEntered` closures).
    /// Called when a drag enters this destination; return the operation to allow.
    open func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    /// Called when a drag leaves this destination without dropping.
    open func draggingExited(_ sender: NSDraggingInfo?) {}
    /// Consumes a drop; return whether it was accepted.
    open func performDragOperation(_ sender: NSDraggingInfo) -> Bool { false }
}
