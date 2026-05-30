import WinChocolate

let app = NSApplication.shared

let menuBar = NSMenu()
let appMenuItem = NSMenuItem(title: "WinChocolate", action: nil, keyEquivalent: "")
let appMenu = NSMenu(title: "WinChocolate")
let quitItem = NSMenuItem(title: "Quit WinChocolate", action: "terminate:", keyEquivalent: "q")
quitItem.target = app
appMenu.addItem(quitItem)
appMenuItem.submenu = appMenu
menuBar.addItem(appMenuItem)
app.mainMenu = menuBar

let window = NSWindow(
    contentRect: NSMakeRect(100, 100, 1120, 700),
    styleMask: [.titled, .closable, .miniaturizable, .resizable],
    backing: .buffered,
    defer: false
)
window.title = "WinChocolate Click Counter"

final class DemoContentView: NSView {
    var onBlankAreaMouseDown: ((NSEvent) -> Void)?
    var onBlankAreaMouseUp: ((NSEvent) -> Void)?
    var onMouseMoved: ((NSEvent) -> Void)?
    var onKeyDown: ((NSEvent) -> Void)?
    var onKeyUp: ((NSEvent) -> Void)?

    override func mouseDown(with event: NSEvent) {
        onBlankAreaMouseDown?(event)
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        onBlankAreaMouseUp?(event)
        super.mouseUp(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        onMouseMoved?(event)
        super.mouseMoved(with: event)
    }

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event)
        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        onKeyUp?(event)
        super.keyUp(with: event)
    }
}

final class DemoTableDataSource: NSTableViewDataSource {
    var rows: [[String]] = [
        ["NSApplication", "Running"],
        ["NSWindow", "Key/Main"],
        ["NSButton", "Actions"],
        ["NSTextField", "Editing"],
        ["NSSecureTextField", "Password"],
        ["NSSearchField", "Immediate search"],
        ["NSComboBox", "Editable list"],
        ["NSLevelIndicator", "Value meter"],
        ["NSColorWell", "Color swatch"],
        ["NSTabView", "Native tabs"],
        ["NSImageView", "Bitmap artwork"],
        ["NSTableView", "First slice"],
        ["NSTableColumn", "Identifiers"],
        ["NSTableCellView", "View based"],
        ["NSTableRowView", "Selection state"],
        ["NSScrollView", "Document view"],
        ["NSResponder", "Key loop"],
        ["NSEvent", "Keyboard/mouse"],
        ["NSMenu", "Quit command"],
        ["NSAlert", "Modal"],
        ["NSColor", "Native paint"],
        ["NSFont", "Native font"]
    ]

    func numberOfRows(in tableView: NSTableView) -> Int {
        rows.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard rows.indices.contains(row) else {
            return nil
        }

        switch tableColumn?.identifier.rawValue {
        case "name":
            return rows[row][0]
        case "status":
            return rows[row][1]
        default:
            return nil
        }
    }

    func sort(using descriptor: NSSortDescriptor) {
        guard let key = descriptor.key else {
            return
        }

        let columnIndex: Int
        switch key {
        case "name":
            columnIndex = 0
        case "status":
            columnIndex = 1
        default:
            return
        }

        rows.sort { left, right in
            let leftValue = left.indices.contains(columnIndex) ? left[columnIndex] : ""
            let rightValue = right.indices.contains(columnIndex) ? right[columnIndex] : ""
            if descriptor.ascending {
                return leftValue < rightValue
            }

            return leftValue > rightValue
        }
    }
}

let contentView = DemoContentView(frame: NSMakeRect(0, 0, 1120, 700))
let counterLabel = NSTextField(string: "Clicks: 0", frame: NSMakeRect(32, 36, 300, 24))
let statusLabel = NSTextField(string: "Ready", frame: NSMakeRect(32, 74, 640, 24))
let focusLabel = NSTextField(string: "Focus: none", frame: NSMakeRect(744, 74, 300, 24))
let button = NSButton(title: "Click", frame: NSMakeRect(32, 124, 100, 34))
let enableButton = NSButton(title: "Disable Click", frame: NSMakeRect(152, 124, 144, 34))
let hideButton = NSButton(title: "Hide Counter", frame: NSMakeRect(316, 124, 144, 34))
let moveButton = NSButton(title: "Move Click", frame: NSMakeRect(480, 124, 128, 34))
let editableLabel = NSTextField(string: "Type here:", frame: NSMakeRect(32, 188, 104, 24))
let editableTextField = NSTextField(string: "", frame: NSMakeRect(152, 186, 360, 28))
let secureLabel = NSTextField(string: "Password:", frame: NSMakeRect(32, 222, 104, 24))
let secureTextField = NSSecureTextField(string: "", frame: NSMakeRect(152, 220, 240, 28))
let alertButton = NSButton(title: "Alert", frame: NSMakeRect(32, 252, 100, 34))
let titleCheckbox = NSButton(title: "Show count in title", frame: NSMakeRect(152, 252, 228, 34))
let alertStyleBox = NSBox(title: "Alert Style", frame: NSMakeRect(448, 220, 248, 116))
let alertStyleLabel = NSTextField(string: "Alert style:", frame: NSMakeRect(472, 256, 112, 24))
let alertStylePopup = NSPopUpButton(frame: NSMakeRect(472, 286, 184, 96), pullsDown: false)
let infoRadio = NSButton(title: "Info", frame: NSMakeRect(32, 334, 88, 24))
let warningRadio = NSButton(title: "Warning", frame: NSMakeRect(136, 334, 116, 24))
let criticalRadio = NSButton(title: "Critical", frame: NSMakeRect(268, 334, 116, 24))
let notesLabel = NSTextField(string: "Notes:", frame: NSMakeRect(32, 386, 104, 24))
let notesTextView = NSTextView(frame: NSMakeRect(152, 386, 360, 96))
let sliderLabel = NSTextField(string: "Slider:", frame: NSMakeRect(744, 166, 72, 24))
let slider = NSSlider(value: 50, minValue: 0, maxValue: 100, target: nil, action: "sliderChanged:")
let sliderValueLabel = NSTextField(string: "50", frame: NSMakeRect(1024, 166, 48, 24))
let progressLabel = NSTextField(string: "Progress:", frame: NSMakeRect(744, 198, 88, 24))
let progressIndicator = NSProgressIndicator(frame: NSMakeRect(840, 202, 232, 18))
let stepperLabel = NSTextField(string: "Stepper:", frame: NSMakeRect(744, 232, 88, 24))
let stepper = NSStepper(frame: NSMakeRect(840, 232, 20, 28))
let stepperValueLabel = NSTextField(string: "50", frame: NSMakeRect(888, 232, 64, 24))
let comboLabel = NSTextField(string: "Combo:", frame: NSMakeRect(744, 292, 88, 24))
let comboBox = NSComboBox(frame: NSMakeRect(840, 290, 184, 28))
let searchLabel = NSTextField(string: "Search:", frame: NSMakeRect(744, 328, 88, 24))
let searchField = NSSearchField(frame: NSMakeRect(840, 326, 232, 28))
let levelLabel = NSTextField(string: "Level:", frame: NSMakeRect(744, 364, 88, 24))
let levelIndicator = NSLevelIndicator(frame: NSMakeRect(840, 368, 144, 18))
let colorWellLabel = NSTextField(string: "Color:", frame: NSMakeRect(992, 364, 56, 24))
let colorWell = NSColorWell(frame: NSMakeRect(1052, 362, 32, 28))
let tabLabel = NSTextField(string: "Tabs:", frame: NSMakeRect(32, 520, 88, 24))
let tabView = NSTabView(frame: NSMakeRect(152, 520, 280, 88))
let imageLabel = NSTextField(string: "Image view:", frame: NSMakeRect(448, 520, 104, 24))
let imageView = NSImageView(frame: NSMakeRect(560, 500, 160, 100))
let splitLabel = NSTextField(string: "Split view:", frame: NSMakeRect(448, 608, 104, 24))
let splitView = NSSplitView(frame: NSMakeRect(560, 604, 160, 64))
let splitLeftPane = NSView(frame: NSZeroRect)
let splitRightPane = NSView(frame: NSZeroRect)
let tableLabel = NSTextField(string: "Table view:", frame: NSMakeRect(744, 392, 120, 24))
let tableScrollView = NSScrollView(frame: NSMakeRect(744, 424, 330, 210))
let tableView = NSTableView(frame: NSMakeRect(0, 0, 330, 210))
let tableDataSource = DemoTableDataSource()
let contentFocusColor = NSColor(calibratedRed: 0.92, green: 0.97, blue: 1.0, alpha: 1.0)
let normalContentColor = NSColor.windowBackgroundColor
let controlFocusColor = NSColor(calibratedRed: 1.0, green: 0.96, blue: 0.72, alpha: 1.0)
let normalTextFieldColor = NSColor.white
var clickCount = 0
var isClickEnabled = true
var isCounterHidden = false
var movedRight = false
var suppressNextTableSelectionStatus = false
var colorIndex = 0
let demoColors: [NSColor] = [.red, .green, .blue, .white]
let demoArtworkPath = "Demo\\DemoApplication\\Resources\\WinChocolateArtwork.bmp"
let demoScreenArtworkPath = "Demo\\DemoApplication\\Resources\\WinChocolateScreenArtwork.bmp"
var imageModeIndex = 0
let imageModes: [(NSImageView.ImageScaling, NSImageView.ImageAlignment, String, String)] = [
    (.scaleProportionallyDown, .alignCenter, demoArtworkPath, "bird center/down"),
    (.scaleProportionallyUpOrDown, .alignTopLeft, demoScreenArtworkPath, "screen top-left/fit"),
    (.scaleAxesIndependently, .alignBottomRight, demoArtworkPath, "bird bottom-right/axes"),
    (.scaleNone, .alignRight, demoScreenArtworkPath, "screen right/none")
]

func modifierText(for event: NSEvent) -> String {
    var names: [String] = []
    if event.modifierFlags.contains(.shift) {
        names.append("shift")
    }
    if event.modifierFlags.contains(.control) {
        names.append("control")
    }
    if event.modifierFlags.contains(.option) {
        names.append("option")
    }
    if event.modifierFlags.contains(.command) {
        names.append("command")
    }
    return names.isEmpty ? "" : " [" + names.joined(separator: "+") + "]"
}

func keyName(for keyCode: UInt16) -> String? {
    switch keyCode {
    case 0x08:
        return "Backspace"
    case 0x09:
        return "Tab"
    case 0x0d:
        return "Enter"
    case 0x10:
        return "Shift"
    case 0x11:
        return "Control"
    case 0x12:
        return "Alt"
    case 0x1b:
        return "Escape"
    case 0x20:
        return "Space"
    case 0x21:
        return "Page Up"
    case 0x22:
        return "Page Down"
    case 0x23:
        return "End"
    case 0x24:
        return "Home"
    case 0x26:
        return "Up"
    case 0x28:
        return "Down"
    case 0x5b:
        return "Left Windows"
    case 0x5c:
        return "Right Windows"
    case 0xa0:
        return "Left Shift"
    case 0xa1:
        return "Right Shift"
    case 0xa2:
        return "Left Control"
    case 0xa3:
        return "Right Control"
    case 0xa4:
        return "Left Alt"
    case 0xa5:
        return "Right Alt"
    default:
        return nil
    }
}

func printableCharacterText(for event: NSEvent) -> String {
    guard let characters = event.characters, !characters.isEmpty else {
        return ""
    }

    switch characters {
    case "\t":
        return " <tab>"
    case "\n":
        return " <enter>"
    case "\u{1b}":
        return " <escape>"
    case "\u{8}":
        return " <backspace>"
    default:
        return " '\(characters)'"
    }
}

func keyText(for event: NSEvent) -> String {
    let code = event.keyCode ?? 0
    let name = keyName(for: code).map { " \($0)" } ?? ""
    return "\(code)\(name)\(printableCharacterText(for: event))\(modifierText(for: event))"
}

func tableRowSummary(_ table: NSTableView, prefix: String) -> String {
    let row = table.clickedRow
    if row >= 0,
       let name = table.value(atColumn: 0, row: row),
       let status = table.value(atColumn: 1, row: row) {
        let column = table.clickedColumn
        if column >= 0,
           let tableColumn = table.tableColumn(at: column) {
            return "\(prefix): row \(row + 1), \(tableColumn.title) - \(name) - \(status)"
        }

        return "\(prefix): row \(row + 1) - \(name) - \(status)"
    }

    return "\(prefix): no row"
}

func tableColumnSummary(_ table: NSTableView) -> String? {
    let column = table.clickedColumn
    guard table.clickedRow < 0,
          column >= 0,
          let tableColumn = table.tableColumn(at: column) else {
        return nil
    }

    return "Table column: \(tableColumn.title)"
}

@MainActor
func focusName() -> String {
    guard let responder = window.firstResponder else {
        return "none"
    }

    if responder === contentView {
        return "content"
    }
    if responder === editableTextField {
        return "text field"
    }
    if responder === secureTextField {
        return "secure text field"
    }
    if responder === button {
        return "click button"
    }
    if responder === enableButton {
        return "disable button"
    }
    if responder === hideButton {
        return "hide button"
    }
    if responder === moveButton {
        return "move button"
    }
    if responder === alertButton {
        return "alert button"
    }
    if responder === titleCheckbox {
        return "title checkbox"
    }
    if responder === alertStylePopup {
        return "alert style popup"
    }
    if responder === infoRadio {
        return "info radio"
    }
    if responder === warningRadio {
        return "warning radio"
    }
    if responder === criticalRadio {
        return "critical radio"
    }
    if responder === notesTextView {
        return "notes"
    }
    if responder === slider {
        return "slider"
    }
    if responder === stepper {
        return "stepper"
    }
    if responder === comboBox {
        return "combo box"
    }
    if responder === searchField {
        return "search field"
    }
    if responder === levelIndicator {
        return "level indicator"
    }
    if responder === colorWell {
        return "color well"
    }
    if responder === tabView {
        return "tab view"
    }
    if responder === tableView {
        return "table view"
    }
    return "view"
}

@MainActor
func updateFocusDisplay() {
    let name = focusName()
    focusLabel.stringValue = "Focus: \(name)"
    contentView.backgroundColor = name == "content" ? contentFocusColor : normalContentColor
    editableTextField.backgroundColor = name == "text field"
        ? controlFocusColor
        : normalTextFieldColor
    secureTextField.backgroundColor = name == "secure text field"
        ? controlFocusColor
        : normalTextFieldColor
    searchField.backgroundColor = name == "search field"
        ? controlFocusColor
        : normalTextFieldColor
}

contentView.backgroundColor = normalContentColor
counterLabel.font = NSFont.boldSystemFont(ofSize: 14)
counterLabel.textColor = .green
statusLabel.font = NSFont.systemFont(ofSize: 13)
statusLabel.textColor = .blue
statusLabel.backgroundColor = NSColor(calibratedRed: 0.94, green: 0.97, blue: 1.0, alpha: 1.0)
focusLabel.font = NSFont.boldSystemFont(ofSize: 12)
focusLabel.textColor = .black
focusLabel.backgroundColor = NSColor(calibratedRed: 1.0, green: 0.98, blue: 0.86, alpha: 1.0)
slider.frame = NSMakeRect(832, 166, 184, 28)
sliderLabel.font = NSFont.boldSystemFont(ofSize: 12)
sliderValueLabel.textColor = .blue
progressLabel.font = NSFont.boldSystemFont(ofSize: 12)
progressIndicator.minValue = 0
progressIndicator.maxValue = 100
progressIndicator.doubleValue = slider.doubleValue
stepperLabel.font = NSFont.boldSystemFont(ofSize: 12)
stepper.minValue = 0
stepper.maxValue = 100
stepper.increment = 1
stepper.doubleValue = 50
stepperValueLabel.textColor = .blue
comboLabel.font = NSFont.boldSystemFont(ofSize: 12)
comboBox.addItems(withObjectValues: ["Cocoa", "AppKit", "WinChocolate"])
comboBox.stringValue = "WinChocolate"
searchLabel.font = NSFont.boldSystemFont(ofSize: 12)
searchField.placeholderString = "Find controls"
levelLabel.font = NSFont.boldSystemFont(ofSize: 12)
levelIndicator.minValue = 0
levelIndicator.maxValue = 100
levelIndicator.warningValue = 70
levelIndicator.criticalValue = 90
levelIndicator.doubleValue = stepper.doubleValue
colorWellLabel.font = NSFont.boldSystemFont(ofSize: 12)
colorWell.color = demoColors[colorIndex]
tabLabel.font = NSFont.boldSystemFont(ofSize: 12)
let firstTab = NSTabViewItem(identifier: "controls")
firstTab.label = "Controls"
let secondTab = NSTabViewItem(identifier: "tables")
secondTab.label = "Tables"
let thirdTab = NSTabViewItem(identifier: "events")
thirdTab.label = "Events"
tabView.addTabViewItem(firstTab)
tabView.addTabViewItem(secondTab)
tabView.addTabViewItem(thirdTab)
imageLabel.font = NSFont.boldSystemFont(ofSize: 12)
imageView.image = NSImage(contentsOfFile: demoArtworkPath) ?? NSImage(named: "WinChocolate artwork")
imageView.imageFrameStyle = .grayBezel
splitLabel.font = NSFont.boldSystemFont(ofSize: 12)
splitLeftPane.backgroundColor = NSColor(calibratedRed: 0.86, green: 0.93, blue: 1.0, alpha: 1.0)
splitRightPane.backgroundColor = NSColor(calibratedRed: 1.0, green: 0.92, blue: 0.84, alpha: 1.0)
splitView.addSubview(splitLeftPane)
splitView.addSubview(splitRightPane)
splitView.setPosition(70, ofDividerAt: 0)
notesLabel.font = NSFont.boldSystemFont(ofSize: 12)
secureLabel.font = NSFont.boldSystemFont(ofSize: 12)
notesTextView.string = "Multiline NSTextView"
contentView.onBlankAreaMouseDown = { event in
    updateFocusDisplay()
}
contentView.onBlankAreaMouseUp = { event in
    statusLabel.stringValue = "Mouse up at \(Int(event.locationInWindow.x)), \(Int(event.locationInWindow.y))\(modifierText(for: event))"
}
// Keep mouse-move dispatch wired in the framework, but leave demo status quiet
// unless we are actively testing mouse movement.
contentView.onMouseMoved = nil
contentView.onKeyDown = { event in
    if event.keyCode == 0x09 {
        if event.modifierFlags.contains(.shift) {
            window.selectPreviousKeyView(nil)
        } else {
            window.selectNextKeyView(nil)
        }
        updateFocusDisplay()
        statusLabel.stringValue = "Focus moved with Tab"
        return
    }

    statusLabel.stringValue = "Key down: \(keyText(for: event))"
}
contentView.onKeyUp = { event in
    if event.keyCode == 0x09 {
        return
    }

    statusLabel.stringValue = "Key up: \(keyText(for: event))"
}

titleCheckbox.setButtonType(.switchButton)
titleCheckbox.state = .on
infoRadio.setButtonType(.radioButton)
warningRadio.setButtonType(.radioButton)
criticalRadio.setButtonType(.radioButton)
infoRadio.state = .on
alertStylePopup.addItems(withTitles: ["Info", "Warning", "Critical"])
alertStylePopup.selectItem(withTitle: "Info")
let tableNameColumn = NSTableColumn(identifier: "name")
let tableStatusColumn = NSTableColumn(identifier: "status")
tableNameColumn.title = "Name"
tableStatusColumn.title = "Status"
tableNameColumn.width = 150
tableStatusColumn.width = 150
tableNameColumn.sortDescriptorPrototype = NSSortDescriptor(key: "name", ascending: true)
tableStatusColumn.sortDescriptorPrototype = NSSortDescriptor(key: "status", ascending: true)
tableView.addTableColumn(tableNameColumn)
tableView.addTableColumn(tableStatusColumn)
tableView.dataSource = tableDataSource
tableView.allowsColumnSelection = true
tableView.reloadData()
tableView.selectRowIndexes([0], byExtendingSelection: false)
tableView.selectColumnIndexes([0], byExtendingSelection: false)
tableScrollView.hasVerticalScroller = true
tableScrollView.documentView = tableView

contentView.nextKeyView = button
editableTextField.nextKeyView = secureTextField
secureTextField.nextKeyView = alertButton
button.nextKeyView = enableButton
enableButton.nextKeyView = hideButton
hideButton.nextKeyView = moveButton
moveButton.nextKeyView = editableTextField
alertButton.nextKeyView = titleCheckbox
titleCheckbox.nextKeyView = alertStylePopup
alertStylePopup.nextKeyView = infoRadio
infoRadio.nextKeyView = warningRadio
warningRadio.nextKeyView = criticalRadio
criticalRadio.nextKeyView = notesTextView
notesTextView.nextKeyView = slider
slider.nextKeyView = stepper
stepper.nextKeyView = comboBox
comboBox.nextKeyView = searchField
searchField.nextKeyView = levelIndicator
levelIndicator.nextKeyView = colorWell
colorWell.nextKeyView = tabView
tabView.nextKeyView = tableView
tableView.nextKeyView = contentView

contentView.previousKeyView = tableView
tableView.previousKeyView = tabView
tabView.previousKeyView = colorWell
colorWell.previousKeyView = levelIndicator
levelIndicator.previousKeyView = searchField
searchField.previousKeyView = comboBox
comboBox.previousKeyView = stepper
stepper.previousKeyView = slider
slider.previousKeyView = notesTextView
notesTextView.previousKeyView = criticalRadio
criticalRadio.previousKeyView = warningRadio
warningRadio.previousKeyView = infoRadio
infoRadio.previousKeyView = alertStylePopup
alertStylePopup.previousKeyView = titleCheckbox
titleCheckbox.previousKeyView = alertButton
alertButton.previousKeyView = secureTextField
moveButton.previousKeyView = hideButton
hideButton.previousKeyView = enableButton
enableButton.previousKeyView = button
button.previousKeyView = contentView
secureTextField.previousKeyView = editableTextField
editableTextField.previousKeyView = moveButton

editableTextField.isEditable = true
editableTextField.onTextChanged = { field in
    updateFocusDisplay()
    statusLabel.stringValue = field.stringValue.isEmpty
        ? "Edit field cleared"
        : "Typed: \(field.stringValue)"
}

secureTextField.onTextChanged = { field in
    updateFocusDisplay()
    statusLabel.stringValue = "Password length: \(field.stringValue.count)"
}

comboBox.onComboBoxTextChanged = { combo in
    updateFocusDisplay()
    statusLabel.stringValue = "Combo typed: \(combo.stringValue)"
}
comboBox.onAction = { control in
    guard let combo = control as? NSComboBox else {
        return
    }

    updateFocusDisplay()
    statusLabel.stringValue = "Combo selected: \(combo.stringValue)"
}

searchField.onAction = { control in
    guard let searchField = control as? NSSearchField else {
        return
    }

    updateFocusDisplay()
    statusLabel.stringValue = searchField.stringValue.isEmpty
        ? "Search cleared"
        : "Search: \(searchField.stringValue)"
}

levelIndicator.onAction = { control in
    guard let level = control as? NSLevelIndicator else {
        return
    }

    updateFocusDisplay()
    statusLabel.stringValue = "Level value: \(level.intValue)"
}

colorWell.onAction = { _ in
    updateFocusDisplay()
    colorIndex = (colorIndex + 1) % demoColors.count
    colorWell.color = demoColors[colorIndex]
    statusLabel.stringValue = "Color well changed"
}

tabView.onSelectionChanged = { tabs in
    updateFocusDisplay()
    statusLabel.stringValue = "Tab selected: \(tabs.selectedTabViewItem?.label ?? "none")"
}

imageView.onAction = { _ in
    updateFocusDisplay()
    imageModeIndex = (imageModeIndex + 1) % imageModes.count
    let mode = imageModes[imageModeIndex]
    imageView.imageScaling = mode.0
    imageView.imageAlignment = mode.1
    imageView.image = NSImage(contentsOfFile: mode.2) ?? NSImage(named: mode.2)
    statusLabel.stringValue = "Image mode: \(mode.3)"
}

notesTextView.onTextChanged = { textView in
    updateFocusDisplay()
    statusLabel.stringValue = "Notes length: \(textView.string.count)"
}

button.onAction = { _ in
    updateFocusDisplay()
    clickCount += 1
    counterLabel.stringValue = "Clicks: \(clickCount)"
    if titleCheckbox.state == .on {
        window.title = "WinChocolate Click Counter (\(clickCount))"
    }
    statusLabel.stringValue = "Click button fired"
}

enableButton.onAction = { _ in
    updateFocusDisplay()
    isClickEnabled.toggle()
    button.isEnabled = isClickEnabled
    enableButton.title = isClickEnabled ? "Disable Click" : "Enable Click"
    statusLabel.stringValue = isClickEnabled ? "Click button enabled" : "Click button disabled"
}

hideButton.onAction = { _ in
    updateFocusDisplay()
    isCounterHidden.toggle()
    counterLabel.isHidden = isCounterHidden
    hideButton.title = isCounterHidden ? "Show Counter" : "Hide Counter"
    statusLabel.stringValue = isCounterHidden ? "Counter hidden" : "Counter visible"
}

moveButton.onAction = { _ in
    updateFocusDisplay()
    movedRight.toggle()
    button.frame = movedRight
        ? NSMakeRect(32, 430, 100, 34)
        : NSMakeRect(32, 124, 100, 34)
    statusLabel.stringValue = movedRight ? "Click button moved down" : "Click button moved back"
}

alertButton.onAction = { _ in
    updateFocusDisplay()
    let alert = NSAlert()
    alert.messageText = "WinChocolate is running"
    alert.informativeText = "This is a native modal NSAlert backed by MessageBoxW."
    if alertStylePopup.titleOfSelectedItem == "Warning" {
        alert.alertStyle = .warning
    } else if alertStylePopup.titleOfSelectedItem == "Critical" {
        alert.alertStyle = .critical
    } else {
        alert.alertStyle = .informational
    }
    alert.addButton(withTitle: "OK")
    _ = alert.runModal()
    updateFocusDisplay()
    statusLabel.stringValue = "Alert dismissed"
}

titleCheckbox.onAction = { _ in
    updateFocusDisplay()
    statusLabel.stringValue = titleCheckbox.state == .on
        ? "Title count enabled"
        : "Title count disabled"
    if titleCheckbox.state == .off {
        window.title = "WinChocolate Click Counter"
    }
}

infoRadio.onAction = { _ in
    updateFocusDisplay()
    alertStylePopup.selectItem(withTitle: "Info")
    statusLabel.stringValue = "Alert style: info"
}

warningRadio.onAction = { _ in
    updateFocusDisplay()
    alertStylePopup.selectItem(withTitle: "Warning")
    statusLabel.stringValue = "Alert style: warning"
}

criticalRadio.onAction = { _ in
    updateFocusDisplay()
    alertStylePopup.selectItem(withTitle: "Critical")
    statusLabel.stringValue = "Alert style: critical"
}

alertStylePopup.onAction = { _ in
    updateFocusDisplay()
    let title = alertStylePopup.titleOfSelectedItem ?? "Info"
    if title == "Warning" {
        warningRadio.performClick(nil)
    } else if title == "Critical" {
        criticalRadio.performClick(nil)
    } else {
        infoRadio.performClick(nil)
    }
}

slider.onAction = { control in
    guard let slider = control as? NSSlider else {
        return
    }

    updateFocusDisplay()
    sliderValueLabel.stringValue = "\(slider.intValue)"
    progressIndicator.doubleValue = slider.doubleValue
    statusLabel.stringValue = "Slider value: \(slider.intValue)"
}

stepper.onAction = { control in
    guard let stepper = control as? NSStepper else {
        return
    }

    updateFocusDisplay()
    stepperValueLabel.stringValue = "\(stepper.intValue)"
    levelIndicator.doubleValue = stepper.doubleValue
    statusLabel.stringValue = "Stepper value: \(stepper.intValue)"
}

tableView.onSelectionChanged = { table in
    updateFocusDisplay()
    if suppressNextTableSelectionStatus {
        suppressNextTableSelectionStatus = false
        return
    }

    statusLabel.stringValue = tableRowSummary(table, prefix: "Table selected")
}
tableView.onAction = { control in
    guard let table = control as? NSTableView else {
        return
    }

    updateFocusDisplay()
    suppressNextTableSelectionStatus = true
    if let columnSummary = tableColumnSummary(table) {
        if let sortDescriptor = table.sortUsingDescriptorPrototype(forColumn: table.clickedColumn) {
            tableDataSource.sort(using: sortDescriptor)
            NSApp.nativeBackend.dispatchAsync {
                table.reloadData()
            }
            statusLabel.stringValue = "\(columnSummary), sorted \(sortDescriptor.ascending ? "ascending" : "descending")"
        } else {
            statusLabel.stringValue = columnSummary
        }
        return
    }

    statusLabel.stringValue = tableColumnSummary(table) ?? tableRowSummary(table, prefix: "Table action")
}
tableView.doubleAction = "openTableRow:"
tableView.onDoubleAction = { table in
    updateFocusDisplay()
    statusLabel.stringValue = tableRowSummary(table, prefix: "Table double action")
}

contentView.addSubview(counterLabel)
contentView.addSubview(statusLabel)
contentView.addSubview(focusLabel)
contentView.addSubview(editableLabel)
contentView.addSubview(editableTextField)
contentView.addSubview(secureLabel)
contentView.addSubview(secureTextField)
contentView.addSubview(button)
contentView.addSubview(enableButton)
contentView.addSubview(hideButton)
contentView.addSubview(moveButton)
contentView.addSubview(alertButton)
contentView.addSubview(titleCheckbox)
contentView.addSubview(alertStyleBox)
contentView.addSubview(alertStyleLabel)
contentView.addSubview(alertStylePopup)
contentView.addSubview(infoRadio)
contentView.addSubview(warningRadio)
contentView.addSubview(criticalRadio)
contentView.addSubview(notesLabel)
contentView.addSubview(notesTextView)
contentView.addSubview(sliderLabel)
contentView.addSubview(slider)
contentView.addSubview(sliderValueLabel)
contentView.addSubview(progressLabel)
contentView.addSubview(progressIndicator)
contentView.addSubview(stepperLabel)
contentView.addSubview(stepper)
contentView.addSubview(stepperValueLabel)
contentView.addSubview(comboLabel)
contentView.addSubview(comboBox)
contentView.addSubview(searchLabel)
contentView.addSubview(searchField)
contentView.addSubview(levelLabel)
contentView.addSubview(levelIndicator)
contentView.addSubview(colorWellLabel)
contentView.addSubview(colorWell)
contentView.addSubview(tabLabel)
contentView.addSubview(tabView)
contentView.addSubview(imageLabel)
contentView.addSubview(imageView)
contentView.addSubview(splitLabel)
contentView.addSubview(splitView)
contentView.addSubview(tableLabel)
contentView.addSubview(tableScrollView)
window.contentView = contentView
window.makeKeyAndOrderFront(nil)
updateFocusDisplay()
statusLabel.stringValue = window.isKeyWindow && window.isMainWindow
    ? "Ready - key/main window"
    : "Ready - window shown"

if CommandLine.arguments.contains("--diagnose") {
    print("Window native handle: \(window.nativeHandle?.rawValue ?? 0)")
    print("App windows: \(NSApp.windows.count)")
    print("Is key window: \(window.isKeyWindow)")
    print("Is main window: \(window.isMainWindow)")
} else {
    app.run()
}
