extension InMemoryNativeControlBackend {
    /// Records tooltip text for a native handle.
    public func setToolTip(_ toolTip: String?, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.toolTip = toolTip
        records[handle] = record
    }

    /// The display scale reported by `winDisplayScale()`, scriptable for tests.

    /// Returns the scripted display scale.
    public func winDisplayScale() -> CGFloat { scriptedDisplayScale }

    /// Records the explicit accessibility name pushed from `accessibilityLabel`.
    public func setAccessibilityName(_ name: String?, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.accessibilityName = name
        records[handle] = record
    }

    /// Updates a recorded font.
    public func setFont(_ font: NSFont?, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.font = font
        records[handle] = record
    }

    /// Records an image-view bitmap source update.
    public func setImagePath(_ imagePath: String?, description: String, tint: NSColor?, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.imagePath = imagePath
        record.imageTint = tint
        record.text = description
        records[handle] = record
    }

    /// Updates a recorded button state.
    public func setButtonState(_ state: NSControl.StateValue, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.buttonState = state
        records[handle] = record
    }

    /// Reads a recorded button state.
    public func buttonState(for handle: NativeHandle) -> NSControl.StateValue {
        records[handle]?.buttonState ?? .off
    }

    /// Replaces recorded pop-up button items.
    public func setPopUpButtonItems(_ items: [String], selectedIndex: Int, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.popUpItems = items
        record.popUpSelectedIndex = selectedIndex
        record.text = items.indices.contains(selectedIndex) ? items[selectedIndex] : ""
        records[handle] = record
    }

    /// Updates recorded pop-up button selection.
    public func setPopUpButtonSelectedIndex(_ selectedIndex: Int, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.popUpSelectedIndex = selectedIndex
        record.text = record.popUpItems.indices.contains(selectedIndex) ? record.popUpItems[selectedIndex] : ""
        records[handle] = record
    }

    /// Reads recorded pop-up button selection.
    public func popUpButtonSelectedIndex(for handle: NativeHandle) -> Int {
        records[handle]?.popUpSelectedIndex ?? -1
    }

    /// Replaces recorded combo-box items.
    public func setComboBoxItems(_ items: [String], text: String, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.comboBoxItems = items
        record.text = text
        records[handle] = record
    }

    /// Reads recorded combo-box text.
    public func comboBoxText(for handle: NativeHandle) -> String {
        records[handle]?.text ?? ""
    }

    /// Replaces recorded tab-view items.
    public func setTabViewItems(_ items: [String], selectedIndex: Int, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.tabViewItems = items
        record.tabViewSelectedIndex = selectedIndex
        record.text = items.indices.contains(selectedIndex) ? items[selectedIndex] : ""
        records[handle] = record
    }

    /// Updates recorded tab-view selection.
    public func setTabViewSelectedIndex(_ selectedIndex: Int, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.tabViewSelectedIndex = selectedIndex
        record.text = record.tabViewItems.indices.contains(selectedIndex) ? record.tabViewItems[selectedIndex] : ""
        records[handle] = record
    }

    /// Reads recorded tab-view selection.
    public func tabViewSelectedIndex(for handle: NativeHandle) -> Int {
        records[handle]?.tabViewSelectedIndex ?? -1
    }

    /// Updates recorded slider range.
    public func setSliderRange(minValue: Double, maxValue: Double, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.sliderMinValue = minValue
        record.sliderMaxValue = maxValue
        records[handle] = record
    }

    /// Updates recorded slider value.
    public func setSliderValue(_ value: Double, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.sliderValue = value
        records[handle] = record
    }

    /// Reads recorded slider value.
    public func sliderValue(for handle: NativeHandle) -> Double {
        records[handle]?.sliderValue ?? 0
    }

    /// Updates recorded progress indicator range.
    public func setProgressIndicatorRange(minValue: Double, maxValue: Double, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.progressMinValue = minValue
        record.progressMaxValue = maxValue
        records[handle] = record
    }

    /// Updates recorded progress indicator value.
    public func setProgressIndicatorValue(_ value: Double, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.progressValue = value
        records[handle] = record
    }

    /// Editable level indicators and their ranges/last-set values.

    /// Records whether a level indicator is editable and its value range.
    public func setLevelIndicatorEditable(_ editable: Bool, minValue: Double, maxValue: Double, for handle: NativeHandle) {
        if editable {
            editableLevelRanges[handle] = (min(minValue, maxValue), max(minValue, maxValue))
        } else {
            editableLevelRanges.removeValue(forKey: handle)
        }
    }

    /// Reads the value a click/drag last set on an editable level indicator.
    public func levelIndicatorValue(for handle: NativeHandle) -> Double {
        levelIndicatorValues[handle] ?? 0
    }

    /// Test helper: pretends the user clicked an editable level bar at a
    /// horizontal fraction, setting the value and firing the action.
    public func simulateLevelIndicatorClick(fraction: Double, for handle: NativeHandle) {
        guard let range = editableLevelRanges[handle] else {
            return
        }

        let clamped = min(max(fraction, 0), 1)
        levelIndicatorValues[handle] = range.minValue + clamped * (range.maxValue - range.minValue)
        actions[handle]?()
    }

    /// Updates recorded scroller state.
    public func setScrollerValue(_ value: Double, knobProportion: Double, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.sliderValue = value
        record.scrollerKnobProportion = knobProportion
        records[handle] = record
    }

    /// Reads recorded scroller value.
    public func scrollerValue(for handle: NativeHandle) -> Double {
        records[handle]?.sliderValue ?? 0
    }

    /// Reads the recorded scroller hit part.
    public func scrollerPart(for handle: NativeHandle) -> NativeScrollerPart {
        scrollerParts[handle] ?? .none
    }

    /// Records the scroller's requested appearance.
    public func setScrollerAppearance(overlay: Bool, knobStyle: NativeScrollerKnobStyle, for handle: NativeHandle) {
        scrollerOverlays[handle] = overlay
        scrollerKnobStyles[handle] = knobStyle
    }

    /// Test helper: pretends the user actuated a scroller part, optionally
    /// moving the value, and fires the registered action (mirroring the Win32
    /// scroll-message path).
    public func simulateScrollerPart(_ part: NativeScrollerPart, value: Double? = nil, for handle: NativeHandle) {
        scrollerParts[handle] = part
        if let value {
            records[handle]?.sliderValue = value
        }
        actions[handle]?()
    }

    /// Updates recorded stepper range.
    public func setStepperRange(minValue: Double, maxValue: Double, increment: Double, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.stepperMinValue = minValue
        record.stepperMaxValue = maxValue
        record.stepperIncrement = increment
        records[handle] = record
    }

    /// Updates recorded stepper value.
    public func setStepperValue(_ value: Double, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.stepperValue = value
        records[handle] = record
    }

    /// Reads recorded stepper value.
    public func stepperValue(for handle: NativeHandle) -> Double {
        records[handle]?.stepperValue ?? 0
    }

    /// Records whether a stepper wraps at its range ends.

    /// Performs the `setStepperWraps` operation.
    public func setStepperWraps(_ wraps: Bool, for handle: NativeHandle) {
        stepperWraps[handle] = wraps
    }

    /// Updates recorded date picker state.
    public func setDatePickerDate(_ date: Date, minDate: Date?, maxDate: Date?, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.datePickerDate = date
        record.datePickerMinDate = minDate
        record.datePickerMaxDate = maxDate
        records[handle] = record
    }

    /// Reads recorded date picker value.
}
