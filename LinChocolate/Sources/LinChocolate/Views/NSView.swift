import Foundation

/// AppKit-shaped view. A rectangular region backed by a native container that
/// can host subviews at absolute frames.
///
/// Subclasses (`NSButton`, `NSTextField`) create their own native control
/// through the backend and hand its handle to the designated initializer.
public class NSView {

    /// The view's frame in its parent's coordinate space.
    public internal(set) var frame: NSRect

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

    /// Creates a plain container view.
    public init(frame: NSRect) {
        self.frame = frame
        self.backend = NSApplication.shared.nativeBackend
        self.handle = backend.createView(frame: frame)
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
}
