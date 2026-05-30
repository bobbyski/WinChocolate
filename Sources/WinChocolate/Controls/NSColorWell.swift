/// A color well control.
///
/// This initial implementation provides AppKit-compatible color state and a
/// clickable native swatch. A shared `NSColorPanel` bridge can layer on later.
open class NSColorWell: NSControl {
    /// The selected color.
    open var color: NSColor {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setBackgroundColor(color, for: nativeHandle)
        }
    }

    /// Whether the color well is active.
    open private(set) var isActive: Bool

    /// Creates a color well with a frame.
    public override init(frame frameRect: NSRect) {
        self.color = .white
        self.isActive = false
        super.init(frame: frameRect)
        self.objectValue = color
    }

    /// Activates the color well.
    open func activate(_ exclusive: Bool) {
        isActive = true
    }

    /// Deactivates the color well.
    open func deactivate() {
        isActive = false
    }

    /// Creates the native swatch peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createImageView(description: "", imagePath: nil, frame: frame, parent: parent)
    }

    /// Ensures the swatch color is synced after realization.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        backend.setBackgroundColor(color, for: handle)
        return handle
    }

    open override func mouseDown(with event: NSEvent) {
        activate(true)
        objectValue = color
        sendAction()
        super.mouseDown(with: event)
    }
}
