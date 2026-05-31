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
    contentRect: NSMakeRect(100, 100, 1120, 760),
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

final class DemoPageView: NSView {
    override var acceptsFirstResponder: Bool {
        false
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
        ["NSSegmentedControl", "Composed segments"],
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

let contentView = DemoContentView(frame: NSMakeRect(0, 0, 1120, 760))
let controlsPage = DemoPageView(frame: NSMakeRect(0, 144, 1120, 560))
let valuesPage = DemoPageView(frame: NSMakeRect(0, 144, 1120, 560))
let tablesPage = DemoPageView(frame: NSMakeRect(0, 144, 1120, 560))
valuesPage.isHidden = true
tablesPage.isHidden = true
let counterLabel = NSTextField(string: "Clicks: 0", frame: NSMakeRect(32, 36, 300, 24))
let statusLabel = NSTextField(string: "Ready", frame: NSMakeRect(32, 74, 640, 24))
let focusLabel = NSTextField(string: "Focus: none", frame: NSMakeRect(744, 74, 300, 24))
let button = NSButton(title: "Click", frame: NSMakeRect(32, 24, 100, 34))
let enableButton = NSButton(title: "Disable Click", frame: NSMakeRect(152, 24, 144, 34))
let hideButton = NSButton(title: "Hide Counter", frame: NSMakeRect(316, 24, 144, 34))
let moveButton = NSButton(title: "Move Click", frame: NSMakeRect(480, 24, 128, 34))
let editableLabel = NSTextField(string: "Type here:", frame: NSMakeRect(32, 88, 104, 24))
let editableTextField = NSTextField(string: "", frame: NSMakeRect(152, 86, 360, 28))
let secureLabel = NSTextField(string: "Password:", frame: NSMakeRect(32, 122, 104, 24))
let secureTextField = NSSecureTextField(string: "", frame: NSMakeRect(152, 120, 240, 28))
let alertButton = NSButton(title: "Alert", frame: NSMakeRect(32, 152, 100, 34))
let titleCheckbox = NSButton(title: "Show count in title", frame: NSMakeRect(152, 152, 228, 34))
let alertStyleBox = NSBox(title: "Alert Style", frame: NSMakeRect(448, 120, 248, 116))
let alertStyleLabel = NSTextField(string: "Alert style:", frame: NSMakeRect(472, 156, 112, 24))
let alertStylePopup = NSPopUpButton(frame: NSMakeRect(472, 186, 184, 96), pullsDown: false)
let infoRadio = NSButton(title: "Info", frame: NSMakeRect(32, 234, 88, 24))
let warningRadio = NSButton(title: "Warning", frame: NSMakeRect(136, 234, 116, 24))
let criticalRadio = NSButton(title: "Critical", frame: NSMakeRect(268, 234, 116, 24))
let notesLabel = NSTextField(string: "Notes:", frame: NSMakeRect(32, 286, 104, 24))
let notesTextView = NSTextView(frame: NSMakeRect(152, 286, 360, 96))
let tokenLabel = NSTextField(string: "Tokens:", frame: NSMakeRect(32, 410, 104, 24))
let tokenField = NSTokenField(tokens: ["Cocoa", "AppKit", "WinChocolate"], frame: NSMakeRect(152, 408, 360, 28))
let sliderLabel = NSTextField(string: "Slider:", frame: NSMakeRect(32, 28, 72, 24))
let slider = NSSlider(value: 50, minValue: 0, maxValue: 100, target: nil, action: "sliderChanged:")
let sliderValueLabel = NSTextField(string: "50", frame: NSMakeRect(312, 28, 48, 24))
let progressLabel = NSTextField(string: "Progress:", frame: NSMakeRect(32, 60, 88, 24))
let progressIndicator = NSProgressIndicator(frame: NSMakeRect(128, 64, 232, 18))
let stepperLabel = NSTextField(string: "Stepper:", frame: NSMakeRect(32, 94, 88, 24))
let stepper = NSStepper(frame: NSMakeRect(128, 94, 20, 28))
let stepperValueLabel = NSTextField(string: "50", frame: NSMakeRect(176, 94, 64, 24))
let comboLabel = NSTextField(string: "Combo:", frame: NSMakeRect(32, 154, 88, 24))
let comboBox = NSComboBox(frame: NSMakeRect(128, 152, 184, 28))
let searchLabel = NSTextField(string: "Search:", frame: NSMakeRect(32, 190, 88, 24))
let searchField = NSSearchField(frame: NSMakeRect(128, 188, 232, 28))
let levelLabel = NSTextField(string: "Level:", frame: NSMakeRect(32, 226, 88, 24))
let levelIndicator = NSLevelIndicator(frame: NSMakeRect(128, 230, 144, 18))
let colorWellLabel = NSTextField(string: "Color:", frame: NSMakeRect(288, 226, 56, 24))
let colorWell = NSColorWell(frame: NSMakeRect(348, 224, 32, 28))
let segmentedLabel = NSTextField(string: "Segments:", frame: NSMakeRect(32, 286, 104, 24))
let segmentedControl = NSSegmentedControl(labels: ["One", "Two", "Three"], frame: NSMakeRect(152, 284, 240, 28))
let scrollerLabel = NSTextField(string: "Scroller:", frame: NSMakeRect(32, 334, 88, 24))
let scroller = NSScroller(frame: NSMakeRect(128, 340, 240, 18))
let scrollerValueLabel = NSTextField(string: "0", frame: NSMakeRect(384, 334, 48, 24))
let tabLabel = NSTextField(string: "Groups:", frame: NSMakeRect(32, 114, 104, 24))
let tabView = NSTabView(frame: NSMakeRect(152, 112, 360, 32))
let imageLabel = NSTextField(string: "Image view:", frame: NSMakeRect(32, 28, 104, 24))
let imageView = NSImageView(frame: NSMakeRect(152, 28, 300, 190))
let clipLabel = NSTextField(string: "Clip view:", frame: NSMakeRect(496, 28, 104, 24))
let clipView = NSClipView(frame: NSMakeRect(616, 28, 220, 110))
let clipDocumentView = NSView(frame: NSMakeRect(0, 0, 420, 220))
let clipTopLeftPane = NSView(frame: NSMakeRect(0, 0, 210, 110))
let clipTopRightPane = NSView(frame: NSMakeRect(210, 0, 210, 110))
let clipBottomLeftPane = NSView(frame: NSMakeRect(0, 110, 210, 110))
let clipBottomRightPane = NSView(frame: NSMakeRect(210, 110, 210, 110))
let clipTopLeftLabel = NSTextField(string: "0,0", frame: NSMakeRect(12, 12, 72, 24))
let clipTopRightLabel = NSTextField(string: "right", frame: NSMakeRect(222, 12, 72, 24))
let clipBottomLeftLabel = NSTextField(string: "down", frame: NSMakeRect(12, 122, 72, 24))
let clipBottomRightLabel = NSTextField(string: "far corner", frame: NSMakeRect(222, 122, 100, 24))
let clipOriginLabel = NSTextField(string: "origin 0,0", frame: NSMakeRect(848, 28, 96, 24))
let clipHomeButton = NSButton(title: "Home", frame: NSMakeRect(848, 60, 72, 28))
let clipCenterButton = NSButton(title: "Center", frame: NSMakeRect(928, 60, 72, 28))
let clipCornerButton = NSButton(title: "Corner", frame: NSMakeRect(1008, 60, 72, 28))
let pathLabel = NSTextField(string: "Path:", frame: NSMakeRect(496, 286, 104, 24))
let pathControl = NSPathControl(url: URL(fileURLWithPath: "C:\\AIResearch\\WinChocolate\\Code\\WinChocolate"), frame: NSMakeRect(616, 284, 360, 28))
let splitLabel = NSTextField(string: "Split view:", frame: NSMakeRect(496, 160, 104, 24))
let splitView = NSSplitView(frame: NSMakeRect(616, 160, 240, 96))
let splitLeftPane = NSView(frame: NSZeroRect)
let splitRightPane = NSView(frame: NSZeroRect)
let tableLabel = NSTextField(string: "Table view:", frame: NSMakeRect(32, 246, 120, 24))
let tableScrollView = NSScrollView(frame: NSMakeRect(152, 246, 520, 250))
let tableView = NSTableView(frame: NSMakeRect(0, 0, 520, 250))
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
    if responder === tokenField {
        return "token field"
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
    if responder === segmentedControl {
        return "segments"
    }
    if responder === clipHomeButton {
        return "clip home"
    }
    if responder === clipCenterButton {
        return "clip center"
    }
    if responder === clipCornerButton {
        return "clip corner"
    }
    if responder === pathControl {
        return "path control"
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
    tokenField.backgroundColor = name == "token field"
        ? controlFocusColor
        : normalTextFieldColor
    pathControl.backgroundColor = name == "path control"
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
slider.frame = NSMakeRect(120, 28, 184, 28)
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
segmentedLabel.font = NSFont.boldSystemFont(ofSize: 12)
segmentedControl.selectedSegment = 0
scrollerLabel.font = NSFont.boldSystemFont(ofSize: 12)
scroller.doubleValue = 0
scroller.knobProportion = 0.25
scrollerValueLabel.textColor = .blue
tabLabel.font = NSFont.boldSystemFont(ofSize: 12)
let firstTab = NSTabViewItem(identifier: "controls")
firstTab.label = "Controls"
let secondTab = NSTabViewItem(identifier: "values")
secondTab.label = "Values"
let thirdTab = NSTabViewItem(identifier: "tables")
thirdTab.label = "Tables/Media"
tabView.addTabViewItem(firstTab)
tabView.addTabViewItem(secondTab)
tabView.addTabViewItem(thirdTab)
imageLabel.font = NSFont.boldSystemFont(ofSize: 12)
imageView.image = NSImage(contentsOfFile: demoArtworkPath) ?? NSImage(named: "WinChocolate artwork")
imageView.imageFrameStyle = .grayBezel
clipLabel.font = NSFont.boldSystemFont(ofSize: 12)
clipOriginLabel.textColor = .blue
clipView.backgroundColor = .white
clipDocumentView.backgroundColor = NSColor(calibratedRed: 0.97, green: 0.97, blue: 0.97, alpha: 1.0)
clipTopLeftPane.backgroundColor = NSColor(calibratedRed: 0.84, green: 0.92, blue: 1.0, alpha: 1.0)
clipTopRightPane.backgroundColor = NSColor(calibratedRed: 1.0, green: 0.94, blue: 0.72, alpha: 1.0)
clipBottomLeftPane.backgroundColor = NSColor(calibratedRed: 0.86, green: 1.0, blue: 0.86, alpha: 1.0)
clipBottomRightPane.backgroundColor = NSColor(calibratedRed: 1.0, green: 0.86, blue: 0.88, alpha: 1.0)
clipDocumentView.addSubview(clipTopLeftPane)
clipDocumentView.addSubview(clipTopRightPane)
clipDocumentView.addSubview(clipBottomLeftPane)
clipDocumentView.addSubview(clipBottomRightPane)
clipDocumentView.addSubview(clipTopLeftLabel)
clipDocumentView.addSubview(clipTopRightLabel)
clipDocumentView.addSubview(clipBottomLeftLabel)
clipDocumentView.addSubview(clipBottomRightLabel)
clipView.documentView = clipDocumentView
splitLabel.font = NSFont.boldSystemFont(ofSize: 12)
splitLeftPane.backgroundColor = NSColor(calibratedRed: 0.86, green: 0.93, blue: 1.0, alpha: 1.0)
splitRightPane.backgroundColor = NSColor(calibratedRed: 1.0, green: 0.92, blue: 0.84, alpha: 1.0)
splitView.addSubview(splitLeftPane)
splitView.addSubview(splitRightPane)
splitView.setPosition(70, ofDividerAt: 0)
notesLabel.font = NSFont.boldSystemFont(ofSize: 12)
secureLabel.font = NSFont.boldSystemFont(ofSize: 12)
notesTextView.string = "Multiline NSTextView"
tokenLabel.font = NSFont.boldSystemFont(ofSize: 12)
pathLabel.font = NSFont.boldSystemFont(ofSize: 12)
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

@MainActor
func showDemoPage(_ index: Int) {
    controlsPage.isHidden = index != 0
    valuesPage.isHidden = index != 1
    tablesPage.isHidden = index != 2
    updateFocusDisplay()
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
tableNameColumn.width = 250
tableStatusColumn.width = 240
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
notesTextView.nextKeyView = tokenField
tokenField.nextKeyView = slider
slider.nextKeyView = stepper
stepper.nextKeyView = comboBox
comboBox.nextKeyView = searchField
searchField.nextKeyView = levelIndicator
levelIndicator.nextKeyView = colorWell
colorWell.nextKeyView = segmentedControl
segmentedControl.nextKeyView = tabView
tabView.nextKeyView = clipHomeButton
clipHomeButton.nextKeyView = clipCenterButton
clipCenterButton.nextKeyView = clipCornerButton
clipCornerButton.nextKeyView = pathControl
pathControl.nextKeyView = tableView
tableView.nextKeyView = contentView

contentView.previousKeyView = tableView
tableView.previousKeyView = pathControl
pathControl.previousKeyView = clipCornerButton
clipCornerButton.previousKeyView = clipCenterButton
clipCenterButton.previousKeyView = clipHomeButton
clipHomeButton.previousKeyView = tabView
tabView.previousKeyView = segmentedControl
segmentedControl.previousKeyView = colorWell
colorWell.previousKeyView = levelIndicator
levelIndicator.previousKeyView = searchField
searchField.previousKeyView = comboBox
comboBox.previousKeyView = stepper
stepper.previousKeyView = slider
slider.previousKeyView = tokenField
tokenField.previousKeyView = notesTextView
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

segmentedControl.onAction = { control in
    guard let segmentedControl = control as? NSSegmentedControl else {
        return
    }

    updateFocusDisplay()
    let index = segmentedControl.selectedSegment
    let label = segmentedControl.label(forSegment: index) ?? "none"
    statusLabel.stringValue = "Segment selected: \(label)"
}

scroller.onAction = { control in
    guard let scroller = control as? NSScroller else {
        return
    }

    updateFocusDisplay()
    let percent = Int((scroller.doubleValue * 100).rounded())
    scrollerValueLabel.stringValue = "\(percent)"
    statusLabel.stringValue = "Scroller value: \(percent)%"
}

tabView.onSelectionChanged = { tabs in
    showDemoPage(tabs.indexOfTabViewItem(tabs.selectedTabViewItem ?? firstTab))
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

@MainActor
func scrollClipDemo(to origin: NSPoint, name: String) {
    clipView.scroll(to: origin)
    let visible = clipView.documentVisibleRect
    clipOriginLabel.stringValue = "origin \(Int(visible.origin.x)),\(Int(visible.origin.y))"
    updateFocusDisplay()
    statusLabel.stringValue = "Clip view: \(name) visible \(Int(visible.origin.x)),\(Int(visible.origin.y))"
}

clipHomeButton.onAction = { _ in
    scrollClipDemo(to: NSMakePoint(0, 0), name: "home")
}

clipCenterButton.onAction = { _ in
    scrollClipDemo(to: NSMakePoint(100, 55), name: "center")
}

clipCornerButton.onAction = { _ in
    scrollClipDemo(to: NSMakePoint(220, 110), name: "corner")
}

notesTextView.onTextChanged = { textView in
    updateFocusDisplay()
    statusLabel.stringValue = "Notes length: \(textView.string.count)"
}

tokenField.onTextChanged = { field in
    guard let tokenField = field as? NSTokenField else {
        return
    }

    updateFocusDisplay()
    statusLabel.stringValue = "Tokens: \(tokenField.tokens.joined(separator: " | "))"
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
        : NSMakeRect(32, 24, 100, 34)
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
contentView.addSubview(tabLabel)
contentView.addSubview(tabView)
contentView.addSubview(controlsPage)
contentView.addSubview(valuesPage)
contentView.addSubview(tablesPage)

controlsPage.addSubview(editableLabel)
controlsPage.addSubview(editableTextField)
controlsPage.addSubview(secureLabel)
controlsPage.addSubview(secureTextField)
controlsPage.addSubview(button)
controlsPage.addSubview(enableButton)
controlsPage.addSubview(hideButton)
controlsPage.addSubview(moveButton)
controlsPage.addSubview(alertButton)
controlsPage.addSubview(titleCheckbox)
controlsPage.addSubview(alertStyleBox)
controlsPage.addSubview(alertStyleLabel)
controlsPage.addSubview(alertStylePopup)
controlsPage.addSubview(infoRadio)
controlsPage.addSubview(warningRadio)
controlsPage.addSubview(criticalRadio)
controlsPage.addSubview(notesLabel)
controlsPage.addSubview(notesTextView)
controlsPage.addSubview(tokenLabel)
controlsPage.addSubview(tokenField)

valuesPage.addSubview(sliderLabel)
valuesPage.addSubview(slider)
valuesPage.addSubview(sliderValueLabel)
valuesPage.addSubview(progressLabel)
valuesPage.addSubview(progressIndicator)
valuesPage.addSubview(stepperLabel)
valuesPage.addSubview(stepper)
valuesPage.addSubview(stepperValueLabel)
valuesPage.addSubview(comboLabel)
valuesPage.addSubview(comboBox)
valuesPage.addSubview(searchLabel)
valuesPage.addSubview(searchField)
valuesPage.addSubview(levelLabel)
valuesPage.addSubview(levelIndicator)
valuesPage.addSubview(colorWellLabel)
valuesPage.addSubview(colorWell)
valuesPage.addSubview(segmentedLabel)
valuesPage.addSubview(segmentedControl)
valuesPage.addSubview(scrollerLabel)
valuesPage.addSubview(scroller)
valuesPage.addSubview(scrollerValueLabel)

tablesPage.addSubview(imageLabel)
tablesPage.addSubview(imageView)
tablesPage.addSubview(clipLabel)
tablesPage.addSubview(clipView)
tablesPage.addSubview(clipOriginLabel)
tablesPage.addSubview(clipHomeButton)
tablesPage.addSubview(clipCenterButton)
tablesPage.addSubview(clipCornerButton)
tablesPage.addSubview(pathLabel)
tablesPage.addSubview(pathControl)
tablesPage.addSubview(splitLabel)
tablesPage.addSubview(splitView)
tablesPage.addSubview(tableLabel)
tablesPage.addSubview(tableScrollView)
window.contentView = contentView
window.makeKeyAndOrderFront(nil)
showDemoPage(0)
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
