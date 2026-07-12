import Foundation

/// Resolves active Auto Layout constraints into concrete frames.
///
/// Each laid-out subview contributes four unknowns — x, y, width, height in the
/// container's (AppKit bottom-left) coordinate space. Every equality constraint
/// becomes one linear equation in those unknowns; the container's bounds and
/// any `translatesAutoresizingMaskIntoConstraints == true` view supply
/// constants. The system is reduced to RREF (Gaussian elimination); free
/// variables (an under-constrained dimension) keep the view's current frame
/// value, so partial constraints compose with manual frames.
///
/// Scope: equality only, single pass (no live resize yet), no priority-based
/// tie-breaking. Those are tracked as later parity items.
enum LayoutSolver {

    /// A single unknown: one geometry component of one view.
    private struct Variable: Hashable {
        let view: ObjectIdentifier
        let component: Int   // 0 = x, 1 = y, 2 = width, 3 = height
    }

    /// Lays out `container`'s constraint-driven subviews, then recurses.
    static func solve(container: NSView) {
        solveOne(container: container)
        for subview in container.subviews {
            solve(container: subview)
        }
    }

    private static func solveOne(container: NSView) {
        let subviews = container.subviews
        let variableViews = subviews.filter { !$0.translatesAutoresizingMaskIntoConstraints }
        guard !variableViews.isEmpty else { return }

        let containerID = ObjectIdentifier(container)
        let subviewIDs = Set(subviews.map(ObjectIdentifier.init))
        let variableIDs = Set(variableViews.map(ObjectIdentifier.init))

        // Known frame for a constant item (the container, or a translates=true view).
        func knownFrame(_ id: ObjectIdentifier) -> NSRect? {
            if id == containerID { return NSMakeRect(0, 0, container.frame.width, container.frame.height) }
            if let v = subviews.first(where: { ObjectIdentifier($0) == id }),
               v.translatesAutoresizingMaskIntoConstraints {
                return v.frame
            }
            return nil
        }

        // Constraints wholly within {container} ∪ subviews that touch a variable view.
        let constraints = NSLayoutConstraint.active.filter { c in
            guard c.relation == .equal, let first = c.firstItem else { return false }
            let fid = ObjectIdentifier(first)
            guard fid == containerID || subviewIDs.contains(fid) else { return false }
            if let second = c.secondItem {
                let sid = ObjectIdentifier(second)
                guard sid == containerID || subviewIDs.contains(sid) else { return false }
            }
            let touchesVariable = variableIDs.contains(fid)
                || (c.secondItem.map { variableIDs.contains(ObjectIdentifier($0)) } ?? false)
            return touchesVariable
        }
        guard !constraints.isEmpty else { return }

        // An attribute as a linear expression: (variable coefficients, constant).
        func expression(item: NSView, attribute: NSLayoutConstraint.Attribute) -> ([Variable: Double], Double) {
            let id = ObjectIdentifier(item)
            if let f = knownFrame(id) {
                let value: Double
                switch attribute {
                case .left, .leading: value = Double(f.minX)
                case .right, .trailing: value = Double(f.maxX)
                case .top: value = Double(f.maxY)
                case .bottom: value = Double(f.minY)
                case .width: value = Double(f.width)
                case .height: value = Double(f.height)
                case .centerX: value = Double(f.midX)
                case .centerY: value = Double(f.midY)
                case .notAnAttribute: value = 0
                }
                return ([:], value)
            }
            let x = Variable(view: id, component: 0)
            let y = Variable(view: id, component: 1)
            let w = Variable(view: id, component: 2)
            let h = Variable(view: id, component: 3)
            switch attribute {
            case .left, .leading:  return ([x: 1], 0)
            case .right, .trailing: return ([x: 1, w: 1], 0)
            case .bottom:          return ([y: 1], 0)
            case .top:             return ([y: 1, h: 1], 0)
            case .width:           return ([w: 1], 0)
            case .height:          return ([h: 1], 0)
            case .centerX:         return ([x: 1, w: 0.5], 0)
            case .centerY:         return ([y: 1, h: 0.5], 0)
            case .notAnAttribute:  return ([:], 0)
            }
        }

        // firstExpr == m·secondExpr + constant  →  (F − m·S)·vars = m·Sconst + constant − Fconst
        var equations: [(coeffs: [Variable: Double], rhs: Double)] = []
        for c in constraints {
            guard let first = c.firstItem else { continue }
            let (fCoeffs, fConst) = expression(item: first, attribute: c.firstAttribute)
            var coeffs = fCoeffs
            var rhs = Double(c.constant) - fConst
            if let second = c.secondItem {
                let (sCoeffs, sConst) = expression(item: second, attribute: c.secondAttribute)
                let m = Double(c.multiplier)
                for (v, k) in sCoeffs { coeffs[v, default: 0] -= m * k }
                rhs += m * sConst
            }
            equations.append((coeffs, rhs))
        }

        // Assemble the system and reduce to RREF.
        let variables = Array(Set(equations.flatMap { $0.coeffs.keys }))
        guard !variables.isEmpty else { return }
        let column = Dictionary(uniqueKeysWithValues: variables.enumerated().map { ($1, $0) })
        let n = variables.count
        let m = equations.count
        var A = [[Double]](repeating: [Double](repeating: 0, count: n), count: m)
        var b = [Double](repeating: 0, count: m)
        for (r, eq) in equations.enumerated() {
            for (v, k) in eq.coeffs { A[r][column[v]!] = k }
            b[r] = eq.rhs
        }

        var pivotRowOfColumn = [Int: Int]()
        var row = 0
        for col in 0..<n where row < m {
            var selected = -1
            var best = 1e-9
            for r in row..<m where abs(A[r][col]) > best { best = abs(A[r][col]); selected = r }
            guard selected != -1 else { continue }
            A.swapAt(selected, row); b.swapAt(selected, row)
            let pivot = A[row][col]
            for j in 0..<n { A[row][j] /= pivot }
            b[row] /= pivot
            for r in 0..<m where r != row {
                let factor = A[r][col]
                if factor != 0 {
                    for j in 0..<n { A[r][j] -= factor * A[row][j] }
                    b[r] -= factor * b[row]
                }
            }
            pivotRowOfColumn[col] = row
            row += 1
        }

        // Free variables keep the view's current frame value; pivots follow.
        func currentValue(_ v: Variable) -> Double {
            guard let view = variableViews.first(where: { ObjectIdentifier($0) == v.view }) else { return 0 }
            switch v.component {
            case 0: return Double(view.frame.minX)
            case 1: return Double(view.frame.minY)
            case 2: return Double(view.frame.width)
            default: return Double(view.frame.height)
            }
        }
        var values = [Variable: Double]()
        for col in 0..<n where pivotRowOfColumn[col] == nil {
            values[variables[col]] = currentValue(variables[col])
        }
        for (col, r) in pivotRowOfColumn {
            var value = b[r]
            for j in 0..<n where j != col {
                value -= A[r][j] * (values[variables[j]] ?? 0)   // other pivot cols have coeff 0
            }
            values[variables[col]] = value
        }

        // Apply resolved frames (setter routes through the backend).
        for view in variableViews {
            let id = ObjectIdentifier(view)
            let x = values[Variable(view: id, component: 0)] ?? Double(view.frame.minX)
            let y = values[Variable(view: id, component: 1)] ?? Double(view.frame.minY)
            let w = values[Variable(view: id, component: 2)] ?? Double(view.frame.width)
            let h = values[Variable(view: id, component: 3)] ?? Double(view.frame.height)
            view.frame = NSMakeRect(CGFloat(x), CGFloat(y), CGFloat(w), CGFloat(h))
        }
    }
}
