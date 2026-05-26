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
