/// Auto Layout surface on `NSView`: anchors, constraint installation, and the
/// layout pass that runs the solver.
extension NSView {
    // MARK: - Anchors

    /// The view's leading-edge anchor (left edge in LTR).
    public var leadingAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: self, attribute: .leading) }

    /// The view's trailing-edge anchor (right edge in LTR).
    public var trailingAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: self, attribute: .trailing) }

    /// The view's left-edge anchor.
    public var leftAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: self, attribute: .left) }

    /// The view's right-edge anchor.
    public var rightAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: self, attribute: .right) }

    /// The view's top-edge anchor.
    public var topAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor(item: self, attribute: .top) }

    /// The view's bottom-edge anchor.
    public var bottomAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor(item: self, attribute: .bottom) }

    /// The view's width anchor.
    public var widthAnchor: NSLayoutDimension { NSLayoutDimension(item: self, attribute: .width) }

    /// The view's height anchor.
    public var heightAnchor: NSLayoutDimension { NSLayoutDimension(item: self, attribute: .height) }

    /// The view's horizontal-center anchor.
    public var centerXAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor(item: self, attribute: .centerX) }

    /// The view's vertical-center anchor.
    public var centerYAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor(item: self, attribute: .centerY) }

    // MARK: - Installing constraints

    /// The constraints installed directly on this view (as their container).
    public var constraints: [NSLayoutConstraint] { winActiveConstraints }

    /// Installs a constraint on this view and schedules layout.
    public func addConstraint(_ constraint: NSLayoutConstraint) {
        constraint.winLayoutContainer = self
        if !winActiveConstraints.contains(where: { $0 === constraint }) {
            winActiveConstraints.append(constraint)
        }
        winSetNeedsLayout()
    }

    /// Installs several constraints on this view.
    public func addConstraints(_ constraints: [NSLayoutConstraint]) {
        constraints.forEach { addConstraint($0) }
    }

    /// Removes a constraint installed on this view.
    public func removeConstraint(_ constraint: NSLayoutConstraint) {
        winActiveConstraints.removeAll { $0 === constraint }
        if constraint.winLayoutContainer === self {
            constraint.winLayoutContainer = nil
        }
        winSetNeedsLayout()
    }

    /// Removes several constraints installed on this view.
    public func removeConstraints(_ constraints: [NSLayoutConstraint]) {
        constraints.forEach { removeConstraint($0) }
    }

    // MARK: - Content size priorities

    /// The priority with which the view resists growing past its intrinsic size
    /// on an axis.
    public func contentHuggingPriority(for orientation: NSLayoutConstraint.Orientation) -> NSLayoutConstraint.Priority {
        NSLayoutConstraint.Priority(orientation == .horizontal
            ? winContentHuggingPriority.horizontal : winContentHuggingPriority.vertical)
    }

    /// Sets the view's content-hugging priority on an axis.
    public func setContentHuggingPriority(_ priority: NSLayoutConstraint.Priority, for orientation: NSLayoutConstraint.Orientation) {
        if orientation == .horizontal {
            winContentHuggingPriority.horizontal = priority.rawValue
        } else {
            winContentHuggingPriority.vertical = priority.rawValue
        }
        winSetNeedsLayout()
    }

    /// The priority with which the view resists shrinking below its intrinsic
    /// size on an axis.
    public func contentCompressionResistancePriority(for orientation: NSLayoutConstraint.Orientation) -> NSLayoutConstraint.Priority {
        NSLayoutConstraint.Priority(orientation == .horizontal
            ? winCompressionResistancePriority.horizontal : winCompressionResistancePriority.vertical)
    }

    /// Sets the view's content-compression-resistance priority on an axis.
    public func setContentCompressionResistancePriority(_ priority: NSLayoutConstraint.Priority, for orientation: NSLayoutConstraint.Orientation) {
        if orientation == .horizontal {
            winCompressionResistancePriority.horizontal = priority.rawValue
        } else {
            winCompressionResistancePriority.vertical = priority.rawValue
        }
        winSetNeedsLayout()
    }

    // MARK: - Layout pass

    /// Flags this view (and its layout container chain) as needing layout.
    func winSetNeedsLayout() {
        needsLayout = true
    }

    /// Marks the view as needing a fresh layout pass.
    public func setNeedsLayout() {
        needsLayout = true
    }

    /// Runs the constraint solver for this view and its whole subtree, then
    /// calls `layout()` at each level. Solving a container positions its
    /// constraint-driven (`translatesAutoresizingMaskIntoConstraints == false`)
    /// direct subviews; the pass then recurses so nested layouts resolve.
    public func layoutSubtreeIfNeeded() {
        NSLayoutSolver.solve(container: self)
        layout()
        needsLayout = false
        for subview in subviews {
            subview.layoutSubtreeIfNeeded()
        }
    }

    // MARK: - Hierarchy helpers

    /// The chain of ancestors from this view up to the root, self first.
    private var winAncestorChain: [NSView] {
        var chain: [NSView] = []
        var current: NSView? = self
        while let view = current {
            chain.append(view)
            current = view.superview
        }
        return chain
    }

    /// The nearest view that is an ancestor of (or equal to) both views.
    static func winNearestCommonAncestor(_ a: NSView, _ b: NSView) -> NSView? {
        let ancestorsOfB = Set(b.winAncestorChain.map { ObjectIdentifier($0) })
        for view in a.winAncestorChain where ancestorsOfB.contains(ObjectIdentifier(view)) {
            return view
        }
        return nil
    }
}
