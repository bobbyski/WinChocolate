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
        didSet { backend.setFrame(frame, for: handle) }
    }

    /// The view's bounds — its own coordinate space, origin at (0, 0).
    public var bounds: NSRect { NSMakeRect(0, 0, frame.width, frame.height) }

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
    public init(frame: NSRect) {
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
    public func addSubview(_ view: NSView) {
        subviews.append(view)
        backend.addSubview(view.handle, to: handle)
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
}
