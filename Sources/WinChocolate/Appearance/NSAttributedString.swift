/// A string with associated drawing attributes.
///
/// This is a first slice of AppKit's `NSAttributedString`: it stores one
/// attribute dictionary that applies to the whole string. Per-range attribute
/// runs, mutation, and archiving are future work.
open class NSAttributedString: NSObject {
    /// Attribute names applied to an attributed string.
    public struct Key: RawRepresentable, Hashable, Sendable {
        /// The attribute's raw string name.
        public let rawValue: String

        /// Creates an attribute key from a raw string name.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// The font of the text (`NSFont`).
        public static let font = Key(rawValue: "NSFont")

        /// The color of the text (`NSColor`).
        public static let foregroundColor = Key(rawValue: "NSColor")
    }

    /// The character contents.
    public let string: String

    /// The attributes applied to the whole string.
    public let attributes: [Key: Any]

    /// Creates an attributed string with no attributes.
    public init(string: String) {
        self.string = string
        self.attributes = [:]
        super.init()
    }

    /// Creates an attributed string with attributes covering the whole string.
    public init(string: String, attributes: [Key: Any]?) {
        self.string = string
        self.attributes = attributes ?? [:]
        super.init()
    }
}

extension String {
    /// Draws the string with its top-left corner at a point in the current
    /// graphics context.
    ///
    /// Resolves `.font` (`NSFont`) and `.foregroundColor` (`NSColor`) from the
    /// attributes; unspecified attributes fall back to 12-point Segoe UI in
    /// black, matching the backend's default control font.
    public func draw(at point: NSPoint, withAttributes attributes: [NSAttributedString.Key: Any]? = nil) {
        guard let context = NSGraphicsContext.current else {
            return
        }

        let font = attributes?[.font] as? NSFont
        let color = attributes?[.foregroundColor] as? NSColor ?? .black
        context.nativeContext.drawText(
            self,
            at: point,
            color: color,
            fontName: font?.fontName ?? "Segoe UI",
            fontSize: font?.pointSize ?? 12,
            bold: (font?.weight.rawValue ?? NSFont.Weight.regular.rawValue) >= 600
        )
    }

    /// Returns the bounding size of the string with attributes.
    ///
    /// Measured with the backend's real text metrics (the in-memory test
    /// backend returns a deterministic estimate).
    public func size(withAttributes attributes: [NSAttributedString.Key: Any]? = nil) -> NSSize {
        let font = attributes?[.font] as? NSFont
        return NSApplication.shared.nativeBackend.measureText(
            self,
            fontName: font?.fontName ?? "Segoe UI",
            fontSize: font?.pointSize ?? 12,
            bold: (font?.weight.rawValue ?? NSFont.Weight.regular.rawValue) >= 600
        )
    }
}
