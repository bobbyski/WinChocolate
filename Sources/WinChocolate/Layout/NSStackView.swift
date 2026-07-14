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

    // MARK: - Custom spacing + hidden views

    /// Sentinel for "use the stack's default `spacing`", matching AppKit's
    /// `NSStackView.spacingUseDefault`.
    public static let useDefaultSpacing: CGFloat = .greatestFiniteMagnitude

    /// Whether hidden arranged views are removed from the layout (default
    /// `true`, matching AppKit) — a hidden view then takes no space.
    open var detachesHiddenViews: Bool = true { didSet { invalidateAndRelayout() } }

    private var customSpacings: [ObjectIdentifier: CGFloat] = [:]

    /// Sets a custom gap after a specific arranged view (or
    /// `NSStackView.useDefaultSpacing` to clear it).
    open func setCustomSpacing(_ spacing: CGFloat, after view: NSView) {
        if spacing == NSStackView.useDefaultSpacing {
            customSpacings.removeValue(forKey: ObjectIdentifier(view))
        } else {
            customSpacings[ObjectIdentifier(view)] = spacing
        }
        invalidateAndRelayout()
    }

    /// The custom gap after a view, or `useDefaultSpacing` when none is set.
    open func customSpacing(after view: NSView) -> CGFloat {
        customSpacings[ObjectIdentifier(view)] ?? NSStackView.useDefaultSpacing
    }

    /// The arranged views that participate in layout (hidden ones drop out when
    /// `detachesHiddenViews`).
    private var layoutArrangedViews: [NSView] {
        detachesHiddenViews ? arrangedSubviews.filter { !$0.isHidden } : arrangedSubviews
    }

    /// The gap after `views[index]` (its custom spacing or the default).
    private func gapAfter(_ views: [NSView], _ index: Int) -> CGFloat {
        guard index < views.count - 1 else { return 0 }
        return customSpacings[ObjectIdentifier(views[index])] ?? spacing
    }

    // MARK: - Gravity areas

    /// The packing region a view occupies when `distribution == .gravityAreas`,
    /// matching AppKit's `NSStackView.Gravity` (top/bottom alias leading/trailing
    /// for vertical stacks).
    public enum Gravity: Int, Sendable {
        case leading = 1
        case center = 2
        case trailing = 3

        /// Vertical-stack alias for `.leading`.
        public static var top: Gravity { .leading }

        /// Vertical-stack alias for `.trailing`.
        public static var bottom: Gravity { .trailing }
    }

    private var gravities: [ObjectIdentifier: Gravity] = [:]

    /// Adds a view to a gravity area (and to the arranged list).
    open func addView(_ view: NSView, in gravity: Gravity) {
        gravities[ObjectIdentifier(view)] = gravity
        addArrangedSubview(view)
    }

    /// Inserts a view at an index *within* a gravity area.
    open func insertView(_ view: NSView, at index: Int, in gravity: Gravity) {
        gravities[ObjectIdentifier(view)] = gravity
        let group = views(in: gravity).filter { $0 !== view }
        if index < group.count, let target = arrangedSubviews.firstIndex(where: { $0 === group[index] }) {
            insertArrangedSubview(view, at: target)
        } else {
            addArrangedSubview(view)
        }
    }

    /// Removes a view from the stack entirely (AppKit's `removeView`).
    open func removeView(_ view: NSView) {
        gravities.removeValue(forKey: ObjectIdentifier(view))
        removeArrangedSubview(view)
        view.removeFromSuperview()
    }

    /// The views currently in a gravity area, in arrangement order.
    open func views(in gravity: Gravity) -> [NSView] {
        arrangedSubviews.filter { self.gravity(for: $0) == gravity }
    }

    /// Replaces the views of a gravity area with a new list.
    open func setViews(_ newViews: [NSView], in gravity: Gravity) {
        for view in views(in: gravity) where !newViews.contains(where: { $0 === view }) {
            removeView(view)
        }
        for view in newViews {
            gravities[ObjectIdentifier(view)] = gravity
            if !arrangedSubviews.contains(where: { $0 === view }) {
                addArrangedSubview(view)
            }
        }
        invalidateAndRelayout()
    }

    /// The gravity area of an arranged view (AppKit's default is leading).
    private func gravity(for view: NSView) -> Gravity {
        gravities[ObjectIdentifier(view)] ?? .leading
    }

    // MARK: - Layout

    open override func layout() {
        arrangeSubviews()
    }

    /// The stack's natural size: the arranged content plus spacing and insets
    /// along the axis, and the widest/tallest arranged view across it.
    open override var intrinsicContentSize: NSSize {
        let views = layoutArrangedViews
        guard !views.isEmpty else {
            return NSSize(width: edgeInsets.left + edgeInsets.right,
                          height: edgeInsets.top + edgeInsets.bottom)
        }
        let sizes = views.map { arrangedSize($0) }
        let horizontal = orientation == .horizontal
        let gapTotal = (0..<views.count).reduce(CGFloat(0)) { $0 + gapAfter(views, $1) }
        let mainTotal = sizes.reduce(0) { $0 + (horizontal ? $1.width : $1.height) } + gapTotal
        let crossMax = sizes.reduce(0) { max($0, horizontal ? $1.height : $1.width) }
        let mainInset = horizontal ? edgeInsets.left + edgeInsets.right : edgeInsets.top + edgeInsets.bottom
        let crossInset = horizontal ? edgeInsets.top + edgeInsets.bottom : edgeInsets.left + edgeInsets.right
        return horizontal
            ? NSSize(width: mainTotal + mainInset, height: crossMax + crossInset)
            : NSSize(width: crossMax + crossInset, height: mainTotal + mainInset)
    }

    private enum CrossAlignment { case leading, center, trailing, baseline }

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
        case (.horizontal, .firstBaseline), (.horizontal, .lastBaseline):
            // Text baselines line up across a horizontal row (each view's
            // `baselineOffsetFromBottom`); meaningless for vertical stacks.
            return .baseline
        default:
            return .center
        }
    }

    private func arrangeSubviews() {
        let views = layoutArrangedViews
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
        // Per-view gaps (custom spacing overrides the default).
        var gaps = (0..<count).map { gapAfter(views, $0) }
        let totalSpacing = gaps.reduce(0, +)

        // Main-axis sizes.
        var mains = intrinsicMains
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
        case .equalSpacing:
            // Views keep their intrinsic size; the gaps grow uniformly to fill.
            let freeSpace = availableMain - intrinsicMains.reduce(0, +)
            if count > 1 {
                let uniform = max(spacing, freeSpace / CGFloat(count - 1))
                gaps = (0..<count).map { $0 < count - 1 ? uniform : 0 }
            }
        case .equalCentering:
            // Views keep their intrinsic size; their *centers* space equally
            // across the axis (positions computed explicitly below).
            break
        }

        // Explicit main-axis positions, when the distribution places views by
        // position rather than by packing with gaps.
        var explicitPositions: [CGFloat]?
        if distribution == .equalCentering, count > 0 {
            let slot = availableMain / CGFloat(count)
            explicitPositions = (0..<count).map { index in
                mainStart + slot * (CGFloat(index) + 0.5) - mains[index] / 2
            }
        }
        if distribution == .gravityAreas, !gravities.isEmpty {
            // True gravity packing: the leading group packs at the start, the
            // trailing group at the end, and the center group centers as a
            // block; views keep their intrinsic sizes.
            mains = intrinsicMains
            var positions = [CGFloat](repeating: mainStart, count: count)
            func pack(_ indexes: [Int], from start: CGFloat) -> CGFloat {
                var cursor = start
                for i in indexes {
                    positions[i] = cursor
                    cursor += mains[i] + spacing
                }
                return cursor - (indexes.isEmpty ? 0 : spacing)
            }
            let leading = views.indices.filter { gravity(for: views[$0]) == .leading }
            let center = views.indices.filter { gravity(for: views[$0]) == .center }
            let trailing = views.indices.filter { gravity(for: views[$0]) == .trailing }
            _ = pack(leading, from: mainStart)
            let trailingTotal = trailing.reduce(CGFloat(0)) { $0 + mains[$1] } + spacing * CGFloat(max(trailing.count - 1, 0))
            _ = pack(trailing, from: mainStart + availableMain - trailingTotal)
            let centerTotal = center.reduce(CGFloat(0)) { $0 + mains[$1] } + spacing * CGFloat(max(center.count - 1, 0))
            _ = pack(center, from: mainStart + (availableMain - centerTotal) / 2)
            explicitPositions = positions
        }

        // For baseline alignment: the deepest baseline-from-top across the row,
        // so every view hangs from a common baseline.
        let alignmentMode = crossAlignment()
        var commonBaseline: CGFloat = 0
        if alignmentMode == .baseline {
            for view in views {
                let height = min(arrangedSize(view).height, availableCross)
                commonBaseline = max(commonBaseline, height - view.baselineOffsetFromBottom)
            }
        }

        // Place each view along the main axis, aligned across it.
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
                case .baseline:
                    crossPos = crossStart + commonBaseline - (crossLen - view.baselineOffsetFromBottom)
                }
            } else {
                // No intrinsic cross size → fill the cross axis.
                crossLen = availableCross
                crossPos = crossStart
            }
            let mainPos = explicitPositions?[index] ?? mainCursor
            view.frame = horizontal
                ? NSRect(x: mainPos, y: crossPos, width: mainLen, height: crossLen)
                : NSRect(x: crossPos, y: mainPos, width: crossLen, height: mainLen)
            mainCursor += mainLen + gaps[index]
        }
    }
}
