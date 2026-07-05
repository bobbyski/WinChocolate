/// Source-compatibility surface for `NSFont`.
///
/// The named system-font factories, standard sizes, and family accessors mirror
/// AppKit's API names. WinChocolate resolves them to Windows system faces
/// (Segoe UI for UI text, Consolas for fixed-pitch) so ports compile and render
/// with a native look.
extension NSFont {
    /// The standard system font size.
    public static var systemFontSize: CGFloat { 13 }

    /// The small system font size.
    public static var smallSystemFontSize: CGFloat { 11 }

    /// The standard label font size.
    public static var labelFontSize: CGFloat { 13 }

    /// The requested font's family name (its face name in WinChocolate).
    public var familyName: String? { fontName }

    /// A human-readable name for the font.
    public var displayName: String? { fontName }

    /// The application's default content font.
    public static func userFont(ofSize fontSize: CGFloat) -> NSFont {
        NSFont(name: "Segoe UI", size: fontSize)
    }

    /// The application's default fixed-pitch font.
    public static func userFixedPitchFont(ofSize fontSize: CGFloat) -> NSFont {
        NSFont(name: "Consolas", size: fontSize)
    }

    /// The font used for standard interface labels.
    public static func labelFont(ofSize fontSize: CGFloat) -> NSFont {
        NSFont(name: "Segoe UI", size: fontSize)
    }

    /// The font used in window title bars.
    public static func titleBarFont(ofSize fontSize: CGFloat) -> NSFont {
        NSFont(name: "Segoe UI", size: fontSize, weight: .semibold)
    }

    /// The font used for menu items.
    public static func menuFont(ofSize fontSize: CGFloat) -> NSFont {
        NSFont(name: "Segoe UI", size: fontSize)
    }

    /// The font used for standard interface items such as button labels.
    public static func messageFont(ofSize fontSize: CGFloat) -> NSFont {
        NSFont(name: "Segoe UI", size: fontSize)
    }

    /// The font used for tool tips.
    public static func toolTipsFont(ofSize fontSize: CGFloat) -> NSFont {
        NSFont(name: "Segoe UI", size: fontSize)
    }

    /// The font used for the content of controls.
    public static func controlContentFont(ofSize fontSize: CGFloat) -> NSFont {
        NSFont(name: "Segoe UI", size: fontSize)
    }

    /// A monospaced system font of the given size and weight.
    public static func monospacedSystemFont(ofSize fontSize: CGFloat, weight: Weight) -> NSFont {
        NSFont(name: "Consolas", size: fontSize, weight: weight)
    }

    /// A system font whose digits are monospaced.
    public static func monospacedDigitSystemFont(ofSize fontSize: CGFloat, weight: Weight) -> NSFont {
        NSFont(name: "Segoe UI", size: fontSize, weight: weight)
    }
}
