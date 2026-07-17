/// A small recursive-descent JSON parser over UTF-8 bytes, producing the same
/// `JSONValue` tree the encoder serializes. Standards-compliant enough for
/// round-tripping Foundation output: objects, arrays, strings (with `\uXXXX`
/// and surrogate pairs), numbers, `true`/`false`/`null`, and JSON whitespace.
struct JSONParser {
    struct ParseError: Error {
        let message: String
    }

    private let bytes: [UInt8]
    private var index = 0

    init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    mutating func parse() throws -> JSONValue {
        skipWhitespace()
        let value = try parseValue()
        skipWhitespace()
        guard index >= bytes.count else {
            throw ParseError(message: "Trailing content after the top-level JSON value.")
        }
        return value
    }

    // MARK: - Values

    private mutating func parseValue() throws -> JSONValue {
        guard index < bytes.count else {
            throw ParseError(message: "Unexpected end of input.")
        }
        switch bytes[index] {
        case 0x7B: return try parseObject()   // {
        case 0x5B: return try parseArray()    // [
        case 0x22: return .string(try parseString())  // "
        case 0x74: try expect("true"); return .bool(true)
        case 0x66: try expect("false"); return .bool(false)
        case 0x6E: try expect("null"); return .null
        case 0x2D, 0x30...0x39: return try parseNumber()  // - or digit
        default:
            throw ParseError(message: "Unexpected character 0x\(String(bytes[index], radix: 16)).")
        }
    }

    private mutating func parseObject() throws -> JSONValue {
        index += 1 // {
        var pairs: [(String, JSONValue)] = []
        skipWhitespace()
        if peek() == 0x7D { index += 1; return .object(pairs) } // empty {}
        while true {
            skipWhitespace()
            guard peek() == 0x22 else {
                throw ParseError(message: "Expected a string key in an object.")
            }
            let key = try parseString()
            skipWhitespace()
            guard peek() == 0x3A else {
                throw ParseError(message: "Expected ':' after an object key.")
            }
            index += 1 // :
            skipWhitespace()
            let value = try parseValue()
            pairs.append((key, value))
            skipWhitespace()
            switch peek() {
            case 0x2C: index += 1 // ,
            case 0x7D: index += 1; return .object(pairs) // }
            default:
                throw ParseError(message: "Expected ',' or '}' in an object.")
            }
        }
    }

    private mutating func parseArray() throws -> JSONValue {
        index += 1 // [
        var elements: [JSONValue] = []
        skipWhitespace()
        if peek() == 0x5D { index += 1; return .array(elements) } // empty []
        while true {
            skipWhitespace()
            elements.append(try parseValue())
            skipWhitespace()
            switch peek() {
            case 0x2C: index += 1 // ,
            case 0x5D: index += 1; return .array(elements) // ]
            default:
                throw ParseError(message: "Expected ',' or ']' in an array.")
            }
        }
    }

    private mutating func parseString() throws -> String {
        index += 1 // opening "
        var scalars = String.UnicodeScalarView()
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 0x22 { // closing "
                index += 1
                return String(scalars)
            }
            if byte == 0x5C { // backslash
                index += 1
                try scalars.append(parseEscape())
                continue
            }
            // A raw UTF-8 sequence: decode it whole so multibyte scalars survive.
            let (scalar, width) = try decodeUTF8(at: index)
            scalars.append(scalar)
            index += width
        }
        throw ParseError(message: "Unterminated string.")
    }

    private mutating func parseEscape() throws -> Unicode.Scalar {
        guard index < bytes.count else {
            throw ParseError(message: "Unterminated escape.")
        }
        let byte = bytes[index]
        index += 1
        switch byte {
        case 0x22: return "\""
        case 0x5C: return "\\"
        case 0x2F: return "/"
        case 0x62: return "\u{08}"
        case 0x66: return "\u{0C}"
        case 0x6E: return "\n"
        case 0x72: return "\r"
        case 0x74: return "\t"
        case 0x75: return try parseUnicodeEscape()
        default:
            throw ParseError(message: "Invalid escape '\\\(Character(Unicode.Scalar(byte)))'.")
        }
    }

    private mutating func parseUnicodeEscape() throws -> Unicode.Scalar {
        let first = try parseHex4()
        // A high surrogate must be followed by a `\uXXXX` low surrogate.
        if (0xD800...0xDBFF).contains(first) {
            guard index + 1 < bytes.count, bytes[index] == 0x5C, bytes[index + 1] == 0x75 else {
                throw ParseError(message: "Expected a low surrogate after a high surrogate.")
            }
            index += 2 // \u
            let second = try parseHex4()
            guard (0xDC00...0xDFFF).contains(second) else {
                throw ParseError(message: "Invalid low surrogate.")
            }
            let combined = 0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00)
            guard let scalar = Unicode.Scalar(combined) else {
                throw ParseError(message: "Invalid surrogate pair.")
            }
            return scalar
        }
        guard let scalar = Unicode.Scalar(first) else {
            throw ParseError(message: "Invalid unicode escape.")
        }
        return scalar
    }

    private mutating func parseHex4() throws -> Int {
        guard index + 4 <= bytes.count else {
            throw ParseError(message: "Truncated \\u escape.")
        }
        var value = 0
        for _ in 0..<4 {
            value = value * 16 + (try hexDigit(bytes[index]))
            index += 1
        }
        return value
    }

    private func hexDigit(_ byte: UInt8) throws -> Int {
        switch byte {
        case 0x30...0x39: return Int(byte - 0x30)
        case 0x41...0x46: return Int(byte - 0x41 + 10)
        case 0x61...0x66: return Int(byte - 0x61 + 10)
        default:
            throw ParseError(message: "Invalid hex digit in \\u escape.")
        }
    }

    private mutating func parseNumber() throws -> JSONValue {
        let start = index
        if peek() == 0x2D { index += 1 } // -
        while let byte = peekOptional(), (0x30...0x39).contains(byte) { index += 1 }
        if peek() == 0x2E { // .
            index += 1
            while let byte = peekOptional(), (0x30...0x39).contains(byte) { index += 1 }
        }
        if peek() == 0x65 || peek() == 0x45 { // e / E
            index += 1
            if peek() == 0x2B || peek() == 0x2D { index += 1 } // +/-
            while let byte = peekOptional(), (0x30...0x39).contains(byte) { index += 1 }
        }
        let text = String(decoding: bytes[start..<index], as: UTF8.self)
        guard Double(text) != nil else {
            throw ParseError(message: "Malformed number '\(text)'.")
        }
        return .number(text)
    }

    // MARK: - Bytes

    private func peek() -> UInt8 {
        index < bytes.count ? bytes[index] : 0
    }

    private func peekOptional() -> UInt8? {
        index < bytes.count ? bytes[index] : nil
    }

    private mutating func skipWhitespace() {
        while index < bytes.count {
            switch bytes[index] {
            case 0x20, 0x09, 0x0A, 0x0D: index += 1
            default: return
            }
        }
    }

    private mutating func expect(_ literal: String) throws {
        for expected in literal.utf8 {
            guard index < bytes.count, bytes[index] == expected else {
                throw ParseError(message: "Expected '\(literal)'.")
            }
            index += 1
        }
    }

    /// Decodes one UTF-8 scalar starting at `offset`, returning it and its byte
    /// width, so raw multibyte text inside strings is preserved exactly.
    private func decodeUTF8(at offset: Int) throws -> (Unicode.Scalar, Int) {
        let first = bytes[offset]
        let width: Int
        switch first {
        case 0x00...0x7F: width = 1
        case 0xC0...0xDF: width = 2
        case 0xE0...0xEF: width = 3
        case 0xF0...0xF7: width = 4
        default:
            throw ParseError(message: "Invalid UTF-8 lead byte.")
        }
        guard offset + width <= bytes.count else {
            throw ParseError(message: "Truncated UTF-8 sequence.")
        }
        var decoder = UTF8()
        var iterator = bytes[offset..<(offset + width)].makeIterator()
        switch decoder.decode(&iterator) {
        case .scalarValue(let scalar): return (scalar, width)
        default:
            throw ParseError(message: "Invalid UTF-8 sequence.")
        }
    }
}
