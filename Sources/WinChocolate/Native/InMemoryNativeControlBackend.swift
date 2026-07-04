/// A drawing context that records commands for deterministic tests.
public final class RecordingDrawingContext: NativeDrawingContext {
    /// A recorded fill command.
    public struct Fill: Equatable {
        /// The filled path segments.
        public let segments: [NativePathSegment]

        /// The fill color.
        public let color: NSColor
    }

    /// A recorded stroke command.
    public struct Stroke: Equatable {
        /// The stroked path segments.
        public let segments: [NativePathSegment]

        /// The stroke color.
        public let color: NSColor

        /// The stroke line width.
        public let lineWidth: CGFloat
    }

    /// A recorded text command.
    public struct Text: Equatable {
        /// The drawn string.
        public let text: String

        /// The top-left origin of the text run.
        public let point: NSPoint

        /// The text color.
        public let color: NSColor

        /// The requested font family name.
        public let fontName: String

        /// The requested font point size.
        public let fontSize: CGFloat

        /// The requested font weight (Windows `LOGFONT` scale).
        public let weight: Int

        /// Whether the text was drawn italic.
        public let italic: Bool

        /// Whether the text was drawn bold (weight of semibold or heavier).
        public var bold: Bool {
            weight >= NSFont.Weight.semibold.rawValue
        }
    }

    /// A recorded image command.
    public struct Image: Equatable {
        /// The source image file path.
        public let path: String

        /// The destination rectangle.
        public let rect: NSRect
    }

    /// A recorded linear-gradient command.
    public struct Gradient: Equatable {
        /// The gradient color stops in order.
        public let stops: [NativeGradientStop]

        /// The filled rectangle.
        public let rect: NSRect

        /// The gradient angle in AppKit degrees.
        public let angle: CGFloat
    }

    /// A recorded clip command.
    public struct Clip: Equatable {
        /// The clip path segments.
        public let segments: [NativePathSegment]
    }

    /// A recorded graphics-state operation.
    public enum StateOperation: Equatable {
        /// A state save.
        case save

        /// A state restore.
        case restore
    }

    /// Fill commands in draw order.
    public private(set) var fills: [Fill] = []

    /// Stroke commands in draw order.
    public private(set) var strokes: [Stroke] = []

    /// Text commands in draw order.
    public private(set) var texts: [Text] = []

    /// Image commands in draw order.
    public private(set) var images: [Image] = []

    /// Linear-gradient commands in draw order.
    public private(set) var gradients: [Gradient] = []

    /// Clip commands in draw order.
    public private(set) var clips: [Clip] = []

    /// Graphics-state saves and restores in order.
    public private(set) var stateOperations: [StateOperation] = []

    /// Creates an empty recording context.
    public init() {
    }

    /// Records a fill command.
    public func fillPath(_ segments: [NativePathSegment], color: NSColor) {
        fills.append(Fill(segments: segments, color: color))
    }

    /// Records a stroke command.
    public func strokePath(_ segments: [NativePathSegment], color: NSColor, lineWidth: CGFloat) {
        strokes.append(Stroke(segments: segments, color: color, lineWidth: lineWidth))
    }

    /// Records a text command.
    public func drawText(_ text: String, at point: NSPoint, color: NSColor, fontName: String, fontSize: CGFloat, weight: Int, italic: Bool) {
        texts.append(Text(text: text, point: point, color: color, fontName: fontName, fontSize: fontSize, weight: weight, italic: italic))
    }

    /// Records an image command.
    public func drawImage(atPath path: String, in rect: NSRect) {
        images.append(Image(path: path, rect: rect))
    }

    /// Records a linear-gradient command.
    public func drawLinearGradient(_ stops: [NativeGradientStop], in rect: NSRect, angle: CGFloat) {
        gradients.append(Gradient(stops: stops, rect: rect, angle: angle))
    }

    /// Records a clip command.
    public func clip(to segments: [NativePathSegment]) {
        clips.append(Clip(segments: segments))
    }

    /// Records a state save.
    public func saveState() {
        stateOperations.append(.save)
    }

    /// Records a state restore.
    public func restoreState() {
        stateOperations.append(.restore)
    }
}

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

        /// Recorded text selection start, in UTF-16 units.
        public var textSelectionLocation: Int

        /// Recorded text selection length, in UTF-16 units.
        public var textSelectionLength: Int

        /// Whether the recorded edit control accepts keyboard editing.
        public var isTextEditable: Bool

        /// Recorded text color.
        public var textColor: NSColor?

        /// Recorded background color.
        public var backgroundColor: NSColor?

        /// Whether the native control should paint its own background.
        public var drawsBackground: Bool

        /// Recorded tooltip text.
        public var toolTip: String?

        /// Recorded font.
        public var font: NSFont?

        /// Whether a top-level window requested the application menu bar.
        public var usesMainMenu: Bool

        /// Recorded top-level window z-ordering level raw value.
        public var windowLevel: Int = 0

        /// Whether the recorded window hides while the application is inactive.
        public var hidesOnDeactivate: Bool = false

        /// Recorded placeholder (cue banner) text.
        public var placeholder: String?

        /// Recorded text alignment.
        public var textAlignment: NSTextAlignment = .natural

        /// Recorded slider tick-mark count.
        public var sliderTickMarkCount: Int = 0

        /// Whether the recorded slider is vertical.
        public var sliderIsVertical: Bool = false

        /// Recorded combo-box visible item count.
        public var comboBoxVisibleItems: Int = 0

        /// Recorded progress/level bar color.
        public var progressBarColor: NSColor?

        /// Recorded minimum content size limit.
        public var minContentSize: NSSize?

        /// Recorded maximum content size limit.
        public var maxContentSize: NSSize?

        /// Recorded content scale for custom-drawn views.
        public var contentScale: CGFloat = 1

        /// Recorded date-picker display format.
        public var datePickerFormat: String?

        /// Recorded button image file path.
        public var buttonImagePath: String?

        /// Whether the recorded text view is rich text.
        public var isRichText: Bool = false

        /// Recorded rich-text range formatting requests, oldest first.
        public var textRangeFormats: [TextRangeFormat] = []
    }

    /// One recorded rich-text range formatting request.
    public struct TextRangeFormat: Equatable, Sendable {
        /// The applied font, when any.
        public var font: NSFont?

        /// The applied color, when any.
        public var color: NSColor?

        /// The applied underline state, when any.
        public var underline: Bool?

        /// The applied strikethrough state, when any.
        public var strikethrough: Bool?

        /// The formatted range start, in UTF-16 units.
        public var location: Int

        /// The formatted range length, in UTF-16 units.
        public var length: Int
    }

    private var nextRawHandle: UInt = 1

    /// Recorded native object requests by handle.
    public private(set) var records: [NativeHandle: Record] = [:]

    /// Registered control actions by handle.
    public private(set) var actions: [NativeHandle: () -> Void] = [:]

    /// Last actuated scroller part by handle.
    private var scrollerParts: [NativeHandle: NativeScrollerPart] = [:]

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

    /// Handles most recently raised above siblings.
    public private(set) var raisedHandles: [NativeHandle] = []

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
        records[handle]?.isHidden = true
        return handle
    }

    /// Records a native window level change.
    public func setWindowLevel(_ level: NSWindow.Level, for handle: NativeHandle) {
        records[handle]?.windowLevel = level.rawValue
    }

    /// Records whether a native window hides while the application is inactive.
    public func setHidesOnDeactivate(_ hidesOnDeactivate: Bool, for handle: NativeHandle) {
        records[handle]?.hidesOnDeactivate = hidesOnDeactivate
    }

    /// Returns a fixed font family list for deterministic tests.
    public func fontFamilyNames() -> [String] {
        ["Arial", "Consolas", "Courier New", "Georgia", "Segoe UI", "Tahoma", "Times New Roman", "Verdana"]
    }

    /// Recorded clipboard text, when any.
    public private(set) var clipboardText: String?

    /// Recorded clipboard data representations by platform format name.
    public private(set) var clipboardDataRepresentations: [String: [UInt8]] = [:]

    /// Number of recorded clipboard changes.
    public private(set) var clipboardChanges = 0

    /// Reads the recorded clipboard text.
    public func clipboardString() -> String? {
        clipboardText
    }

    /// Records new clipboard text.
    public func setClipboardString(_ string: String) {
        setClipboardContents(text: string, dataRepresentations: [:])
    }

    /// Records a combined clipboard update.
    public func setClipboardContents(text: String?, dataRepresentations: [String: [UInt8]]) {
        clipboardText = text
        clipboardDataRepresentations = dataRepresentations
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
        clipboardChanges += 1
    }

    /// The recorded clipboard change count.
    public func clipboardChangeCount() -> Int {
        clipboardChanges
    }

    /// Records that a window should be shown.
    public func showWindow(_ handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.isHidden = false
        records[handle] = record
    }

    /// Records a fade show/hide request and updates visibility.
    public func fadeWindow(_ handle: NativeHandle, visible: Bool) {
        fadedWindows[handle] = visible
        guard var record = records[handle] else {
            return
        }

        record.isHidden = !visible
        records[handle] = record
    }

    /// Last fade visibility requested per window, for tests.
    public private(set) var fadedWindows: [NativeHandle: Bool] = [:]

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

    /// Registered window close-veto handlers by handle.
    public private(set) var windowShouldCloseHandlers: [NativeHandle: () -> Bool] = [:]

    /// Records a window close-veto handler.
    public func registerWindowShouldCloseHandler(for handle: NativeHandle, handler: @escaping () -> Bool) {
        windowShouldCloseHandlers[handle] = handler
    }

    /// Simulates a title-bar close request, honoring the veto handler.
    @discardableResult
    public func requestWindowClose(_ handle: NativeHandle) -> Bool {
        if windowShouldCloseHandlers[handle]?() == false {
            return false
        }

        closeWindow(handle)
        return true
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
    public func createTextField(text: String, frame: NSRect, parent: NativeHandle?, isEditable: Bool, isBordered: Bool) -> NativeHandle {
        makeHandle(kind: isEditable ? "editableTextField" : "textField", text: text, frame: frame, parent: parent)
    }

    /// Records a secure text field creation request.
    public func createSecureTextField(text: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        makeHandle(kind: "secureTextField", text: text, frame: frame, parent: parent)
    }

    /// Records a text view creation request.
    public func createTextView(text: String, frame: NSRect, parent: NativeHandle?, isEditable: Bool, isRichText: Bool) -> NativeHandle {
        let handle = makeHandle(kind: isEditable ? "editableTextView" : "textView", text: text, frame: frame, parent: parent)
        records[handle]?.isTextEditable = isEditable
        records[handle]?.isRichText = isRichText
        return handle
    }

    /// Records a rich-text range formatting request.
    public func setTextRangeFormat(font: NSFont?, color: NSColor?, underline: Bool?, strikethrough: Bool?, location: Int, length: Int, for handle: NativeHandle) {
        records[handle]?.textRangeFormats.append(TextRangeFormat(
            font: font,
            color: color,
            underline: underline,
            strikethrough: strikethrough,
            location: location,
            length: length
        ))
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

    /// Returns the recorded toolbar item frame using the same simple sizing model as the in-memory toolbar.
    public func toolbarItemFrame(at index: Int, for handle: NativeHandle) -> NSRect? {
        guard let record = records[handle], record.toolbarItems.indices.contains(index) else {
            return nil
        }

        var x: CGFloat = 8
        for itemIndex in 0..<index {
            x += toolbarItemWidth(record.toolbarItems[itemIndex], toolbarWidth: record.frame.size.width)
        }

        let width = toolbarItemWidth(record.toolbarItems[index], toolbarWidth: record.frame.size.width)
        return NSMakeRect(x, 0, width, record.frame.size.height)
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

    /// Reads a recorded text selection.
    public func textSelection(for handle: NativeHandle) -> (location: Int, length: Int) {
        guard let record = records[handle] else {
            return (0, 0)
        }

        return (record.textSelectionLocation, record.textSelectionLength)
    }

    /// Records a text selection, clamped to the stored text like a native edit control.
    public func setTextSelection(location: Int, length: Int, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        let textLength = record.text.utf16.count
        let clampedLocation = min(max(0, location), textLength)
        record.textSelectionLocation = clampedLocation
        record.textSelectionLength = min(max(0, length), textLength - clampedLocation)
        records[handle] = record
    }

    /// Replaces the recorded selection in the stored text and moves the
    /// selection to the end of the inserted text, mirroring `EM_REPLACESEL`.
    public func replaceSelectedText(_ text: String, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        var units = Array(record.text.utf16)
        let location = min(max(0, record.textSelectionLocation), units.count)
        let length = min(max(0, record.textSelectionLength), units.count - location)
        let replacement = Array(text.utf16)
        units.replaceSubrange(location..<(location + length), with: replacement)
        record.text = String(decoding: units, as: UTF16.self)
        record.textSelectionLocation = location + replacement.count
        record.textSelectionLength = 0
        records[handle] = record
    }

    /// Records whether an edit control accepts keyboard editing.
    public func setTextEditable(_ isEditable: Bool, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.isTextEditable = isEditable
        records[handle] = record
    }

    /// Updates a recorded control frame.
    public func setFrame(_ frame: NSRect, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        // Scaled views record magnified native geometry, mirroring Win32.
        let scale = record.contentScale
        record.frame = scale == 1 ? frame : NSRect(
            x: frame.origin.x * scale,
            y: frame.origin.y * scale,
            width: frame.size.width * scale,
            height: frame.size.height * scale
        )
        records[handle] = record
    }

    /// Records the content scale applied to a custom-drawn view.
    public func setContentScale(_ scale: CGFloat, for handle: NativeHandle) {
        records[handle]?.contentScale = scale
    }

    /// Records placeholder text.
    public func setTextPlaceholder(_ placeholder: String?, for handle: NativeHandle) {
        records[handle]?.placeholder = placeholder
    }

    /// Records text alignment.
    public func setTextAlignment(_ alignment: NSTextAlignment, for handle: NativeHandle) {
        records[handle]?.textAlignment = alignment
    }

    /// Records the slider tick-mark count.
    public func setSliderTickMarks(count: Int, for handle: NativeHandle) {
        records[handle]?.sliderTickMarkCount = count
    }

    /// Records the slider orientation.
    public func setSliderVertical(_ isVertical: Bool, for handle: NativeHandle) {
        records[handle]?.sliderIsVertical = isVertical
    }

    /// Records the combo-box visible item count.
    public func setComboBoxVisibleItems(_ count: Int, for handle: NativeHandle) {
        records[handle]?.comboBoxVisibleItems = count
    }

    /// Records the progress/level bar color.
    public func setProgressBarColor(_ color: NSColor?, for handle: NativeHandle) {
        records[handle]?.progressBarColor = color
    }

    /// Records window content size limits.
    public func setWindowContentSizeLimits(minSize: NSSize?, maxSize: NSSize?, for handle: NativeHandle) {
        records[handle]?.minContentSize = minSize
        records[handle]?.maxContentSize = maxSize
    }

    /// Handles whose background click drags the parent window.
    public private(set) var windowDragViewHandles: Set<NativeHandle> = []

    /// Records whether a view's background click drags its window.
    public func setViewDragsParentWindow(_ enabled: Bool, for handle: NativeHandle) {
        if enabled {
            windowDragViewHandles.insert(handle)
        } else {
            windowDragViewHandles.remove(handle)
        }
    }

    /// The handle currently watched for an outside-click dismiss, if any.
    public private(set) var outsideClickDismissHandle: NativeHandle?

    /// The recorded outside-click dismiss action, for tests to invoke.
    public private(set) var outsideClickDismissAction: (() -> Void)?

    /// Records the start of an outside-click dismiss watch.
    public func beginOutsideClickDismiss(for handle: NativeHandle, onDismiss: @escaping () -> Void) {
        outsideClickDismissHandle = handle
        outsideClickDismissAction = onDismiss
    }

    /// Records the end of an outside-click dismiss watch.
    public func endOutsideClickDismiss() {
        outsideClickDismissHandle = nil
        outsideClickDismissAction = nil
    }

    /// Simulates a click outside the watched window, firing the dismiss action.
    public func simulateOutsideClick() {
        outsideClickDismissAction?()
    }

    /// Records that a control should be raised above siblings.
    public func raiseControl(_ handle: NativeHandle) {
        raisedHandles.append(handle)
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

    /// Updates whether a recorded control draws its own background.
    public func setDrawsBackground(_ drawsBackground: Bool, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.drawsBackground = drawsBackground
        records[handle] = record
    }

    /// Updates recorded tooltip text.
    public func setToolTip(_ toolTip: String?, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.toolTip = toolTip
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

    /// Records a date-picker display format.
    public func setDatePickerFormat(_ format: String?, for handle: NativeHandle) {
        records[handle]?.datePickerFormat = format
    }

    /// Records a button image file path.
    public func setButtonImage(imagePath: String?, for handle: NativeHandle) {
        records[handle]?.buttonImagePath = imagePath
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

    /// Registered focus-change actions by handle.
    public private(set) var focusChangeActions: [NativeHandle: (Bool) -> Void] = [:]

    /// Records a focus-change action.
    public func registerFocusChangeAction(for handle: NativeHandle, action: @escaping (Bool) -> Void) {
        focusChangeActions[handle] = action
    }

    /// Simulates a native focus change for tests.
    public func simulateFocusChange(gained: Bool, for handle: NativeHandle) {
        focusChangeActions[handle]?(gained)
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

    /// Registered right mouse-down actions by handle.
    public private(set) var rightMouseDownActions: [NativeHandle: (NSEvent) -> Void] = [:]

    /// Registered right mouse-up actions by handle.
    public private(set) var rightMouseUpActions: [NativeHandle: (NSEvent) -> Void] = [:]

    /// Registered tertiary mouse-down actions by handle.
    public private(set) var otherMouseDownActions: [NativeHandle: (NSEvent) -> Void] = [:]

    /// Registered tertiary mouse-up actions by handle.
    public private(set) var otherMouseUpActions: [NativeHandle: (NSEvent) -> Void] = [:]

    /// Registered scroll-wheel actions by handle.
    public private(set) var scrollWheelActions: [NativeHandle: (NSEvent) -> Void] = [:]

    /// Registered draw actions by handle.
    public private(set) var drawActions: [NativeHandle: (NativeDrawingContext, NSRect) -> Void] = [:]

    /// Handles that requested a repaint, in request order.
    public private(set) var invalidatedHandles: [NativeHandle] = []

    /// Records a right mouse-down action.
    public func registerRightMouseDownAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        rightMouseDownActions[handle] = action
    }

    /// Records a right mouse-up action.
    public func registerRightMouseUpAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        rightMouseUpActions[handle] = action
    }

    /// Records a tertiary mouse-down action.
    public func registerOtherMouseDownAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        otherMouseDownActions[handle] = action
    }

    /// Records a tertiary mouse-up action.
    public func registerOtherMouseUpAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        otherMouseUpActions[handle] = action
    }

    /// Records a scroll-wheel action.
    public func registerScrollWheelAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        scrollWheelActions[handle] = action
    }

    /// Records a draw action.
    public func registerDrawAction(for handle: NativeHandle, action: @escaping (NativeDrawingContext, NSRect) -> Void) {
        drawActions[handle] = action
    }

    /// Records a repaint request.
    public func invalidateControl(_ handle: NativeHandle) {
        invalidatedHandles.append(handle)
    }

    /// Runs a handle's registered draw action and returns the recorded commands.
    @discardableResult
    public func performDraw(for handle: NativeHandle, in rect: NSRect) -> RecordingDrawingContext {
        let context = RecordingDrawingContext()
        drawActions[handle]?(context, rect)
        return context
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

    /// File dialog descriptors received through `runFileDialog`, oldest first.
    public private(set) var fileDialogRequests: [NativeFileDialogOptions] = []

    /// Paths returned by the next `runFileDialog` calls, consumed in order.
    ///
    /// Each element scripts one dialog run; `nil` scripts a user cancel. When
    /// the queue is empty, dialogs report cancel.
    public var scriptedFileDialogPaths: [[String]?] = []

    /// Records the request and returns the next scripted dialog result.
    public func runFileDialog(_ options: NativeFileDialogOptions) -> [String]? {
        fileDialogRequests.append(options)
        guard !scriptedFileDialogPaths.isEmpty else {
            return nil
        }

        return scriptedFileDialogPaths.removeFirst()
    }

    /// Initial colors received through `runColorChooser`, oldest first.
    public private(set) var colorChooserRequests: [NSColor] = []

    /// The color returned by the next `runColorChooser` call; `nil` scripts a
    /// user cancel.
    public var nextColorChooserResult: NSColor?

    /// Records the request and returns the scripted color chooser result.
    public func runColorChooser(initialColor: NSColor) -> NSColor? {
        colorChooserRequests.append(initialColor)
        return nextColorChooserResult
    }

    /// Initial fonts received through `runFontChooser`, oldest first.
    public private(set) var fontChooserRequests: [NSFont?] = []

    /// The font returned by the next `runFontChooser` call; `nil` scripts a
    /// user cancel.
    public var nextFontChooserResult: NSFont?

    /// Records the request and returns the scripted font chooser result.
    public func runFontChooser(initialFont: NSFont?) -> NSFont? {
        fontChooserRequests.append(initialFont)
        return nextFontChooserResult
    }

    /// Windows that ran modal sessions, oldest first.
    public private(set) var modalSessions: [NativeHandle] = []

    /// Stop codes recorded through `stopModal`, oldest first.
    public private(set) var modalStopCodes: [Int] = []

    /// The code returned by the next `runModal` call.
    public var nextModalResponseCode: Int = NSApplication.ModalResponse.alertFirstButtonReturn.rawValue

    /// Records the modal session and returns the scripted stop code.
    public func runModal(for handle: NativeHandle) -> Int {
        modalSessions.append(handle)
        return nextModalResponseCode
    }

    /// Records a modal stop request.
    public func stopModal(withCode code: Int) {
        modalStopCodes.append(code)
    }

    /// Recorded indeterminate state by handle.
    public private(set) var progressIndeterminateStates: [NativeHandle: (isIndeterminate: Bool, animating: Bool)] = [:]

    /// Measures text with a deterministic estimate for tests.
    public func measureText(_ text: String, fontName: String, fontSize: CGFloat, weight: Int, italic: Bool) -> NSSize {
        NSMakeSize(CGFloat(text.count) * fontSize * 0.55, fontSize * 1.35)
    }

    /// Records native progress indeterminate state.

    public func setProgressIndicatorIndeterminate(_ isIndeterminate: Bool, animating: Bool, for handle: NativeHandle) {
        progressIndeterminateStates[handle] = (isIndeterminate, animating)
    }

    /// Cursor names requested through `setCursor(named:)`, oldest first.
    public private(set) var cursorNames: [String] = []

    /// Records a cursor request.
    public func setCursor(named name: String) {
        cursorNames.append(name)
    }

    /// Hover cursor regions by handle.
    public private(set) var cursorRegions: [NativeHandle: [NativeCursorRegion]] = [:]

    /// Records a view's hover cursor regions.
    public func setCursorRegions(_ regions: [NativeCursorRegion], for handle: NativeHandle) {
        cursorRegions[handle] = regions
    }

    /// A recorded run-loop timer request.
    public struct ScheduledTimer: Equatable, Sendable {
        /// The timer identifier handed back to the scheduler.
        public let identifier: UInt

        /// The requested firing interval in milliseconds.
        public let intervalMilliseconds: Int
    }

    /// Scheduled run-loop timers, oldest first.
    public private(set) var scheduledTimers: [ScheduledTimer] = []

    /// Identifiers of canceled run-loop timers, oldest first.
    public private(set) var canceledTimerIdentifiers: [UInt] = []

    private var timerActions: [UInt: () -> Void] = [:]
    private var nextTimerIdentifier: UInt = 1

    /// Records a run-loop timer request.
    public func scheduleNativeTimer(intervalMilliseconds: Int, action: @escaping () -> Void) -> UInt {
        let identifier = nextTimerIdentifier
        nextTimerIdentifier += 1
        scheduledTimers.append(ScheduledTimer(identifier: identifier, intervalMilliseconds: intervalMilliseconds))
        timerActions[identifier] = action
        return identifier
    }

    /// Records a run-loop timer cancellation.
    public func cancelNativeTimer(_ identifier: UInt) {
        timerActions.removeValue(forKey: identifier)
        canceledTimerIdentifiers.append(identifier)
    }

    /// Fires a scheduled timer's action, standing in for a message-loop tick.
    public func fireTimer(_ identifier: UInt) {
        timerActions[identifier]?()
    }

    /// The most recently registered key-equivalent handler.
    public private(set) var keyEquivalentHandler: ((NSEvent) -> Bool)?

    /// Records the key-equivalent handler.
    public func registerKeyEquivalentHandler(_ handler: @escaping (NSEvent) -> Bool) {
        keyEquivalentHandler = handler
    }

    /// Menus popped through `runContextMenu`, oldest first.
    public private(set) var poppedContextMenus: [NSMenu] = []

    /// Index into the popped menu's depth-first flattened items selected by the
    /// next `runContextMenu` call; `-1` scripts a user cancel.
    public var nextContextMenuSelection: Int = -1

    /// Records the pop request and performs the scripted flat-item selection.
    public func runContextMenu(_ menu: NSMenu, atScreenPoint point: NSPoint) -> NSMenuItem? {
        poppedContextMenus.append(menu)
        let items = flattenedItems(of: menu)
        guard items.indices.contains(nextContextMenuSelection) else {
            return nil
        }

        let item = items[nextContextMenuSelection]
        _ = item.performAction()
        return item
    }

    private func flattenedItems(of menu: NSMenu) -> [NSMenuItem] {
        var flattened: [NSMenuItem] = []
        for item in menu.items {
            flattened.append(item)
            if let submenu = item.submenu {
                flattened.append(contentsOf: flattenedItems(of: submenu))
            }
        }
        return flattened
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
            textSelectionLocation: 0,
            textSelectionLength: 0,
            isTextEditable: true,
            textColor: nil,
            backgroundColor: nil,
            drawsBackground: true,
            toolTip: nil,
            font: nil,
            usesMainMenu: false
        )
        return handle
    }

    private func toolbarItemWidth(_ item: NativeToolbarItem, toolbarWidth: CGFloat) -> CGFloat {
        if item.isFlexibleSpace {
            return max(24, toolbarWidth / 4)
        }
        if let customViewWidth = item.customViewWidth {
            return customViewWidth
        }
        if item.isSeparator {
            return 8
        }

        let iconWidth: CGFloat = item.imageName == nil ? 0 : 24
        let labelWidth = CGFloat(max(28, item.label.count * 6))
        return max(iconWidth, labelWidth) + 20
    }
}
