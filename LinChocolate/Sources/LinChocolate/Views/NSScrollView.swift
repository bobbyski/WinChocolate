import Foundation

/// AppKit-shaped scroll container (GtkScrolledWindow). Set `documentView` to a
/// view larger than the scroll view's frame and the native container provides
/// the scrollbars and scrolling. `contentView` (an `NSClipView`) exposes the
/// scroll offset; `verticalScroller`/`horizontalScroller` expose the knobs.
public final class NSScrollView: NSView {

    /// The scrolled content.
    public var documentView: NSView? {
        didSet {
            guard let documentView else { return }
            backend.setContentView(documentView.handle, for: handle)
        }
    }

    /// The clip view (viewport) — its `bounds.origin` is the scroll offset.
    public private(set) lazy var contentView = NSClipView(scrollView: self)

    /// The vertical scroller.
    public private(set) lazy var verticalScroller = NSScroller(scrollView: self, vertical: true)

    /// The horizontal scroller.
    public private(set) lazy var horizontalScroller = NSScroller(scrollView: self, vertical: false)

    /// Whether the vertical scroller may appear (shown when the content needs it).
    public var hasVerticalScroller = true { didSet { applyScrollerPolicy() } }

    /// Whether the horizontal scroller may appear.
    public var hasHorizontalScroller = true { didSet { applyScrollerPolicy() } }

    /// The visible portion of the document, in document coordinates.
    public var documentVisibleRect: NSRect { contentView.bounds }

    /// Fired when the user (or `scroll(to:)`) changes the scroll offset.
    public var onScroll: ((NSPoint) -> Void)?

    /// Creates an empty scroll view.
    public override init(frame: NSRect) {
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createScrollView(frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
        backend.setScrollChangeAction(for: handle) { [weak self] x, y in
            self?.onScroll?(NSMakePoint(CGFloat(x), CGFloat(y)))
        }
    }

    /// Scrolls the content so `point` is at the viewport's top-left.
    public func scroll(to point: NSPoint) {
        contentView.scroll(to: point)
    }

    private func applyScrollerPolicy() {
        backend.setScrollerPolicy(vertical: hasVerticalScroller,
                                  horizontal: hasHorizontalScroller, for: handle)
    }
}
