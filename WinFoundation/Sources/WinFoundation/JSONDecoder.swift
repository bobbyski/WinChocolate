/// A Foundation-compatible JSON decoder — the inverse of `JSONEncoder`, built
/// on the standard library's `Decodable`/`Decoder` machinery, with Apple's
/// default strategies (`Date` from seconds-since-2001, `Data` from base64).
public final class JSONDecoder {

    /// How `Date` values are read.
    public enum DateDecodingStrategy {
        case deferredToDate
        case secondsSince1970
        case millisecondsSince1970
        case iso8601
        case formatted(DateFormatter)
        case custom((Decoder) throws -> Date)
    }

    /// How `Data` values are read.
    public enum DataDecodingStrategy {
        case deferredToData
        case base64
        case custom((Decoder) throws -> Data)
    }

    /// How coding keys are transformed on the way in.
    public enum KeyDecodingStrategy {
        case useDefaultKeys
        case convertFromSnakeCase
        case custom(([CodingKey]) -> CodingKey)
    }

    public var dateDecodingStrategy: DateDecodingStrategy = .deferredToDate
    public var dataDecodingStrategy: DataDecodingStrategy = .base64
    public var keyDecodingStrategy: KeyDecodingStrategy = .useDefaultKeys
    public var userInfo: [CodingUserInfoKey: Any] = [:]

    public init() {}

    /// Decodes a value from UTF-8 JSON bytes.
    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let value: JSONValue
        do {
            var parser = JSONParser(bytes: Array(data))
            value = try parser.parse()
        } catch let error as JSONParser.ParseError {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: [],
                debugDescription: error.message))
        }
        let options = Options(
            dateStrategy: dateDecodingStrategy,
            dataStrategy: dataDecodingStrategy,
            keyStrategy: keyDecodingStrategy,
            userInfo: userInfo)
        let decoder = _JSONDecoder(value: value, options: options, codingPath: [])
        return try decoder.unbox(value, as: T.self, at: [])
    }

    struct Options {
        let dateStrategy: DateDecodingStrategy
        let dataStrategy: DataDecodingStrategy
        let keyStrategy: KeyDecodingStrategy
        let userInfo: [CodingUserInfoKey: Any]
    }
}

// MARK: - Decoder core

private final class _JSONDecoder: Decoder {
    let value: JSONValue
    let options: JSONDecoder.Options
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { options.userInfo }

    init(value: JSONValue, options: JSONDecoder.Options, codingPath: [CodingKey]) {
        self.value = value
        self.options = options
        self.codingPath = codingPath
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        guard case .object(let pairs) = value else {
            throw typeMismatch([String: Any].self, "keyed container")
        }
        var map: [String: JSONValue] = [:]
        for (key, element) in pairs {
            map[transform(key)] = element
        }
        return KeyedDecodingContainer(KeyedContainer<Key>(decoder: self, values: map, codingPath: codingPath))
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        guard case .array(let elements) = value else {
            throw typeMismatch([Any].self, "unkeyed container")
        }
        return UnkeyedContainer(decoder: self, elements: elements, codingPath: codingPath)
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        SingleValueContainer(decoder: self, value: value, codingPath: codingPath)
    }

    /// Applies the key strategy to an incoming JSON key.
    private func transform(_ key: String) -> String {
        switch options.keyStrategy {
        case .useDefaultKeys: return key
        case .convertFromSnakeCase: return JSONKeyTransform.fromSnakeCase(key)
        case .custom: return key   // custom keys resolve per-container below
        }
    }

    private func typeMismatch(_ type: Any.Type, _ description: String) -> DecodingError {
        DecodingError.typeMismatch(type, DecodingError.Context(
            codingPath: codingPath,
            debugDescription: "Expected a \(description) but found \(value.describeType())."))
    }

    // MARK: unbox

    func unbox<T: Decodable>(_ value: JSONValue, as type: T.Type, at path: [CodingKey]) throws -> T {
        switch type {
        case is Date.Type:
            return try unboxDate(value, at: path) as! T
        case is Data.Type:
            return try unboxData(value, at: path) as! T
        case is URL.Type:
            guard case .string(let text) = value, let url = URL(string: text) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: path, debugDescription: "Invalid URL string."))
            }
            return url as! T
        default:
            let nested = _JSONDecoder(value: value, options: options, codingPath: path)
            return try T(from: nested)
        }
    }

    private func unboxDate(_ value: JSONValue, at path: [CodingKey]) throws -> Date {
        switch options.dateStrategy {
        case .deferredToDate:
            let nested = _JSONDecoder(value: value, options: options, codingPath: path)
            return try Date(from: nested)
        case .secondsSince1970:
            return Date(timeIntervalSince1970: try double(value, at: path))
        case .millisecondsSince1970:
            return Date(timeIntervalSince1970: try double(value, at: path) / 1000)
        case .iso8601:
            guard case .string(let text) = value, let date = JSONDateFormats.iso8601.date(from: text) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: path, debugDescription: "Expected an ISO-8601 date string."))
            }
            return date
        case .formatted(let formatter):
            guard case .string(let text) = value, let date = formatter.date(from: text) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: path, debugDescription: "Date string did not match the formatter."))
            }
            return date
        case .custom(let decode):
            let nested = _JSONDecoder(value: value, options: options, codingPath: path)
            return try decode(nested)
        }
    }

    private func unboxData(_ value: JSONValue, at path: [CodingKey]) throws -> Data {
        switch options.dataStrategy {
        case .base64:
            guard case .string(let text) = value, let data = Data(base64Encoded: text) else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: path, debugDescription: "Expected a base64-encoded string."))
            }
            return data
        case .deferredToData:
            // Inverse of the encoder's `.deferredToData`: read the byte array.
            let nested = _JSONDecoder(value: value, options: options, codingPath: path)
            return Data(try [UInt8](from: nested))
        case .custom(let decode):
            let nested = _JSONDecoder(value: value, options: options, codingPath: path)
            return try decode(nested)
        }
    }

    private func double(_ value: JSONValue, at path: [CodingKey]) throws -> Double {
        guard case .number(let text) = value, let number = Double(text) else {
            throw DecodingError.typeMismatch(Double.self, DecodingError.Context(
                codingPath: path, debugDescription: "Expected a number."))
        }
        return number
    }
}

// MARK: - Numeric unboxing shared by the containers

private enum JSONNumberDecode {
    static func fixedWidth<T: FixedWidthInteger>(_ value: JSONValue, as type: T.Type, path: [CodingKey]) throws -> T {
        guard case .number(let text) = value else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(
                codingPath: path, debugDescription: "Expected an integer."))
        }
        if let exact = T(text) {
            return exact
        }
        // A whole-valued double literal (e.g. "5" arriving as "5.0") still fits.
        if let asDouble = Double(text), asDouble == asDouble.rounded(), let exact = T(exactly: asDouble) {
            return exact
        }
        throw DecodingError.dataCorrupted(DecodingError.Context(
            codingPath: path, debugDescription: "Number \(text) does not fit \(type)."))
    }

    static func floating<T: BinaryFloatingPoint>(_ value: JSONValue, as type: T.Type, path: [CodingKey]) throws -> T {
        guard case .number(let text) = value, let number = Double(text) else {
            throw DecodingError.typeMismatch(type, DecodingError.Context(
                codingPath: path, debugDescription: "Expected a floating-point number."))
        }
        return T(number)
    }
}

// MARK: - Keyed container

private struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
    let decoder: _JSONDecoder
    let values: [String: JSONValue]
    var codingPath: [CodingKey]

    var allKeys: [Key] { values.keys.compactMap { Key(stringValue: $0) } }

    func contains(_ key: Key) -> Bool { values[key.stringValue] != nil }

    private func value(for key: Key) throws -> JSONValue {
        guard let value = values[key.stringValue] else {
            throw DecodingError.keyNotFound(key, DecodingError.Context(
                codingPath: codingPath, debugDescription: "No value for key '\(key.stringValue)'."))
        }
        return value
    }

    func decodeNil(forKey key: Key) throws -> Bool {
        guard let value = values[key.stringValue] else { return true }
        if case .null = value { return true }
        return false
    }

    func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
        guard case .bool(let flag) = try value(for: key) else {
            throw typeMismatch(type, key)
        }
        return flag
    }

    func decode(_ type: String.Type, forKey key: Key) throws -> String {
        guard case .string(let text) = try value(for: key) else {
            throw typeMismatch(type, key)
        }
        return text
    }

    func decode(_ type: Double.Type, forKey key: Key) throws -> Double { try JSONNumberDecode.floating(try value(for: key), as: type, path: codingPath + [key]) }
    func decode(_ type: Float.Type, forKey key: Key) throws -> Float { try JSONNumberDecode.floating(try value(for: key), as: type, path: codingPath + [key]) }
    func decode(_ type: Int.Type, forKey key: Key) throws -> Int { try JSONNumberDecode.fixedWidth(try value(for: key), as: type, path: codingPath + [key]) }
    func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 { try JSONNumberDecode.fixedWidth(try value(for: key), as: type, path: codingPath + [key]) }
    func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 { try JSONNumberDecode.fixedWidth(try value(for: key), as: type, path: codingPath + [key]) }
    func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 { try JSONNumberDecode.fixedWidth(try value(for: key), as: type, path: codingPath + [key]) }
    func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 { try JSONNumberDecode.fixedWidth(try value(for: key), as: type, path: codingPath + [key]) }
    func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt { try JSONNumberDecode.fixedWidth(try value(for: key), as: type, path: codingPath + [key]) }
    func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 { try JSONNumberDecode.fixedWidth(try value(for: key), as: type, path: codingPath + [key]) }
    func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 { try JSONNumberDecode.fixedWidth(try value(for: key), as: type, path: codingPath + [key]) }
    func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 { try JSONNumberDecode.fixedWidth(try value(for: key), as: type, path: codingPath + [key]) }
    func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 { try JSONNumberDecode.fixedWidth(try value(for: key), as: type, path: codingPath + [key]) }

    func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
        try decoder.unbox(try value(for: key), as: type, at: codingPath + [key])
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
        let nested = _JSONDecoder(value: try value(for: key), options: decoder.options, codingPath: codingPath + [key])
        return try nested.container(keyedBy: type)
    }

    func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
        let nested = _JSONDecoder(value: try value(for: key), options: decoder.options, codingPath: codingPath + [key])
        return try nested.unkeyedContainer()
    }

    func superDecoder() throws -> Decoder { try superDecoder(forKey: Key(stringValue: "super")!) }

    func superDecoder(forKey key: Key) throws -> Decoder {
        _JSONDecoder(value: values[key.stringValue] ?? .null, options: decoder.options, codingPath: codingPath + [key])
    }

    private func typeMismatch(_ type: Any.Type, _ key: Key) -> DecodingError {
        DecodingError.typeMismatch(type, DecodingError.Context(
            codingPath: codingPath + [key], debugDescription: "Wrong type for key '\(key.stringValue)'."))
    }
}

// MARK: - Unkeyed container

private final class UnkeyedContainer: UnkeyedDecodingContainer {
    let decoder: _JSONDecoder
    let elements: [JSONValue]
    var codingPath: [CodingKey]
    var currentIndex = 0

    init(decoder: _JSONDecoder, elements: [JSONValue], codingPath: [CodingKey]) {
        self.decoder = decoder
        self.elements = elements
        self.codingPath = codingPath
    }

    var count: Int? { elements.count }
    var isAtEnd: Bool { currentIndex >= elements.count }

    private func next() throws -> JSONValue {
        guard !isAtEnd else {
            throw DecodingError.valueNotFound(JSONValue.self, DecodingError.Context(
                codingPath: codingPath, debugDescription: "Unkeyed container is at end."))
        }
        let value = elements[currentIndex]
        currentIndex += 1
        return value
    }

    func decodeNil() throws -> Bool {
        guard !isAtEnd else { return false }
        if case .null = elements[currentIndex] {
            currentIndex += 1
            return true
        }
        return false
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        guard case .bool(let flag) = try next() else { throw mismatch(type) }
        return flag
    }

    func decode(_ type: String.Type) throws -> String {
        guard case .string(let text) = try next() else { throw mismatch(type) }
        return text
    }

    func decode(_ type: Double.Type) throws -> Double { try JSONNumberDecode.floating(try next(), as: type, path: codingPath) }
    func decode(_ type: Float.Type) throws -> Float { try JSONNumberDecode.floating(try next(), as: type, path: codingPath) }
    func decode(_ type: Int.Type) throws -> Int { try JSONNumberDecode.fixedWidth(try next(), as: type, path: codingPath) }
    func decode(_ type: Int8.Type) throws -> Int8 { try JSONNumberDecode.fixedWidth(try next(), as: type, path: codingPath) }
    func decode(_ type: Int16.Type) throws -> Int16 { try JSONNumberDecode.fixedWidth(try next(), as: type, path: codingPath) }
    func decode(_ type: Int32.Type) throws -> Int32 { try JSONNumberDecode.fixedWidth(try next(), as: type, path: codingPath) }
    func decode(_ type: Int64.Type) throws -> Int64 { try JSONNumberDecode.fixedWidth(try next(), as: type, path: codingPath) }
    func decode(_ type: UInt.Type) throws -> UInt { try JSONNumberDecode.fixedWidth(try next(), as: type, path: codingPath) }
    func decode(_ type: UInt8.Type) throws -> UInt8 { try JSONNumberDecode.fixedWidth(try next(), as: type, path: codingPath) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { try JSONNumberDecode.fixedWidth(try next(), as: type, path: codingPath) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { try JSONNumberDecode.fixedWidth(try next(), as: type, path: codingPath) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { try JSONNumberDecode.fixedWidth(try next(), as: type, path: codingPath) }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try decoder.unbox(try next(), as: type, at: codingPath)
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
        let nested = _JSONDecoder(value: try next(), options: decoder.options, codingPath: codingPath)
        return try nested.container(keyedBy: type)
    }

    func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
        let nested = _JSONDecoder(value: try next(), options: decoder.options, codingPath: codingPath)
        return try nested.unkeyedContainer()
    }

    func superDecoder() throws -> Decoder {
        _JSONDecoder(value: try next(), options: decoder.options, codingPath: codingPath)
    }

    private func mismatch(_ type: Any.Type) -> DecodingError {
        DecodingError.typeMismatch(type, DecodingError.Context(
            codingPath: codingPath, debugDescription: "Wrong element type in array."))
    }
}

// MARK: - Single-value container

private struct SingleValueContainer: SingleValueDecodingContainer {
    let decoder: _JSONDecoder
    let value: JSONValue
    var codingPath: [CodingKey]

    func decodeNil() -> Bool {
        if case .null = value { return true }
        return false
    }

    func decode(_ type: Bool.Type) throws -> Bool {
        guard case .bool(let flag) = value else { throw mismatch(type) }
        return flag
    }

    func decode(_ type: String.Type) throws -> String {
        guard case .string(let text) = value else { throw mismatch(type) }
        return text
    }

    func decode(_ type: Double.Type) throws -> Double { try JSONNumberDecode.floating(value, as: type, path: codingPath) }
    func decode(_ type: Float.Type) throws -> Float { try JSONNumberDecode.floating(value, as: type, path: codingPath) }
    func decode(_ type: Int.Type) throws -> Int { try JSONNumberDecode.fixedWidth(value, as: type, path: codingPath) }
    func decode(_ type: Int8.Type) throws -> Int8 { try JSONNumberDecode.fixedWidth(value, as: type, path: codingPath) }
    func decode(_ type: Int16.Type) throws -> Int16 { try JSONNumberDecode.fixedWidth(value, as: type, path: codingPath) }
    func decode(_ type: Int32.Type) throws -> Int32 { try JSONNumberDecode.fixedWidth(value, as: type, path: codingPath) }
    func decode(_ type: Int64.Type) throws -> Int64 { try JSONNumberDecode.fixedWidth(value, as: type, path: codingPath) }
    func decode(_ type: UInt.Type) throws -> UInt { try JSONNumberDecode.fixedWidth(value, as: type, path: codingPath) }
    func decode(_ type: UInt8.Type) throws -> UInt8 { try JSONNumberDecode.fixedWidth(value, as: type, path: codingPath) }
    func decode(_ type: UInt16.Type) throws -> UInt16 { try JSONNumberDecode.fixedWidth(value, as: type, path: codingPath) }
    func decode(_ type: UInt32.Type) throws -> UInt32 { try JSONNumberDecode.fixedWidth(value, as: type, path: codingPath) }
    func decode(_ type: UInt64.Type) throws -> UInt64 { try JSONNumberDecode.fixedWidth(value, as: type, path: codingPath) }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try decoder.unbox(value, as: type, at: codingPath)
    }

    private func mismatch(_ type: Any.Type) -> DecodingError {
        DecodingError.typeMismatch(type, DecodingError.Context(
            codingPath: codingPath, debugDescription: "Wrong single value type."))
    }
}

private extension JSONValue {
    func describeType() -> String {
        switch self {
        case .null: return "null"
        case .bool: return "a boolean"
        case .number: return "a number"
        case .string: return "a string"
        case .array: return "an array"
        case .object: return "an object"
        }
    }
}
