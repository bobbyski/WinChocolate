extension InMemoryNativeControlBackend {
    /// Records framework-rendered date-field text.
    public func setDatePickerText(_ text: String, for handle: NativeHandle) {
        datePickerTexts[handle] = text
    }

    /// Records the selected date-field character range.
    public func setDatePickerSelection(location: Int, length: Int, for handle: NativeHandle) {
        datePickerSelections[handle] = (location, length)
    }

    /// Registers a simulated date-step action.
    public func setDateStepAction(for handle: NativeHandle, action: @escaping (Int) -> Void) {
        dateStepActions[handle] = action
    }

    /// Registers a simulated date-field cursor action.
    public func setDatePickerCursorAction(for handle: NativeHandle, action: @escaping (Int) -> Void) {
        datePickerCursorActions[handle] = action
    }

    /// Registers a simulated date-field movement action.
    public func setDatePickerMoveAction(for handle: NativeHandle, action: @escaping (Int) -> Void) {
        datePickerMoveActions[handle] = action
    }

    /// Registers a simulated date-field typing action.
    public func setDatePickerTypeAction(for handle: NativeHandle, action: @escaping (String) -> Void) {
        datePickerTypeActions[handle] = action
    }

    /// Simulates pressing a compact date picker's stepper.
    public func simulateDateStep(_ direction: Int, for handle: NativeHandle) {
        dateStepActions[handle]?(direction)
    }

    /// Simulates clicking a compact date field at a character offset.
    public func simulateDatePickerClick(atCharacter offset: Int, for handle: NativeHandle) {
        datePickerCursorActions[handle]?(offset)
    }

    /// Simulates moving between compact date fields.
    public func simulateDatePickerMove(_ delta: Int, for handle: NativeHandle) {
        datePickerMoveActions[handle]?(delta)
    }

    /// Simulates typing characters into a compact date field.
    public func simulateDatePickerTyping(_ text: String, for handle: NativeHandle) {
        for character in text {
            datePickerTypeActions[handle]?(String(character))
        }
    }
}
