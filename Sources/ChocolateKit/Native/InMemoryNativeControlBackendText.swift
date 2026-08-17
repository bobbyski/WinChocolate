// Text and scroll-view readers, plus one test hook.
//
// The writers and creators that used to live here moved to the class body in
// `InMemoryNativeControlBackendState.swift` so a backend can override them —
// see the note there.
extension InMemoryNativeControlBackend {
    /// Reads a scroll-view visible origin.
    public func scrollViewContentOffset(for handle: NativeHandle) -> NSPoint {
        records[handle]?.scrollViewContentOffset ?? NSZeroPoint
    }

    /// Reads a recorded text selection.
    public func textSelection(for handle: NativeHandle) -> (location: Int, length: Int) {
        guard let record = records[handle] else {
            return (0, 0)
        }

        return (record.textSelectionLocation, record.textSelectionLength)
    }

    /// Simulates a click outside the watched window, firing the dismiss action.
    public func simulateOutsideClick() {
        outsideClickDismissAction?()
    }
}
