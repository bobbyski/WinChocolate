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

        /// Native slider minimum value.
        public var sliderMinValue: Double

        /// Native slider maximum value.
        public var sliderMaxValue: Double

        /// Native slider value.
        public var sliderValue: Double

        /// Native table column titles.
        public var tableColumns: [String]

        /// Native table column widths.
        public var tableColumnWidths: [CGFloat]

        /// Native table row values.
        public var tableRows: [[String]]

        /// Native table selected row.
        public var tableSelectedRow: Int

        /// Native table clicked row.
        public var tableClickedRow: Int

        /// Native table clicked column.
        public var tableClickedColumn: Int

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

    /// Registered mouse-moved actions by handle.
    public private(set) var mouseMovedActions: [NativeHandle: (NSEvent) -> Void] = [:]

    /// Registered key-down actions by handle.
    public private(set) var keyDownActions: [NativeHandle: (NSEvent) -> Void] = [:]

    /// Registered key-up actions by handle.
    public private(set) var keyUpActions: [NativeHandle: (NSEvent) -> Void] = [:]

    /// The handle most recently asked to take keyboard focus.
    public private(set) var focusedHandle: NativeHandle?

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

    /// Runs deferred work immediately in deterministic tests.
    public func dispatchAsync(_ action: @escaping () -> Void) {
        action()
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
        mouseMovedActions.removeValue(forKey: handle)
        keyDownActions.removeValue(forKey: handle)
        keyUpActions.removeValue(forKey: handle)
    }

    /// Removes a recorded native child object.
    public func destroyControl(_ handle: NativeHandle) {
        records.removeValue(forKey: handle)
        actions.removeValue(forKey: handle)
        mouseDownActions.removeValue(forKey: handle)
        mouseUpActions.removeValue(forKey: handle)
        mouseMovedActions.removeValue(forKey: handle)
        keyDownActions.removeValue(forKey: handle)
        keyUpActions.removeValue(forKey: handle)
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

    /// Records a slider creation request.
    public func createSlider(value: Double, minValue: Double, maxValue: Double, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = makeHandle(kind: "slider", text: "", frame: frame, parent: parent)
        records[handle]?.sliderMinValue = minValue
        records[handle]?.sliderMaxValue = maxValue
        records[handle]?.sliderValue = value
        return handle
    }

    /// Records a scroll view creation request.
    public func createScrollView(frame: NSRect, parent: NativeHandle?, hasVerticalScroller: Bool, hasHorizontalScroller: Bool) -> NativeHandle {
        makeHandle(kind: "scrollView", text: "", frame: frame, parent: parent)
    }

    /// Records a table view creation request.
    public func createTableView(columns: [String], rows: [[String]], selectedRow: Int, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        createTableView(columns: columns, columnWidths: [], rows: rows, selectedRow: selectedRow, frame: frame, parent: parent)
    }

    /// Records a table view creation request with explicit column widths.
    public func createTableView(columns: [String], columnWidths: [CGFloat], rows: [[String]], selectedRow: Int, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = makeHandle(kind: "tableView", text: "", frame: frame, parent: parent)
        records[handle]?.tableColumns = columns
        records[handle]?.tableColumnWidths = columnWidths
        records[handle]?.tableRows = rows
        records[handle]?.tableSelectedRow = selectedRow
        records[handle]?.tableClickedRow = -1
        records[handle]?.tableClickedColumn = -1
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

    /// Records native focus movement.
    public func focusControl(_ handle: NativeHandle) {
        focusedHandle = handle
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

    /// Replaces recorded table rows.
    public func setTableRows(_ rows: [[String]], selectedRow: Int, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.tableRows = rows
        record.tableSelectedRow = selectedRow
        records[handle] = record
    }

    /// Updates recorded table selection.
    public func setTableSelectedRow(_ selectedRow: Int, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.tableSelectedRow = selectedRow
        records[handle] = record
    }

    /// Reads recorded table selection.
    public func tableSelectedRow(for handle: NativeHandle) -> Int {
        records[handle]?.tableSelectedRow ?? -1
    }

    /// Reads recorded table clicked row.
    public func tableClickedRow(for handle: NativeHandle) -> Int {
        records[handle]?.tableClickedRow ?? -1
    }

    /// Reads recorded table clicked column.
    public func tableClickedColumn(for handle: NativeHandle) -> Int {
        records[handle]?.tableClickedColumn ?? -1
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

    /// Records a mouse-moved action.
    public func registerMouseMovedAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        mouseMovedActions[handle] = action
    }

    /// Records a key-down action.
    public func registerKeyDownAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        keyDownActions[handle] = action
    }

    /// Records a key-up action.
    public func registerKeyUpAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        keyUpActions[handle] = action
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
            sliderMinValue: 0,
            sliderMaxValue: 1,
            sliderValue: 0,
            tableColumns: [],
            tableColumnWidths: [],
            tableRows: [],
            tableSelectedRow: -1,
            tableClickedRow: -1,
            tableClickedColumn: -1,
            textColor: nil,
            backgroundColor: nil,
            font: nil
        )
        return handle
    }
}
