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
    contentRect: NSMakeRect(100, 100, 560, 360),
    styleMask: [.titled, .closable, .miniaturizable, .resizable],
    backing: .buffered,
    defer: false
)
window.title = "WinChocolate Click Counter"

let contentView = NSView(frame: NSMakeRect(0, 0, 560, 360))
let counterLabel = NSTextField(string: "Clicks: 0", frame: NSMakeRect(24, 286, 260, 24))
let statusLabel = NSTextField(string: "Ready", frame: NSMakeRect(24, 252, 360, 24))
let editableLabel = NSTextField(string: "Type here:", frame: NSMakeRect(24, 72, 80, 24))
let editableTextField = NSTextField(string: "", frame: NSMakeRect(112, 72, 240, 24))
let button = NSButton(title: "Click", frame: NSMakeRect(24, 204, 88, 32))
let enableButton = NSButton(title: "Disable Click", frame: NSMakeRect(128, 204, 128, 32))
let hideButton = NSButton(title: "Hide Counter", frame: NSMakeRect(272, 204, 128, 32))
let moveButton = NSButton(title: "Move Click", frame: NSMakeRect(416, 204, 112, 32))
let alertButton = NSButton(title: "Alert", frame: NSMakeRect(24, 108, 88, 32))
let titleCheckbox = NSButton(title: "Show count in title", frame: NSMakeRect(128, 108, 180, 32))
let infoRadio = NSButton(title: "Info", frame: NSMakeRect(24, 28, 72, 24))
let warningRadio = NSButton(title: "Warning", frame: NSMakeRect(104, 28, 92, 24))
let criticalRadio = NSButton(title: "Critical", frame: NSMakeRect(204, 28, 92, 24))
var clickCount = 0
var isClickEnabled = true
var isCounterHidden = false
var movedRight = false

titleCheckbox.setButtonType(.switchButton)
titleCheckbox.state = .on
infoRadio.setButtonType(.radioButton)
warningRadio.setButtonType(.radioButton)
criticalRadio.setButtonType(.radioButton)
infoRadio.state = .on

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
        ? NSMakeRect(24, 156, 88, 32)
        : NSMakeRect(24, 204, 88, 32)
    statusLabel.stringValue = movedRight ? "Click button moved down" : "Click button moved back"
}

alertButton.onAction = { _ in
    let alert = NSAlert()
    alert.messageText = "WinChocolate is running"
    alert.informativeText = "This is a native modal NSAlert backed by MessageBoxW."
    if warningRadio.state == .on {
        alert.alertStyle = .warning
    } else if criticalRadio.state == .on {
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
    statusLabel.stringValue = "Alert style: info"
}

warningRadio.onAction = { _ in
    statusLabel.stringValue = "Alert style: warning"
}

criticalRadio.onAction = { _ in
    statusLabel.stringValue = "Alert style: critical"
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
