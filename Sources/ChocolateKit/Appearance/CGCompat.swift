/// Core Graphics-compatible drawing surface over WinChocolate's context.
///
/// AppKit consumers draw through `CGContext` (`NSGraphicsContext.current?
/// .cgColor`, `CGMutablePath`, `CGGradient`); Windows has no Core Graphics,
/// so this file gives those names WinChocolate-backed meanings:
///
///     CGColor   = NSColor            (colors are RGBA values here)
///     CGContext = NSGraphicsContext  (+ the CG drawing ops as methods)
///     CGPath/CGMutablePath           (path built from native segments)
///     CGGradient/CGColorSpace        (value stand-ins for the gradient API)
///
/// The op set covers what AppKit-shaped drawing code actually calls — paths,
/// fills, strokes, clipping, translate/scale transforms, and linear/radial
/// gradients — not the whole of Core Graphics. Radial gradients rasterize as
/// concentric interpolated rings over the native path primitives.

// MARK: - Colors

/// The Core Graphics color name: WinChocolate colors are already plain
/// RGBA values, so `CGColor` is `NSColor` itself.
public typealias CGColor = NSColor

extension NSColor {
    /// The color as a `CGColor` — itself, matching the AppKit spelling.
    public var cgColor: CGColor { self }
}

// `CGColorSpace` and `CGColorSpaceCreateDeviceRGB()` moved to WinCoreGraphics
// (they are CoreGraphics value types on Apple, and `CGImage`'s designated
// initializer takes a `CGColorSpace`). They remain visible here via
// WinChocolate's `@_exported import WinCoreGraphics`.

/// Core Foundation array stand-in for the `colors as CFArray` gradient idiom.
public typealias CFArray = [Any]

/// Line-cap styles, matching Core Graphics' names.
public enum CGLineCap: Sendable {
    case butt
    case round
    case square
}

/// Line-join styles, matching Core Graphics' names.
public enum CGLineJoin: Sendable {
    case miter
    case round
    case bevel
}

/// How `drawPath(using:)` consumes the pending path.
public enum CGPathDrawingMode: Sendable {
    case fill
    case eoFill
    case stroke
    case fillStroke
    case eoFillStroke
}

// MARK: - Paths

/// An immutable drawing path, matching Core Graphics' shape.
///
/// Backed by WinChocolate's native path segments; the mutable subclass adds
/// the builder calls. Arcs, ellipses, and rounded rects flatten to Bézier
/// curves — the same segments the native renderer consumes.
public class CGPath {
    /// The native segments the path has accumulated.
    private(set) var winSegments: [NativePathSegment] = []

    // The current point, tracked for arc/quad-curve conversion.
    private(set) var winCurrentPoint: CGPoint = .zero

    /// Creates an empty path.
    public init() {}

    /// Creates a rounded rectangle path, matching Core Graphics' initializer.
    ///
    /// The `transform` parameter is accepted because drawing code spells it
    /// out — `transform: nil` at every call site — and a signature without it
    /// would reject all of them. A non-nil transform is applied to the points.
    public convenience init(roundedRect rect: CGRect,
                            cornerWidth: CGFloat,
                            cornerHeight: CGFloat,
                            transform: UnsafePointer<CGAffineTransform>?) {
        let path = CGMutablePath()
        path.addRoundedRect(in: rect, cornerWidth: cornerWidth, cornerHeight: cornerHeight)
        self.init(winSegments: path.winSegments, transform: transform)
    }

    /// Creates a rectangle path.
    public convenience init(rect: CGRect, transform: UnsafePointer<CGAffineTransform>?) {
        let path = CGMutablePath()
        path.addRect(rect)
        self.init(winSegments: path.winSegments, transform: transform)
    }

    /// Creates an ellipse path inscribed in a rectangle.
    public convenience init(ellipseIn rect: CGRect, transform: UnsafePointer<CGAffineTransform>?) {
        let path = CGMutablePath()
        path.addEllipse(in: rect)
        self.init(winSegments: path.winSegments, transform: transform)
    }

    // The shared body of the three initializers above.
    init(winSegments segments: [NativePathSegment], transform: UnsafePointer<CGAffineTransform>?) {
        guard let transform else {
            winSegments = segments
            return
        }
        let matrix = transform.pointee
        func map(_ point: CGPoint) -> CGPoint {
            CGPoint(x: matrix.a * point.x + matrix.c * point.y + matrix.tx,
                    y: matrix.b * point.x + matrix.d * point.y + matrix.ty)
        }
        winSegments = segments.map { segment in
            switch segment {
            case .move(let point): return .move(map(point))
            case .line(let point): return .line(map(point))
            case .curve(let end, let c1, let c2): return .curve(to: map(end), control1: map(c1), control2: map(c2))
            case .close: return .close
            }
        }
    }

    // Appends a segment and tracks the pen position.
    func winAppend(_ segment: NativePathSegment) {
        winSegments.append(segment)
        switch segment {
        case .move(let point), .line(let point):
            winCurrentPoint = point
        case .curve(let endPoint, _, _):
            winCurrentPoint = endPoint
        case .close:
            break
        }
    }
}

/// One element of a path, as Core Graphics' `CGPathElement`.
public struct CGPathElement {
    /// The kinds of element a path is made of.
    public enum ElementType: Sendable {
        case moveToPoint
        case addLineToPoint
        case addQuadCurveToPoint
        case addCurveToPoint
        case closeSubpath
    }

    /// Which kind this element is.
    public let type: ElementType

    /// The element's points: one for a move or line, two for a quad curve,
    /// three for a cubic, none for a close — the same packing CG uses.
    public let points: UnsafeMutablePointer<CGPoint>
}

extension CGPath {
    /// Walks the path's elements, as Core Graphics' `applyWithBlock`.
    ///
    /// The way a path is *read* rather than built — flattening a shape into
    /// polylines, hit-testing it, exporting it. The framework stores cubic
    /// segments, so a quadratic is never reported: it was elevated to a cubic
    /// when it was added, exactly as the native renderers require.
    public func applyWithBlock(_ body: (UnsafePointer<CGPathElement>) -> Void) {
        for segment in winSegments {
            var storage: [CGPoint]
            let type: CGPathElement.ElementType
            switch segment {
            case .move(let point):
                storage = [point]; type = .moveToPoint
            case .line(let point):
                storage = [point]; type = .addLineToPoint
            case .curve(let end, let c1, let c2):
                // CG orders a cubic's points control1, control2, endpoint.
                storage = [c1, c2, end]; type = .addCurveToPoint
            case .close:
                storage = []; type = .closeSubpath
            }
            storage.withUnsafeMutableBufferPointer { buffer in
                let base = buffer.baseAddress ?? UnsafeMutablePointer<CGPoint>.allocate(capacity: 1)
                var element = CGPathElement(type: type, points: base)
                withUnsafePointer(to: &element) { body($0) }
            }
        }
    }
}

/// A mutable drawing path, matching Core Graphics' builder surface.
public final class CGMutablePath: CGPath {
    /// Starts a new subpath at a point.
    public func move(to point: CGPoint) {
        winAppend(.move(point))
    }

    /// Adds a line to a point.
    public func addLine(to point: CGPoint) {
        winAppend(.line(point))
    }

    /// Adds a cubic Bézier curve.
    public func addCurve(to end: CGPoint, control1: CGPoint, control2: CGPoint) {
        winAppend(.curve(to: end, control1: control1, control2: control2))
    }

    /// Adds a quadratic Bézier curve, elevated to the cubic the native
    /// renderer consumes.
    public func addQuadCurve(to end: CGPoint, control: CGPoint) {
        let start = winCurrentPoint
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
        if winSegments.isEmpty {
            move(to: startPoint)
        } else {
            addLine(to: startPoint)
        }

        while angle < end - 0.0001 {
            let step = min(.pi / 2, end - angle)
            let next = angle + step
            // Control-point distance for a Bézier approximating this sweep.
            let alpha = 4.0 / 3.0 * tanApprox(step / 4)
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

    // tan via sin/cos (the C runtime shims expose those two).
    private func tanApprox(_ x: CGFloat) -> CGFloat {
        sin(x) / cos(x)
    }

    /// Closes the current subpath.
    public func closeSubpath() {
        winAppend(.close)
    }
}

// MARK: - Gradients

/// Gradient drawing options, matching Core Graphics' names. The native
/// renderer always extends the end colors, so the options are accepted and
/// carry no additional behavior.
public struct CGGradientDrawingOptions: OptionSet, Sendable {
    /// The `rawValue` value.
    public let rawValue: UInt32

    /// Creates a value with the supplied arguments.
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
    let winStops: [NativeGradientStop]

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

        winStops = zip(rampColors, rampLocations).map { NativeGradientStop(color: $0, location: $1) }
    }

    /// The interpolated color at a unit position along the ramp.
    func winColor(at position: CGFloat) -> NSColor {
        guard let first = winStops.first else {
            return .black
        }
        guard let after = winStops.first(where: { $0.location >= position }) else {
            return winStops.last?.color ?? first.color
        }
        guard let before = winStops.last(where: { $0.location <= position }), after.location > before.location else {
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

/// The Core Graphics context name: WinChocolate's graphics context carries
/// the drawing state, and the extension below gives it the CG op surface.
public typealias CGContext = NSGraphicsContext

extension NSGraphicsContext {
    /// The context as a `CGContext` — itself, matching the AppKit spelling.
    public var cgContext: CGContext { self }

    // MARK: State

    /// Saves the graphics state, including the clip region and the shim's
    /// transform and path state.
    public func saveGState() {
        winTransformStack.append(winTransform)
        winStateStack.append(WinGState(alpha: winAlpha,
                                       lineWidth: winLineWidth,
                                       lineCap: winLineCap,
                                       lineJoin: winLineJoin,
                                       shouldAntialias: winShouldAntialias,
                                       lineDashLengths: winLineDashLengths,
                                       lineDashPhase: winLineDashPhase))
        nativeContext.saveState()
    }

    /// Restores the most recently saved graphics state.
    public func restoreGState() {
        if let transform = winTransformStack.popLast() {
            winTransform = transform
        }
        if let state = winStateStack.popLast() {
            winAlpha = state.alpha
            winLineWidth = state.lineWidth
            winLineCap = state.lineCap
            winLineJoin = state.lineJoin
            winShouldAntialias = state.shouldAntialias
            winLineDashLengths = state.lineDashLengths
            winLineDashPhase = state.lineDashPhase
        }
        nativeContext.restoreState()
    }

    /// Sets the fill color for subsequent fill operations.
    public func setFillColor(_ color: CGColor) {
        fillColor = color
    }

    /// Sets the stroke color for subsequent stroke operations.
    public func setStrokeColor(_ color: CGColor) {
        strokeColor = color
    }

    /// Sets the stroke line width.
    public func setLineWidth(_ width: CGFloat) {
        winLineWidth = width
    }

    /// Sets the stroke line-cap style. Stored for CG shape; the native
    /// stroke primitive renders its default caps.
    public func setLineCap(_ cap: CGLineCap) {
        winLineCap = cap
    }

    /// Sets the dash pattern applied to later strokes.
    ///
    /// **The dashing is done here, not by the backend.** `NativeDrawingContext`
    /// strokes a segment list and has no dash concept, and giving every backend
    /// one would mean Win32, GTK and canvas each implementing the same
    /// arithmetic slightly differently. Instead `strokePath` walks the path and
    /// hands down only the on-segments, so a dashed line is a dashed line
    /// everywhere by construction.
    ///
    /// An empty `lengths` clears the pattern, as it does in Core Graphics.
    /// Lengths that are all zero or negative would produce infinitely many
    /// zero-length dashes, so they clear it too rather than hang.
    public func setLineDash(phase: CGFloat, lengths: [CGFloat]) {
        let usable = lengths.filter { $0.isFinite && $0 >= 0 }
        winLineDashLengths = usable.contains(where: { $0 > 0 }) ? usable : []
        winLineDashPhase = winLineDashLengths.isEmpty ? 0 : max(0, phase)
    }

    // MARK: Transforms

    /// Translates the user space.
    public func translateBy(x: CGFloat, y: CGFloat) {
        winTransform.prepend(.init(tx: x, ty: y))
    }

    /// Scales the user space.
    public func scaleBy(x: CGFloat, y: CGFloat) {
        winTransform.prepend(.init(a: x, d: y))
    }

    /// Rotates the user space by an angle in radians.
    public func rotate(by angle: CGFloat) {
        let cosine = cos(angle)
        let sine = sin(angle)
        winTransform.prepend(.init(a: cosine, b: sine, c: -sine, d: cosine))
    }

    // MARK: Paths

    /// Sets the pending path for the next fill/stroke/clip operation.
    public func addPath(_ path: CGPath) {
        winPendingSegments.append(contentsOf: path.winSegments.map(winTransformed))
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

    /// Discards any pending path and starts a new one.
    ///
    /// Core Graphics contexts carry *one* current path, built by the context's
    /// own `move`/`addLine`/`addArc` calls and consumed by the next paint. The
    /// builder calls below exist because AppKit-shaped drawing code uses the
    /// context form as often as the `CGMutablePath` form, and a control written
    /// against one should not have to be rewritten for the other.
    public func beginPath() {
        winPendingSegments.removeAll()
    }

    /// Starts a new subpath at a point.
    public func move(to point: CGPoint) {
        winPendingSegments.append(winTransformed(.move(point)))
    }

    /// Adds a line from the current point.
    public func addLine(to point: CGPoint) {
        winPendingSegments.append(winTransformed(.line(point)))
    }

    /// Adds a connected series of lines through an array of points.
    ///
    /// Core Graphics' `addLines(between:)`, and its exact semantics: the first
    /// point *moves*, the rest connect. A caller that already has a current
    /// point and expects this to continue from it is wrong on Apple too, so
    /// matching the surprise is the correct behaviour.
    ///
    /// An empty array adds nothing rather than starting an empty subpath.
    public func addLines(between points: [CGPoint]) {
        guard let first = points.first else { return }
        move(to: first)
        for point in points.dropFirst() {
            addLine(to: point)
        }
    }

    /// Adds a cubic Bézier curve from the current point.
    public func addCurve(to end: CGPoint, control1: CGPoint, control2: CGPoint) {
        winPendingSegments.append(
            winTransformed(.curve(to: end, control1: control1, control2: control2))
        )
    }

    /// Closes the current subpath with a straight line back to its start.
    public func closePath() {
        winPendingSegments.append(.close)
    }

    /// Adds an ellipse inscribed in a rectangle to the pending path.
    public func addEllipse(in rect: CGRect) {
        let path = CGMutablePath()
        path.addEllipse(in: rect)
        addPath(path)
    }

    /// Adds a rectangle as a closed subpath of the pending path.
    public func addRect(_ rect: CGRect) {
        let path = CGMutablePath()
        path.addRect(rect)
        addPath(path)
    }

    /// Paints the pending path the way the mode asks for.
    ///
    /// The even-odd modes paint identically to their non-zero counterparts:
    /// the fill rule lives in the native renderer, and the seam does not carry
    /// it yet. Every other distinction the mode draws — fill, stroke, or both,
    /// in that order — is honoured.
    public func drawPath(using mode: CGPathDrawingMode) {
        switch mode {
        case .fill, .eoFill:
            fillPath()
        case .stroke:
            strokePath()
        case .fillStroke, .eoFillStroke:
            // The path is consumed by the first paint, so it is kept for the
            // second — CG paints one path twice here, not two paths once.
            let segments = winPendingSegments
            fillPath()
            winPendingSegments = segments
            strokePath()
        }
    }

    /// Sets the global alpha applied to everything painted after it.
    ///
    /// Core Graphics multiplies this into the source colour of every drawing
    /// operation, and `saveGState`/`restoreGState` bracket it — which is how
    /// callers fade a whole drawn control by wrapping its paint in one call.
    public func setAlpha(_ alpha: CGFloat) {
        winAlpha = max(0, min(1, alpha))
    }

    /// Sets the join style used where stroked segments meet.
    ///
    /// Stored rather than applied: the native seam carries a line width but no
    /// join style, so strokes render with each backend's default join. The
    /// value is kept so the state is not silently lost across a save/restore.
    public func setLineJoin(_ join: CGLineJoin) {
        winLineJoin = join
    }

    /// Sets whether drawing is antialiased.
    ///
    /// Stored for the same reason as the join style — every backend this
    /// framework targets antialiases by default, and none of them can be asked
    /// not to through the current seam.
    public func setShouldAntialias(_ shouldAntialias: Bool) {
        winShouldAntialias = shouldAntialias
    }

    /// Draws a decoded image into a rectangle.
    ///
    /// `CGImage` already carries its pixels as RGBA8 and the drawing seam
    /// already takes that form, so this is a real blit rather than a stub —
    /// the same path a data-backed `NSImage` takes.
    public func draw(_ image: CGImage, in rect: CGRect) {
        nativeContext.drawImage(rgbaPixels: image.pixels,
                                width: image.width,
                                height: image.height,
                                in: winTransformedRect(rect),
                                tint: nil)
    }

    /// Replaces the pending path with the outline its stroke would cover.
    ///
    /// **The one CG call that is real geometry rather than a forwarding.** It
    /// exists so a caller can *clip* to a stroke — `addPath; setLineWidth;
    /// replacePathWithStrokedPath; clip; drawGradient` is how a gradient-filled
    /// ring is drawn, and clipping to the unstroked path would fill the disc.
    ///
    /// The outline is built by flattening each subpath to a polyline and
    /// offsetting it by half the line width to either side: outward for the
    /// outer contour, inward for the inner one, which for the closed shapes
    /// this is used on (rounded rects, ellipses, arcs) is exactly the stroke.
    /// An open subpath gets the two offsets joined end to end, which is the
    /// same figure a butt-capped stroke covers.
    public func replacePathWithStrokedPath() {
        let flattened = winFlattenedSubpaths()
        let half = max(winLineWidth, 0.01) / 2
        var outlined: [NativePathSegment] = []
        for (points, isClosed) in flattened where points.count >= 2 {
            let outer = Self.winOffsetContour(points, by: half, closed: isClosed)
            let inner = Self.winOffsetContour(points, by: -half, closed: isClosed)
            outlined += Self.winContourSegments(outer)
            // The inner contour runs the other way so an even-odd or non-zero
            // fill leaves the middle empty, which is what a stroke looks like.
            outlined += Self.winContourSegments(inner.reversed())
        }
        winPendingSegments = outlined
    }

    // Flattens the pending path into polylines, one per subpath.
    private func winFlattenedSubpaths() -> [([CGPoint], Bool)] {
        var subpaths: [([CGPoint], Bool)] = []
        var current: [CGPoint] = []
        var here = CGPoint.zero

        func flush(closed: Bool) {
            if current.count >= 2 { subpaths.append((current, closed)) }
            current = []
        }

        for segment in winPendingSegments {
            switch segment {
            case .move(let point):
                flush(closed: false)
                current = [point]
                here = point
            case .line(let point):
                current.append(point)
                here = point
            case .curve(let end, let c1, let c2):
                // 16 steps is invisible at any size these controls are drawn
                // at, and keeps the outline cheap enough to run per frame.
                let steps = 16
                for step in 1...steps {
                    let t = CGFloat(step) / CGFloat(steps)
                    let u = 1 - t
                    let x = u*u*u*here.x + 3*u*u*t*c1.x + 3*u*t*t*c2.x + t*t*t*end.x
                    let y = u*u*u*here.y + 3*u*u*t*c1.y + 3*u*t*t*c2.y + t*t*t*end.y
                    current.append(CGPoint(x: x, y: y))
                }
                here = end
            case .close:
                flush(closed: true)
            }
        }
        flush(closed: false)
        return subpaths
    }

    // Offsets a polyline by a signed distance along its own normals.
    private static func winOffsetContour(_ points: [CGPoint], by distance: CGFloat,
                                         closed: Bool) -> [CGPoint] {
        var result: [CGPoint] = []
        let count = points.count
        for index in 0..<count {
            let previous = points[(index - 1 + count) % count]
            let next = points[(index + 1) % count]
            // The vertex normal is the average of its two edge normals, which
            // rounds corners slightly rather than mitering them — the right
            // trade for a clip path.
            let before = closed || index > 0 ? CGPoint(x: points[index].x - previous.x, y: points[index].y - previous.y) : .zero
            let after = closed || index < count - 1 ? CGPoint(x: next.x - points[index].x, y: next.y - points[index].y) : .zero
            var nx = -(before.y + after.y)
            var ny = before.x + after.x
            let length = (nx * nx + ny * ny).squareRoot()
            guard length > 0 else { continue }
            nx /= length
            ny /= length
            result.append(CGPoint(x: points[index].x + nx * distance,
                                  y: points[index].y + ny * distance))
        }
        return result
    }

    // Turns a polyline back into path segments.
    private static func winContourSegments(_ points: [CGPoint]) -> [NativePathSegment] {
        guard let first = points.first else { return [] }
        var segments: [NativePathSegment] = [.move(first)]
        for point in points.dropFirst() { segments.append(.line(point)) }
        segments.append(.close)
        return segments
    }

    // The rect in device space, so an image lands where the transform says.
    private func winTransformedRect(_ rect: CGRect) -> NSRect {
        let origin = winTransform.apply(to: CGPoint(x: rect.minX, y: rect.minY))
        let opposite = winTransform.apply(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return NSRect(x: min(origin.x, opposite.x), y: min(origin.y, opposite.y),
                      width: abs(opposite.x - origin.x), height: abs(opposite.y - origin.y))
    }

    /// Fills the pending path with the fill color.
    public func fillPath() {
        let segments = winTakePendingSegments()
        guard !segments.isEmpty else { return }
        nativeContext.fillPath(segments, color: winAlphaApplied(fillColor))
    }

    /// Strokes the pending path with the stroke color and line width.
    public func strokePath() {
        let segments = winTakePendingSegments()
        guard !segments.isEmpty else { return }
        nativeContext.strokePath(winDashed(segments),
                                 color: winAlphaApplied(strokeColor),
                                 lineWidth: winLineWidth)
    }

    /// Splits a path into the "on" runs of the current dash pattern.
    ///
    /// Returns the path unchanged when no pattern is set, which is the common
    /// case and must stay free.
    ///
    /// Curves are dashed by their chord rather than their arc: the segment list
    /// keeps control points, and flattening a Bezier here to measure it would
    /// mean re-implementing the backend's own curve tessellation at a different
    /// tolerance. A dashed curve is rare — dashes mark rules, guides and
    /// selection outlines, which are straight — and a chord-dashed curve is
    /// visibly a dashed curve, just with slightly uneven spacing.
    private func winDashed(_ segments: [NativePathSegment]) -> [NativePathSegment] {
        guard !winLineDashLengths.isEmpty else { return segments }

        var output: [NativePathSegment] = []
        var patternIndex = 0
        var remaining = winLineDashLengths[0]
        var drawing = true

        // Consume the phase before drawing anything, so a pattern can start
        // mid-dash the way CG's does.
        var phase = winLineDashPhase
        while phase > 0 {
            if phase < remaining {
                remaining -= phase
                phase = 0
            } else {
                phase -= remaining
                patternIndex = (patternIndex + 1) % winLineDashLengths.count
                remaining = winLineDashLengths[patternIndex]
                drawing.toggle()
            }
        }

        var current = NSPoint.zero
        var subpathStart = NSPoint.zero
        var penDown = false

        func dash(from start: NSPoint, to end: NSPoint) {
            let dx = end.x - start.x
            let dy = end.y - start.y
            let length = (dx * dx + dy * dy).squareRoot()
            guard length > 0 else { return }

            var travelled: CGFloat = 0
            while travelled < length {
                let step = min(remaining, length - travelled)
                let from = NSPoint(x: start.x + dx * (travelled / length),
                                   y: start.y + dy * (travelled / length))
                travelled += step
                let to = NSPoint(x: start.x + dx * (travelled / length),
                                 y: start.y + dy * (travelled / length))
                if drawing {
                    output.append(.move(from))
                    output.append(.line(to))
                }
                remaining -= step
                if remaining <= 0 {
                    patternIndex = (patternIndex + 1) % winLineDashLengths.count
                    remaining = winLineDashLengths[patternIndex]
                    drawing.toggle()
                }
            }
        }

        for segment in segments {
            switch segment {
            case .move(let point):
                current = point
                subpathStart = point
                penDown = true
            case .line(let point):
                if penDown { dash(from: current, to: point) }
                current = point
            case .curve(let to, _, _):
                if penDown { dash(from: current, to: to) }
                current = to
            case .close:
                if penDown { dash(from: current, to: subpathStart) }
                current = subpathStart
            }
        }
        return output
    }

    /// Intersects the clip region with the pending path.
    public func clip() {
        let segments = winTakePendingSegments()
        guard !segments.isEmpty else { return }
        nativeContext.clip(to: segments)
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
        let from = winTransformed(start)
        let to = winTransformed(end)
        let rect = CGRect(
            x: min(from.x, to.x),
            y: min(from.y, to.y),
            width: max(abs(to.x - from.x), 1),
            height: max(abs(to.y - from.y), 1)
        )
        let angle = atan2(to.y - from.y, to.x - from.x)
        nativeContext.drawLinearGradient(gradient.winStops, in: rect, angle: angle)
    }

    /// Draws a radial gradient as concentric interpolated rings — the
    /// native surface has no radial primitive, so the ramp rasterizes
    /// outside-in over the path primitives it does have.
    public func drawRadialGradient(
        _ gradient: CGGradient,
        startCenter: CGPoint,
        startRadius: CGFloat,
        endCenter: CGPoint,
        endRadius: CGFloat,
        options: CGGradientDrawingOptions
    ) {
        let center = winTransformed(endCenter)
        let scaledEnd = endRadius * winTransform.scaleMagnitude
        let scaledStart = startRadius * winTransform.scaleMagnitude
        let rings = 48
        for ring in stride(from: rings - 1, through: 0, by: -1) {
            let fraction = CGFloat(ring) / CGFloat(rings - 1)
            let radius = scaledStart + fraction * (scaledEnd - scaledStart)
            guard radius > 0 else { continue }
            let color = gradient.winColor(at: fraction)
            let path = CGMutablePath()
            path.addEllipse(in: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
            nativeContext.fillPath(path.winSegments, color: color)
        }
    }

    // MARK: Shim state helpers

    // Multiplies the context's global alpha into a colour, the way Core
    // Graphics folds `setAlpha` into every source colour.
    private func winAlphaApplied(_ color: NSColor) -> NSColor {
        guard winAlpha < 1 else { return color }
        return color.withAlphaComponent(color.alphaComponent * winAlpha)
    }

    // Applies the current transform to a point.
    private func winTransformed(_ point: CGPoint) -> CGPoint {
        winTransform.apply(to: point)
    }

    // Applies the current transform to a segment.
    private func winTransformed(_ segment: NativePathSegment) -> NativePathSegment {
        switch segment {
        case .move(let point):
            return .move(winTransformed(point))
        case .line(let point):
            return .line(winTransformed(point))
        case .curve(let end, let control1, let control2):
            return .curve(to: winTransformed(end), control1: winTransformed(control1), control2: winTransformed(control2))
        case .close:
            return .close
        }
    }

    // Consumes the pending path, resetting it for the next operation.
    private func winTakePendingSegments() -> [NativePathSegment] {
        let segments = winPendingSegments
        winPendingSegments = []
        return segments
    }
}
