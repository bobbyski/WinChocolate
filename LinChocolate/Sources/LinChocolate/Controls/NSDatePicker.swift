import Foundation

/// AppKit-shaped date picker. `.textFieldAndStepper` (the default) renders a
/// compact field whose individual elements the stepper edits; `.clockAndCalendar`
/// renders a month grid. `dateValue` is the selected date.
open class NSDatePicker: NSControl {

    /// One editable field of the compact style — the character range it occupies
    /// in the displayed text and the calendar component the stepper moves.
    ///
    /// This is what makes the stepper edit *the selected* element, as AppKit
    /// does, rather than always the day.
    struct Segment {
        let range: Range<Int>
        let component: Calendar.Component
        /// Units per step: 1, or 12 for the AM/PM field (half a day).
        let step: Int
        /// The ICU pattern letter this field came from.
        let letter: Character
        /// Digits the field accepts before the selection moves on.
        var maxDigits: Int { letter == "y" || letter == "Y" || letter == "u" ? 4 : 2 }
        /// AM/PM takes letters, not digits.
        var acceptsDigits: Bool { !isMeridiem }
        var isMeridiem: Bool { letter == "a" || letter == "b" || letter == "B" }
        /// `h`/`K` are the 12-hour clocks; `H`/`k` are 24-hour.
        var isTwelveHour: Bool { letter == "h" || letter == "K" }
    }

    /// Digits typed so far into the selected field, and how many.
    ///
    /// AppKit lets you *type* a field's value — stepping a minute to 55 one
    /// click at a time is unusable — accumulating digits until the field is
    /// full or no further digit could be valid, then moving to the next field.
    private var typingBuffer = 0
    private var typingDigits = 0

    private var backingDate: Date
    private var segments: [Segment] = []
    private var selectedSegmentIndex = 0

    /// The selected date, clamped to `minDate`/`maxDate` as on Apple.
    public var dateValue: Date {
        get { backingDate }
        set {
            backingDate = clamped(newValue)
            backend.setDateValue(backingDate, for: handle)
            refreshDisplay()
        }
    }

    /// The earliest selectable date (AppKit's `minDate`); nil = unbounded.
    public var minDate: Date? {
        didSet {
            backend.setDateRange(min: minDate, max: maxDate, for: handle)
            dateValue = backingDate      // re-clamp
        }
    }

    /// The latest selectable date (AppKit's `maxDate`); nil = unbounded.
    public var maxDate: Date? {
        didSet {
            backend.setDateRange(min: minDate, max: maxDate, for: handle)
            dateValue = backingDate
        }
    }

    /// Which elements the picker shows and edits (AppKit's `datePickerElements`).
    public var datePickerElements: NSDatePickerElementFlags = .yearMonthDay {
        didSet { refreshDisplay() }
    }

    /// The locale used to format and order the fields; nil = the current locale.
    public var locale: Locale?
    /// The calendar used for stepping; nil = the current calendar.
    public var calendar: Calendar?
    /// The time zone the value is displayed in; nil = the current zone.
    public var timeZone: TimeZone?

    var resolvedLocale: Locale { locale ?? .current }
    var resolvedTimeZone: TimeZone { timeZone ?? .current }
    var resolvedCalendar: Calendar {
        var resolved = calendar ?? .current
        resolved.timeZone = resolvedTimeZone
        resolved.locale = resolvedLocale
        return resolved
    }

    /// Called when the user picks a day or steps a field.
    public var onDateChange: ((NSDatePicker) -> Void)?
    /// WinChocolate/AppKit control-action alias.
    public var onAction: ((NSDatePicker) -> Void)? {
        get { onDateChange }
        set { onDateChange = newValue }
    }

    /// The value as a string.
    ///
    /// AppKit returns the **full** date and time style here — not the compact
    /// field's text, and independent of `datePickerElements`. Verified against
    /// real AppKit: for 2026-06-01 00:00 UTC in en_US/Eastern it returns
    /// "Sunday, May 31, 2026 at 8:00:00 PM Eastern Daylight Time", which is
    /// exactly `DateFormatter(dateStyle: .full, timeStyle: .full)`.
    public var stringValue: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .full
        formatter.locale = resolvedLocale
        formatter.timeZone = resolvedTimeZone
        formatter.calendar = resolvedCalendar
        return formatter.string(from: backingDate)
    }

    /// The presentation style (AppKit's `datePickerStyle`).
    public var datePickerStyle: NSDatePickerStyle = .textFieldAndStepper {
        didSet {
            backend.setDatePickerGraphical(datePickerStyle == .clockAndCalendar, for: handle)
            backend.setDateValue(backingDate, for: handle)
            wireActions()
            refreshDisplay()
        }
    }

    /// Creates a date picker showing `date`.
    public required convenience init(frame: NSRect) {
        self.init(date: Date(), frame: frame)
    }

    public init(date: Date = Date(), frame: NSRect) {
        self.backingDate = date
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createDatePicker(date: date, frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
        wireActions()
        refreshDisplay()
    }

    // MARK: - Formatting

    /// The ICU pattern for the current elements, in the picker's locale.
    ///
    /// Built from a template so the field order follows the locale, which is
    /// what AppKit does: en_US yields "M/d/yyyy, h:mm:ss a" for
    /// `[.yearMonthDay, .hourMinuteSecond]` — matching real AppKit's render
    /// exactly, including the 4-digit year (a plain `.short` date style would
    /// give "5/31/26").
    private func displayPattern() -> String {
        var template = ""
        if datePickerStyle == .clockAndCalendar {
            // The calendar shows the date; the field beside it edits the TIME.
            template = datePickerElements.contains(.hourMinute) && !datePickerElements.contains(.hourMinuteSecond)
                ? "jmm" : "jmmss"
        } else {
            // Cumulative flags: test the wider one first.
            if datePickerElements.contains(.yearMonthDay) { template += "Mdyyyy" }
            else if datePickerElements.contains(.yearMonth) { template += "yyyyM" }
            if datePickerElements.contains(.era) { template += "G" }
            if datePickerElements.contains(.hourMinuteSecond) { template += "jmmss" }
            else if datePickerElements.contains(.hourMinute) { template += "jmm" }
            if datePickerElements.contains(.timeZone) { template += "z" }
            if template.isEmpty { template = "Mdyyyy" }
        }
        return DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: resolvedLocale)
            ?? "M/d/yyyy"
    }

    /// Renders the pattern into display text, recording each field's character
    /// range so a click can select a field and the stepper can edit it.
    private func renderDisplay() -> (text: String, segments: [Segment]) {
        let pattern = displayPattern()
        var text = ""
        var segments: [Segment] = []
        var index = pattern.startIndex
        while index < pattern.endIndex {
            let character = pattern[index]
            if character == "'" {          // ICU quotes literal runs
                var next = pattern.index(after: index)
                while next < pattern.endIndex, pattern[next] != "'" {
                    text.append(pattern[next])
                    next = pattern.index(after: next)
                }
                index = next < pattern.endIndex ? pattern.index(after: next) : next
                continue
            }
            guard character.isLetter else {
                text.append(character)
                index = pattern.index(after: index)
                continue
            }
            var run = ""
            while index < pattern.endIndex, pattern[index] == character {
                run.append(character)
                index = pattern.index(after: index)
            }
            let start = text.count
            text += formatted(run)
            if let (component, step) = Self.component(for: character) {
                segments.append(Segment(range: start..<text.count, component: component,
                                       step: step, letter: character))
            }
        }
        return (text, segments)
    }

    /// Formats just one pattern run (e.g. "yyyy") of the current value.
    private func formatted(_ run: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = resolvedLocale
        formatter.timeZone = resolvedTimeZone
        formatter.calendar = resolvedCalendar
        formatter.dateFormat = run
        return formatter.string(from: backingDate)
    }

    /// The calendar component a pattern letter edits, and its step size.
    /// Returns nil for fields the stepper can't move (era, zone, weekday).
    private static func component(for letter: Character) -> (Calendar.Component, Int)? {
        switch letter {
        case "y", "Y", "u": return (.year, 1)
        case "M", "L": return (.month, 1)
        case "d": return (.day, 1)
        case "h", "H", "K", "k": return (.hour, 1)
        case "m": return (.minute, 1)
        case "s": return (.second, 1)
        case "a", "b", "B": return (.hour, 12)   // AM/PM flips by half a day
        default: return nil
        }
    }

    // MARK: - Selection and stepping

    private func clamped(_ date: Date) -> Date {
        var result = date
        if let minDate, result < minDate { result = minDate }
        if let maxDate, result > maxDate { result = maxDate }
        return result
    }

    private func refreshDisplay() {
        let rendered = renderDisplay()
        segments = rendered.segments
        if selectedSegmentIndex >= segments.count { selectedSegmentIndex = 0 }
        backend.setDatePickerText(rendered.text, for: handle)
        pushSelection()
    }

    private func pushSelection() {
        guard segments.indices.contains(selectedSegmentIndex) else { return }
        let range = segments[selectedSegmentIndex].range
        backend.setDatePickerSelection(location: range.lowerBound,
                                       length: range.count, for: handle)
    }

    /// Selects the field containing character `offset` — a click in the field.
    private func selectSegment(atCharacter offset: Int) {
        guard !segments.isEmpty else { return }
        let previous = selectedSegmentIndex
        let index: Int
        if let hit = segments.firstIndex(where: { $0.range.contains(offset) }) {
            index = hit
        } else if let left = segments.lastIndex(where: { $0.range.lowerBound <= offset }) {
            index = left                      // a click on a separator picks the field left of it
        } else {
            index = 0
        }
        // Only *changing* field abandons a number being typed. The backend
        // reports selection from the field's cursor, and GTK delivers those
        // notifications in a batch *after* we set the text and selection — so
        // the field re-reports itself mid-typing. Resetting on every report
        // swallowed the second digit: typing "45" landed as "05".
        if index != previous { endTyping() }
        selectedSegmentIndex = index
        pushSelection()
    }

    /// Moves the selection one field left/right (AppKit's arrow keys).
    private func moveSelection(by delta: Int) {
        guard !segments.isEmpty else { return }
        endTyping()
        selectedSegmentIndex = Swift.min(Swift.max(selectedSegmentIndex + delta, 0), segments.count - 1)
        pushSelection()
    }

    /// Steps **the selected field** by one unit — AppKit's behaviour. Stepping
    /// used to always add a day regardless of what was selected.
    private func stepSelectedSegment(_ direction: Int) {
        guard segments.indices.contains(selectedSegmentIndex) else { return }
        endTyping()
        let segment = segments[selectedSegmentIndex]
        guard let stepped = resolvedCalendar.date(byAdding: segment.component,
                                                  value: direction * segment.step,
                                                  to: backingDate) else { return }
        let clampedDate = clamped(stepped)
        guard clampedDate != backingDate else { return }
        dateValue = clampedDate
        onDateChange?(self)
        sendAction()
    }

    /// The valid range for a field, in the units the user types.
    private func valueRange(of segment: Segment) -> ClosedRange<Int> {
        switch segment.component {
        case .year: return 1...9999
        case .month: return 1...12
        case .day:
            let days = resolvedCalendar.range(of: .day, in: .month, for: backingDate) ?? 1..<32
            return days.lowerBound...(days.upperBound - 1)
        case .hour: return segment.isTwelveHour ? 1...12 : 0...23
        case .minute, .second: return 0...59
        default: return 0...0
        }
    }

    /// The date with `value` written into `segment`, or nil if it can't be.
    private func applying(_ value: Int, to segment: Segment) -> Date? {
        var parts = resolvedCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: backingDate)
        switch segment.component {
        case .year: parts.year = value
        case .month: parts.month = value
        case .day: parts.day = value
        case .hour:
            if segment.isTwelveHour {
                // Typing "8" on a 12-hour clock keeps the current half-day.
                let isAfternoon = (parts.hour ?? 0) >= 12
                parts.hour = (value % 12) + (isAfternoon ? 12 : 0)
            } else {
                parts.hour = value
            }
        case .minute: parts.minute = value
        case .second: parts.second = value
        default: return nil
        }
        // Typing a month/year can strand an impossible day — April 31 — and
        // Calendar would roll that forward into May 1. AppKit clamps to the
        // month's last day instead, which is also what stepping already does
        // (May 31 + 1 month = June 30), so the two agree.
        if let year = parts.year, let month = parts.month, let day = parts.day,
           let firstOfMonth = resolvedCalendar.date(from: DateComponents(year: year, month: month, day: 1)),
           let days = resolvedCalendar.range(of: .day, in: .month, for: firstOfMonth) {
            parts.day = Swift.min(day, days.upperBound - 1)
        }
        return resolvedCalendar.date(from: parts)
    }

    /// Types one character into the selected field, as AppKit's date field does.
    private func type(_ text: String) {
        guard let character = text.first else { return }
        if let digit = character.wholeNumberValue, character.isNumber {
            typeDigit(digit)
        } else {
            typeMeridiem(character)
        }
    }

    private func typeDigit(_ digit: Int) {
        guard segments.indices.contains(selectedSegmentIndex) else { return }
        let segment = segments[selectedSegmentIndex]
        guard segment.acceptsDigits else { return }
        let bounds = valueRange(of: segment)

        var candidate = typingBuffer * 10 + digit
        var digits = typingDigits + 1
        if candidate > bounds.upperBound {
            candidate = digit        // the run can't continue — start over on this digit
            digits = 1
        }
        typingBuffer = candidate
        typingDigits = digits

        // A leading 0 in a 1-based field ("0" of "05") isn't a value yet, so
        // hold it and wait for the next digit rather than rejecting the keypress.
        if candidate >= bounds.lowerBound, let typed = applying(candidate, to: segment) {
            commitTyped(typed)
        }
        // Move on once the field is full, or no further digit could be valid.
        if digits >= segment.maxDigits || candidate * 10 > bounds.upperBound {
            endTyping()
            moveSelection(by: 1)
        }
    }

    /// AM/PM takes "a"/"p", as on Apple.
    private func typeMeridiem(_ character: Character) {
        guard segments.indices.contains(selectedSegmentIndex) else { return }
        let segment = segments[selectedSegmentIndex]
        guard segment.isMeridiem else { return }
        let wantsAfternoon: Bool
        switch Character(character.lowercased()) {
        case "a": wantsAfternoon = false
        case "p": wantsAfternoon = true
        default: return
        }
        let hour = resolvedCalendar.component(.hour, from: backingDate)
        guard (hour >= 12) != wantsAfternoon else { return }
        guard let typed = resolvedCalendar.date(byAdding: .hour,
                                                value: wantsAfternoon ? 12 : -12,
                                                to: backingDate) else { return }
        commitTyped(typed)
    }

    private func commitTyped(_ date: Date) {
        let selected = selectedSegmentIndex     // re-rendering must not lose the field
        dateValue = clamped(date)
        selectedSegmentIndex = selected
        pushSelection()
        onDateChange?(self)
        sendAction()
    }

    private func endTyping() {
        typingBuffer = 0
        typingDigits = 0
    }

    private func wireActions() {
        backend.setDateChangeAction(for: handle) { [weak self] date in
            guard let self else { return }
            if self.datePickerStyle == .clockAndCalendar {
                // The calendar can only change the *day*; keep the time of day
                // the user set in the time row, rather than resetting to the
                // calendar's midnight.
                let calendar = self.resolvedCalendar
                let ymd = calendar.dateComponents([.year, .month, .day], from: date)
                let hms = calendar.dateComponents([.hour, .minute, .second], from: self.backingDate)
                var merged = DateComponents()
                merged.year = ymd.year; merged.month = ymd.month; merged.day = ymd.day
                merged.hour = hms.hour; merged.minute = hms.minute; merged.second = hms.second
                self.backingDate = calendar.date(from: merged) ?? date
            } else {
                self.backingDate = date            // sync silently
            }
            self.onDateChange?(self)
            self.sendAction()
        }
        backend.setDateStepAction(for: handle) { [weak self] direction in
            self?.stepSelectedSegment(direction)
        }
        backend.setDatePickerCursorAction(for: handle) { [weak self] offset in
            self?.selectSegment(atCharacter: offset)
        }
        backend.setDatePickerMoveAction(for: handle) { [weak self] delta in
            self?.moveSelection(by: delta)
        }
        backend.setDatePickerTypeAction(for: handle) { [weak self] text in
            self?.type(text)
        }
    }
}
