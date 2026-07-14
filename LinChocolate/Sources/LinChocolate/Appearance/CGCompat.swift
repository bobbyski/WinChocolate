import Foundation

/// Core Graphics-compatible drawing surface over LinChocolate's context — the
/// LinChocolate port of WinChocolate's `CGCompat.swift`, kept API-identical so
/// the shared demo compiles against either library.
///
/// AppKit consumers draw through `CGContext` (`NSGraphicsContext.current?
/// .cgContext`, `CGMutablePath`, `CGGradient`); Linux's corelibs Foundation has
/// the geometry types (CGRect/CGPoint/CGFloat) but no Core Graphics, so this
/// file gives those names LinChocolate-backed meanings:
///
///     CGColor   = NSColor            (colors are RGBA values here)
///     CGContext = NSGraphicsContext  (+ the CG drawing ops as methods)
///     CGPath/CGMutablePath           (path recorded as segments)
///     CGGradient/CGColorSpace        (value stand-ins for the gradient API)
///
/// The op set covers what AppKit-shaped drawing code actually calls — paths,
/// fills, strokes, clipping, translate/scale/rotate transforms, and linear/
/// radial gradients — not the whole of Core Graphics. Rendering goes through
/// the `NativeGraphicsContext` seam (Cairo on GTK), so everything lands in the
/// same pipeline as `NSBezierPath`.

// MARK: - Colors

/// The Core Graphics color name: LinChocolate colors are already plain
/// RGBA values, so `CGColor` is `NSColor` itself.
public typealias CGColor = NSColor

extension NSColor {
    /// The color as a `CGColor` — itself, matching the AppKit spelling.
    public var cgColor: CGColor { self }
}

/// A color-space stand-in. LinChocolate colors are device-independent RGBA
/// values, so spaces carry no conversion — the type exists so AppKit-shaped
/// gradient code compiles unchanged.
public final class CGColorSpace: @unchecked Sendable {
    /// The sRGB space name.
    public static let sRGB = "kCGColorSpaceSRGB"

    /// Creates a named color space; all names resolve to the same identity
    /// space here.
    public init?(name: String) {}

    /// Creates the device RGB space.
    init() {}
}

/// Creates the device RGB color space, matching the C-style CG spelling.
public func CGColorSpaceCreateDeviceRGB() -> CGColorSpace {
    CGColorSpace()
}

/// Core Foundation array stand-in for the `colors as CFArray` gradient idiom.
public typealias CFArray = [Any]

/// Line-cap styles, matching Core Graphics' names.
public enum CGLineCap: Sendable {
    case butt
    case round
    case square
}

// MARK: - Path segments and transforms (shim internals)

/// One recorded path segment (the CG shim's path representation).
enum CGPathSegment {
    case move(CGPoint)
    case line(CGPoint)
    case curve(to: CGPoint, control1: CGPoint, control2: CGPoint)
    case close
}

/// A minimal 2×3 affine transform for the CG shim's user-space ops
/// (translate/scale/rotate). Foundation on Linux has no `CGAffineTransform`.
struct CGShimTransform {
    var a: CGFloat = 1, b: CGFloat = 0, c: CGFloat = 0, d: CGFloat = 1
    var tx: CGFloat = 0, ty: CGFloat = 0

    /// Prepends (new ∘ current): subsequent ops happen in the new space.
    mutating func prepend(a na: CGFloat, b nb: CGFloat, c nc: CGFloat, d nd: CGFloat, tx ntx: CGFloat, ty nty: CGFloat) {
        let ra = na * a + nb * c
        let rb = na * b + nb * d
        let rc = nc * a + nd * c
        let rd = nc * b + nd * d
        let rtx = ntx * a + nty * c + tx
        let rty = ntx * b + nty * d + ty
        (a, b, c, d, tx, ty) = (ra, rb, rc, rd, rtx, rty)
    }

    /// Applies the transform to a point.
    func apply(to point: CGPoint) -> CGPoint {
        CGPoint(x: a * point.x + c * point.y + tx,
                y: b * point.x + d * point.y + ty)
    }

    /// A representative scale factor (for radii under uniform-ish scaling).
    var scaleMagnitude: CGFloat {
        ((a * a + b * b).squareRoot() + (c * c + d * d).squareRoot()) / 2
    }
}

// MARK: - Paths

/// An immutable drawing path, matching Core Graphics' shape.
///
/// The mutable subclass adds the builder calls. Arcs, ellipses, and rounded
/// rects flatten to Bézier curves — the same segments the native renderer
/// consumes.
public class CGPath {
    /// The segments the path has accumulated.
    private(set) var linSegments: [CGPathSegment] = []

    // The current point, tracked for arc/quad-curve conversion.
    private(set) var linCurrentPoint: CGPoint = .zero

    /// Creates an empty path.
    public init() {}

    // Appends a segment and tracks the pen position.
    func linAppend(_ segment: CGPathSegment) {
        linSegments.append(segment)
        switch segment {
        case .move(let point), .line(let point):
            linCurrentPoint = point
        case .curve(let endPoint, _, _):
            linCurrentPoint = endPoint
        case .close:
            break
        }
    }
}

/// A mutable drawing path, matching Core Graphics' builder surface.
public final class CGMutablePath: CGPath {
    /// Starts a new subpath at a point.
    public func move(to point: CGPoint) {
        linAppend(.move(point))
    }

    /// Adds a line to a point.
    public func addLine(to point: CGPoint) {
        linAppend(.line(point))
    }

    /// Adds a cubic Bézier curve.
    public func addCurve(to end: CGPoint, control1: CGPoint, control2: CGPoint) {
        linAppend(.curve(to: end, control1: control1, control2: control2))
    }

    /// Adds a quadratic Bézier curve, elevated to the cubic the native
    /// renderer consumes.
    public func addQuadCurve(to end: CGPoint, control: CGPoint) {
        let start = linCurrentPoint
        let control1 = CGPoint(
            x: start.x + 2.0 / 3.0 * (control.x - start.x),
            y: start.y + 2.0 / 3.0 * (control.y - start.y)
        )
        let control2 = CGPoint(
            x: end.x + 2.0 / 3.0 * (control.x - end.x),
            y: end.y + 2.0 / 3.0 * (control.y - end.y)
        )
        addCurve(to: end, control1: control1, control2: control2)
    }

    /// Adds a rectangle as a closed subpath.
    public func addRect(_ rect: CGRect) {
        move(to: CGPoint(x: rect.minX, y: rect.minY))
        addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        closeSubpath()
    }

    /// Adds an ellipse inscribed in a rectangle, as four Bézier quadrants.
    public func addEllipse(in rect: CGRect) {
        // The circle-to-Bézier control-point factor.
        let kappa: CGFloat = 0.5522847498
        let cx = rect.midX, cy = rect.midY
        let rx = rect.width / 2, ry = rect.height / 2
        let ox = rx * kappa, oy = ry * kappa

        move(to: CGPoint(x: cx + rx, y: cy))
        addCurve(to: CGPoint(x: cx, y: cy + ry),
                 control1: CGPoint(x: cx + rx, y: cy + oy),
                 control2: CGPoint(x: cx + ox, y: cy + ry))
        addCurve(to: CGPoint(x: cx - rx, y: cy),
                 control1: CGPoint(x: cx - ox, y: cy + ry),
                 control2: CGPoint(x: cx - rx, y: cy + oy))
        addCurve(to: CGPoint(x: cx, y: cy - ry),
                 control1: CGPoint(x: cx - rx, y: cy - oy),
                 control2: CGPoint(x: cx - ox, y: cy - ry))
        addCurve(to: CGPoint(x: cx + rx, y: cy),
                 control1: CGPoint(x: cx + ox, y: cy - ry),
                 control2: CGPoint(x: cx + rx, y: cy - oy))
        closeSubpath()
    }

    /// Adds a rounded rectangle as lines joined by Bézier corner quadrants.
    public func addRoundedRect(in rect: CGRect, cornerWidth: CGFloat, cornerHeight: CGFloat) {
        let rx = min(cornerWidth, rect.width / 2)
        let ry = min(cornerHeight, rect.height / 2)
        let kappa: CGFloat = 0.5522847498
        let ox = rx * kappa, oy = ry * kappa

        move(to: CGPoint(x: rect.minX + rx, y: rect.minY))
        addLine(to: CGPoint(x: rect.maxX - rx, y: rect.minY))
        addCurve(to: CGPoint(x: rect.maxX, y: rect.minY + ry),
                 control1: CGPoint(x: rect.maxX - rx + ox, y: rect.minY),
                 control2: CGPoint(x: rect.maxX, y: rect.minY + ry - oy))
        addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - ry))
        addCurve(to: CGPoint(x: rect.maxX - rx, y: rect.maxY),
                 control1: CGPoint(x: rect.maxX, y: rect.maxY - ry + oy),
                 control2: CGPoint(x: rect.maxX - rx + ox, y: rect.maxY))
        addLine(to: CGPoint(x: rect.minX + rx, y: rect.maxY))
        addCurve(to: CGPoint(x: rect.minX, y: rect.maxY - ry),
                 control1: CGPoint(x: rect.minX + rx - ox, y: rect.maxY),
                 control2: CGPoint(x: rect.minX, y: rect.maxY - ry + oy))
        addLine(to: CGPoint(x: rect.minX, y: rect.minY + ry))
        addCurve(to: CGPoint(x: rect.minX + rx, y: rect.minY),
                 control1: CGPoint(x: rect.minX, y: rect.minY + ry - oy),
                 control2: CGPoint(x: rect.minX + rx - ox, y: rect.minY))
        closeSubpath()
    }

    /// Adds a circular arc, flattened to Bézier segments of at most a
    /// quarter turn each.
    public func addArc(
        center: CGPoint,
        radius: CGFloat,
        startAngle: CGFloat,
        endAngle: CGFloat,
        clockwise: Bool
    ) {
        // Normalize sweep direction: work in the drawing's y-down space.
        var start = startAngle
        var end = endAngle
        if clockwise {
            swap(&start, &end)
        }
        if end < start {
            end += 2 * .pi
        }

        var angle = start
        let startPoint = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
        if linSegments.isEmpty {
            move(to: startPoint)
        } else {
            addLine(to: startPoint)
        }

        while angle < end - 0.0001 {
            let step = min(.pi / 2, end - angle)
            let next = angle + step
            // Control-point distance for a Bézier approximating this sweep.
            let alpha = 4.0 / 3.0 * (sin(step / 4) / cos(step / 4))
            let from = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            let to = CGPoint(x: center.x + radius * cos(next), y: center.y + radius * sin(next))
            let control1 = CGPoint(
                x: from.x - alpha * radius * sin(angle),
                y: from.y + alpha * radius * cos(angle)
            )
            let control2 = CGPoint(
                x: to.x + alpha * radius * sin(next),
                y: to.y - alpha * radius * cos(next)
            )
            addCurve(to: to, control1: control1, control2: control2)
            angle = next
        }
    }

    /// Closes the current subpath.
    public func closeSubpath() {
        linAppend(.close)
    }
}

// MARK: - Gradients

/// Gradient drawing options, matching Core Graphics' names. The native
/// renderer always extends the end colors, so the options are accepted and
/// carry no additional behavior.
public struct CGGradientDrawingOptions: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// Extend the first color before the start location.
    public static let drawsBeforeStartLocation = CGGradientDrawingOptions(rawValue: 1 << 0)

    /// Extend the last color past the end location.
    public static let drawsAfterEndLocation = CGGradientDrawingOptions(rawValue: 1 << 1)
}

/// A color ramp for gradient drawing, matching Core Graphics' shape.
public final class CGGradient {
    /// The ramp as native stops.
    let linStops: [NativeGradientStop]

    /// Creates a gradient from colors and locations. Locations default to
    /// an even spread when nil.
    public init?(colorsSpace: CGColorSpace?, colors: CFArray, locations: [CGFloat]?) {
        let rampColors = colors.compactMap { $0 as? NSColor }
        guard !rampColors.isEmpty else {
            return nil
        }

        let rampLocations: [CGFloat]
        if let locations, locations.count == rampColors.count {
            rampLocations = locations
        } else if rampColors.count == 1 {
            rampLocations = [0]
        } else {
            rampLocations = (0..<rampColors.count).map { CGFloat($0) / CGFloat(rampColors.count - 1) }
        }

        linStops = zip(rampColors, rampLocations).map { NativeGradientStop(color: $0, location: $1) }
    }

    /// The interpolated color at a unit position along the ramp.
    func linColor(at position: CGFloat) -> NSColor {
        guard let first = linStops.first else {
            return .black
        }
        guard let after = linStops.first(where: { $0.location >= position }) else {
            return linStops.last?.color ?? first.color
        }
        guard let before = linStops.last(where: { $0.location <= position }), after.location > before.location else {
            return after.color
        }

        let t = (position - before.location) / (after.location - before.location)
        return NSColor(
            calibratedRed: before.color.redComponent + t * (after.color.redComponent - before.color.redComponent),
            green: before.color.greenComponent + t * (after.color.greenComponent - before.color.greenComponent),
            blue: before.color.blueComponent + t * (after.color.blueComponent - before.color.blueComponent),
            alpha: before.color.alphaComponent + t * (after.color.alphaComponent - before.color.alphaComponent)
        )
    }
}

// MARK: - Context

/// The Core Graphics context name: LinChocolate's graphics context carries
/// the drawing state, and the extension below gives it the CG op surface.
public typealias CGContext = NSGraphicsContext

extension NSGraphicsContext {
    /// The context as a `CGContext` — itself, matching the AppKit spelling.
    public var cgContext: CGContext { self }

    // MARK: State

    /// Saves the graphics state, including the clip region and the shim's
    /// transform and path state.
    public func saveGState() {
        cgTransformStack.append(cgTransform)
        native.saveState()
    }

    /// Restores the most recently saved graphics state.
    public func restoreGState() {
        if let transform = cgTransformStack.popLast() {
            cgTransform = transform
        }
        native.restoreState()
    }

    /// Sets the fill color for subsequent fill operations.
    public func setFillColor(_ color: CGColor) {
        cgFillColor = color
        native.setFillColor(color)
    }

    /// Sets the stroke color for subsequent stroke operations.
    public func setStrokeColor(_ color: CGColor) {
        cgStrokeColor = color
        native.setStrokeColor(color)
    }

    /// Sets the stroke line width.
    public func setLineWidth(_ width: CGFloat) {
        cgLineWidth = width
    }

    /// Sets the stroke line-cap style. Stored for CG shape; the native
    /// stroke primitive renders its default caps.
    public func setLineCap(_ cap: CGLineCap) {
        cgLineCap = cap
    }

    // MARK: Transforms

    /// Translates the user space.
    public func translateBy(x: CGFloat, y: CGFloat) {
        cgTransform.prepend(a: 1, b: 0, c: 0, d: 1, tx: x, ty: y)
    }

    /// Scales the user space.
    public func scaleBy(x: CGFloat, y: CGFloat) {
        cgTransform.prepend(a: x, b: 0, c: 0, d: y, tx: 0, ty: 0)
    }

    /// Rotates the user space by an angle in radians.
    public func rotate(by angle: CGFloat) {
        let cosine = cos(angle)
        let sine = sin(angle)
        cgTransform.prepend(a: cosine, b: sine, c: -sine, d: cosine, tx: 0, ty: 0)
    }

    // MARK: Paths

    /// Sets the pending path for the next fill/stroke/clip operation.
    public func addPath(_ path: CGPath) {
        cgPendingSegments.append(contentsOf: path.linSegments.map(cgTransformed))
    }

    /// Appends a circular arc to the pending path.
    public func addArc(
        center: CGPoint,
        radius: CGFloat,
        startAngle: CGFloat,
        endAngle: CGFloat,
        clockwise: Bool
    ) {
        let path = CGMutablePath()
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: clockwise)
        addPath(path)
    }

    /// Fills the pending path with the fill color.
    public func fillPath() {
        let segments = cgTakePendingSegments()
        guard !segments.isEmpty else { return }
        native.setFillColor(cgFillColor)
        cgReplay(segments)
        native.fillPath()
    }

    /// Strokes the pending path with the stroke color and line width.
    public func strokePath() {
        let segments = cgTakePendingSegments()
        guard !segments.isEmpty else { return }
        native.setStrokeColor(cgStrokeColor)
        native.setLineWidth(Double(cgLineWidth))
        cgReplay(segments)
        native.strokePath()
    }

    /// Intersects the clip region with the pending path.
    public func clip() {
        let segments = cgTakePendingSegments()
        guard !segments.isEmpty else { return }
        cgReplay(segments)
        native.clipToCurrentPath()
    }

    /// Intersects the clip region with a rectangle.
    public func clip(to rect: CGRect) {
        let path = CGMutablePath()
        path.addRect(rect)
        addPath(path)
        clip()
    }

    /// Fills a rectangle with the fill color.
    public func fill(_ rect: CGRect) {
        let path = CGMutablePath()
        path.addRect(rect)
        addPath(path)
        fillPath()
    }

    /// Strokes a rectangle with the stroke color.
    public func stroke(_ rect: CGRect) {
        let path = CGMutablePath()
        path.addRect(rect)
        addPath(path)
        strokePath()
    }

    /// Fills an ellipse inscribed in a rectangle.
    public func fillEllipse(in rect: CGRect) {
        let path = CGMutablePath()
        path.addEllipse(in: rect)
        addPath(path)
        fillPath()
    }

    /// Strokes an ellipse inscribed in a rectangle.
    public func strokeEllipse(in rect: CGRect) {
        let path = CGMutablePath()
        path.addEllipse(in: rect)
        addPath(path)
        strokePath()
    }

    // MARK: Gradients

    /// Draws a linear gradient between two points.
    ///
    /// The native renderer paints axis-projected linear ramps across the
    /// clip; start/end map to the ramp direction and extent.
    public func drawLinearGradient(
        _ gradient: CGGradient,
        start: CGPoint,
        end: CGPoint,
        options: CGGradientDrawingOptions
    ) {
        let from = cgTransformed(start)
        let to = cgTransformed(end)
        let rect = CGRect(
            x: min(from.x, to.x),
            y: min(from.y, to.y),
            width: max(abs(to.x - from.x), 1),
            height: max(abs(to.y - from.y), 1)
        )
        let angle = atan2(to.y - from.y, to.x - from.x)
        native.fillLinearGradient(gradient.linStops, inRect: rect, angleDegrees: Double(angle * 180 / .pi))
    }

    /// Draws a radial gradient as concentric interpolated rings — the seam
    /// has only a centered radial primitive, so the ramp rasterizes
    /// outside-in over the path primitives it does have.
    public func drawRadialGradient(
        _ gradient: CGGradient,
        startCenter: CGPoint,
        startRadius: CGFloat,
        endCenter: CGPoint,
        endRadius: CGFloat,
        options: CGGradientDrawingOptions
    ) {
        let center = cgTransformed(endCenter)
        let scaledEnd = endRadius * cgTransform.scaleMagnitude
        let scaledStart = startRadius * cgTransform.scaleMagnitude
        let rings = 48
        for ring in stride(from: rings - 1, through: 0, by: -1) {
            let fraction = CGFloat(ring) / CGFloat(rings - 1)
            let radius = scaledStart + fraction * (scaledEnd - scaledStart)
            guard radius > 0 else { continue }
            let color = gradient.linColor(at: fraction)
            let path = CGMutablePath()
            path.addEllipse(in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
            native.setFillColor(color)
            cgReplay(path.linSegments)
            native.fillPath()
        }
        // Restore the caller's fill color after the per-ring overrides.
        native.setFillColor(cgFillColor)
    }

    // MARK: Shim state helpers

    // Applies the current transform to a point.
    private func cgTransformed(_ point: CGPoint) -> CGPoint {
        cgTransform.apply(to: point)
    }

    // Applies the current transform to a segment.
    private func cgTransformed(_ segment: CGPathSegment) -> CGPathSegment {
        switch segment {
        case .move(let point):
            return .move(cgTransformed(point))
        case .line(let point):
            return .line(cgTransformed(point))
        case .curve(let end, let control1, let control2):
            return .curve(to: cgTransformed(end), control1: cgTransformed(control1), control2: cgTransformed(control2))
        case .close:
            return .close
        }
    }

    // Replays segments into the native context as its current path.
    private func cgReplay(_ segments: [CGPathSegment]) {
        native.beginPath()
        for segment in segments {
            switch segment {
            case .move(let p):
                native.move(toX: Double(p.x), y: Double(p.y))
            case .line(let p):
                native.line(toX: Double(p.x), y: Double(p.y))
            case .curve(let to, let c1, let c2):
                native.curve(toX: Double(to.x), y: Double(to.y),
                             c1x: Double(c1.x), c1y: Double(c1.y),
                             c2x: Double(c2.x), c2y: Double(c2.y))
            case .close:
                native.closePath()
            }
        }
    }

    // Consumes the pending path, resetting it for the next operation.
    private func cgTakePendingSegments() -> [CGPathSegment] {
        let segments = cgPendingSegments
        cgPendingSegments = []
        return segments
    }
}
