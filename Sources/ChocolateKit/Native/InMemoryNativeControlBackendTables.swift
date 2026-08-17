// Value readers and interaction simulators.
//
// The writers moved to the class body in
// `InMemoryNativeControlBackendState.swift` so a backend can override them —
// see the note there. The getters below stay because a backend never needs to
// replace them: they read `records`, which the backend writes to from its own
// event handlers, so the inherited answer is already the right one.
extension InMemoryNativeControlBackend {
    /// Reads a recorded button state.
    public func buttonState(for handle: NativeHandle) -> NSControl.StateValue {
        records[handle]?.buttonState ?? .off
    }

    /// Reads recorded pop-up button selection.
    public func popUpButtonSelectedIndex(for handle: NativeHandle) -> Int {
        records[handle]?.popUpSelectedIndex ?? -1
    }

    /// Reads recorded combo-box text.
    public func comboBoxText(for handle: NativeHandle) -> String {
        records[handle]?.text ?? ""
    }

    /// Reads recorded tab-view selection.
    public func tabViewSelectedIndex(for handle: NativeHandle) -> Int {
        records[handle]?.tabViewSelectedIndex ?? -1
    }

    /// Reads recorded slider value.
    public func sliderValue(for handle: NativeHandle) -> Double {
        records[handle]?.sliderValue ?? 0
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

    /// Reads recorded scroller value.
    public func scrollerValue(for handle: NativeHandle) -> Double {
        records[handle]?.sliderValue ?? 0
    }

    /// Reads the recorded scroller hit part.
    public func scrollerPart(for handle: NativeHandle) -> NativeScrollerPart {
        scrollerParts[handle] ?? .none
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

    /// Reads recorded stepper value.
    public func stepperValue(for handle: NativeHandle) -> Double {
        records[handle]?.stepperValue ?? 0
    }
}
