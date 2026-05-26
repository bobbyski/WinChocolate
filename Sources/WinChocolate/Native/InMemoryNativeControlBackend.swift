/// In-memory backend used before controls are realized and by tests.
///
/// This backend records requested controls without touching the operating
/// system. It keeps framework behavior deterministic in unit tests while the
/// Win32 backend owns real HWND creation for application runs.
public final class InMemoryNativeControlBackend: NativeControlBackend {
    /// A recorded native object request.
    public struct Record: Equatable, Sendable {
        /// The kind of native object requested.
        public var kind: String

        /// The visible title or text.
        public var text: String

        /// The requested frame.
        public var frame: NSRect

        /// The parent native handle, when any.
        public var parent: NativeHandle?
    }

    private var nextRawHandle: UInt = 1

    /// Recorded native object requests by handle.
    public private(set) var records: [NativeHandle: Record] = [:]

    /// Registered control actions by handle.
    public private(set) var actions: [NativeHandle: () -> Void] = [:]

    /// Whether the application run loop has been requested.
    public private(set) var didRunApplication = false

    /// Whether application termination has been requested.
    public private(set) var didTerminateApplication = false

    /// Most recently installed main menu.
    public private(set) weak var installedMainMenu: NSMenu?

    /// Creates an in-memory backend.
    public init() {}

    /// Records that the application run loop was requested.
    public func runApplication() {
        didRunApplication = true
    }

    /// Records that application termination was requested.
    public func terminateApplication() {
        didTerminateApplication = true
    }

    /// Records the installed main menu.
    public func installMainMenu(_ menu: NSMenu?) {
        installedMainMenu = menu
    }

    /// Records a top-level window creation request.
    public func createWindow(title: String, frame: NSRect, styleMask: NSWindow.StyleMask) -> NativeHandle {
        makeHandle(kind: "window", text: title, frame: frame, parent: nil)
    }

    /// Records that a window should be shown.
    public func showWindow(_ handle: NativeHandle) {}

    /// Removes a recorded native object.
    public func closeWindow(_ handle: NativeHandle) {
        records.removeValue(forKey: handle)
    }

    /// Records a view creation request.
    public func createView(frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        makeHandle(kind: "view", text: "", frame: frame, parent: parent)
    }

    /// Records a button creation request.
    public func createButton(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        makeHandle(kind: "button", text: title, frame: frame, parent: parent)
    }

    /// Records a text field creation request.
    public func createTextField(text: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        makeHandle(kind: "textField", text: text, frame: frame, parent: parent)
    }

    /// Updates a recorded control text value.
    public func setText(_ text: String, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.text = text
        records[handle] = record
    }

    /// Records a control action.
    public func registerAction(for handle: NativeHandle, action: @escaping () -> Void) {
        actions[handle] = action
    }

    private func makeHandle(kind: String, text: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = NativeHandle(rawValue: nextRawHandle)
        nextRawHandle += 1
        records[handle] = Record(kind: kind, text: text, frame: frame, parent: parent)
        return handle
    }
}
