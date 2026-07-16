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
open class NSScroller: NSControl {
    private unowned var owner: NSScrollView?
    private let isVertical: Bool

    /// Fires when a standalone scroller's value changes.
    public var onAction: ((NSScroller) -> Void)?

    init(scrollView: NSScrollView, vertical: Bool) {
        self.owner = scrollView
        self.isVertical = vertical
        super.init(frame: .zero)
    }

    public required init(frame: NSRect) {
        self.owner = nil
        let vertical = frame.height > frame.width
        self.isVertical = vertical
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createScroller(vertical: vertical, frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
        // AppKit's NSScroller is the one control that starts **disabled**
        // (verified against real AppKit: isEnabled == false, usableParts ==
        // .noScrollerParts), so no knob is drawn and nothing responds until the
        // app enables it. Assigning after super.init, so NSControl's observer
        // fires and the native side agrees.
        isEnabled = false
        backend.setScrollerGeometry(value: _value, knobProportion: _knobProportion, for: handle)
        backend.setScrollerAction(for: handle) { [weak self] value in
            guard let self else { return }
            self._value = value          // sync silently — this came *from* the knob
            self.onAction?(self)
            self.sendAction()
        }
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
            // AppKit does not send a control's action when the value is set in
            // code — only the user's drag does. (This used to fire `onAction`
            // here, which reported positions the user never scrolled to.)
            guard owner == nil else { return }
            backend.setScrollerGeometry(value: _value, knobProportion: _knobProportion, for: handle)
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
        set {
            _knobProportion = min(1, max(0, newValue))
            guard owner == nil else { return }
            backend.setScrollerGeometry(value: _value, knobProportion: _knobProportion, for: handle)
        }
    }

    /// Whether the scroller is currently needed (document exceeds the viewport).
    public var isVisible: Bool { knobProportion < 1 }
}
