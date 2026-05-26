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
    contentRect: NSMakeRect(100, 100, 480, 320),
    styleMask: [.titled, .closable, .miniaturizable, .resizable],
    backing: .buffered,
    defer: false
)
window.title = "WinChocolate Click Counter"

let contentView = NSView(frame: NSMakeRect(0, 0, 480, 320))
let counterLabel = NSTextField(string: "Clicks: 0", frame: NSMakeRect(24, 240, 260, 24))
let button = NSButton(title: "Click", frame: NSMakeRect(24, 196, 88, 32))
var clickCount = 0

button.onAction = { _ in
    clickCount += 1
    counterLabel.stringValue = "Clicks: \(clickCount)"
}

contentView.addSubview(counterLabel)
contentView.addSubview(button)
window.contentView = contentView
window.makeKeyAndOrderFront(nil)

app.run()
