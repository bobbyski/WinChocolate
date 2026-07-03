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

    /// Vertical distance scrolled per wheel line, in points.
    open var verticalLineScroll: CGFloat = 16

    /// Horizontal distance scrolled per wheel line, in points.
    open var horizontalLineScroll: CGFloat = 16

    /// The distance scrolled per wheel line on both axes.
    open var lineScroll: CGFloat {
        get {
            verticalLineScroll
        }
        set {
            verticalLineScroll = newValue
            horizontalLineScroll = newValue
        }
    }

    /// Whether user gestures may change the magnification.
    ///
    /// Programmatic magnification always works; gesture support arrives with
    /// the modern appearance work.
    open var allowsMagnification: Bool = false

    /// The smallest magnification `setMagnification` accepts.
    open var minMagnification: CGFloat = 0.25

    /// The largest magnification `setMagnification` accepts.
    open var maxMagnification: CGFloat = 4

    /// The current document magnification.
    ///
    /// Setting the magnification keeps the center of the visible document
    /// rectangle fixed in the viewport. Magnification scales custom-drawn
    /// document content and the scroll geometry; native child controls
    /// inside the document view do not scale, and event locations remain in
    /// window coordinates.
    open var magnification: CGFloat {
        get {
            contentView.magnification
        }
        set {
            let visible = contentView.documentVisibleRect
            applyMagnification(newValue, centeredAt: NSPoint(x: NSMidX(visible), y: NSMidY(visible)))
        }
    }

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

    /// Lines scrolled per wheel notch, matching the Windows default.
    private static let wheelScrollLinesPerNotch: CGFloat = 3

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
        if contentView.magnification != 1, let documentView, let documentHandle = documentView.nativeHandle {
            backend.setContentScale(contentView.magnification, for: documentHandle)
            backend.setFrame(documentView.frame, for: documentHandle)
        }
        syncNativeScrollState()
        backend.registerAction(for: handle) { [weak self, weak backend] in
            guard let self, let backend, let nativeHandle = self.nativeHandle else {
                return
            }

            // Native scrollbars track magnified pixels; the clip origin
            // stays in document coordinates.
            let offset = backend.scrollViewContentOffset(for: nativeHandle)
            let magnification = self.contentView.magnification
            self.contentView.scroll(to: NSPoint(x: offset.x / magnification, y: offset.y / magnification))
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

    /// Scrolls the document in response to a wheel movement.
    ///
    /// Wheel deltas arrive in lines; holding Shift converts a vertical wheel
    /// to horizontal scrolling, following Windows convention. Scroll
    /// distances stay constant on screen under magnification.
    open override func scrollWheel(with event: NSEvent) {
        var deltaX = event.scrollingDeltaX
        var deltaY = event.scrollingDeltaY
        if event.modifierFlags.contains(.shift), deltaX == 0 {
            (deltaX, deltaY) = (deltaY, 0)
        }

        guard deltaX != 0 || deltaY != 0, documentView != nil else {
            super.scrollWheel(with: event)
            return
        }

        let magnification = contentView.magnification
        let origin = contentView.boundsOrigin
        contentView.scroll(to: NSPoint(
            x: origin.x - deltaX * horizontalLineScroll * Self.wheelScrollLinesPerNotch / magnification,
            y: origin.y - deltaY * verticalLineScroll * Self.wheelScrollLinesPerNotch / magnification
        ))
    }

    /// Magnifies the document, keeping a document-space point fixed in the viewport.
    open func setMagnification(_ magnification: CGFloat, centeredAt point: NSPoint) {
        applyMagnification(magnification, centeredAt: point)
    }

    /// Magnifies so a document rectangle fills the viewport, then scrolls to it.
    open func magnify(toFit rect: NSRect) {
        guard rect.size.width > 0, rect.size.height > 0 else {
            return
        }

        let fit = min(
            contentView.frame.size.width / rect.size.width,
            contentView.frame.size.height / rect.size.height
        )
        applyMagnification(fit, centeredAt: NSPoint(x: NSMidX(rect), y: NSMidY(rect)))
        contentView.scroll(to: rect.origin)
        syncNativeScrollState()
    }

    private func applyMagnification(_ proposed: CGFloat, centeredAt point: NSPoint) {
        let clamped = min(max(proposed, minMagnification), maxMagnification)
        let previous = contentView.magnification
        guard clamped != previous else {
            return
        }

        contentView.magnification = clamped
        if let documentView, let handle = documentView.nativeHandle {
            realizedBackend?.setContentScale(clamped, for: handle)
            realizedBackend?.setFrame(documentView.frame, for: handle)
        }

        // Keep the anchor's viewport position: document-space distances from
        // the origin shrink by the previous/new scale ratio.
        let origin = contentView.boundsOrigin
        contentView.scroll(to: NSPoint(
            x: point.x - (point.x - origin.x) * previous / clamped,
            y: point.y - (point.y - origin.y) * previous / clamped
        ))
        syncNativeScrollState()
        if let documentView, let handle = documentView.nativeHandle {
            realizedBackend?.invalidateControl(handle)
        }
    }

    private func installClipViewScrollCallback() {
        contentView.onScroll = { [weak self] origin in
            guard let self, let nativeHandle = self.nativeHandle else {
                return
            }

            let magnification = self.contentView.magnification
            self.realizedBackend?.setScrollViewContentOffset(
                NSPoint(x: origin.x * magnification, y: origin.y * magnification),
                for: nativeHandle
            )
        }
    }

    private func syncNativeScrollState() {
        guard let nativeHandle else {
            return
        }

        // Native scrollbars work in magnified pixels: the document occupies
        // its logical size times the magnification on screen.
        let magnification = contentView.magnification
        let documentSize = documentView?.frame.size ?? contentView.bounds.size
        realizedBackend?.setScrollViewContentSize(
            NSSize(width: documentSize.width * magnification, height: documentSize.height * magnification),
            viewportSize: contentView.bounds.size,
            hasVerticalScroller: hasVerticalScroller,
            hasHorizontalScroller: hasHorizontalScroller,
            for: nativeHandle
        )
        let origin = contentView.boundsOrigin
        realizedBackend?.setScrollViewContentOffset(
            NSPoint(x: origin.x * magnification, y: origin.y * magnification),
            for: nativeHandle
        )
    }
}
