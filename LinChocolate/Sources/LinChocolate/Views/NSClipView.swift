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
    private unowned var owner: NSScrollView?

    init(scrollView: NSScrollView) {
        self.owner = scrollView
        super.init(frame: .zero)
    }

    public required init(frame: NSRect) {
        self.owner = nil
        super.init(frame: frame)
    }

    private var _documentView: NSView?

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
        guard let owner else { return super.bounds }
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
        guard let owner else { return }
        owner.backend.setScrollOffset(x: Double(point.x), y: Double(point.y), for: owner.handle)
    }
}
