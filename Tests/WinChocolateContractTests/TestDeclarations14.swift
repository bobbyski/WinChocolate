import WinChocolate

private final class SingleStringEncoder: Encoder {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]
    var captured: String?
    var capturedDouble: Double?

    func singleValueContainer() -> SingleValueEncodingContainer { Container(encoder: self) }
    func unkeyedContainer() -> UnkeyedEncodingContainer { fatalError("unsupported in test coder") }
    func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> { fatalError("unsupported in test coder") }

    struct Container: SingleValueEncodingContainer {
        let encoder: SingleStringEncoder
        var codingPath: [CodingKey] { [] }
        func encodeNil() throws { fatalError("unsupported in test coder") }
        func encode(_ value: String) throws { encoder.captured = value }
        func encode(_ value: Bool) throws { fatalError("unsupported in test coder") }
        func encode(_ value: Double) throws { encoder.capturedDouble = value }
        func encode(_ value: Float) throws { fatalError("unsupported in test coder") }
        func encode(_ value: Int) throws { fatalError("unsupported in test coder") }
        func encode(_ value: Int8) throws { fatalError("unsupported in test coder") }
        func encode(_ value: Int16) throws { fatalError("unsupported in test coder") }
        func encode(_ value: Int32) throws { fatalError("unsupported in test coder") }
        func encode(_ value: Int64) throws { fatalError("unsupported in test coder") }
        func encode(_ value: UInt) throws { fatalError("unsupported in test coder") }
        func encode(_ value: UInt8) throws { fatalError("unsupported in test coder") }
        func encode(_ value: UInt16) throws { fatalError("unsupported in test coder") }
        func encode(_ value: UInt32) throws { fatalError("unsupported in test coder") }
        func encode(_ value: UInt64) throws { fatalError("unsupported in test coder") }
        func encode<T: Encodable>(_ value: T) throws { fatalError("unsupported in test coder") }
    }
}

private final class SingleStringDecoder: Decoder {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]
    let value: String
    init(_ value: String) { self.value = value }

    func singleValueContainer() throws -> SingleValueDecodingContainer { Container(value: value) }
    func unkeyedContainer() throws -> UnkeyedDecodingContainer { fatalError("unsupported in test coder") }
    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> { fatalError("unsupported in test coder") }

    struct Container: SingleValueDecodingContainer {
        let value: String
        var codingPath: [CodingKey] { [] }
        func decodeNil() -> Bool { false }
        func decode(_ type: String.Type) throws -> String { value }
        func decode(_ type: Bool.Type) throws -> Bool { fatalError("unsupported in test coder") }
        func decode(_ type: Double.Type) throws -> Double { fatalError("unsupported in test coder") }
        func decode(_ type: Float.Type) throws -> Float { fatalError("unsupported in test coder") }
        func decode(_ type: Int.Type) throws -> Int { fatalError("unsupported in test coder") }
        func decode(_ type: Int8.Type) throws -> Int8 { fatalError("unsupported in test coder") }
        func decode(_ type: Int16.Type) throws -> Int16 { fatalError("unsupported in test coder") }
        func decode(_ type: Int32.Type) throws -> Int32 { fatalError("unsupported in test coder") }
        func decode(_ type: Int64.Type) throws -> Int64 { fatalError("unsupported in test coder") }
        func decode(_ type: UInt.Type) throws -> UInt { fatalError("unsupported in test coder") }
        func decode(_ type: UInt8.Type) throws -> UInt8 { fatalError("unsupported in test coder") }
        func decode(_ type: UInt16.Type) throws -> UInt16 { fatalError("unsupported in test coder") }
        func decode(_ type: UInt32.Type) throws -> UInt32 { fatalError("unsupported in test coder") }
        func decode(_ type: UInt64.Type) throws -> UInt64 { fatalError("unsupported in test coder") }
        func decode<T: Decodable>(_ type: T.Type) throws -> T { fatalError("unsupported in test coder") }
    }
}

private final class SingleDoubleDecoder: Decoder {
    var codingPath: [CodingKey] = []
    var userInfo: [CodingUserInfoKey: Any] = [:]
    let value: Double
    init(_ value: Double) { self.value = value }

    func singleValueContainer() throws -> SingleValueDecodingContainer { Container(value: value) }
    func unkeyedContainer() throws -> UnkeyedDecodingContainer { fatalError("unsupported in test coder") }
    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> { fatalError("unsupported in test coder") }

    struct Container: SingleValueDecodingContainer {
        let value: Double
        var codingPath: [CodingKey] { [] }
        func decodeNil() -> Bool { false }
        func decode(_ type: Double.Type) throws -> Double { value }
        func decode(_ type: String.Type) throws -> String { fatalError("unsupported in test coder") }
        func decode(_ type: Bool.Type) throws -> Bool { fatalError("unsupported in test coder") }
        func decode(_ type: Float.Type) throws -> Float { fatalError("unsupported in test coder") }
        func decode(_ type: Int.Type) throws -> Int { fatalError("unsupported in test coder") }
        func decode(_ type: Int8.Type) throws -> Int8 { fatalError("unsupported in test coder") }
        func decode(_ type: Int16.Type) throws -> Int16 { fatalError("unsupported in test coder") }
        func decode(_ type: Int32.Type) throws -> Int32 { fatalError("unsupported in test coder") }
        func decode(_ type: Int64.Type) throws -> Int64 { fatalError("unsupported in test coder") }
        func decode(_ type: UInt.Type) throws -> UInt { fatalError("unsupported in test coder") }
        func decode(_ type: UInt8.Type) throws -> UInt8 { fatalError("unsupported in test coder") }
        func decode(_ type: UInt16.Type) throws -> UInt16 { fatalError("unsupported in test coder") }
        func decode(_ type: UInt32.Type) throws -> UInt32 { fatalError("unsupported in test coder") }
        func decode(_ type: UInt64.Type) throws -> UInt64 { fatalError("unsupported in test coder") }
        func decode<T: Decodable>(_ type: T.Type) throws -> T { fatalError("unsupported in test coder") }
    }
}

@MainActor
func testWinFoundationCoreTypeGapsClosed() {
    #if os(Windows)
    // Date: distant constants, arithmetic operators, and Codable (encodes as
    // its seconds-since-reference-date, matching Foundation).
    expect(Date.distantPast < Date.distantFuture, "Date.distantPast should precede distantFuture.")
    expect(Date.distantPast < Date(), "Date.distantPast should precede now.")
    let base = Date(timeIntervalSinceReferenceDate: 100)
    expect((base + 10).timeIntervalSinceReferenceDate == 110, "Date + TimeInterval failed.")
    expect((base - 10).timeIntervalSinceReferenceDate == 90, "Date - TimeInterval failed.")
    expect((base - Date(timeIntervalSinceReferenceDate: 60)) == 40, "Date - Date should give the interval.")
    var moving = base
    moving += 5
    moving -= 2
    expect(moving.timeIntervalSinceReferenceDate == 103, "Date += / -= failed.")

    let dateEncoder = SingleStringEncoder()
    requireNoThrow({ try base.encode(to: dateEncoder) }, "Date encoding should succeed")
    expect(dateEncoder.capturedDouble == 100, "Date should encode as its seconds-since-reference-date.")
    let dateDecoded = requireNoThrow({ try Date(from: SingleDoubleDecoder(100)) }, "Date decoding should succeed")
    expect(dateDecoded == base, "Date did not round-trip through Codable.")

    // Data: Base64 round-trip + a known RFC 4648 vector.
    let bytes = Data([0x57, 0x69, 0x6E, 0x43, 0x68, 0x6F, 0x63, 0x6F, 0x6C, 0x61, 0x74, 0x65]) // "WinChocolate"
    expect(bytes.base64EncodedString() == "V2luQ2hvY29sYXRl", "Data.base64EncodedString produced the wrong string.")
    expect(Data(base64Encoded: "V2luQ2hvY29sYXRl")?.array == bytes.array, "Data(base64Encoded:) did not round-trip.")
    // Padding cases (0/1/2 trailing bytes).
    expect(Data([1]).base64EncodedString() == "AQ==", "Base64 single-byte padding wrong.")
    expect(Data([1, 2]).base64EncodedString() == "AQI=", "Base64 two-byte padding wrong.")
    expect(Data(base64Encoded: "AQI=")?.array == [1, 2], "Base64 decode of padded input wrong.")
    expect(Data(base64Encoded: "not valid @@@") == nil, "Invalid Base64 should return nil.")

    // IndexPath: lexicographic Comparable ordering.
    expect(IndexPath(indexes: [0, 5]) < IndexPath(indexes: [1, 0]), "IndexPath ordering by first component failed.")
    expect(IndexPath(indexes: [1, 2]) < IndexPath(indexes: [1, 3]), "IndexPath ordering by second component failed.")
    expect(IndexPath(indexes: [1]) < IndexPath(indexes: [1, 0]), "A prefix IndexPath should sort before its extension.")
    let sortedPaths = [IndexPath(indexes: [1, 0]), IndexPath(indexes: [0, 9]), IndexPath(indexes: [0, 1])].sorted()
    expect(sortedPaths == [IndexPath(indexes: [0, 1]), IndexPath(indexes: [0, 9]), IndexPath(indexes: [1, 0])],
           "IndexPath sorting produced the wrong order.")
    #endif
}

func testWinFoundationUUIDCodableMatchesAppleForm() {
    #if os(Windows)
    let uuid = requireValue(
        UUID(uuidString: "00112233-4455-6677-8899-AABBCCDDEEFF"),
        "Canonical UUID fixture should be valid."
    )

    // Encodes as the uppercase uuidString in a single value — byte-identical to
    // Apple Foundation's UUID coding, so a JSON model file interchanges across
    // the two Foundations without a UUID mismatch.
    let encoder = SingleStringEncoder()
    requireNoThrow({ try uuid.encode(to: encoder) }, "UUID encoding should succeed")
    expect(encoder.captured == "00112233-4455-6677-8899-AABBCCDDEEFF",
        "UUID should encode as its uppercase uuidString; got \(String(describing: encoder.captured)).")

    // Round-trips its own output.
    let encodedUUID = requireValue(encoder.captured, "UUID encoder should capture a value.")
    let decoded = requireNoThrow({ try UUID(from: SingleStringDecoder(encodedUUID)) }, "UUID decoding should succeed")
    expect(decoded == uuid, "UUID did not round-trip through Codable.")

    // Decodes Apple's canonical lowercase uuidString too (interop robustness).
    let fromLower = requireNoThrow(
        { try UUID(from: SingleStringDecoder("00112233-4455-6677-8899-aabbccddeeff")) },
        "Lowercase UUID decoding should succeed"
    )
    expect(fromLower == uuid, "UUID should decode Apple's lowercase uuidString form.")

    // A malformed string throws a DecodingError instead of crashing.
    var threw = false
    do {
        _ = try UUID(from: SingleStringDecoder("not-a-uuid"))
    } catch {
        threw = true
    }
    expect(threw, "Decoding an invalid UUID string should throw a DecodingError.")
    #endif
}

struct JSONAddress: Codable, Equatable { let street: String; let zip: Int }

struct JSONPerson: Codable, Equatable {
    let name: String
    let age: Int
    let height: Double
    let admin: Bool
    let nickname: String?
    let tags: [String]
    let address: JSONAddress
    let id: UUID
}

struct JSONSnake: Codable, Equatable { let firstName: String; let lastNameHTML: String; let urlString: String }

struct JSONDates: Codable, Equatable { let d: Date }

@MainActor
func testWinFoundationJSONCompactEncoding() {
    #if os(Windows)
    // Compact output: keys in declaration order, escaped quote and slash and
    // tab, nil optional omitted — byte-for-byte Apple's default JSONEncoder.
    let person = JSONPerson(
        name: "Bobby \"B\"", age: 42, height: 1.75, admin: true, nickname: nil,
        tags: ["a", "b/c"], address: JSONAddress(street: "1 Main\tSt", zip: 90210),
        id: requireValue(
            UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"),
            "JSON UUID fixture should be valid."
        ))
    let compact = requireNoThrow({ try JSONEncoder().encode(person) }, "Compact JSON encoding should succeed")
    let expectedCompact = "{\"name\":\"Bobby \\\"B\\\"\",\"age\":42,\"height\":1.75,\"admin\":true,\"tags\":[\"a\",\"b\\/c\"],\"address\":{\"street\":\"1 Main\\tSt\",\"zip\":90210},\"id\":\"E621E1F8-C36C-495A-93FC-0C247A3E6E5F\"}"
    expect(String(decoding: compact, as: UTF8.self) == expectedCompact,
        "Compact JSON did not match Apple's form; got \(String(decoding: compact, as: UTF8.self)).")

    // Round-trips its own output.
    let back = requireNoThrow(
        { try JSONDecoder().decode(JSONPerson.self, from: compact) },
        "JSON model decoding should succeed"
    )
    expect(back == person, "JSON did not round-trip a model with nested and optional fields.")

    // Integral doubles print without a fractional part; fractions keep precision.
    let numbers = requireNoThrow({ try JSONEncoder().encode([5.0, 5.5, -3.25, 100.0]) }, "Number encoding should succeed")
    expect(String(decoding: numbers, as: UTF8.self) == "[5,5.5,-3.25,100]",
        "Number formatting did not match Apple; got \(String(decoding: numbers, as: UTF8.self)).")

    // Date defaults to seconds since the 2001 reference date, a bare number.
    let dateJSON = requireNoThrow(
        { try JSONEncoder().encode(JSONDates(d: Date(timeIntervalSinceReferenceDate: 0))) },
        "Date JSON encoding should succeed"
    )
    expect(String(decoding: dateJSON, as: UTF8.self) == "{\"d\":0}",
        "Default Date encoding was not seconds-since-2001; got \(String(decoding: dateJSON, as: UTF8.self)).")
    #endif
}

@MainActor
func testWinFoundationJSONFormattingAndKeys() {
    #if os(Windows)
    // Pretty-printed + sorted keys: two-space indent, ": " separator, sorted.
    let pretty = JSONEncoder()
    pretty.outputFormatting = [.prettyPrinted, .sortedKeys]
    let prettyData = requireNoThrow(
        { try pretty.encode(JSONAddress(street: "x", zip: 1)) },
        "Pretty JSON encoding should succeed"
    )
    let prettyOut = String(decoding: prettyData, as: UTF8.self)
    expect(prettyOut == "{\n  \"street\" : \"x\",\n  \"zip\" : 1\n}",
        "Pretty-printed output did not match Apple; got \(prettyOut).")

    // Snake-case key conversion, including Apple's acronym rule
    // (lastNameHTML -> last_name_html, not last_name_h_t_m_l).
    let snakeEncoder = JSONEncoder()
    snakeEncoder.keyEncodingStrategy = .convertToSnakeCase
    snakeEncoder.outputFormatting = [.sortedKeys]
    let snakeData = requireNoThrow(
        { try snakeEncoder.encode(JSONSnake(firstName: "a", lastNameHTML: "b", urlString: "u")) },
        "Snake-case JSON encoding should succeed"
    )
    let snake = String(decoding: snakeData, as: UTF8.self)
    expect(snake == "{\"first_name\":\"a\",\"last_name_html\":\"b\",\"url_string\":\"u\"}",
        "Snake-case conversion did not match Apple's acronym handling; got \(snake).")

    // Decoding transforms snake_case back to camelCase.
    let snakeDecoder = JSONDecoder()
    snakeDecoder.keyDecodingStrategy = .convertFromSnakeCase
    struct Pair: Codable, Equatable { let firstName: String; let lastName: String }
    let pair = requireNoThrow(
        { try snakeDecoder.decode(Pair.self, from: Data("{\"first_name\":\"x\",\"last_name\":\"y\"}".utf8)) },
        "Snake-case JSON decoding should succeed"
    )
    expect(pair == Pair(firstName: "x", lastName: "y"), "convertFromSnakeCase did not restore camelCase keys.")
    #endif
}

@MainActor
func testWinFoundationJSONUnicodeDatesAndErrors() {
    #if os(Windows)
    // Non-ASCII passes through unescaped; control characters are \u-escaped;
    // both survive a round trip.
    struct Text: Codable, Equatable { let s: String }
    let unicode = Text(s: "café\u{1F600}\u{01}")
    let unicodeJSON = requireNoThrow({ try JSONEncoder().encode(unicode) }, "Unicode JSON encoding should succeed")
    expect(String(decoding: unicodeJSON, as: UTF8.self) == "{\"s\":\"café😀\\u0001\"}",
        "Unicode/control-char escaping did not match Apple; got \(String(decoding: unicodeJSON, as: UTF8.self)).")
    let decodedUnicode = requireNoThrow(
        { try JSONDecoder().decode(Text.self, from: unicodeJSON) },
        "Unicode JSON decoding should succeed"
    )
    expect(decodedUnicode == unicode, "Unicode text did not round-trip.")

    // The withoutEscapingSlashes option leaves slashes bare.
    let noSlash = JSONEncoder()
    noSlash.outputFormatting = [.withoutEscapingSlashes]
    let slashData = requireNoThrow({ try noSlash.encode(Text(s: "a/b")) }, "Slash JSON encoding should succeed")
    let slashed = String(decoding: slashData, as: UTF8.self)
    expect(slashed == "{\"s\":\"a/b\"}", "withoutEscapingSlashes should leave slashes bare; got \(slashed).")

    // secondsSince1970 date strategy on both sides round-trips an exact instant.
    let secEncoder = JSONEncoder(); secEncoder.dateEncodingStrategy = .secondsSince1970
    let secDecoder = JSONDecoder(); secDecoder.dateDecodingStrategy = .secondsSince1970
    let instant = JSONDates(d: Date(timeIntervalSince1970: 1_780_272_000))
    let secJSON = requireNoThrow({ try secEncoder.encode(instant) }, "Epoch date encoding should succeed")
    expect(String(decoding: secJSON, as: UTF8.self) == "{\"d\":1780272000}",
        "secondsSince1970 strategy was wrong; got \(String(decoding: secJSON, as: UTF8.self)).")
    let decodedInstant = requireNoThrow(
        { try secDecoder.decode(JSONDates.self, from: secJSON) },
        "Epoch date decoding should succeed"
    )
    expect(decodedInstant == instant, "secondsSince1970 date did not round-trip.")

    // A malformed document throws rather than crashing.
    var threw = false
    do { _ = try JSONDecoder().decode(JSONAddress.self, from: Data("{\"street\":".utf8)) } catch { threw = true }
    expect(threw, "Malformed JSON should throw a DecodingError.")
    #endif
}

@MainActor
func testWinFoundationJSONCoderMatchesAppleForm() {
    testWinFoundationJSONCompactEncoding()
    testWinFoundationJSONFormattingAndKeys()
    testWinFoundationJSONUnicodeDatesAndErrors()
}

@MainActor
func testWinFoundationRunLoopAndTimer() {
    #if os(Windows)
    // `RunLoop` has no public initializer (as on Apple), so this drives
    // `RunLoop.main` headlessly and invalidates every timer it adds so nothing
    // leaks to another test. There is no pump in the test process, so time is
    // advanced deterministically through `fireTimers(forMode:upTo:)`; the live
    // pump path is covered by RunLoopDemo.
    let loop = RunLoop.main

    // A repeating timer fires once per elapsed interval and reschedules.
    var ticks = 0
    let repeating = WinFoundation.Timer(timeInterval: 1, repeats: true) { _ in ticks += 1 }
    loop.add(repeating, forMode: .default)
    let base = repeating.nextFireDate

    loop.fireTimers(forMode: .default, upTo: base.addingTimeInterval(-0.5))
    expect(ticks == 0, "A timer fired before its first fire date.")

    loop.fireTimers(forMode: .default, upTo: base)
    loop.fireTimers(forMode: .default, upTo: base.addingTimeInterval(1))
    loop.fireTimers(forMode: .default, upTo: base.addingTimeInterval(2))
    expect(ticks == 3, "A repeating timer did not fire once per interval; got \(ticks).")
    repeating.invalidate()

    // A non-repeating timer fires once and invalidates itself.
    var oneShots = 0
    let oneShot = WinFoundation.Timer(timeInterval: 0, repeats: false) { _ in oneShots += 1 }
    loop.add(oneShot, forMode: .default)
    let oneShotDate = oneShot.nextFireDate
    loop.fireTimers(forMode: .default, upTo: oneShotDate)
    loop.fireTimers(forMode: .default, upTo: oneShotDate.addingTimeInterval(10))
    expect(oneShots == 1, "A non-repeating timer fired \(oneShots) times, expected 1.")
    expect(!oneShot.isValid, "A non-repeating timer stayed valid after firing.")

    // An invalidated timer never fires.
    var invalidatedFires = 0
    let stopped = WinFoundation.Timer(timeInterval: 0, repeats: true) { _ in invalidatedFires += 1 }
    loop.add(stopped, forMode: .default)
    stopped.invalidate()
    loop.fireTimers(forMode: .default, upTo: Date(timeIntervalSinceNow: 100))
    expect(invalidatedFires == 0, "An invalidated timer still fired.")

    // A `.common` timer is serviced (and time-limits the loop) while running
    // any mode.
    var commonFires = 0
    let commonTimer = WinFoundation.Timer(timeInterval: 5, repeats: false) { _ in commonFires += 1 }
    loop.add(commonTimer, forMode: .common)
    expect(loop.limitDate(forMode: .default) != nil,
           "A .common timer should be serviced (and time-limited) in .default mode.")
    loop.fireTimers(forMode: .default, upTo: commonTimer.nextFireDate)
    expect(commonFires == 1, "A .common-mode timer did not fire while running .default.")

    // `perform` runs its block on the next iteration; with no pump, one pass of
    // `run(mode:before:)` drains it and returns.
    var performed = false
    loop.perform { performed = true }
    _ = loop.run(mode: .default, before: Date())
    expect(performed, "A perform block did not run on the next loop iteration.")

    // `RunLoop.Mode` carries Apple's raw values, so `Timer.publish(on:in:)`
    // can be spelled the same across Foundations.
    expect(RunLoop.Mode.default.rawValue == "kCFRunLoopDefaultMode", "RunLoop.Mode.default raw value drifted from Apple's.")
    expect(RunLoop.Mode.common.rawValue == "kCFRunLoopCommonModes", "RunLoop.Mode.common raw value drifted from Apple's.")
    #endif
}

@MainActor
func testWinFoundationFileURLCompatibility() {
    #if os(Windows)
    let url = URL(fileURLWithPath: "C:\\AIResearch\\WinChocolate\\")
    expect(url.path == "C:\\AIResearch\\WinChocolate\\", "WinFoundation URL did not preserve directory-style trailing separator.")
    expect(url.isFileURL, "WinFoundation URL(fileURLWithPath:) should create a file URL.")
    expect(url.absoluteString == "file:///C:/AIResearch/WinChocolate/", "WinFoundation URL absoluteString did not create a file URL string.")
    expect(url.relativeString == url.absoluteString, "WinFoundation URL relativeString should match absoluteString without base URL support.")
    expect(url.lastPathComponent == "WinChocolate", "WinFoundation URL lastPathComponent failed.")
    expect(url.appendingPathComponent("Code").path.hasSuffix("WinChocolate\\Code"), "WinFoundation URL appendingPathComponent failed.")
    expect(url.appendingPathComponent("Code", isDirectory: true).hasDirectoryPath, "WinFoundation URL directory appending failed.")
    expect(url.appendingPathComponent("README").appendingPathExtension("md").lastPathComponent == "README.md", "WinFoundation URL appendingPathExtension failed.")
    expect(url.appendingPathComponent("README.md").pathExtension == "md", "WinFoundation URL pathExtension failed.")
    expect(url.appendingPathComponent("README.md").deletingPathExtension().lastPathComponent == "README", "WinFoundation URL deletingPathExtension failed.")
    expect(url.appendingPathComponent("Code").deletingLastPathComponent().lastPathComponent == "WinChocolate", "WinFoundation URL deletingLastPathComponent failed.")

    let parsedFileURL = URL(string: "file:///C:/AIResearch/WinChocolate/Code")
    expect(parsedFileURL?.isFileURL == true, "WinFoundation URL(string:) did not parse file URL.")
    expect(parsedFileURL?.lastPathComponent == "Code", "WinFoundation parsed file URL lastPathComponent failed.")
    #endif
}

@MainActor
func testWinFoundationWebAndRelativeURLCompatibility() {
    #if os(Windows)
    let webURL = URL(string: "https://example.com/index.html")
    expect(webURL?.isFileURL == false, "WinFoundation URL(string:) should preserve non-file URLs.")
    expect(webURL?.scheme == "https", "WinFoundation URL scheme failed.")
    expect(webURL?.host == "example.com", "WinFoundation URL host failed.")
    expect(webURL?.path == "/index.html", "WinFoundation URL path failed for web URL.")
    expect(webURL?.absoluteString == "https://example.com/index.html", "WinFoundation non-file URL absoluteString failed.")

    let queriedURL = URL(string: "https://example.com/search docs/index.html?q=hello world&sort=up#top item")
    expect(queriedURL?.scheme == "https", "WinFoundation queried URL scheme failed.")
    expect(queriedURL?.host == "example.com", "WinFoundation queried URL host failed.")
    expect(queriedURL?.path == "/search docs/index.html", "WinFoundation queried URL path failed.")
    expect(queriedURL?.query == "q=hello world&sort=up", "WinFoundation queried URL query failed.")
    expect(queriedURL?.fragment == "top item", "WinFoundation queried URL fragment failed.")
    expect(queriedURL?.percentEncodedPath == "/search%20docs/index.html", "WinFoundation queried URL percentEncodedPath failed.")
    expect(queriedURL?.percentEncodedQuery == "q=hello%20world&sort=up", "WinFoundation queried URL percentEncodedQuery failed.")
    expect(queriedURL?.percentEncodedFragment == "top%20item", "WinFoundation queried URL percentEncodedFragment failed.")
    expect(queriedURL?.absoluteString == "https://example.com/search%20docs/index.html?q=hello%20world&sort=up#top%20item", "WinFoundation queried URL absoluteString failed.")

    let spacedFileURL = URL(fileURLWithPath: "C:\\AIResearch\\Win Chocolate\\hello world.txt")
    expect(spacedFileURL.absoluteString == "file:///C:/AIResearch/Win%20Chocolate/hello%20world.txt", "WinFoundation URL did not percent-encode file URL spaces.")
    expect(spacedFileURL.percentEncodedPath == "C:/AIResearch/Win%20Chocolate/hello%20world.txt", "WinFoundation URL percentEncodedPath failed.")

    let decodedFileURL = URL(string: "file:///C:/AIResearch/Win%20Chocolate/hello%20world.txt")
    expect(decodedFileURL?.path == "C:\\AIResearch\\Win Chocolate\\hello world.txt", "WinFoundation URL did not decode percent-encoded file URL path.")

    let baseURL = URL(string: "https://example.com/docs/")
    let relativeURL = URL(string: "guide/index.html", relativeTo: baseURL)
    expect(relativeURL?.baseURL?.absoluteString == "https://example.com/docs/", "WinFoundation relative URL did not preserve base URL.")
    expect(relativeURL?.relativePath == "guide/index.html", "WinFoundation relative URL did not preserve relative path.")
    expect(relativeURL?.relativeString == "guide/index.html", "WinFoundation relative URL did not preserve relativeString.")
    expect(relativeURL?.absoluteString == "https://example.com/docs/guide/index.html", "WinFoundation relative URL did not resolve absoluteString with base URL.")
    expect(relativeURL?.absoluteURL.absoluteString == "https://example.com/docs/guide/index.html", "WinFoundation relative URL absoluteURL failed.")

    let queriedRelativeURL = URL(string: "guide/search results.html?q=hello world#section 1", relativeTo: baseURL)
    expect(queriedRelativeURL?.absoluteString == "https://example.com/docs/guide/search%20results.html?q=hello%20world#section%201", "WinFoundation queried relative URL absoluteString failed.")
    expect(queriedRelativeURL?.absoluteURL.query == "q=hello world", "WinFoundation queried relative URL query failed.")
    expect(queriedRelativeURL?.absoluteURL.fragment == "section 1", "WinFoundation queried relative URL fragment failed.")

    let weirdPath = URL(fileURLWithPath: "C:\\AIResearch\\.\\WinChocolate\\Code\\..\\Docs\\")
    expect(weirdPath.standardizedFileURL.path == "C:\\AIResearch\\WinChocolate\\Docs\\", "WinFoundation URL standardizedFileURL did not collapse dot components.")

    let uncURL = URL(fileURLWithPath: "\\\\Server\\Share\\WinChocolate")
    expect(uncURL.absoluteString == "file://Server/Share/WinChocolate", "WinFoundation URL did not format UNC file URL correctly.")
    expect(uncURL.pathComponents == ["Server", "Share", "WinChocolate"], "WinFoundation URL UNC pathComponents failed.")

    let parsedUNCURL = URL(string: "file://Server/Share/WinChocolate")
    expect(parsedUNCURL?.path == "\\\\Server\\Share\\WinChocolate", "WinFoundation URL did not parse UNC file URL correctly.")

    let driveRoot = URL(fileURLWithPath: "C:\\")
    expect(driveRoot.deletingLastPathComponent().path == "C:\\", "WinFoundation URL should preserve Windows drive root when deleting last component.")
    #endif
}

@MainActor
func testWinFoundationCompatibilitySurface() {
    #if os(Windows)
    testWinFoundationFileURLCompatibility()
    testWinFoundationWebAndRelativeURLCompatibility()
    testWinFoundationDataCompatibility()
    testWinFoundationValueTypeCompatibility()
    testWinFoundationBundleAndNotificationCompatibility()
    #endif
}

@MainActor
func testWinFoundationDataCompatibility() {
    #if os(Windows)
    let data = Data([1, 2, 3])
    expect(data.count == 3, "WinFoundation Data count failed.")
    expect(Array(data) == [1, 2, 3], "WinFoundation Data iteration failed.")

    var mutableData = Data(repeating: 7, count: 3)
    expect(Array(mutableData) == [7, 7, 7], "WinFoundation Data repeating initializer failed.")
    mutableData[1] = 9
    expect(mutableData[1] == 9, "WinFoundation Data mutable subscript failed.")
    mutableData.append(10)
    mutableData.append(contentsOf: [11, 12])
    mutableData.append(Data([13, 14]))
    expect(Array(mutableData) == [7, 9, 7, 10, 11, 12, 13, 14], "WinFoundation Data append failed.")
    mutableData.replaceSubrange(1..<3, with: [21, 22, 23])
    expect(Array(mutableData) == [7, 21, 22, 23, 10, 11, 12, 13, 14], "WinFoundation Data replaceSubrange failed.")
    expect(Array(mutableData.subdata(in: 1..<4)) == [21, 22, 23], "WinFoundation Data subdata failed.")
    let unsafeSum = mutableData.withUnsafeBytes { rawBuffer in
        rawBuffer.reduce(0) { partial, byte in partial + Int(byte) }
    }
    expect(unsafeSum == Array(mutableData).reduce(0) { $0 + Int($1) }, "WinFoundation Data withUnsafeBytes failed.")
    mutableData.withUnsafeMutableBytes { rawBuffer in
        rawBuffer[0] = 99
    }
    expect(mutableData.first == 99, "WinFoundation Data withUnsafeMutableBytes failed.")
    mutableData.removeAll(keepingCapacity: true)
    expect(mutableData.isEmpty, "WinFoundation Data removeAll failed.")

    let packageDataURL = URL(fileURLWithPath: "Package.swift")
    let packageData = try? Data(contentsOf: packageDataURL)
    expect(packageData?.count ?? 0 > 0, "WinFoundation Data(contentsOf:) failed to read a package file.")
    expect(String(decoding: packageData ?? Data(), as: UTF8.self).contains("WinChocolate"), "WinFoundation Data(contentsOf:) did not preserve file bytes.")

    let writeDataURL = URL(fileURLWithPath: ".build\\winfoundation-data-write.txt")
    let writtenData = Data([87, 105, 110, 67, 104, 111, 99, 111, 108, 97, 116, 101])
    do {
        try writtenData.write(to: writeDataURL)
        let roundTripData = try Data(contentsOf: writeDataURL)
        expect(roundTripData == writtenData, "WinFoundation Data write/read round trip failed.")
    } catch {
        fatalError("WinFoundation Data file I/O threw unexpectedly: \(error)")
    }

    #endif
}

