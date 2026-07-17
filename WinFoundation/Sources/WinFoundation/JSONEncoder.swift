/// A Foundation-compatible JSON encoder.
///
/// Real Foundation's `JSONEncoder` lives in Foundation, not the standard
/// library — but the machinery it drives (`Encodable`, `Encoder`, the keyed /
/// unkeyed / single-value container protocols, `CodingKey`, `EncodingError`)
/// is all standard-library, so this rebuilds the encoder on top of it. The
/// goal is **byte-for-byte** parity with Apple's defaults so a model encoded on
/// a WinFoundation build round-trips with one encoded on a real-Foundation Mac:
///
/// - `Date` → seconds since the 2001 reference date, as a bare JSON number
///   (Apple's `.deferredToDate` default; `Date`'s own `Codable` already does
///   exactly this).
/// - `Data` → a base64 string (Apple's `.base64` default), **not** deferred to
///   `Data`'s array-of-bytes `Codable`.
/// - Keys unchanged, compact output, in declaration order.
public final class JSONEncoder {

    /// Formatting options for the produced JSON.
    public struct OutputFormatting: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }

        /// Insert newlines and indentation for readability.
        public static let prettyPrinted = OutputFormatting(rawValue: 1 << 0)
        /// Emit object keys in sorted order (stable output).
        public static let sortedKeys = OutputFormatting(rawValue: 1 << 1)
        /// Leave forward slashes unescaped (`/` instead of `\/`).
        public static let withoutEscapingSlashes = OutputFormatting(rawValue: 1 << 2)
    }

    /// How `Date` values are written.
    public enum DateEncodingStrategy {
        /// `Date`'s own `Codable` — seconds since 2001, a bare number. Default.
        case deferredToDate
        /// Seconds since 1970 as a number.
        case secondsSince1970
        /// Milliseconds since 1970 as a number.
        case millisecondsSince1970
        /// An ISO-8601 string.
        case iso8601
        /// A string from the given formatter.
        case formatted(DateFormatter)
        /// A caller-provided encoding.
        case custom((Date, Encoder) throws -> Void)
    }

    /// How `Data` values are written.
    public enum DataEncodingStrategy {
        /// `Data`'s own `Codable` — an array of byte numbers.
        case deferredToData
        /// A base64 string. Default.
        case base64
        /// A caller-provided encoding.
        case custom((Data, Encoder) throws -> Void)
    }

    /// How coding keys are transformed on the way out.
    public enum KeyEncodingStrategy {
        /// Keys unchanged. Default.
        case useDefaultKeys
        /// `camelCase` → `snake_case`, matching Foundation's algorithm.
        case convertToSnakeCase
        /// A caller-provided transform of the coding path.
        case custom(([CodingKey]) -> CodingKey)
    }

    public var outputFormatting: OutputFormatting = []
    public var dateEncodingStrategy: DateEncodingStrategy = .deferredToDate
    public var dataEncodingStrategy: DataEncodingStrategy = .base64
    public var keyEncodingStrategy: KeyEncodingStrategy = .useDefaultKeys
    public var userInfo: [CodingUserInfoKey: Any] = [:]

    public init() {}

    /// Encodes a value to UTF-8 JSON bytes.
    public func encode<T: Encodable>(_ value: T) throws -> Data {
        let options = Options(
            dateStrategy: dateEncodingStrategy,
            dataStrategy: dataEncodingStrategy,
            keyStrategy: keyEncodingStrategy,
            userInfo: userInfo
        )
        let encoder = _JSONEncoder(options: options, codingPath: [])
        try value.encode(to: encoder)
        guard let top = encoder.storage.value else {
            throw EncodingError.invalidValue(value, EncodingError.Context(
                codingPath: [],
                debugDescription: "Top-level \(T.self) did not encode any value."))
        }
        var writer = JSONWriter(formatting: outputFormatting)
        writer.write(top)
        return Data(writer.utf8)
    }

    /// The resolved strategies threaded through the encoding tree.
    struct Options {
        let dateStrategy: DateEncodingStrategy
        let dataStrategy: DataEncodingStrategy
        let keyStrategy: KeyEncodingStrategy
        let userInfo: [CodingUserInfoKey: Any]
    }
}

// MARK: - Intermediate value tree

/// A parsed/pending JSON value. Numbers keep their already-formatted text so
/// the integer/double distinction and full precision survive to serialization.
enum JSONValue {
    case null
    case bool(Bool)
    case number(String)
    case string(String)
    case array([JSONValue])
    case object([(String, JSONValue)])
}

// MARK: - Encoder core

private final class _JSONEncoder: Encoder {
    let options: JSONEncoder.Options
    var codingPath: [CodingKey]
    var userInfo: [CodingUserInfoKey: Any] { options.userInfo }
    let storage = Storage()

    init(options: JSONEncoder.Options, codingPath: [CodingKey]) {
        self.options = options
        self.codingPath = codingPath
    }

    /// Holds the single value this encoder produced, notifying a parent (for
    /// the super-encoder case) whenever it changes.
    final class Storage {
        var value: JSONValue? {
            didSet {
                if let value {
                    onChange?(value)
                }
            }
        }
        /// Set by a parent container when this encoder is a super-encoder, so
        /// the value it eventually produces is spliced into the parent.
        var onChange: ((JSONValue) -> Void)? {
            didSet {
                if let value {
                    onChange?(value)
                }
            }
        }
    }

    /// Forwards a parent's splice-in hook to the storage.
    var onChange: ((JSONValue) -> Void)? {
        get { storage.onChange }
        set { storage.onChange = newValue }
    }

    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        let container = KeyedContainer<Key>(encoder: self, codingPath: codingPath)
        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        UnkeyedContainer(encoder: self, codingPath: codingPath)
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        SingleValueContainer(encoder: self, codingPath: codingPath)
    }

    /// Applies the key strategy to a coding key's string.
    func encodedKey(_ key: CodingKey) -> String {
        switch options.keyStrategy {
        case .useDefaultKeys:
            return key.stringValue
        case .convertToSnakeCase:
            return JSONKeyTransform.toSnakeCase(key.stringValue)
        case .custom(let transform):
            return transform(codingPath + [key]).stringValue
        }
    }

    /// Boxes an arbitrary `Encodable`, intercepting the specially-handled types
    /// (`Date`, `Data`, `URL`) exactly as Foundation's encoder does.
    func box(_ value: Encodable, at path: [CodingKey]) throws -> JSONValue {
        switch value {
        case let date as Date:
            return try boxDate(date, at: path)
        case let data as Data:
            return try boxData(data, at: path)
        case let url as URL:
            return .string(url.absoluteString)
        default:
            let nested = _JSONEncoder(options: options, codingPath: path)
            try value.encode(to: nested)
            return nested.storage.value ?? .object([])
        }
    }

    private func boxDate(_ date: Date, at path: [CodingKey]) throws -> JSONValue {
        switch options.dateStrategy {
        case .deferredToDate:
            let nested = _JSONEncoder(options: options, codingPath: path)
            try date.encode(to: nested)
            return nested.storage.value ?? .null
        case .secondsSince1970:
            return .number(JSONNumber.string(from: date.timeIntervalSince1970))
        case .millisecondsSince1970:
            return .number(JSONNumber.string(from: date.timeIntervalSince1970 * 1000))
        case .iso8601:
            return .string(JSONDateFormats.iso8601.string(from: date))
        case .formatted(let formatter):
            return .string(formatter.string(from: date))
        case .custom(let encode):
            let nested = _JSONEncoder(options: options, codingPath: path)
            try encode(date, nested)
            return nested.storage.value ?? .null
        }
    }

    private func boxData(_ data: Data, at path: [CodingKey]) throws -> JSONValue {
        switch options.dataStrategy {
        case .base64:
            return .string(data.base64EncodedString())
        case .deferredToData:
            // WinFoundation's `Data` isn't `Encodable` (Apple's is), so the
            // array-of-bytes form Foundation's `.deferredToData` produces is
            // written explicitly from the bytes.
            let nested = _JSONEncoder(options: options, codingPath: path)
            try Array(data).encode(to: nested)
            return nested.storage.value ?? .null
        case .custom(let encode):
            let nested = _JSONEncoder(options: options, codingPath: path)
            try encode(data, nested)
            return nested.storage.value ?? .null
        }
    }
}

// MARK: - Keyed container

private final class KeyedContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    let encoder: _JSONEncoder
    var codingPath: [CodingKey]
    /// Insertion-ordered pairs so default output preserves declaration order.
    private var pairs: [(String, JSONValue)] = []

    init(encoder: _JSONEncoder, codingPath: [CodingKey]) {
        self.encoder = encoder
        self.codingPath = codingPath
        // A keyed container makes this encoder an object even when empty.
        encoder.storage.value = .object([])
    }

    private func store(_ value: JSONValue, forKey key: Key) {
        pairs.append((encoder.encodedKey(key), value))
        encoder.storage.value = .object(pairs)
    }

    func encodeNil(forKey key: Key) throws { store(.null, forKey: key) }
    func encode(_ value: Bool, forKey key: Key) throws { store(.bool(value), forKey: key) }
    func encode(_ value: String, forKey key: Key) throws { store(.string(value), forKey: key) }
    func encode(_ value: Double, forKey key: Key) throws { store(try number(value, key), forKey: key) }
    func encode(_ value: Float, forKey key: Key) throws { store(try number(Double(value), key), forKey: key) }
    func encode(_ value: Int, forKey key: Key) throws { store(.number(String(value)), forKey: key) }
    func encode(_ value: Int8, forKey key: Key) throws { store(.number(String(value)), forKey: key) }
    func encode(_ value: Int16, forKey key: Key) throws { store(.number(String(value)), forKey: key) }
    func encode(_ value: Int32, forKey key: Key) throws { store(.number(String(value)), forKey: key) }
    func encode(_ value: Int64, forKey key: Key) throws { store(.number(String(value)), forKey: key) }
    func encode(_ value: UInt, forKey key: Key) throws { store(.number(String(value)), forKey: key) }
    func encode(_ value: UInt8, forKey key: Key) throws { store(.number(String(value)), forKey: key) }
    func encode(_ value: UInt16, forKey key: Key) throws { store(.number(String(value)), forKey: key) }
    func encode(_ value: UInt32, forKey key: Key) throws { store(.number(String(value)), forKey: key) }
    func encode(_ value: UInt64, forKey key: Key) throws { store(.number(String(value)), forKey: key) }

    func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
        store(try encoder.box(value, at: codingPath + [key]), forKey: key)
    }

    private func number(_ value: Double, _ key: Key) throws -> JSONValue {
        guard value.isFinite else {
            throw EncodingError.invalidValue(value, EncodingError.Context(
                codingPath: codingPath + [key],
                debugDescription: "Non-finite doubles are not valid JSON."))
        }
        return .number(JSONNumber.string(from: value))
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
        let nested = _JSONEncoder(options: encoder.options, codingPath: codingPath + [key])
        let container = KeyedContainer<NestedKey>(encoder: nested, codingPath: nested.codingPath)
        store(.object([]), forKey: key)
        // Re-point the stored slot at the nested object as it fills.
        let slot = pairs.count - 1
        nested.storage.value = .object([])
        container.onChange = { [weak self] value in
            guard let self else { return }
            self.pairs[slot].1 = value
            self.encoder.storage.value = .object(self.pairs)
        }
        return KeyedEncodingContainer(container)
    }

    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        let nested = _JSONEncoder(options: encoder.options, codingPath: codingPath + [key])
        let container = UnkeyedContainer(encoder: nested, codingPath: nested.codingPath)
        store(.array([]), forKey: key)
        let slot = pairs.count - 1
        container.onChange = { [weak self] value in
            guard let self else { return }
            self.pairs[slot].1 = value
            self.encoder.storage.value = .object(self.pairs)
        }
        return container
    }

    func superEncoder() -> Encoder { superEncoder(forKey: Key(stringValue: "super")!) }

    func superEncoder(forKey key: Key) -> Encoder {
        let nested = _JSONEncoder(options: encoder.options, codingPath: codingPath + [key])
        store(.null, forKey: key)
        let slot = pairs.count - 1
        nested.onChange = { [weak self] value in
            guard let self else { return }
            self.pairs[slot].1 = value
            self.encoder.storage.value = .object(self.pairs)
        }
        return nested
    }

    /// Set by a parent so a nested keyed container reports its growth upward.
    var onChange: ((JSONValue) -> Void)?
}

// MARK: - Unkeyed container

private final class UnkeyedContainer: UnkeyedEncodingContainer {
    let encoder: _JSONEncoder
    var codingPath: [CodingKey]
    private var elements: [JSONValue] = []
    var count: Int { elements.count }
    var onChange: ((JSONValue) -> Void)?

    init(encoder: _JSONEncoder, codingPath: [CodingKey]) {
        self.encoder = encoder
        self.codingPath = codingPath
        encoder.storage.value = .array([])
    }

    private func append(_ value: JSONValue) {
        elements.append(value)
        let array = JSONValue.array(elements)
        encoder.storage.value = array
        onChange?(array)
    }

    func encodeNil() throws { append(.null) }
    func encode(_ value: Bool) throws { append(.bool(value)) }
    func encode(_ value: String) throws { append(.string(value)) }
    func encode(_ value: Double) throws { append(try number(value)) }
    func encode(_ value: Float) throws { append(try number(Double(value))) }
    func encode(_ value: Int) throws { append(.number(String(value))) }
    func encode(_ value: Int8) throws { append(.number(String(value))) }
    func encode(_ value: Int16) throws { append(.number(String(value))) }
    func encode(_ value: Int32) throws { append(.number(String(value))) }
    func encode(_ value: Int64) throws { append(.number(String(value))) }
    func encode(_ value: UInt) throws { append(.number(String(value))) }
    func encode(_ value: UInt8) throws { append(.number(String(value))) }
    func encode(_ value: UInt16) throws { append(.number(String(value))) }
    func encode(_ value: UInt32) throws { append(.number(String(value))) }
    func encode(_ value: UInt64) throws { append(.number(String(value))) }

    func encode<T: Encodable>(_ value: T) throws {
        append(try encoder.box(value, at: codingPath))
    }

    private func number(_ value: Double) throws -> JSONValue {
        guard value.isFinite else {
            throw EncodingError.invalidValue(value, EncodingError.Context(
                codingPath: codingPath,
                debugDescription: "Non-finite doubles are not valid JSON."))
        }
        return .number(JSONNumber.string(from: value))
    }

    func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> {
        let nested = _JSONEncoder(options: encoder.options, codingPath: codingPath)
        let container = KeyedContainer<NestedKey>(encoder: nested, codingPath: nested.codingPath)
        let slot = elements.count
        append(.object([]))
        container.onChange = { [weak self] value in self?.replace(slot, value) }
        return KeyedEncodingContainer(container)
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let nested = _JSONEncoder(options: encoder.options, codingPath: codingPath)
        let container = UnkeyedContainer(encoder: nested, codingPath: nested.codingPath)
        let slot = elements.count
        append(.array([]))
        container.onChange = { [weak self] value in self?.replace(slot, value) }
        return container
    }

    func superEncoder() -> Encoder {
        let nested = _JSONEncoder(options: encoder.options, codingPath: codingPath)
        let slot = elements.count
        append(.null)
        nested.onChange = { [weak self] value in self?.replace(slot, value) }
        return nested
    }

    private func replace(_ index: Int, _ value: JSONValue) {
        elements[index] = value
        let array = JSONValue.array(elements)
        encoder.storage.value = array
        onChange?(array)
    }
}

// MARK: - Single-value container

private struct SingleValueContainer: SingleValueEncodingContainer {
    let encoder: _JSONEncoder
    var codingPath: [CodingKey]

    private func set(_ value: JSONValue) { encoder.storage.value = value }

    func encodeNil() throws { set(.null) }
    func encode(_ value: Bool) throws { set(.bool(value)) }
    func encode(_ value: String) throws { set(.string(value)) }
    func encode(_ value: Double) throws { set(try number(value)) }
    func encode(_ value: Float) throws { set(try number(Double(value))) }
    func encode(_ value: Int) throws { set(.number(String(value))) }
    func encode(_ value: Int8) throws { set(.number(String(value))) }
    func encode(_ value: Int16) throws { set(.number(String(value))) }
    func encode(_ value: Int32) throws { set(.number(String(value))) }
    func encode(_ value: Int64) throws { set(.number(String(value))) }
    func encode(_ value: UInt) throws { set(.number(String(value))) }
    func encode(_ value: UInt8) throws { set(.number(String(value))) }
    func encode(_ value: UInt16) throws { set(.number(String(value))) }
    func encode(_ value: UInt32) throws { set(.number(String(value))) }
    func encode(_ value: UInt64) throws { set(.number(String(value))) }

    func encode<T: Encodable>(_ value: T) throws {
        set(try encoder.box(value, at: codingPath))
    }

    private func number(_ value: Double) throws -> JSONValue {
        guard value.isFinite else {
            throw EncodingError.invalidValue(value, EncodingError.Context(
                codingPath: codingPath,
                debugDescription: "Non-finite doubles are not valid JSON."))
        }
        return .number(JSONNumber.string(from: value))
    }
}

