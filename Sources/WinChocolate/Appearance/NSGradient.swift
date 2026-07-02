/// A linear gradient of color stops.
///
/// This slice covers the drawing forms custom views use inside `draw(_:)`:
/// rectangle fills at an angle and path fills (clip plus fill). Radial
/// drawing and `draw(from:to:options:)` are future work.
open class NSGradient: NSObject {
    /// The gradient stops in ascending location order.
    internal let stops: [NativeGradientStop]

    /// Creates a two-color gradient from start to end.
    public convenience init?(starting startingColor: NSColor, ending endingColor: NSColor) {
        self.init(colors: [startingColor, endingColor])
    }

    /// Creates a gradient with evenly spaced colors.
    public init?(colors: [NSColor]) {
        guard colors.count >= 2 else {
            return nil
        }

        let step = 1.0 / CGFloat(colors.count - 1)
        stops = colors.enumerated().map { index, color in
            NativeGradientStop(color: color, location: CGFloat(index) * step)
        }
        super.init()
    }

    /// Creates a gradient from color-location pairs in ascending order.
    public init?(colorsAndLocations: (NSColor, CGFloat)...) {
        guard colorsAndLocations.count >= 2 else {
            return nil
        }

        stops = colorsAndLocations.map { color, location in
            NativeGradientStop(color: color, location: min(max(location, 0), 1))
        }
        super.init()
    }

    /// The number of color stops.
    open var numberOfColorStops: Int {
        stops.count
    }

    /// Draws the gradient in a rectangle along an angle in degrees.
    ///
    /// Angle 0 runs left to right and positive angles rotate toward the top
    /// of the view, matching AppKit: 90 draws bottom-to-top.
    open func draw(in rect: NSRect, angle: CGFloat) {
        guard let context = NSGraphicsContext.current, rect.size.width > 0, rect.size.height > 0 else {
            return
        }

        context.nativeContext.drawLinearGradient(stops, in: rect, angle: angle)
    }

    /// Draws the gradient clipped to a path along an angle in degrees.
    open func draw(in path: NSBezierPath, angle: CGFloat) {
        guard let context = NSGraphicsContext.current, !path.isEmpty else {
            return
        }

        let rect = path.bounds
        guard rect.size.width > 0, rect.size.height > 0 else {
            return
        }
        context.nativeContext.saveState()
        context.nativeContext.clip(to: path.nativeSegments)
        context.nativeContext.drawLinearGradient(stops, in: rect, angle: angle)
        context.nativeContext.restoreState()
    }
}
