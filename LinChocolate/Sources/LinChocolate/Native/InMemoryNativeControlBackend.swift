import Foundation

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
    public private(set) var imagePaths: [UInt: String] = [:]
    /// Alerts shown so far (message, informative, buttons), newest last.
    public private(set) var alerts: [(message: String, informative: String, buttons: [String])] = []
    /// The button index `runAlert` returns, standing in for the user's press.
    public var nextAlertResponse = 0
    private var dateChangeActions: [UInt: (Date) -> Void] = [:]
    private var colorChangeActions: [UInt: (NSColor) -> Void] = [:]

    public init() {}

    private func allocate(_ kind: Kind) -> NativeHandle {
        defer { nextRaw += 1 }
        kinds[nextRaw] = kind
        return NativeHandle(rawValue: nextRaw)
    }

    // MARK: Application lifecycle
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
    }
    public func setWindowTitle(_ title: String, for handle: NativeHandle) {
        titles[handle.rawValue] = title
    }
    public func registerWindowCloseAction(for handle: NativeHandle, action: @escaping () -> Void) {
        windowCloseActions[handle.rawValue] = action
    }
    public func installMenuBar(_ menus: [NativeMenuSpec], on window: NativeHandle) {
        menuBars[window.rawValue] = menus
    }
    public func runAlert(message: String, informative: String, buttons: [String], for window: NativeHandle?) -> Int {
        alerts.append((message: message, informative: informative, buttons: buttons))
        return nextAlertResponse
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

    // MARK: Mutators
    public func setText(_ text: String, for handle: NativeHandle) { texts[handle.rawValue] = text }
    public func setFrame(_ frame: NSRect, for handle: NativeHandle) { frames[handle.rawValue] = frame }
    public func setEnabled(_ isEnabled: Bool, for handle: NativeHandle) { enabledStates[handle.rawValue] = isEnabled }
    public func destroyControl(_ handle: NativeHandle) {
        let r = handle.rawValue
        kinds[r] = nil; titles[r] = nil; texts[r] = nil; frames[r] = nil
        enabledStates[r] = nil; actions[r] = nil
    }

    // MARK: Events
    public func registerAction(for handle: NativeHandle, action: @escaping () -> Void) {
        actions[handle.rawValue] = action
    }
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
