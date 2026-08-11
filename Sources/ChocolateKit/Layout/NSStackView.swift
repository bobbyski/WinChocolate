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
    public required init(frame frameRect: NSRect) {
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
    var layoutArrangedViews: [NSView] {
        detachesHiddenViews ? arrangedSubviews.filter { !$0.isHidden } : arrangedSubviews
    }

    /// The gap after `views[index]` (its custom spacing or the default).
    func gapAfter(_ views: [NSView], _ index: Int) -> CGFloat {
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

    var gravities: [ObjectIdentifier: Gravity] = [:]

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
    func gravity(for view: NSView) -> Gravity {
        gravities[ObjectIdentifier(view)] ?? .leading
    }

    // MARK: - Layout

    /// Arranges the stack's visible views along its orientation axis.
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

    enum CrossAlignment { case leading, center, trailing, baseline }

    private func invalidateAndRelayout() {
        invalidateIntrinsicContentSize()
        winSetNeedsLayout()
    }

    /// A view's size for arrangement: its intrinsic size per axis where it has
    /// one, else its current frame size.
}

extension NSStackView {
    func arrangedSize(_ view: NSView) -> NSSize {
        let intrinsic = view.intrinsicContentSize
        let width = intrinsic.width == NSView.noIntrinsicMetric ? view.frame.size.width : intrinsic.width
        let height = intrinsic.height == NSView.noIntrinsicMetric ? view.frame.size.height : intrinsic.height
        return NSSize(width: width, height: height)
    }

    func hasIntrinsicCross(_ view: NSView) -> Bool {
        orientation == .horizontal
            ? view.intrinsicContentSize.height != NSView.noIntrinsicMetric
            : view.intrinsicContentSize.width != NSView.noIntrinsicMetric
    }

    func crossAlignment() -> CrossAlignment {
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

    func commonBaseline(for views: [NSView], availableCross: CGFloat) -> CGFloat {
        views.reduce(0) { baseline, view in
            let height = min(arrangedSize(view).height, availableCross)
            return max(baseline, height - view.baselineOffsetFromBottom)
        }
    }

    func arrangeSubviews() {
        winArrangeSubviews()
    }
}
