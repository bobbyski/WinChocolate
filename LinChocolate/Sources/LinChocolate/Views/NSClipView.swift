import Foundation

/// AppKit-shaped clip view — the scrolling viewport of an `NSScrollView`.
///
/// GTK's `GtkScrolledWindow` bundles the clip and scrollers into one widget, so
/// this is a facade over the enclosing scroll view rather than a separate
/// native view: `bounds.origin` is the scroll offset (like AppKit's flipped
/// clip view, y grows downward), `bounds.size` is the visible size.
public final class NSClipView {
    private unowned let scrollView: NSScrollView
    private var backend: NativeControlBackend { scrollView.backend }
    private var handle: NativeHandle { scrollView.handle }

    init(scrollView: NSScrollView) {
        self.scrollView = scrollView
    }

    /// The scrolled document (the scroll view's `documentView`).
    public var documentView: NSView? { scrollView.documentView }

    /// The visible rectangle in document coordinates: origin = scroll offset,
    /// size = viewport size.
    public var bounds: NSRect {
        let offset = backend.scrollOffset(for: handle)
        let size = backend.scrollVisibleSize(for: handle)
        return NSMakeRect(offset.x, offset.y, size.width, size.height)
    }

    /// The full document rectangle (origin zero, document size).
    public var documentRect: NSRect {
        let size = backend.scrollDocumentSize(for: handle)
        return NSMakeRect(0, 0, size.width, size.height)
    }

    /// Scrolls so the document point `point` is at the viewport's top-left.
    public func scroll(to point: NSPoint) {
        backend.setScrollOffset(x: Double(point.x), y: Double(point.y), for: handle)
    }
}
