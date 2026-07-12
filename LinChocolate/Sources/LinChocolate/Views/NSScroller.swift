import Foundation

/// AppKit-shaped scroller — one scrollbar of an `NSScrollView`. Backed by the
/// `GtkScrolledWindow`'s own scrollbar, so this exposes its knob position and
/// proportion (read from the scroll geometry) rather than owning a widget.
public final class NSScroller {
    private unowned let scrollView: NSScrollView
    private let isVertical: Bool
    private var backend: NativeControlBackend { scrollView.backend }
    private var handle: NativeHandle { scrollView.handle }

    init(scrollView: NSScrollView, vertical: Bool) {
        self.scrollView = scrollView
        self.isVertical = vertical
    }

    /// Knob position in `0...1` (fraction of the scrollable range consumed).
    public var doubleValue: Double {
        let offset = backend.scrollOffset(for: handle)
        let document = backend.scrollDocumentSize(for: handle)
        let visible = backend.scrollVisibleSize(for: handle)
        let (o, d, v) = isVertical
            ? (offset.y, document.height, visible.height)
            : (offset.x, document.width, visible.width)
        let range = d - v
        return range > 0 ? min(1, max(0, o / range)) : 0
    }

    /// Fraction of the document currently visible (knob length), `0...1`.
    public var knobProportion: Double {
        let document = backend.scrollDocumentSize(for: handle)
        let visible = backend.scrollVisibleSize(for: handle)
        let (d, v) = isVertical ? (document.height, visible.height) : (document.width, visible.width)
        return d > 0 ? min(1, v / d) : 1
    }

    /// Whether the scroller is currently needed (document exceeds the viewport).
    public var isVisible: Bool { knobProportion < 1 }
}
