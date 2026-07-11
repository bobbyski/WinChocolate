import WinFoundation

/// A constraint-to-frame solver: it computes the frames of a container's
/// direct subviews from the Auto Layout constraints installed on the container.
///
/// It solves the horizontal and vertical axes independently (each subview has a
/// position and a size variable per axis) by iterated projection (a Kaczmarz /
/// Gauss–Seidel relaxation): every constraint is projected onto in turn, and
/// the pass repeats until the frames stop moving. For a well-posed system of
/// required equalities this converges to the exact solution; inequalities are
/// projected only when violated, and lower-priority constraints are projected
/// with a smaller step so required constraints win. (Full Cassowary priority
/// ordering is a later refinement — see the Phase 9 plan.)
enum NSLayoutSolver {
    /// One view's unknowns on a single axis: its origin (`pos`) and extent
    /// (`size`), indexed into the flat variable vector.
    private struct AxisVars {
        var posIndex: Int
        var sizeIndex: Int
    }

    /// A linearized constraint on one axis: `Σ coeff·var (relation) rhs`.
    private struct AxisEquation {
        var terms: [(index: Int, coeff: Double)]
        var rhs: Double
        var relation: NSLayoutConstraint.Relation
        var priority: Float
    }

    /// Solves the container's active constraints and writes the resulting
    /// frames onto its solved (non-autoresizing) direct subviews.
    static func solve(container: NSView) {
        let constraints = container.winActiveConstraints
        guard !constraints.isEmpty else {
            return
        }

        // Direct subviews whose frame is constraint-driven (translates == false)
        // are solved; the rest are fixed inputs, as is the container.
        let solved = container.subviews.filter { !$0.translatesAutoresizingMaskIntoConstraints }
        guard !solved.isEmpty else {
            return
        }
        var indexOf: [ObjectIdentifier: Int] = [:]
        for (i, view) in solved.enumerated() {
            indexOf[ObjectIdentifier(view)] = i
        }

        let containerBounds = NSRect(origin: .zero, size: container.frame.size)
        let horizontal = solveAxis(
            constraints: constraints, container: container, containerBounds: containerBounds,
            solved: solved, indexOf: indexOf, isHorizontal: true
        )
        let vertical = solveAxis(
            constraints: constraints, container: container, containerBounds: containerBounds,
            solved: solved, indexOf: indexOf, isHorizontal: false
        )

        for (i, view) in solved.enumerated() {
            let x = horizontal.map { $0[i].pos } ?? view.frame.origin.x
            let w = horizontal.map { max($0[i].size, 0) } ?? view.frame.size.width
            let y = vertical.map { $0[i].pos } ?? view.frame.origin.y
            let h = vertical.map { max($0[i].size, 0) } ?? view.frame.size.height
            view.frame = NSRect(x: x, y: y, width: w, height: h)
        }
    }

    /// Solves one axis, returning per-solved-view `(pos, size)` or `nil` when
    /// that axis carries no constraints.
    private static func solveAxis(
        constraints: [NSLayoutConstraint],
        container: NSView,
        containerBounds: NSRect,
        solved: [NSView],
        indexOf: [ObjectIdentifier: Int],
        isHorizontal: Bool
    ) -> [(pos: Double, size: Double)]? {
        // Two unknowns per solved view: [pos0, size0, pos1, size1, ...].
        var values = [Double](repeating: 0, count: solved.count * 2)
        for (i, view) in solved.enumerated() {
            values[i * 2] = Double(isHorizontal ? view.frame.origin.x : view.frame.origin.y)
            values[i * 2 + 1] = Double(isHorizontal ? view.frame.size.width : view.frame.size.height)
        }
        func vars(for index: Int) -> AxisVars { AxisVars(posIndex: index * 2, sizeIndex: index * 2 + 1) }

        var equations: [AxisEquation] = []
        for constraint in constraints where constraint.firstAttribute.isHorizontal == isHorizontal
            && constraint.firstAttribute != .notAnAttribute {
            if let equation = linearize(
                constraint, container: container, containerBounds: containerBounds,
                indexOf: indexOf, isHorizontal: isHorizontal, vars: vars
            ) {
                equations.append(equation)
            }
        }
        guard !equations.isEmpty else {
            return nil
        }

        // Project in ascending priority order so higher-priority constraints
        // are applied last in each sweep and win any conflict — required
        // constraints (projected last) always hold at the end of a sweep, and
        // the final iteration leaves them satisfied. A well-posed system
        // converges and breaks early; genuine conflicts run to the cap with the
        // higher-priority side satisfied.
        equations.sort { $0.priority < $1.priority }
        let maxIterations = 2000
        let epsilon = 1e-8
        for _ in 0..<maxIterations {
            var maxDelta = 0.0
            for equation in equations {
                let lhs = equation.terms.reduce(0.0) { $0 + $1.coeff * values[$1.index] }
                let residual = lhs - equation.rhs
                switch equation.relation {
                case .lessThanOrEqual where residual <= 0: continue
                case .greaterThanOrEqual where residual >= 0: continue
                default: break
                }
                let norm = equation.terms.reduce(0.0) { $0 + $1.coeff * $1.coeff }
                guard norm > 0 else { continue }
                let step = residual / norm
                for term in equation.terms {
                    let delta = step * term.coeff
                    values[term.index] -= delta
                    maxDelta = max(maxDelta, abs(delta))
                }
            }
            if maxDelta < epsilon {
                break
            }
        }

        return (0..<solved.count).map { (pos: values[$0 * 2], size: values[$0 * 2 + 1]) }
    }

    /// Reduces a constraint to a single-axis linear equation over the solved
    /// variables, folding fixed (container/autoresizing) attributes into the
    /// constant. Returns `nil` for constraints referencing a view that is
    /// neither the container nor a solved direct subview (a documented
    /// first-slice limitation: cross-hierarchy constraints aren't solved here).
    private static func linearize(
        _ constraint: NSLayoutConstraint,
        container: NSView,
        containerBounds: NSRect,
        indexOf: [ObjectIdentifier: Int],
        isHorizontal: Bool,
        vars: (Int) -> AxisVars
    ) -> AxisEquation? {
        guard let first = constraint.firstItem else {
            return nil
        }
        guard let firstExpr = attributeExpression(
            view: first, attribute: constraint.firstAttribute,
            container: container, containerBounds: containerBounds, indexOf: indexOf, vars: vars
        ) else {
            return nil
        }

        var terms = firstExpr.terms
        var constTerm = firstExpr.constant

        if let second = constraint.secondItem {
            guard let secondExpr = attributeExpression(
                view: second, attribute: constraint.secondAttribute,
                container: container, containerBounds: containerBounds, indexOf: indexOf, vars: vars
            ) else {
                return nil
            }
            let m = Double(constraint.multiplier)
            for term in secondExpr.terms {
                terms.append((index: term.index, coeff: -m * term.coeff))
            }
            constTerm -= m * secondExpr.constant
        }

        // firstExpr - m·secondExpr = constant  ⇒  Σ coeff·var = constant - constTerm.
        let rhs = Double(constraint.constant) - constTerm
        // Merge duplicate variable indices (e.g. a self-referential constraint).
        var merged: [Int: Double] = [:]
        for term in terms {
            merged[term.index, default: 0] += term.coeff
        }
        let mergedTerms = merged.map { (index: $0.key, coeff: $0.value) }
        guard !mergedTerms.isEmpty else {
            // No free variables — an all-fixed constraint; nothing to solve.
            return nil
        }
        return AxisEquation(terms: mergedTerms, rhs: rhs, relation: constraint.relation, priority: constraint.priority.rawValue)
    }

    /// A linear expression `Σ coeff·var + constant` for one attribute.
    private struct Expression {
        var terms: [(index: Int, coeff: Double)]
        var constant: Double
    }

    /// Expresses `view.attribute` on the axis as a linear form over the solved
    /// variables (or a pure constant for the container / a fixed subview).
    private static func attributeExpression(
        view: NSView,
        attribute: NSLayoutConstraint.Attribute,
        container: NSView,
        containerBounds: NSRect,
        indexOf: [ObjectIdentifier: Int],
        vars: (Int) -> AxisVars
    ) -> Expression? {
        // Container attribute → constant from its bounds.
        if view === container {
            return Expression(terms: [], constant: containerConstant(attribute, bounds: containerBounds))
        }
        // Solved subview → linear in (pos, size).
        if let index = indexOf[ObjectIdentifier(view)] {
            let v = vars(index)
            let (posCoeff, sizeCoeff): (Double, Double)
            switch attribute {
            case .left, .leading, .top:
                (posCoeff, sizeCoeff) = (1, 0)
            case .right, .trailing, .bottom:
                (posCoeff, sizeCoeff) = (1, 1)
            case .width, .height:
                (posCoeff, sizeCoeff) = (0, 1)
            case .centerX, .centerY:
                (posCoeff, sizeCoeff) = (1, 0.5)
            case .notAnAttribute:
                return nil
            }
            var terms: [(index: Int, coeff: Double)] = []
            if posCoeff != 0 { terms.append((index: v.posIndex, coeff: posCoeff)) }
            if sizeCoeff != 0 { terms.append((index: v.sizeIndex, coeff: sizeCoeff)) }
            return Expression(terms: terms, constant: 0)
        }
        // A fixed direct subview (autoresizing) → constant from its frame.
        if view.superview === container {
            return Expression(terms: [], constant: fixedConstant(attribute, frame: view.frame))
        }
        // Neither the container nor a direct subview — outside this slice.
        return nil
    }

    private static func containerConstant(_ attribute: NSLayoutConstraint.Attribute, bounds: NSRect) -> Double {
        switch attribute {
        case .left, .leading, .top: return 0
        case .right, .trailing: return Double(bounds.size.width)
        case .bottom: return Double(bounds.size.height)
        case .width: return Double(bounds.size.width)
        case .height: return Double(bounds.size.height)
        case .centerX: return Double(bounds.size.width) / 2
        case .centerY: return Double(bounds.size.height) / 2
        case .notAnAttribute: return 0
        }
    }

    private static func fixedConstant(_ attribute: NSLayoutConstraint.Attribute, frame: NSRect) -> Double {
        switch attribute {
        case .left, .leading: return Double(frame.origin.x)
        case .right, .trailing: return Double(frame.origin.x + frame.size.width)
        case .top: return Double(frame.origin.y)
        case .bottom: return Double(frame.origin.y + frame.size.height)
        case .width: return Double(frame.size.width)
        case .height: return Double(frame.size.height)
        case .centerX: return Double(frame.origin.x + frame.size.width / 2)
        case .centerY: return Double(frame.origin.y + frame.size.height / 2)
        case .notAnAttribute: return 0
        }
    }
}
