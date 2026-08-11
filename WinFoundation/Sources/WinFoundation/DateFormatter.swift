/// A minimal Foundation-compatible date/time formatter.
///
/// This shim covers the `dateFormat` pattern path most application and AppKit
/// code uses — numeric fields (`yyyy`/`MM`/`dd`/`HH`/`mm`/`ss`), 12-hour time
/// (`h`/`a`), month and weekday names (`MMM`/`MMMM`/`EEE`/`EEEE`), and
/// single-quoted literals — plus the `dateStyle`/`timeStyle` presets. It is a
/// drop-in for real Foundation's `DateFormatter` once the Windows toolchain
/// can build Foundation; until then it keeps date formatting out of the
/// hand-rolled control code. Locales and time zones beyond UTC are future work.
///
/// Inherits `Formatter` because Foundation's does: `NSControl.formatter` is
/// typed `Formatter?`, so `textField.formatter = DateFormatter()` — which
/// compiles on macOS — has to compile here too. Left `open` for the same
/// reason: Foundation's `DateFormatter` is subclassable, and an app that
/// subclasses it must not need a source change to build on Windows.
open class DateFormatter: Formatter {
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
    public override init() {
        super.init()
    }

    /// Formats a `Date` for the control layer, matching Foundation's override.
    /// Anything that is not a `Date` formats as `nil`, so a control holding a
    /// mismatched `objectValue` shows nothing rather than garbage.
    open override func string(for obj: Any?) -> String? {
        guard let date = obj as? Date else { return nil }
        return string(from: date)
    }

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
            guard let datePart = localeDatePart(time, localeName: name) else { return nil }
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

    private func localeDatePart(_ time: WinSystemTime, localeName: String) -> String? {
        switch dateStyle {
        case .short: WinLocale.formatDate(time, localeName: localeName, flags: WinLocale.dateShortDate, pattern: nil)
        case .medium: WinLocale.formatDate(time, localeName: localeName, flags: 0, pattern: "MMM d, yyyy")
        case .long: WinLocale.formatDate(time, localeName: localeName, flags: 0, pattern: "MMMM d, yyyy")
        case .full: WinLocale.formatDate(time, localeName: localeName, flags: WinLocale.dateLongDate, pattern: nil)
        case .none: nil
        }
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
        let parts = WinCivilTime.Parts(
            year: year, month: month, day: day,
            hour: hour, minute: minute, second: second, weekday: 0
        )
        let local = WinCivilTime.epoch(from: parts)
        var offset = timeZone.secondsFromGMT(for: Date(timeIntervalSince1970: Double(local)))
        offset = timeZone.secondsFromGMT(for: Date(timeIntervalSince1970: Double(local - offset)))
        return Double(local - offset)
    }

    // MARK: - Parsing

    private func readInteger(from input: [Character], index: inout Int, maxDigits: Int) -> Int? {
        var value = 0
        var count = 0
        while index < input.count, input[index].isNumber, count < maxDigits {
            guard let digit = Int(String(input[index])) else {
                return nil
            }
            value = value * 10 + digit
            index += 1
            count += 1
        }
        return count > 0 ? value : nil
    }

    private func matchName(_ names: [String], in input: [Character], index: inout Int) -> Int? {
        for (offset, name) in names.enumerated() {
            let candidate = Array(name)
            guard index + candidate.count <= input.count else {
                continue
            }
            if Array(input[index..<(index + candidate.count)]) == candidate {
                index += candidate.count
                return offset
            }
        }
        return nil
    }

    private struct ParsedDateFields {
        var year = 1_970
        var month = 1
        var day = 1
        var hour = 0
        var minute = 0
        var second = 0
        var isPM = false
        var sawMeridiem = false
    }

    private func numericWidth(for character: Character, runLength: Int) -> Int? {
        switch character {
        case "y": return runLength == 2 ? 2 : 4
        case "d", "H", "h", "m", "s": return 2
        default: return nil
        }
    }

    private func applyNumericField(
        _ character: Character, value: Int, runLength: Int, fields: inout ParsedDateFields
    ) {
        switch character {
        case "y": fields.year = runLength == 2 ? 2_000 + value : value
        case "d": fields.day = value
        case "H": fields.hour = value
        case "h": fields.hour = value % 12
        case "m": fields.minute = value
        case "s": fields.second = value
        default: break
        }
    }

    private func applyPatternField(
        _ character: Character,
        runLength: Int,
        input: [Character],
        inputIndex: inout Int,
        fields: inout ParsedDateFields
    ) -> Bool {
        if character == "M" {
            if runLength >= 3 {
                guard let index = matchName(
                    runLength >= 4 ? Self.longMonths : Self.shortMonths,
                    in: input,
                    index: &inputIndex
                ) else { return false }
                fields.month = index + 1
            } else {
                guard let value = readInteger(from: input, index: &inputIndex, maxDigits: 2) else { return false }
                fields.month = value
            }
            return true
        }
        if character == "a" {
            if matchName(["AM", "am"], in: input, index: &inputIndex) != nil {
                fields.isPM = false
            } else if matchName(["PM", "pm"], in: input, index: &inputIndex) != nil {
                fields.isPM = true
            } else {
                return false
            }
            fields.sawMeridiem = true
            return true
        }
        if character == "E" {
            _ = matchName(
                runLength >= 4 ? Self.longWeekdays : Self.shortWeekdays,
                in: input,
                index: &inputIndex
            )
            return true
        }
        guard let width = numericWidth(for: character, runLength: runLength),
              let value = readInteger(from: input, index: &inputIndex, maxDigits: width) else {
            return false
        }
        applyNumericField(character, value: value, runLength: runLength, fields: &fields)
        return true
    }

    private func parse(_ string: String, using pattern: String) -> Date? {
        let format = Array(pattern)
        let input = Array(string)
        var formatIndex = 0
        var inputIndex = 0

        var fields = ParsedDateFields()

        while formatIndex < format.count {
            let character = format[formatIndex]

            if character == "'" {
                guard parseQuotedLiteral(format, formatIndex: &formatIndex, input: input, inputIndex: &inputIndex) else { return nil }
                continue
            }

            if character.isLetter {
                var runLength = 0
                while formatIndex < format.count && format[formatIndex] == character {
                    runLength += 1
                    formatIndex += 1
                }

                guard applyPatternField(
                    character,
                    runLength: runLength,
                    input: input,
                    inputIndex: &inputIndex,
                    fields: &fields
                ) else { return nil }
                continue
            }

            // Literal format character must match the input.
            guard inputIndex < input.count, input[inputIndex] == character else {
                return nil
            }
            inputIndex += 1
            formatIndex += 1
        }

        if fields.sawMeridiem && fields.isPM && fields.hour < 12 {
            fields.hour += 12
        }

        return Date(timeIntervalSince1970: timestamp(
            year: fields.year,
            month: fields.month,
            day: fields.day,
            hour: fields.hour,
            minute: fields.minute,
            second: fields.second
        ))
    }

    private func parseQuotedLiteral(
        _ format: [Character],
        formatIndex: inout Int,
        input: [Character],
        inputIndex: inout Int
    ) -> Bool {
        formatIndex += 1
        if formatIndex < format.count && format[formatIndex] == "'" {
            guard inputIndex < input.count, input[inputIndex] == "'" else { return false }
            inputIndex += 1
            formatIndex += 1
            return true
        }
        while formatIndex < format.count && format[formatIndex] != "'" {
            guard inputIndex < input.count, input[inputIndex] == format[formatIndex] else { return false }
            inputIndex += 1
            formatIndex += 1
        }
        formatIndex += 1
        return true
    }
}
