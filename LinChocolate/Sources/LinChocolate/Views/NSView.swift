import Foundation

/// AppKit-shaped view. A rectangular region backed by a native container that
/// can host subviews at absolute frames and draw custom content: subclass and
/// override `draw(_:)`, using `NSBezierPath`/`NSColor` in AppKit's bottom-left
/// coordinates.
///
/// Control subclasses (`NSButton`, `NSTextField`) create their own native
/// control through the backend and hand its handle to the designated
/// initializer (controls render natively and do not custom-draw).
open class NSView {

    /// The view's frame in its parent's coordinate space (AppKit bottom-left
    /// origin). Setting it repositions/resizes the native control.
    public var frame: NSRect {
        didSet {
            backend.setFrame(frame, for: handle)
            layout()
        }
    }

    /// Lays out subviews after a frame change (AppKit's `layout()`). The base
    /// implementation does nothing; containers that position their own children
    /// (e.g. `NSStackView`) override it.
    open func layout() {}

    /// The view's bounds — its own coordinate space, origin at (0, 0).
    open var bounds: NSRect { NSMakeRect(0, 0, frame.width, frame.height) }

    /// Whether the view is hidden.
    public var isHidden: Bool = false {
        didSet { backend.setHidden(isHidden, for: handle) }
    }

    /// The view's background color; nil clears it (painted natively via CSS).
    public var backgroundColor: NSColor? {
        didSet { backend.setBackgroundColor(backgroundColor, for: handle) }
    }

    /// The tooltip shown on hover.
    public var toolTip: String?

    /// The key-view loop links (AppKit's focus chain). Stored for API parity;
    /// native focus traversal is a later item.
    public weak var nextKeyView: NSView?
    public weak var previousKeyView: NSView?

    /// The view's identifier (AppKit's `NSUserInterfaceItemIdentifier`).
    public var identifier: String?

    /// Opaque backend handle for this view. Exposed for advanced/testing use
    /// (e.g. simulating input against a specific control).
    public let handle: NativeHandle

    /// The backend that owns this view's native control.
    let backend: NativeControlBackend

    /// Views added via `addSubview(_:)`, in back-to-front order.
    public private(set) var subviews: [NSView] = []

    /// Whether the control accepts input.
    public var isEnabled: Bool = true {
        didSet { backend.setEnabled(isEnabled, for: handle) }
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
    public required init(frame: NSRect) {
        self.frame = frame
        self.backend = NSApplication.shared.nativeBackend
        self.handle = backend.createView(frame: frame)
        backend.setDrawHandler(for: handle) { [weak self] native, width, height in
            guard let self else { return }
            NSGraphicsContext.setCurrent(NSGraphicsContext(native: native))
            self.draw(NSMakeRect(0, 0, width, height))
            NSGraphicsContext.setCurrent(nil)
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

    public func addSubview(_ view: NSView) {
        subviews.append(view)
        view.superview = self
        // Record this parent's flip (for positioning children) and the child's
        // own flip (for its own drawing coordinate space).
        backend.setViewFlipped(isFlipped, for: handle)
        backend.setViewFlipped(view.isFlipped, for: view.handle)
        backend.addSubview(view.handle, to: handle)
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

    public var leadingAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: self, attribute: .leading) }
    public var trailingAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: self, attribute: .trailing) }
    public var leftAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: self, attribute: .left) }
    public var rightAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: self, attribute: .right) }
    public var centerXAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: self, attribute: .centerX) }
    public var topAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor(item: self, attribute: .top) }
    public var bottomAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor(item: self, attribute: .bottom) }
    public var centerYAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor(item: self, attribute: .centerY) }
    public var widthAnchor: NSLayoutDimension { NSLayoutDimension(item: self, attribute: .width) }
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
            if let entered = self.onDraggingEntered, entered(info) == .none { return false }
            return self.onPerformDragOperation?(info) ?? false
        }
    }

    /// Makes this view a drag source that carries the string returned by
    /// `provider` when the user drags it (`nil` cancels the drag). The
    /// pragmatic Linux shape of AppKit's `NSDraggingSource` /
    /// `beginDraggingSession` — GTK initiates the drag from the widget itself.
    public func registerDraggingSource(_ provider: @escaping () -> String?) {
        backend.registerDragSource(for: handle, provider: provider)
    }

    // MARK: - Responder / event surface (NSResponder)
    //
    // Override points so AppKit-shaped custom views compile and can be routed to
    // later. Native GTK controls handle their own input; actual delivery to
    // these is a later parity item — they exist so the same source builds.

    open var acceptsFirstResponder: Bool { false }
    @discardableResult open func becomeFirstResponder() -> Bool { true }
    @discardableResult open func resignFirstResponder() -> Bool { true }

    open func mouseDown(with event: NSEvent) {}
    open func mouseUp(with event: NSEvent) {}
    open func mouseDragged(with event: NSEvent) {}
    open func mouseMoved(with event: NSEvent) {}
    open func mouseEntered(with event: NSEvent) {}
    open func mouseExited(with event: NSEvent) {}
    open func rightMouseDown(with event: NSEvent) {}
    open func scrollWheel(with event: NSEvent) {}
    open func keyDown(with event: NSEvent) {}
    open func keyUp(with event: NSEvent) {}

    open func resetCursorRects() {}
    open func addCursorRect(_ rect: NSRect, cursor: NSCursor) {}
    open func updateTrackingAreas() {}
    public private(set) var trackingAreas: [NSTrackingArea] = []
    public func addTrackingArea(_ area: NSTrackingArea) { trackingAreas.append(area) }
    public func removeTrackingArea(_ area: NSTrackingArea) { trackingAreas.removeAll { $0 === area } }

    /// Point conversion (identity stub — LinChocolate views currently share the
    /// window's coordinate space).
    public func convert(_ point: NSPoint, from view: NSView?) -> NSPoint { point }
    public func convert(_ point: NSPoint, to view: NSView?) -> NSPoint { point }

    // Drag-destination method form (mirrors the `onDraggingEntered` closures).
    open func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    open func draggingExited(_ sender: NSDraggingInfo?) {}
    open func performDragOperation(_ sender: NSDraggingInfo) -> Bool { false }
}
