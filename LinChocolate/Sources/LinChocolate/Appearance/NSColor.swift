import Foundation

/// AppKit-shaped RGBA color. A minimal, platform-neutral slice — enough for
/// `NSColorWell` and future view background/text-color support; grows toward
/// AppKit's `NSColor` as controls need it (mirrors WinChocolate's early slice).
public struct NSColor: Equatable, Sendable {

    public var redComponent: CGFloat
    public var greenComponent: CGFloat
    public var blueComponent: CGFloat
    public var alphaComponent: CGFloat

    /// Creates a color from RGBA components in `0...1`.
    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat = 1) {
        self.redComponent = red
        self.greenComponent = green
        self.blueComponent = blue
        self.alphaComponent = alpha
    }

    // AppKit's calibrated initializer, same components on this backend.
    public init(calibratedRed red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    // MARK: Drawing
    /// Uses this color for subsequent fills in the current draw pass.
    public func setFill() { NSGraphicsContext.current?.native.setFillColor(self) }
    /// Uses this color for subsequent strokes in the current draw pass.
    public func setStroke() { NSGraphicsContext.current?.native.setStrokeColor(self) }
    /// Uses this color for both fills and strokes.
    public func set() { setFill(); setStroke() }

    // MARK: Common colors
    public static let black   = NSColor(red: 0, green: 0, blue: 0)
    public static let white   = NSColor(red: 1, green: 1, blue: 1)
    public static let red     = NSColor(red: 1, green: 0, blue: 0)
    public static let green   = NSColor(red: 0, green: 1, blue: 0)
    public static let blue    = NSColor(red: 0, green: 0, blue: 1)
    public static let yellow  = NSColor(red: 1, green: 1, blue: 0)
    public static let orange  = NSColor(red: 1, green: 0.5, blue: 0)
    public static let purple  = NSColor(red: 0.5, green: 0, blue: 0.5)
    public static let gray    = NSColor(red: 0.5, green: 0.5, blue: 0.5)
    public static let clear   = NSColor(red: 0, green: 0, blue: 0, alpha: 0)
}
