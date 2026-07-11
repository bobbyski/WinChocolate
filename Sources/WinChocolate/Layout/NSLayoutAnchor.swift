/// A factory for layout constraints against one view attribute, matching
/// AppKit's `NSLayoutAnchor`.
///
/// The axis subclasses (`NSLayoutXAxisAnchor`, `NSLayoutYAxisAnchor`,
/// `NSLayoutDimension`) exist so the type system prevents constraining, say, a
/// leading edge to a top edge, exactly as AppKit does.
public class NSLayoutAnchor {
    /// The view this anchor belongs to.
    weak var item: NSView?

    /// The attribute this anchor represents.
    let attribute: NSLayoutConstraint.Attribute

    init(item: NSView?, attribute: NSLayoutConstraint.Attribute) {
        self.item = item
        self.attribute = attribute
    }

    /// `self == other`.
    public func constraint(equalTo anchor: NSLayoutAnchor) -> NSLayoutConstraint {
        makeConstraint(to: anchor, relation: .equal, constant: 0)
    }

    /// `self == other + constant`.
    public func constraint(equalTo anchor: NSLayoutAnchor, constant: CGFloat) -> NSLayoutConstraint {
        makeConstraint(to: anchor, relation: .equal, constant: constant)
    }

    /// `self >= other + constant`.
    public func constraint(greaterThanOrEqualTo anchor: NSLayoutAnchor, constant: CGFloat = 0) -> NSLayoutConstraint {
        makeConstraint(to: anchor, relation: .greaterThanOrEqual, constant: constant)
    }

    /// `self <= other + constant`.
    public func constraint(lessThanOrEqualTo anchor: NSLayoutAnchor, constant: CGFloat = 0) -> NSLayoutConstraint {
        makeConstraint(to: anchor, relation: .lessThanOrEqual, constant: constant)
    }

    func makeConstraint(
        to anchor: NSLayoutAnchor,
        relation: NSLayoutConstraint.Relation,
        constant: CGFloat,
        multiplier: CGFloat = 1
    ) -> NSLayoutConstraint {
        NSLayoutConstraint(
            item: item,
            attribute: attribute,
            relatedBy: relation,
            toItem: anchor.item,
            attribute: anchor.attribute,
            multiplier: multiplier,
            constant: constant
        )
    }
}

/// A horizontal-axis anchor (leading/trailing/left/right/centerX).
public final class NSLayoutXAxisAnchor: NSLayoutAnchor {}

/// A vertical-axis anchor (top/bottom/centerY).
public final class NSLayoutYAxisAnchor: NSLayoutAnchor {}

/// A size-dimension anchor (width/height), which also constrains to constants
/// and to a multiple of another dimension.
public final class NSLayoutDimension: NSLayoutAnchor {
    /// `self == constant`.
    public func constraint(equalToConstant constant: CGFloat) -> NSLayoutConstraint {
        constantConstraint(relation: .equal, constant: constant)
    }

    /// `self >= constant`.
    public func constraint(greaterThanOrEqualToConstant constant: CGFloat) -> NSLayoutConstraint {
        constantConstraint(relation: .greaterThanOrEqual, constant: constant)
    }

    /// `self <= constant`.
    public func constraint(lessThanOrEqualToConstant constant: CGFloat) -> NSLayoutConstraint {
        constantConstraint(relation: .lessThanOrEqual, constant: constant)
    }

    /// `self == other * multiplier + constant`.
    public func constraint(
        equalTo anchor: NSLayoutDimension,
        multiplier: CGFloat,
        constant: CGFloat = 0
    ) -> NSLayoutConstraint {
        makeConstraint(to: anchor, relation: .equal, constant: constant, multiplier: multiplier)
    }

    /// `self == other * multiplier`.
    public func constraint(equalTo anchor: NSLayoutDimension, multiplier: CGFloat) -> NSLayoutConstraint {
        makeConstraint(to: anchor, relation: .equal, constant: 0, multiplier: multiplier)
    }

    private func constantConstraint(
        relation: NSLayoutConstraint.Relation,
        constant: CGFloat
    ) -> NSLayoutConstraint {
        NSLayoutConstraint(
            item: item,
            attribute: attribute,
            relatedBy: relation,
            toItem: nil,
            attribute: .notAnAttribute,
            multiplier: 1,
            constant: constant
        )
    }
}
