import Foundation

/// Graphics context that records its operations as readable strings, so
/// contract tests can assert an entire draw pass without a display.
public final class RecordingGraphicsContext: NativeGraphicsContext {
    public private(set) var ops: [String] = []
    public init() {}

    private func rgb(_ c: NSColor) -> String {
        String(format: "%.2f,%.2f,%.2f", c.redComponent, c.greenComponent, c.blueComponent)
    }
    public func setFillColor(_ color: NSColor) { ops.append("fillColor(\(rgb(color)))") }
    public func setStrokeColor(_ color: NSColor) { ops.append("strokeColor(\(rgb(color)))") }
    public func setLineWidth(_ width: Double) { ops.append("lineWidth(\(Int(width)))") }
    public func beginPath() { ops.append("begin") }
    public func move(toX x: Double, y: Double) { ops.append("move(\(Int(x)),\(Int(y)))") }
    public func line(toX x: Double, y: Double) { ops.append("line(\(Int(x)),\(Int(y)))") }
    public func curve(toX x: Double, y: Double, c1x: Double, c1y: Double, c2x: Double, c2y: Double) {
        ops.append("curve(\(Int(x)),\(Int(y)))")
    }
    public func addArc(centerX: Double, centerY: Double, radius: Double, startAngleRadians: Double, endAngleRadians: Double, clockwise: Bool) {
        ops.append("arc(\(Int(centerX)),\(Int(centerY)),\(Int(radius)))")
    }
    public func closePath() { ops.append("close") }
    public func fillPath() { ops.append("fill") }
    public func strokePath() { ops.append("stroke") }
    public func saveState() { ops.append("save") }
    public func restoreState() { ops.append("restore") }
    public func clipToCurrentPath() { ops.append("clip") }
    public func fillLinearGradient(_ stops: [NativeGradientStop], inRect rect: NSRect, angleDegrees: Double) {
        ops.append("linearGradient[\(stops.map { rgb($0.color) }.joined(separator: ";"))]@\(Int(angleDegrees))")
    }
    public func fillRadialGradient(_ stops: [NativeGradientStop], inRect rect: NSRect) {
        ops.append("radialGradient[\(stops.map { rgb($0.color) }.joined(separator: ";"))]")
    }
}

/// A backend that records state in memory instead of touching a display.
///
/// It lets the contract tests exercise the whole AppKit-shaped API — window
/// creation, control wiring, actions — with no GTK and no X server, so the
/// tests are hermetic and run anywhere (including CI). The `simulate*` hooks
/// stand in for user input.
///
/// Platform-neutral by construction: this type is a prime candidate to move
/// into the shared core in Phase L6, unchanged.
public final class InMemoryNativeControlBackend: NativeControlBackend {

    /// What kind of control a handle refers to (drives `setText` routing).
    public enum Kind: Equatable {
        case window, view, button, label, textField, secureField, searchField, comboBox
        case checkbox, radio, slider, progress, popUp, stepper, level, textView
        case datePicker, colorWell, tabView, box, scrollView, splitView, segmented, imageView
        case tokenField, table, outline, collection, scroller
    }

    private var nextRaw: UInt = 1

    public private(set) var isRunning = false
    public private(set) var kinds: [UInt: Kind] = [:]
    public private(set) var titles: [UInt: String] = [:]
    public private(set) var texts: [UInt: String] = [:]
    public private(set) var frames: [UInt: NSRect] = [:]
    public private(set) var enabledStates: [UInt: Bool] = [:]
    public private(set) var contentViews: [UInt: UInt] = [:]
    public private(set) var subviews: [UInt: [UInt]] = [:]
    public private(set) var visibleWindows: Set<UInt> = []
    public private(set) var buttonStates: [UInt: Bool] = [:]
    public private(set) var doubleValues: [UInt: Double] = [:]
    public private(set) var selectedIndices: [UInt: Int] = [:]
    public private(set) var popUpItems: [UInt: [String]] = [:]
    public private(set) var flippedViews: [UInt: Bool] = [:]
    public private(set) var sliderVerticals: [UInt: Bool] = [:]
    public private(set) var datePickerGraphical: [UInt: Bool] = [:]
    public private(set) var textEditable: [UInt: Bool] = [:]
    public private(set) var backgroundColors: [UInt: NSColor?] = [:]
    public private(set) var itemsByHandle: [UInt: [String]] = [:]
    private var ranges: [UInt: (min: Double, max: Double)] = [:]
    private var radioGroups: [UInt: [UInt]] = [:]   // member -> all members in its group
    private var actions: [UInt: () -> Void] = [:]
    private var windowCloseActions: [UInt: () -> Void] = [:]
    private var textChangeActions: [UInt: (String) -> Void] = [:]
    private var toggleActions: [UInt: (Bool) -> Void] = [:]
    private var valueChangeActions: [UInt: (Double) -> Void] = [:]
    private var selectionActions: [UInt: (Int) -> Void] = [:]
    public private(set) var dates: [UInt: Date] = [:]
    public private(set) var colors: [UInt: NSColor] = [:]
    public private(set) var tabPages: [UInt: [(page: UInt, label: String)]] = [:]
    public private(set) var splitPanes: [UInt: [UInt]] = [:]
    public private(set) var dividerPositions: [UInt: Double] = [:]
    public private(set) var menuBars: [UInt: [NativeMenuSpec]] = [:]
    public private(set) var toolbars: [UInt: [NativeToolbarItemSpec]] = [:]
    public private(set) var imagePaths: [UInt: String] = [:]
    public private(set) var tokensByHandle: [UInt: [String]] = [:]
    public private(set) var fonts: [UInt: NativeFontSpec] = [:]
    public private(set) var textColors: [UInt: NSColor] = [:]
    public private(set) var styledTexts: [UInt: [NativeTextRun]] = [:]
    /// The ops recorded by the most recent draw of each view.
    public private(set) var lastDrawOps: [UInt: [String]] = [:]
    public private(set) var displayRequests: [UInt: Int] = [:]
    private var drawHandlers: [UInt: (NativeGraphicsContext, Double, Double) -> Void] = [:]
    public private(set) var tableColumns: [UInt: [String]] = [:]
    public private(set) var sortableColumns: [UInt: Set<Int>] = [:]
    private var sortActions: [UInt: (Int, Bool) -> Void] = [:]
    private var rowActivateActions: [UInt: (Int) -> Void] = [:]
    public private(set) var tableRowCounts: [UInt: Int] = [:]
    private var tableCellProviders: [UInt: (Int, Int) -> String] = [:]
    public private(set) var collectionItemCounts: [UInt: Int] = [:]
    private var collectionItemProviders: [UInt: (Int) -> String] = [:]
    public private(set) var outlineColumns: [UInt: [String]] = [:]
    public private(set) var outlineRootCounts: [UInt: Int] = [:]
    private var outlineChildCountProviders: [UInt: (String) -> Int] = [:]
    private var outlineCellTextProviders: [UInt: (String, Int) -> String] = [:]
    private var tokensChangeActions: [UInt: ([String]) -> Void] = [:]
    /// Whether the app is currently in dark appearance.
    public private(set) var appearanceIsDark = false
    /// The material (raw value) applied to each visual-effect view.
    public private(set) var materials: [UInt: String] = [:]
    /// The last string pushed to the clipboard.
    public private(set) var clipboard: String?
    /// The dragged types each drop target accepts.
    public private(set) var dropTargetTypes: [UInt: [String]] = [:]
    private var dropHandlers: [UInt: (String, Double, Double) -> Bool] = [:]
    private var dragProviders: [UInt: () -> String?] = [:]
    /// Alerts shown so far (message, informative, buttons), newest last.
    public private(set) var alerts: [(message: String, informative: String, buttons: [String])] = []
    /// The button index `runAlert` returns, standing in for the user's press.
    public var nextAlertResponse = 0
    /// The path `runOpenPanel` returns (nil = user cancelled).
    public var nextOpenPanelPath: String?
    /// The path `runSavePanel` returns (nil = user cancelled).
    public var nextSavePanelPath: String?
    /// Save-panel invocations recorded as (directory, suggestedName), newest last.
    public private(set) var savePanelRuns: [(directory: String?, suggestedName: String?)] = []
    /// Open-panel invocations recorded as initial directories, newest last.
    public private(set) var openPanelRuns: [String?] = []
    private var dateChangeActions: [UInt: (Date) -> Void] = [:]
    private var colorChangeActions: [UInt: (NSColor) -> Void] = [:]

    public init() {}

    private func allocate(_ kind: Kind) -> NativeHandle {
        defer { nextRaw += 1 }
        kinds[nextRaw] = kind
        return NativeHandle(rawValue: nextRaw)
    }

    // MARK: Application lifecycle
    /// Scheduled timers, for tests: fire them with `simulateTimerTick`.
    public private(set) var scheduledTimers: [(interval: Double, repeats: Bool, block: () -> Void)] = []
    public func scheduleTimer(interval: Double, repeats: Bool, _ block: @escaping () -> Void) {
        scheduledTimers.append((interval, repeats, block))
    }
    /// Test hook: fire every scheduled timer once.
    public func simulateTimerTick() {
        for timer in scheduledTimers { timer.block() }
    }

    public func runApplication() { isRunning = true }
    public func terminateApplication() { isRunning = false }

    // MARK: Windows
    public func createWindow(title: String, frame: NSRect, styleMask: NSWindow.StyleMask) -> NativeHandle {
        let h = allocate(.window)
        titles[h.rawValue] = title
        frames[h.rawValue] = frame
        return h
    }
    public func setContentView(_ view: NativeHandle, for window: NativeHandle) {
        contentViews[window.rawValue] = view.rawValue
    }
    public func showWindow(_ handle: NativeHandle) {
        visibleWindows.insert(handle.rawValue)
        hiddenWindows.remove(handle.rawValue)   // re-presenting un-hides
    }
    public func setWindowTitle(_ title: String, for handle: NativeHandle) {
        titles[handle.rawValue] = title
    }
    /// Hidden (ordered-out) windows, for tests.
    public private(set) var hiddenWindows: Set<UInt> = []
    public func hideWindow(_ handle: NativeHandle) {
        hiddenWindows.insert(handle.rawValue)
        visibleWindows.remove(handle.rawValue)
    }

    public func registerWindowCloseAction(for handle: NativeHandle, action: @escaping () -> Void) {
        windowCloseActions[handle.rawValue] = action
    }
    public func installMenuBar(_ menus: [NativeMenuSpec], on window: NativeHandle) {
        menuBars[window.rawValue] = menus
    }
    public private(set) var toolbarDisplayModes: [UInt: NativeToolbarDisplayMode] = [:]
    public func installToolbar(_ items: [NativeToolbarItemSpec], displayMode: NativeToolbarDisplayMode = .iconAndLabel, on window: NativeHandle) {
        toolbarDisplayModes[window.rawValue] = displayMode
        toolbars[window.rawValue] = items
    }
    /// Fires toolbar item `index`'s action, as if the user clicked it.
    public func simulateToolbarActivate(_ window: NativeHandle, item index: Int) {
        guard let items = toolbars[window.rawValue], index < items.count else { return }
        items[index].action?()
    }

    /// The palette items from the most recent customization request.
    public private(set) var toolbarCustomizationItems: [NativeToolbarPaletteItem] = []
    private var toolbarCustomizationClose: (() -> Void)?
    public func runToolbarCustomization(_ session: NativeToolbarCustomizationSession,
                                        handlers: NativeToolbarCustomizationHandlers,
                                        for window: NativeHandle) {
        toolbarCustomizationSession = session
        toolbarCustomizationItems = session.palette
        toolbarCustomizationHandlers = handlers
        toolbarCustomizationClose = handlers.onClose
    }

    public func updateToolbarCustomization(_ session: NativeToolbarCustomizationSession) {
        toolbarCustomizationSession = session
        toolbarCustomizationItems = session.palette
    }

    /// The last session pushed to the (recorded) customization panel.
    public private(set) var toolbarCustomizationSession: NativeToolbarCustomizationSession?
    private var toolbarCustomizationHandlers: NativeToolbarCustomizationHandlers?

    /// Test hooks: drive the panel exactly as drags would.
    public func simulateToolbarCustomizationInsert(_ identifier: String, at index: Int) {
        toolbarCustomizationHandlers?.onInsert(identifier, index)
    }
    public func simulateToolbarCustomizationRemove(at index: Int) {
        toolbarCustomizationHandlers?.onRemove(index)
    }
    public func simulateToolbarCustomizationMove(from: Int, to: Int) {
        toolbarCustomizationHandlers?.onMove(from, to)
    }
    public func simulateToolbarCustomizationReset() {
        toolbarCustomizationHandlers?.onResetToDefault()
    }
    public func simulateToolbarCustomizationDisplayMode(_ index: Int) {
        toolbarCustomizationHandlers?.onDisplayMode(index)
    }
    /// Test hook: closes the open customization palette.
    public func simulateToolbarCustomizationClose() {
        toolbarCustomizationClose?()
    }
    public func runAlert(message: String, informative: String, buttons: [String], for window: NativeHandle?) -> Int {
        alerts.append((message: message, informative: informative, buttons: buttons))
        return nextAlertResponse
    }
    public func runOpenPanel(directory: String?, for window: NativeHandle?) -> String? {
        openPanelRuns.append(directory)
        return nextOpenPanelPath
    }
    public func runSavePanel(directory: String?, suggestedName: String?, for window: NativeHandle?) -> String? {
        savePanelRuns.append((directory: directory, suggestedName: suggestedName))
        return nextSavePanelPath
    }

    // MARK: Appearance
    public func setAppearanceDark(_ dark: Bool) { appearanceIsDark = dark }

    // MARK: Popover
    public private(set) var popoverContents: [UInt: UInt] = [:]
    public private(set) var shownPopovers: Set<UInt> = []
    public func createPopover() -> NativeHandle { allocate(.view) }
    public func setPopoverContent(_ content: NativeHandle, size: NSSize, for popover: NativeHandle) {
        popoverContents[popover.rawValue] = content.rawValue
        frames[content.rawValue] = NSMakeRect(0, 0, size.width, size.height)
    }
    public func showPopover(_ popover: NativeHandle, relativeTo view: NativeHandle, rect: NSRect, edge: Int) {
        shownPopovers.insert(popover.rawValue)
    }
    public func closePopover(_ popover: NativeHandle) {
        shownPopovers.remove(popover.rawValue)
    }

    // MARK: Pasteboard & drag-and-drop
    public func setClipboardString(_ string: String) { clipboard = string }
    public func clipboardString() -> String? { clipboard }
    public func registerDropTarget(for handle: NativeHandle, types: [String], onDrop: @escaping (String, Double, Double) -> Bool) {
        dropTargetTypes[handle.rawValue] = types
        dropHandlers[handle.rawValue] = onDrop
    }
    public func registerDragSource(for handle: NativeHandle, provider: @escaping () -> String?) {
        dragProviders[handle.rawValue] = provider
    }

    /// Test hook: simulates a drop of `string` on a target at `(x, y)`; returns
    /// whether the destination accepted it (nil = no target registered).
    @discardableResult
    public func simulateDrop(_ string: String, at point: NSPoint = .zero, on handle: NativeHandle) -> Bool? {
        dropHandlers[handle.rawValue]?(string, Double(point.x), Double(point.y))
    }

    /// Test hook: simulates the user dragging `source` and dropping on `target`,
    /// transferring the source's provided string. Returns whether it was accepted.
    @discardableResult
    public func simulateDragAndDrop(from source: NativeHandle, to target: NativeHandle, at point: NSPoint = .zero) -> Bool? {
        guard let string = dragProviders[source.rawValue]?() else { return false }
        return simulateDrop(string, at: point, on: target)
    }

    // MARK: Views & controls
    public func createView(frame: NSRect) -> NativeHandle {
        let h = allocate(.view); frames[h.rawValue] = frame; return h
    }
    public func createButton(title: String, frame: NSRect) -> NativeHandle {
        let h = allocate(.button)
        titles[h.rawValue] = title
        texts[h.rawValue] = title
        frames[h.rawValue] = frame
        enabledStates[h.rawValue] = true
        return h
    }
    public func createLabel(text: String, frame: NSRect) -> NativeHandle {
        let h = allocate(.label); texts[h.rawValue] = text; frames[h.rawValue] = frame; return h
    }
    public func createTextField(text: String, frame: NSRect) -> NativeHandle {
        let h = allocate(.textField)
        texts[h.rawValue] = text
        frames[h.rawValue] = frame
        enabledStates[h.rawValue] = true
        return h
    }
    public func createSecureTextField(text: String, frame: NSRect) -> NativeHandle {
        let h = allocate(.secureField)
        texts[h.rawValue] = text; frames[h.rawValue] = frame; enabledStates[h.rawValue] = true
        return h
    }
    public func createSearchField(text: String, frame: NSRect) -> NativeHandle {
        let h = allocate(.searchField)
        texts[h.rawValue] = text; frames[h.rawValue] = frame; enabledStates[h.rawValue] = true
        return h
    }
    public func createComboBox(items: [String], text: String, frame: NSRect) -> NativeHandle {
        let h = allocate(.comboBox)
        texts[h.rawValue] = text; frames[h.rawValue] = frame; enabledStates[h.rawValue] = true
        itemsByHandle[h.rawValue] = items
        return h
    }
    public func createCheckbox(title: String, frame: NSRect) -> NativeHandle {
        let h = allocate(.checkbox)
        titles[h.rawValue] = title
        texts[h.rawValue] = title
        frames[h.rawValue] = frame
        enabledStates[h.rawValue] = true
        buttonStates[h.rawValue] = false
        return h
    }
    public func createRadioButton(title: String, frame: NSRect) -> NativeHandle {
        let h = allocate(.radio)
        titles[h.rawValue] = title
        texts[h.rawValue] = title
        frames[h.rawValue] = frame
        enabledStates[h.rawValue] = true
        buttonStates[h.rawValue] = false
        return h
    }
    public func groupRadioButtons(_ handles: [NativeHandle]) {
        let members = handles.map(\.rawValue)
        for raw in members { radioGroups[raw] = members }
    }
    public func createSlider(value: Double, minValue: Double, maxValue: Double, frame: NSRect) -> NativeHandle {
        let h = allocate(.slider)
        frames[h.rawValue] = frame
        ranges[h.rawValue] = (minValue, maxValue)
        doubleValues[h.rawValue] = value
        enabledStates[h.rawValue] = true
        return h
    }
    public func createProgressIndicator(value: Double, minValue: Double, maxValue: Double, frame: NSRect) -> NativeHandle {
        let h = allocate(.progress)
        frames[h.rawValue] = frame
        ranges[h.rawValue] = (minValue, maxValue)
        doubleValues[h.rawValue] = value
        return h
    }
    /// Progress-bar state, for tests.
    public private(set) var indeterminateProgress: Set<UInt> = []
    public private(set) var animatingProgress: Set<UInt> = []
    public func setProgressIndeterminate(_ indeterminate: Bool, for handle: NativeHandle) {
        if indeterminate { indeterminateProgress.insert(handle.rawValue) }
        else { indeterminateProgress.remove(handle.rawValue); animatingProgress.remove(handle.rawValue) }
    }
    public func setProgressAnimating(_ animating: Bool, for handle: NativeHandle) {
        if animating && indeterminateProgress.contains(handle.rawValue) { animatingProgress.insert(handle.rawValue) }
        else { animatingProgress.remove(handle.rawValue) }
    }
    public func createPopUpButton(items: [String], selectedIndex: Int, frame: NSRect) -> NativeHandle {
        let h = allocate(.popUp)
        frames[h.rawValue] = frame
        itemsByHandle[h.rawValue] = items
        selectedIndices[h.rawValue] = selectedIndex
        enabledStates[h.rawValue] = true
        return h
    }
    public func createStepper(value: Double, minValue: Double, maxValue: Double, stepSize: Double, frame: NSRect) -> NativeHandle {
        let h = allocate(.stepper)
        frames[h.rawValue] = frame
        ranges[h.rawValue] = (minValue, maxValue)
        doubleValues[h.rawValue] = value
        enabledStates[h.rawValue] = true
        return h
    }
    public func createLevelIndicator(value: Double, minValue: Double, maxValue: Double, frame: NSRect) -> NativeHandle {
        let h = allocate(.level)
        frames[h.rawValue] = frame
        ranges[h.rawValue] = (minValue, maxValue)
        doubleValues[h.rawValue] = value
        return h
    }
    public func createTextView(text: String, frame: NSRect) -> NativeHandle {
        let h = allocate(.textView)
        texts[h.rawValue] = text
        frames[h.rawValue] = frame
        enabledStates[h.rawValue] = true
        return h
    }
    public func createDatePicker(date: Date, frame: NSRect) -> NativeHandle {
        let h = allocate(.datePicker)
        frames[h.rawValue] = frame
        dates[h.rawValue] = date
        enabledStates[h.rawValue] = true
        return h
    }
    public func createColorWell(color: NSColor, frame: NSRect) -> NativeHandle {
        let h = allocate(.colorWell)
        frames[h.rawValue] = frame
        colors[h.rawValue] = color
        enabledStates[h.rawValue] = true
        return h
    }
    public func createTabView(frame: NSRect) -> NativeHandle {
        let h = allocate(.tabView)
        frames[h.rawValue] = frame
        selectedIndices[h.rawValue] = 0
        return h
    }
    public func addTabPage(_ page: NativeHandle, label: String, to tabView: NativeHandle) {
        tabPages[tabView.rawValue, default: []].append((page: page.rawValue, label: label))
    }
    public func createSegmentedControl(labels: [String], frame: NSRect) -> NativeHandle {
        let h = allocate(.segmented)
        frames[h.rawValue] = frame
        itemsByHandle[h.rawValue] = labels
        selectedIndices[h.rawValue] = -1
        enabledStates[h.rawValue] = true
        return h
    }
    public func createImageView(frame: NSRect) -> NativeHandle {
        let h = allocate(.imageView); frames[h.rawValue] = frame; return h
    }
    public func createTableView(frame: NSRect) -> NativeHandle {
        let h = allocate(.table)
        frames[h.rawValue] = frame
        selectedIndices[h.rawValue] = -1
        return h
    }
    public func addTableColumn(title: String, to table: NativeHandle) {
        tableColumns[table.rawValue, default: []].append(title)
    }
    public func setTableColumnTitle(_ title: String, columnIndex: Int, for table: NativeHandle) {
        guard var cols = tableColumns[table.rawValue], columnIndex < cols.count else { return }
        cols[columnIndex] = title
        tableColumns[table.rawValue] = cols
    }
    public func setColumnSortable(_ columnIndex: Int, for table: NativeHandle) {
        sortableColumns[table.rawValue, default: []].insert(columnIndex)
    }
    public func setSortChangeAction(for table: NativeHandle, action: @escaping (Int, Bool) -> Void) {
        sortActions[table.rawValue] = action
    }
    public func setRowActivateAction(for table: NativeHandle, action: @escaping (Int) -> Void) {
        rowActivateActions[table.rawValue] = action
    }
    /// Test hook: simulates a click on a sortable column header.
    public func simulateSortColumn(_ columnIndex: Int, ascending: Bool, on table: NativeHandle) {
        sortActions[table.rawValue]?(columnIndex, ascending)
    }
    /// Test hook: simulates activating a row (double-click / Enter).
    public func simulateRowActivate(_ row: Int, on table: NativeHandle) {
        rowActivateActions[table.rawValue]?(row)
    }
    public func setTableRowCount(_ count: Int, for table: NativeHandle) {
        tableRowCounts[table.rawValue] = count
    }
    public func setTableCellProvider(for table: NativeHandle, provider: @escaping (Int, Int) -> String) {
        tableCellProviders[table.rawValue] = provider
    }
    /// The text a table would render at (row, columnIndex) — test hook.
    public func tableCellText(_ table: NativeHandle, row: Int, column: Int) -> String {
        tableCellProviders[table.rawValue]?(row, column) ?? ""
    }
    public func createOutlineView(frame: NSRect) -> NativeHandle {
        let h = allocate(.outline)
        frames[h.rawValue] = frame
        selectedIndices[h.rawValue] = -1
        return h
    }
    public func addOutlineColumn(title: String, to outline: NativeHandle) {
        outlineColumns[outline.rawValue, default: []].append(title)
    }
    public func setOutlineRootCount(_ count: Int, for outline: NativeHandle) {
        outlineRootCounts[outline.rawValue] = count
    }
    public func setOutlineProviders(
        for outline: NativeHandle,
        childCount: @escaping (String) -> Int,
        cellText: @escaping (String, Int) -> String
    ) {
        outlineChildCountProviders[outline.rawValue] = childCount
        outlineCellTextProviders[outline.rawValue] = cellText
    }
    /// The number of children an outline reports at `path` — test hook.
    public func outlineChildCount(_ outline: NativeHandle, path: String) -> Int {
        outlineChildCountProviders[outline.rawValue]?(path) ?? 0
    }
    /// The text an outline renders at (`path`, columnIndex) — test hook.
    public func outlineCellText(_ outline: NativeHandle, path: String, column: Int) -> String {
        outlineCellTextProviders[outline.rawValue]?(path, column) ?? ""
    }
    public func createCollectionView(frame: NSRect) -> NativeHandle {
        let h = allocate(.collection)
        frames[h.rawValue] = frame
        selectedIndices[h.rawValue] = -1
        return h
    }
    public func setCollectionItemCount(_ count: Int, for collection: NativeHandle) {
        collectionItemCounts[collection.rawValue] = count
    }
    /// Recorded item-view providers, for tests.
    public private(set) var collectionItemViewProviders: [UInt: (Int) -> NativeHandle?] = [:]
    public func setCollectionItemViewProvider(for collection: NativeHandle, provider: @escaping (Int) -> NativeHandle?) {
        collectionItemViewProviders[collection.rawValue] = provider
    }

    private var clickActions: [UInt: (Double, Double) -> Void] = [:]
    public func setClickAction(for handle: NativeHandle, action: @escaping (Double, Double) -> Void) {
        clickActions[handle.rawValue] = action
    }
    /// Test hook: click a view at a position in its own coordinates.
    public func simulateClick(at x: Double, _ y: Double, for handle: NativeHandle) {
        clickActions[handle.rawValue]?(x, y)
    }

    public func setCollectionItemProvider(for collection: NativeHandle, provider: @escaping (Int) -> String) {
        collectionItemProviders[collection.rawValue] = provider
    }
    /// The text a collection tile would render at `index` — test hook.
    public func collectionItemText(_ collection: NativeHandle, index: Int) -> String {
        collectionItemProviders[collection.rawValue]?(index) ?? ""
    }
    public func createTokenField(tokens: [String], frame: NSRect) -> NativeHandle {
        let h = allocate(.tokenField)
        frames[h.rawValue] = frame
        tokensByHandle[h.rawValue] = tokens
        enabledStates[h.rawValue] = true
        return h
    }
    public func setTokens(_ tokens: [String], for handle: NativeHandle) {
        tokensByHandle[handle.rawValue] = tokens
    }
    public func setTokensChangeAction(for handle: NativeHandle, action: @escaping ([String]) -> Void) {
        tokensChangeActions[handle.rawValue] = action
    }
    /// Simulates the user adding/removing tokens (e.g. typing one and hitting Enter).
    public func simulateTokensChange(_ handle: NativeHandle, _ tokens: [String]) {
        tokensByHandle[handle.rawValue] = tokens
        tokensChangeActions[handle.rawValue]?(tokens)
    }
    public func setImagePath(_ path: String?, for handle: NativeHandle) {
        if let path { imagePaths[handle.rawValue] = path } else { imagePaths[handle.rawValue] = nil }
    }
    public func createBox(title: String, frame: NSRect) -> NativeHandle {
        let h = allocate(.box)
        titles[h.rawValue] = title
        texts[h.rawValue] = title
        frames[h.rawValue] = frame
        return h
    }
    public func createScrollView(frame: NSRect) -> NativeHandle {
        let h = allocate(.scrollView); frames[h.rawValue] = frame; return h
    }

    /// Whether each scroller is allowed to appear, per scroll view.
    public private(set) var scrollerPolicies: [UInt: (vertical: Bool, horizontal: Bool)] = [:]
    private var scrollOffsets: [UInt: NSPoint] = [:]
    private var scrollActions: [UInt: (Double, Double) -> Void] = [:]

    public func setScrollerPolicy(vertical: Bool, horizontal: Bool, for handle: NativeHandle) {
        scrollerPolicies[handle.rawValue] = (vertical, horizontal)
    }
    public func scrollDocumentSize(for handle: NativeHandle) -> (width: Double, height: Double) {
        // The document view's frame is the scrollable content size.
        let docFrame = contentViews[handle.rawValue].flatMap { frames[$0] } ?? frames[handle.rawValue] ?? .zero
        return (Double(docFrame.width), Double(docFrame.height))
    }
    public func scrollVisibleSize(for handle: NativeHandle) -> (width: Double, height: Double) {
        let frame = frames[handle.rawValue] ?? .zero
        return (Double(frame.width), Double(frame.height))
    }
    public func setScrollOffset(x: Double, y: Double, for handle: NativeHandle) {
        // Clamp to the scrollable range, as GTK's adjustments do.
        let doc = scrollDocumentSize(for: handle), vis = scrollVisibleSize(for: handle)
        let cx = min(max(0, x), max(0, doc.width - vis.width))
        let cy = min(max(0, y), max(0, doc.height - vis.height))
        scrollOffsets[handle.rawValue] = NSMakePoint(CGFloat(cx), CGFloat(cy))
        scrollActions[handle.rawValue]?(cx, cy)
    }
    public func scrollOffset(for handle: NativeHandle) -> (x: Double, y: Double) {
        let p = scrollOffsets[handle.rawValue] ?? .zero
        return (Double(p.x), Double(p.y))
    }
    public func setScrollChangeAction(for handle: NativeHandle, action: @escaping (Double, Double) -> Void) {
        scrollActions[handle.rawValue] = action
    }

    /// Test hook: simulates the user scrolling to `(x, y)` (clamped), firing the
    /// scroll-change action.
    public func simulateScroll(to point: NSPoint, on handle: NativeHandle) {
        setScrollOffset(x: Double(point.x), y: Double(point.y), for: handle)
    }
    public func createSplitView(vertical: Bool, frame: NSRect) -> NativeHandle {
        let h = allocate(.splitView); frames[h.rawValue] = frame; return h
    }
    public func addSplitPane(_ pane: NativeHandle, to splitView: NativeHandle) {
        splitPanes[splitView.rawValue, default: []].append(pane.rawValue)
    }
    public func setDividerPosition(_ position: Double, for splitView: NativeHandle) {
        dividerPositions[splitView.rawValue] = position
    }
    public func addSubview(_ child: NativeHandle, to parent: NativeHandle) {
        subviews[parent.rawValue, default: []].append(child.rawValue)
    }
    public private(set) var clippedViews: Set<UInt> = []
    public func setClipsToBounds(_ clips: Bool, for handle: NativeHandle) {
        if clips { clippedViews.insert(handle.rawValue) } else { clippedViews.remove(handle.rawValue) }
    }
    public func setViewFlipped(_ flipped: Bool, for handle: NativeHandle) {
        flippedViews[handle.rawValue] = flipped
    }
    public func setSliderVertical(_ vertical: Bool, for handle: NativeHandle) {
        sliderVerticals[handle.rawValue] = vertical
    }
    /// Recorded date ranges, for tests.
    public private(set) var dateRanges: [UInt: (min: Date?, max: Date?)] = [:]
    public func setDateRange(min: Date?, max: Date?, for handle: NativeHandle) {
        dateRanges[handle.rawValue] = (min, max)
        // Clamping is the control's contract, so model it here too.
        if let current = dates[handle.rawValue] {
            if let min, current < min { setDateValue(min, for: handle) }
            if let max, current > max { setDateValue(max, for: handle) }
        }
    }

    /// The compact field's rendered text, for tests.
    public private(set) var datePickerTexts: [UInt: String] = [:]
    public func setDatePickerText(_ text: String, for handle: NativeHandle) {
        datePickerTexts[handle.rawValue] = text
    }

    /// The highlighted element's range, for tests.
    public private(set) var datePickerSelections: [UInt: (location: Int, length: Int)] = [:]
    public func setDatePickerSelection(location: Int, length: Int, for handle: NativeHandle) {
        datePickerSelections[handle.rawValue] = (location, length)
    }

    private var dateStepActions: [UInt: (Int) -> Void] = [:]
    public func setDateStepAction(for handle: NativeHandle, action: @escaping (Int) -> Void) {
        dateStepActions[handle.rawValue] = action
    }
    /// Test hook: press the picker's stepper.
    public func simulateDateStep(_ direction: Int, for handle: NativeHandle) {
        dateStepActions[handle.rawValue]?(direction)
    }

    private var datePickerCursorActions: [UInt: (Int) -> Void] = [:]
    public func setDatePickerCursorAction(for handle: NativeHandle, action: @escaping (Int) -> Void) {
        datePickerCursorActions[handle.rawValue] = action
    }
    /// Test hook: click the compact field at a character offset.
    public func simulateDatePickerClick(atCharacter offset: Int, for handle: NativeHandle) {
        datePickerCursorActions[handle.rawValue]?(offset)
    }

    private var datePickerTypeActions: [UInt: (String) -> Void] = [:]
    public func setDatePickerTypeAction(for handle: NativeHandle, action: @escaping (String) -> Void) {
        datePickerTypeActions[handle.rawValue] = action
    }
    /// Test hook: type into the compact field's selected element.
    public func simulateDatePickerTyping(_ text: String, for handle: NativeHandle) {
        for character in text { datePickerTypeActions[handle.rawValue]?(String(character)) }
    }

    private var datePickerMoveActions: [UInt: (Int) -> Void] = [:]
    public func setDatePickerMoveAction(for handle: NativeHandle, action: @escaping (Int) -> Void) {
        datePickerMoveActions[handle.rawValue] = action
    }
    /// Test hook: press left/right in the compact field.
    public func simulateDatePickerMove(_ delta: Int, for handle: NativeHandle) {
        datePickerMoveActions[handle.rawValue]?(delta)
    }

    /// Level indicator state, for tests.
    public private(set) var levelStyles: [UInt: Int] = [:]
    public private(set) var levelEditable: [UInt: Bool] = [:]
    public private(set) var levelThresholds: [UInt: (warning: Double, critical: Double)] = [:]
    public func setLevelIndicatorStyle(_ rawValue: Int, for handle: NativeHandle) {
        levelStyles[handle.rawValue] = rawValue
    }
    public func setLevelIndicatorEditable(_ editable: Bool, for handle: NativeHandle) {
        levelEditable[handle.rawValue] = editable
    }
    public func setLevelIndicatorRange(min: Double, max: Double, for handle: NativeHandle) {
        ranges[handle.rawValue] = (min, max)
    }
    public func setLevelThresholds(warning: Double, critical: Double, for handle: NativeHandle) {
        levelThresholds[handle.rawValue] = (warning, critical)
    }
    private var levelChangeActions: [UInt: (Double) -> Void] = [:]
    public func setLevelChangeAction(for handle: NativeHandle, action: @escaping (Double) -> Void) {
        levelChangeActions[handle.rawValue] = action
    }
    /// Test hook: click an editable indicator to set `value`.
    public func simulateLevelClick(to value: Double, for handle: NativeHandle) {
        levelChangeActions[handle.rawValue]?(value)
    }

    /// Standalone scrollers, for tests.
    public private(set) var scrollerGeometry: [UInt: (value: Double, knobProportion: Double)] = [:]
    public func createScroller(vertical: Bool, frame: NSRect) -> NativeHandle {
        let h = allocate(.scroller)
        frames[h.rawValue] = frame
        enabledStates[h.rawValue] = false    // AppKit's NSScroller starts disabled
        scrollerGeometry[h.rawValue] = (0, 1)
        return h
    }
    public func setScrollerGeometry(value: Double, knobProportion: Double, for handle: NativeHandle) {
        scrollerGeometry[handle.rawValue] = (value, knobProportion)
    }
    private var scrollerActions: [UInt: (Double) -> Void] = [:]
    public func setScrollerAction(for handle: NativeHandle, action: @escaping (Double) -> Void) {
        scrollerActions[handle.rawValue] = action
    }
    /// Test hook: drag a standalone scroller to `value`.
    public func simulateScrollerDrag(to value: Double, for handle: NativeHandle) {
        scrollerActions[handle.rawValue]?(value)
    }

    public func setDatePickerGraphical(_ graphical: Bool, for handle: NativeHandle) {
        datePickerGraphical[handle.rawValue] = graphical
    }
    public func setTextEditable(_ editable: Bool, for handle: NativeHandle) {
        textEditable[handle.rawValue] = editable
    }
    public func setBackgroundColor(_ color: NSColor?, for handle: NativeHandle) {
        backgroundColors[handle.rawValue] = color
    }
    public func setButtonKind(_ kind: NativeButtonKind, title: String, for handle: NativeHandle) {
        switch kind {
        case .push:     kinds[handle.rawValue] = .button
        case .checkbox: kinds[handle.rawValue] = .checkbox
        case .radio:    kinds[handle.rawValue] = .radio
        }
        texts[handle.rawValue] = title
    }

    // MARK: Mutators
    public func setText(_ text: String, for handle: NativeHandle) { texts[handle.rawValue] = text }
    public func setFrame(_ frame: NSRect, for handle: NativeHandle) { frames[handle.rawValue] = frame }
    public func setEnabled(_ isEnabled: Bool, for handle: NativeHandle) { enabledStates[handle.rawValue] = isEnabled }
    public private(set) var hiddenStates: [UInt: Bool] = [:]
    public func setHidden(_ isHidden: Bool, for handle: NativeHandle) { hiddenStates[handle.rawValue] = isHidden }
    public func setFont(_ font: NativeFontSpec, for handle: NativeHandle) { fonts[handle.rawValue] = font }
    public func setTextColor(_ color: NSColor, for handle: NativeHandle) { textColors[handle.rawValue] = color }
    public func setMaterial(_ material: String, for handle: NativeHandle) { materials[handle.rawValue] = material }
    public func setStyledText(_ runs: [NativeTextRun], for handle: NativeHandle) {
        styledTexts[handle.rawValue] = runs
        texts[handle.rawValue] = runs.map(\.text).joined()
    }
    public func setDrawHandler(for handle: NativeHandle, handler: @escaping (NativeGraphicsContext, Double, Double) -> Void) {
        drawHandlers[handle.rawValue] = handler
    }
    public func setNeedsDisplay(_ handle: NativeHandle) {
        displayRequests[handle.rawValue, default: 0] += 1
        // Draw synchronously so tests can assert the recorded ops immediately.
        guard let handler = drawHandlers[handle.rawValue] else { return }
        let frame = frames[handle.rawValue] ?? .zero
        let context = RecordingGraphicsContext()
        handler(context, Double(frame.width), Double(frame.height))
        lastDrawOps[handle.rawValue] = context.ops
    }
    public func destroyControl(_ handle: NativeHandle) {
        let r = handle.rawValue
        kinds[r] = nil; titles[r] = nil; texts[r] = nil; frames[r] = nil
        enabledStates[r] = nil; actions[r] = nil
    }

    // MARK: Events
    public func registerAction(for handle: NativeHandle, action: @escaping () -> Void) {
        actions[handle.rawValue] = action
    }
    private var submitActions: [UInt: () -> Void] = [:]
    public func setSubmitAction(for handle: NativeHandle, action: @escaping () -> Void) {
        submitActions[handle.rawValue] = action
    }
    /// Test hook: submit (Enter) a field.
    public func simulateSubmit(for handle: NativeHandle) { submitActions[handle.rawValue]?() }

    public func setTextChangeAction(for handle: NativeHandle, action: @escaping (String) -> Void) {
        textChangeActions[handle.rawValue] = action
    }
    public func setButtonState(_ on: Bool, for handle: NativeHandle) {
        buttonStates[handle.rawValue] = on
    }
    public func setDoubleValue(_ value: Double, for handle: NativeHandle) {
        doubleValues[handle.rawValue] = value
    }
    public func setSelectedIndex(_ index: Int, for handle: NativeHandle) {
        selectedIndices[handle.rawValue] = index
    }
    public func setPopUpItems(_ titles: [String], selectedIndex: Int, for handle: NativeHandle) {
        popUpItems[handle.rawValue] = titles
        selectedIndices[handle.rawValue] = selectedIndex
    }
    public func setToggleAction(for handle: NativeHandle, action: @escaping (Bool) -> Void) {
        toggleActions[handle.rawValue] = action
    }
    public func setValueChangeAction(for handle: NativeHandle, action: @escaping (Double) -> Void) {
        valueChangeActions[handle.rawValue] = action
    }
    public func setSelectionChangeAction(for handle: NativeHandle, action: @escaping (Int) -> Void) {
        selectionActions[handle.rawValue] = action
    }
    public func setDateValue(_ date: Date, for handle: NativeHandle) {
        dates[handle.rawValue] = date
    }
    public func setColor(_ color: NSColor, for handle: NativeHandle) {
        colors[handle.rawValue] = color
    }
    public func setDateChangeAction(for handle: NativeHandle, action: @escaping (Date) -> Void) {
        dateChangeActions[handle.rawValue] = action
    }
    public func setColorChangeAction(for handle: NativeHandle, action: @escaping (NSColor) -> Void) {
        colorChangeActions[handle.rawValue] = action
    }

    // MARK: Test hooks (not part of the protocol)
    /// Fires the action registered for a control, as if the user clicked it.
    public func simulateClick(_ handle: NativeHandle) { actions[handle.rawValue]?() }
    /// Fires a window's close action, as if the user closed it.
    public func simulateWindowClose(_ handle: NativeHandle) { windowCloseActions[handle.rawValue]?() }
    /// Simulates the user editing a text field to `text`.
    public func simulateTextChange(_ handle: NativeHandle, _ text: String) {
        texts[handle.rawValue] = text
        textChangeActions[handle.rawValue]?(text)
    }
    /// Simulates the user toggling a checkbox to `on`.
    public func simulateToggle(_ handle: NativeHandle, _ on: Bool) {
        buttonStates[handle.rawValue] = on
        toggleActions[handle.rawValue]?(on)
    }
    /// Whether a checkbox is on.
    public func isOn(_ handle: NativeHandle) -> Bool { buttonStates[handle.rawValue] ?? false }
    /// Simulates the user selecting a radio button: it turns on, its group peers
    /// turn off, and its toggle action fires.
    public func simulateRadioSelect(_ handle: NativeHandle) {
        let raw = handle.rawValue
        // Like GTK: the newly-selected radio and the previously-selected one both
        // fire `toggled` (on and off respectively); unchanged peers stay quiet.
        for peer in radioGroups[raw] ?? [raw] {
            let newState = (peer == raw)
            if (buttonStates[peer] ?? false) != newState {
                buttonStates[peer] = newState
                toggleActions[peer]?(newState)
            }
        }
    }
    /// Simulates the user moving a slider to `value`.
    public func simulateValueChange(_ handle: NativeHandle, _ value: Double) {
        doubleValues[handle.rawValue] = value
        valueChangeActions[handle.rawValue]?(value)
    }
    /// Simulates the user choosing pop-up item `index`.
    public func simulateSelection(_ handle: NativeHandle, _ index: Int) {
        selectedIndices[handle.rawValue] = index
        selectionActions[handle.rawValue]?(index)
    }
    /// Fires the action of menu item `itemIndex` in top-level menu `menuIndex`,
    /// as if the user picked it from the window's menu bar.
    public func simulateMenuActivate(_ window: NativeHandle, menu menuIndex: Int, item itemIndex: Int) {
        guard let menus = menuBars[window.rawValue],
              menuIndex < menus.count, itemIndex < menus[menuIndex].items.count else { return }
        menus[menuIndex].items[itemIndex].action?()
    }
    /// Simulates the user picking a date.
    public func simulateDateChange(_ handle: NativeHandle, _ date: Date) {
        dates[handle.rawValue] = date
        dateChangeActions[handle.rawValue]?(date)
    }
    /// Simulates the user choosing a color.
    public func simulateColorChange(_ handle: NativeHandle, _ color: NSColor) {
        colors[handle.rawValue] = color
        colorChangeActions[handle.rawValue]?(color)
    }
    /// The current date-picker date.
    public func date(_ handle: NativeHandle) -> Date? { dates[handle.rawValue] }
    /// The current color-well color.
    public func color(_ handle: NativeHandle) -> NSColor? { colors[handle.rawValue] }
    /// The current slider/progress value.
    public func doubleValue(_ handle: NativeHandle) -> Double { doubleValues[handle.rawValue] ?? 0 }
    /// The current pop-up selection index.
    public func selectedIndex(_ handle: NativeHandle) -> Int { selectedIndices[handle.rawValue] ?? -1 }
    /// The text currently recorded for a control.
    public func text(for handle: NativeHandle) -> String? { texts[handle.rawValue] }
    /// Whether a window has been shown.
    public func isVisible(_ handle: NativeHandle) -> Bool { visibleWindows.contains(handle.rawValue) }
    /// Whether a control is enabled.
    public func isEnabled(_ handle: NativeHandle) -> Bool { enabledStates[handle.rawValue] ?? true }
}
