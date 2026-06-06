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
