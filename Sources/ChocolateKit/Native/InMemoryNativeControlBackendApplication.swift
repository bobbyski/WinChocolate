extension InMemoryNativeControlBackend {

    /// Records a native window level change.
    public func setWindowLevel(_ level: NSWindow.Level, for handle: NativeHandle) {
        records[handle]?.windowLevel = level.rawValue
    }

    /// Records whether a native window hides while the application is inactive.
    public func setHidesOnDeactivate(_ hidesOnDeactivate: Bool, for handle: NativeHandle) {
        records[handle]?.hidesOnDeactivate = hidesOnDeactivate
    }

    /// Records the owning window of an auxiliary window (AppKit's panel-to-owner
    /// relationship), so tests can assert a panel was actually paired.
    public func setWindowParent(_ parent: NativeHandle, for handle: NativeHandle) {
        windowParents[handle] = parent
    }

    /// Returns a fixed font family list for deterministic tests.
    public func fontFamilyNames() -> [String] {
        ["Arial", "Consolas", "Courier New", "Georgia", "Segoe UI", "Tahoma", "Times New Roman", "Verdana"]
    }

    /// Reads the recorded clipboard text.
    public func clipboardString() -> String? {
        clipboardText
    }

    /// Records new clipboard text.
    public func setClipboardString(_ string: String) {
        setClipboardContents(text: string, dataRepresentations: [:])
    }

    /// Reads the recorded clipboard file paths.
    public func clipboardFilePaths() -> [String] {
        clipboardFileList
    }

    /// Records a combined clipboard update.
    public func setClipboardContents(text: String?, dataRepresentations: [String: [UInt8]], filePaths: [String]) {
        clipboardText = text
        clipboardDataRepresentations = dataRepresentations
        clipboardFileList = filePaths
        clipboardChanges += 1
    }

    /// Reads recorded clipboard bytes for a format name.
    public func clipboardData(forFormat formatName: String) -> [UInt8]? {
        clipboardDataRepresentations[formatName]
    }

    /// Returns whether a recorded format is present.
    public func clipboardHasData(forFormat formatName: String) -> Bool {
        clipboardDataRepresentations[formatName] != nil
    }

    /// Clears the recorded clipboard.
    public func clearClipboard() {
        clipboardText = nil
        clipboardDataRepresentations = [:]
        clipboardFileList = []
        clipboardChanges += 1
    }

    /// The recorded clipboard change count.
    public func clipboardChangeCount() -> Int {
        clipboardChanges
    }

    /// The screen frame returned to placement logic, settable for tests.

    /// Scripted system theme: set to simulate Windows dark mode in tests.

    /// Returns the scripted system theme preference.
    public func systemPrefersDarkAppearance() -> Bool {
        simulatedDarkAppearance
    }

    /// Scripted system accent color; `nil` (the default) keeps the fallback
    /// palette so color assertions stay machine-independent.

    /// Returns the scripted accent color.
    public func systemAccentColor() -> NSColor? {
        simulatedAccentColor
    }

    /// Returns the (test-configurable) primary screen frame.
    public func primaryScreenFrame() -> NSRect {
        testScreenFrame
    }

    /// Test-configurable screen list; defaults to one screen matching
    /// `testScreenFrame` whose work area equals its full frame.

    /// Returns the (test-configurable) attached screens.
    public func screenDescriptions() -> [NativeScreenDescription] {
        testScreens ?? [NativeScreenDescription(frame: testScreenFrame, visibleFrame: testScreenFrame)]
    }

    /// Minimized windows, by handle.

    /// Zoomed (maximized) windows, by handle.

    /// Handles currently in full-screen presentation (test-visible).

    /// Windows ordered to the back, in request order.

    /// Records a window minimize/restore.
    public func setWindowMinimized(_ minimized: Bool, for handle: NativeHandle) {
        if minimized {
            minimizedWindows.insert(handle)
        } else {
            minimizedWindows.remove(handle)
        }
    }

    /// Records a window zoom toggle.
    public func toggleWindowZoom(_ handle: NativeHandle) {
        if zoomedWindows.contains(handle) {
            zoomedWindows.remove(handle)
        } else {
            zoomedWindows.insert(handle)
        }
    }

    /// Records a window being sent to the back.
    public func orderWindowBack(_ handle: NativeHandle) {
        windowsOrderedBack.append(handle)
    }

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

    /// Records a window entering or exiting full-screen presentation.
    public func setWindowFullScreen(_ fullScreen: Bool, for handle: NativeHandle) {
        if fullScreen {
            fullScreenWindows.insert(handle)
        } else {
            fullScreenWindows.remove(handle)
        }
    }

    /// Registered window-move actions by handle.

    /// Records a window-move action.
    public func registerWindowMoveAction(for handle: NativeHandle, action: @escaping (NSPoint) -> Void) {
        windowMoveActions[handle] = action
    }

    /// Simulates a native window move for tests.
    public func simulateWindowMove(to origin: NSPoint, for handle: NativeHandle) {
        windowMoveActions[handle]?(origin)
    }

    /// Registered drop handlers by handle.

    /// Handles whose drop registration was removed, in order.

    /// Outbound drags requested through `performDrag`, in order.

    /// The scripted result for the next outbound drag.

    /// Records a drop-target registration.
    public func registerDropTarget(for handle: NativeHandle, handler: NativeDropHandler) {
        dropHandlers[handle] = handler
    }

    /// Records a drop-target removal.
    public func unregisterDropTarget(for handle: NativeHandle) {
        dropHandlers.removeValue(forKey: handle)
        unregisteredDropTargets.append(handle)
    }

    /// Records an outbound drag and returns the scripted result.
    public func performDrag(content: NativeDropContent, from handle: NativeHandle) -> Bool {
        performedDrags.append((content: content, handle: handle))
        return nextDragResult
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

    /// Print jobs run through `runPrintOperation`, oldest first.

    /// The scripted print-dialog outcome; `false` simulates a cancel.

    /// Records a print job, rendering the view into a recording context.
    public func runPrintOperation(for handle: NativeHandle, jobName: String, contentSize: NSSize) -> Bool {
        guard nextPrintResult else {
            return false
        }
        let recording = RecordingDrawingContext()
        drawActions[handle]?(recording, NSRect(origin: NSZeroPoint, size: contentSize))
        printJobs.append(PrintJob(handle: handle, jobName: jobName, contentSize: contentSize, recording: recording))
        return true
    }

    /// Hidden standard-button state per window, for tests.

    /// Records the hidden standard-button state.
}
