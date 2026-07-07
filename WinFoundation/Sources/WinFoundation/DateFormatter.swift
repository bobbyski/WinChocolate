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
           let styled = localeStyledString(from: parts) {
            return styled
        }
        return format(from: parts)
    }

    private func localeStyledString(from c: Components) -> String? {
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
            guard let timePart = WinLocale.formatTime(time, localeName: name, flags: flags) else {
                return nil
            }
            parts.append(timePart)
        }

        return parts.isEmpty ? nil : parts.joined(separator: " ")
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

    // MARK: - Calendar math (proleptic Gregorian, UTC)

    private func components(from date: Date) -> Components {
        let total = Int(date.timeIntervalSince1970.rounded(.down))
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

        return Components(
            year: year,
            month: month,
            day: day,
            hour: seconds / 3_600,
            minute: (seconds % 3_600) / 60,
            second: seconds % 60,
            weekday: weekday
        )
    }

    private func timestamp(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int) -> Double {
        var adjustedYear = year
        adjustedYear -= month <= 2 ? 1 : 0
        let era = (adjustedYear >= 0 ? adjustedYear : adjustedYear - 399) / 400
        let yoe = adjustedYear - era * 400
        let adjustedMonth = month + (month > 2 ? -3 : 9)
        let doy = (153 * adjustedMonth + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        let days = era * 146_097 + doe - 719_468
        return Double(days) * 86_400.0 + Double(hour * 3_600 + minute * 60 + second)
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
