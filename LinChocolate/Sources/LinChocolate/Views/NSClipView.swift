import Foundation

/// AppKit-shaped clip view — the scrolling viewport of an `NSScrollView`.
///
/// Two modes:
/// - **Bound** (`init(scrollView:)`): a facade over the enclosing scroll view.
///   GTK's `GtkScrolledWindow` bundles the clip and scrollers into one widget,
///   so `bounds.origin` is the scroll offset (like AppKit's flipped clip view,
///   y grows downward) and `bounds.size` is the visible size.
/// - **Standalone** (`init(frame:)`): a plain clipping container the demo builds
///   directly; it hosts a `documentView` as its child.
public final class NSClipView: NSView {

    /// AppKit's `NSClipView` is flipped — its document scrolls in top-left
    /// coordinates (y grows downward), which is what makes `scroll(to:)` and
    /// the demo's pane layout line up. Without this an oversized document is
    /// bottom-anchored, so "home" showed the document's bottom edge.
    public override var isFlipped: Bool { true }

    /// The clip view's background fill (real AppKit API on this class).
    public var backgroundColor: NSColor? {
        didSet { backend.setBackgroundColor(backgroundColor, for: handle) }
    }
    private unowned var owner: NSScrollView?

    init(scrollView: NSScrollView) {
        self.owner = scrollView
        super.init(frame: .zero)
    }

    public required init(frame: NSRect) {
        self.owner = nil
        super.init(frame: frame)
        clipsToBounds = true   // a standalone clip view clips its oversized document
    }

    private var _documentView: NSView?
    /// The scroll offset of a standalone clip view (document coordinates).
    private var _scrollOffset: NSPoint = .zero

    /// The scrolled document. Bound: the scroll view's `documentView`.
    /// Standalone: the hosted child view.
    public var documentView: NSView? {
        get { owner?.documentView ?? _documentView }
        set {
            guard owner == nil else { return }
            _documentView?.removeFromSuperview()
            _documentView = newValue
            if let view = newValue { addSubview(view) }
        }
    }

    /// The visible rectangle in document coordinates: origin = scroll offset,
    /// size = viewport size. Standalone: the view's own bounds.
    public override var bounds: NSRect {
        guard let owner else {
            // Standalone: origin is the scroll offset, size is the viewport.
            return NSMakeRect(_scrollOffset.x, _scrollOffset.y, frame.width, frame.height)
        }
        let offset = owner.backend.scrollOffset(for: owner.handle)
        let size = owner.backend.scrollVisibleSize(for: owner.handle)
        return NSMakeRect(offset.x, offset.y, size.width, size.height)
    }

    /// The full document rectangle (origin zero, document size).
    public var documentRect: NSRect {
        guard let owner else {
            let s = _documentView?.frame.size ?? frame.size
            return NSMakeRect(0, 0, s.width, s.height)
        }
        let size = owner.backend.scrollDocumentSize(for: owner.handle)
        return NSMakeRect(0, 0, size.width, size.height)
    }

    /// The visible document rectangle (AppKit's `documentVisibleRect`).
    public var documentVisibleRect: NSRect { bounds }

    /// Scrolls so the document point `point` is at the viewport's top-left.
    public func scroll(to point: NSPoint) {
        guard let owner else {
            // Standalone: move the document so `point` sits at the origin,
            // clamped to the document's extent — the clip mask (clipsToBounds)
            // hides the part that scrolls out.
            _scrollOffset = clampedOffset(point)
            if let document = _documentView {
                document.frame = NSMakeRect(-_scrollOffset.x, -_scrollOffset.y,
                                            document.frame.width, document.frame.height)
            }
            return
        }
        owner.backend.setScrollOffset(x: Double(point.x), y: Double(point.y), for: owner.handle)
    }

    /// Keeps a scroll offset within `[0, documentSize - viewportSize]`.
    private func clampedOffset(_ point: NSPoint) -> NSPoint {
        let doc = _documentView?.frame.size ?? frame.size
        let maxX = max(0, doc.width - frame.width)
        let maxY = max(0, doc.height - frame.height)
        return NSMakePoint(min(max(0, point.x), maxX), min(max(0, point.y), maxY))
    }
}
