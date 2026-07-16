/// A minimal Foundation-compatible time zone.
///
/// `Date` is an absolute instant; a time zone is what turns it into a wall
/// clock. Without one, `DateFormatter` could only render UTC — so a picker
/// holding 2026-06-01T00:00Z showed `12:00:00 AM` where AppKit, on an Eastern
/// machine, shows `8:00:00 PM` the previous day.
///
/// The current zone is backed by Windows, which owns the DST rules: offsets
/// come from `SystemTimeToTzSpecificLocalTime` (which applies the right rule
/// for the *date* being converted, not just today's), and the names from
/// `GetTimeZoneInformationForYear`. Named IANA zones (`America/New_York`) are
/// not supported — Windows has no such database — so `init(identifier:)`
/// accepts UTC/GMT and the current zone's own name only.
public struct TimeZone: Equatable, Sendable {
    /// How a zone determines its offset.
    private enum Kind: Equatable, Sendable {
        /// The system's current zone, with its DST rules.
        case current
        /// A constant offset from GMT.
        case fixed(seconds: Int)
    }

    private let kind: Kind

    /// The zone's identifier (`America/New_York`-style on Apple; here the
    /// Windows zone name, or `GMT`/`GMT+0530` for fixed offsets).
    public let identifier: String

    private init(kind: Kind, identifier: String) {
        self.kind = kind
        self.identifier = identifier
    }

    /// The system's current time zone.
    public static var current: TimeZone {
        TimeZone(kind: .current, identifier: WinTimeZone.currentIdentifier())
    }

    /// The system's current time zone, tracking changes (same as `current`).
    public static var autoupdatingCurrent: TimeZone {
        current
    }

    /// The GMT (zero-offset) zone.
    public static var gmt: TimeZone {
        TimeZone(kind: .fixed(seconds: 0), identifier: "GMT")
    }

    /// Creates a zone from an identifier.
    ///
    /// Only `UTC`/`GMT` and the current zone's own identifier resolve; Windows
    /// has no IANA zone database, so other names return `nil` rather than
    /// silently returning the wrong zone.
    public init?(identifier: String) {
        if identifier == "UTC" || identifier == "GMT" {
            self.init(kind: .fixed(seconds: 0), identifier: identifier)
            return
        }
        let current = WinTimeZone.currentIdentifier()
        if identifier == current {
            self.init(kind: .current, identifier: current)
            return
        }
        return nil
    }

    /// Creates a zone with a constant offset from GMT.
    public init?(secondsFromGMT seconds: Int) {
        guard abs(seconds) < 18 * 3_600 else {
            return nil
        }
        self.init(kind: .fixed(seconds: seconds), identifier: TimeZone.gmtIdentifier(for: seconds))
    }

    /// The offset from GMT, in seconds, in effect at `date`.
    ///
    /// DST-aware: the same zone returns −4h in June and −5h in December.
    public func secondsFromGMT(for date: Date = Date()) -> Int {
        switch kind {
        case .fixed(let seconds):
            return seconds
        case .current:
            return WinTimeZone.secondsFromGMT(for: date)
        }
    }

    /// Whether daylight saving time is in effect at `date`.
    ///
    /// Determined by comparing the offset at `date` against the zone's own
    /// yearly extremes rather than by reading a DST flag: DST always *adds* to
    /// the standard offset, so the larger of the two is daylight — which holds
    /// in the southern hemisphere too, where the seasons are inverted.
    public func isDaylightSavingTime(for date: Date = Date()) -> Bool {
        guard case .current = kind else {
            return false
        }
        let offsets = WinTimeZone.yearOffsets(around: date)
        guard offsets.standard != offsets.daylight else {
            return false
        }
        return secondsFromGMT(for: date) == offsets.daylight
    }

    /// The zone's abbreviation at `date` (`EDT`), or a `GMT-4` style fallback.
    ///
    /// Windows stores only full names ("Eastern Daylight Time"), so the
    /// abbreviation is built from the initials of the name's words. That is
    /// right for the Americas but not universal (Central European Summer Time
    /// abbreviates CEST, not CEST's initials of the *Windows* name), so a name
    /// that doesn't fit the pattern falls back to a GMT offset, which is never
    /// wrong — only less pretty.
    public func abbreviation(for date: Date = Date()) -> String? {
        guard case .current = kind else {
            return TimeZone.gmtIdentifier(for: secondsFromGMT(for: date))
        }
        guard let name = localizedName(for: isDaylightSavingTime(for: date) ? .daylightSaving : .standard, locale: nil) else {
            return TimeZone.gmtIdentifier(for: secondsFromGMT(for: date))
        }
        let initials = name.split(separator: " ").compactMap { $0.first }.filter { $0.isUppercase }
        guard initials.count >= 2 else {
            return TimeZone.gmtIdentifier(for: secondsFromGMT(for: date))
        }
        return String(initials)
    }

    /// Styles for `localizedName(for:locale:)`.
    public enum NameStyle: Int, Sendable {
        case standard
        case shortStandard
        case daylightSaving
        case shortDaylightSaving
        case generic
        case shortGeneric
    }

    /// The zone's display name — "Eastern Daylight Time" — for `date`'s year.
    ///
    /// This is what `DateFormatter`'s full time style appends, and what makes
    /// `NSDatePicker.stringValue` match AppKit.
    public func localizedName(for style: NameStyle, locale: Locale?) -> String? {
        _ = locale     // Windows returns the zone names already localized.
        guard case .current = kind else {
            return identifier
        }
        let names = WinTimeZone.names(forYearOf: Date())
        switch style {
        case .standard, .generic:
            return names.standard
        case .daylightSaving:
            return names.daylight
        case .shortStandard, .shortDaylightSaving, .shortGeneric:
            return abbreviation()
        }
    }

    /// The display name in effect at `date` — standard or daylight.
    ///
    /// The distinction is per-instant, not per-today: a June date reads
    /// "Eastern Daylight Time" even when it is December on the machine.
    public func longName(for date: Date) -> String? {
        guard case .current = kind else {
            return identifier
        }
        let names = WinTimeZone.names(forYearOf: date)
        return isDaylightSavingTime(for: date) ? names.daylight : names.standard
    }

    /// A `GMT`/`GMT+0530` identifier for a constant offset.
    private static func gmtIdentifier(for seconds: Int) -> String {
        guard seconds != 0 else {
            return "GMT"
        }
        let sign = seconds < 0 ? "-" : "+"
        let total = abs(seconds) / 60
        let hours = total / 60
        let minutes = total % 60
        let hourText = hours < 10 ? "0\(hours)" : String(hours)
        let minuteText = minutes < 10 ? "0\(minutes)" : String(minutes)
        return "GMT\(sign)\(hourText)\(minuteText)"
    }
}

/// Proleptic-Gregorian civil-date math, shared by `TimeZone` and
/// `DateFormatter` so one algorithm decides what instant a wall clock is.
///
/// Both directions are Howard Hinnant's `civil_from_days`/`days_from_civil`.
enum WinCivilTime {
    /// A wall-clock reading, with no zone attached.
    struct Parts {
        var year: Int
        var month: Int
        var day: Int
        var hour: Int
        var minute: Int
        var second: Int
        /// 1 = Sunday ... 7 = Saturday.
        var weekday: Int
    }

    /// Splits a count of seconds since the epoch into a wall clock.
    static func parts(fromEpoch total: Int) -> Parts {
        let days = Int((Double(total) / 86_400.0).rounded(.down))
        var seconds = total - days * 86_400
        if seconds < 0 {
            seconds += 86_400
        }

        let z = days + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365
        var year = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let day = doy - (153 * mp + 2) / 5 + 1
        let month = mp + (mp < 10 ? 3 : -9)
        year += month <= 2 ? 1 : 0

        // 1970-01-01 was a Thursday (weekday 5 with Sunday = 1).
        let weekday = ((days % 7) + 7 + 4) % 7 + 1

        return Parts(year: year, month: month, day: day,
                     hour: seconds / 3_600, minute: (seconds % 3_600) / 60, second: seconds % 60,
                     weekday: weekday)
    }

    /// Joins a wall clock back into seconds since the epoch.
    static func epoch(from parts: Parts) -> Int {
        epoch(year: parts.year, month: parts.month, day: parts.day,
              hour: parts.hour, minute: parts.minute, second: parts.second)
    }

    /// Joins wall-clock fields back into seconds since the epoch.
    static func epoch(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int) -> Int {
        var adjustedYear = year
        adjustedYear -= month <= 2 ? 1 : 0
        let era = (adjustedYear >= 0 ? adjustedYear : adjustedYear - 399) / 400
        let yoe = adjustedYear - era * 400
        let adjustedMonth = month + (month > 2 ? -3 : 9)
        let doy = (153 * adjustedMonth + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        let days = era * 146_097 + doe - 719_468
        return days * 86_400 + hour * 3_600 + minute * 60 + second
    }
}

/// Windows time-zone bridging.
enum WinTimeZone {
    /// The current zone's standard name, which serves as its identifier.
    static func currentIdentifier() -> String {
        names(forYearOf: Date()).standard
    }

    /// The offset from GMT in effect at `date`, in seconds.
    ///
    /// Windows is asked to convert the instant rather than being asked for a
    /// bias: `SystemTimeToTzSpecificLocalTime` applies the DST rule that was in
    /// force on that date, so a June instant reads −4h even in December.
    static func secondsFromGMT(for date: Date) -> Int {
        #if os(Windows)
        let utcSeconds = Int(date.timeIntervalSince1970.rounded(.down))
        let utcParts = WinCivilTime.parts(fromEpoch: utcSeconds)
        var utc = systemTime(from: utcParts)
        var local = WinSystemTime()
        guard WinFoundationSystemTimeToTzSpecificLocalTime(nil, &utc, &local) != 0 else {
            return 0
        }
        let localSeconds = WinCivilTime.epoch(year: Int(local.year), month: Int(local.month), day: Int(local.day),
                                              hour: Int(local.hour), minute: Int(local.minute), second: Int(local.second))
        return localSeconds - utcSeconds
        #else
        _ = date
        return 0
        #endif
    }

    /// The zone's standard and daylight offsets in `date`'s year, in seconds.
    ///
    /// Probed by converting a midwinter and a midsummer instant rather than by
    /// reading the bias fields — no sign conventions to get wrong. DST adds, so
    /// the larger offset is the daylight one in either hemisphere.
    static func yearOffsets(around date: Date) -> (standard: Int, daylight: Int) {
        let year = WinCivilTime.parts(fromEpoch: Int(date.timeIntervalSince1970.rounded(.down))).year
        let january = Date(timeIntervalSince1970: Double(WinCivilTime.epoch(year: year, month: 1, day: 15, hour: 12, minute: 0, second: 0)))
        let july = Date(timeIntervalSince1970: Double(WinCivilTime.epoch(year: year, month: 7, day: 15, hour: 12, minute: 0, second: 0)))
        let first = secondsFromGMT(for: january)
        let second = secondsFromGMT(for: july)
        return (standard: min(first, second), daylight: max(first, second))
    }

    /// The zone's standard and daylight names for `date`'s year.
    static func names(forYearOf date: Date) -> (standard: String, daylight: String) {
        #if os(Windows)
        let year = WinCivilTime.parts(fromEpoch: Int(date.timeIntervalSince1970.rounded(.down))).year
        // TIME_ZONE_INFORMATION is read through raw offsets rather than a Swift
        // struct: it embeds two WCHAR[32] arrays, which Swift can only express
        // as 32-element tuples, and a hand-declared layout that drifts from C's
        // is a bug that reads as data corruption (as NMHDR's missing tail
        // padding once did). Layout (LONG-aligned, 172 bytes total):
        //     0    LONG       Bias
        //     4    WCHAR      StandardName[32]
        //     68   SYSTEMTIME StandardDate
        //     84   LONG       StandardBias
        //     88   WCHAR      DaylightName[32]
        //     152  SYSTEMTIME DaylightDate
        //     168  LONG       DaylightBias
        let size = 172
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 4)
        defer { buffer.deallocate() }
        buffer.initializeMemory(as: UInt8.self, repeating: 0, count: size)
        guard WinFoundationGetTimeZoneInformationForYear(UInt16(clamping: year), nil, buffer) != 0 else {
            return ("GMT", "GMT")
        }
        let standard = wideString(in: buffer, atByteOffset: 4, maxUnits: 32)
        let daylight = wideString(in: buffer, atByteOffset: 88, maxUnits: 32)
        return (standard: standard.isEmpty ? "GMT" : standard,
                daylight: daylight.isEmpty ? standard : daylight)
        #else
        _ = date
        return ("GMT", "GMT")
        #endif
    }

    #if os(Windows)
    /// Reads a fixed-width, NUL-terminated WCHAR array out of a raw struct.
    private static func wideString(in buffer: UnsafeMutableRawPointer, atByteOffset offset: Int, maxUnits: Int) -> String {
        var units: [UInt16] = []
        for index in 0..<maxUnits {
            let unit = buffer.load(fromByteOffset: offset + index * 2, as: UInt16.self)
            if unit == 0 {
                break
            }
            units.append(unit)
        }
        return String(decoding: units, as: UTF16.self)
    }

    private static func systemTime(from parts: WinCivilTime.Parts) -> WinSystemTime {
        WinSystemTime(
            year: UInt16(clamping: parts.year),
            month: UInt16(clamping: parts.month),
            dayOfWeek: UInt16(clamping: parts.weekday - 1),
            day: UInt16(clamping: parts.day),
            hour: UInt16(clamping: parts.hour),
            minute: UInt16(clamping: parts.minute),
            second: UInt16(clamping: parts.second),
            milliseconds: 0
        )
    }
    #endif
}

#if os(Windows)
@_silgen_name("SystemTimeToTzSpecificLocalTime")
private func WinFoundationSystemTimeToTzSpecificLocalTime(_ timeZone: UnsafeRawPointer?, _ universal: UnsafePointer<WinSystemTime>?, _ local: UnsafeMutablePointer<WinSystemTime>?) -> Int32

@_silgen_name("GetTimeZoneInformationForYear")
private func WinFoundationGetTimeZoneInformationForYear(_ year: UInt16, _ dynamicZone: UnsafeRawPointer?, _ zone: UnsafeMutableRawPointer?) -> Int32
#endif
