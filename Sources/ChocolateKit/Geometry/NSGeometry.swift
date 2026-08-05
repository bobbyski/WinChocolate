// The geometry value types are owned by WinCoreGraphics (plan 13.1/13.2) —
// exactly Apple's layering, where `NSRect` *is* `CGRect`. The module is
// re-exported so `import WinChocolate` keeps providing `CGRect`/`CGFloat`
// and the rest of the CG-named surface unchanged.
@_exported import WinCoreGraphics

/// AppKit point alias over the CoreGraphics type, matching Apple.
public typealias NSPoint = CGPoint

/// AppKit size alias over the CoreGraphics type, matching Apple.
public typealias NSSize = CGSize

/// AppKit rectangle alias over the CoreGraphics type, matching Apple.
public typealias NSRect = CGRect

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

// (The CG-named aliases, `CGVector`, and the Swift-idiomatic rect members now
// live in WinCoreGraphics — see CGGeometry.swift there.)

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
