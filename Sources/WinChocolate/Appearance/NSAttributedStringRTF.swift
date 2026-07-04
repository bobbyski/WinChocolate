import WinFoundation

extension NSAttributedString {
    /// Document attribute keys used by RTF conversion, kept for AppKit API
    /// compatibility; this slice does not consume them.
    public struct DocumentAttributeKey: RawRepresentable, Hashable, Sendable {
        /// The key's raw string name.
        public let rawValue: String

        /// Creates a document attribute key from a raw string name.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }

    /// Returns RTF data for a character range.
    ///
    /// The writer emits a standard font and color table and renders each
    /// attribute run as a group carrying face, size, bold, underline,
    /// strikethrough, and color. Non-ASCII characters use RTF unicode
    /// escapes, so the output round-trips through WordPad, Office, and the
    /// rich-edit control. RTF reading remains future work (plan item 3.16).
    public func rtf(from range: NSRange, documentAttributes: [DocumentAttributeKey: Any] = [:]) -> Data? {
        let bounded = clamped(range)
        let content = attributedSubstring(from: bounded)

        // Collect the font and color tables from the runs.
        var fontNames: [String] = ["Segoe UI"]
        var colors: [NSColor] = []
        content.enumerateAttributes(in: NSRange(location: 0, length: content.length)) { attributes, _, _ in
            if let font = attributes[.font] as? NSFont, !fontNames.contains(font.fontName) {
                fontNames.append(font.fontName)
            }
            if let color = attributes[.foregroundColor] as? NSColor, !colors.contains(color) {
                colors.append(color)
            }
        }

        var rtf = "{\\rtf1\\ansi\\deff0"
        rtf += "{\\fonttbl"
        for (index, name) in fontNames.enumerated() {
            rtf += "{\\f\(index)\\fnil \(Self.rtfEscaped(name));}"
        }
        rtf += "}"
        if !colors.isEmpty {
            // The leading semicolon keeps index 0 as the automatic color.
            rtf += "{\\colortbl ;"
            for color in colors {
                let red = Int((color.redComponent * 255).rounded())
                let green = Int((color.greenComponent * 255).rounded())
                let blue = Int((color.blueComponent * 255).rounded())
                rtf += "\\red\(red)\\green\(green)\\blue\(blue);"
            }
            rtf += "}"
        }

        content.enumerateAttributes(in: NSRange(location: 0, length: content.length)) { attributes, runRange, _ in
            var controls = ""
            if let font = attributes[.font] as? NSFont {
                let fontIndex = fontNames.firstIndex(of: font.fontName) ?? 0
                controls += "\\f\(fontIndex)\\fs\(Int((font.pointSize * 2).rounded()))"
                if font.weight.isBold {
                    controls += "\\b"
                }
                if font.italic {
                    controls += "\\i"
                }
            }
            if let color = attributes[.foregroundColor] as? NSColor, let colorIndex = colors.firstIndex(of: color) {
                controls += "\\cf\(colorIndex + 1)"
            }
            if let underline = attributes[.underlineStyle] as? Int, underline != 0 {
                controls += "\\ul"
            }
            if let strikethrough = attributes[.strikethroughStyle] as? Int, strikethrough != 0 {
                controls += "\\strike"
            }

            let text = Self.rtfEscaped(String(decoding: content.units[runRange.location..<(runRange.location + runRange.length)], as: UTF16.self))
            // Group scoping keeps run formatting from leaking into the next run.
            rtf += controls.isEmpty ? "{\(text)}" : "{\(controls) \(text)}"
        }

        rtf += "}"
        return Data(Array(rtf.utf8))
    }

    /// Escapes RTF control characters and non-ASCII text.
    private static func rtfEscaped(_ text: String) -> String {
        var escaped = ""
        for unit in text.utf16 {
            switch unit {
            case 0x5c:
                escaped += "\\\\"
            case 0x7b:
                escaped += "\\{"
            case 0x7d:
                escaped += "\\}"
            case 0x0a:
                escaped += "\\par "
            case 0x0d:
                break
            case let ascii where ascii < 0x80:
                escaped.append(Character(UnicodeScalar(ascii)!))
            default:
                // RTF unicode escapes are signed 16-bit with a fallback char.
                escaped += "\\u\(Int16(bitPattern: unit))?"
            }
        }
        return escaped
    }
}
