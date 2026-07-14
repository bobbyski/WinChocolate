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

    /// Zoom magnification (accepted for API parity; not yet applied natively).
    public var magnification: CGFloat = 1
    public var allowsMagnification: Bool = false
    public var minMagnification: CGFloat = 0.25
    public var maxMagnification: CGFloat = 4
    public var hasVerticalRuler: Bool = false
    public var hasHorizontalRuler: Bool = false

    /// Creates an empty scroll view.
    public required init(frame: NSRect) {
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

    /// Scrolls so the end of the document sits at the bottom of the viewport
    /// (AppKit's `scrollToEndOfDocument:`). The offset is clamped to the range,
    /// so the last content aligns to the bottom edge rather than overshooting.
    public func scrollToEndOfDocument(_ sender: Any? = nil) {
        let document = backend.scrollDocumentSize(for: handle)
        let visible = backend.scrollVisibleSize(for: handle)
        scroll(to: NSMakePoint(0, max(0, document.height - visible.height)))
    }

    /// Scrolls to the top of the document (AppKit's `scrollToBeginningOfDocument:`).
    public func scrollToBeginningOfDocument(_ sender: Any? = nil) {
        scroll(to: .zero)
    }

    private func applyScrollerPolicy() {
        backend.setScrollerPolicy(vertical: hasVerticalScroller,
                                  horizontal: hasHorizontalScroller, for: handle)
    }
}
