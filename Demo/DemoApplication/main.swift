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
    contentRect: NSMakeRect(100, 100, 920, 640),
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
    let rows: [[String]] = [
        ["NSApplication", "Running"],
        ["NSWindow", "Key/Main"],
        ["NSButton", "Actions"],
        ["NSTextField", "Editing"],
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
}

let contentView = DemoContentView(frame: NSMakeRect(0, 0, 920, 640))
let counterLabel = NSTextField(string: "Clicks: 0", frame: NSMakeRect(32, 36, 300, 24))
let statusLabel = NSTextField(string: "Ready", frame: NSMakeRect(32, 74, 520, 24))
let focusLabel = NSTextField(string: "Focus: none", frame: NSMakeRect(568, 74, 260, 24))
let button = NSButton(title: "Click", frame: NSMakeRect(32, 124, 100, 34))
let enableButton = NSButton(title: "Disable Click", frame: NSMakeRect(152, 124, 144, 34))
let hideButton = NSButton(title: "Hide Counter", frame: NSMakeRect(316, 124, 144, 34))
let moveButton = NSButton(title: "Move Click", frame: NSMakeRect(480, 124, 128, 34))
let editableLabel = NSTextField(string: "Type here:", frame: NSMakeRect(32, 188, 104, 24))
let editableTextField = NSTextField(string: "", frame: NSMakeRect(152, 186, 360, 28))
let alertButton = NSButton(title: "Alert", frame: NSMakeRect(32, 252, 100, 34))
let titleCheckbox = NSButton(title: "Show count in title", frame: NSMakeRect(152, 252, 228, 34))
let alertStyleBox = NSBox(title: "Alert Style", frame: NSMakeRect(448, 220, 248, 116))
let alertStyleLabel = NSTextField(string: "Alert style:", frame: NSMakeRect(472, 256, 112, 24))
let alertStylePopup = NSPopUpButton(frame: NSMakeRect(472, 286, 184, 96), pullsDown: false)
let infoRadio = NSButton(title: "Info", frame: NSMakeRect(32, 334, 88, 24))
let warningRadio = NSButton(title: "Warning", frame: NSMakeRect(136, 334, 116, 24))
let criticalRadio = NSButton(title: "Critical", frame: NSMakeRect(268, 334, 116, 24))
let tableLabel = NSTextField(string: "Table view:", frame: NSMakeRect(560, 392, 120, 24))
let tableScrollView = NSScrollView(frame: NSMakeRect(560, 424, 300, 160))
let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 160))
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
tableView.addTableColumn(tableNameColumn)
tableView.addTableColumn(tableStatusColumn)
tableView.dataSource = tableDataSource
tableView.allowsColumnSelection = true
tableView.reloadData()
tableView.selectRowIndexes([0], byExtendingSelection: false)
tableView.selectColumnIndexes([0], byExtendingSelection: false)
tableScrollView.hasVerticalScroller = true
tableScrollView.documentView = tableView

contentView.nextKeyView = editableTextField
editableTextField.nextKeyView = button
button.nextKeyView = enableButton
enableButton.nextKeyView = hideButton
hideButton.nextKeyView = moveButton
moveButton.nextKeyView = alertButton
alertButton.nextKeyView = titleCheckbox
titleCheckbox.nextKeyView = alertStylePopup
alertStylePopup.nextKeyView = infoRadio
infoRadio.nextKeyView = warningRadio
warningRadio.nextKeyView = criticalRadio
criticalRadio.nextKeyView = tableView
tableView.nextKeyView = contentView

contentView.previousKeyView = tableView
tableView.previousKeyView = criticalRadio
criticalRadio.previousKeyView = warningRadio
warningRadio.previousKeyView = infoRadio
infoRadio.previousKeyView = alertStylePopup
alertStylePopup.previousKeyView = titleCheckbox
titleCheckbox.previousKeyView = alertButton
alertButton.previousKeyView = moveButton
moveButton.previousKeyView = hideButton
hideButton.previousKeyView = enableButton
enableButton.previousKeyView = button
button.previousKeyView = editableTextField
editableTextField.previousKeyView = contentView

editableTextField.isEditable = true
editableTextField.onTextChanged = { field in
    updateFocusDisplay()
    statusLabel.stringValue = field.stringValue.isEmpty
        ? "Edit field cleared"
        : "Typed: \(field.stringValue)"
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
        ? NSMakeRect(32, 386, 100, 34)
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
