/// The axis a view arranges its content along, matching AppKit's
/// `NSUserInterfaceLayoutOrientation`.
public enum NSUserInterfaceLayoutOrientation: Int, Sendable {
    case horizontal = 0
    case vertical = 1
}

/// A view that lays a list of arranged subviews out in a row or column, matching
/// AppKit's `NSStackView`.
///
/// WinChocolate arranges the subviews directly in `layout()` (which the Auto
/// Layout pass calls after the solver has sized the stack itself), honoring
/// `orientation`, `spacing`, `edgeInsets`, `distribution` (main axis), and
/// `alignment` (cross axis), and reports an `intrinsicContentSize` derived from
/// its arranged subviews so a stack composes inside a constraint layout.
open class NSStackView: NSView {
    /// How arranged views share the space along the stacking axis.
    public enum Distribution: Int, Sendable {
        /// Views keep their intrinsic size; leftover space is shared out (default).
        case fill = 0
        /// Every view gets the same size along the axis.
        case fillEqually
        /// Views are sized in proportion to their intrinsic size along the axis.
        case fillProportionally
        /// Views keep their intrinsic size; gaps grow to fill the axis.
        case equalSpacing
        /// Views are spaced so their centers are equally far apart.
        case equalCentering
        /// AppKit's gravity-area model; here it behaves like `.fill`.
        case gravityAreas
    }

    /// Which way the arranged subviews stack.
    open var orientation: NSUserInterfaceLayoutOrientation = .horizontal {
        didSet { invalidateAndRelayout() }
    }

    /// The cross-axis alignment of arranged subviews (`.leading`/`.trailing`/
    /// centered per the stacking axis; other attributes fall back to centered).
    open var alignment: NSLayoutConstraint.Attribute = .centerY {
        didSet { invalidateAndRelayout() }
    }

    /// How arranged views share the main axis.
    open var distribution: Distribution = .fill {
        didSet { invalidateAndRelayout() }
    }

    /// The gap between adjacent arranged views.
    open var spacing: CGFloat = 8 {
        didSet { invalidateAndRelayout() }
    }

    /// Padding between the stack's edges and its arranged content.
    open var edgeInsets: NSEdgeInsets = NSEdgeInsetsZero {
        didSet { invalidateAndRelayout() }
    }

    /// The views the stack arranges, in order.
    open private(set) var arrangedSubviews: [NSView] = []

    /// Creates an empty stack view.
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    /// Creates a stack view pre-populated with arranged views (AppKit's
    /// `NSStackView(views:)`).
    public convenience init(views: [NSView]) {
        self.init(frame: .zero)
        views.forEach { addArrangedSubview($0) }
    }

    // MARK: - Managing arranged subviews

    /// Adds a view to the end of the arranged list (and as a subview).
    open func addArrangedSubview(_ view: NSView) {
        insertArrangedSubview(view, at: arrangedSubviews.count)
    }

    /// Inserts a view into the arranged list at an index (and as a subview).
    open func insertArrangedSubview(_ view: NSView, at index: Int) {
        arrangedSubviews.removeAll { $0 === view }
        let clamped = min(max(index, 0), arrangedSubviews.count)
        arrangedSubviews.insert(view, at: clamped)
        if view.superview !== self {
            addSubview(view)
        }
        invalidateAndRelayout()
    }

    /// Removes a view from the arranged list. Like AppKit, the view stays a
    /// subview (call `removeFromSuperview()` to fully detach it).
    open func removeArrangedSubview(_ view: NSView) {
        arrangedSubviews.removeAll { $0 === view }
        invalidateAndRelayout()
    }

    // MARK: - Layout

    open override func layout() {
        arrangeSubviews()
    }

    /// The stack's natural size: the arranged content plus spacing and insets
    /// along the axis, and the widest/tallest arranged view across it.
    open override var intrinsicContentSize: NSSize {
        guard !arrangedSubviews.isEmpty else {
            return NSSize(width: edgeInsets.left + edgeInsets.right,
                          height: edgeInsets.top + edgeInsets.bottom)
        }
        let sizes = arrangedSubviews.map { arrangedSize($0) }
        let horizontal = orientation == .horizontal
        let mainTotal = sizes.reduce(0) { $0 + (horizontal ? $1.width : $1.height) }
            + spacing * CGFloat(arrangedSubviews.count - 1)
        let crossMax = sizes.reduce(0) { max($0, horizontal ? $1.height : $1.width) }
        let mainInset = horizontal ? edgeInsets.left + edgeInsets.right : edgeInsets.top + edgeInsets.bottom
        let crossInset = horizontal ? edgeInsets.top + edgeInsets.bottom : edgeInsets.left + edgeInsets.right
        return horizontal
            ? NSSize(width: mainTotal + mainInset, height: crossMax + crossInset)
            : NSSize(width: crossMax + crossInset, height: mainTotal + mainInset)
    }

    private enum CrossAlignment { case leading, center, trailing }

    private func invalidateAndRelayout() {
        invalidateIntrinsicContentSize()
        winSetNeedsLayout()
    }

    /// A view's size for arrangement: its intrinsic size per axis where it has
    /// one, else its current frame size.
    private func arrangedSize(_ view: NSView) -> NSSize {
        let intrinsic = view.intrinsicContentSize
        let width = intrinsic.width == NSView.noIntrinsicMetric ? view.frame.size.width : intrinsic.width
        let height = intrinsic.height == NSView.noIntrinsicMetric ? view.frame.size.height : intrinsic.height
        return NSSize(width: width, height: height)
    }

    private func hasIntrinsicCross(_ view: NSView) -> Bool {
        orientation == .horizontal
            ? view.intrinsicContentSize.height != NSView.noIntrinsicMetric
            : view.intrinsicContentSize.width != NSView.noIntrinsicMetric
    }

    private func crossAlignment() -> CrossAlignment {
        switch (orientation, alignment) {
        case (.horizontal, .top), (.vertical, .leading):
            return .leading
        case (.horizontal, .bottom), (.vertical, .trailing):
            return .trailing
        default:
            return .center
        }
    }

    private func arrangeSubviews() {
        let views = arrangedSubviews
        guard !views.isEmpty else {
            return
        }
        let horizontal = orientation == .horizontal
        let bounds = self.bounds

        // Main axis geometry.
        let mainStart = horizontal ? edgeInsets.left : edgeInsets.top
        let mainInset = horizontal ? edgeInsets.left + edgeInsets.right : edgeInsets.top + edgeInsets.bottom
        let availableMain = max((horizontal ? bounds.size.width : bounds.size.height) - mainInset, 0)
        // Cross axis geometry.
        let crossStart = horizontal ? edgeInsets.top : edgeInsets.left
        let crossInset = horizontal ? edgeInsets.top + edgeInsets.bottom : edgeInsets.left + edgeInsets.right
        let availableCross = max((horizontal ? bounds.size.height : bounds.size.width) - crossInset, 0)

        let intrinsicMains = views.map { horizontal ? arrangedSize($0).width : arrangedSize($0).height }
        let count = views.count
        let totalSpacing = spacing * CGFloat(count - 1)

        // Main-axis sizes + the gap to use between views.
        var mains = intrinsicMains
        var gap = spacing
        switch distribution {
        case .fillEqually:
            let each = max((availableMain - totalSpacing) / CGFloat(count), 0)
            mains = Array(repeating: each, count: count)
        case .fillProportionally:
            let sum = intrinsicMains.reduce(0, +)
            if sum > 0 {
                let scale = max(availableMain - totalSpacing, 0) / sum
                mains = intrinsicMains.map { $0 * scale }
            } else {
                let each = max((availableMain - totalSpacing) / CGFloat(count), 0)
                mains = Array(repeating: each, count: count)
            }
        case .fill, .gravityAreas:
            let leftover = availableMain - totalSpacing - intrinsicMains.reduce(0, +)
            let share = leftover / CGFloat(count)
            mains = intrinsicMains.map { max($0 + share, 0) }
        case .equalSpacing, .equalCentering:
            // Views keep their intrinsic size; the gap grows to fill the axis.
            let freeSpace = availableMain - intrinsicMains.reduce(0, +)
            if count > 1 {
                gap = max(spacing, freeSpace / CGFloat(count - 1))
            }
        }

        // Place each view along the main axis, aligned across it.
        let alignmentMode = crossAlignment()
        var mainCursor = mainStart
        for (index, view) in views.enumerated() {
            let mainLen = mains[index]
            let crossLen: CGFloat
            let crossPos: CGFloat
            if hasIntrinsicCross(view) {
                crossLen = min(horizontal ? arrangedSize(view).height : arrangedSize(view).width, availableCross)
                switch alignmentMode {
                case .leading: crossPos = crossStart
                case .center: crossPos = crossStart + (availableCross - crossLen) / 2
                case .trailing: crossPos = crossStart + availableCross - crossLen
                }
            } else {
                // No intrinsic cross size → fill the cross axis.
                crossLen = availableCross
                crossPos = crossStart
            }
            view.frame = horizontal
                ? NSRect(x: mainCursor, y: crossPos, width: mainLen, height: crossLen)
                : NSRect(x: crossPos, y: mainCursor, width: crossLen, height: mainLen)
            mainCursor += mainLen + gap
        }
    }
}
