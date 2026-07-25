import Foundation

/// Graphics context that records its operations as readable strings, so
/// contract tests can assert an entire draw pass without a display.
public final class RecordingGraphicsContext: NativeGraphicsContext {
    /// The operations recorded since this context was created, in call order.
    public private(set) var ops: [String] = []
    /// Creates an empty recording context.
    public init() {}

    private func rgb(_ c: NSColor) -> String {
        String(format: "%.2f,%.2f,%.2f", c.redComponent, c.greenComponent, c.blueComponent)
    }
    /// Records `fillColor(r,g,b)`.
    public func setFillColor(_ color: NSColor) { ops.append("fillColor(\(rgb(color)))") }
    /// Records `strokeColor(r,g,b)`.
    public func setStrokeColor(_ color: NSColor) { ops.append("strokeColor(\(rgb(color)))") }
    /// Records `lineWidth(width)`.
    public func setLineWidth(_ width: Double) { ops.append("lineWidth(\(Int(width)))") }
    /// Records `begin`.
    public func beginPath() { ops.append("begin") }
    /// Records `move(x,y)`.
    public func move(toX x: Double, y: Double) { ops.append("move(\(Int(x)),\(Int(y)))") }
    /// Records `line(x,y)`.
    public func line(toX x: Double, y: Double) { ops.append("line(\(Int(x)),\(Int(y)))") }
    /// Records `curve(x,y)` (control points omitted for brevity).
    public func curve(toX x: Double, y: Double, c1x: Double, c1y: Double, c2x: Double, c2y: Double) {
        ops.append("curve(\(Int(x)),\(Int(y)))")
    }
    /// Records `arc(cx,cy,radius)`.
    public func addArc(centerX: Double, centerY: Double, radius: Double, startAngleRadians: Double, endAngleRadians: Double, clockwise: Bool) {
        ops.append("arc(\(Int(centerX)),\(Int(centerY)),\(Int(radius)))")
    }
    /// Records `close`.
    public func closePath() { ops.append("close") }
    /// Records `fill`.
    public func fillPath() { ops.append("fill") }
    /// Records `stroke`.
    public func strokePath() { ops.append("stroke") }
    /// Records `save`.
    public func saveState() { ops.append("save") }
    /// Records `restore`.
    public func restoreState() { ops.append("restore") }
    /// Records `clip`.
    public func clipToCurrentPath() { ops.append("clip") }
    /// Records the linear-gradient stops and angle as a single string.
    public func fillLinearGradient(_ stops: [NativeGradientStop], inRect rect: NSRect, angleDegrees: Double) {
        ops.append("linearGradient[\(stops.map { rgb($0.color) }.joined(separator: ";"))]@\(Int(angleDegrees))")
    }
    /// Records the radial-gradient stops as a single string.
    public func fillRadialGradient(_ stops: [NativeGradientStop], inRect rect: NSRect) {
        ops.append("radialGradient[\(stops.map { rgb($0.color) }.joined(separator: ";"))]")
    }
    /// Records `text(str)@x,y`.
    public func drawText(_ text: String, at point: NSPoint, font: NativeFontSpec?, color: NSColor) {
        ops.append("text(\(text))@\(Int(point.x)),\(Int(point.y))")
    }
    /// Records `image(filename)@x,y`.
    public func drawImage(atPath path: String, inRect rect: NSRect) {
        ops.append("image(\((path as NSString).lastPathComponent))@\(Int(rect.minX)),\(Int(rect.minY))")
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

    /// Whether `runApplication` has been called and `terminateApplication` has not.
    public private(set) var isRunning = false
    /// Kind of each allocated handle, indexed by raw value.
    public private(set) var kinds: [UInt: Kind] = [:]
    /// Title assigned to each handle (window title, button title, etc.).
    public private(set) var titles: [UInt: String] = [:]
    /// Text content of each handle (label, field, text view).
    public private(set) var texts: [UInt: String] = [:]
    /// Frame currently assigned to each handle.
    public private(set) var frames: [UInt: NSRect] = [:]
    /// Enabled state for each handle.
    public private(set) var enabledStates: [UInt: Bool] = [:]
    /// The content view installed for each window/box/scroll view.
    public private(set) var contentViews: [UInt: UInt] = [:]
    /// Subview raw values for each parent view, in insertion order.
    public private(set) var subviews: [UInt: [UInt]] = [:]
    /// Set of window handles currently shown.
    public private(set) var visibleWindows: Set<UInt> = []
    /// On/off state for each checkbox or radio button.
    public private(set) var buttonStates: [UInt: Bool] = [:]
    /// Current double value for each slider/progress/level/stepper.
    public private(set) var doubleValues: [UInt: Double] = [:]
    /// Selected index for each pop-up, tab, or table.
    public private(set) var selectedIndices: [UInt: Int] = [:]
    /// Item titles for each pop-up button.
    public private(set) var popUpItems: [UInt: [String]] = [:]
    /// Whether each view is flipped (top-left coordinates).
    public private(set) var flippedViews: [UInt: Bool] = [:]
    /// Whether each slider is oriented vertically.
    public private(set) var sliderVerticals: [UInt: Bool] = [:]
    /// Whether each date picker uses the graphical calendar style.
    public private(set) var datePickerGraphical: [UInt: Bool] = [:]
    /// Whether each text field is editable.
    public private(set) var textEditable: [UInt: Bool] = [:]
    /// Background color assigned to each view (nil = cleared).
    public private(set) var backgroundColors: [UInt: NSColor?] = [:]
    /// Item lists (combo box, segmented control, pop-up) for each handle.
    public private(set) var itemsByHandle: [UInt: [String]] = [:]
    private var ranges: [UInt: (min: Double, max: Double)] = [:]
    private var radioGroups: [UInt: [UInt]] = [:]   // member -> all members in its group
    private var actions: [UInt: () -> Void] = [:]
    private var windowCloseActions: [UInt: () -> Void] = [:]
    private var textChangeActions: [UInt: (String) -> Void] = [:]
    private var toggleActions: [UInt: (Bool) -> Void] = [:]
    private var valueChangeActions: [UInt: (Double) -> Void] = [:]
    private var selectionActions: [UInt: (Int) -> Void] = [:]
    /// Current date for each date picker.
    public private(set) var dates: [UInt: Date] = [:]
    /// Current color for each color well.
    public private(set) var colors: [UInt: NSColor] = [:]
    /// Tab pages appended to each tab view.
    public private(set) var tabPages: [UInt: [(page: UInt, label: String)]] = [:]
    /// Panes added to each split view.
    public private(set) var splitPanes: [UInt: [UInt]] = [:]
    /// Divider positions set on each split view.
    public private(set) var dividerPositions: [UInt: Double] = [:]
    /// Menu-bar contents installed for each window.
    public private(set) var menuBars: [UInt: [NativeMenuSpec]] = [:]
    /// Toolbar contents installed for each window.
    public private(set) var toolbars: [UInt: [NativeToolbarItemSpec]] = [:]
    /// Image file path assigned to each image view.
    public private(set) var imagePaths: [UInt: String] = [:]
    /// Tokens present in each token field.
    public private(set) var tokensByHandle: [UInt: [String]] = [:]
    /// Font applied to each control.
    public private(set) var fonts: [UInt: NativeFontSpec] = [:]
    /// Text color applied to each control.
    public private(set) var textColors: [UInt: NSColor] = [:]
    /// Styled (attributed) text applied to each label.
    public private(set) var styledTexts: [UInt: [NativeTextRun]] = [:]
    /// The ops recorded by the most recent draw of each view.
    public private(set) var lastDrawOps: [UInt: [String]] = [:]
    /// Number of `setNeedsDisplay` calls received per view.
    public private(set) var displayRequests: [UInt: Int] = [:]
    private var drawHandlers: [UInt: (NativeGraphicsContext, Double, Double) -> Void] = [:]
    /// Column titles for each table.
    public private(set) var tableColumns: [UInt: [String]] = [:]
    /// Set of column indices marked sortable, per table.
    public private(set) var sortableColumns: [UInt: Set<Int>] = [:]
    private var sortActions: [UInt: (Int, Bool) -> Void] = [:]
    private var rowActivateActions: [UInt: (Int) -> Void] = [:]
    /// Row count set on each table.
    public private(set) var tableRowCounts: [UInt: Int] = [:]
    private var tableCellProviders: [UInt: (Int, Int) -> String] = [:]
    /// Item count set on each collection view.
    public private(set) var collectionItemCounts: [UInt: Int] = [:]
    private var collectionItemProviders: [UInt: (Int) -> String] = [:]
    /// Column titles for each outline view.
    public private(set) var outlineColumns: [UInt: [String]] = [:]
    /// Root-level item count for each outline view.
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

    /// Creates an empty in-memory backend.
    public init() {}

    private func allocate(_ kind: Kind) -> NativeHandle {
        defer { nextRaw += 1 }
        kinds[nextRaw] = kind
        return NativeHandle(rawValue: nextRaw)
    }

    // MARK: Application lifecycle
    /// Scheduled timers, for tests: fire them with `simulateTimerTick`.
    public private(set) var scheduledTimers: [(interval: Double, repeats: Bool, block: () -> Void)] = []
    /// Records a scheduled timer for later inspection or firing.
    public func scheduleTimer(interval: Double, repeats: Bool, _ block: @escaping () -> Void) {
        scheduledTimers.append((interval, repeats, block))
    }
    /// Test hook: fire every scheduled timer once.
    public func simulateTimerTick() {
        for timer in scheduledTimers { timer.block() }
    }

    /// Marks the backend as running.
    public func runApplication() { isRunning = true }
    /// Marks the backend as stopped.
    public func terminateApplication() { isRunning = false }

    // MARK: Windows
    /// Allocates a window handle, recording its title and frame.
    public func createWindow(title: String, frame: NSRect, styleMask: NSWindow.StyleMask) -> NativeHandle {
        let h = allocate(.window)
        titles[h.rawValue] = title
        frames[h.rawValue] = frame
        return h
    }
    /// Records `view` as the content view for `window`.
    public func setContentView(_ view: NativeHandle, for window: NativeHandle) {
        contentViews[window.rawValue] = view.rawValue
    }
    /// Marks the window visible (and un-hides it if hidden).
    public func showWindow(_ handle: NativeHandle) {
        visibleWindows.insert(handle.rawValue)
        hiddenWindows.remove(handle.rawValue)   // re-presenting un-hides
    }
    /// Records a new title for the window.
    public func setWindowTitle(_ title: String, for handle: NativeHandle) {
        titles[handle.rawValue] = title
    }
    /// Hidden (ordered-out) windows, for tests.
    public private(set) var hiddenWindows: Set<UInt> = []
    /// Records the window as hidden and no longer visible.
    public func hideWindow(_ handle: NativeHandle) {
        hiddenWindows.insert(handle.rawValue)
        visibleWindows.remove(handle.rawValue)
    }

    /// Records the close action for a window.
    public func registerWindowCloseAction(for handle: NativeHandle, action: @escaping () -> Void) {
        windowCloseActions[handle.rawValue] = action
    }
    /// Records the menu bar installed on a window.
    public func installMenuBar(_ menus: [NativeMenuSpec], on window: NativeHandle) {
        menuBars[window.rawValue] = menus
    }
    /// Toolbar display mode installed per window.
    public private(set) var toolbarDisplayModes: [UInt: NativeToolbarDisplayMode] = [:]
    /// Records the toolbar items and display mode for a window.
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
    /// Records the customization session and handlers as if the panel had opened.
    public func runToolbarCustomization(_ session: NativeToolbarCustomizationSession,
                                        handlers: NativeToolbarCustomizationHandlers,
                                        for window: NativeHandle) {
        toolbarCustomizationSession = session
        toolbarCustomizationItems = session.palette
        toolbarCustomizationHandlers = handlers
        toolbarCustomizationClose = handlers.onClose
    }

    /// Replaces the recorded customization session with a refreshed snapshot.
    public func updateToolbarCustomization(_ session: NativeToolbarCustomizationSession) {
        toolbarCustomizationSession = session
        toolbarCustomizationItems = session.palette
    }

    /// The last session pushed to the (recorded) customization panel.
    public private(set) var toolbarCustomizationSession: NativeToolbarCustomizationSession?
    private var toolbarCustomizationHandlers: NativeToolbarCustomizationHandlers?

    /// Test hooks: drive the panel exactly as drags would.
    /// Simulates dragging `identifier` from the palette into the strip at `index`.
    public func simulateToolbarCustomizationInsert(_ identifier: String, at index: Int) {
        toolbarCustomizationHandlers?.onInsert(identifier, index)
    }
    /// Simulates dragging the strip item at `index` out to remove it.
    public func simulateToolbarCustomizationRemove(at index: Int) {
        toolbarCustomizationHandlers?.onRemove(index)
    }
    /// Simulates dragging a strip item from one position to another.
    public func simulateToolbarCustomizationMove(from: Int, to: Int) {
        toolbarCustomizationHandlers?.onMove(from, to)
    }
    /// Simulates dragging the default-set tile in to reset the toolbar.
    public func simulateToolbarCustomizationReset() {
        toolbarCustomizationHandlers?.onResetToDefault()
    }
    /// Simulates the user choosing display-mode ordinal `index`.
    public func simulateToolbarCustomizationDisplayMode(_ index: Int) {
        toolbarCustomizationHandlers?.onDisplayMode(index)
    }
    /// Test hook: closes the open customization palette.
    public func simulateToolbarCustomizationClose() {
        toolbarCustomizationClose?()
    }
    /// Records an alert invocation and returns `nextAlertResponse` as the pressed button.
    public func runAlert(message: String, informative: String, buttons: [String], for window: NativeHandle?) -> Int {
        alerts.append((message: message, informative: informative, buttons: buttons))
        return nextAlertResponse
    }
    /// Records an open-panel invocation and returns `nextOpenPanelPath`.
    public func runOpenPanel(directory: String?, for window: NativeHandle?) -> String? {
        openPanelRuns.append(directory)
        return nextOpenPanelPath
    }
    /// Records a save-panel invocation and returns `nextSavePanelPath`.
    public func runSavePanel(directory: String?, suggestedName: String?, for window: NativeHandle?) -> String? {
        savePanelRuns.append((directory: directory, suggestedName: suggestedName))
        return nextSavePanelPath
    }

    // MARK: Appearance
    /// Records the current appearance mode.
    public func setAppearanceDark(_ dark: Bool) { appearanceIsDark = dark }

    // MARK: Popover
    /// The content view installed for each popover.
    public private(set) var popoverContents: [UInt: UInt] = [:]
    /// Set of popovers currently shown.
    public private(set) var shownPopovers: Set<UInt> = []
    /// Allocates a popover handle (represented as a view).
    public func createPopover() -> NativeHandle { allocate(.view) }
    /// Records `content` and its size as the popover's payload.
    public func setPopoverContent(_ content: NativeHandle, size: NSSize, for popover: NativeHandle) {
        popoverContents[popover.rawValue] = content.rawValue
        frames[content.rawValue] = NSMakeRect(0, 0, size.width, size.height)
    }
    /// Marks the popover as shown.
    public func showPopover(_ popover: NativeHandle, relativeTo view: NativeHandle, rect: NSRect, edge: Int) {
        shownPopovers.insert(popover.rawValue)
    }
    /// Marks the popover as no longer shown.
    public func closePopover(_ popover: NativeHandle) {
        shownPopovers.remove(popover.rawValue)
    }

    // MARK: Pasteboard & drag-and-drop
    /// Stores the clipboard string.
    public func setClipboardString(_ string: String) { clipboard = string }
    /// Returns the last string written to the clipboard.
    public func clipboardString() -> String? { clipboard }
    /// Records the drop handler and accepted types for a view.
    public func registerDropTarget(for handle: NativeHandle, types: [String], onDrop: @escaping (String, Double, Double) -> Bool) {
        dropTargetTypes[handle.rawValue] = types
        dropHandlers[handle.rawValue] = onDrop
    }
    /// Records the drag-source provider for a view.
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
    /// Allocates a container-view handle at `frame`.
    public func createView(frame: NSRect) -> NativeHandle {
        let h = allocate(.view); frames[h.rawValue] = frame; return h
    }
    /// Allocates a push-button handle with the given title and frame.
    public func createButton(title: String, frame: NSRect) -> NativeHandle {
        let h = allocate(.button)
        titles[h.rawValue] = title
        texts[h.rawValue] = title
        frames[h.rawValue] = frame
        enabledStates[h.rawValue] = true
        return h
    }
    /// Allocates a static-label handle.
    public func createLabel(text: String, frame: NSRect) -> NativeHandle {
        let h = allocate(.label); texts[h.rawValue] = text; frames[h.rawValue] = frame; return h
    }
    /// Allocates a single-line editable text-field handle.
    public func createTextField(text: String, frame: NSRect) -> NativeHandle {
        let h = allocate(.textField)
        texts[h.rawValue] = text
        frames[h.rawValue] = frame
        enabledStates[h.rawValue] = true
        return h
    }
    /// Allocates a secure (password) text-field handle.
    public func createSecureTextField(text: String, frame: NSRect) -> NativeHandle {
        let h = allocate(.secureField)
        texts[h.rawValue] = text; frames[h.rawValue] = frame; enabledStates[h.rawValue] = true
        return h
    }
    /// Allocates a search-field handle.
    public func createSearchField(text: String, frame: NSRect) -> NativeHandle {
        let h = allocate(.searchField)
        texts[h.rawValue] = text; frames[h.rawValue] = frame; enabledStates[h.rawValue] = true
        return h
    }
    /// Allocates a combo-box handle with the given items and initial text.
    public func createComboBox(items: [String], text: String, frame: NSRect) -> NativeHandle {
        let h = allocate(.comboBox)
        texts[h.rawValue] = text; frames[h.rawValue] = frame; enabledStates[h.rawValue] = true
        itemsByHandle[h.rawValue] = items
        return h
    }
    /// Allocates a checkbox handle (initial state off).
    public func createCheckbox(title: String, frame: NSRect) -> NativeHandle {
        let h = allocate(.checkbox)
        titles[h.rawValue] = title
        texts[h.rawValue] = title
        frames[h.rawValue] = frame
        enabledStates[h.rawValue] = true
        buttonStates[h.rawValue] = false
        return h
    }
    /// Allocates a radio-button handle (initial state off).
    public func createRadioButton(title: String, frame: NSRect) -> NativeHandle {
        let h = allocate(.radio)
        titles[h.rawValue] = title
        texts[h.rawValue] = title
        frames[h.rawValue] = frame
        enabledStates[h.rawValue] = true
        buttonStates[h.rawValue] = false
        return h
    }
    /// Groups `handles` so their button states are mutually exclusive on simulate.
    public func groupRadioButtons(_ handles: [NativeHandle]) {
        let members = handles.map(\.rawValue)
        for raw in members { radioGroups[raw] = members }
    }
    /// Allocates a slider handle over `[minValue, maxValue]`.
    public func createSlider(value: Double, minValue: Double, maxValue: Double, frame: NSRect) -> NativeHandle {
        let h = allocate(.slider)
        frames[h.rawValue] = frame
        ranges[h.rawValue] = (minValue, maxValue)
        doubleValues[h.rawValue] = value
        enabledStates[h.rawValue] = true
        return h
    }
    /// Allocates a progress-indicator handle over `[minValue, maxValue]`.
    public func createProgressIndicator(value: Double, minValue: Double, maxValue: Double, frame: NSRect) -> NativeHandle {
        let h = allocate(.progress)
        frames[h.rawValue] = frame
        ranges[h.rawValue] = (minValue, maxValue)
        doubleValues[h.rawValue] = value
        return h
    }
    /// Progress-bar state, for tests.
    public private(set) var indeterminateProgress: Set<UInt> = []
    /// Progress indicators currently animating, for tests.
    public private(set) var animatingProgress: Set<UInt> = []
    /// Records whether a progress indicator is indeterminate.
    public func setProgressIndeterminate(_ indeterminate: Bool, for handle: NativeHandle) {
        if indeterminate { indeterminateProgress.insert(handle.rawValue) }
        else { indeterminateProgress.remove(handle.rawValue); animatingProgress.remove(handle.rawValue) }
    }
    /// Progress spinners (as opposed to bars), for tests.
    public private(set) var spinningProgress: Set<UInt> = []
    /// Records whether a progress indicator is rendered as a spinner.
    public func setProgressSpinning(_ spinning: Bool, for handle: NativeHandle) {
        if spinning { spinningProgress.insert(handle.rawValue) } else { spinningProgress.remove(handle.rawValue) }
    }
    private var mouseHandlers: [UInt: (NativeMouseEvent) -> Void] = [:]
    /// Records the pointer-event handler for a view.
    public func setMouseHandler(for handle: NativeHandle, _ handler: @escaping (NativeMouseEvent) -> Void) {
        mouseHandlers[handle.rawValue] = handler
    }
    /// Test hook: deliver a pointer event to a view.
    public func simulateMouse(_ event: NativeMouseEvent, for handle: NativeHandle) {
        mouseHandlers[handle.rawValue]?(event)
    }
    /// Records whether an indeterminate indicator is animating.
    public func setProgressAnimating(_ animating: Bool, for handle: NativeHandle) {
        if animating && indeterminateProgress.contains(handle.rawValue) { animatingProgress.insert(handle.rawValue) }
        else { animatingProgress.remove(handle.rawValue) }
    }
    /// Allocates a pop-up button handle with the given items and selection.
    public func createPopUpButton(items: [String], selectedIndex: Int, frame: NSRect) -> NativeHandle {
        let h = allocate(.popUp)
        frames[h.rawValue] = frame
        itemsByHandle[h.rawValue] = items
        selectedIndices[h.rawValue] = selectedIndex
        enabledStates[h.rawValue] = true
        return h
    }
    /// Allocates a stepper handle over `[minValue, maxValue]`.
    public func createStepper(value: Double, minValue: Double, maxValue: Double, stepSize: Double, frame: NSRect) -> NativeHandle {
        let h = allocate(.stepper)
        frames[h.rawValue] = frame
        ranges[h.rawValue] = (minValue, maxValue)
        doubleValues[h.rawValue] = value
        enabledStates[h.rawValue] = true
        return h
    }
    /// Allocates a level-indicator handle over `[minValue, maxValue]`.
    public func createLevelIndicator(value: Double, minValue: Double, maxValue: Double, frame: NSRect) -> NativeHandle {
        let h = allocate(.level)
        frames[h.rawValue] = frame
        ranges[h.rawValue] = (minValue, maxValue)
        doubleValues[h.rawValue] = value
        return h
    }
    /// Allocates a multi-line text-view handle.
    public func createTextView(text: String, frame: NSRect) -> NativeHandle {
        let h = allocate(.textView)
        texts[h.rawValue] = text
        frames[h.rawValue] = frame
        enabledStates[h.rawValue] = true
        return h
    }
    /// Allocates a date-picker handle initialised to `date`.
    public func createDatePicker(date: Date, frame: NSRect) -> NativeHandle {
        let h = allocate(.datePicker)
        frames[h.rawValue] = frame
        dates[h.rawValue] = date
        enabledStates[h.rawValue] = true
        return h
    }
    /// Allocates a color-well handle initialised to `color`.
    public func createColorWell(color: NSColor, frame: NSRect) -> NativeHandle {
        let h = allocate(.colorWell)
        frames[h.rawValue] = frame
        colors[h.rawValue] = color
        enabledStates[h.rawValue] = true
        return h
    }
    /// Allocates a tab-view handle with the first page selected.
    public func createTabView(frame: NSRect) -> NativeHandle {
        let h = allocate(.tabView)
        frames[h.rawValue] = frame
        selectedIndices[h.rawValue] = 0
        return h
    }
    /// Records `page` as a new tab titled `label`.
    public func addTabPage(_ page: NativeHandle, label: String, to tabView: NativeHandle) {
        tabPages[tabView.rawValue, default: []].append((page: page.rawValue, label: label))
    }
    /// Allocates a segmented-control handle (initial selection -1).
    public func createSegmentedControl(labels: [String], frame: NSRect) -> NativeHandle {
        let h = allocate(.segmented)
        frames[h.rawValue] = frame
        itemsByHandle[h.rawValue] = labels
        selectedIndices[h.rawValue] = -1
        enabledStates[h.rawValue] = true
        return h
    }
    /// Allocates an image-view handle.
    public func createImageView(frame: NSRect) -> NativeHandle {
        let h = allocate(.imageView); frames[h.rawValue] = frame; return h
    }
    /// Allocates a table-view handle (initial selection -1).
    public func createTableView(frame: NSRect) -> NativeHandle {
        let h = allocate(.table)
        frames[h.rawValue] = frame
        selectedIndices[h.rawValue] = -1
        return h
    }
    /// Appends a titled column to a table.
    public func addTableColumn(title: String, to table: NativeHandle) {
        tableColumns[table.rawValue, default: []].append(title)
    }
    /// Renames the column at `columnIndex`.
    public func setTableColumnTitle(_ title: String, columnIndex: Int, for table: NativeHandle) {
        guard var cols = tableColumns[table.rawValue], columnIndex < cols.count else { return }
        cols[columnIndex] = title
        tableColumns[table.rawValue] = cols
    }
    /// Marks `columnIndex` sortable.
    public func setColumnSortable(_ columnIndex: Int, for table: NativeHandle) {
        sortableColumns[table.rawValue, default: []].insert(columnIndex)
    }
    /// Rows scrolled into view, newest last (test hook).
    public private(set) var scrolledTableRows: [(table: UInt, row: Int)] = []
    /// Records a scroll-to-row request.
    public func scrollTableRowToVisible(_ row: Int, for table: NativeHandle) {
        scrolledTableRows.append((table: table.rawValue, row: row))
    }
    /// Records the sort-change action for a table.
    public func setSortChangeAction(for table: NativeHandle, action: @escaping (Int, Bool) -> Void) {
        sortActions[table.rawValue] = action
    }
    /// Records the row-activate (double-click / Enter) action for a table.
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
    /// Records the table's row count.
    public func setTableRowCount(_ count: Int, for table: NativeHandle) {
        tableRowCounts[table.rawValue] = count
    }
    /// Records the cell-text provider used by `tableCellText`.
    public func setTableCellProvider(for table: NativeHandle, provider: @escaping (Int, Int) -> String) {
        tableCellProviders[table.rawValue] = provider
    }
    /// The text a table would render at (row, columnIndex) — test hook.
    public func tableCellText(_ table: NativeHandle, row: Int, column: Int) -> String {
        tableCellProviders[table.rawValue]?(row, column) ?? ""
    }
    /// Allocates an outline-view handle (initial selection -1).
    public func createOutlineView(frame: NSRect) -> NativeHandle {
        let h = allocate(.outline)
        frames[h.rawValue] = frame
        selectedIndices[h.rawValue] = -1
        return h
    }
    /// Appends a titled column to an outline view.
    public func addOutlineColumn(title: String, to outline: NativeHandle) {
        outlineColumns[outline.rawValue, default: []].append(title)
    }
    /// Records the number of root items in an outline view.
    public func setOutlineRootCount(_ count: Int, for outline: NativeHandle) {
        outlineRootCounts[outline.rawValue] = count
    }
    /// Records the tree/text providers used by `outlineChildCount` and `outlineCellText`.
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
    /// Allocates a collection-view handle (initial selection -1).
    public func createCollectionView(frame: NSRect) -> NativeHandle {
        let h = allocate(.collection)
        frames[h.rawValue] = frame
        selectedIndices[h.rawValue] = -1
        return h
    }
    /// Records the collection's item count.
    public func setCollectionItemCount(_ count: Int, for collection: NativeHandle) {
        collectionItemCounts[collection.rawValue] = count
    }
    /// Recorded item-view providers, for tests.
    public private(set) var collectionItemViewProviders: [UInt: (Int) -> NativeHandle?] = [:]
    /// Records the item-view provider for a collection.
    public func setCollectionItemViewProvider(for collection: NativeHandle, provider: @escaping (Int) -> NativeHandle?) {
        collectionItemViewProviders[collection.rawValue] = provider
    }

    private var clickActions: [UInt: (Double, Double) -> Void] = [:]
    /// Records a click action fired by `simulateClick(at:_:for:)`.
    public func setClickAction(for handle: NativeHandle, action: @escaping (Double, Double) -> Void) {
        clickActions[handle.rawValue] = action
    }
    /// Test hook: click a view at a position in its own coordinates.
    public func simulateClick(at x: Double, _ y: Double, for handle: NativeHandle) {
        clickActions[handle.rawValue]?(x, y)
    }

    /// Records the text provider used by `collectionItemText`.
    public func setCollectionItemProvider(for collection: NativeHandle, provider: @escaping (Int) -> String) {
        collectionItemProviders[collection.rawValue] = provider
    }
    /// The text a collection tile would render at `index` — test hook.
    public func collectionItemText(_ collection: NativeHandle, index: Int) -> String {
        collectionItemProviders[collection.rawValue]?(index) ?? ""
    }
    /// Allocates a token-field handle populated with `tokens`.
    public func createTokenField(tokens: [String], frame: NSRect) -> NativeHandle {
        let h = allocate(.tokenField)
        frames[h.rawValue] = frame
        tokensByHandle[h.rawValue] = tokens
        enabledStates[h.rawValue] = true
        return h
    }
    /// Replaces the tokens shown by a token field.
    public func setTokens(_ tokens: [String], for handle: NativeHandle) {
        tokensByHandle[handle.rawValue] = tokens
    }
    /// Records the tokens-change action for a token field.
    public func setTokensChangeAction(for handle: NativeHandle, action: @escaping ([String]) -> Void) {
        tokensChangeActions[handle.rawValue] = action
    }
    /// Simulates the user adding/removing tokens (e.g. typing one and hitting Enter).
    public func simulateTokensChange(_ handle: NativeHandle, _ tokens: [String]) {
        tokensByHandle[handle.rawValue] = tokens
        tokensChangeActions[handle.rawValue]?(tokens)
    }
    /// Records (or clears) the image path shown by an image view.
    public func setImagePath(_ path: String?, for handle: NativeHandle) {
        if let path { imagePaths[handle.rawValue] = path } else { imagePaths[handle.rawValue] = nil }
    }
    /// Allocates a titled group-box handle.
    public func createBox(title: String, frame: NSRect) -> NativeHandle {
        let h = allocate(.box)
        titles[h.rawValue] = title
        texts[h.rawValue] = title
        frames[h.rawValue] = frame
        return h
    }
    /// Allocates a scroll-view handle.
    public func createScrollView(frame: NSRect) -> NativeHandle {
        let h = allocate(.scrollView); frames[h.rawValue] = frame; return h
    }

    /// Whether each scroller is allowed to appear, per scroll view.
    public private(set) var scrollerPolicies: [UInt: (vertical: Bool, horizontal: Bool)] = [:]
    private var scrollOffsets: [UInt: NSPoint] = [:]
    private var scrollActions: [UInt: (Double, Double) -> Void] = [:]

    /// Records per-axis scroller visibility policy for a scroll view.
    public func setScrollerPolicy(vertical: Bool, horizontal: Bool, for handle: NativeHandle) {
        scrollerPolicies[handle.rawValue] = (vertical, horizontal)
    }
    /// Returns the document view's frame size as the scrollable content size.
    public func scrollDocumentSize(for handle: NativeHandle) -> (width: Double, height: Double) {
        // The document view's frame is the scrollable content size.
        let docFrame = contentViews[handle.rawValue].flatMap { frames[$0] } ?? frames[handle.rawValue] ?? .zero
        return (Double(docFrame.width), Double(docFrame.height))
    }
    /// Returns the scroll view's own frame size as the viewport size.
    public func scrollVisibleSize(for handle: NativeHandle) -> (width: Double, height: Double) {
        let frame = frames[handle.rawValue] ?? .zero
        return (Double(frame.width), Double(frame.height))
    }
    /// Sets the clamped scroll offset and fires the scroll-change action.
    public func setScrollOffset(x: Double, y: Double, for handle: NativeHandle) {
        // Clamp to the scrollable range, as GTK's adjustments do.
        let doc = scrollDocumentSize(for: handle), vis = scrollVisibleSize(for: handle)
        let cx = min(max(0, x), max(0, doc.width - vis.width))
        let cy = min(max(0, y), max(0, doc.height - vis.height))
        scrollOffsets[handle.rawValue] = NSMakePoint(CGFloat(cx), CGFloat(cy))
        scrollActions[handle.rawValue]?(cx, cy)
    }
    /// Returns the current scroll offset.
    public func scrollOffset(for handle: NativeHandle) -> (x: Double, y: Double) {
        let p = scrollOffsets[handle.rawValue] ?? .zero
        return (Double(p.x), Double(p.y))
    }
    /// Records the scroll-change action for a scroll view.
    public func setScrollChangeAction(for handle: NativeHandle, action: @escaping (Double, Double) -> Void) {
        scrollActions[handle.rawValue] = action
    }

    /// Test hook: simulates the user scrolling to `(x, y)` (clamped), firing the
    /// scroll-change action.
    public func simulateScroll(to point: NSPoint, on handle: NativeHandle) {
        setScrollOffset(x: Double(point.x), y: Double(point.y), for: handle)
    }
    /// Allocates a split-view handle.
    public func createSplitView(vertical: Bool, frame: NSRect) -> NativeHandle {
        let h = allocate(.splitView); frames[h.rawValue] = frame; return h
    }
    /// Records `pane` as the next pane in a split view.
    public func addSplitPane(_ pane: NativeHandle, to splitView: NativeHandle) {
        splitPanes[splitView.rawValue, default: []].append(pane.rawValue)
    }
    /// Records the divider position of a split view.
    public func setDividerPosition(_ position: Double, for splitView: NativeHandle) {
        dividerPositions[splitView.rawValue] = position
    }
    /// Records `child` as a subview of `parent`.
    public func addSubview(_ child: NativeHandle, to parent: NativeHandle) {
        subviews[parent.rawValue, default: []].append(child.rawValue)
    }
    /// Views whose children are clipped to bounds.
    public private(set) var clippedViews: Set<UInt> = []
    /// Records whether a view clips its children to its bounds.
    public func setClipsToBounds(_ clips: Bool, for handle: NativeHandle) {
        if clips { clippedViews.insert(handle.rawValue) } else { clippedViews.remove(handle.rawValue) }
    }
    /// Records whether a view uses top-left (flipped) coordinates.
    public func setViewFlipped(_ flipped: Bool, for handle: NativeHandle) {
        flippedViews[handle.rawValue] = flipped
    }
    /// Records whether a slider is vertically oriented.
    public func setSliderVertical(_ vertical: Bool, for handle: NativeHandle) {
        sliderVerticals[handle.rawValue] = vertical
    }
    /// Recorded date ranges, for tests.
    public private(set) var dateRanges: [UInt: (min: Date?, max: Date?)] = [:]
    /// Records the date range and clamps the current date into it.
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
    /// Records the formatted text shown by a compact date picker.
    public func setDatePickerText(_ text: String, for handle: NativeHandle) {
        datePickerTexts[handle.rawValue] = text
    }

    /// The highlighted element's range, for tests.
    public private(set) var datePickerSelections: [UInt: (location: Int, length: Int)] = [:]
    /// Records the selected character range in a compact date picker.
    public func setDatePickerSelection(location: Int, length: Int, for handle: NativeHandle) {
        datePickerSelections[handle.rawValue] = (location, length)
    }

    private var dateStepActions: [UInt: (Int) -> Void] = [:]
    /// Records the stepper-direction action for a date picker.
    public func setDateStepAction(for handle: NativeHandle, action: @escaping (Int) -> Void) {
        dateStepActions[handle.rawValue] = action
    }
    /// Test hook: press the picker's stepper.
    public func simulateDateStep(_ direction: Int, for handle: NativeHandle) {
        dateStepActions[handle.rawValue]?(direction)
    }

    private var datePickerCursorActions: [UInt: (Int) -> Void] = [:]
    /// Records the click-position action for a compact date picker.
    public func setDatePickerCursorAction(for handle: NativeHandle, action: @escaping (Int) -> Void) {
        datePickerCursorActions[handle.rawValue] = action
    }
    /// Test hook: click the compact field at a character offset.
    public func simulateDatePickerClick(atCharacter offset: Int, for handle: NativeHandle) {
        datePickerCursorActions[handle.rawValue]?(offset)
    }

    private var datePickerTypeActions: [UInt: (String) -> Void] = [:]
    /// Records the character-typed action for a compact date picker.
    public func setDatePickerTypeAction(for handle: NativeHandle, action: @escaping (String) -> Void) {
        datePickerTypeActions[handle.rawValue] = action
    }
    /// Test hook: type into the compact field's selected element.
    public func simulateDatePickerTyping(_ text: String, for handle: NativeHandle) {
        for character in text { datePickerTypeActions[handle.rawValue]?(String(character)) }
    }

    private var datePickerMoveActions: [UInt: (Int) -> Void] = [:]
    /// Records the left/right-arrow action for a compact date picker.
    public func setDatePickerMoveAction(for handle: NativeHandle, action: @escaping (Int) -> Void) {
        datePickerMoveActions[handle.rawValue] = action
    }
    /// Test hook: press left/right in the compact field.
    public func simulateDatePickerMove(_ delta: Int, for handle: NativeHandle) {
        datePickerMoveActions[handle.rawValue]?(delta)
    }

    /// Level indicator state, for tests.
    public private(set) var levelStyles: [UInt: Int] = [:]
    /// Editable-flag state for each level indicator.
    public private(set) var levelEditable: [UInt: Bool] = [:]
    /// Warning / critical thresholds recorded for each level indicator.
    public private(set) var levelThresholds: [UInt: (warning: Double, critical: Double)] = [:]
    /// Records the level-indicator style (raw value).
    public func setLevelIndicatorStyle(_ rawValue: Int, for handle: NativeHandle) {
        levelStyles[handle.rawValue] = rawValue
    }
    /// Records whether a level indicator is editable.
    public func setLevelIndicatorEditable(_ editable: Bool, for handle: NativeHandle) {
        levelEditable[handle.rawValue] = editable
    }
    /// Records the min/max range of a level indicator.
    public func setLevelIndicatorRange(min: Double, max: Double, for handle: NativeHandle) {
        ranges[handle.rawValue] = (min, max)
    }
    /// Records the warning / critical thresholds of a level indicator.
    public func setLevelThresholds(warning: Double, critical: Double, for handle: NativeHandle) {
        levelThresholds[handle.rawValue] = (warning, critical)
    }
    private var levelChangeActions: [UInt: (Double) -> Void] = [:]
    /// Records the level-change action for a level indicator.
    public func setLevelChangeAction(for handle: NativeHandle, action: @escaping (Double) -> Void) {
        levelChangeActions[handle.rawValue] = action
    }
    /// Test hook: click an editable indicator to set `value`.
    public func simulateLevelClick(to value: Double, for handle: NativeHandle) {
        levelChangeActions[handle.rawValue]?(value)
    }

    /// Standalone scrollers, for tests.
    public private(set) var scrollerGeometry: [UInt: (value: Double, knobProportion: Double)] = [:]
    /// Allocates a standalone scroller (initial state: disabled, full knob).
    public func createScroller(vertical: Bool, frame: NSRect) -> NativeHandle {
        let h = allocate(.scroller)
        frames[h.rawValue] = frame
        enabledStates[h.rawValue] = false    // AppKit's NSScroller starts disabled
        scrollerGeometry[h.rawValue] = (0, 1)
        return h
    }
    /// Records the scroller's value and knob proportion.
    public func setScrollerGeometry(value: Double, knobProportion: Double, for handle: NativeHandle) {
        scrollerGeometry[handle.rawValue] = (value, knobProportion)
    }
    private var scrollerActions: [UInt: (Double) -> Void] = [:]
    /// Records the drag action for a standalone scroller.
    public func setScrollerAction(for handle: NativeHandle, action: @escaping (Double) -> Void) {
        scrollerActions[handle.rawValue] = action
    }
    /// Test hook: drag a standalone scroller to `value`.
    public func simulateScrollerDrag(to value: Double, for handle: NativeHandle) {
        scrollerActions[handle.rawValue]?(value)
    }

    /// Records whether a date picker uses the graphical (calendar) style.
    public func setDatePickerGraphical(_ graphical: Bool, for handle: NativeHandle) {
        datePickerGraphical[handle.rawValue] = graphical
    }
    /// Records whether a text field is editable.
    public func setTextEditable(_ editable: Bool, for handle: NativeHandle) {
        textEditable[handle.rawValue] = editable
    }
    /// Records the view's background color (nil clears it).
    public func setBackgroundColor(_ color: NSColor?, for handle: NativeHandle) {
        backgroundColors[handle.rawValue] = color
    }
    /// Rewrites a button's kind and title.
    public func setButtonKind(_ kind: NativeButtonKind, title: String, for handle: NativeHandle) {
        switch kind {
        case .push:     kinds[handle.rawValue] = .button
        case .checkbox: kinds[handle.rawValue] = .checkbox
        case .radio:    kinds[handle.rawValue] = .radio
        }
        texts[handle.rawValue] = title
    }

    // MARK: Mutators
    /// Records the text of a control.
    public func setText(_ text: String, for handle: NativeHandle) { texts[handle.rawValue] = text }
    /// Records the frame of a control.
    public func setFrame(_ frame: NSRect, for handle: NativeHandle) { frames[handle.rawValue] = frame }
    /// Records the enabled state of a control.
    public func setEnabled(_ isEnabled: Bool, for handle: NativeHandle) { enabledStates[handle.rawValue] = isEnabled }
    /// Hidden state per control.
    public private(set) var hiddenStates: [UInt: Bool] = [:]
    /// Records the hidden state of a control.
    public func setHidden(_ isHidden: Bool, for handle: NativeHandle) { hiddenStates[handle.rawValue] = isHidden }
    /// Records the font applied to a control.
    public func setFont(_ font: NativeFontSpec, for handle: NativeHandle) { fonts[handle.rawValue] = font }
    /// Records the text color applied to a control.
    public func setTextColor(_ color: NSColor, for handle: NativeHandle) { textColors[handle.rawValue] = color }
    /// Records the material applied to a visual-effect view.
    public func setMaterial(_ material: String, for handle: NativeHandle) { materials[handle.rawValue] = material }
    /// Records styled runs and reconstructs a plain-text join.
    public func setStyledText(_ runs: [NativeTextRun], for handle: NativeHandle) {
        styledTexts[handle.rawValue] = runs
        texts[handle.rawValue] = runs.map(\.text).joined()
    }
    /// Records the draw handler for a view.
    public func setDrawHandler(for handle: NativeHandle, handler: @escaping (NativeGraphicsContext, Double, Double) -> Void) {
        drawHandlers[handle.rawValue] = handler
    }
    /// Counts the display request and re-runs the draw handler synchronously.
    public func setNeedsDisplay(_ handle: NativeHandle) {
        displayRequests[handle.rawValue, default: 0] += 1
        // Draw synchronously so tests can assert the recorded ops immediately.
        guard let handler = drawHandlers[handle.rawValue] else { return }
        let frame = frames[handle.rawValue] ?? .zero
        let context = RecordingGraphicsContext()
        handler(context, Double(frame.width), Double(frame.height))
        lastDrawOps[handle.rawValue] = context.ops
    }
    /// Forgets all recorded state for `handle`.
    public func destroyControl(_ handle: NativeHandle) {
        let r = handle.rawValue
        kinds[r] = nil; titles[r] = nil; texts[r] = nil; frames[r] = nil
        enabledStates[r] = nil; actions[r] = nil
    }

    // MARK: Events
    /// Records the primary action for a control.
    public func registerAction(for handle: NativeHandle, action: @escaping () -> Void) {
        actions[handle.rawValue] = action
    }
    private var submitActions: [UInt: () -> Void] = [:]
    /// Records the submit action for a text field.
    public func setSubmitAction(for handle: NativeHandle, action: @escaping () -> Void) {
        submitActions[handle.rawValue] = action
    }
    /// Test hook: submit (Enter) a field.
    public func simulateSubmit(for handle: NativeHandle) { submitActions[handle.rawValue]?() }

    /// Records the text-change action for a text field.
    public func setTextChangeAction(for handle: NativeHandle, action: @escaping (String) -> Void) {
        textChangeActions[handle.rawValue] = action
    }
    /// Records a checkbox/radio's on/off state.
    public func setButtonState(_ on: Bool, for handle: NativeHandle) {
        buttonStates[handle.rawValue] = on
    }
    /// Records a slider/progress/level value.
    public func setDoubleValue(_ value: Double, for handle: NativeHandle) {
        doubleValues[handle.rawValue] = value
    }
    /// Records the selected index of a pop-up/tab/table.
    public func setSelectedIndex(_ index: Int, for handle: NativeHandle) {
        selectedIndices[handle.rawValue] = index
    }
    /// Records a pop-up's items and selection.
    public func setPopUpItems(_ titles: [String], selectedIndex: Int, for handle: NativeHandle) {
        popUpItems[handle.rawValue] = titles
        selectedIndices[handle.rawValue] = selectedIndex
    }
    /// Records the toggle action for a checkbox/radio.
    public func setToggleAction(for handle: NativeHandle, action: @escaping (Bool) -> Void) {
        toggleActions[handle.rawValue] = action
    }
    /// Records the value-change action for a slider or stepper.
    public func setValueChangeAction(for handle: NativeHandle, action: @escaping (Double) -> Void) {
        valueChangeActions[handle.rawValue] = action
    }
    /// Records the selection-change action for a pop-up/table.
    public func setSelectionChangeAction(for handle: NativeHandle, action: @escaping (Int) -> Void) {
        selectionActions[handle.rawValue] = action
    }
    /// Records a date-picker's date.
    public func setDateValue(_ date: Date, for handle: NativeHandle) {
        dates[handle.rawValue] = date
    }
    /// Records a color-well's color.
    public func setColor(_ color: NSColor, for handle: NativeHandle) {
        colors[handle.rawValue] = color
    }
    /// Records the date-change action for a date picker.
    public func setDateChangeAction(for handle: NativeHandle, action: @escaping (Date) -> Void) {
        dateChangeActions[handle.rawValue] = action
    }
    /// Records the color-change action for a color well.
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
