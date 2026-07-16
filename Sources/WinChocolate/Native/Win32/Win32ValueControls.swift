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
        // The trackbar requests its channel background via WM_CTLCOLORSTATIC;
        // transparency lets the slider float on the window color.
        transparentBackgroundHandles.insert(handle.rawValue)
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
        if let hwnd = hwnd(from: handle) {
            applyDarkProgressColorsIfNeeded(hwnd)
        }
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
        scrollerHandles.insert(handle.rawValue)
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
    ///
    /// A calendar-style picker uses `SysMonthCal32` (AppKit's
    /// clock-and-calendar); otherwise the compact `SysDateTimePick32` field.
    ///
    /// `.textFieldAndStepper` adds `DTS_UPDOWN`, which is the stepper the style
    /// is named for: the field is created with the up/down arrows instead of
    /// the drop-down calendar button, matching AppKit, where that style has a
    /// stepper and no calendar popup. The arrows step whichever element the
    /// field has selected — AppKit's behaviour, and the control's own.
    public func createDatePicker(date: Date, minDate: Date?, maxDate: Date?, style: NSDatePicker.Style, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        initializeDateControls()
        let showsCalendar = style == .clockAndCalendar
        let handle = createChildWindow(
            className: showsCalendar ? "SysMonthCal32" : "SysDateTimePick32",
            text: "",
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: wsChild | wsVisible | wsTabStop | (style == .textFieldAndStepper ? dtsUpDown : 0)
        )
        if showsCalendar {
            monthCalHandles.insert(handle.rawValue)
            // The month-calendar has a fixed natural grid size; grow the peer to
            // at least that so the last week row and the "Today" footer are not
            // clipped by a smaller requested frame.
            if let hwnd = hwnd(from: handle) {
                var required = RECT()
                let ok = withUnsafeMutablePointer(to: &required) { pointer in
                    winSendMessageW(hwnd, mcmGetMinReqRect, 0, LPARAM(bitPattern: pointer))
                }
                if ok != 0 {
                    let minWidth = Int32(required.right - required.left)
                    let minHeight = Int32(required.bottom - required.top)
                    let width = max(Int32(frame.size.width.rounded()), minWidth)
                    let height = max(Int32(frame.size.height.rounded()), minHeight)
                    _ = winSetWindowPos(hwnd, nil, 0, 0, width, height, swpNoMove | swpNoZOrder | swpNoActivate)
                }
                applyDarkCalendarColorsIfNeeded(hwnd)
            }
        } else {
            subclassControlForTabKey(handle)
            if let hwnd = hwnd(from: handle) {
                // The drop-down calendar honors the explicit palette (applied
                // fresh at DTN_DROPDOWN too). The closed field has no dark
                // theme part and no color API — `DarkMode_CFD` only darkens
                // the hot/open states, so the resting field is owner-drawn
                // dark by the framework (plan 8.5, WM_PAINT in the subclass).
                applyDarkDropDownCalendarColorsIfNeeded(hwnd)
                if NSApplication.shared.effectiveAppearance.winIsDark {
                    darkDatePickerFieldHandles.insert(handle.rawValue)
                    _ = winInvalidateRect(hwnd, nil, 1)
                }
            }
        }
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

    /// Sets the tick-mark count on a trackbar slider.
    ///
    /// A positive count turns on auto-ticks and spaces them across the range;
    /// zero removes them. Only affects trackbar peers.
    public func setSliderTickMarks(count: Int, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle), trackbarHandles.contains(handle.rawValue) else {
            return
        }

        var style = winGetWindowLongPtrW(hwnd, gwlStyle)
        style &= ~LONG_PTR(tbsNoTicks | tbsAutoTicks)
        style |= LONG_PTR(count > 0 ? tbsAutoTicks : tbsNoTicks)
        _ = winSetWindowLongPtrW(hwnd, gwlStyle, style)

        if count > 1 {
            let range = sliderRanges[handle.rawValue] ?? (0, 1)
            let span = max(1.0, range.maxValue - range.minValue)
            let frequency = max(1, Int32((span / Double(count - 1)).rounded()))
            _ = winSendMessageW(hwnd, tbmSetTicFreq, WPARAM(frequency), 0)
        }
        _ = winInvalidateRect(hwnd, nil, 1)
    }

    /// Moves a trackbar's tick marks to the top/left edge (or default bottom/right).
    public func setSliderTickMarkPosition(aboveOrLeading: Bool, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle), trackbarHandles.contains(handle.rawValue) else {
            return
        }

        var style = winGetWindowLongPtrW(hwnd, gwlStyle)
        if aboveOrLeading {
            style |= LONG_PTR(tbsTop)
        } else {
            style &= ~LONG_PTR(tbsTop)
        }
        _ = winSetWindowLongPtrW(hwnd, gwlStyle, style)
        _ = winSetWindowPos(hwnd, nil, 0, 0, 0, 0, swpNoMove | swpNoSize | swpNoZOrder | swpNoActivate | swpFrameChanged)
        _ = winInvalidateRect(hwnd, nil, 1)
    }

    /// Sets whether a trackbar slider is drawn vertically.
    public func setSliderVertical(_ isVertical: Bool, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle), trackbarHandles.contains(handle.rawValue) else {
            return
        }

        var style = winGetWindowLongPtrW(hwnd, gwlStyle)
        if isVertical {
            style |= LONG_PTR(tbsVert)
        } else {
            style &= ~LONG_PTR(tbsVert)
        }
        _ = winSetWindowLongPtrW(hwnd, gwlStyle, style)
        _ = winSetWindowPos(hwnd, nil, 0, 0, 0, 0, swpNoMove | swpNoSize | swpNoZOrder | swpNoActivate | swpFrameChanged)
        _ = winInvalidateRect(hwnd, nil, 1)
    }

    /// Sets the fill color of a progress/level bar (nil restores the default).
    public func setProgressBarColor(_ color: NSColor?, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        // CLR_DEFAULT (0xFF000000) restores the theme color.
        let barColor = color.map { colorRef(from: $0) } ?? 0xFF00_0000
        _ = winSendMessageW(hwnd, pbmSetBarColor, 0, LPARAM(barColor))
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

    /// Makes a level indicator's native bar respond to click/drag.
    public func setLevelIndicatorEditable(_ editable: Bool, minValue: Double, maxValue: Double, for handle: NativeHandle) {
        guard editable else {
            editableLevelHandles.remove(handle.rawValue)
            levelIndicatorRanges.removeValue(forKey: handle.rawValue)
            return
        }

        levelIndicatorRanges[handle.rawValue] = (min(minValue, maxValue), max(minValue, maxValue))
        if editableLevelHandles.insert(handle.rawValue).inserted {
            // Subclass the bar so its window procedure routes mouse messages
            // through the framework, which native progress bars otherwise eat.
            subclassControlForTabKey(handle)
        }
    }

    /// Reads the value a click/drag last set on an editable level indicator.
    public func levelIndicatorValue(for handle: NativeHandle) -> Double {
        levelIndicatorValues[handle.rawValue] ?? 0
    }

    /// Maps a horizontal click position on an editable level bar to a value,
    /// updates the bar, and records it for the framework action.
    func applyLevelIndicatorClick(x: Int, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle), let range = levelIndicatorRanges[handle.rawValue] else {
            return
        }

        var rectangle = RECT()
        _ = winGetClientRect(hwnd, &rectangle)
        let width = Double(rectangle.right - rectangle.left)
        guard width > 0 else {
            return
        }

        let fraction = min(max(Double(x) / width, 0), 1)
        let value = range.minValue + fraction * (range.maxValue - range.minValue)
        levelIndicatorValues[handle.rawValue] = value
        _ = winSendMessageW(hwnd, pbmSetPos, WPARAM(Int32(value.rounded())), 0)
    }

    /// Updates whether a native progress indicator animates indeterminately.
    ///
    /// The classic progress control only supports marquee rendering with the
    /// themed common controls, so the backend animates a sweeping position
    /// with a native timer instead; the modern appearance will add a true
    /// spinner.
    public func setProgressIndicatorIndeterminate(_ isIndeterminate: Bool, animating: Bool, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        if isIndeterminate && animating {
            if marqueePositions[handle.rawValue] == nil {
                subclassControlForTabKey(handle)
                marqueePositions[handle.rawValue] = 0
            }
            _ = winSendMessageW(hwnd, pbmSetRange32, 0, 100)
            _ = winSetTimer(hwnd, 1, 33, nil)
            return
        }

        if marqueePositions.removeValue(forKey: handle.rawValue) != nil {
            _ = winKillTimer(hwnd, 1)
        }
        _ = winSendMessageW(hwnd, pbmSetPos, 0, 0)
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

    /// Reports the scroller part actuated by the last scroll message.
    public func scrollerPart(for handle: NativeHandle) -> NativeScrollerPart {
        scrollerParts[handle.rawValue] ?? .none
    }

    /// Applies the scroller's appearance. Windows draws the native themed
    /// scrollbar (there is no standalone-control overlay style), so `overlay`
    /// has no visual effect here; `knobStyle` selects this scroller's light or
    /// dark visual-styles theme (`.default` follows the window's appearance).
    public func setScrollerAppearance(overlay: Bool, knobStyle: NativeScrollerKnobStyle, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        let dark: Bool
        switch knobStyle {
        case .dark:
            dark = true
        case .light:
            dark = false
        case .default:
            dark = NSApplication.shared.effectiveAppearance.winIsDark
        }
        _ = withWideString(dark ? "DarkMode_Explorer" : "Explorer") { winSetWindowTheme(hwnd, $0, nil) }
        _ = winInvalidateRect(hwnd, nil, 1)
    }

    /// Maps a Win32 scroll notification code to a backend-neutral part.
    func scrollerPart(fromScrollCode code: UInt) -> NativeScrollerPart {
        switch code {
        case sbLineLeft:
            return .decrementLine
        case sbLineRight:
            return .incrementLine
        case sbPageLeft:
            return .decrementPage
        case sbPageRight:
            return .incrementPage
        case sbThumbPosition, sbThumbTrack, sbTop, sbBottom:
            return .knob
        default:
            return .none
        }
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

    /// Toggles the up/down control's wrap-at-ends style.
    public func setStepperWraps(_ wraps: Bool, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        var style = winGetWindowLongPtrW(hwnd, gwlStyle)
        if wraps {
            style |= LONG_PTR(udsWrap)
        } else {
            style &= ~LONG_PTR(udsWrap)
        }
        _ = winSetWindowLongPtrW(hwnd, gwlStyle, style)
    }

    /// Sets the zone a native date picker's wall clock is rendered in.
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

    private func civilFromSeconds(_ total: Int) -> (year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int) {
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
        return (year, month, day, seconds / 3_600, (seconds % 3_600) / 60, seconds % 60)
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
