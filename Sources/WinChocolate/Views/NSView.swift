/// Base class for visible rectangular content.
///
/// `NSView` owns a frame, a child hierarchy, and a lazily-created native peer.
/// Subclasses override `realizeNativePeer(in:)` to request a specific Windows
/// control kind while keeping AppKit-style view composition at the public API.
open class NSView: NSObject {
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

    /// The backend-created native handle, if realized.
    public private(set) var nativeHandle: NativeHandle?

    /// Backend that created the native peer, if realized.
    public private(set) weak var realizedBackend: NativeControlBackend?

    /// Indicates whether the view needs display.
    public private(set) var needsDisplay = false

    /// Creates a view with a frame.
    public init(frame frameRect: NSRect) {
        self.frame = frameRect
        super.init()
    }

    /// Adds a child view.
    open func addSubview(_ view: NSView) {
        view.removeFromSuperview()
        view.superview = self
        subviews.append(view)
    }

    /// Removes the view from its parent hierarchy.
    open func removeFromSuperview() {
        guard let superview else {
            return
        }

        superview.subviews.removeAll { $0 === self }
        self.superview = nil
    }

    /// Marks the view as needing display.
    open func setNeedsDisplay(_ needsDisplay: Bool) {
        self.needsDisplay = needsDisplay
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

        for subview in subviews {
            subview.realizeNativePeer(in: backend, parent: handle)
        }

        return handle
    }

    /// Creates the native peer for this specific view type.
    open func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createView(frame: frame, parent: parent)
    }
}
