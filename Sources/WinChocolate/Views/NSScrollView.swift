/// A scrolling container for a document view.
open class NSScrollView: NSView {
    /// Whether a vertical scroller should be shown.
    open var hasVerticalScroller: Bool = false

    /// Whether a horizontal scroller should be shown.
    open var hasHorizontalScroller: Bool = false

    /// The scrolled document view.
    open var documentView: NSView? {
        didSet {
            oldValue?.removeFromSuperview()
            guard let documentView else {
                return
            }

            addSubview(documentView)
        }
    }

    /// Creates the native scroll-view peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createScrollView(frame: frame, parent: parent, hasVerticalScroller: hasVerticalScroller, hasHorizontalScroller: hasHorizontalScroller)
    }
}
