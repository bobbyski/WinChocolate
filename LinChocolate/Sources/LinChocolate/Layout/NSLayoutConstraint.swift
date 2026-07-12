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
        case left, right, top, bottom, leading, trailing
        case width, height, centerX, centerY, notAnAttribute
    }

    /// The relation between the two sides.
    public enum Relation: Sendable {
        case lessThanOrEqual, equal, greaterThanOrEqual
    }

    /// Constraint priority (required = 1000).
    public struct Priority: RawRepresentable, Comparable, Sendable {
        public let rawValue: Float
        public init(rawValue: Float) { self.rawValue = rawValue }
        public init(_ value: Float) { self.rawValue = value }
        public static let required = Priority(1000)
        public static let defaultHigh = Priority(750)
        public static let defaultLow = Priority(250)
        public static func < (l: Priority, r: Priority) -> Bool { l.rawValue < r.rawValue }
    }

    public private(set) weak var firstItem: NSView?
    public let firstAttribute: Attribute
    public let relation: Relation
    public private(set) weak var secondItem: NSView?
    public let secondAttribute: Attribute
    public let multiplier: CGFloat
    public var constant: CGFloat
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
