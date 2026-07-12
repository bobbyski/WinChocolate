/// A floating-point scalar used by WinChocolate geometry types.
public typealias CGFloat = Double

/// A two-dimensional point.
public struct NSPoint: Equatable, Sendable {
    /// The horizontal coordinate.
    public var x: CGFloat

    /// The vertical coordinate.
    public var y: CGFloat

    /// Creates a point from horizontal and vertical coordinates.
    public init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }
}

/// A two-dimensional size.
public struct NSSize: Equatable, Sendable {
    /// The width value.
    public var width: CGFloat

    /// The height value.
    public var height: CGFloat

    /// Creates a size from width and height values.
    public init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }
}

/// A rectangle represented by an origin and size.
public struct NSRect: Equatable, Sendable {
    /// The rectangle origin.
    public var origin: NSPoint

    /// The rectangle size.
    public var size: NSSize

    /// Creates a rectangle from an origin and size.
    public init(origin: NSPoint, size: NSSize) {
        self.origin = origin
        self.size = size
    }

    /// Creates a rectangle from individual coordinate and dimension values.
    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.origin = NSPoint(x: x, y: y)
        self.size = NSSize(width: width, height: height)
    }
}

/// A zero-valued point.
public let NSZeroPoint = NSPoint(x: 0, y: 0)

/// A zero-valued size.
public let NSZeroSize = NSSize(width: 0, height: 0)

/// A zero-valued rectangle.
public let NSZeroRect = NSRect(origin: NSZeroPoint, size: NSZeroSize)

/// Creates a point using AppKit's convenience function name.
public func NSMakePoint(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
    NSPoint(x: x, y: y)
}

/// Creates a size using AppKit's convenience function name.
public func NSMakeSize(_ width: CGFloat, _ height: CGFloat) -> NSSize {
    NSSize(width: width, height: height)
}

/// Creates a rectangle using AppKit's convenience function name.
public func NSMakeRect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
    NSRect(x: x, y: y, width: width, height: height)
}

/// Returns the minimum x-coordinate of a rectangle.
public func NSMinX(_ rect: NSRect) -> CGFloat {
    rect.origin.x
}

/// Returns the midpoint x-coordinate of a rectangle.
public func NSMidX(_ rect: NSRect) -> CGFloat {
    rect.origin.x + rect.size.width / 2
}

/// Returns the maximum x-coordinate of a rectangle.
public func NSMaxX(_ rect: NSRect) -> CGFloat {
    rect.origin.x + rect.size.width
}

/// Returns the minimum y-coordinate of a rectangle.
public func NSMinY(_ rect: NSRect) -> CGFloat {
    rect.origin.y
}

/// Returns the midpoint y-coordinate of a rectangle.
public func NSMidY(_ rect: NSRect) -> CGFloat {
    rect.origin.y + rect.size.height / 2
}

/// Returns the maximum y-coordinate of a rectangle.
public func NSMaxY(_ rect: NSRect) -> CGFloat {
    rect.origin.y + rect.size.height
}

/// Returns the width of a rectangle.
public func NSWidth(_ rect: NSRect) -> CGFloat {
    rect.size.width
}

/// Returns the height of a rectangle.
public func NSHeight(_ rect: NSRect) -> CGFloat {
    rect.size.height
}

/// Returns whether two rectangles are equal.
public func NSEqualRects(_ first: NSRect, _ second: NSRect) -> Bool {
    first == second
}

/// Returns whether a point lies inside a rectangle.
public func NSPointInRect(_ point: NSPoint, _ rect: NSRect) -> Bool {
    point.x >= NSMinX(rect)
        && point.x < NSMaxX(rect)
        && point.y >= NSMinY(rect)
        && point.y < NSMaxY(rect)
}

/// Returns a rectangle offset by the given x and y amounts.
public func NSOffsetRect(_ rect: NSRect, _ deltaX: CGFloat, _ deltaY: CGFloat) -> NSRect {
    NSRect(
        x: rect.origin.x + deltaX,
        y: rect.origin.y + deltaY,
        width: rect.size.width,
        height: rect.size.height
    )
}

/// Returns a rectangle inset by the given x and y amounts.
public func NSInsetRect(_ rect: NSRect, _ deltaX: CGFloat, _ deltaY: CGFloat) -> NSRect {
    NSRect(
        x: rect.origin.x + deltaX,
        y: rect.origin.y + deltaY,
        width: rect.size.width - deltaX * 2,
        height: rect.size.height - deltaY * 2
    )
}

// MARK: - CoreGraphics-compatible aliases

/// CoreGraphics point alias, so `CGPoint` source compiles unchanged.
public typealias CGPoint = NSPoint

/// CoreGraphics size alias.
public typealias CGSize = NSSize

/// CoreGraphics rectangle alias.
public typealias CGRect = NSRect

/// A two-dimensional vector (a delta), matching CoreGraphics' `CGVector`.
public struct CGVector: Equatable, Sendable {
    public var dx: CGFloat
    public var dy: CGFloat

    public init(dx: CGFloat, dy: CGFloat) {
        self.dx = dx
        self.dy = dy
    }

    public init() {
        self.dx = 0
        self.dy = 0
    }

    public static let zero = CGVector(dx: 0, dy: 0)
}

// MARK: - Swift-idiomatic geometry members

extension NSPoint {
    /// The point at the origin.
    public static let zero = NSPoint(x: 0, y: 0)
}

extension NSSize {
    /// The zero size.
    public static let zero = NSSize(width: 0, height: 0)
}

extension NSRect {
    /// The zero rectangle.
    public static let zero = NSRect(x: 0, y: 0, width: 0, height: 0)

    /// The smallest x-coordinate (standardized for negative widths).
    public var minX: CGFloat { min(origin.x, origin.x + size.width) }
    /// The center x-coordinate.
    public var midX: CGFloat { (minX + maxX) / 2 }
    /// The largest x-coordinate.
    public var maxX: CGFloat { max(origin.x, origin.x + size.width) }
    /// The smallest y-coordinate.
    public var minY: CGFloat { min(origin.y, origin.y + size.height) }
    /// The center y-coordinate.
    public var midY: CGFloat { (minY + maxY) / 2 }
    /// The largest y-coordinate.
    public var maxY: CGFloat { max(origin.y, origin.y + size.height) }
    /// The rectangle width (non-negative).
    public var width: CGFloat { abs(size.width) }
    /// The rectangle height (non-negative).
    public var height: CGFloat { abs(size.height) }
    /// Whether the rectangle has zero area.
    public var isEmpty: Bool { size.width == 0 || size.height == 0 }

    /// A rectangle with a non-negative width and height.
    public var standardized: NSRect {
        var rect = self
        if rect.size.width < 0 {
            rect.origin.x += rect.size.width
            rect.size.width = -rect.size.width
        }
        if rect.size.height < 0 {
            rect.origin.y += rect.size.height
            rect.size.height = -rect.size.height
        }
        return rect
    }

    /// The smallest integral rectangle that contains this one.
    public var integral: NSRect {
        let standardized = self.standardized
        let x = standardized.origin.x.rounded(.down)
        let y = standardized.origin.y.rounded(.down)
        let maxX = (standardized.origin.x + standardized.size.width).rounded(.up)
        let maxY = (standardized.origin.y + standardized.size.height).rounded(.up)
        return NSRect(x: x, y: y, width: maxX - x, height: maxY - y)
    }

    /// Returns a rectangle inset on all sides.
    public func insetBy(dx: CGFloat, dy: CGFloat) -> NSRect {
        NSRect(x: origin.x + dx, y: origin.y + dy, width: size.width - dx * 2, height: size.height - dy * 2)
    }

    /// Returns a rectangle offset by the given amounts.
    public func offsetBy(dx: CGFloat, dy: CGFloat) -> NSRect {
        NSRect(x: origin.x + dx, y: origin.y + dy, width: size.width, height: size.height)
    }

    /// Returns whether a point lies inside the rectangle (half-open).
    public func contains(_ point: NSPoint) -> Bool {
        let rect = standardized
        return point.x >= rect.minX && point.x < rect.maxX && point.y >= rect.minY && point.y < rect.maxY
    }

    /// Returns whether another rectangle is fully inside this one.
    public func contains(_ rect: NSRect) -> Bool {
        let a = standardized, b = rect.standardized
        return b.minX >= a.minX && b.maxX <= a.maxX && b.minY >= a.minY && b.maxY <= a.maxY
    }

    /// Returns whether two rectangles overlap.
    public func intersects(_ rect: NSRect) -> Bool {
        let a = standardized, b = rect.standardized
        return !(a.maxX <= b.minX || b.maxX <= a.minX || a.maxY <= b.minY || b.maxY <= a.minY)
    }

    /// Returns the smallest rectangle containing both rectangles.
    public func union(_ rect: NSRect) -> NSRect {
        if isEmpty { return rect.standardized }
        if rect.isEmpty { return standardized }
        let a = standardized, b = rect.standardized
        let x = min(a.minX, b.minX), y = min(a.minY, b.minY)
        return NSRect(x: x, y: y, width: max(a.maxX, b.maxX) - x, height: max(a.maxY, b.maxY) - y)
    }

    /// Returns the overlapping rectangle, or the zero rectangle when disjoint.
    public func intersection(_ rect: NSRect) -> NSRect {
        let a = standardized, b = rect.standardized
        let x = max(a.minX, b.minX), y = max(a.minY, b.minY)
        let right = min(a.maxX, b.maxX), bottom = min(a.maxY, b.maxY)
        guard right > x && bottom > y else {
            return .zero
        }
        return NSRect(x: x, y: y, width: right - x, height: bottom - y)
    }
}

// MARK: - Additional C-style geometry functions

/// Returns whether two points are equal.
public func NSEqualPoints(_ first: NSPoint, _ second: NSPoint) -> Bool { first == second }

/// Returns whether two sizes are equal.
public func NSEqualSizes(_ first: NSSize, _ second: NSSize) -> Bool { first == second }

/// Returns whether the first rectangle fully contains the second.
public func NSContainsRect(_ first: NSRect, _ second: NSRect) -> Bool { first.contains(second) }

/// Returns whether two rectangles overlap.
public func NSIntersectsRect(_ first: NSRect, _ second: NSRect) -> Bool { first.intersects(second) }

/// Returns the smallest rectangle containing both rectangles.
public func NSUnionRect(_ first: NSRect, _ second: NSRect) -> NSRect { first.union(second) }

/// Returns the overlapping rectangle of two rectangles.
public func NSIntersectionRect(_ first: NSRect, _ second: NSRect) -> NSRect { first.intersection(second) }

/// Returns whether a rectangle has zero area.
public func NSIsEmptyRect(_ rect: NSRect) -> Bool { rect.isEmpty }

/// Returns the smallest integral rectangle containing a rectangle.
public func NSIntegralRect(_ rect: NSRect) -> NSRect { rect.integral }

/// Returns whether a point is within a rectangle (the flip flag is accepted for
/// source compatibility; WinChocolate uses top-left coordinates throughout).
public func NSMouseInRect(_ point: NSPoint, _ rect: NSRect, _ flipped: Bool) -> Bool { rect.contains(point) }

/// Splits a rectangle into a slice of the given thickness taken from an edge and
/// the remaining rectangle, matching AppKit's `NSDivideRect`.
public func NSDivideRect(_ rect: NSRect, _ slice: inout NSRect, _ remainder: inout NSRect, _ amount: CGFloat, _ edge: NSRectEdge) {
    let thickness = max(0, amount)
    switch edge {
    case .minX:
        let width = min(thickness, rect.size.width)
        slice = NSRect(x: rect.origin.x, y: rect.origin.y, width: width, height: rect.size.height)
        remainder = NSRect(x: rect.origin.x + width, y: rect.origin.y, width: rect.size.width - width, height: rect.size.height)
    case .maxX:
        let width = min(thickness, rect.size.width)
        slice = NSRect(x: rect.origin.x + rect.size.width - width, y: rect.origin.y, width: width, height: rect.size.height)
        remainder = NSRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width - width, height: rect.size.height)
    case .minY:
        let height = min(thickness, rect.size.height)
        slice = NSRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width, height: height)
        remainder = NSRect(x: rect.origin.x, y: rect.origin.y + height, width: rect.size.width, height: rect.size.height - height)
    case .maxY:
        let height = min(thickness, rect.size.height)
        slice = NSRect(x: rect.origin.x, y: rect.origin.y + rect.size.height - height, width: rect.size.width, height: height)
        remainder = NSRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width, height: rect.size.height - height)
    }
}

// MARK: - Edge insets

/// The inset distances for the sides of a rectangle, matching `NSEdgeInsets`.
public struct NSEdgeInsets: Equatable, Sendable {
    public var top: CGFloat
    public var left: CGFloat
    public var bottom: CGFloat
    public var right: CGFloat

    public init(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    public init() {
        self.init(top: 0, left: 0, bottom: 0, right: 0)
    }
}

/// Zero edge insets.
public let NSEdgeInsetsZero = NSEdgeInsets()

/// Writing-direction-relative inset distances, matching AppKit's
/// `NSDirectionalEdgeInsets` (leading/trailing rather than left/right). In a
/// left-to-right layout, `leading` is the left edge and `trailing` the right.
public struct NSDirectionalEdgeInsets: Equatable, Sendable {
    public var top: CGFloat
    public var leading: CGFloat
    public var bottom: CGFloat
    public var trailing: CGFloat

    public init(top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) {
        self.top = top
        self.leading = leading
        self.bottom = bottom
        self.trailing = trailing
    }

    public init() {
        self.init(top: 0, leading: 0, bottom: 0, trailing: 0)
    }
}

/// Zero directional edge insets.
public let NSDirectionalEdgeInsetsZero = NSDirectionalEdgeInsets()

/// Creates edge insets, matching AppKit's convenience function.
public func NSEdgeInsetsMake(_ top: CGFloat, _ left: CGFloat, _ bottom: CGFloat, _ right: CGFloat) -> NSEdgeInsets {
    NSEdgeInsets(top: top, left: left, bottom: bottom, right: right)
}

/// Returns whether two edge insets are equal.
public func NSEdgeInsetsEqual(_ first: NSEdgeInsets, _ second: NSEdgeInsets) -> Bool { first == second }

/// Rectangle edge constants used by AppKit positioning APIs.
public enum NSRectEdge: UInt, Sendable {
    /// The minimum x edge.
    case minX = 0

    /// The minimum y edge.
    case minY = 1

    /// The maximum x edge.
    case maxX = 2

    /// The maximum y edge.
    case maxY = 3
}
