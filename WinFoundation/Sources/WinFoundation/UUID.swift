public typealias uuid_t = (
    UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8
)

/// A Foundation-compatible UUID subset backed by native Windows GUID creation.
public struct UUID: Equatable, Hashable, Sendable, CustomStringConvertible {
    private let bytes: [UInt8]

    /// Creates a new UUID.
    public init() {
        self.bytes = UUID.makeNativeUUIDBytes()
    }

    /// Creates a UUID from raw bytes.
    public init(uuid: uuid_t) {
        self.bytes = [
            uuid.0, uuid.1, uuid.2, uuid.3,
            uuid.4, uuid.5, uuid.6, uuid.7,
            uuid.8, uuid.9, uuid.10, uuid.11,
            uuid.12, uuid.13, uuid.14, uuid.15
        ]
    }

    /// Creates a UUID from a standard string representation.
    public init?(uuidString string: String) {
        guard let parsed = UUID.parseUUIDString(string) else {
            return nil
        }
        self.bytes = parsed
    }

    /// Raw UUID bytes.
    public var uuid: uuid_t {
        (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
    }

    /// Standard uppercase UUID string.
    public var uuidString: String {
        let hex = bytes.map(UUID.twoDigitHex)
        return "\(hex[0])\(hex[1])\(hex[2])\(hex[3])-\(hex[4])\(hex[5])-\(hex[6])\(hex[7])-\(hex[8])\(hex[9])-\(hex[10])\(hex[11])\(hex[12])\(hex[13])\(hex[14])\(hex[15])"
    }

    public var description: String {
        uuidString
    }

    private static func parseUUIDString(_ string: String) -> [UInt8]? {
        let filtered = string.filter { $0 != "-" }
        guard filtered.count == 32 else {
            return nil
        }

        var result: [UInt8] = []
        var index = filtered.startIndex
        while index < filtered.endIndex {
            let nextIndex = filtered.index(after: index)
            guard nextIndex < filtered.endIndex,
                  let high = hexValue(filtered[index]),
                  let low = hexValue(filtered[nextIndex]) else {
                return nil
            }
            result.append(UInt8(high * 16 + low))
            index = filtered.index(after: nextIndex)
        }
        return result.count == 16 ? result : nil
    }

    private static func twoDigitHex(_ byte: UInt8) -> String {
        String(hexDigit(Int(byte >> 4))) + String(hexDigit(Int(byte & 0x0F)))
    }

    private static func hexDigit(_ value: Int) -> Character {
        let digits = Array("0123456789ABCDEF")
        return digits[value]
    }

    private static func hexValue(_ character: Character) -> Int? {
        guard let scalar = character.unicodeScalars.first, character.unicodeScalars.count == 1 else {
            return nil
        }

        switch scalar.value {
        case 48...57:
            return Int(scalar.value - 48)
        case 65...70:
            return Int(scalar.value - 55)
        case 97...102:
            return Int(scalar.value - 87)
        default:
            return nil
        }
    }

    private static func makeNativeUUIDBytes() -> [UInt8] {
        #if os(Windows)
        var guid = WinFoundationGUID()
        let result = WinFoundationCoCreateGuid(&guid)
        if result == 0 {
            return [
                UInt8((guid.data1 >> 24) & 0xFF),
                UInt8((guid.data1 >> 16) & 0xFF),
                UInt8((guid.data1 >> 8) & 0xFF),
                UInt8(guid.data1 & 0xFF),
                UInt8((guid.data2 >> 8) & 0xFF),
                UInt8(guid.data2 & 0xFF),
                UInt8((guid.data3 >> 8) & 0xFF),
                UInt8(guid.data3 & 0xFF),
                guid.data4.0, guid.data4.1, guid.data4.2, guid.data4.3,
                guid.data4.4, guid.data4.5, guid.data4.6, guid.data4.7
            ]
        }
        #endif

        let seed = UInt64(Date().timeIntervalSinceReferenceDate * 1_000_000)
        return [
            UInt8((seed >> 56) & 0xFF), UInt8((seed >> 48) & 0xFF),
            UInt8((seed >> 40) & 0xFF), UInt8((seed >> 32) & 0xFF),
            UInt8((seed >> 24) & 0xFF), UInt8((seed >> 16) & 0xFF),
            UInt8((seed >> 8) & 0xFF), UInt8(seed & 0xFF),
            0, 0, 0, 0, 0, 0, 0, 0
        ]
    }
}

#if os(Windows)
private struct WinFoundationGUID {
    var data1: UInt32 = 0
    var data2: UInt16 = 0
    var data3: UInt16 = 0
    var data4: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0, 0, 0, 0, 0)
}

@_silgen_name("CoCreateGuid")
private func WinFoundationCoCreateGuid(_ guid: UnsafeMutablePointer<WinFoundationGUID>) -> Int32
#endif
