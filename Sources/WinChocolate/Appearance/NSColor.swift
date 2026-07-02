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
