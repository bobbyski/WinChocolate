/// A minimal Foundation-compatible `NSNumber`.
///
/// Real Foundation cannot build on the current Windows toolchain, so this shim
/// boxes a numeric value the way AppKit-facing code expects: it is what
/// `NumberFormatter.string(from:)`/`number(from:)` take and return, and what a
/// control's `objectValue` can carry for a formatted field. It is a reference
/// type (a `final class`) like Foundation's `NSNumber`, and it round-trips the
/// common integer, floating-point, and boolean widths. It is a drop-in for the
/// real thing once Foundation is available; automatic bridging (`Int as
/// NSNumber`) is a Foundation feature the shim cannot reproduce, so callers use
/// the explicit `NSNumber(value:)` initializers.
public final class NSNumber: Equatable, Hashable, CustomStringConvertible {
    /// How the value was stored, so integer/boolean values round-trip exactly.
    private enum Storage {
        case int(Int64)
        case double(Double)
        case bool(Bool)
    }

    private let storage: Storage

    // MARK: - Initializers

    /// Creates a number from an `Int`.
    public init(value: Int) { storage = .int(Int64(value)) }

    /// Creates a number from an `Int8`.
    public init(value: Int8) { storage = .int(Int64(value)) }

    /// Creates a number from an `Int16`.
    public init(value: Int16) { storage = .int(Int64(value)) }

    /// Creates a number from an `Int32`.
    public init(value: Int32) { storage = .int(Int64(value)) }

    /// Creates a number from an `Int64`.
    public init(value: Int64) { storage = .int(value) }

    /// Creates a number from a `UInt`.
    public init(value: UInt) { storage = .int(Int64(bitPattern: UInt64(value))) }

    /// Creates a number from a `UInt8`.
    public init(value: UInt8) { storage = .int(Int64(value)) }

    /// Creates a number from a `UInt16`.
    public init(value: UInt16) { storage = .int(Int64(value)) }

    /// Creates a number from a `UInt32`.
    public init(value: UInt32) { storage = .int(Int64(value)) }

    /// Creates a number from a `Float`.
    public init(value: Float) { storage = .double(Double(value)) }

    /// Creates a number from a `Double`.
    public init(value: Double) { storage = .double(value) }

    /// Creates a number from a `Bool`.
    public init(value: Bool) { storage = .bool(value) }

    // MARK: - Accessors

    /// The value as an `Int` (rounding floating-point values toward zero).
    public var intValue: Int { Int(int64Value) }

    /// The value as an `Int8`.
    public var int8Value: Int8 { Int8(truncatingIfNeeded: int64Value) }

    /// The value as an `Int16`.
    public var int16Value: Int16 { Int16(truncatingIfNeeded: int64Value) }

    /// The value as an `Int32`.
    public var int32Value: Int32 { Int32(truncatingIfNeeded: int64Value) }

    /// The value as an `Int64`.
    public var int64Value: Int64 {
        switch storage {
        case .int(let value): return value
        case .double(let value): return Int64(value)
        case .bool(let value): return value ? 1 : 0
        }
    }

    /// The value as a `UInt`.
    public var uintValue: UInt { UInt(bitPattern: Int(int64Value)) }

    /// The value as a `Float`.
    public var floatValue: Float { Float(doubleValue) }

    /// The value as a `Double`.
    public var doubleValue: Double {
        switch storage {
        case .int(let value): return Double(value)
        case .double(let value): return value
        case .bool(let value): return value ? 1 : 0
        }
    }

    /// The value as a `Bool` (non-zero is `true`).
    public var boolValue: Bool {
        switch storage {
        case .int(let value): return value != 0
        case .double(let value): return value != 0
        case .bool(let value): return value
        }
    }

    /// The value formatted as a plain string (integers without a decimal point).
    public var stringValue: String {
        switch storage {
        case .int(let value): return String(value)
        case .bool(let value): return value ? "1" : "0"
        case .double(let value):
            if value == value.rounded() && abs(value) < 1e15 {
                return String(Int64(value))
            }
            return String(value)
        }
    }

    /// A textual description matching `stringValue`.
    public var description: String { stringValue }

    // MARK: - Comparison

    /// Compares two numbers by their `Double` value.
    public func compare(_ other: NSNumber) -> ComparisonResult {
        let lhs = doubleValue
        let rhs = other.doubleValue
        if lhs < rhs { return .orderedAscending }
        if lhs > rhs { return .orderedDescending }
        return .orderedSame
    }

    /// Numbers are equal when their `Double` values match.
    public static func == (lhs: NSNumber, rhs: NSNumber) -> Bool {
        lhs.doubleValue == rhs.doubleValue
    }

    /// Hashes the number by its `Double` value so equal numbers hash equally.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(doubleValue)
    }
}
