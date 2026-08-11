#if os(Windows)
extension Win32NativeControlBackend {
    /// Sets the time zone used to translate a date picker's native wall-clock value.
    public func setDatePickerTimeZone(_ timeZone: TimeZone, for handle: NativeHandle) {
        datePickerTimeZones[handle.rawValue] = timeZone
    }

    /// Updates native date-picker state.
    public func setDatePickerDate(_ date: Date, minDate: Date?, maxDate: Date?, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        let zone = datePickerTimeZone(for: handle)
        var wallClock = systemTime(from: date, in: zone)
        let isCalendar = monthCalHandles.contains(handle.rawValue)
        let message = isCalendar ? mcmSetCurSel : dtmSetSystemTime
        let wParam: WPARAM = isCalendar ? 0 : gdtValid
        withUnsafePointer(to: &wallClock) { pointer in
            _ = winSendMessageW(hwnd, message, wParam, LPARAM(bitPattern: pointer))
        }
        if isCalendar {
            // Track the set value so a paint-time notification is not mistaken
            // for a user selection change.
            monthCalDates[handle.rawValue] = date
        }

        // Push the range to the control as well as clamping in the framework:
        // AppKit's picker refuses to leave its range, so the field should too
        // rather than accept an out-of-range entry and have it corrected after
        // the fact. The bounds were previously accepted and dropped here.
        var bounds = (SYSTEMTIME(), SYSTEMTIME())
        var flags: WPARAM = 0
        if let minDate {
            bounds.0 = systemTime(from: minDate, in: zone)
            flags |= gdtrMin
        }
        if let maxDate {
            bounds.1 = systemTime(from: maxDate, in: zone)
            flags |= gdtrMax
        }
        withUnsafePointer(to: &bounds) { pointer in
            _ = winSendMessageW(hwnd, isCalendar ? mcmSetRange : dtmSetRange, flags, LPARAM(bitPattern: pointer))
        }
    }

    /// Sets a native date-picker display format string.
    ///
    /// A `nil` format restores the control's default date display; a format
    /// string (for example `HH':'mm':'ss` for time) switches the fields the
    /// picker shows without recreating it.
    public func setDatePickerFormat(_ format: String?, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        // The month-calendar peer has no field-format string.
        guard !monthCalHandles.contains(handle.rawValue) else {
            return
        }

        withOptionalWideString(format) { formatPointer in
            _ = winSendMessageW(hwnd, dtmSetFormatW, 0, Int(bitPattern: formatPointer))
        }
    }

    /// Reads native date-picker value.
    public func datePickerDate(for handle: NativeHandle) -> Date? {
        guard let hwnd = hwnd(from: handle) else {
            return nil
        }

        var systemTime = SYSTEMTIME()
        if monthCalHandles.contains(handle.rawValue) {
            let ok = withUnsafeMutablePointer(to: &systemTime) { pointer in
                winSendMessageW(hwnd, mcmGetCurSel, 0, LPARAM(bitPattern: pointer))
            }
            return ok != 0 ? date(from: systemTime, in: datePickerTimeZone(for: handle)) : nil
        }

        let result = withUnsafeMutablePointer(to: &systemTime) { pointer in
            winSendMessageW(hwnd, dtmGetSystemTime, 0, LPARAM(bitPattern: pointer))
        }
        guard WPARAM(result) == gdtValid else {
            return nil
        }

        return date(from: systemTime, in: datePickerTimeZone(for: handle))
    }

    /// The zone a handle's wall clock is rendered in — AppKit's
    /// `NSDatePicker.timeZone`, which the framework resolves and pushes here.
    func datePickerTimeZone(for handle: NativeHandle) -> TimeZone {
        datePickerTimeZones[handle.rawValue] ?? .current
    }

    /// The wall clock `date` reads in a handle's zone.
    ///
    /// `SYSTEMTIME` is a wall clock with no zone attached, so the instant has
    /// to be converted before it is handed over. This used to hardcode the
    /// time fields to zero and format in UTC, which discarded the time of day
    /// twice over: the demo's 2026-06-01T00:00Z rendered `6/1/2026 12:00:00
    /// AM` where AppKit, on an Eastern machine, renders `5/31/2026, 8:00:00
    /// PM`.
    private func systemTime(from date: Date, in zone: TimeZone) -> SYSTEMTIME {
        let local = Int(date.timeIntervalSince1970.rounded(.down)) + zone.secondsFromGMT(for: date)
        let parts = civilFromSeconds(local)
        return SYSTEMTIME(
            wYear: UInt16(clamping: parts.year),
            wMonth: UInt16(clamping: parts.month),
            wDayOfWeek: 0,
            wDay: UInt16(clamping: parts.day),
            wHour: UInt16(clamping: parts.hour),
            wMinute: UInt16(clamping: parts.minute),
            wSecond: UInt16(clamping: parts.second),
            wMilliseconds: 0
        )
    }

    /// The instant a handle's wall clock names in its zone.
    ///
    /// The offset depends on the instant being computed, so the reading is
    /// first taken as if it were GMT to pick an offset, then that offset is
    /// re-checked against the instant it implies.
    private func date(from systemTime: SYSTEMTIME, in zone: TimeZone) -> Date {
        let days = daysFromCivil(
            year: Int(systemTime.wYear),
            month: Int(systemTime.wMonth),
            day: Int(systemTime.wDay)
        )
        let local = days * 86_400
            + Int(systemTime.wHour) * 3_600
            + Int(systemTime.wMinute) * 60
            + Int(systemTime.wSecond)
        var offset = zone.secondsFromGMT(for: Date(timeIntervalSince1970: Double(local)))
        offset = zone.secondsFromGMT(for: Date(timeIntervalSince1970: Double(local - offset)))
        return Date(timeIntervalSince1970: Double(local - offset))
    }

    private struct CivilTime {
        let year: Int
        let month: Int
        let day: Int
        let hour: Int
        let minute: Int
        let second: Int
    }

    private func civilFromSeconds(_ total: Int) -> CivilTime {
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
        return CivilTime(
            year: year,
            month: month,
            day: day,
            hour: seconds / 3_600,
            minute: (seconds % 3_600) / 60,
            second: seconds % 60
        )
    }

    private func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        var adjustedYear = year
        adjustedYear -= month <= 2 ? 1 : 0
        let era = (adjustedYear >= 0 ? adjustedYear : adjustedYear - 399) / 400
        let yoe = adjustedYear - era * 400
        let adjustedMonth = month + (month > 2 ? -3 : 9)
        let doy = (153 * adjustedMonth + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }
}
#endif
