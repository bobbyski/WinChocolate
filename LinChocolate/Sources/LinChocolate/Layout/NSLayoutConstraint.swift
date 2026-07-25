import Foundation

/// AppKit-shaped layout constraint: `firstItem.firstAttribute (relation)
/// multiplier × secondItem.secondAttribute + constant`.
///
/// Constraints are collected in a process-wide active set and resolved to
/// frames by `LayoutSolver` when a container lays out. This slice solves
/// **equality** constraints (the common anchor case); inequalities and
/// priority-based ambiguity resolution are later parity items.
public final class NSLayoutConstraint {

    /// The geometric attribute a constraint refers to.
    public enum Attribute: Sendable {
        /// The view's left edge.
        case left
        /// The view's right edge.
        case right
        /// The view's top edge.
        case top
        /// The view's bottom edge.
        case bottom
        /// The view's leading edge (left in LTR).
        case leading
        /// The view's trailing edge (right in LTR).
        case trailing
        /// The view's width.
        case width
        /// The view's height.
        case height
        /// The view's horizontal center.
        case centerX
        /// The view's vertical center.
        case centerY
        /// No attribute (used for constant-only constraints).
        case notAnAttribute
    }

    /// The relation between the two sides.
    public enum Relation: Sendable {
        /// The first side is less than or equal to the second.
        case lessThanOrEqual
        /// The two sides are equal.
        case equal
        /// The first side is greater than or equal to the second.
        case greaterThanOrEqual
    }

    /// Constraint priority (required = 1000).
    public struct Priority: RawRepresentable, Comparable, Sendable {
        /// The priority's raw numeric value.
        public let rawValue: Float
        /// Creates a priority from a raw float value.
        public init(rawValue: Float) { self.rawValue = rawValue }
        /// Creates a priority from a float value.
        public init(_ value: Float) { self.rawValue = value }
        /// The highest priority; the constraint must be satisfied.
        public static let required = Priority(1000)
        /// The default high (non-required) priority.
        public static let defaultHigh = Priority(750)
        /// The default low priority.
        public static let defaultLow = Priority(250)
        /// Priorities compare by their raw value.
        public static func < (l: Priority, r: Priority) -> Bool { l.rawValue < r.rawValue }
    }

    /// The first view participating in the constraint.
    public private(set) weak var firstItem: NSView?
    /// The attribute of `firstItem`.
    public let firstAttribute: Attribute
    /// The relation between the two sides.
    public let relation: Relation
    /// The optional second view; nil for constant-only constraints.
    public private(set) weak var secondItem: NSView?
    /// The attribute of `secondItem` (or `.notAnAttribute`).
    public let secondAttribute: Attribute
    /// The multiplier applied to the second side.
    public let multiplier: CGFloat
    /// The constant added to the second side.
    public var constant: CGFloat
    /// The constraint's priority.
    public var priority: Priority = .required

    /// Activating a constraint adds it to the active set and requests layout.
    public var isActive: Bool = false {
        didSet {
            guard isActive != oldValue else { return }
            if isActive {
                NSLayoutConstraint.active.append(self)
            } else {
                NSLayoutConstraint.active.removeAll { $0 === self }
            }
            firstItem?.setNeedsLayout()
        }
    }

    /// The process-wide active constraint set (single-thread UI contract).
    nonisolated(unsafe) static var active: [NSLayoutConstraint] = []

    /// Creates a constraint of the form
    /// `item.attribute (relation) toItem.secondAttribute * multiplier + constant`.
    public init(item: NSView?, attribute: Attribute, relatedBy: Relation,
                toItem: NSView?, attribute secondAttribute: Attribute,
                multiplier: CGFloat, constant: CGFloat) {
        self.firstItem = item
        self.firstAttribute = attribute
        self.relation = relatedBy
        self.secondItem = toItem
        self.secondAttribute = secondAttribute
        self.multiplier = multiplier
        self.constant = constant
    }

    /// Activates every constraint (AppKit's batch API).
    public static func activate(_ constraints: [NSLayoutConstraint]) {
        constraints.forEach { $0.isActive = true }
    }

    /// Deactivates every constraint.
    public static func deactivate(_ constraints: [NSLayoutConstraint]) {
        constraints.forEach { $0.isActive = false }
    }
}
