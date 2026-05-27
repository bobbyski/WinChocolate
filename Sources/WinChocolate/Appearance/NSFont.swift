/// A font descriptor with AppKit-compatible naming.
///
/// WinChocolate stores the portable font request and lets each backend translate
/// it into native font handles or modern text styling.
public struct NSFont: Equatable, Sendable {
    /// The requested font family name.
    public let fontName: String

    /// The requested point size.
    public let pointSize: CGFloat

    /// The requested font weight.
    public let weight: Weight

    /// Font weight values.
    public enum Weight: Int, Sendable {
        /// Regular weight.
        case regular = 400

        /// Bold weight.
        case bold = 700
    }

    /// Creates a font descriptor.
    public init(name fontName: String, size pointSize: CGFloat, weight: Weight = .regular) {
        self.fontName = fontName
        self.pointSize = max(pointSize, 1)
        self.weight = weight
    }

    /// Creates the default system font.
    public static func systemFont(ofSize fontSize: CGFloat) -> NSFont {
        NSFont(name: "Segoe UI", size: fontSize)
    }

    /// Creates the default bold system font.
    public static func boldSystemFont(ofSize fontSize: CGFloat) -> NSFont {
        NSFont(name: "Segoe UI", size: fontSize, weight: .bold)
    }
}
