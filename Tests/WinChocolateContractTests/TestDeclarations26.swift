import WinChocolate

func testFoundationFormatterShape() {
    // DateFormatter must BE a Formatter: `NSControl.formatter` is typed
    // `Formatter?` on Apple, so `field.formatter = DateFormatter()` compiles on
    // macOS and has to compile here. Before Phase 2 this was a standalone class
    // and that assignment was a Windows-only compile error.
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    dateFormatter.timeZone = TimeZone(identifier: "UTC") ?? .current
    let asFormatter: Formatter = dateFormatter
    expect(asFormatter is DateFormatter, "DateFormatter must be usable as a Formatter.")

    let field = NSTextField(frame: NSMakeRect(0, 0, 160, 24))
    field.formatter = dateFormatter
    expect(field.formatter === dateFormatter, "A DateFormatter should assign to NSControl.formatter.")

    // …and format through the base class's entry point, as Foundation's does.
    let epoch = Date(timeIntervalSince1970: 0)
    expect(asFormatter.string(for: epoch) == "1970-01-01",
           "DateFormatter.string(for:) should format a Date. Got \(String(describing: asFormatter.string(for: epoch))).")
    expect(asFormatter.string(for: "not a date") == nil,
           "DateFormatter.string(for:) should return nil for a non-Date.")

    // The subclass above proves `open`; check the override actually dispatches.
    let percent: Formatter = ParityPercentFormatter()
    expect(percent.string(for: 0.42) == "42%",
           "A NumberFormatter subclass's override should dispatch. Got \(String(describing: percent.string(for: 0.42))).")
}

func testFoundationNibInstantiationShape() {
    // NSNib.instantiate takes `inout NSArray?` — AppKit's exact signature. An
    // app declares `var topLevelObjects: NSArray?` on Apple; that same
    // declaration has to type-check here, which is what this line tests.
    let xib = """
    <?xml version="1.0" encoding="UTF-8"?>
    <document type="com.apple.InterfaceBuilder3.Cocoa.XIB" version="3.0" toolsVersion="22505">
        <objects>
            <customView id="root-1" identifier="parityRoot">
                <rect key="frame" x="0.0" y="0.0" width="120" height="80"/>
            </customView>
        </objects>
    </document>
    """
    var topLevelObjects: NSArray?
    let nib = NSNib(nibData: Data(Array(xib.utf8)))
    expect(nib.instantiate(withOwner: nil, topLevelObjects: &topLevelObjects),
           "The nib should instantiate.")
    expect(topLevelObjects?.count == 1,
           "instantiate should populate topLevelObjects. Got \(String(describing: topLevelObjects?.count)).")
}

func testFoundationCodableAndHashableShapes() {
    // A URL has to survive a round-trip through its own absoluteString.
    // absoluteString is lossy — it always emits "/" — so both entry points must
    // agree on the stored separator, whichever form the caller used. Without
    // that, anything persisting a URL reads back a value that compares unequal.
    #if os(Windows)
    let parityPaths = ["/tmp/parity.txt", "C:\\AIResearch\\parity.txt", "C:/mixed\\sep/file.txt"]
    let payloadPath = "C:\\tmp\\parity.txt"
    #else
    let parityPaths = ["/tmp/parity.txt", "/tmp/mixed/sep/file.txt"]
    let payloadPath = "/tmp/parity.txt"
    #endif
    for path in parityPaths {
        let original = URL(fileURLWithPath: path)
        let reparsed = URL(string: original.absoluteString)
        expect(reparsed == original,
               "URL should survive its own absoluteString for \(path). Got \(String(describing: reparsed?.path)) vs \(original.path).")
    }

    // Data and URL are Codable in Foundation; a struct holding either must
    // round-trip. Data specifically must encode as base64, not as an array.
    struct ParityPayload: Codable, Equatable {
        let blob: Data
        let link: URL
    }
    let payload = ParityPayload(blob: Data([0xDE, 0xAD, 0xBE, 0xEF]),
                                link: URL(fileURLWithPath: payloadPath))
    let encoded = try? JSONEncoder().encode(payload)
    expect(encoded != nil, "A Codable struct holding Data + URL should encode.")
    if let encoded {
        let json = String(decoding: encoded.array, as: UTF8.self)
        expect(json.contains("3q2+7w=="),
               "Data should encode as base64, as Foundation's does. Got \(json).")
        let decoded = try? JSONDecoder().decode(ParityPayload.self, from: encoded)
        expect(decoded == payload, "The payload should round-trip unchanged.")
    }

    // Locale and TimeZone are Hashable + Codable in Foundation. Without those a
    // preferences struct holding either cannot synthesize Codable at all, and
    // neither can key a dictionary. The encoded form is Foundation's — a keyed
    // container carrying the identifier — so a file written on a Mac reads here.
    struct ParityPreferences: Codable, Equatable {
        let locale: Locale
        let zone: TimeZone
    }
    let preferences = ParityPreferences(locale: Locale(identifier: "en_US"),
                                        zone: TimeZone(identifier: "UTC") ?? .current)
    if let encodedPreferences = try? JSONEncoder().encode(preferences) {
        let json = String(decoding: encodedPreferences.array, as: UTF8.self)
        expect(json.contains("\"identifier\""),
               "Locale/TimeZone should encode Foundation's identifier-keyed form. Got \(json).")
        let decoded = try? JSONDecoder().decode(ParityPreferences.self, from: encodedPreferences)
        expect(decoded == preferences, "Preferences should round-trip unchanged.")
    } else {
        expect(false, "A Codable struct holding Locale + TimeZone should encode.")
    }

    // Hashable: usable as dictionary keys and in sets, as on Apple.
    let byLocale: [Locale: String] = [Locale(identifier: "en_US"): "US"]
    expect(byLocale[Locale(identifier: "en_US")] == "US", "Locale should key a dictionary.")
    expect(Set([TimeZone(identifier: "UTC") ?? .current, TimeZone(identifier: "UTC") ?? .current]).count == 1,
           "Equal TimeZones should collapse in a Set.")
}

func testFoundationTypesMatchApplesShapes() {
    testFoundationFormatterShape()
    testFoundationNibInstantiationShape()
    testFoundationCodableAndHashableShapes()
}

