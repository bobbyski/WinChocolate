/// A date picker control.
///
/// `dateValue` is an absolute instant; the field renders it as a wall clock in
/// the picker's time zone, which is what makes 2026-06-01T00:00Z read
/// `5/31/2026, 8:00:00 PM` on an Eastern machine, as it does on AppKit.
///
/// **Where the behaviour comes from.** LinChocolate renders this control's
/// field itself — building the text, tracking which element is selected, and
/// stepping and typing into it — because GTK has no date field to delegate to.
/// Windows does: `SysDateTimePick32` selects an element on click, moves between
/// elements with the arrow keys, steps the *selected* element from its stepper,
/// and takes typed digits with auto-advance. That is both the behaviour AppKit
/// specifies and the native Windows look, so the control is configured rather
/// than reimplemented. What the framework owns is the AppKit semantics the
/// platform can't know: the element flags, the locale-driven format they imply,
/// the min/max clamp, and `stringValue`.
open class NSDatePicker: NSControl {
    /// Visual style for the date picker.
    ///
    /// Raw values are Apple's.
    public enum Style: UInt, Sendable {
        /// A field with a stepper — AppKit's default. No calendar popup.
        case textFieldAndStepper = 0
        /// A graphical month grid.
        case clockAndCalendar = 1
        /// A field alone.
        case textField = 2
    }

    /// Which date/time elements the picker presents.
    ///
    /// These are Apple's real raw values, and they are **cumulative**:
    /// `.hourMinuteSecond` contains `.hourMinute`, and `.yearMonthDay` contains
    /// `.yearMonth`. Test the wider flag first — `contains(.yearMonth)` is true
    /// for a year-month-day picker. (The previous values here were invented
    /// `1 << n` bits, which compiled fine under symbolic use while every raw
    /// value and every cross-pair `contains` check was wrong.)
    public struct ElementFlags: OptionSet, Sendable {
        public let rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// Hour and minute.
        public static let hourMinute = ElementFlags(rawValue: 0x000c)
        /// Hour, minute and second — contains `.hourMinute`.
        public static let hourMinuteSecond = ElementFlags(rawValue: 0x000e)
        /// The time zone.
        public static let timeZone = ElementFlags(rawValue: 0x0010)
        /// Year and month.
        public static let yearMonth = ElementFlags(rawValue: 0x00c0)
        /// Year, month and day — contains `.yearMonth`.
        public static let yearMonthDay = ElementFlags(rawValue: 0x00e0)
        /// The era.
        public static let era = ElementFlags(rawValue: 0x0100)
    }

    /// Selected date.
    open var dateValue: Date {
        didSet {
            dateValue = clampedDate(dateValue)
            syncNativeDate()
        }
    }

    /// Earliest selectable date.
    open var minDate: Date? {
        didSet {
            dateValue = clampedDate(dateValue)
            syncNativeDate()
        }
    }

    /// Latest selectable date.
    open var maxDate: Date? {
        didSet {
            dateValue = clampedDate(dateValue)
            syncNativeDate()
        }
    }

    /// The locale the field's format follows; `nil` uses the current locale,
    /// as on Apple.
    open var locale: Locale? {
        didSet {
            applyDatePickerFormat()
        }
    }

    /// The zone the value is displayed in; `nil` uses the current zone.
    open var timeZone: TimeZone? {
        didSet {
            if let nativeHandle {
                realizedBackend?.setDatePickerTimeZone(resolvedTimeZone, for: nativeHandle)
            }
            syncNativeDate()
            applyDatePickerFormat()
        }
    }

    /// The locale in effect.
    var resolvedLocale: Locale {
        locale ?? .current
    }

    /// The zone in effect.
    var resolvedTimeZone: TimeZone {
        timeZone ?? .current
    }

    /// The control's natural size.
    ///
    /// The calendar and the two field configurations Apple was probed for use
    /// its measured values; other element combinations were not probed, so they
    /// are measured from the text rather than invented. (AppKit's own numbers:
    /// 275.5 x 148 calendar, 180 x 22 field with date and time, 95 x 22
    /// date-only.)
    open override var intrinsicContentSize: NSSize {
        if datePickerStyle == .clockAndCalendar {
            return NSSize(width: 275.5, height: 148)
        }
        let showsDate = datePickerElements.contains(.yearMonth)
        let showsTime = datePickerElements.contains(.hourMinute)
        if showsDate, showsTime, datePickerElements.contains(.yearMonthDay),
           datePickerElements.contains(.hourMinuteSecond),
           !datePickerElements.contains(.timeZone), !datePickerElements.contains(.era) {
            return NSSize(width: 180, height: 22)
        }
        if showsDate, !showsTime, datePickerElements.contains(.yearMonthDay),
           !datePickerElements.contains(.timeZone), !datePickerElements.contains(.era) {
            return NSSize(width: 95, height: 22)
        }
        let font = self.font ?? NSFont.systemFont(ofSize: 13)
        let measured = displayedText.size(withAttributes: [.font: font])
        let stepper: CGFloat = datePickerStyle == .textFieldAndStepper ? 16 : 0
        return NSSize(width: measured.width + 12 + stepper, height: 22)
    }

    /// Requested visual style.
    open var datePickerStyle: Style = .textFieldAndStepper

    /// Requested element flags.
    open var datePickerElements: ElementFlags = [.yearMonthDay] {
        didSet {
            applyDatePickerFormat()
        }
    }

    /// The field's format, in the Windows date-picker pattern syntax.
    ///
    /// AppKit builds its field from a locale *template*
    /// (`dateFormat(fromTemplate: "Mdyyyyjmmss")` -> `M/d/yyyy, h:mm:ss a`),
    /// which is why it shows a four-digit year that a plain short date style
    /// cannot produce. The Windows equivalent is the locale's own patterns —
    /// `LOCALE_SSHORTDATE` is already `M/d/yyyy` on a modern en-US machine, and
    /// already in the syntax the control wants — so the field order follows the
    /// locale here exactly as it does on Apple, without a template engine.
    var nativeDateFormat: String? {
        // Cumulative flags: the wider one has to be tested first.
        let showsDay = datePickerElements.contains(.yearMonthDay)
        let showsYearMonth = datePickerElements.contains(.yearMonth)
        let showsSeconds = datePickerElements.contains(.hourMinuteSecond)
        let showsTime = datePickerElements.contains(.hourMinute)

        var parts: [String] = []
        if showsDay {
            parts.append(resolvedLocale.shortDatePattern)
        } else if showsYearMonth {
            // Apple's "yyyyM" template renders "5/2026" — the same numeric
            // shape as its year-month-day field, not a spelled-out month. The
            // locale's own year-month format (Windows: "MMMM yyyy") would look
            // native but would not match the sibling field, so the day is
            // dropped from the short date pattern instead, which keeps the
            // locale's field order.
            parts.append(Self.removingDayField(from: resolvedLocale.shortDatePattern))
        }
        if datePickerElements.contains(.era) {
            parts.append("gg")
        }
        if showsSeconds {
            parts.append(resolvedLocale.timePattern)
        } else if showsTime {
            parts.append(resolvedLocale.shortTimePattern)
        }
        if datePickerElements.contains(.timeZone) {
            // The control has no zone field, so the zone is a literal. It is a
            // display-only element on Apple too (nothing steps a zone).
            let abbreviation = resolvedTimeZone.abbreviation(for: dateValue) ?? resolvedTimeZone.identifier
            parts.append(Self.quotedLiteral(abbreviation))
        }
        guard !parts.isEmpty else {
            return nil
        }
        // AppKit's template joins the date and time with ", " ("M/d/yyyy,
        // h:mm:ss a"); the remaining elements follow with a space.
        var format = parts[0]
        for (index, part) in parts.enumerated().dropFirst() {
            let isDateThenTime = index == 1 && (showsDay || showsYearMonth) && showsTime
            format += (isDateThenTime ? ", " : " ") + part
        }
        return format
    }

    /// The text the field is showing, used to measure an unprobed size.
    private var displayedText: String {
        guard let format = nativeDateFormat else {
            return "00/00/0000"
        }
        let formatter = DateFormatter()
        // The control's pattern syntax and Foundation's agree on the numeric
        // fields; only the meridiem differs (`tt` versus `a`).
        formatter.dateFormat = format.replacingOccurrences(of: "tt", with: "a")
        formatter.locale = resolvedLocale
        formatter.timeZone = resolvedTimeZone
        return formatter.string(from: dateValue)
    }

    /// Drops the day field, and one adjacent separator, from a date pattern.
    static func removingDayField(from pattern: String) -> String {
        var tokens = Self.tokenized(pattern)
        guard let dayIndex = tokens.firstIndex(where: { $0.isField && ($0.text.first == "d" || $0.text.first == "D") }) else {
            return pattern
        }
        tokens.remove(at: dayIndex)
        // Removing "d" from "M/d/yyyy" leaves "M//yyyy": drop the separator the
        // day took with it, preferring the one that followed it.
        if dayIndex < tokens.count, !tokens[dayIndex].isField {
            tokens.remove(at: dayIndex)
        } else if dayIndex > 0, !tokens[dayIndex - 1].isField {
            tokens.remove(at: dayIndex - 1)
        }
        while let first = tokens.first, !first.isField {
            tokens.removeFirst()
        }
        while let last = tokens.last, !last.isField {
            tokens.removeLast()
        }
        return tokens.map(\.text).joined()
    }

    /// One run of a date pattern: a field (a run of one letter) or a literal.
    private struct PatternToken {
        let text: String
        let isField: Bool
    }

    /// Splits a pattern into field runs and the separators between them.
    private static func tokenized(_ pattern: String) -> [PatternToken] {
        var tokens: [PatternToken] = []
        var index = pattern.startIndex
        while index < pattern.endIndex {
            let character = pattern[index]
            if character == "'" {
                // A quoted literal run.
                var text = String(character)
                var next = pattern.index(after: index)
                while next < pattern.endIndex, pattern[next] != "'" {
                    text.append(pattern[next])
                    next = pattern.index(after: next)
                }
                if next < pattern.endIndex {
                    text.append("'")
                    next = pattern.index(after: next)
                }
                tokens.append(PatternToken(text: text, isField: false))
                index = next
                continue
            }
            var run = ""
            if character.isLetter {
                while index < pattern.endIndex, pattern[index] == character {
                    run.append(character)
                    index = pattern.index(after: index)
                }
                tokens.append(PatternToken(text: run, isField: true))
            } else {
                while index < pattern.endIndex, !pattern[index].isLetter, pattern[index] != "'" {
                    run.append(pattern[index])
                    index = pattern.index(after: index)
                }
                tokens.append(PatternToken(text: run, isField: false))
            }
        }
        return tokens
    }

    /// Wraps text as a literal the date-picker pattern parser won't read as
    /// format letters.
    private static func quotedLiteral(_ text: String) -> String {
        "'" + text.replacingOccurrences(of: "'", with: "''") + "'"
    }

    private func applyDatePickerFormat() {
        guard let nativeHandle else {
            return
        }

        realizedBackend?.setDatePickerFormat(nativeDateFormat, for: nativeHandle)
    }

    /// Creates a date picker with the current date.
    public required init(frame frameRect: NSRect) {
        self.dateValue = Date()
        super.init(frame: frameRect)
    }

    /// Creates a date picker with an explicit date.
    init(date: Date, frame: NSRect) {
        self.dateValue = date
        super.init(frame: frame)
    }

    /// Date pickers accept keyboard focus.
    open override var acceptsFirstResponder: Bool {
        true
    }

    /// Creates the native date picker peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createDatePicker(date: dateValue, minDate: minDate, maxDate: maxDate, style: datePickerStyle, frame: frame, parent: parent)
    }

    /// Wires native date change notifications into the control action path.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        // The zone has to reach the peer before the value: a SYSTEMTIME is a
        // wall clock, so the backend cannot place an instant without it.
        backend.setDatePickerTimeZone(resolvedTimeZone, for: handle)
        backend.setDatePickerDate(dateValue, minDate: minDate, maxDate: maxDate, for: handle)
        if let format = nativeDateFormat {
            backend.setDatePickerFormat(format, for: handle)
        }
        backend.registerAction(for: handle) { [weak self, weak backend] in
            guard let self, let backend, let nativeHandle = self.nativeHandle else {
                return
            }

            if let date = backend.datePickerDate(for: nativeHandle) {
                self.dateValue = self.clampedDate(date)
            }
            self.sendAction()
        }
        return handle
    }

    /// The value as a string.
    ///
    /// AppKit returns the **full** date and time here — probed on real AppKit
    /// as `Sunday, May 31, 2026 at 8:00:00 PM Eastern Daylight Time`, which is
    /// exactly `DateFormatter(dateStyle: .full, timeStyle: .full)`. It is *not*
    /// the field's text, and it does **not** vary with `datePickerElements`: a
    /// date-only picker returns the same full string, times included.
    open var stringValue: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .full
        formatter.locale = resolvedLocale
        formatter.timeZone = resolvedTimeZone
        return formatter.string(from: dateValue)
    }

    private func syncNativeDate() {
        guard let nativeHandle else {
            return
        }

        realizedBackend?.setDatePickerDate(dateValue, minDate: minDate, maxDate: maxDate, for: nativeHandle)
    }

    private func clampedDate(_ date: Date) -> Date {
        if let minDate, date < minDate {
            return minDate
        }
        if let maxDate, date > maxDate {
            return maxDate
        }
        return date
    }

}
