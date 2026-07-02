/// A vector path of lines and cubic Bezier curves.
///
/// This first slice covers the construction and drawing surface custom views
/// need inside `NSView.draw(_:)`: move/line/curve/close building, rectangle,
/// oval, and rounded-rectangle conveniences, and `fill()`/`stroke()` against
/// the current `NSGraphicsContext`. Hit testing, transforms, and path
/// enumeration are future work.
open class NSBezierPath {
    /// Constant for approximating a quarter circle with one cubic Bezier.
    private static let circleApproximation: CGFloat = 0.5522847498

    /// The path's segments in the order they were added.
    internal private(set) var nativeSegments: [NativePathSegment] = []

    /// Width used by `stroke()`.
    open var lineWidth: CGFloat = 1

    /// Creates an empty path.
    public init() {
    }

    /// Creates a rectangular path.
    public init(rect: NSRect) {
        appendRect(rect)
    }

    /// Creates an oval path inscribed in a rectangle.
    public init(ovalIn rect: NSRect) {
        appendOval(in: rect)
    }

    /// Creates a rounded-rectangle path.
    public init(roundedRect rect: NSRect, xRadius: CGFloat, yRadius: CGFloat) {
        appendRoundedRect(rect, xRadius: xRadius, yRadius: yRadius)
    }

    // MARK: - Construction

    /// Begins a new subpath at a point.
    open func move(to point: NSPoint) {
        nativeSegments.append(.move(point))
    }

    /// Adds a line from the current point to a point.
    open func line(to point: NSPoint) {
        nativeSegments.append(.line(point))
    }

    /// Adds a cubic Bezier curve to an end point with two control points.
    open func curve(to endPoint: NSPoint, controlPoint1: NSPoint, controlPoint2: NSPoint) {
        nativeSegments.append(.curve(to: endPoint, control1: controlPoint1, control2: controlPoint2))
    }

    /// Closes the current subpath.
    open func close() {
        nativeSegments.append(.close)
    }

    /// Removes all segments from the path.
    open func removeAllPoints() {
        nativeSegments.removeAll()
    }

    /// Whether the path has no segments.
    open var isEmpty: Bool {
        nativeSegments.isEmpty
    }

    /// Appends a rectangle subpath.
    open func appendRect(_ rect: NSRect) {
        move(to: rect.origin)
        line(to: NSMakePoint(NSMaxX(rect), rect.origin.y))
        line(to: NSMakePoint(NSMaxX(rect), NSMaxY(rect)))
        line(to: NSMakePoint(rect.origin.x, NSMaxY(rect)))
        close()
    }

    /// Appends an oval subpath inscribed in a rectangle.
    open func appendOval(in rect: NSRect) {
        let radiusX = rect.size.width / 2
        let radiusY = rect.size.height / 2
        let centerX = NSMidX(rect)
        let centerY = NSMidY(rect)
        let controlX = radiusX * Self.circleApproximation
        let controlY = radiusY * Self.circleApproximation

        move(to: NSMakePoint(centerX + radiusX, centerY))
        curve(
            to: NSMakePoint(centerX, centerY + radiusY),
            controlPoint1: NSMakePoint(centerX + radiusX, centerY + controlY),
            controlPoint2: NSMakePoint(centerX + controlX, centerY + radiusY)
        )
        curve(
            to: NSMakePoint(centerX - radiusX, centerY),
            controlPoint1: NSMakePoint(centerX - controlX, centerY + radiusY),
            controlPoint2: NSMakePoint(centerX - radiusX, centerY + controlY)
        )
        curve(
            to: NSMakePoint(centerX, centerY - radiusY),
            controlPoint1: NSMakePoint(centerX - radiusX, centerY - controlY),
            controlPoint2: NSMakePoint(centerX - controlX, centerY - radiusY)
        )
        curve(
            to: NSMakePoint(centerX + radiusX, centerY),
            controlPoint1: NSMakePoint(centerX + controlX, centerY - radiusY),
            controlPoint2: NSMakePoint(centerX + radiusX, centerY - controlY)
        )
        close()
    }

    /// Appends a rounded-rectangle subpath.
    open func appendRoundedRect(_ rect: NSRect, xRadius: CGFloat, yRadius: CGFloat) {
        let radiusX = min(max(xRadius, 0), rect.size.width / 2)
        let radiusY = min(max(yRadius, 0), rect.size.height / 2)
        guard radiusX > 0 && radiusY > 0 else {
            appendRect(rect)
            return
        }

        let controlX = radiusX * Self.circleApproximation
        let controlY = radiusY * Self.circleApproximation
        let left = rect.origin.x
        let top = rect.origin.y
        let right = NSMaxX(rect)
        let bottom = NSMaxY(rect)

        move(to: NSMakePoint(left + radiusX, top))
        line(to: NSMakePoint(right - radiusX, top))
        curve(
            to: NSMakePoint(right, top + radiusY),
            controlPoint1: NSMakePoint(right - radiusX + controlX, top),
            controlPoint2: NSMakePoint(right, top + radiusY - controlY)
        )
        line(to: NSMakePoint(right, bottom - radiusY))
        curve(
            to: NSMakePoint(right - radiusX, bottom),
            controlPoint1: NSMakePoint(right, bottom - radiusY + controlY),
            controlPoint2: NSMakePoint(right - radiusX + controlX, bottom)
        )
        line(to: NSMakePoint(left + radiusX, bottom))
        curve(
            to: NSMakePoint(left, bottom - radiusY),
            controlPoint1: NSMakePoint(left + radiusX - controlX, bottom),
            controlPoint2: NSMakePoint(left, bottom - radiusY + controlY)
        )
        line(to: NSMakePoint(left, top + radiusY))
        curve(
            to: NSMakePoint(left + radiusX, top),
            controlPoint1: NSMakePoint(left, top + radiusY - controlY),
            controlPoint2: NSMakePoint(left + radiusX - controlX, top)
        )
        close()
    }

    // MARK: - Drawing

    /// Fills the path with the current fill color.
    open func fill() {
        guard let context = NSGraphicsContext.current, !nativeSegments.isEmpty else {
            return
        }

        context.nativeContext.fillPath(nativeSegments, color: context.fillColor)
    }

    /// Strokes the path with the current stroke color and `lineWidth`.
    open func stroke() {
        guard let context = NSGraphicsContext.current, !nativeSegments.isEmpty else {
            return
        }

        context.nativeContext.strokePath(nativeSegments, color: context.strokeColor, lineWidth: lineWidth)
    }
}
