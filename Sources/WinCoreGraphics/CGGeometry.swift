/// CoreGraphics-shaped geometry value types (plan Phase 13).
///
/// WinCoreGraphics owns the CG-named types — exactly Apple's layering, where
/// `NSRect` *is* `CGRect` — and WinChocolate re-exports the module with
/// `NSPoint`/`NSSize`/`NSRect` typealiases, so both spellings compile
/// unchanged. The module is dependency-free so non-UI code (and other
/// libraries) can use the types without pulling in the AppKit layer.

/// A floating-point scalar used by the geometry types.
public typealias CGFloat = Double

/// A two-dimensional point.
public struct CGPoint: Equatable, Sendable {
    /// The horizontal coordinate.
    public var x: CGFloat

    /// The vertical coordinate.
    public var y: CGFloat

    /// Creates a point from horizontal and vertical coordinates.
    public init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }

    /// The point at the origin.
    public static let zero = CGPoint(x: 0, y: 0)
}

/// A two-dimensional size.
public struct CGSize: Equatable, Sendable {
    /// The width value.
    public var width: CGFloat

    /// The height value.
    public var height: CGFloat

    /// Creates a size from width and height values.
    public init(width: CGFloat, height: CGFloat) {
        self.width = width
        self.height = height
    }

    /// The zero size.
    public static let zero = CGSize(width: 0, height: 0)
}

/// A rectangle represented by an origin and size.
public struct CGRect: Equatable, Sendable {
    /// The rectangle origin.
    public var origin: CGPoint

    /// The rectangle size.
    public var size: CGSize

    /// Creates a rectangle from an origin and size.
    public init(origin: CGPoint, size: CGSize) {
        self.origin = origin
        self.size = size
    }

    /// Creates a rectangle from individual coordinate and dimension values.
    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.origin = CGPoint(x: x, y: y)
        self.size = CGSize(width: width, height: height)
    }

    /// The zero rectangle.
    public static let zero = CGRect(x: 0, y: 0, width: 0, height: 0)

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
    public var standardized: CGRect {
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
    public var integral: CGRect {
        let standardized = self.standardized
        let x = standardized.origin.x.rounded(.down)
        let y = standardized.origin.y.rounded(.down)
        let maxX = (standardized.origin.x + standardized.size.width).rounded(.up)
        let maxY = (standardized.origin.y + standardized.size.height).rounded(.up)
        return CGRect(x: x, y: y, width: maxX - x, height: maxY - y)
    }

    /// Returns a rectangle inset on all sides.
    public func insetBy(dx: CGFloat, dy: CGFloat) -> CGRect {
        CGRect(x: origin.x + dx, y: origin.y + dy, width: size.width - dx * 2, height: size.height - dy * 2)
    }

    /// Returns a rectangle offset by the given amounts.
    public func offsetBy(dx: CGFloat, dy: CGFloat) -> CGRect {
        CGRect(x: origin.x + dx, y: origin.y + dy, width: size.width, height: size.height)
    }

    /// Returns whether a point lies inside the rectangle (half-open).
    public func contains(_ point: CGPoint) -> Bool {
        let rect = standardized
        return point.x >= rect.minX && point.x < rect.maxX && point.y >= rect.minY && point.y < rect.maxY
    }

    /// Returns whether another rectangle is fully inside this one.
    public func contains(_ rect: CGRect) -> Bool {
        let a = standardized, b = rect.standardized
        return b.minX >= a.minX && b.maxX <= a.maxX && b.minY >= a.minY && b.maxY <= a.maxY
    }

    /// Returns whether two rectangles overlap.
    public func intersects(_ rect: CGRect) -> Bool {
        let a = standardized, b = rect.standardized
        return !(a.maxX <= b.minX || b.maxX <= a.minX || a.maxY <= b.minY || b.maxY <= a.minY)
    }

    /// Returns the smallest rectangle containing both rectangles.
    public func union(_ rect: CGRect) -> CGRect {
        if isEmpty { return rect.standardized }
        if rect.isEmpty { return standardized }
        let a = standardized, b = rect.standardized
        let x = min(a.minX, b.minX), y = min(a.minY, b.minY)
        return CGRect(x: x, y: y, width: max(a.maxX, b.maxX) - x, height: max(a.maxY, b.maxY) - y)
    }

    /// Returns the overlapping rectangle, or the zero rectangle when disjoint.
    public func intersection(_ rect: CGRect) -> CGRect {
        let a = standardized, b = rect.standardized
        let x = max(a.minX, b.minX), y = max(a.minY, b.minY)
        let right = min(a.maxX, b.maxX), bottom = min(a.maxY, b.maxY)
        guard right > x && bottom > y else {
            return .zero
        }
        return CGRect(x: x, y: y, width: right - x, height: bottom - y)
    }
}

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

/// A 2×3 affine transformation matrix, matching CoreGraphics' layout:
/// `x' = a·x + c·y + tx`, `y' = b·x + d·y + ty`.
public struct CGAffineTransform: Equatable, Sendable {
    public var a: CGFloat
    public var b: CGFloat
    public var c: CGFloat
    public var d: CGFloat
    public var tx: CGFloat
    public var ty: CGFloat

    public init(a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat, tx: CGFloat, ty: CGFloat) {
        self.a = a
        self.b = b
        self.c = c
        self.d = d
        self.tx = tx
        self.ty = ty
    }

    /// The identity transform.
    public static let identity = CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0)

    /// Creates a translation transform.
    public init(translationX tx: CGFloat, y ty: CGFloat) {
        self.init(a: 1, b: 0, c: 0, d: 1, tx: tx, ty: ty)
    }

    /// Creates a scaling transform.
    public init(scaleX sx: CGFloat, y sy: CGFloat) {
        self.init(a: sx, b: 0, c: 0, d: sy, tx: 0, ty: 0)
    }

    /// Creates a rotation transform (radians, counterclockwise for positive
    /// angles in an unflipped space).
    public init(rotationAngle angle: CGFloat) {
        let cosine = _win_cos(angle)
        let sine = _win_sin(angle)
        self.init(a: cosine, b: sine, c: -sine, d: cosine, tx: 0, ty: 0)
    }

    /// Whether this is the identity transform.
    public var isIdentity: Bool { self == .identity }

    /// Returns this transform concatenated with another (`self` applied first).
    public func concatenating(_ other: CGAffineTransform) -> CGAffineTransform {
        CGAffineTransform(
            a: a * other.a + b * other.c,
            b: a * other.b + b * other.d,
            c: c * other.a + d * other.c,
            d: c * other.b + d * other.d,
            tx: tx * other.a + ty * other.c + other.tx,
            ty: tx * other.b + ty * other.d + other.ty
        )
    }

    /// Returns the transform translated by the given amounts.
    public func translatedBy(x: CGFloat, y: CGFloat) -> CGAffineTransform {
        CGAffineTransform(translationX: x, y: y).concatenating(self)
    }

    /// Returns the transform scaled by the given factors.
    public func scaledBy(x: CGFloat, y: CGFloat) -> CGAffineTransform {
        CGAffineTransform(scaleX: x, y: y).concatenating(self)
    }

    /// Returns the transform rotated by an angle (radians).
    public func rotated(by angle: CGFloat) -> CGAffineTransform {
        CGAffineTransform(rotationAngle: angle).concatenating(self)
    }

    /// Returns the inverse, or the transform unchanged when it is singular
    /// (CoreGraphics' documented fallback).
    public func inverted() -> CGAffineTransform {
        let determinant = a * d - b * c
        guard determinant != 0 else {
            return self
        }
        let inverseDeterminant = 1 / determinant
        return CGAffineTransform(
            a: d * inverseDeterminant,
            b: -b * inverseDeterminant,
            c: -c * inverseDeterminant,
            d: a * inverseDeterminant,
            tx: (c * ty - d * tx) * inverseDeterminant,
            ty: (b * tx - a * ty) * inverseDeterminant
        )
    }
}

extension CGPoint {
    /// Returns the point transformed by an affine transform.
    public func applying(_ transform: CGAffineTransform) -> CGPoint {
        CGPoint(
            x: transform.a * x + transform.c * y + transform.tx,
            y: transform.b * x + transform.d * y + transform.ty
        )
    }
}

extension CGSize {
    /// Returns the size transformed by an affine transform (translation ignored).
    public func applying(_ transform: CGAffineTransform) -> CGSize {
        CGSize(
            width: transform.a * width + transform.c * height,
            height: transform.b * width + transform.d * height
        )
    }
}

// C math via the CRT, keeping the module dependency-free (real Foundation is
// unavailable on this toolchain; the same approach WinFoundation uses).
@_silgen_name("cos")
private func _win_cos(_ value: Double) -> Double

@_silgen_name("sin")
private func _win_sin(_ value: Double) -> Double
