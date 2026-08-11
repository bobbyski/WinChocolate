#if !USE_WIN_FOUNDATION
struct WinDatePickerSegment {
    let range: Range<Int>
    let component: Calendar.Component
    let step: Int
    let letter: Character

    var maxDigits: Int {
        letter == "y" || letter == "Y" || letter == "u" ? 4 : 2
    }

    var isMeridiem: Bool {
        letter == "a" || letter == "b" || letter == "B"
    }

    var isTwelveHour: Bool {
        letter == "h" || letter == "K"
    }
}

extension NSDatePicker {
    var winResolvedCalendar: Calendar {
        var calendar = Calendar.current
        calendar.timeZone = resolvedTimeZone
        calendar.locale = resolvedLocale
        return calendar
    }

    func winWireDateFieldEditing(backend: NativeControlBackend, handle: NativeHandle) {
        backend.setDateStepAction(for: handle) { [weak self] direction in
            self?.winStepSelectedDateSegment(direction)
        }
        backend.setDatePickerCursorAction(for: handle) { [weak self] offset in
            self?.winSelectDateSegment(at: offset)
        }
        backend.setDatePickerMoveAction(for: handle) { [weak self] delta in
            self?.winMoveDateSelection(by: delta)
        }
        backend.setDatePickerTypeAction(for: handle) { [weak self] text in
            self?.winTypeDateText(text)
        }
    }

    func winRefreshDateField(backend: NativeControlBackend, handle: NativeHandle) {
        guard datePickerStyle != .clockAndCalendar, let pattern = nativeDateFormat else { return }
        let rendered = winRenderDateField(pattern: pattern.replacingOccurrences(of: "tt", with: "a"))
        winDateSegments = rendered.segments
        if winSelectedDateSegment >= winDateSegments.count {
            winSelectedDateSegment = 0
        }
        backend.setDatePickerText(rendered.text, for: handle)
        winPushDateSelection(backend: backend, handle: handle)
    }

    private func winRenderDateField(pattern: String) -> (text: String, segments: [WinDatePickerSegment]) {
        var text = ""
        var segments: [WinDatePickerSegment] = []
        for token in Self.winDatePatternTokens(pattern) {
            guard token.isField, let letter = token.text.first else {
                text += Self.winUnquotedDateLiteral(token.text)
                continue
            }
            let start = text.count
            text += winFormattedDateRun(token.text)
            if let component = Self.winDateComponent(for: letter) {
                segments.append(WinDatePickerSegment(
                    range: start..<text.count,
                    component: component.component,
                    step: component.step,
                    letter: letter
                ))
            }
        }
        return (text, segments)
    }

    private func winFormattedDateRun(_ run: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = resolvedLocale
        formatter.timeZone = resolvedTimeZone
        formatter.calendar = winResolvedCalendar
        formatter.dateFormat = run
        return formatter.string(from: dateValue)
    }

    private static func winDateComponent(for letter: Character) -> (component: Calendar.Component, step: Int)? {
        switch letter {
        case "y", "Y", "u": return (.year, 1)
        case "M", "L": return (.month, 1)
        case "d": return (.day, 1)
        case "h", "H", "K", "k": return (.hour, 1)
        case "m": return (.minute, 1)
        case "s": return (.second, 1)
        case "a", "b", "B": return (.hour, 12)
        default: return nil
        }
    }

    private static func winDatePatternTokens(_ pattern: String) -> [(text: String, isField: Bool)] {
        var tokens: [(text: String, isField: Bool)] = []
        var index = pattern.startIndex
        while index < pattern.endIndex {
            let character = pattern[index]
            var run = String(character)
            index = pattern.index(after: index)
            if character == "'" {
                while index < pattern.endIndex {
                    let next = pattern[index]
                    run.append(next)
                    index = pattern.index(after: index)
                    if next == "'" { break }
                }
                tokens.append((run, false))
            } else if character.isLetter {
                while index < pattern.endIndex, pattern[index] == character {
                    run.append(character)
                    index = pattern.index(after: index)
                }
                tokens.append((run, true))
            } else {
                while index < pattern.endIndex, !pattern[index].isLetter, pattern[index] != "'" {
                    run.append(pattern[index])
                    index = pattern.index(after: index)
                }
                tokens.append((run, false))
            }
        }
        return tokens
    }

    private static func winUnquotedDateLiteral(_ literal: String) -> String {
        guard literal.first == "'", literal.last == "'", literal.count >= 2 else { return literal }
        return String(literal.dropFirst().dropLast()).replacingOccurrences(of: "''", with: "'")
    }

    private func winPushDateSelection(backend: NativeControlBackend? = nil, handle: NativeHandle? = nil) {
        guard winDateSegments.indices.contains(winSelectedDateSegment),
              let backend = backend ?? realizedBackend,
              let handle = handle ?? nativeHandle else { return }
        let range = winDateSegments[winSelectedDateSegment].range
        backend.setDatePickerSelection(location: range.lowerBound, length: range.count, for: handle)
    }

    private func winSelectDateSegment(at offset: Int) {
        guard !winDateSegments.isEmpty else { return }
        let previous = winSelectedDateSegment
        if let hit = winDateSegments.firstIndex(where: { $0.range.contains(offset) }) {
            winSelectedDateSegment = hit
        } else {
            winSelectedDateSegment = winDateSegments.lastIndex(where: { $0.range.lowerBound <= offset }) ?? 0
        }
        if previous != winSelectedDateSegment { winEndDateTyping() }
        winPushDateSelection()
    }

    private func winMoveDateSelection(by delta: Int) {
        guard !winDateSegments.isEmpty else { return }
        winEndDateTyping()
        winSelectedDateSegment = min(max(winSelectedDateSegment + delta, 0), winDateSegments.count - 1)
        winPushDateSelection()
    }

    private func winStepSelectedDateSegment(_ direction: Int) {
        guard winDateSegments.indices.contains(winSelectedDateSegment) else { return }
        winEndDateTyping()
        let segment = winDateSegments[winSelectedDateSegment]
        guard let stepped = winResolvedCalendar.date(
            byAdding: segment.component, value: direction * segment.step, to: dateValue
        ) else { return }
        let next = winClampedDate(stepped)
        guard next != dateValue else { return }
        dateValue = next
        sendAction()
    }

    private func winTypeDateText(_ text: String) {
        guard let character = text.first else { return }
        if let digit = character.wholeNumberValue, character.isNumber {
            winTypeDateDigit(digit)
        } else {
            winTypeMeridiem(character)
        }
    }

    private func winTypeDateDigit(_ digit: Int) {
        guard winDateSegments.indices.contains(winSelectedDateSegment) else { return }
        let segment = winDateSegments[winSelectedDateSegment]
        guard !segment.isMeridiem else { return }
        let bounds = winDateValueRange(for: segment)
        var candidate = winDateTypingBuffer * 10 + digit
        var digits = winDateTypingDigits + 1
        if candidate > bounds.upperBound {
            candidate = digit
            digits = 1
        }
        winDateTypingBuffer = candidate
        winDateTypingDigits = digits
        if candidate >= bounds.lowerBound, let typed = winDate(applying: candidate, to: segment) {
            winCommitTypedDate(typed)
        }
        if digits >= segment.maxDigits || candidate * 10 > bounds.upperBound {
            winEndDateTyping()
            winMoveDateSelection(by: 1)
        }
    }

    private func winTypeMeridiem(_ character: Character) {
        guard winDateSegments.indices.contains(winSelectedDateSegment) else { return }
        let segment = winDateSegments[winSelectedDateSegment]
        guard segment.isMeridiem else { return }
        let lower = character.lowercased()
        guard lower == "a" || lower == "p" else { return }
        let hour = winResolvedCalendar.component(.hour, from: dateValue)
        let wantsAfternoon = lower == "p"
        guard (hour >= 12) != wantsAfternoon,
              let typed = winResolvedCalendar.date(
                byAdding: .hour, value: wantsAfternoon ? 12 : -12, to: dateValue
              ) else { return }
        winCommitTypedDate(typed)
    }

    private func winDateValueRange(for segment: WinDatePickerSegment) -> ClosedRange<Int> {
        switch segment.component {
        case .year: return 1...9999
        case .month: return 1...12
        case .day:
            let days = winResolvedCalendar.range(of: .day, in: .month, for: dateValue) ?? 1..<32
            return days.lowerBound...(days.upperBound - 1)
        case .hour: return segment.isTwelveHour ? 1...12 : 0...23
        case .minute, .second: return 0...59
        default: return 0...0
        }
    }

    private func winDate(applying value: Int, to segment: WinDatePickerSegment) -> Date? {
        var parts = winResolvedCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second], from: dateValue
        )
        switch segment.component {
        case .year: parts.year = value
        case .month: parts.month = value
        case .day: parts.day = value
        case .hour:
            parts.hour = segment.isTwelveHour
                ? (value % 12) + ((parts.hour ?? 0) >= 12 ? 12 : 0)
                : value
        case .minute: parts.minute = value
        case .second: parts.second = value
        default: return nil
        }
        winClampDay(in: &parts)
        return winResolvedCalendar.date(from: parts)
    }

    private func winClampDay(in parts: inout DateComponents) {
        guard let year = parts.year, let month = parts.month, let day = parts.day,
              let first = winResolvedCalendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let days = winResolvedCalendar.range(of: .day, in: .month, for: first) else { return }
        parts.day = min(day, days.upperBound - 1)
    }

    private func winCommitTypedDate(_ typed: Date) {
        let selected = winSelectedDateSegment
        dateValue = winClampedDate(typed)
        winSelectedDateSegment = selected
        winPushDateSelection()
        sendAction()
    }

    private func winEndDateTyping() {
        winDateTypingBuffer = 0
        winDateTypingDigits = 0
    }

    private func winClampedDate(_ date: Date) -> Date {
        if let minDate, date < minDate { return minDate }
        if let maxDate, date > maxDate { return maxDate }
        return date
    }
}
#endif
