/// A minimal Foundation-compatible instant value.
public struct Date: Equatable, Comparable, Hashable, Sendable {
    private static let secondsBetween1601And1970 = 11_644_473_600.0
    private static let secondsBetween1970And2001 = 978_307_200.0

    private let secondsSinceReferenceDate: Double

    /// Creates a date for the current instant.
    public init() {
        self.secondsSinceReferenceDate = Date.currentTimeIntervalSinceReferenceDate()
    }

    /// Creates a date offset from Foundation's reference date.
    public init(timeIntervalSinceReferenceDate seconds: Double) {
        self.secondsSinceReferenceDate = seconds
    }

    /// Creates a date offset from the Unix epoch.
    public init(timeIntervalSince1970 seconds: Double) {
        self.secondsSinceReferenceDate = seconds - Date.secondsBetween1970And2001
    }

    /// Creates a date offset from the current instant.
    public init(timeIntervalSinceNow seconds: Double) {
        self.secondsSinceReferenceDate = Date.currentTimeIntervalSinceReferenceDate() + seconds
    }

    /// Creates a date offset from another date.
    public init(timeInterval seconds: Double, since date: Date) {
        self.secondsSinceReferenceDate = date.secondsSinceReferenceDate + seconds
    }

    /// Current instant.
    public static var now: Date {
        Date()
    }

    /// A date in the distant past, matching Foundation's constant.
    public static let distantPast = Date(timeIntervalSinceReferenceDate: -63_114_076_800.0)

    /// A date in the distant future, matching Foundation's constant.
    public static let distantFuture = Date(timeIntervalSinceReferenceDate: 63_113_904_000.0)

    /// Seconds since Foundation's reference date.
    public var timeIntervalSinceReferenceDate: Double {
        secondsSinceReferenceDate
    }

    /// Seconds since the Unix epoch.
    public var timeIntervalSince1970: Double {
        secondsSinceReferenceDate + Date.secondsBetween1970And2001
    }

    /// Seconds from this date to the current instant.
    public var timeIntervalSinceNow: Double {
        secondsSinceReferenceDate - Date.currentTimeIntervalSinceReferenceDate()
    }

    /// Returns the interval from another date to this date.
    public func timeIntervalSince(_ date: Date) -> Double {
        secondsSinceReferenceDate - date.secondsSinceReferenceDate
    }

    /// Returns a date by adding a time interval.
    public func addingTimeInterval(_ seconds: Double) -> Date {
        Date(timeIntervalSinceReferenceDate: secondsSinceReferenceDate + seconds)
    }

    /// Returns the distance to another date.
    public func distance(to other: Date) -> Double {
        other.secondsSinceReferenceDate - secondsSinceReferenceDate
    }

    /// Returns a date advanced by a time interval.
    public func advanced(by seconds: Double) -> Date {
        addingTimeInterval(seconds)
    }

    public static func < (lhs: Date, rhs: Date) -> Bool {
        lhs.secondsSinceReferenceDate < rhs.secondsSinceReferenceDate
    }

    private static func currentTimeIntervalSinceReferenceDate() -> Double {
        #if os(Windows)
        var fileTime = WinFoundationFileTime()
        WinFoundationGetSystemTimeAsFileTime(&fileTime)
        let high = UInt64(fileTime.dwHighDateTime) << 32
        let low = UInt64(fileTime.dwLowDateTime)
        let intervals = high | low
        let secondsSince1601 = Double(intervals) / 10_000_000.0
        return secondsSince1601 - secondsBetween1601And1970 - secondsBetween1970And2001
        #else
        return 0
        #endif
    }
}

extension Date {
    /// A date advanced by a time interval.
    public static func + (lhs: Date, rhs: Double) -> Date { lhs.addingTimeInterval(rhs) }
    /// A date moved back by a time interval.
    public static func - (lhs: Date, rhs: Double) -> Date { lhs.addingTimeInterval(-rhs) }
    /// The interval between two dates.
    public static func - (lhs: Date, rhs: Date) -> Double { lhs.timeIntervalSince(rhs) }
    public static func += (lhs: inout Date, rhs: Double) { lhs = lhs + rhs }
    public static func -= (lhs: inout Date, rhs: Double) { lhs = lhs - rhs }
}

extension Date: Codable {
    /// Decodes a date from its seconds-since-reference-date value, matching
    /// Foundation's single-value representation.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(timeIntervalSinceReferenceDate: try container.decode(Double.self))
    }

    /// Encodes a date as its seconds-since-reference-date value, matching
    /// Foundation.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(timeIntervalSinceReferenceDate)
    }
}

#if os(Windows)
private struct WinFoundationFileTime {
    var dwLowDateTime: UInt32 = 0
    var dwHighDateTime: UInt32 = 0
}

@_silgen_name("GetSystemTimeAsFileTime")
private func WinFoundationGetSystemTimeAsFileTime(_ fileTime: UnsafeMutablePointer<WinFoundationFileTime>)
#endif
