/// Serialization helpers shared by `JSONEncoder` and `JSONDecoder`.

/// Formats a `Double` the way Foundation's JSON output does: an integral value
/// prints without a fractional part (`5`, not `5.0`), everything else uses
/// Swift's shortest round-trippable description.
enum JSONNumber {
    static func string(from value: Double) -> String {
        if value == value.rounded(), abs(value) < 1e15 {
            return String(Int64(value))
        }
        return "\(value)"
    }
}

/// Serializes a `JSONValue` tree to UTF-8 bytes with the requested formatting.
struct JSONWriter {
    let formatting: JSONEncoder.OutputFormatting
    private(set) var utf8: [UInt8] = []

    private var pretty: Bool { formatting.contains(.prettyPrinted) }
    private var sortKeys: Bool { formatting.contains(.sortedKeys) }
    private var escapeSlashes: Bool { !formatting.contains(.withoutEscapingSlashes) }

    init(formatting: JSONEncoder.OutputFormatting) {
        self.formatting = formatting
    }

    mutating func write(_ value: JSONValue) {
        write(value, indent: 0)
    }

    private mutating func write(_ value: JSONValue, indent: Int) {
        switch value {
        case .null:
            append("null")
        case .bool(let flag):
            append(flag ? "true" : "false")
        case .number(let text):
            append(text)
        case .string(let text):
            writeString(text)
        case .array(let elements):
            writeArray(elements, indent: indent)
        case .object(let pairs):
            writeObject(pairs, indent: indent)
        }
    }

    private mutating func writeArray(_ elements: [JSONValue], indent: Int) {
        guard !elements.isEmpty else {
            append("[]")
            return
        }
        utf8.append(0x5B) // [
        for (offset, element) in elements.enumerated() {
            if offset > 0 { utf8.append(0x2C) } // ,
            newlineAndIndent(indent + 1)
            write(element, indent: indent + 1)
        }
        newlineAndIndent(indent)
        utf8.append(0x5D) // ]
    }

    private mutating func writeObject(_ pairs: [(String, JSONValue)], indent: Int) {
        guard !pairs.isEmpty else {
            append("{}")
            return
        }
        let ordered = sortKeys ? pairs.sorted { $0.0 < $1.0 } : pairs
        utf8.append(0x7B) // {
        for (offset, pair) in ordered.enumerated() {
            if offset > 0 { utf8.append(0x2C) } // ,
            newlineAndIndent(indent + 1)
            writeString(pair.0)
            // Foundation's pretty printer spaces the colon on both sides
            // ("key" : value); compact output uses a bare colon.
            if pretty { utf8.append(0x20) }
            utf8.append(0x3A) // :
            if pretty { utf8.append(0x20) }
            write(pair.1, indent: indent + 1)
        }
        newlineAndIndent(indent)
        utf8.append(0x7D) // }
    }

    private mutating func newlineAndIndent(_ level: Int) {
        guard pretty else { return }
        utf8.append(0x0A) // \n
        for _ in 0..<level {
            utf8.append(0x20)
            utf8.append(0x20) // two-space indent, matching Foundation
        }
    }

    private mutating func append(_ text: String) {
        utf8.append(contentsOf: text.utf8)
    }

    /// Writes a JSON string literal with the escaping Foundation uses.
    private mutating func writeString(_ text: String) {
        utf8.append(0x22) // "
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": utf8.append(contentsOf: [0x5C, 0x22])
            case "\\": utf8.append(contentsOf: [0x5C, 0x5C])
            case "\n": utf8.append(contentsOf: [0x5C, 0x6E])
            case "\r": utf8.append(contentsOf: [0x5C, 0x72])
            case "\t": utf8.append(contentsOf: [0x5C, 0x74])
            case "\u{08}": utf8.append(contentsOf: [0x5C, 0x62]) // \b
            case "\u{0C}": utf8.append(contentsOf: [0x5C, 0x66]) // \f
            case "/" where escapeSlashes:
                utf8.append(contentsOf: [0x5C, 0x2F])
            default:
                if scalar.value < 0x20 {
                    appendUnicodeEscape(UInt16(scalar.value))
                } else {
                    utf8.append(contentsOf: String(scalar).utf8)
                }
            }
        }
        utf8.append(0x22) // "
    }

    private mutating func appendUnicodeEscape(_ code: UInt16) {
        let hex = "0123456789abcdef"
        let digits = Array(hex.utf8)
        utf8.append(0x5C) // \
        utf8.append(0x75) // u
        utf8.append(digits[Int((code >> 12) & 0xF)])
        utf8.append(digits[Int((code >> 8) & 0xF)])
        utf8.append(digits[Int((code >> 4) & 0xF)])
        utf8.append(digits[Int(code & 0xF)])
    }
}

/// Foundation's `camelCase` → `snake_case` key transform (and its inverse for
/// decoding), reproduced from the documented algorithm.
enum JSONKeyTransform {
    static func toSnakeCase(_ key: String) -> String {
        guard !key.isEmpty else { return key }
        let scalars = Array(key.unicodeScalars)

        // Words are split at case boundaries, Foundation's way: a run of
        // uppercase is one word (an acronym — `HTML` → `html`, not `h_t_m_l`),
        // *except* that when an uppercase run is immediately followed by
        // lowercase, its last character begins the next word
        // (`HTMLDocument` → `html_document`).
        var words: [Range<Int>] = []
        var wordStart = 0
        var index = 1
        while index < scalars.count {
            // Find the next uppercase letter.
            guard isUppercase(scalars[index]) else { index += 1; continue }
            words.append(wordStart..<index)

            // Scan the uppercase run.
            var runEnd = index
            while runEnd < scalars.count, isUppercase(scalars[runEnd]) {
                runEnd += 1
            }
            if runEnd < scalars.count, isLowercase(scalars[runEnd]), runEnd - index > 1 {
                // A multi-char acronym followed by lowercase: the last capital
                // of the run starts the next word.
                words.append(index..<(runEnd - 1))
                wordStart = runEnd - 1
                index = runEnd
            } else {
                wordStart = index
                index = max(runEnd, index + 1)
            }
        }
        words.append(wordStart..<scalars.count)

        return words
            .filter { !$0.isEmpty }
            .map { String(String.UnicodeScalarView(scalars[$0])).lowercased() }
            .joined(separator: "_")
    }

    private static func isUppercase(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value >= 0x41 && scalar.value <= 0x5A
    }

    private static func isLowercase(_ scalar: Unicode.Scalar) -> Bool {
        scalar.value >= 0x61 && scalar.value <= 0x7A
    }

    /// `snake_case` → `camelCase`, for `.convertFromSnakeCase` on decode.
    static func fromSnakeCase(_ key: String) -> String {
        guard key.contains("_") else { return key }
        let scalars = Array(key.unicodeScalars)

        var leadingCount = 0
        while leadingCount < scalars.count, scalars[leadingCount] == "_" {
            leadingCount += 1
        }
        var trailingCount = 0
        while trailingCount < scalars.count - leadingCount, scalars[scalars.count - 1 - trailingCount] == "_" {
            trailingCount += 1
        }
        let leading = String(repeating: "_", count: leadingCount)
        let trailing = String(repeating: "_", count: trailingCount)
        let core = String(String.UnicodeScalarView(scalars[leadingCount..<(scalars.count - trailingCount)]))
        guard !core.isEmpty else { return key }

        let parts = core.split(separator: "_", omittingEmptySubsequences: false)
        var result = String(parts[0])
        for part in parts.dropFirst() {
            if let first = part.first {
                result += String(first).uppercased() + part.dropFirst()
            } else {
                result += "_"
            }
        }
        return leading + result + trailing
    }
}

/// Formatters for the non-default date strategies. A fresh instance per access
/// keeps this free of shared mutable state (`DateFormatter` isn't `Sendable`);
/// the non-default `.iso8601` path isn't hot.
enum JSONDateFormats {
    static var iso8601: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)!
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
}
