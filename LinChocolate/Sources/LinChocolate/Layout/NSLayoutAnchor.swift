import Foundation

/// AppKit-shaped layout anchor: a factory for constraints between a view's
/// attribute and another's. Access via `NSView.leadingAnchor`, `widthAnchor`, …
public class NSLayoutAnchor {
    let item: NSView
    let attribute: NSLayoutConstraint.Attribute

    init(item: NSView, attribute: NSLayoutConstraint.Attribute) {
        self.item = item
        self.attribute = attribute
    }

    func makeConstraint(to other: NSLayoutAnchor?, multiplier: CGFloat, constant: CGFloat) -> NSLayoutConstraint {
        NSLayoutConstraint(
            item: item, attribute: attribute, relatedBy: .equal,
            toItem: other?.item, attribute: other?.attribute ?? .notAnAttribute,
            multiplier: multiplier, constant: constant
        )
    }
}

/// Horizontal-axis anchor (leading/trailing/left/right/centerX).
public final class NSLayoutXAxisAnchor: NSLayoutAnchor {
    public func constraint(equalTo other: NSLayoutXAxisAnchor, constant: CGFloat = 0) -> NSLayoutConstraint {
        makeConstraint(to: other, multiplier: 1, constant: constant)
    }
}

/// Vertical-axis anchor (top/bottom/centerY).
public final class NSLayoutYAxisAnchor: NSLayoutAnchor {
    public func constraint(equalTo other: NSLayoutYAxisAnchor, constant: CGFloat = 0) -> NSLayoutConstraint {
        makeConstraint(to: other, multiplier: 1, constant: constant)
    }
}

/// Size anchor (width/height), which also supports constants and multipliers.
public final class NSLayoutDimension: NSLayoutAnchor {
    public func constraint(equalToConstant c: CGFloat) -> NSLayoutConstraint {
        makeConstraint(to: nil, multiplier: 1, constant: c)
    }
    public func constraint(equalTo other: NSLayoutDimension, multiplier: CGFloat = 1, constant: CGFloat = 0) -> NSLayoutConstraint {
        makeConstraint(to: other, multiplier: multiplier, constant: constant)
    }
}
