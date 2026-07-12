/// A font descriptor with AppKit-compatible naming.
///
/// WinChocolate stores the portable font request and lets each backend translate
/// it into native font handles or modern text styling. Weight raw values are the
/// Windows `LOGFONT` weights (100-900), so the backend feeds `weight.rawValue`
/// straight into `CreateFontW`; the italic trait maps to the font's italic flag.
public struct NSFont: Equatable, Sendable {
    /// The requested font family name.
    public let fontName: String

    /// The requested point size.
    public let pointSize: CGFloat

    /// The requested font weight.
    public let weight: Weight

    /// Whether the font is italic (or oblique).
    public let italic: Bool

    /// Font weight values, matching the standard nine-step scale.
    ///
    /// Raw values are the Windows `LOGFONT` weights so they translate directly;
    /// weights of `.semibold` and heavier render bold where only a boolean
    /// bold flag is available.
    public enum Weight: Int, Sendable, CaseIterable {
        /// Ultra-light weight (100).
        case ultraLight = 100

        /// Thin weight (200).
        case thin = 200

        /// Light weight (300).
        case light = 300

        /// Regular weight (400).
        case regular = 400

        /// Medium weight (500).
        case medium = 500

        /// Semibold weight (600).
        case semibold = 600

        /// Bold weight (700).
        case bold = 700

        /// Heavy weight (800).
        case heavy = 800

        /// Black weight (900).
        case black = 900

        /// Whether this weight renders as bold on a boolean bold/regular peer.
        public var isBold: Bool {
            rawValue >= Weight.semibold.rawValue
        }

        /// The named weight nearest a raw Windows `LOGFONT` weight value.
        public static func closest(toLogFontWeight value: Int) -> Weight {
            allCases.min { abs($0.rawValue - value) < abs($1.rawValue - value) } ?? .regular
        }
    }

    /// Creates a font descriptor.
    public init(name fontName: String, size pointSize: CGFloat, weight: Weight = .regular, italic: Bool = false) {
        self.fontName = fontName
        self.pointSize = max(pointSize, 1)
        self.weight = weight
        self.italic = italic
    }

    /// Creates the default system font.
    public static func systemFont(ofSize fontSize: CGFloat) -> NSFont {
        NSFont(name: "Segoe UI", size: fontSize)
    }

    /// Creates the default bold system font.
    public static func boldSystemFont(ofSize fontSize: CGFloat) -> NSFont {
        NSFont(name: "Segoe UI", size: fontSize, weight: .bold)
    }

    /// Creates a system font of a specific weight.
    public static func systemFont(ofSize fontSize: CGFloat, weight: Weight) -> NSFont {
        NSFont(name: "Segoe UI", size: fontSize, weight: weight)
    }

    /// Dynamic-type text styles, matching AppKit's names.
    ///
    /// Windows has no system dynamic-type ramp, so each style maps to the
    /// fixed point size AppKit uses at the default content size on macOS.
    public enum TextStyle: Sendable {
        case largeTitle, title1, title2, title3
        case headline, subheadline
        case body, callout, footnote
        case caption1, caption2
    }

    /// Returns the system font for a text style, matching AppKit's shape.
    public static func preferredFont(forTextStyle style: TextStyle) -> NSFont {
        switch style {
        case .largeTitle: systemFont(ofSize: 26)
        case .title1: systemFont(ofSize: 22)
        case .title2: systemFont(ofSize: 17)
        case .title3: systemFont(ofSize: 15)
        case .headline: boldSystemFont(ofSize: 13)
        case .subheadline: systemFont(ofSize: 11)
        case .body: systemFont(ofSize: 13)
        case .callout: systemFont(ofSize: 12)
        case .footnote: systemFont(ofSize: 10)
        case .caption1: systemFont(ofSize: 10)
        case .caption2: systemFont(ofSize: 10)
        }
    }

    /// Whether the font renders bold on a boolean bold/regular peer.
    public var isBold: Bool {
        weight.isBold
    }

    /// A copy with a different weight.
    public func withWeight(_ newWeight: Weight) -> NSFont {
        NSFont(name: fontName, size: pointSize, weight: newWeight, italic: italic)
    }

    /// A copy with the italic trait set or cleared.
    public func withItalic(_ isItalic: Bool) -> NSFont {
        NSFont(name: fontName, size: pointSize, weight: weight, italic: isItalic)
    }

    /// A copy at a different point size.
    public func withSize(_ newSize: CGFloat) -> NSFont {
        NSFont(name: fontName, size: newSize, weight: weight, italic: italic)
    }

    /// A descriptor capturing this font's family, size, and symbolic traits.
    public var fontDescriptor: NSFontDescriptor {
        var traits: NSFontDescriptor.SymbolicTraits = []
        if weight.isBold {
            traits.insert(.bold)
        }
        if italic {
            traits.insert(.italic)
        }
        return NSFontDescriptor(name: fontName, size: pointSize, symbolicTraits: traits)
    }

    /// Creates a font from a descriptor, using a size override when nonzero.
    public init(descriptor: NSFontDescriptor, size: CGFloat) {
        let resolvedSize = size > 0 ? size : descriptor.pointSize
        self.init(
            name: descriptor.fontName,
            size: resolvedSize > 0 ? resolvedSize : 13,
            weight: descriptor.symbolicTraits.contains(.bold) ? .bold : .regular,
            italic: descriptor.symbolicTraits.contains(.italic)
        )
    }
}

/// A description of a font's attributes used to create or vary a font.
///
/// This slice keeps AppKit's `NSFontDescriptor` shape for the common trait
/// operations — a family, size, and symbolic bold/italic traits — that
/// programmatic ports reach for; the full attribute-dictionary matching model
/// is future work.
public struct NSFontDescriptor: Equatable, Sendable {
    /// Symbolic font traits.
    public struct SymbolicTraits: OptionSet, Sendable {
        /// Raw option value.
        public let rawValue: UInt32

        /// Creates traits from a raw value.
        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        /// A bold face.
        public static let bold = SymbolicTraits(rawValue: 1 << 1)

        /// An italic face.
        public static let italic = SymbolicTraits(rawValue: 1 << 0)
    }

    /// The descriptor's font family name.
    public let fontName: String

    /// The descriptor's point size, or zero when unspecified.
    public let pointSize: CGFloat

    /// The descriptor's symbolic traits.
    public let symbolicTraits: SymbolicTraits

    /// Creates a font descriptor.
    public init(name fontName: String, size pointSize: CGFloat, symbolicTraits: SymbolicTraits = []) {
        self.fontName = fontName
        self.pointSize = pointSize
        self.symbolicTraits = symbolicTraits
    }

    /// A copy with the given symbolic traits added.
    public func withSymbolicTraits(_ traits: SymbolicTraits) -> NSFontDescriptor {
        NSFontDescriptor(name: fontName, size: pointSize, symbolicTraits: symbolicTraits.union(traits))
    }
}
