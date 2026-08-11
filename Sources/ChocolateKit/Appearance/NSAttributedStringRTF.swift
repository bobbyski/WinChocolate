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

        /// The document's type (see `DocumentType`).
        public static let documentType = DocumentAttributeKey(rawValue: "DocumentType")
    }

    /// Document types for encoded-data conversion, matching AppKit's names.
    public struct DocumentType: RawRepresentable, Hashable, Sendable {
        /// The type's raw string name.
        public let rawValue: String

        /// Creates a document type from a raw string name.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// Rich Text Format.
        public static let rtf = DocumentType(rawValue: "NSRTF")

        /// Plain text.
        public static let plainText = DocumentType(rawValue: "NSPlainText")
    }

    /// Document reading option keys, matching AppKit's names.
    public struct DocumentReadingOptionKey: RawRepresentable, Hashable, Sendable {
        /// The key's raw string name.
        public let rawValue: String

        /// Creates a reading option key from a raw string name.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// The expected document type (see `DocumentType`).
        public static let documentType = DocumentReadingOptionKey(rawValue: "DocumentType")
    }

    /// Returns encoded document data for a range, matching AppKit's shape.
    /// RTF is the encoding this slice supports; other document types throw.
    public func data(from range: NSRange, documentAttributes: [DocumentAttributeKey: Any]) throws -> Data {
        let type = documentAttributes[.documentType] as? DocumentType
        guard type == nil || type == .rtf, let data = rtf(from: range) else {
            throw NSError(domain: "WinChocolate.NSAttributedString", code: 1)
        }
        return data
    }

    /// Creates an attributed string from encoded document data, matching
    /// AppKit's shape. RTF is the encoding this slice supports.
    public convenience init(
        data: Data,
        options: [DocumentReadingOptionKey: Any] = [:],
        documentAttributes: UnsafeMutablePointer<[DocumentAttributeKey: Any]>? = nil
    ) throws {
        let type = options[.documentType] as? DocumentType
        guard type == nil || type == .rtf else {
            throw NSError(domain: "WinChocolate.NSAttributedString", code: 1)
        }
        guard let parsed = NSAttributedString(rtf: data, documentAttributes: documentAttributes) else {
            throw NSError(domain: "WinChocolate.NSAttributedString", code: 2)
        }
        self.init(attributedString: parsed)
    }

    /// Returns RTF data for a character range.
    ///
    /// The writer emits a standard font and color table and renders each
    /// attribute run as a group carrying face, size, bold, underline,
    /// strikethrough, color, and paragraph alignment. Non-ASCII characters use
    /// RTF unicode escapes, so the output round-trips through WordPad, Office,
    /// and the rich-edit control — and back through `init(rtf:)` below.
    public func rtf(from range: NSRange, documentAttributes: [DocumentAttributeKey: Any] = [:]) -> Data? {
        let bounded = clamped(range)
        let content = attributedSubstring(from: bounded)

        let (fontNames, colors) = Self.rtfTables(for: content)
        var rtf = Self.rtfHeader(fontNames: fontNames, colors: colors)

        content.enumerateAttributes(in: NSRange(location: 0, length: content.length)) { attributes, runRange, _ in
            let controls = Self.rtfControls(for: attributes, fontNames: fontNames, colors: colors)

            let text = Self.rtfEscaped(String(decoding: content.units[runRange.location..<(runRange.location + runRange.length)], as: UTF16.self))
            // Group scoping keeps run formatting from leaking into the next run.
            rtf += controls.isEmpty ? "{\(text)}" : "{\(controls) \(text)}"
        }

        rtf += "}"
        return Data(Array(rtf.utf8))
    }

    private static func rtfTables(for content: NSAttributedString) -> ([String], [NSColor]) {
        var fontNames = ["Segoe UI"]
        var colors: [NSColor] = []
        content.enumerateAttributes(in: NSRange(location: 0, length: content.length)) { attributes, _, _ in
            if let font = attributes[.font] as? NSFont, !fontNames.contains(font.fontName) {
                fontNames.append(font.fontName)
            }
            if let color = attributes[.foregroundColor] as? NSColor, !colors.contains(color) {
                colors.append(color)
            }
        }
        return (fontNames, colors)
    }

    private static func rtfHeader(fontNames: [String], colors: [NSColor]) -> String {
        var header = "{\\rtf1\\ansi\\deff0{\\fonttbl"
        for (index, name) in fontNames.enumerated() {
            header += "{\\f\(index)\\fnil \(rtfEscaped(name));}"
        }
        header += "}"
        guard !colors.isEmpty else { return header }
        header += "{\\colortbl ;"
        for color in colors {
            header += "\\red\(Int((color.redComponent * 255).rounded()))"
            header += "\\green\(Int((color.greenComponent * 255).rounded()))"
            header += "\\blue\(Int((color.blueComponent * 255).rounded()));"
        }
        return header + "}"
    }

    private static func rtfControls(
        for attributes: [NSAttributedString.Key: Any], fontNames: [String], colors: [NSColor]
    ) -> String {
        var controls = ""
        if let font = attributes[.font] as? NSFont {
            controls += "\\f\(fontNames.firstIndex(of: font.fontName) ?? 0)\\fs\(Int((font.pointSize * 2).rounded()))"
            if font.weight.isBold { controls += "\\b" }
            if font.italic { controls += "\\i" }
        }
        if let color = attributes[.foregroundColor] as? NSColor, let index = colors.firstIndex(of: color) {
            controls += "\\cf\(index + 1)"
        }
        if let style = attributes[.underlineStyle] as? Int, style != 0 { controls += "\\ul" }
        if let style = attributes[.strikethroughStyle] as? Int, style != 0 { controls += "\\strike" }
        if let paragraph = attributes[.paragraphStyle] as? NSParagraphStyle {
            controls += [.center: "\\qc", .right: "\\qr", .left: "\\ql"][paragraph.alignment] ?? ""
        }
        return controls
    }

    /// Creates an attributed string by parsing RTF data.
    ///
    /// The reader handles the controls the writer emits plus the common
    /// wild-RTF set: groups with state save/restore, `\fonttbl`/`\colortbl`,
    /// face/size/bold/italic/underline/strikethrough/color, paragraph
    /// alignment (`\ql`/`\qc`/`\qr`), `\par`/`\line`/`\tab`, `\uN` unicode and
    /// `\'hh` hex escapes, and skipped `\*` destinations. Unknown control
    /// words are ignored, so WordPad/Office output reads without breaking.
    public convenience init?(rtf data: Data, documentAttributes: UnsafeMutablePointer<[DocumentAttributeKey: Any]>? = nil) {
        guard let parsed = RTFReader(data: data)?.parse() else {
            return nil
        }
        self.init(attributedString: parsed)
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
                if let scalar = UnicodeScalar(ascii) {
                    escaped.append(Character(scalar))
                }
            default:
                // RTF unicode escapes are signed 16-bit with a fallback char.
                escaped += "\\u\(Int16(bitPattern: unit))?"
            }
        }
        return escaped
    }
}

/// A small RTF tokenizer/parser producing attributed-string runs.
private final class RTFReader {
    /// Formatting state, saved and restored at RTF group boundaries.
    private struct State {
        var fontIndex = 0
        var fontSize: CGFloat = 12
        var bold = false
        var italic = false
        var underline = false
        var strikethrough = false
        var colorIndex = 0
        var alignment: NSTextAlignment = .natural
        var destination = Destination.content
    }

    /// What the current group's text means.
    private enum Destination {
        case content
        case fontTable
        case colorTable
        case skip
    }

    private let bytes: [UInt8]
    private var index = 0
    private var state = State()
    private var stack: [State] = []
    private var fontTable: [Int: String] = [:]
    private var colorTable: [NSColor?] = []
    private var pendingFontName = ""
    private struct PendingColor {
        var red = 0
        var green = 0
        var blue = 0
        var hasComponents = false
    }

    private var pendingColor = PendingColor()
    private var pendingText: [UInt16] = []
    private let result = NSMutableAttributedString(string: "")

    init?(data: Data) {
        bytes = Array(data)
        // Any RTF stream opens with "{\rtf".
        guard bytes.count >= 5, Array("{\\rtf".utf8) == Array(bytes.prefix(5)) else {
            return nil
        }
    }

    func parse() -> NSAttributedString? {
        while index < bytes.count {
            let byte = bytes[index]
            switch byte {
            case UInt8(ascii: "{"):
                index += 1
                flushText()
                stack.append(state)
            case UInt8(ascii: "}"):
                index += 1
                flushText()
                if state.destination == .fontTable {
                    finishFontEntry()
                }
                if let saved = stack.popLast() {
                    state = saved
                }
            case UInt8(ascii: "\\"):
                index += 1
                parseControl()
            case 0x0d, 0x0a:
                // Raw newlines in the RTF source are ignored per the spec.
                index += 1
            default:
                consumeText(byte)
                index += 1
            }
        }
        flushText()
        return result
    }

    /// Handles the character(s) after a backslash.
    private func parseControl() {
        guard index < bytes.count else {
            return
        }
        let byte = bytes[index]
        guard !parseControlSymbol(byte) else {
            return
        }
        let (word, parameter) = parseControlWord()
        apply(word: word, parameter: parameter)
    }

    private func parseControlSymbol(_ byte: UInt8) -> Bool {
        switch byte {
        case UInt8(ascii: "\\"), UInt8(ascii: "{"), UInt8(ascii: "}"):
            consumeText(byte)
            index += 1
            return true
        case UInt8(ascii: "'"):
            index += 1
            let high = hexValue(at: index)
            let low = hexValue(at: index + 1)
            index += 2
            if let high, let low, state.destination != .skip {
                // Treat hex escapes as Latin-1, close enough for common text.
                appendScalar(UInt16(high * 16 + low))
            }
            return true
        case UInt8(ascii: "*"):
            // \* marks an optional destination; skip the whole group.
            index += 1
            state.destination = .skip
            return true
        case UInt8(ascii: "~"):
            index += 1
            consumeText(UInt8(ascii: " "))
            return true
        default:
            return false
        }
    }

    private func parseControlWord() -> (String, Int?) {
        var word = ""
        while index < bytes.count, (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(bytes[index]) {
            word.append(Character(UnicodeScalar(bytes[index])))
            index += 1
        }
        var parameter: Int?
        var negative = false
        if index < bytes.count, bytes[index] == UInt8(ascii: "-") {
            negative = true
            index += 1
        }
        var digits = 0
        var value = 0
        while index < bytes.count, (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(bytes[index]) {
            value = value * 10 + Int(bytes[index] - UInt8(ascii: "0"))
            digits += 1
            index += 1
        }
        if digits > 0 {
            parameter = negative ? -value : value
        }
        // One space after a control word belongs to the control word.
        if index < bytes.count, bytes[index] == UInt8(ascii: " ") {
            index += 1
        }
        return (word, parameter)
    }

    /// Applies one control word to the parser state.
    private func apply(word: String, parameter: Int?) {
        if applyDestinationWord(word) { return }
        if applyFontWord(word, parameter: parameter) { return }
        if applyAlignmentWord(word) { return }
        if applyTextWord(word, parameter: parameter) { return }
        _ = applyColorWord(word, parameter: parameter)
    }

    private func applyDestinationWord(_ word: String) -> Bool {
        switch word {
        case "fonttbl":
            state.destination = .fontTable
            return true
        case "colortbl":
            state.destination = .colorTable
            return true
        case "stylesheet", "info", "pict", "themedata", "colorschememapping", "fldinst", "generator":
            state.destination = .skip
            return true
        default:
            return false
        }
    }

    private func applyFontWord(_ word: String, parameter: Int?) -> Bool {
        switch word {
        case "f":
            if state.destination == .fontTable {
                finishFontEntry()
            }
            flushText()
            state.fontIndex = parameter ?? 0
            return true
        case "fs":
            flushText()
            state.fontSize = CGFloat(parameter ?? 24) / 2
            return true
        case "b":
            flushText()
            state.bold = parameter != 0
            return true
        case "i":
            flushText()
            state.italic = parameter != 0
            return true
        case "ul":
            flushText()
            state.underline = parameter != 0
            return true
        case "ulnone":
            flushText()
            state.underline = false
            return true
        case "strike":
            flushText()
            state.strikethrough = parameter != 0
            return true
        case "cf":
            flushText()
            state.colorIndex = parameter ?? 0
            return true
        default:
            return false
        }
    }

    private func applyAlignmentWord(_ word: String) -> Bool {
        switch word {
        case "ql":
            flushText()
            state.alignment = .left
            return true
        case "qc":
            flushText()
            state.alignment = .center
            return true
        case "qr":
            flushText()
            state.alignment = .right
            return true
        case "pard":
            flushText()
            state.alignment = .natural
            return true
        default:
            return false
        }
    }

    private func applyTextWord(_ word: String, parameter: Int?) -> Bool {
        switch word {
        case "par", "line":
            if state.destination == .content {
                appendScalar(UInt16(0x0a))
            }
            return true
        case "tab":
            if state.destination == .content {
                appendScalar(UInt16(0x09))
            }
            return true
        case "u":
            if state.destination == .content, let parameter {
                appendScalar(UInt16(bitPattern: Int16(truncatingIfNeeded: parameter)))
                // Skip the single fallback character the writer emits.
                if index < bytes.count, bytes[index] == UInt8(ascii: "?") {
                    index += 1
                }
            }
            return true
        default:
            return false
        }
    }

    private func applyColorWord(_ word: String, parameter: Int?) -> Bool {
        switch word {
        case "red":
            pendingColor.red = parameter ?? 0
            pendingColor.hasComponents = true
            return true
        case "green":
            pendingColor.green = parameter ?? 0
            pendingColor.hasComponents = true
            return true
        case "blue":
            pendingColor.blue = parameter ?? 0
            pendingColor.hasComponents = true
            return true
        default:
            return false
        }
    }

    /// Routes plain text bytes by the current destination.
    private func consumeText(_ byte: UInt8) {
        switch state.destination {
        case .content:
            appendScalar(UInt16(byte))
        case .fontTable:
            if byte == UInt8(ascii: ";") {
                finishFontEntry()
            } else {
                pendingFontName.append(Character(UnicodeScalar(byte)))
            }
        case .colorTable:
            if byte == UInt8(ascii: ";") {
                if pendingColor.hasComponents {
                    colorTable.append(NSColor(
                        calibratedRed: CGFloat(pendingColor.red) / 255,
                        green: CGFloat(pendingColor.green) / 255,
                        blue: CGFloat(pendingColor.blue) / 255,
                        alpha: 1
                    ))
                } else {
                    // The empty first entry is the automatic color.
                    colorTable.append(nil)
                }
                pendingColor = PendingColor()
            }
        case .skip:
            break
        }
    }

    /// Records a completed font-table entry name.
    private func finishFontEntry() {
        let name = pendingFontName.trimmingCharacters(in: " ")
        if !name.isEmpty {
            fontTable[state.fontIndex] = name
        }
        pendingFontName = ""
    }

    private func appendScalar(_ unit: UInt16) {
        pendingText.append(unit)
    }

    /// Emits the buffered text as a run carrying the current formatting.
    private func flushText() {
        guard !pendingText.isEmpty else {
            return
        }
        let text = String(decoding: pendingText, as: UTF16.self)
        pendingText.removeAll()

        var attributes: [NSAttributedString.Key: Any] = [:]
        let faceName = fontTable[state.fontIndex] ?? "Segoe UI"
        attributes[.font] = NSFont(
            name: faceName,
            size: state.fontSize,
            weight: state.bold ? .bold : .regular,
            italic: state.italic
        )
        // \cfN indexes the color table 0-based; a nil entry is the automatic
        // color and carries no explicit attribute.
        if state.colorIndex >= 0, state.colorIndex < colorTable.count, let color = colorTable[state.colorIndex] {
            attributes[.foregroundColor] = color
        }
        if state.underline {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if state.strikethrough {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        if state.alignment != .natural {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = state.alignment
            attributes[.paragraphStyle] = paragraph
        }
        result.append(NSAttributedString(string: text, attributes: attributes))
    }

    private func hexValue(at position: Int) -> Int? {
        guard position < bytes.count else {
            return nil
        }
        let byte = bytes[position]
        switch byte {
        case UInt8(ascii: "0")...UInt8(ascii: "9"):
            return Int(byte - UInt8(ascii: "0"))
        case UInt8(ascii: "a")...UInt8(ascii: "f"):
            return Int(byte - UInt8(ascii: "a")) + 10
        case UInt8(ascii: "A")...UInt8(ascii: "F"):
            return Int(byte - UInt8(ascii: "A")) + 10
        default:
            return nil
        }
    }
}

private extension String {
    /// Trims the given single-character set from both ends.
    func trimmingCharacters(in characters: String) -> String {
        var start = startIndex
        var end = endIndex
        while start < end, characters.contains(self[start]) {
            start = index(after: start)
        }
        while start < end, characters.contains(self[index(before: end)]) {
            end = index(before: end)
        }
        return String(self[start..<end])
    }
}
