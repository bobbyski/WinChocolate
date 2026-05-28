/// Base class for visible rectangular content.
///
/// `NSView` owns a frame, a child hierarchy, and a lazily-created native peer.
/// Subclasses override `realizeNativePeer(in:)` to request a specific Windows
/// control kind while keeping AppKit-style view composition at the public API.
open class NSView: NSResponder {
    /// The view frame in its parent coordinate space.
    open var frame: NSRect {
        didSet {
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

    /// Indicates whether the view needs display.
    public private(set) var needsDisplay = false

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

    /// Creates a view with a frame.
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
        view.removeFromSuperview()
        view.superview = self
        view.nextResponder = self
        subviews.append(view)

        guard let realizedBackend, let nativeHandle else {
            return
        }

        view.realizeNativePeer(in: realizedBackend, parent: nativeHandle)
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
        backend.registerMouseDownAction(for: handle) { [weak self] event in
            _ = self?.window?.makeFirstResponder(self)
            self?.mouseDown(with: event)
        }
        backend.registerMouseUpAction(for: handle) { [weak self] event in
            self?.mouseUp(with: event)
        }
        backend.registerMouseMovedAction(for: handle) { [weak self] event in
            self?.mouseMoved(with: event)
        }
        backend.registerKeyDownAction(for: handle) { [weak self] event in
            self?.keyDown(with: event)
        }
        backend.registerKeyUpAction(for: handle) { [weak self] event in
            self?.keyUp(with: event)
        }

        for subview in subviews {
            subview.realizeNativePeer(in: backend, parent: handle)
        }

        return handle
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
}
