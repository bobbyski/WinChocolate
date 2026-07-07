/// String encoding, file I/O, and `Data` conversion (plan 7.9).
///
/// A Foundation-shaped `String.Encoding` plus the everyday I/O surface:
/// `String(contentsOf:encoding:)`, BOM-sniffing `String(contentsOf:)`,
/// `String(data:encoding:)`, `data(using:)`, and
/// `write(to:atomically:encoding:)`. Decoding is strict (invalid bytes fail,
/// as in Foundation); encoding fails for unrepresentable characters unless
/// lossy conversion substitutes `?`.

/// Errors thrown by string file I/O.
public enum StringIOError: Error {
    /// The file's bytes are not valid in the requested encoding.
    case decodingFailed

    /// The string cannot be represented in the requested encoding.
    case encodingFailed
}

extension String {
    /// A text encoding for string I/O (raw values match Foundation's).
    public struct Encoding: RawRepresentable, Hashable, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// Strict 7-bit ASCII.
        public static let ascii = Encoding(rawValue: 1)

        /// UTF-8.
        public static let utf8 = Encoding(rawValue: 4)

        /// ISO Latin-1 (each byte is the same-valued Unicode scalar).
        public static let isoLatin1 = Encoding(rawValue: 5)

        /// UTF-16 with a byte-order mark (written little-endian, the Windows
        /// native order; decoding honors either BOM and defaults to LE).
        public static let utf16 = Encoding(rawValue: 10)

        /// UTF-16 little-endian, no byte-order mark.
        public static let utf16LittleEndian = Encoding(rawValue: 0x9400_0100)

        /// UTF-16 big-endian, no byte-order mark.
        public static let utf16BigEndian = Encoding(rawValue: 0x9000_0100)

        /// A Foundation alias for `utf16`.
        public static let unicode = Encoding.utf16
    }

    // MARK: Decoding

    /// Creates a string by decoding data in an encoding; fails on bytes that
    /// are not valid in that encoding.
    public init?(data: Data, encoding: Encoding) {
        guard let decoded = String.winDecode(data.array, encoding: encoding) else {
            return nil
        }
        self = decoded
    }

    /// Reads a file as text in an explicit encoding.
    public init(contentsOf url: URL, encoding: Encoding) throws {
        let data = try Data(contentsOf: url)
        guard let decoded = String.winDecode(data.array, encoding: encoding) else {
            throw StringIOError.decodingFailed
        }
        self = decoded
    }

    /// Reads a file as text, detecting the encoding from a byte-order mark
    /// (UTF-8/UTF-16 BOMs) and defaulting to UTF-8.
    public init(contentsOf url: URL) throws {
        let bytes = try Data(contentsOf: url).array
        let decoded: String?
        if bytes.count >= 3, bytes[0] == 0xEF, bytes[1] == 0xBB, bytes[2] == 0xBF {
            decoded = String.winDecode(Array(bytes.dropFirst(3)), encoding: .utf8)
        } else if bytes.count >= 2, bytes[0] == 0xFF, bytes[1] == 0xFE {
            decoded = String.winDecode(Array(bytes.dropFirst(2)), encoding: .utf16LittleEndian)
        } else if bytes.count >= 2, bytes[0] == 0xFE, bytes[1] == 0xFF {
            decoded = String.winDecode(Array(bytes.dropFirst(2)), encoding: .utf16BigEndian)
        } else {
            decoded = String.winDecode(bytes, encoding: .utf8)
        }
        guard let decoded else {
            throw StringIOError.decodingFailed
        }
        self = decoded
    }

    // MARK: Encoding

    /// Returns the string's bytes in an encoding, or `nil` when a character
    /// has no representation there (unless lossy conversion substitutes `?`).
    public func data(using encoding: Encoding, allowLossyConversion: Bool = false) -> Data? {
        guard let bytes = winEncode(encoding, lossy: allowLossyConversion) else {
            return nil
        }
        return Data(bytes)
    }

    /// Writes the string to a file in an encoding.
    ///
    /// `atomically` is accepted for source compatibility; the write goes
    /// directly to the destination path.
    public func write(to url: URL, atomically: Bool, encoding: Encoding) throws {
        guard let data = data(using: encoding) else {
            throw StringIOError.encodingFailed
        }
        try data.write(to: url)
    }

    // MARK: Codecs

    /// Decodes bytes in an encoding, or `nil` when they are invalid in it.
    static func winDecode(_ bytes: [UInt8], encoding: Encoding) -> String? {
        switch encoding {
        case .utf8:
            var decoder = UTF8()
            var iterator = bytes.makeIterator()
            var result = ""
            result.reserveCapacity(bytes.count)
            while true {
                switch decoder.decode(&iterator) {
                case .scalarValue(let scalar):
                    result.unicodeScalars.append(scalar)
                case .emptyInput:
                    return result
                case .error:
                    return nil
                }
            }
        case .ascii:
            guard bytes.allSatisfy({ $0 < 0x80 }) else {
                return nil
            }
            return String(bytes.map { Character(UnicodeScalar($0)) })
        case .isoLatin1:
            return String(bytes.map { Character(UnicodeScalar($0)) })
        case .utf16, .utf16LittleEndian, .utf16BigEndian:
            var payload = bytes[...]
            var bigEndian = encoding == .utf16BigEndian
            if encoding == .utf16 {
                // Honor a BOM; default to little-endian (the Windows order).
                if payload.count >= 2, payload.first == 0xFF, payload.dropFirst().first == 0xFE {
                    payload = payload.dropFirst(2)
                } else if payload.count >= 2, payload.first == 0xFE, payload.dropFirst().first == 0xFF {
                    payload = payload.dropFirst(2)
                    bigEndian = true
                }
            }
            guard payload.count % 2 == 0 else {
                return nil
            }
            var units: [UInt16] = []
            units.reserveCapacity(payload.count / 2)
            var index = payload.startIndex
            while index < payload.endIndex {
                let first = UInt16(payload[index])
                let second = UInt16(payload[payload.index(after: index)])
                units.append(bigEndian ? (first << 8) | second : (second << 8) | first)
                index = payload.index(index, offsetBy: 2)
            }
            var decoder = UTF16()
            var iterator = units.makeIterator()
            var result = ""
            while true {
                switch decoder.decode(&iterator) {
                case .scalarValue(let scalar):
                    result.unicodeScalars.append(scalar)
                case .emptyInput:
                    return result
                case .error:
                    return nil
                }
            }
        default:
            return nil
        }
    }

    /// Encodes the string's bytes in an encoding, or `nil` for characters the
    /// encoding cannot represent (substituted with `?` when lossy).
    private func winEncode(_ encoding: Encoding, lossy: Bool) -> [UInt8]? {
        switch encoding {
        case .utf8:
            return Array(utf8)
        case .ascii, .isoLatin1:
            let limit: UInt32 = encoding == .ascii ? 0x80 : 0x100
            var result: [UInt8] = []
            result.reserveCapacity(unicodeScalars.count)
            for scalar in unicodeScalars {
                if scalar.value < limit {
                    result.append(UInt8(scalar.value))
                } else if lossy {
                    result.append(UInt8(ascii: "?"))
                } else {
                    return nil
                }
            }
            return result
        case .utf16, .utf16LittleEndian, .utf16BigEndian:
            var result: [UInt8] = []
            result.reserveCapacity(utf16.count * 2 + 2)
            if encoding == .utf16 {
                // Little-endian BOM.
                result.append(contentsOf: [0xFF, 0xFE])
            }
            let bigEndian = encoding == .utf16BigEndian
            for unit in utf16 {
                let high = UInt8(unit >> 8)
                let low = UInt8(unit & 0xFF)
                result.append(bigEndian ? high : low)
                result.append(bigEndian ? low : high)
            }
            return result
        default:
            return nil
        }
    }
}
