#if os(Windows)
extension Win32NativeControlBackend {
    /// Creates a native slider child.
    public func createSlider(value: Double, minValue: Double, maxValue: Double, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        initializeToolbarControls()
        let handle = createChildWindow(
            content: ("msctls_trackbar32", ""),
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
            content: ("msctls_progress32", ""),
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
            content: ("SCROLLBAR", ""),
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
    public func createStepper(
        configuration: NativeStepperConfiguration,
        frame: NSRect,
        parent: NativeHandle?
    ) -> NativeHandle {
        initializeUpDownControls()
        let handle = createChildWindow(
            content: ("msctls_updown32", ""),
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: wsChild | wsVisible | wsTabStop | udsArrowKeys
        )
        subclassControlForTabKey(handle)
        setStepperRange(
            minValue: configuration.minValue,
            maxValue: configuration.maxValue,
            increment: configuration.increment,
            for: handle
        )
        setStepperValue(configuration.value, for: handle)
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
    public func createDatePicker(
        configuration: NativeDatePickerConfiguration,
        frame: NSRect,
        parent: NativeHandle?
    ) -> NativeHandle {
        initializeDateControls()
        let showsCalendar = configuration.style == .clockAndCalendar
        let handle = createChildWindow(
            content: (showsCalendar ? "SysMonthCal32" : "SysDateTimePick32", ""),
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: wsChild | wsVisible | wsTabStop
                | (configuration.style == .textFieldAndStepper ? dtsUpDown : 0)
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
        setDatePickerDate(
            configuration.date,
            minDate: configuration.minDate,
            maxDate: configuration.maxDate,
            for: handle
        )
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
        stepperRanges[handle.rawValue] = WinStepperRange(
            minValue: Double(lower),
            maxValue: Double(upper),
            increment: max(1, increment.rounded()),
            value: min(max(current, Double(lower)), Double(upper))
        )
        _ = winSendMessageW(hwnd, udmSetRange32, WPARAM(lower), LPARAM(upper))
    }

    /// Updates native stepper value.
    public func setStepperValue(_ value: Double, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        var range = stepperRanges[handle.rawValue]
            ?? WinStepperRange(minValue: 0, maxValue: 100, increment: 1, value: 0)
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
}
#endif
