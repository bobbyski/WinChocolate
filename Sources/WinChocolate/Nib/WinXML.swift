// WinXML.swift
// A minimal XML document parser for Interface Builder `.xib` files (Phase 15).
//
// Xib documents are plain, well-formed XML with elements, attributes, and no
// mixed content the loader cares about, so a small recursive-descent parser is
// all nib loading needs — the same dependency-free approach as `WinJSON`
// (UserDefaults) and the WinCoreGraphics codecs. Not a general XML library:
// namespaces, CDATA, and DTD internals are out of scope (IB emits none).

/// One parsed XML element: name, attributes, and child elements.
final class WinXMLElement {
    let name: String
    let attributes: [String: String]
    private(set) var children: [WinXMLElement] = []

    init(name: String, attributes: [String: String]) {
        self.name = name
        self.attributes = attributes
    }

    func addChild(_ child: WinXMLElement) {
        children.append(child)
    }

    /// The value of an attribute, or `nil`.
    func attribute(_ name: String) -> String? {
        attributes[name]
    }

    /// The first child with an element name.
    func firstChild(named name: String) -> WinXMLElement? {
        children.first { $0.name == name }
    }

    /// The first child carrying a `key="..."` attribute, IB's slot convention
    /// (e.g. `<rect key="frame" .../>`, `<buttonCell key="cell" .../>`).
    func firstChild(withKey key: String) -> WinXMLElement? {
        children.first { $0.attribute("key") == key }
    }

    /// Every child with an element name.
    func children(named name: String) -> [WinXMLElement] {
        children.filter { $0.name == name }
    }
}

/// Parses a complete XML document, returning its root element.
enum WinXML {
    static func parse(_ text: String) -> WinXMLElement? {
        var scanner = Scanner(text: Array(text.unicodeScalars))
        return scanner.parseDocument()
    }

    private struct Scanner {
        let text: [Unicode.Scalar]
        var index = 0

        init(text: [Unicode.Scalar]) {
            self.text = text
        }

        var isAtEnd: Bool { index >= text.count }

        mutating func parseDocument() -> WinXMLElement? {
            skipProlog()
            return parseElement()
        }

        // Skips whitespace, the XML declaration, comments, and DOCTYPE up to
        // the first real element.
        private mutating func skipProlog() {
            while !isAtEnd {
                skipWhitespace()
                if matches("<?") {
                    skipPast("?>")
                } else if matches("<!--") {
                    skipPast("-->")
                } else if matches("<!") {
                    skipPast(">")
                } else {
                    return
                }
            }
        }

        private mutating func parseElement() -> WinXMLElement? {
            skipWhitespace()
            guard consume("<") else { return nil }
            let name = readName()
            guard !name.isEmpty else { return nil }

            var attributes: [String: String] = [:]
            while true {
                skipWhitespace()
                if consume("/") {
                    // Self-closing element.
                    guard consume(">") else { return nil }
                    return WinXMLElement(name: name, attributes: attributes)
                }
                if consume(">") {
                    break
                }
                let attributeName = readName()
                guard !attributeName.isEmpty else { return nil }
                skipWhitespace()
                guard consume("=") else { return nil }
                skipWhitespace()
                guard let value = readQuotedValue() else { return nil }
                attributes[attributeName] = value
            }

            // Children until the matching close tag. Text content (IB emits
            // it only for a few elements like <string>) is skipped — the nib
            // loader consumes attributes and structure.
            let element = WinXMLElement(name: name, attributes: attributes)
            while !isAtEnd {
                skipUntil("<")
                if matches("<!--") {
                    skipPast("-->")
                    continue
                }
                if matches("</") {
                    index += 2
                    _ = readName()
                    skipWhitespace()
                    _ = consume(">")
                    return element
                }
                guard let child = parseElement() else { return nil }
                element.addChild(child)
            }
            return element
        }

        private mutating func readName() -> String {
            var name = String.UnicodeScalarView()
            while !isAtEnd {
                let scalar = text[index]
                if scalar == " " || scalar == "\t" || scalar == "\n" || scalar == "\r"
                    || scalar == ">" || scalar == "/" || scalar == "=" || scalar == "<" {
                    break
                }
                name.append(scalar)
                index += 1
            }
            return String(name)
        }

        private mutating func readQuotedValue() -> String? {
            guard !isAtEnd else { return nil }
            let quote = text[index]
            guard quote == "\"" || quote == "'" else { return nil }
            index += 1
            var raw = String.UnicodeScalarView()
            while !isAtEnd, text[index] != quote {
                raw.append(text[index])
                index += 1
            }
            guard consumeScalar(quote) else { return nil }
            return WinXML.decodeEntities(String(raw))
        }

        private mutating func skipWhitespace() {
            while !isAtEnd {
                let scalar = text[index]
                if scalar == " " || scalar == "\t" || scalar == "\n" || scalar == "\r" {
                    index += 1
                } else {
                    return
                }
            }
        }

        private mutating func skipUntil(_ scalar: Unicode.Scalar) {
            while !isAtEnd, text[index] != scalar {
                index += 1
            }
        }

        private func matches(_ literal: String) -> Bool {
            let scalars = Array(literal.unicodeScalars)
            guard index + scalars.count <= text.count else { return false }
            for (offset, scalar) in scalars.enumerated() where text[index + offset] != scalar {
                return false
            }
            return true
        }

        private mutating func skipPast(_ literal: String) {
            while !isAtEnd {
                if matches(literal) {
                    index += literal.unicodeScalars.count
                    return
                }
                index += 1
            }
        }

        private mutating func consume(_ scalar: Unicode.Scalar) -> Bool {
            consumeScalar(scalar)
        }

        private mutating func consumeScalar(_ scalar: Unicode.Scalar) -> Bool {
            guard !isAtEnd, text[index] == scalar else { return false }
            index += 1
            return true
        }
    }

    /// Decodes the five predefined XML entities plus numeric references.
    static func decodeEntities(_ value: String) -> String {
        guard value.contains("&") else { return value }
        var out = String.UnicodeScalarView()
        let scalars = Array(value.unicodeScalars)
        var i = 0
        while i < scalars.count {
            guard scalars[i] == "&" else {
                out.append(scalars[i])
                i += 1
                continue
            }
            // Find the terminating semicolon (entities are short).
            var end = i + 1
            while end < scalars.count, end - i <= 10, scalars[end] != ";" {
                end += 1
            }
            guard end < scalars.count, scalars[end] == ";" else {
                out.append(scalars[i])
                i += 1
                continue
            }
            let body = String(String.UnicodeScalarView(scalars[(i + 1)..<end]))
            var decoded: Unicode.Scalar?
            switch body {
            case "amp": decoded = "&"
            case "lt": decoded = "<"
            case "gt": decoded = ">"
            case "quot": decoded = "\""
            case "apos": decoded = "'"
            default:
                if body.hasPrefix("#x") || body.hasPrefix("#X") {
                    decoded = UInt32(body.dropFirst(2), radix: 16).flatMap { Unicode.Scalar($0) }
                } else if body.hasPrefix("#") {
                    decoded = UInt32(body.dropFirst()).flatMap { Unicode.Scalar($0) }
                }
            }
            if let decoded {
                out.append(decoded)
                i = end + 1
            } else {
                out.append(scalars[i])
                i += 1
            }
        }
        return String(out)
    }
}
