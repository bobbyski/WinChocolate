// Window-state readers, drag simulators and the print-job record type.
//
// The writers moved to the class body in
// `InMemoryNativeControlBackendState.swift` so a backend can override them —
// see the note there. The readers below derive from state those writers
// maintain, so a backend gets the right answer without touching them.
extension InMemoryNativeControlBackend {
    /// Whether a recorded window is shown and not minimized.
    public func isWindowVisible(_ handle: NativeHandle) -> Bool {
        records[handle]?.isHidden == false && !minimizedWindows.contains(handle)
    }

    /// Whether a recorded window is minimized.
    public func isWindowMinimized(_ handle: NativeHandle) -> Bool {
        minimizedWindows.contains(handle)
    }

    /// Whether a recorded window is zoomed.
    public func isWindowZoomed(_ handle: NativeHandle) -> Bool {
        zoomedWindows.contains(handle)
    }

    /// Simulates a native window move for tests.
    public func simulateWindowMove(to origin: NSPoint, for handle: NativeHandle) {
        windowMoveActions[handle]?(origin)
    }

    /// Simulates a native drag entering a registered target.
    @discardableResult
    public func simulateDragEnter(content: NativeDropContent, at location: NSPoint, for handle: NativeHandle) -> Bool {
        dropHandlers[handle]?.entered(content, location) ?? false
    }

    /// Simulates a native drag moving over a registered target.
    @discardableResult
    public func simulateDragMove(to location: NSPoint, for handle: NativeHandle) -> Bool {
        dropHandlers[handle]?.moved(location) ?? false
    }

    /// Simulates a native drag leaving a registered target.
    public func simulateDragExit(for handle: NativeHandle) {
        dropHandlers[handle]?.exited()
    }

    /// Simulates a native drop on a registered target.
    @discardableResult
    public func simulateDrop(content: NativeDropContent, at location: NSPoint, for handle: NativeHandle) -> Bool {
        dropHandlers[handle]?.performed(content, location) ?? false
    }

    /// A recorded print job.
    public struct PrintJob {
        /// The printed control handle.
        public let handle: NativeHandle

        /// The document name shown in the print queue.
        public let jobName: String

        /// The printed content size in points.
        public let contentSize: NSSize

        /// What the view drew into the print context.
        public let recording: RecordingDrawingContext
    }
}
