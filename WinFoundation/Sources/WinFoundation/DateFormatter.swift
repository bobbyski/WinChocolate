/// A minimal Foundation-compatible date/time formatter.
///
/// This shim covers the `dateFormat` pattern path most application and AppKit
/// code uses — numeric fields (`yyyy`/`MM`/`dd`/`HH`/`mm`/`ss`), 12-hour time
/// (`h`/`a`), month and weekday names (`MMM`/`MMMM`/`EEE`/`EEEE`), and
/// single-quoted literals — plus the `dateStyle`/`timeStyle` presets. It is a
/// drop-in for real Foundation's `DateFormatter` once the Windows toolchain
/// can build Foundation; until then it keeps date formatting out of the
/// hand-rolled control code. Locales and time zones beyond UTC are future work.
public final class DateFormatter {
    /// Named presentation styles for `dateStyle`/`timeStyle`.
    public enum Style: Int, Equatable, Sendable {
        case none = 0
        case short = 1
        case medium = 2
        case long = 3
        case full = 4
    }

    /// An explicit Unicode-style format pattern. When empty, `dateStyle` and
    /// `timeStyle` drive the output.
    public var dateFormat: String = ""

    /// The date portion preset used when `dateFormat` is empty.
    public var dateStyle: Style = .none

    /// The time portion preset used when `dateFormat` is empty.
    public var timeStyle: Style = .none

    /// The locale used for the `dateStyle`/`timeStyle` presets. Defaults to the
    /// user's current locale, so styled output matches the system (US dates on
    /// a US machine).
    public var locale: Locale = .current

    /// The zone the wall clock is rendered in. Defaults to the system's zone,
    /// as Foundation's does — a `Date` is an instant, and this is what turns it
    /// into a time of day.
    public var timeZone: TimeZone = .current

    /// Creates a date formatter.
    public init() {}

    /// Returns the string representation of a date.
    ///
    /// An explicit `dateFormat` uses the pattern engine; otherwise the
    /// `dateStyle`/`timeStyle` presets format through the OS locale so the
    /// result matches the system's conventions.
    public func string(from date: Date) -> String {
        let parts = components(from: date)
        if dateFormat.isEmpty, dateStyle != .none || timeStyle != .none,
           let styled = localeStyledString(from: parts, at: date) {
            return styled
        }
        return format(from: parts)
    }

    private func localeStyledString(from c: Components, at date: Date) -> String? {
        let time = WinSystemTime(
            year: UInt16(max(0, c.year)),
            month: UInt16(c.month),
            dayOfWeek: UInt16(max(0, c.weekday - 1)),
            day: UInt16(c.day),
            hour: UInt16(c.hour),
            minute: UInt16(c.minute),
            second: UInt16(c.second),
            milliseconds: 0
        )
        let name = locale.windowsName
        var parts: [String] = []

        if dateStyle != .none {
            let datePart: String?
            switch dateStyle {
            case .short:
                datePart = WinLocale.formatDate(time, localeName: name, flags: WinLocale.dateShortDate, pattern: nil)
            case .medium:
                datePart = WinLocale.formatDate(time, localeName: name, flags: 0, pattern: "MMM d, yyyy")
            case .long:
                datePart = WinLocale.formatDate(time, localeName: name, flags: 0, pattern: "MMMM d, yyyy")
            case .full:
                datePart = WinLocale.formatDate(time, localeName: name, flags: WinLocale.dateLongDate, pattern: nil)
            case .none:
                datePart = nil
            }
            guard let datePart else {
                return nil
            }
            parts.append(datePart)
        }

        if timeStyle != .none {
            let flags: UInt32 = timeStyle == .short ? WinLocale.timeNoSeconds : 0
            guard var timePart = WinLocale.formatTime(time, localeName: name, flags: flags) else {
                return nil
            }
            // The long and full time styles name the zone — the full style
            // spells it out ("Eastern Daylight Time"), which is the tail of
            // AppKit's full/full string.
            switch timeStyle {
            case .full:
                if let zone = timeZone.longName(for: date) {
                    timePart += " \(zone)"
                }
            case .long:
                if let zone = timeZone.abbreviation(for: date) {
                    timePart += " \(zone)"
                }
            case .none, .short, .medium:
                break
            }
            parts.append(timePart)
        }

        guard !parts.isEmpty else {
            return nil
        }
        return parts.joined(separator: dateTimeSeparator)
    }

    /// How the date and time halves are joined.
    ///
    /// ICU joins them per locale and per style: en_US uses "{1} 'at' {0}" for
    /// the full and long date styles and "{1}, {0}" for medium and short —
    /// which is where the "at" in AppKit's "Sunday, May 31, 2026 at 8:00:00 PM"
    /// comes from. Windows has no combining-pattern API, so this reproduces
    /// ICU's rule directly; it holds for en and the Western locales, and is an
    /// approximation elsewhere.
    private var dateTimeSeparator: String {
        guard dateStyle != .none, timeStyle != .none else {
            return " "
        }
        switch dateStyle {
        case .full, .long:
            return " at "
        case .none, .short, .medium:
            return ", "
        }
    }

    /// Parses a date from a string, or returns `nil` when it does not match.
    public func date(from string: String) -> Date? {
        parse(string, using: effectiveFormat)
    }

    // MARK: - Formatting

    private struct Components {
        var year: Int
        var month: Int
        var day: Int
        var hour: Int
        var minute: Int
        var second: Int
        var weekday: Int // 1 = Sunday ... 7 = Saturday
    }

    private static let shortMonths = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private static let longMonths = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    private static let shortWeekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private static let longWeekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    /// The format actually used: `dateFormat` if set, else built from styles.
    private var effectiveFormat: String {
        if !dateFormat.isEmpty {
            return dateFormat
        }

        let datePart = datePattern(for: dateStyle)
        let timePart = timePattern(for: timeStyle)
        return [datePart, timePart].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func datePattern(for style: Style) -> String {
        switch style {
        case .none: return ""
        case .short: return "M/d/yy"
        case .medium: return "MMM d, yyyy"
        case .long: return "MMMM d, yyyy"
        case .full: return "EEEE, MMMM d, yyyy"
        }
    }

    private func timePattern(for style: Style) -> String {
        switch style {
        case .none: return ""
        case .short: return "h:mm a"
        case .medium, .long, .full: return "h:mm:ss a"
        }
    }

    private func format(from c: Components) -> String {
        let pattern = Array(effectiveFormat)
        var result = ""
        var index = 0
        while index < pattern.count {
            let character = pattern[index]
            if character == "'" {
                index += 1
                if index < pattern.count && pattern[index] == "'" {
                    result.append("'")
                    index += 1
                    continue
                }
                while index < pattern.count && pattern[index] != "'" {
                    result.append(pattern[index])
                    index += 1
                }
                index += 1 // skip the closing quote
                continue
            }

            if character.isLetter {
                var runLength = 0
                while index < pattern.count && pattern[index] == character {
                    runLength += 1
                    index += 1
                }
                result += token(character, count: runLength, components: c)
                continue
            }

            result.append(character)
            index += 1
        }
        return result
    }

    private func token(_ character: Character, count: Int, components c: Components) -> String {
        switch character {
        case "y":
            return count == 2 ? padded(c.year % 100, 2) : (count >= 4 ? padded(c.year, 4) : String(c.year))
        case "M":
            switch count {
            case 1: return String(c.month)
            case 2: return padded(c.month, 2)
            case 3: return Self.shortMonths[monthIndex(c.month)]
            default: return Self.longMonths[monthIndex(c.month)]
            }
        case "d":
            return count >= 2 ? padded(c.day, 2) : String(c.day)
        case "H":
            return count >= 2 ? padded(c.hour, 2) : String(c.hour)
        case "h":
            let twelve = c.hour % 12 == 0 ? 12 : c.hour % 12
            return count >= 2 ? padded(twelve, 2) : String(twelve)
        case "m":
            return count >= 2 ? padded(c.minute, 2) : String(c.minute)
        case "s":
            return count >= 2 ? padded(c.second, 2) : String(c.second)
        case "a":
            return c.hour < 12 ? "AM" : "PM"
        case "E":
            let day = weekdayIndex(c.weekday)
            return count >= 4 ? Self.longWeekdays[day] : Self.shortWeekdays[day]
        default:
            return String(repeating: String(character), count: count)
        }
    }

    private func monthIndex(_ month: Int) -> Int {
        min(max(month - 1, 0), 11)
    }

    private func weekdayIndex(_ weekday: Int) -> Int {
        min(max(weekday - 1, 0), 6)
    }

    private func padded(_ value: Int, _ width: Int) -> String {
        let text = String(value)
        return text.count >= width ? text : String(repeating: "0", count: width - text.count) + text
    }

    // MARK: - Calendar math (proleptic Gregorian, in `timeZone`)

    /// The wall clock `date` reads in the formatter's zone.
    private func components(from date: Date) -> Components {
        let instant = Int(date.timeIntervalSince1970.rounded(.down))
        let local = instant + timeZone.secondsFromGMT(for: date)
        let parts = WinCivilTime.parts(fromEpoch: local)
        return Components(year: parts.year, month: parts.month, day: parts.day,
                          hour: parts.hour, minute: parts.minute, second: parts.second,
                          weekday: parts.weekday)
    }

    /// The instant a wall clock reading names in the formatter's zone.
    ///
    /// The offset depends on the instant, and the instant is what is being
    /// computed — so the local reading is first taken as if it were GMT to pick
    /// an offset, then that offset is re-checked against the instant it
    /// implies. One refinement settles every case except the hour that DST
    /// skips or repeats, which is genuinely ambiguous.
    private func timestamp(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int) -> Double {
        let local = WinCivilTime.epoch(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        var offset = timeZone.secondsFromGMT(for: Date(timeIntervalSince1970: Double(local)))
        offset = timeZone.secondsFromGMT(for: Date(timeIntervalSince1970: Double(local - offset)))
        return Double(local - offset)
    }

    // MARK: - Parsing

    private func parse(_ string: String, using pattern: String) -> Date? {
        let format = Array(pattern)
        let input = Array(string)
        var formatIndex = 0
        var inputIndex = 0

        var year = 1_970, month = 1, day = 1, hour = 0, minute = 0, second = 0
        var isPM = false
        var sawMeridiem = false

        func readInt(maxDigits: Int) -> Int? {
            var value = 0
            var read = 0
            while inputIndex < input.count, input[inputIndex].isNumber, read < maxDigits {
                value = value * 10 + Int(String(input[inputIndex]))!
                inputIndex += 1
                read += 1
            }
            return read > 0 ? value : nil
        }

        func matchName(_ names: [String]) -> Int? {
            for (offset, name) in names.enumerated() {
                let candidate = Array(name)
                if inputIndex + candidate.count <= input.count,
                   Array(input[inputIndex..<(inputIndex + candidate.count)]) == candidate {
                    inputIndex += candidate.count
                    return offset
                }
            }
            return nil
        }

        while formatIndex < format.count {
            let character = format[formatIndex]

            if character == "'" {
                formatIndex += 1
                if formatIndex < format.count && format[formatIndex] == "'" {
                    guard inputIndex < input.count, input[inputIndex] == "'" else { return nil }
                    inputIndex += 1
                    formatIndex += 1
                    continue
                }
                while formatIndex < format.count && format[formatIndex] != "'" {
                    guard inputIndex < input.count, input[inputIndex] == format[formatIndex] else { return nil }
                    inputIndex += 1
                    formatIndex += 1
                }
                formatIndex += 1
                continue
            }

            if character.isLetter {
                var runLength = 0
                while formatIndex < format.count && format[formatIndex] == character {
                    runLength += 1
                    formatIndex += 1
                }

                switch character {
                case "y":
                    guard let value = readInt(maxDigits: runLength == 2 ? 2 : 4) else { return nil }
                    year = runLength == 2 ? 2_000 + value : value
                case "M":
                    if runLength >= 3 {
                        guard let index = matchName(runLength >= 4 ? Self.longMonths : Self.shortMonths) else { return nil }
                        month = index + 1
                    } else {
                        guard let value = readInt(maxDigits: 2) else { return nil }
                        month = value
                    }
                case "d":
                    guard let value = readInt(maxDigits: 2) else { return nil }
                    day = value
                case "H":
                    guard let value = readInt(maxDigits: 2) else { return nil }
                    hour = value
                case "h":
                    guard let value = readInt(maxDigits: 2) else { return nil }
                    hour = value % 12
                case "m":
                    guard let value = readInt(maxDigits: 2) else { return nil }
                    minute = value
                case "s":
                    guard let value = readInt(maxDigits: 2) else { return nil }
                    second = value
                case "a":
                    if matchName(["AM", "am"]) != nil {
                        isPM = false
                        sawMeridiem = true
                    } else if matchName(["PM", "pm"]) != nil {
                        isPM = true
                        sawMeridiem = true
                    } else {
                        return nil
                    }
                case "E":
                    _ = matchName(runLength >= 4 ? Self.longWeekdays : Self.shortWeekdays)
                default:
                    return nil
                }
                continue
            }

            // Literal format character must match the input.
            guard inputIndex < input.count, input[inputIndex] == character else {
                return nil
            }
            inputIndex += 1
            formatIndex += 1
        }

        if sawMeridiem && isPM && hour < 12 {
            hour += 12
        }

        return Date(timeIntervalSince1970: timestamp(year: year, month: month, day: day, hour: hour, minute: minute, second: second))
    }
}
