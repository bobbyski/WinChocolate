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

        /// Whether the native object is hidden.
        public var isHidden: Bool

        /// Whether the native object accepts input.
        public var isEnabled: Bool

        /// Native button check state.
        public var buttonState: NSControl.StateValue

        /// Native pop-up button items.
        public var popUpItems: [String]

        /// Native pop-up button selected index.
        public var popUpSelectedIndex: Int

        /// Recorded text color.
        public var textColor: NSColor?

        /// Recorded background color.
        public var backgroundColor: NSColor?

        /// Recorded font.
        public var font: NSFont?
    }

    private var nextRawHandle: UInt = 1

    /// Recorded native object requests by handle.
    public private(set) var records: [NativeHandle: Record] = [:]

    /// Registered control actions by handle.
    public private(set) var actions: [NativeHandle: () -> Void] = [:]

    /// Registered text change actions by handle.
    public private(set) var textChangeActions: [NativeHandle: (String) -> Void] = [:]

    /// Registered mouse-down actions by handle.
    public private(set) var mouseDownActions: [NativeHandle: (NSEvent) -> Void] = [:]

    /// Registered mouse-up actions by handle.
    public private(set) var mouseUpActions: [NativeHandle: (NSEvent) -> Void] = [:]

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
        actions.removeValue(forKey: handle)
        mouseDownActions.removeValue(forKey: handle)
        mouseUpActions.removeValue(forKey: handle)
    }

    /// Removes a recorded native child object.
    public func destroyControl(_ handle: NativeHandle) {
        records.removeValue(forKey: handle)
        actions.removeValue(forKey: handle)
        mouseDownActions.removeValue(forKey: handle)
        mouseUpActions.removeValue(forKey: handle)
    }

    /// Records a view creation request.
    public func createView(frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        makeHandle(kind: "view", text: "", frame: frame, parent: parent)
    }

    /// Records a button creation request.
    public func createButton(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        makeHandle(kind: "button", text: title, frame: frame, parent: parent)
    }

    /// Records a checkbox creation request.
    public func createCheckbox(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        makeHandle(kind: "checkbox", text: title, frame: frame, parent: parent)
    }

    /// Records a radio button creation request.
    public func createRadioButton(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        makeHandle(kind: "radioButton", text: title, frame: frame, parent: parent)
    }

    /// Records a box creation request.
    public func createBox(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        makeHandle(kind: "box", text: title, frame: frame, parent: parent)
    }

    /// Records a text field creation request.
    public func createTextField(text: String, frame: NSRect, parent: NativeHandle?, isEditable: Bool) -> NativeHandle {
        makeHandle(kind: isEditable ? "editableTextField" : "textField", text: text, frame: frame, parent: parent)
    }

    /// Records a pop-up button creation request.
    public func createPopUpButton(items: [String], selectedIndex: Int, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = makeHandle(kind: "popUpButton", text: items.indices.contains(selectedIndex) ? items[selectedIndex] : "", frame: frame, parent: parent)
        records[handle]?.popUpItems = items
        records[handle]?.popUpSelectedIndex = selectedIndex
        return handle
    }

    /// Updates a recorded control text value.
    public func setText(_ text: String, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.text = text
        records[handle] = record
    }

    /// Updates a recorded control frame.
    public func setFrame(_ frame: NSRect, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.frame = frame
        records[handle] = record
    }

    /// Updates a recorded hidden state.
    public func setHidden(_ isHidden: Bool, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.isHidden = isHidden
        records[handle] = record
    }

    /// Updates a recorded enabled state.
    public func setEnabled(_ isEnabled: Bool, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.isEnabled = isEnabled
        records[handle] = record
    }

    /// Updates a recorded text color.
    public func setTextColor(_ color: NSColor?, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.textColor = color
        records[handle] = record
    }

    /// Updates a recorded background color.
    public func setBackgroundColor(_ color: NSColor?, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.backgroundColor = color
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

    /// Records a control action.
    public func registerAction(for handle: NativeHandle, action: @escaping () -> Void) {
        actions[handle] = action
    }

    /// Records a text change action.
    public func registerTextChangeAction(for handle: NativeHandle, action: @escaping (String) -> Void) {
        textChangeActions[handle] = action
    }

    /// Records a mouse-down action.
    public func registerMouseDownAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        mouseDownActions[handle] = action
    }

    /// Records a mouse-up action.
    public func registerMouseUpAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        mouseUpActions[handle] = action
    }

    /// Returns the default alert response without displaying UI.
    public func runAlert(_ alert: NSAlert) -> NSApplication.ModalResponse {
        .alertFirstButtonReturn
    }

    private func makeHandle(kind: String, text: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = NativeHandle(rawValue: nextRawHandle)
        nextRawHandle += 1
        records[handle] = Record(
            kind: kind,
            text: text,
            frame: frame,
            parent: parent,
            isHidden: false,
            isEnabled: true,
            buttonState: .off,
            popUpItems: [],
            popUpSelectedIndex: -1,
            textColor: nil,
            backgroundColor: nil,
            font: nil
        )
        return handle
    }
}
