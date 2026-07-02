/// A color value with AppKit-compatible naming.
///
/// WinChocolate stores colors as normalized device-independent RGBA components.
/// Backends translate those values into native color formats when possible.
public struct NSColor: Equatable, Sendable {
    /// Red component in the range `0...1`.
    public let redComponent: CGFloat

    /// Green component in the range `0...1`.
    public let greenComponent: CGFloat

    /// Blue component in the range `0...1`.
    public let blueComponent: CGFloat

    /// Alpha component in the range `0...1`.
    public let alphaComponent: CGFloat

    /// Creates a calibrated RGB color.
    public init(calibratedRed red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.redComponent = Self.clamp(red)
        self.greenComponent = Self.clamp(green)
        self.blueComponent = Self.clamp(blue)
        self.alphaComponent = Self.clamp(alpha)
    }

    /// Creates an sRGB color.
    public init(srgbRed red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.init(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }

    /// Standard text color.
    public static var textColor: NSColor {
        NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: 1)
    }

    /// Standard window background color.
    public static var windowBackgroundColor: NSColor {
        NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: 1)
    }

    /// Standard label color.
    public static var labelColor: NSColor {
        textColor
    }

    /// Black.
    public static var black: NSColor {
        NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: 1)
    }

    /// White.
    public static var white: NSColor {
        NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: 1)
    }

    /// Red.
    public static var red: NSColor {
        NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 1)
    }

    /// Green.
    public static var green: NSColor {
        NSColor(calibratedRed: 0, green: 0.5, blue: 0, alpha: 1)
    }

    /// Blue.
    public static var blue: NSColor {
        NSColor(calibratedRed: 0, green: 0, blue: 1, alpha: 1)
    }

    /// Gray (50% white).
    public static var gray: NSColor {
        NSColor(calibratedRed: 0.5, green: 0.5, blue: 0.5, alpha: 1)
    }

    /// Dark gray (33% white).
    public static var darkGray: NSColor {
        NSColor(calibratedRed: 1.0 / 3.0, green: 1.0 / 3.0, blue: 1.0 / 3.0, alpha: 1)
    }

    /// Light gray (67% white).
    public static var lightGray: NSColor {
        NSColor(calibratedRed: 2.0 / 3.0, green: 2.0 / 3.0, blue: 2.0 / 3.0, alpha: 1)
    }

    /// Yellow.
    public static var yellow: NSColor {
        NSColor(calibratedRed: 1, green: 1, blue: 0, alpha: 1)
    }

    /// Orange.
    public static var orange: NSColor {
        NSColor(calibratedRed: 1, green: 0.5, blue: 0, alpha: 1)
    }

    /// Purple.
    public static var purple: NSColor {
        NSColor(calibratedRed: 0.5, green: 0, blue: 0.5, alpha: 1)
    }

    /// Brown.
    public static var brown: NSColor {
        NSColor(calibratedRed: 0.6, green: 0.4, blue: 0.2, alpha: 1)
    }

    /// Cyan.
    public static var cyan: NSColor {
        NSColor(calibratedRed: 0, green: 1, blue: 1, alpha: 1)
    }

    /// Magenta.
    public static var magenta: NSColor {
        NSColor(calibratedRed: 1, green: 0, blue: 1, alpha: 1)
    }

    /// Fully transparent black.
    public static var clear: NSColor {
        NSColor(calibratedRed: 0, green: 0, blue: 0, alpha: 0)
    }

    /// Sets this color as both the fill and stroke color of the current context.
    public func set() {
        NSGraphicsContext.current?.fillColor = self
        NSGraphicsContext.current?.strokeColor = self
    }

    /// Sets this color as the fill color of the current context.
    public func setFill() {
        NSGraphicsContext.current?.fillColor = self
    }

    /// Sets this color as the stroke color of the current context.
    public func setStroke() {
        NSGraphicsContext.current?.strokeColor = self
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}
