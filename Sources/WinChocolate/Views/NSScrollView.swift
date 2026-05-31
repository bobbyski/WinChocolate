/// A scrolling container for a document view.
open class NSScrollView: NSView {
    /// The clip view that hosts the document view.
    open var contentView: NSClipView {
        didSet {
            oldValue.removeFromSuperview()
            contentView.frame = bounds
            addSubview(contentView)
        }
    }

    /// Whether a vertical scroller should be shown.
    open var hasVerticalScroller: Bool = false

    /// Whether a horizontal scroller should be shown.
    open var hasHorizontalScroller: Bool = false

    /// The scrolled document view.
    open var documentView: NSView? {
        get {
            contentView.documentView
        }
        set {
            contentView.documentView = newValue
        }
    }

    /// Creates a scroll view with a default clip view.
    public override init(frame frameRect: NSRect) {
        self.contentView = NSClipView(frame: NSRect(origin: NSZeroPoint, size: frameRect.size))
        super.init(frame: frameRect)
        addSubview(contentView)
    }

    /// Creates the native scroll-view peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createScrollView(frame: frame, parent: parent, hasVerticalScroller: hasVerticalScroller, hasHorizontalScroller: hasHorizontalScroller)
    }

    /// Updates the clip view to match the scroll view's bounds.
    open func tile() {
        contentView.frame = bounds
    }

    /// Scrolls the document to a point in document coordinates.
    open func scroll(_ point: NSPoint) {
        contentView.scroll(to: point)
    }
}
