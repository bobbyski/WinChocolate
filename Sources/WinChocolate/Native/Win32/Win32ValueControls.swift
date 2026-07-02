#if os(Windows)
extension Win32NativeControlBackend {
    /// Creates a native slider child.
    public func createSlider(value: Double, minValue: Double, maxValue: Double, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        initializeToolbarControls()
        let handle = createChildWindow(
            className: "msctls_trackbar32",
            text: "",
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: wsChild | wsVisible | wsTabStop
        )
        trackbarHandles.insert(handle.rawValue)
        subclassControlForTabKey(handle)
        setSliderRange(minValue: minValue, maxValue: maxValue, for: handle)
        setSliderValue(value, for: handle)
        return handle
    }

    /// Creates a native progress-indicator child.
    public func createProgressIndicator(value: Double, minValue: Double, maxValue: Double, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        initializeProgressControls()
        let handle = createChildWindow(
            className: "msctls_progress32",
            text: "",
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: wsChild | wsVisible
        )
        setProgressIndicatorRange(minValue: minValue, maxValue: maxValue, for: handle)
        setProgressIndicatorValue(value, for: handle)
        return handle
    }

    /// Creates a native scroller child.
    public func createScroller(value: Double, knobProportion: Double, isVertical: Bool, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = createChildWindow(
            className: "SCROLLBAR",
            text: "",
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: wsChild | wsVisible | (isVertical ? sbsVert : sbsHorz)
        )
        setSliderRange(minValue: 0, maxValue: 100, for: handle)
        setScrollerValue(value, knobProportion: knobProportion, for: handle)
        return handle
    }

    /// Creates a native stepper child.
    public func createStepper(value: Double, minValue: Double, maxValue: Double, increment: Double, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        initializeUpDownControls()
        let handle = createChildWindow(
            className: "msctls_updown32",
            text: "",
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: wsChild | wsVisible | wsTabStop | udsArrowKeys
        )
        subclassControlForTabKey(handle)
        setStepperRange(minValue: minValue, maxValue: maxValue, increment: increment, for: handle)
        setStepperValue(value, for: handle)
        return handle
    }

    /// Creates a native date-picker child.
    public func createDatePicker(date: Date, minDate: Date?, maxDate: Date?, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        initializeDateControls()
        let handle = createChildWindow(
            className: "SysDateTimePick32",
            text: "",
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: wsChild | wsVisible | wsTabStop
        )
        subclassControlForTabKey(handle)
        setDatePickerDate(date, minDate: minDate, maxDate: maxDate, for: handle)
        return handle
    }

    /// Updates native slider range.
    public func setSliderRange(minValue: Double, maxValue: Double, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        let lower = Int32(min(minValue, maxValue).rounded())
        let upper = Int32(max(minValue, maxValue).rounded())
        sliderRanges[handle.rawValue] = (Double(lower), Double(upper))
        if trackbarHandles.contains(handle.rawValue) {
            _ = winSendMessageW(hwnd, tbmSetRangeMin, 1, LPARAM(lower))
            _ = winSendMessageW(hwnd, tbmSetRangeMax, 1, LPARAM(upper))
            return
        }
        _ = winSendMessageW(hwnd, sbmSetRange, WPARAM(lower), LPARAM(upper))
    }

    /// Updates native slider value.
    public func setSliderValue(_ value: Double, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        let range = sliderRanges[handle.rawValue] ?? (0, 1)
        let clampedValue = min(max(value, range.minValue), range.maxValue)
        if trackbarHandles.contains(handle.rawValue) {
            _ = winSendMessageW(hwnd, tbmSetPos, 1, LPARAM(Int32(clampedValue.rounded())))
            return
        }
        _ = winSendMessageW(hwnd, sbmSetPos, WPARAM(Int32(clampedValue.rounded())), 1)
    }

    /// Reads native slider value.
    public func sliderValue(for handle: NativeHandle) -> Double {
        guard let hwnd = hwnd(from: handle) else {
            return 0
        }

        if trackbarHandles.contains(handle.rawValue) {
            return Double(winSendMessageW(hwnd, tbmGetPos, 0, 0))
        }

        return Double(winSendMessageW(hwnd, sbmGetPos, 0, 0))
    }

    /// Updates native progress-indicator range.
    public func setProgressIndicatorRange(minValue: Double, maxValue: Double, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        let lower = Int32(min(minValue, maxValue).rounded())
        let upper = Int32(max(minValue, maxValue).rounded())
        _ = winSendMessageW(hwnd, pbmSetRange32, WPARAM(lower), LPARAM(upper))
    }

    /// Updates native progress-indicator value.
    public func setProgressIndicatorValue(_ value: Double, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winSendMessageW(hwnd, pbmSetPos, WPARAM(Int32(value.rounded())), 0)
    }

    /// Updates native scroller state.
    public func setScrollerValue(_ value: Double, knobProportion: Double, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        let clampedValue = min(max(value, 0), 1)
        let clampedProportion = min(max(knobProportion, 0), 1)
        sliderRanges[handle.rawValue] = (0, 100)
        var scrollInfo = SCROLLINFO(
            cbSize: UINT(MemoryLayout<SCROLLINFO>.size),
            fMask: sifRange | sifPage | sifPos,
            nMin: 0,
            nMax: 100,
            nPage: UINT(max(1, Int32((clampedProportion * 100).rounded()))),
            nPos: Int32((clampedValue * 100).rounded()),
            nTrackPos: 0
        )
        withUnsafePointer(to: &scrollInfo) { pointer in
            _ = winSendMessageW(hwnd, sbmSetScrollInfo, 1, LPARAM(bitPattern: pointer))
        }
    }

    /// Reads native scroller value.
    public func scrollerValue(for handle: NativeHandle) -> Double {
        guard let hwnd = hwnd(from: handle) else {
            return 0
        }

        var scrollInfo = SCROLLINFO(cbSize: UINT(MemoryLayout<SCROLLINFO>.size), fMask: sifAll)
        let result = withUnsafeMutablePointer(to: &scrollInfo) { pointer in
            winSendMessageW(hwnd, sbmGetScrollInfo, 0, LPARAM(bitPattern: pointer))
        }
        guard result != 0 else {
            return min(max(sliderValue(for: handle) / 100, 0), 1)
        }

        return min(max(Double(scrollInfo.nPos) / 100, 0), 1)
    }

    /// Updates native stepper range.
    public func setStepperRange(minValue: Double, maxValue: Double, increment: Double, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        let lower = Int32(min(minValue, maxValue).rounded())
        let upper = Int32(max(minValue, maxValue).rounded())
        let current = stepperRanges[handle.rawValue]?.value ?? Double(lower)
        stepperRanges[handle.rawValue] = (
            Double(lower),
            Double(upper),
            max(1, increment.rounded()),
            min(max(current, Double(lower)), Double(upper))
        )
        _ = winSendMessageW(hwnd, udmSetRange32, WPARAM(lower), LPARAM(upper))
    }

    /// Updates native stepper value.
    public func setStepperValue(_ value: Double, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        var range = stepperRanges[handle.rawValue] ?? (0, 100, 1, 0)
        range.value = min(max(value, range.minValue), range.maxValue)
        stepperRanges[handle.rawValue] = range
        _ = winSendMessageW(hwnd, udmSetPos32, 0, LPARAM(Int32(range.value.rounded())))
    }

    /// Reads native stepper value.
    public func stepperValue(for handle: NativeHandle) -> Double {
        stepperRanges[handle.rawValue]?.value ?? 0
    }

    /// Updates native date-picker state.
    public func setDatePickerDate(_ date: Date, minDate: Date?, maxDate: Date?, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        var systemTime = systemTime(from: date)
        withUnsafePointer(to: &systemTime) { pointer in
            _ = winSendMessageW(hwnd, dtmSetSystemTime, gdtValid, LPARAM(bitPattern: pointer))
        }
    }

    /// Reads native date-picker value.
    public func datePickerDate(for handle: NativeHandle) -> Date? {
        guard let hwnd = hwnd(from: handle) else {
            return nil
        }

        var systemTime = SYSTEMTIME()
        let result = withUnsafeMutablePointer(to: &systemTime) { pointer in
            winSendMessageW(hwnd, dtmGetSystemTime, 0, LPARAM(bitPattern: pointer))
        }
        guard WPARAM(result) == gdtValid else {
            return nil
        }

        return date(from: systemTime)
    }

    private func systemTime(from date: Date) -> SYSTEMTIME {
        let components = dateComponents(from: date)
        return SYSTEMTIME(
            wYear: UInt16(components.year),
            wMonth: UInt16(components.month),
            wDayOfWeek: 0,
            wDay: UInt16(components.day),
            wHour: 0,
            wMinute: 0,
            wSecond: 0,
            wMilliseconds: 0
        )
    }

    private func date(from systemTime: SYSTEMTIME) -> Date {
        let days = daysFromCivil(
            year: Int(systemTime.wYear),
            month: Int(systemTime.wMonth),
            day: Int(systemTime.wDay)
        )
        let seconds = Double(days) * 86_400.0
        return Date(timeIntervalSince1970: seconds)
    }

    private func dateComponents(from date: Date) -> (year: Int, month: Int, day: Int) {
        let days = Int((date.timeIntervalSince1970 / 86_400.0).rounded(.down))
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
        return (year, month, day)
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
