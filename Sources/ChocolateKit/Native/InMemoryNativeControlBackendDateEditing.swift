// Date-editing test simulations.
//
// The date-field writers a backend has to intercept moved to the class body in
// `InMemoryNativeControlBackendState.swift` — see the note there. What is left
// here drives those recordings from a test and will never be overridden.
extension InMemoryNativeControlBackend {
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
