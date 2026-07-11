import Foundation

/// AppKit-shaped vector path. Build with move/line/curve/close (AppKit
/// bottom-left coordinates), then `fill()` or `stroke()` inside
/// `NSView.draw(_:)`. Rect and oval convenience initializers included.
public final class NSBezierPath {

    private enum Element {
        case move(NSPoint)
        case line(NSPoint)
        case curve(to: NSPoint, c1: NSPoint, c2: NSPoint)
        case close
    }

    private var elements: [Element] = []

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

    public func move(to point: NSPoint) { elements.append(.move(point)) }
    public func line(to point: NSPoint) { elements.append(.line(point)) }
    public func curve(to point: NSPoint, controlPoint1: NSPoint, controlPoint2: NSPoint) {
        elements.append(.curve(to: point, c1: controlPoint1, c2: controlPoint2))
    }
    public func close() { elements.append(.close) }

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

    private func replay(into context: NativeGraphicsContext) {
        context.beginPath()
        for element in elements {
            switch element {
            case .move(let p): context.move(toX: Double(p.x), y: Double(p.y))
            case .line(let p): context.line(toX: Double(p.x), y: Double(p.y))
            case .curve(let to, let c1, let c2):
                context.curve(toX: Double(to.x), y: Double(to.y),
                              c1x: Double(c1.x), c1y: Double(c1.y),
                              c2x: Double(c2.x), c2y: Double(c2.y))
            case .close: context.closePath()
            }
        }
    }
}
