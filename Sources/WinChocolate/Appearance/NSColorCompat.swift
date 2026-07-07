/// Source-compatibility surface for `NSColor`.
///
/// These initializers, component accessors, derived-color helpers, and semantic
/// system colors mirror the AppKit API names so ports compile unchanged. Colors
/// are stored as device-independent RGBA, so color-space conversions are
/// identity operations and grayscale/HSB values are computed on demand.

/// A minimal `NSColorSpace` stand-in.
///
/// WinChocolate stores colors in a single device-independent RGBA space, so the
/// distinct color-space objects exist only to keep `usingColorSpace(_:)` call
/// sites source-compatible; conversions return the same color.
public final class NSColorSpace: Sendable {
    /// The sRGB color space.
    public static let sRGB = NSColorSpace()

    /// The device RGB color space.
    public static let deviceRGB = NSColorSpace()

    /// The generic RGB color space.
    public static let genericRGB = NSColorSpace()

    /// The generic grayscale color space.
    public static let genericGray = NSColorSpace()

    /// Creates a color space.
    public init() {}
}

extension NSColor {
    // MARK: - Additional initializers

    /// Creates an RGB color (calibrated space).
    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.init(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }

    /// Creates a device RGB color.
    public init(deviceRed red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.init(calibratedRed: red, green: green, blue: blue, alpha: alpha)
    }

    /// Creates a grayscale color.
    public init(white: CGFloat, alpha: CGFloat) {
        self.init(calibratedRed: white, green: white, blue: white, alpha: alpha)
    }

    /// Creates a calibrated grayscale color.
    public init(calibratedWhite white: CGFloat, alpha: CGFloat) {
        self.init(white: white, alpha: alpha)
    }

    /// Creates a device grayscale color.
    public init(deviceWhite white: CGFloat, alpha: CGFloat) {
        self.init(white: white, alpha: alpha)
    }

    /// Creates a color from hue, saturation, and brightness.
    public init(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) {
        let rgb = NSColor.hsbToRGB(hue: hue, saturation: saturation, brightness: brightness)
        self.init(calibratedRed: rgb.red, green: rgb.green, blue: rgb.blue, alpha: alpha)
    }

    /// Creates a calibrated HSB color.
    public init(calibratedHue hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) {
        self.init(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
    }

    /// Creates a device HSB color.
    public init(deviceHue hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) {
        self.init(hue: hue, saturation: saturation, brightness: brightness, alpha: alpha)
    }

    // MARK: - Derived colors

    /// Returns a copy with a different alpha component.
    public func withAlphaComponent(_ alpha: CGFloat) -> NSColor {
        NSColor(calibratedRed: redComponent, green: greenComponent, blue: blueComponent, alpha: alpha)
    }

    /// Returns a color blended a fraction of the way toward another color.
    public func blended(withFraction fraction: CGFloat, of color: NSColor) -> NSColor? {
        let f = min(max(fraction, 0), 1)
        return NSColor(
            calibratedRed: redComponent * (1 - f) + color.redComponent * f,
            green: greenComponent * (1 - f) + color.greenComponent * f,
            blue: blueComponent * (1 - f) + color.blueComponent * f,
            alpha: alphaComponent
        )
    }

    /// Returns the color as-is (WinChocolate uses a single RGBA space).
    public func usingColorSpace(_ space: NSColorSpace) -> NSColor? { self }

    /// Returns the color as-is (deprecated color-space-name form).
    public func usingColorSpaceName(_ name: String?) -> NSColor? { self }

    // MARK: - Component accessors

    /// The grayscale (luminance) value of the color.
    public var whiteComponent: CGFloat {
        0.299 * redComponent + 0.587 * greenComponent + 0.114 * blueComponent
    }

    /// The hue component in the range `0...1`.
    public var hueComponent: CGFloat { NSColor.rgbToHSB(self).hue }

    /// The saturation component in the range `0...1`.
    public var saturationComponent: CGFloat { NSColor.rgbToHSB(self).saturation }

    /// The brightness component in the range `0...1`.
    public var brightnessComponent: CGFloat { NSColor.rgbToHSB(self).brightness }

    /// Writes the RGBA components through the given pointers.
    public func getRed(_ red: UnsafeMutablePointer<CGFloat>?, green: UnsafeMutablePointer<CGFloat>?, blue: UnsafeMutablePointer<CGFloat>?, alpha: UnsafeMutablePointer<CGFloat>?) {
        red?.pointee = redComponent
        green?.pointee = greenComponent
        blue?.pointee = blueComponent
        alpha?.pointee = alphaComponent
    }

    /// Writes the HSBA components through the given pointers.
    public func getHue(_ hue: UnsafeMutablePointer<CGFloat>?, saturation: UnsafeMutablePointer<CGFloat>?, brightness: UnsafeMutablePointer<CGFloat>?, alpha: UnsafeMutablePointer<CGFloat>?) {
        let hsb = NSColor.rgbToHSB(self)
        hue?.pointee = hsb.hue
        saturation?.pointee = hsb.saturation
        brightness?.pointee = hsb.brightness
        alpha?.pointee = alphaComponent
    }

    /// Writes the grayscale value and alpha through the given pointers.
    public func getWhite(_ white: UnsafeMutablePointer<CGFloat>?, alpha: UnsafeMutablePointer<CGFloat>?) {
        white?.pointee = whiteComponent
        alpha?.pointee = alphaComponent
    }

    // MARK: - Semantic label colors

    /// Secondary label color.
    public static var secondaryLabelColor: NSColor {
        winDynamic(light: NSColor(white: 0, alpha: 0.5), dark: NSColor(white: 1, alpha: 0.55))
    }
    /// Tertiary label color.
    public static var tertiaryLabelColor: NSColor {
        winDynamic(light: NSColor(white: 0, alpha: 0.26), dark: NSColor(white: 1, alpha: 0.25))
    }
    /// Quaternary label color.
    public static var quaternaryLabelColor: NSColor {
        winDynamic(light: NSColor(white: 0, alpha: 0.1), dark: NSColor(white: 1, alpha: 0.1))
    }
    /// Placeholder text color.
    public static var placeholderTextColor: NSColor {
        winDynamic(light: NSColor(white: 0, alpha: 0.25), dark: NSColor(white: 1, alpha: 0.25))
    }
    /// Separator color.
    public static var separatorColor: NSColor {
        winDynamic(light: NSColor(white: 0, alpha: 0.1), dark: NSColor(white: 1, alpha: 0.12))
    }
    /// Link color.
    public static var linkColor: NSColor { systemBlue }
    /// The control accent color.
    public static var controlAccentColor: NSColor { systemBlue }
    /// Selected text color.
    public static var selectedTextColor: NSColor {
        winDynamic(light: black, dark: white)
    }
    /// Selected text background color.
    public static var selectedTextBackgroundColor: NSColor {
        winDynamic(light: NSColor(red: 0.70, green: 0.85, blue: 1.0, alpha: 1),
                   dark: NSColor(red: 0.15, green: 0.32, blue: 0.55, alpha: 1))
    }
    /// Control background color.
    public static var controlBackgroundColor: NSColor {
        winDynamic(light: white, dark: NSColor(white: 0.17, alpha: 1))
    }
    /// Grid color.
    public static var gridColor: NSColor {
        winDynamic(light: NSColor(white: 0.9, alpha: 1), dark: NSColor(white: 0.28, alpha: 1))
    }
    /// Header color.
    public static var headerColor: NSColor {
        winDynamic(light: white, dark: NSColor(white: 0.17, alpha: 1))
    }

    // MARK: - System palette

    /// System red.
    public static var systemRed: NSColor { NSColor(red: 1.0, green: 0.231, blue: 0.188, alpha: 1) }
    /// System blue.
    public static var systemBlue: NSColor { NSColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1) }
    /// System green.
    public static var systemGreen: NSColor { NSColor(red: 0.196, green: 0.843, blue: 0.294, alpha: 1) }
    /// System orange.
    public static var systemOrange: NSColor { NSColor(red: 1.0, green: 0.584, blue: 0.0, alpha: 1) }
    /// System yellow.
    public static var systemYellow: NSColor { NSColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 1) }
    /// System pink.
    public static var systemPink: NSColor { NSColor(red: 1.0, green: 0.176, blue: 0.333, alpha: 1) }
    /// System purple.
    public static var systemPurple: NSColor { NSColor(red: 0.686, green: 0.322, blue: 0.871, alpha: 1) }
    /// System gray.
    public static var systemGray: NSColor { NSColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1) }
    /// System teal.
    public static var systemTeal: NSColor { NSColor(red: 0.353, green: 0.784, blue: 0.98, alpha: 1) }
    /// System indigo.
    public static var systemIndigo: NSColor { NSColor(red: 0.345, green: 0.337, blue: 0.839, alpha: 1) }

    // MARK: - HSB conversion helpers

    static func hsbToRGB(hue: CGFloat, saturation: CGFloat, brightness: CGFloat) -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
        let s = min(max(saturation, 0), 1)
        let v = min(max(brightness, 0), 1)
        if s == 0 {
            return (v, v, v)
        }
        var h = hue.truncatingRemainder(dividingBy: 1)
        if h < 0 { h += 1 }
        h *= 6
        let sector = Int(h) % 6
        let f = h - CGFloat(Int(h))
        let p = v * (1 - s)
        let q = v * (1 - s * f)
        let t = v * (1 - s * (1 - f))
        switch sector {
        case 0: return (v, t, p)
        case 1: return (q, v, p)
        case 2: return (p, v, t)
        case 3: return (p, q, v)
        case 4: return (t, p, v)
        default: return (v, p, q)
        }
    }

    static func rgbToHSB(_ color: NSColor) -> (hue: CGFloat, saturation: CGFloat, brightness: CGFloat) {
        let r = color.redComponent, g = color.greenComponent, b = color.blueComponent
        let maxV = max(r, g, b)
        let minV = min(r, g, b)
        let delta = maxV - minV
        let brightness = maxV
        let saturation = maxV == 0 ? 0 : delta / maxV
        var hue: CGFloat = 0
        if delta != 0 {
            if maxV == r {
                hue = (g - b) / delta
            } else if maxV == g {
                hue = 2 + (b - r) / delta
            } else {
                hue = 4 + (r - g) / delta
            }
            hue /= 6
            if hue < 0 { hue += 1 }
        }
        return (hue, saturation, brightness)
    }
}
