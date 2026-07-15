import Foundation

/// AppKit-shaped vector path. Build with move/line/curve/close (AppKit
/// bottom-left coordinates), then `fill()` or `stroke()` inside
/// `NSView.draw(_:)`. Rect and oval convenience initializers included.
public final class NSBezierPath {

    private enum Element {
        case move(NSPoint)
        case line(NSPoint)
        case curve(to: NSPoint, c1: NSPoint, c2: NSPoint)
        case arc(center: NSPoint, radius: CGFloat, start: CGFloat, end: CGFloat, clockwise: Bool)
        case close
    }

    private var elements: [Element] = []

    /// Whether the path has no elements.
    public var isEmpty: Bool { elements.isEmpty }

    /// Stroke width used by `stroke()`.
    public var lineWidth: CGFloat = 1

    /// Creates an empty path.
    public init() {}

    /// Creates a rectangular path.
    public convenience init(rect: NSRect) {
        self.init()
        move(to: NSMakePoint(rect.minX, rect.minY))
        line(to: NSMakePoint(rect.maxX, rect.minY))
        line(to: NSMakePoint(rect.maxX, rect.maxY))
        line(to: NSMakePoint(rect.minX, rect.maxY))
        close()
    }

    /// Creates an elliptical path inscribed in `rect` (four Bézier arcs).
    public convenience init(ovalIn rect: NSRect) {
        self.init()
        let kappa: CGFloat = 0.5522847498
        let (cx, cy) = (rect.midX, rect.midY)
        let (rx, ry) = (rect.width / 2, rect.height / 2)
        let (ox, oy) = (rx * kappa, ry * kappa)
        move(to: NSMakePoint(rect.maxX, cy))
        curve(to: NSMakePoint(cx, rect.maxY),
              controlPoint1: NSMakePoint(rect.maxX, cy + oy), controlPoint2: NSMakePoint(cx + ox, rect.maxY))
        curve(to: NSMakePoint(rect.minX, cy),
              controlPoint1: NSMakePoint(cx - ox, rect.maxY), controlPoint2: NSMakePoint(rect.minX, cy + oy))
        curve(to: NSMakePoint(cx, rect.minY),
              controlPoint1: NSMakePoint(rect.minX, cy - oy), controlPoint2: NSMakePoint(cx - ox, rect.minY))
        curve(to: NSMakePoint(rect.maxX, cy),
              controlPoint1: NSMakePoint(cx + ox, rect.minY), controlPoint2: NSMakePoint(rect.maxX, cy - oy))
        close()
    }

    /// Creates a rounded-rectangle path.
    public convenience init(roundedRect rect: NSRect, xRadius: CGFloat, yRadius: CGFloat) {
        self.init()
        appendRoundedRect(rect, xRadius: xRadius, yRadius: yRadius)
    }

    public func move(to point: NSPoint) { elements.append(.move(point)) }
    public func line(to point: NSPoint) { elements.append(.line(point)) }
    public func curve(to point: NSPoint, controlPoint1: NSPoint, controlPoint2: NSPoint) {
        elements.append(.curve(to: point, c1: controlPoint1, c2: controlPoint2))
    }
    /// Appends an arc. Angles are in **degrees** (AppKit convention).
    public func appendArc(withCenter center: NSPoint, radius: CGFloat,
                          startAngle: CGFloat, endAngle: CGFloat, clockwise: Bool = false) {
        elements.append(.arc(center: center, radius: radius, start: startAngle, end: endAngle, clockwise: clockwise))
    }
    /// Appends a rounded rectangle (corners as cubic Bézier quarter-arcs).
    public func appendRoundedRect(_ rect: NSRect, xRadius: CGFloat, yRadius: CGFloat) {
        let rx = min(xRadius, rect.width / 2), ry = min(yRadius, rect.height / 2)
        let k: CGFloat = 0.5522847498   // circle-to-Bézier constant
        let (x0, y0, x1, y1) = (rect.minX, rect.minY, rect.maxX, rect.maxY)
        move(to: NSMakePoint(x0 + rx, y0))
        line(to: NSMakePoint(x1 - rx, y0))
        curve(to: NSMakePoint(x1, y0 + ry), controlPoint1: NSMakePoint(x1 - rx + rx * k, y0), controlPoint2: NSMakePoint(x1, y0 + ry - ry * k))
        line(to: NSMakePoint(x1, y1 - ry))
        curve(to: NSMakePoint(x1 - rx, y1), controlPoint1: NSMakePoint(x1, y1 - ry + ry * k), controlPoint2: NSMakePoint(x1 - rx + rx * k, y1))
        line(to: NSMakePoint(x0 + rx, y1))
        curve(to: NSMakePoint(x0, y1 - ry), controlPoint1: NSMakePoint(x0 + rx - rx * k, y1), controlPoint2: NSMakePoint(x0, y1 - ry + ry * k))
        line(to: NSMakePoint(x0, y0 + ry))
        curve(to: NSMakePoint(x0 + rx, y0), controlPoint1: NSMakePoint(x0, y0 + ry - ry * k), controlPoint2: NSMakePoint(x0 + rx - rx * k, y0))
        close()
    }
    public func close() { elements.append(.close) }

    /// The bounding box of the path's points (approximate for arcs: their
    /// enclosing square).
    public var bounds: NSRect {
        var minX = CGFloat.greatestFiniteMagnitude, minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude, maxY = -CGFloat.greatestFiniteMagnitude
        func include(_ p: NSPoint) {
            minX = min(minX, p.x); minY = min(minY, p.y)
            maxX = max(maxX, p.x); maxY = max(maxY, p.y)
        }
        for element in elements {
            switch element {
            case .move(let p), .line(let p): include(p)
            case .curve(let to, let c1, let c2): include(to); include(c1); include(c2)
            case .arc(let c, let r, _, _, _):
                include(NSMakePoint(c.x - r, c.y - r)); include(NSMakePoint(c.x + r, c.y + r))
            case .close: break
            }
        }
        guard minX <= maxX else { return .zero }
        return NSMakeRect(minX, minY, maxX - minX, maxY - minY)
    }

    /// Fills the path with the current fill color.
    public func fill() {
        guard let context = NSGraphicsContext.current?.native else { return }
        replay(into: context)
        context.fillPath()
    }

    /// Strokes the path with the current stroke color and `lineWidth`.
    public func stroke() {
        guard let context = NSGraphicsContext.current?.native else { return }
        replay(into: context)
        context.setLineWidth(Double(lineWidth))
        context.strokePath()
    }

    /// Replays the path's elements into a native context (used by `fill`/
    /// `stroke` and by `NSGradient` path fills).
    func replay(into context: NativeGraphicsContext) {
        context.beginPath()
        for element in elements {
            switch element {
            case .move(let p): context.move(toX: Double(p.x), y: Double(p.y))
            case .line(let p): context.line(toX: Double(p.x), y: Double(p.y))
            case .curve(let to, let c1, let c2):
                context.curve(toX: Double(to.x), y: Double(to.y),
                              c1x: Double(c1.x), c1y: Double(c1.y),
                              c2x: Double(c2.x), c2y: Double(c2.y))
            case .arc(let c, let r, let start, let end, let clockwise):
                context.addArc(centerX: Double(c.x), centerY: Double(c.y), radius: Double(r),
                               startAngleRadians: Double(start) * .pi / 180,
                               endAngleRadians: Double(end) * .pi / 180, clockwise: clockwise)
            case .close: context.closePath()
            }
        }
    }
}


// AppKit's drawing methods on NSRect (`rect.fill()` / `rect.frame()`), which
// the shared demo's draw(_:) code uses directly.
public extension NSRect {
    /// Fills the rect with the current fill color.
    func fill() {
        NSBezierPath(rect: self).fill()
    }

    /// Strokes a 1pt frame just inside the rect with the current fill color
    /// (AppKit's `NSFrameRect` semantics).
    func frame() {
        let path = NSBezierPath(rect: insetBy(dx: 0.5, dy: 0.5))
        path.lineWidth = 1
        path.stroke()
    }
}
