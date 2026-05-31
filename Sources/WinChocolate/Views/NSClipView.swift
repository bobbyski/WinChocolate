/// The clipping viewport used by `NSScrollView`.
///
/// AppKit exposes `NSClipView` as the scroll view's content view. This first
/// slice keeps document hosting and bounds-origin state in Swift while native
/// backends continue to provide a simple child view peer.
open class NSClipView: NSView {
    /// The view shown inside the clip view.
    open var documentView: NSView? {
        didSet {
            oldValue?.removeFromSuperview()
            guard let documentView else {
                return
            }

            addSubview(documentView)
            positionDocumentView()
        }
    }

    /// The current document-space origin visible in the clip view.
    open var boundsOrigin: NSPoint {
        didSet {
            positionDocumentView()
        }
    }

    /// The visible document rectangle.
    open var documentVisibleRect: NSRect {
        NSRect(origin: boundsOrigin, size: bounds.size)
    }

    /// Creates a clip view with a frame.
    public override init(frame frameRect: NSRect) {
        self.boundsOrigin = NSZeroPoint
        super.init(frame: frameRect)
    }

    /// Clip views are internal viewport containers and skip normal focus.
    open override var acceptsFirstResponder: Bool {
        false
    }

    /// Scrolls the document to a document-space point.
    open func scroll(to newOrigin: NSPoint) {
        boundsOrigin = constrainBoundsRect(NSRect(origin: newOrigin, size: bounds.size)).origin
    }

    /// Constrains a proposed visible rectangle to the current document extent.
    open func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        guard let documentView else {
            return NSRect(origin: NSZeroPoint, size: proposedBounds.size)
        }

        let maxX = max(0, documentView.frame.size.width - frame.size.width)
        let maxY = max(0, documentView.frame.size.height - frame.size.height)
        let origin = NSPoint(
            x: min(max(proposedBounds.origin.x, 0), maxX),
            y: min(max(proposedBounds.origin.y, 0), maxY)
        )
        return NSRect(origin: origin, size: proposedBounds.size)
    }

    /// Creates the native viewport peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createView(frame: frame, parent: parent)
    }

    private func positionDocumentView() {
        guard let documentView else {
            return
        }

        let constrained = constrainBoundsRect(NSRect(origin: boundsOrigin, size: bounds.size))
        if constrained.origin != boundsOrigin {
            boundsOrigin = constrained.origin
            return
        }

        documentView.frame = NSMakeRect(
            -boundsOrigin.x,
            -boundsOrigin.y,
            documentView.frame.size.width,
            documentView.frame.size.height
        )
    }
}
