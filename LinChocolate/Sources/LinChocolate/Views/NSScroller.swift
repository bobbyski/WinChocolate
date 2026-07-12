import Foundation

/// AppKit-shaped scroller — one scrollbar of an `NSScrollView`.
///
/// Two modes:
/// - **Bound** (`init(scrollView:vertical:)`): backed by the
///   `GtkScrolledWindow`'s own scrollbar, exposing its knob position and
///   proportion (read from the scroll geometry) rather than owning a widget.
/// - **Standalone** (`init(frame:)`): a slider-like scrollbar the demo builds
///   directly; `doubleValue` holds its `0...1` position and `onAction` fires
///   when it changes.
public final class NSScroller: NSView {
    private unowned var owner: NSScrollView?
    private let isVertical: Bool

    /// Fires when a standalone scroller's value changes.
    public var onAction: ((NSScroller) -> Void)?

    init(scrollView: NSScrollView, vertical: Bool) {
        self.owner = scrollView
        self.isVertical = vertical
        super.init(frame: .zero)
    }

    public override init(frame: NSRect) {
        self.owner = nil
        self.isVertical = frame.height > frame.width
        super.init(frame: frame)
    }

    private var _value: Double = 0

    /// Knob position in `0...1` (fraction of the scrollable range consumed).
    public var doubleValue: Double {
        get {
            guard let owner else { return _value }
            let offset = owner.backend.scrollOffset(for: owner.handle)
            let document = owner.backend.scrollDocumentSize(for: owner.handle)
            let visible = owner.backend.scrollVisibleSize(for: owner.handle)
            let (o, d, v) = isVertical
                ? (offset.y, document.height, visible.height)
                : (offset.x, document.width, visible.width)
            let range = d - v
            return range > 0 ? min(1, max(0, o / range)) : 0
        }
        set {
            _value = min(1, max(0, newValue))
            if owner == nil { onAction?(self) }
        }
    }

    private var _knobProportion: Double = 1

    /// Fraction of the document currently visible (knob length), `0...1`.
    /// Bound: derived from the scroll geometry. Standalone: settable.
    public var knobProportion: Double {
        get {
            guard let owner else { return _knobProportion }
            let document = owner.backend.scrollDocumentSize(for: owner.handle)
            let visible = owner.backend.scrollVisibleSize(for: owner.handle)
            let (d, v) = isVertical ? (document.height, visible.height) : (document.width, visible.width)
            return d > 0 ? min(1, v / d) : 1
        }
        set { _knobProportion = min(1, max(0, newValue)) }
    }

    /// Whether the scroller is currently needed (document exceeds the viewport).
    public var isVisible: Bool { knobProportion < 1 }
}
