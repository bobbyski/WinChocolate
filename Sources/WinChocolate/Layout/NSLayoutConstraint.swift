/// A single Auto Layout constraint relating two view attributes.
///
/// WinChocolate implements a real constraint-to-frame solver (see
/// `NSLayoutSolver`), so activating constraints actually lays views out — the
/// plan deliberately avoids stubs that silently do nothing. The first slice
/// covers the positional/size attributes and equality plus inequality
/// relations with priority-weighted relaxation; strict Cassowary priority
/// ordering is a later refinement.
public final class NSLayoutConstraint {
    /// The attribute of a view an anchor/constraint refers to.
    public enum Attribute: Int, Sendable {
        case left, right, top, bottom
        case leading, trailing
        case width, height
        case centerX, centerY
        case notAnAttribute

        /// Whether the attribute lives on the horizontal axis.
        var isHorizontal: Bool {
            switch self {
            case .left, .right, .leading, .trailing, .width, .centerX:
                return true
            default:
                return false
            }
        }
    }

    /// The relation between the two sides of a constraint.
    public enum Relation: Int, Sendable {
        case lessThanOrEqual = -1
        case equal = 0
        case greaterThanOrEqual = 1
    }

    /// The axis a content-size priority applies to, matching AppKit's
    /// `NSLayoutConstraint.Orientation`.
    public enum Orientation: Int, Sendable {
        case horizontal = 0
        case vertical = 1
    }

    /// The strength of a constraint, matching AppKit's `NSLayoutConstraint.Priority`.
    public struct Priority: RawRepresentable, Equatable, Comparable, Sendable {
        public var rawValue: Float
        public init(rawValue: Float) { self.rawValue = rawValue }
        public init(_ value: Float) { self.rawValue = value }

        public static let required = Priority(1000)
        public static let defaultHigh = Priority(750)
        public static let dragThatCanResizeWindow = Priority(510)
        public static let windowSizeStayPut = Priority(500)
        public static let dragThatCannotResizeWindow = Priority(490)
        public static let defaultLow = Priority(250)
        public static let fittingSizeCompression = Priority(50)

        public static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// The first (left-hand) item; AppKit types this as `Any?` but WinChocolate
    /// layout relates `NSView`s.
    public weak var firstItem: NSView?

    /// The attribute of the first item.
    public let firstAttribute: Attribute

    /// The relation between the two attributes.
    public let relation: Relation

    /// The second (right-hand) item, or `nil` for a constant-only constraint
    /// (e.g. a fixed width).
    public weak var secondItem: NSView?

    /// The attribute of the second item.
    public let secondAttribute: Attribute

    /// The multiplier applied to the second attribute.
    public let multiplier: CGFloat

    /// The constant added to the second attribute. Changing it re-lays out.
    public var constant: CGFloat {
        didSet { winLayoutContainer?.winSetNeedsLayout() }
    }

    /// The constraint priority. Changing it re-lays out.
    public var priority: Priority = .required {
        didSet { winLayoutContainer?.winSetNeedsLayout() }
    }

    /// An optional identifier for debugging.
    public var identifier: String?

    /// Activates or deactivates the constraint.
    public var isActive: Bool {
        get { winLayoutContainer?.winActiveConstraints.contains(where: { $0 === self }) ?? false }
        set { newValue ? NSLayoutConstraint.activate([self]) : NSLayoutConstraint.deactivate([self]) }
    }

    /// The view the constraint is installed on while active (the nearest common
    /// ancestor of its items), tracked so activation is reversible.
    weak var winLayoutContainer: NSView?

    /// Creates a constraint with AppKit's designated initializer shape.
    public init(
        item firstItem: Any?,
        attribute firstAttribute: Attribute,
        relatedBy relation: Relation,
        toItem secondItem: Any?,
        attribute secondAttribute: Attribute,
        multiplier: CGFloat,
        constant: CGFloat
    ) {
        self.firstItem = firstItem as? NSView
        self.firstAttribute = firstAttribute
        self.relation = relation
        self.secondItem = secondItem as? NSView
        self.secondAttribute = secondAttribute
        self.multiplier = multiplier
        self.constant = constant
    }

    /// Activates each constraint, installing it on the nearest common ancestor
    /// of its items and scheduling that container for layout.
    public static func activate(_ constraints: [NSLayoutConstraint]) {
        for constraint in constraints {
            guard let container = constraint.winComputeContainer() else {
                continue
            }
            constraint.winLayoutContainer = container
            if !container.winActiveConstraints.contains(where: { $0 === constraint }) {
                container.winActiveConstraints.append(constraint)
            }
            container.winSetNeedsLayout()
        }
    }

    /// Deactivates each constraint, removing it from its container.
    public static func deactivate(_ constraints: [NSLayoutConstraint]) {
        for constraint in constraints {
            let container = constraint.winLayoutContainer
            container?.winActiveConstraints.removeAll { $0 === constraint }
            container?.winSetNeedsLayout()
            constraint.winLayoutContainer = nil
        }
    }

    /// The view that should own this constraint: the nearest common ancestor of
    /// its two items, or the first item's superview for a single-item
    /// constraint (falling back to the item itself at the root).
    private func winComputeContainer() -> NSView? {
        guard let first = firstItem else {
            return nil
        }
        guard let second = secondItem else {
            return first.superview ?? first
        }
        return NSView.winNearestCommonAncestor(first, second) ?? first.superview ?? first
    }
}
