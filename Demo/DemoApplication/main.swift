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
    contentRect: NSMakeRect(100, 100, 760, 500),
    styleMask: [.titled, .closable, .miniaturizable, .resizable],
    backing: .buffered,
    defer: false
)
window.title = "WinChocolate Click Counter"

let contentView = NSView(frame: NSMakeRect(0, 0, 760, 500))
let counterLabel = NSTextField(string: "Clicks: 0", frame: NSMakeRect(32, 36, 300, 24))
let statusLabel = NSTextField(string: "Ready", frame: NSMakeRect(32, 74, 520, 24))
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
var clickCount = 0
var isClickEnabled = true
var isCounterHidden = false
var movedRight = false

contentView.backgroundColor = .windowBackgroundColor
counterLabel.font = NSFont.boldSystemFont(ofSize: 14)
counterLabel.textColor = .green
statusLabel.font = NSFont.systemFont(ofSize: 13)
statusLabel.textColor = .blue
statusLabel.backgroundColor = NSColor(calibratedRed: 0.94, green: 0.97, blue: 1.0, alpha: 1.0)

titleCheckbox.setButtonType(.switchButton)
titleCheckbox.state = .on
infoRadio.setButtonType(.radioButton)
warningRadio.setButtonType(.radioButton)
criticalRadio.setButtonType(.radioButton)
infoRadio.state = .on
alertStylePopup.addItems(withTitles: ["Info", "Warning", "Critical"])
alertStylePopup.selectItem(withTitle: "Info")

editableTextField.isEditable = true
editableTextField.onTextChanged = { field in
    statusLabel.stringValue = field.stringValue.isEmpty
        ? "Edit field cleared"
        : "Typed: \(field.stringValue)"
}

button.onAction = { _ in
    clickCount += 1
    counterLabel.stringValue = "Clicks: \(clickCount)"
    if titleCheckbox.state == .on {
        window.title = "WinChocolate Click Counter (\(clickCount))"
    }
    statusLabel.stringValue = "Click button fired"
}

enableButton.onAction = { _ in
    isClickEnabled.toggle()
    button.isEnabled = isClickEnabled
    enableButton.title = isClickEnabled ? "Disable Click" : "Enable Click"
    statusLabel.stringValue = isClickEnabled ? "Click button enabled" : "Click button disabled"
}

hideButton.onAction = { _ in
    isCounterHidden.toggle()
    counterLabel.isHidden = isCounterHidden
    hideButton.title = isCounterHidden ? "Show Counter" : "Hide Counter"
    statusLabel.stringValue = isCounterHidden ? "Counter hidden" : "Counter visible"
}

moveButton.onAction = { _ in
    movedRight.toggle()
    button.frame = movedRight
        ? NSMakeRect(32, 386, 100, 34)
        : NSMakeRect(32, 124, 100, 34)
    statusLabel.stringValue = movedRight ? "Click button moved down" : "Click button moved back"
}

alertButton.onAction = { _ in
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
    statusLabel.stringValue = "Alert dismissed"
}

titleCheckbox.onAction = { _ in
    statusLabel.stringValue = titleCheckbox.state == .on
        ? "Title count enabled"
        : "Title count disabled"
    if titleCheckbox.state == .off {
        window.title = "WinChocolate Click Counter"
    }
}

infoRadio.onAction = { _ in
    alertStylePopup.selectItem(withTitle: "Info")
    statusLabel.stringValue = "Alert style: info"
}

warningRadio.onAction = { _ in
    alertStylePopup.selectItem(withTitle: "Warning")
    statusLabel.stringValue = "Alert style: warning"
}

criticalRadio.onAction = { _ in
    alertStylePopup.selectItem(withTitle: "Critical")
    statusLabel.stringValue = "Alert style: critical"
}

alertStylePopup.onAction = { _ in
    let title = alertStylePopup.titleOfSelectedItem ?? "Info"
    if title == "Warning" {
        warningRadio.performClick(nil)
    } else if title == "Critical" {
        criticalRadio.performClick(nil)
    } else {
        infoRadio.performClick(nil)
    }
}

contentView.addSubview(counterLabel)
contentView.addSubview(statusLabel)
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
window.contentView = contentView
window.makeKeyAndOrderFront(nil)

if CommandLine.arguments.contains("--diagnose") {
    print("Window native handle: \(window.nativeHandle?.rawValue ?? 0)")
} else {
    app.run()
}
