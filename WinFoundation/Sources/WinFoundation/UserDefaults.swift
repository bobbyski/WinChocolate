/// A Foundation-compatible defaults store.
///
/// `UserDefaults.standard` persists to a JSON file under the user's roaming
/// AppData (`<Application Support>/<executable name>/defaults.json`), giving
/// WinChocolate apps the Mac behavior — set a value, relaunch, read it back —
/// without real Foundation. Supported value types are the property-list
/// subset: `String`, `Int`, `Double`, `Bool`, arrays of those, and
/// string-keyed dictionaries of those (nested freely).
open class UserDefaults {
    /// The shared defaults store for the running app.
    nonisolated(unsafe) public static let standard = UserDefaults()

    private var storage: [String: Any] = [:]
    private var registrationDomain: [String: Any] = [:]
    private let persistsToDisk: Bool

    /// Creates the standard on-disk store.
    public convenience init() {
        self.init(persistsToDisk: true)
        load()
    }

    /// Creates an in-memory store (used by tests via `UserDefaults(suiteName:)`
    /// with a nil-like sentinel; the standard store persists).
    public init(persistsToDisk: Bool) {
        self.persistsToDisk = persistsToDisk
    }

    // MARK: - Reading

    /// Returns the value for a key from the store, else the registration domain.
    open func object(forKey defaultName: String) -> Any? {
        storage[defaultName] ?? registrationDomain[defaultName]
    }

    /// Returns the string value for a key.
    open func string(forKey defaultName: String) -> String? {
        object(forKey: defaultName) as? String
    }

    /// Returns the array value for a key.
    open func array(forKey defaultName: String) -> [Any]? {
        object(forKey: defaultName) as? [Any]
    }

    /// Returns the string-array value for a key.
    open func stringArray(forKey defaultName: String) -> [String]? {
        (object(forKey: defaultName) as? [Any])?.compactMap { $0 as? String }
    }

    /// Returns the dictionary value for a key.
    open func dictionary(forKey defaultName: String) -> [String: Any]? {
        object(forKey: defaultName) as? [String: Any]
    }

    /// Returns the boolean value for a key (`false` when absent).
    open func bool(forKey defaultName: String) -> Bool {
        (object(forKey: defaultName) as? Bool)
            ?? (object(forKey: defaultName) as? Int).map { $0 != 0 }
            ?? false
    }

    /// Returns the integer value for a key (`0` when absent).
    open func integer(forKey defaultName: String) -> Int {
        (object(forKey: defaultName) as? Int)
            ?? (object(forKey: defaultName) as? Double).map(Int.init)
            ?? 0
    }

    /// Returns the double value for a key (`0` when absent).
    open func double(forKey defaultName: String) -> Double {
        (object(forKey: defaultName) as? Double)
            ?? (object(forKey: defaultName) as? Int).map(Double.init)
            ?? 0
    }

    // MARK: - Writing

    /// Stores a property-list value for a key (nil removes it) and persists.
    open func set(_ value: Any?, forKey defaultName: String) {
        if let value {
            storage[defaultName] = value
        } else {
            storage.removeValue(forKey: defaultName)
        }
        persist()
    }

    /// Stores a boolean for a key.
    open func set(_ value: Bool, forKey defaultName: String) {
        set(value as Any, forKey: defaultName)
    }

    /// Stores an integer for a key.
    open func set(_ value: Int, forKey defaultName: String) {
        set(value as Any, forKey: defaultName)
    }

    /// Stores a double for a key.
    open func set(_ value: Double, forKey defaultName: String) {
        set(value as Any, forKey: defaultName)
    }

    /// Removes the value for a key.
    open func removeObject(forKey defaultName: String) {
        storage.removeValue(forKey: defaultName)
        persist()
    }

    /// Adds fallback values consulted when the store has no explicit value,
    /// matching Foundation's registration domain (not persisted).
    open func register(defaults registrationDictionary: [String: Any]) {
        registrationDomain.merge(registrationDictionary) { _, new in new }
    }

    /// Writes pending changes to disk. Writes are already synchronous; this
    /// exists for source compatibility.
    @discardableResult
    open func synchronize() -> Bool {
        persist()
        return true
    }

    // MARK: - Persistence

    private var storeURL: URL? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let executable = CommandLine.arguments.first
            .map { path -> String in
                let name = path.split(separator: "\\").last.map(String.init) ?? path
                return name.hasSuffix(".exe") ? String(name.dropLast(4)) : name
            } ?? "WinChocolateApp"
        return support.appendingPathComponent(executable).appendingPathComponent("defaults.json")
    }

    private func load() {
        guard persistsToDisk, let url = storeURL,
              let data = try? Data(contentsOf: url),
              let parsed = WinJSON.parse(String(decoding: data, as: UTF8.self)) as? [String: Any] else {
            return
        }
        storage = parsed
    }

    private func persist() {
        guard persistsToDisk, let url = storeURL else {
            return
        }
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(atPath: directory.path, withIntermediateDirectories: true)
        let text = WinJSON.serialize(storage)
        try? Data(Array(text.utf8)).write(to: url)
    }
}

/// A minimal JSON reader/writer for the property-list subset `UserDefaults`
/// stores: strings, integers, doubles, booleans, arrays, and string-keyed
/// dictionaries. Not a general JSON library — just enough to round-trip the
/// defaults file.
enum WinJSON {
    // MARK: - Writing

    static func serialize(_ value: Any) -> String {
        switch value {
        case let string as String:
            return quote(string)
        case let bool as Bool:
            return bool ? "true" : "false"
        case let integer as Int:
            return String(integer)
        case let double as Double:
            return double == double.rounded() && abs(double) < 1e15
                ? String(Int(double)) + ".0"
                : String(double)
        case let array as [Any]:
            return "[" + array.map(serialize).joined(separator: ",") + "]"
        case let dictionary as [String: Any]:
            let body = dictionary
                .sorted { $0.key < $1.key }
                .map { quote($0.key) + ":" + serialize($0.value) }
                .joined(separator: ",")
            return "{" + body + "}"
        default:
            return "null"
        }
    }

    private static func quote(_ string: String) -> String {
        var result = "\""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            default:
                if scalar.value < 0x20 {
                    let hex = String(scalar.value, radix: 16)
                    result += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
                } else {
                    result.unicodeScalars.append(scalar)
                }
            }
        }
        return result + "\""
    }

    // MARK: - Reading

    static func parse(_ text: String) -> Any? {
        var scanner = Scanner(text: Array(text.unicodeScalars))
        let value = scanner.parseValue()
        scanner.skipWhitespace()
        return scanner.isAtEnd ? value : nil
    }

    private struct Scanner {
        let text: [Unicode.Scalar]
        var index = 0

        init(text: [Unicode.Scalar]) {
            self.text = text
        }

        var isAtEnd: Bool {
            index >= text.count
        }

        mutating func skipWhitespace() {
            while index < text.count, text[index] == " " || text[index] == "\n" || text[index] == "\r" || text[index] == "\t" {
                index += 1
            }
        }

        mutating func parseValue() -> Any? {
            skipWhitespace()
            guard index < text.count else {
                return nil
            }
            switch text[index] {
            case "{":
                return parseObject()
            case "[":
                return parseArray()
            case "\"":
                return parseString()
            case "t":
                return consume("true") ? true : nil
            case "f":
                return consume("false") ? false : nil
            case "n":
                return consume("null") ? nil : nil
            default:
                return parseNumber()
            }
        }

        mutating func consume(_ word: String) -> Bool {
            let scalars = Array(word.unicodeScalars)
            guard index + scalars.count <= text.count,
                  Array(text[index..<index + scalars.count]) == scalars else {
                return false
            }
            index += scalars.count
            return true
        }

        mutating func parseObject() -> [String: Any]? {
            index += 1  // {
            var result: [String: Any] = [:]
            skipWhitespace()
            if index < text.count, text[index] == "}" {
                index += 1
                return result
            }
            while index < text.count {
                skipWhitespace()
                guard let key = parseString() else {
                    return nil
                }
                skipWhitespace()
                guard index < text.count, text[index] == ":" else {
                    return nil
                }
                index += 1
                guard let value = parseValue() else {
                    // A JSON null drops the key (the plist subset has no null).
                    skipWhitespace()
                    if index < text.count, text[index] == "," {
                        index += 1
                        continue
                    }
                    if index < text.count, text[index] == "}" {
                        index += 1
                        return result
                    }
                    return nil
                }
                result[key] = value
                skipWhitespace()
                if index < text.count, text[index] == "," {
                    index += 1
                    continue
                }
                if index < text.count, text[index] == "}" {
                    index += 1
                    return result
                }
                return nil
            }
            return nil
        }

        mutating func parseArray() -> [Any]? {
            index += 1  // [
            var result: [Any] = []
            skipWhitespace()
            if index < text.count, text[index] == "]" {
                index += 1
                return result
            }
            while index < text.count {
                guard let value = parseValue() else {
                    return nil
                }
                result.append(value)
                skipWhitespace()
                if index < text.count, text[index] == "," {
                    index += 1
                    continue
                }
                if index < text.count, text[index] == "]" {
                    index += 1
                    return result
                }
                return nil
            }
            return nil
        }

        mutating func parseString() -> String? {
            guard index < text.count, text[index] == "\"" else {
                return nil
            }
            index += 1
            var result = String.UnicodeScalarView()
            while index < text.count {
                let scalar = text[index]
                if scalar == "\"" {
                    index += 1
                    return String(result)
                }
                if scalar == "\\", index + 1 < text.count {
                    index += 1
                    switch text[index] {
                    case "\"": result.append("\"")
                    case "\\": result.append("\\")
                    case "/": result.append("/")
                    case "n": result.append("\n")
                    case "r": result.append("\r")
                    case "t": result.append("\t")
                    case "u":
                        guard index + 4 < text.count else {
                            return nil
                        }
                        let hex = String(String.UnicodeScalarView(text[index + 1...index + 4]))
                        guard let value = UInt32(hex, radix: 16), let unicode = Unicode.Scalar(value) else {
                            return nil
                        }
                        result.append(unicode)
                        index += 4
                    default:
                        return nil
                    }
                    index += 1
                    continue
                }
                result.append(scalar)
                index += 1
            }
            return nil
        }

        mutating func parseNumber() -> Any? {
            var literal = ""
            var isDouble = false
            while index < text.count {
                let scalar = text[index]
                if scalar == "-" || scalar == "+" || ("0"..."9").contains(String(scalar)) {
                    literal.unicodeScalars.append(scalar)
                } else if scalar == "." || scalar == "e" || scalar == "E" {
                    isDouble = true
                    literal.unicodeScalars.append(scalar)
                } else {
                    break
                }
                index += 1
            }
            if isDouble {
                return Double(literal)
            }
            return Int(literal) ?? Double(literal)
        }
    }
}
