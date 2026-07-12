import Foundation

/// AppKit-shaped font reference. Carries a family/size/weight description that
/// the backend renders natively (via CSS on GTK). This slice always resolves —
/// unknown families fall back through the platform's font matching.
public final class NSFont {

    /// The font family name ("Sans", "Serif", "Monospace", or an installed family).
    public let fontName: String

    /// The size in points.
    public let pointSize: CGFloat

    let spec: NativeFontSpec

    /// Creates a font by family name. (AppKit returns nil for unknown names;
    /// here unknown families fall back via platform font matching.)
    public init?(name: String, size: CGFloat) {
        self.fontName = name
        self.pointSize = size
        self.spec = NativeFontSpec(family: name, size: Double(size))
    }

    /// Creates a font with an explicit weight and italic flag (weights at or
    /// above `.semibold` render bold on the GTK backend).
    public init?(name: String, size: CGFloat, weight: NSFont.Weight, italic: Bool = false) {
        self.fontName = name
        self.pointSize = size
        self.spec = NativeFontSpec(family: name, size: Double(size),
                                   bold: weight.rawValue >= NSFont.Weight.semibold.rawValue,
                                   italic: italic)
    }

    private init(spec: NativeFontSpec, name: String) {
        self.fontName = name
        self.pointSize = CGFloat(spec.size)
        self.spec = spec
    }

    /// The platform's default UI font at `size`.
    public static func systemFont(ofSize size: CGFloat) -> NSFont {
        NSFont(spec: NativeFontSpec(family: nil, size: Double(size)), name: "system")
    }

    /// Bold variant of the platform's default UI font.
    public static func boldSystemFont(ofSize size: CGFloat) -> NSFont {
        NSFont(spec: NativeFontSpec(family: nil, size: Double(size), bold: true), name: "system-bold")
    }

    /// The platform's default fixed-pitch font.
    public static func monospacedSystemFont(ofSize size: CGFloat) -> NSFont {
        NSFont(spec: NativeFontSpec(family: "Monospace", size: Double(size)), name: "Monospace")
    }
}
