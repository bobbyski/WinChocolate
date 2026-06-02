/// A scrolling container for a document view.
open class NSScrollView: NSView {
    /// The clip view that hosts the document view.
    open var contentView: NSClipView {
        didSet {
            oldValue.removeFromSuperview()
            oldValue.onScroll = nil
            contentView.frame = bounds
            installClipViewScrollCallback()
            addSubview(contentView)
            syncNativeScrollState()
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
            syncNativeScrollState()
        }
    }

    /// Creates a scroll view with a default clip view.
    public override init(frame frameRect: NSRect) {
        self.contentView = NSClipView(frame: NSRect(origin: NSZeroPoint, size: frameRect.size))
        super.init(frame: frameRect)
        installClipViewScrollCallback()
        addSubview(contentView)
    }

    /// Creates the native scroll-view peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createScrollView(frame: frame, parent: parent, hasVerticalScroller: hasVerticalScroller, hasHorizontalScroller: hasHorizontalScroller)
    }

    /// Ensures native scroll bar actions move the AppKit clip-view origin.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        syncNativeScrollState()
        backend.registerAction(for: handle) { [weak self, weak backend] in
            guard let self, let backend, let nativeHandle = self.nativeHandle else {
                return
            }

            self.contentView.scroll(to: backend.scrollViewContentOffset(for: nativeHandle))
        }
        return handle
    }

    /// Updates the clip view to match the scroll view's bounds.
    open func tile() {
        contentView.frame = bounds
        syncNativeScrollState()
    }

    /// Scrolls the document to a point in document coordinates.
    open func scroll(_ point: NSPoint) {
        contentView.scroll(to: point)
    }

    private func installClipViewScrollCallback() {
        contentView.onScroll = { [weak self] origin in
            guard let self, let nativeHandle = self.nativeHandle else {
                return
            }

            self.realizedBackend?.setScrollViewContentOffset(origin, for: nativeHandle)
        }
    }

    private func syncNativeScrollState() {
        guard let nativeHandle else {
            return
        }

        let contentSize = documentView?.frame.size ?? contentView.bounds.size
        realizedBackend?.setScrollViewContentSize(
            contentSize,
            viewportSize: contentView.bounds.size,
            hasVerticalScroller: hasVerticalScroller,
            hasHorizontalScroller: hasHorizontalScroller,
            for: nativeHandle
        )
        realizedBackend?.setScrollViewContentOffset(contentView.boundsOrigin, for: nativeHandle)
    }
}
