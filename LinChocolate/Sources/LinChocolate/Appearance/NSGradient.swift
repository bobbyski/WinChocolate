import Foundation

/// AppKit-shaped gradient. Draw inside `NSView.draw(_:)` to fill a rectangle at
/// an angle, fill a `NSBezierPath` (clip + fill), or fill radially. Backed by
/// Cairo gradient patterns on GTK.
public final class NSGradient {

    let stops: [NativeGradientStop]

    /// The number of color stops.
    public var numberOfColorStops: Int { stops.count }

    /// Creates a two-color gradient from start to end.
    public convenience init?(starting startingColor: NSColor, ending endingColor: NSColor) {
        self.init(colors: [startingColor, endingColor])
    }

    /// Creates a gradient with evenly spaced colors.
    public init?(colors: [NSColor]) {
        guard colors.count >= 2 else { return nil }
        let step = 1.0 / CGFloat(colors.count - 1)
        stops = colors.enumerated().map { NativeGradientStop(color: $1, location: CGFloat($0) * step) }
    }

    /// Creates a gradient from color/location pairs (locations clamped to 0...1).
    public init?(colorsAndLocations: (NSColor, CGFloat)...) {
        guard colorsAndLocations.count >= 2 else { return nil }
        stops = colorsAndLocations.map { NativeGradientStop(color: $0.0, location: min(max($0.1, 0), 1)) }
    }

    /// Draws the gradient filling `rect` at `angle` degrees (0 = left→right,
    /// 90 = bottom→top).
    public func draw(in rect: NSRect, angle: CGFloat) {
        guard let context = NSGraphicsContext.current?.native,
              rect.width > 0, rect.height > 0 else { return }
        context.fillLinearGradient(stops, inRect: rect, angleDegrees: Double(angle))
    }

    /// Draws the gradient clipped to `path`, at `angle` degrees.
    public func draw(in path: NSBezierPath, angle: CGFloat) {
        guard let context = NSGraphicsContext.current?.native, !path.isEmpty else { return }
        let rect = path.bounds
        guard rect.width > 0, rect.height > 0 else { return }
        context.saveState()
        path.replay(into: context)
        context.clipToCurrentPath()
        context.fillLinearGradient(stops, inRect: rect, angleDegrees: Double(angle))
        context.restoreState()
    }

    /// Draws the gradient radially, filling `rect` (center = rect center).
    public func draw(inRadial rect: NSRect) {
        guard let context = NSGraphicsContext.current?.native,
              rect.width > 0, rect.height > 0 else { return }
        context.fillRadialGradient(stops, inRect: rect)
    }
}
