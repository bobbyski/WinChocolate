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

        /// Native combo-box items.
        public var comboBoxItems: [String]

        /// Native image-view file path.
        public var imagePath: String?

        /// Native tab-view items.
        public var tabViewItems: [String]

        /// Native tab-view selected index.
        public var tabViewSelectedIndex: Int

        /// Native toolbar items.
        public var toolbarItems: [NativeToolbarItem]

        /// Native slider minimum value.
        public var sliderMinValue: Double

        /// Native slider maximum value.
        public var sliderMaxValue: Double

        /// Native slider value.
        public var sliderValue: Double

        /// Native progress minimum value.
        public var progressMinValue: Double

        /// Native progress maximum value.
        public var progressMaxValue: Double

        /// Native progress value.
        public var progressValue: Double

        /// Native scroller knob proportion.
        public var scrollerKnobProportion: Double

        /// Whether the native scroller is vertical.
        public var scrollerIsVertical: Bool
        /// Native scroll-view document size.
        public var scrollViewContentSize: NSSize
        /// Native scroll-view viewport size.
        public var scrollViewViewportSize: NSSize
        /// Native scroll-view visible origin.
        public var scrollViewContentOffset: NSPoint

        /// Native stepper minimum value.
        public var stepperMinValue: Double

        /// Native stepper maximum value.
        public var stepperMaxValue: Double

        /// Native stepper increment.
        public var stepperIncrement: Double

        /// Native stepper value.
        public var stepperValue: Double

        /// Native date picker value.
        public var datePickerDate: Date?

        /// Native date picker minimum date.
        public var datePickerMinDate: Date?

        /// Native date picker maximum date.
        public var datePickerMaxDate: Date?

        /// Native table column titles.
        public var tableColumns: [String]

        /// Native table column widths.
        public var tableColumnWidths: [CGFloat]

        /// Native table row values.
        public var tableRows: [[String]]

        /// Native table selected row.
        public var tableSelectedRow: Int

        /// Last native table row requested visible.
        public var tableVisibleRow: Int

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

        /// Whether a top-level window requested the application menu bar.
        public var usesMainMenu: Bool
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

    /// Registered mouse-dragged actions by handle.
    public private(set) var mouseDraggedActions: [NativeHandle: (NSEvent) -> Void] = [:]

    /// Registered key-down actions by handle.
    public private(set) var keyDownActions: [NativeHandle: (NSEvent) -> Void] = [:]

    /// Registered key-up actions by handle.
    public private(set) var keyUpActions: [NativeHandle: (NSEvent) -> Void] = [:]

    /// Registered native window close actions by handle.
    public private(set) var windowCloseActions: [NativeHandle: () -> Void] = [:]

    /// Registered native window resize actions by handle.
    public private(set) var windowResizeActions: [NativeHandle: (NSSize) -> Void] = [:]

    /// Registered toolbar item actions by handle.
    public private(set) var toolbarActions: [NativeHandle: (String) -> Void] = [:]

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
    public func createWindow(title: String, frame: NSRect, styleMask: NSWindow.StyleMask, usesMainMenu: Bool) -> NativeHandle {
        let handle = makeHandle(kind: "window", text: title, frame: frame, parent: nil)
        records[handle]?.usesMainMenu = usesMainMenu
        return handle
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
        mouseDraggedActions.removeValue(forKey: handle)
        keyDownActions.removeValue(forKey: handle)
        keyUpActions.removeValue(forKey: handle)
        toolbarActions.removeValue(forKey: handle)
        windowResizeActions.removeValue(forKey: handle)
        windowCloseActions.removeValue(forKey: handle)?()
    }

    /// Records a native window close action.
    public func registerWindowCloseAction(for handle: NativeHandle, action: @escaping () -> Void) {
        windowCloseActions[handle] = action
    }

    /// Records a native window resize action.
    public func registerWindowResizeAction(for handle: NativeHandle, action: @escaping (NSSize) -> Void) {
        windowResizeActions[handle] = action
    }

    /// Removes a recorded native child object.
    public func destroyControl(_ handle: NativeHandle) {
        records.removeValue(forKey: handle)
        actions.removeValue(forKey: handle)
        mouseDownActions.removeValue(forKey: handle)
        mouseUpActions.removeValue(forKey: handle)
        mouseMovedActions.removeValue(forKey: handle)
        mouseDraggedActions.removeValue(forKey: handle)
        keyDownActions.removeValue(forKey: handle)
        keyUpActions.removeValue(forKey: handle)
        toolbarActions.removeValue(forKey: handle)
        windowResizeActions.removeValue(forKey: handle)
    }

    /// Records a view creation request.
    public func createView(frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        makeHandle(kind: "view", text: "", frame: frame, parent: parent)
    }

    /// Records a button creation request.
    public func createButton(title: String, frame: NSRect, parent: NativeHandle?, isBordered: Bool) -> NativeHandle {
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

    /// Records a secure text field creation request.
    public func createSecureTextField(text: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        makeHandle(kind: "secureTextField", text: text, frame: frame, parent: parent)
    }

    /// Records a text view creation request.
    public func createTextView(text: String, frame: NSRect, parent: NativeHandle?, isEditable: Bool) -> NativeHandle {
        makeHandle(kind: isEditable ? "editableTextView" : "textView", text: text, frame: frame, parent: parent)
    }

    /// Records a pop-up button creation request.
    public func createPopUpButton(items: [String], selectedIndex: Int, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = makeHandle(kind: "popUpButton", text: items.indices.contains(selectedIndex) ? items[selectedIndex] : "", frame: frame, parent: parent)
        records[handle]?.popUpItems = items
        records[handle]?.popUpSelectedIndex = selectedIndex
        return handle
    }

    /// Records a combo-box creation request.
    public func createComboBox(items: [String], text: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = makeHandle(kind: "comboBox", text: text, frame: frame, parent: parent)
        records[handle]?.comboBoxItems = items
        return handle
    }

    /// Records an image-view creation request.
    public func createImageView(description: String, imagePath: String?, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = makeHandle(kind: "imageView", text: description, frame: frame, parent: parent)
        records[handle]?.imagePath = imagePath
        return handle
    }

    /// Records a tab-view creation request.
    public func createTabView(items: [String], selectedIndex: Int, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = makeHandle(kind: "tabView", text: items.indices.contains(selectedIndex) ? items[selectedIndex] : "", frame: frame, parent: parent)
        records[handle]?.tabViewItems = items
        records[handle]?.tabViewSelectedIndex = selectedIndex
        return handle
    }

    /// Records a toolbar creation request.
    public func createToolbar(items: [NativeToolbarItem], frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = makeHandle(kind: "toolbar", text: "", frame: frame, parent: parent)
        records[handle]?.toolbarItems = items
        return handle
    }

    /// Replaces recorded toolbar items.
    public func setToolbarItems(_ items: [NativeToolbarItem], for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.toolbarItems = items
        records[handle] = record
    }

    /// Records a toolbar action.
    public func registerToolbarAction(for handle: NativeHandle, action: @escaping (String) -> Void) {
        toolbarActions[handle] = action
    }

    /// Records a slider creation request.
    public func createSlider(value: Double, minValue: Double, maxValue: Double, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = makeHandle(kind: "slider", text: "", frame: frame, parent: parent)
        records[handle]?.sliderMinValue = minValue
        records[handle]?.sliderMaxValue = maxValue
        records[handle]?.sliderValue = value
        return handle
    }

    /// Records a progress indicator creation request.
    public func createProgressIndicator(value: Double, minValue: Double, maxValue: Double, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = makeHandle(kind: "progressIndicator", text: "", frame: frame, parent: parent)
        records[handle]?.progressMinValue = minValue
        records[handle]?.progressMaxValue = maxValue
        records[handle]?.progressValue = value
        return handle
    }

    /// Records a scroller creation request.
    public func createScroller(value: Double, knobProportion: Double, isVertical: Bool, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = makeHandle(kind: "scroller", text: "", frame: frame, parent: parent)
        records[handle]?.sliderMinValue = 0
        records[handle]?.sliderMaxValue = 1
        records[handle]?.sliderValue = value
        records[handle]?.scrollerKnobProportion = knobProportion
        records[handle]?.scrollerIsVertical = isVertical
        return handle
    }

    /// Records a stepper creation request.
    public func createStepper(value: Double, minValue: Double, maxValue: Double, increment: Double, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = makeHandle(kind: "stepper", text: "", frame: frame, parent: parent)
        records[handle]?.stepperMinValue = minValue
        records[handle]?.stepperMaxValue = maxValue
        records[handle]?.stepperIncrement = increment
        records[handle]?.stepperValue = value
        return handle
    }

    /// Records a date picker creation request.
    public func createDatePicker(date: Date, minDate: Date?, maxDate: Date?, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = makeHandle(kind: "datePicker", text: "", frame: frame, parent: parent)
        records[handle]?.datePickerDate = date
        records[handle]?.datePickerMinDate = minDate
        records[handle]?.datePickerMaxDate = maxDate
        return handle
    }

    /// Records a scroll view creation request.
    public func createScrollView(frame: NSRect, parent: NativeHandle?, hasVerticalScroller: Bool, hasHorizontalScroller: Bool) -> NativeHandle {
        makeHandle(kind: "scrollView", text: "", frame: frame, parent: parent)
    }

    /// Records scroll-view document and viewport geometry.
    public func setScrollViewContentSize(_ contentSize: NSSize, viewportSize: NSSize, hasVerticalScroller: Bool, hasHorizontalScroller: Bool, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.scrollViewContentSize = contentSize
        record.scrollViewViewportSize = viewportSize
        records[handle] = record
    }

    /// Records a scroll-view visible origin.
    public func setScrollViewContentOffset(_ offset: NSPoint, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        let maxX = max(0, record.scrollViewContentSize.width - record.scrollViewViewportSize.width)
        let maxY = max(0, record.scrollViewContentSize.height - record.scrollViewViewportSize.height)
        record.scrollViewContentOffset = NSPoint(
            x: min(max(offset.x, 0), maxX),
            y: min(max(offset.y, 0), maxY)
        )
        records[handle] = record
    }

    /// Reads a scroll-view visible origin.
    public func scrollViewContentOffset(for handle: NativeHandle) -> NSPoint {
        records[handle]?.scrollViewContentOffset ?? NSZeroPoint
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

    /// Records an image-view bitmap source update.
    public func setImagePath(_ imagePath: String?, description: String, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.imagePath = imagePath
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
    public func datePickerDate(for handle: NativeHandle) -> Date? {
        records[handle]?.datePickerDate
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

    /// Records a table row visibility request.
    public func scrollTableRowToVisible(_ row: Int, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.tableVisibleRow = row
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

    /// Records a mouse-dragged action.
    public func registerMouseDraggedAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        mouseDraggedActions[handle] = action
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
            comboBoxItems: [],
            imagePath: nil,
            tabViewItems: [],
            tabViewSelectedIndex: -1,
            toolbarItems: [],
            sliderMinValue: 0,
            sliderMaxValue: 1,
            sliderValue: 0,
            progressMinValue: 0,
            progressMaxValue: 1,
            progressValue: 0,
            scrollerKnobProportion: 0,
            scrollerIsVertical: false,
            scrollViewContentSize: NSZeroSize,
            scrollViewViewportSize: NSZeroSize,
            scrollViewContentOffset: NSZeroPoint,
            stepperMinValue: 0,
            stepperMaxValue: 1,
            stepperIncrement: 1,
            stepperValue: 0,
            datePickerDate: nil,
            datePickerMinDate: nil,
            datePickerMaxDate: nil,
            tableColumns: [],
            tableColumnWidths: [],
            tableRows: [],
            tableSelectedRow: -1,
            tableVisibleRow: -1,
            tableClickedRow: -1,
            tableClickedColumn: -1,
            textColor: nil,
            backgroundColor: nil,
            font: nil,
            usesMainMenu: false
        )
        return handle
    }
}
