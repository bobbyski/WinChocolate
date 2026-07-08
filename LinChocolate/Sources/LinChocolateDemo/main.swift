// LinChocolate demo — a small Controls page written against the AppKit-shaped
// API, rendered as native GTK controls on Linux. Same program shape as
// WinChocolate's demo; only the backend line is Linux-specific.
//
// Run it through the Ring 1 harness so the window shows on the Mac via XQuartz:
//   ./run-linux.sh LinChocolateDemo

import LinChocolate
import Foundation

let app = NSApplication.shared
app.nativeBackend = GTKNativeControlBackend()   // native Linux backend (GTK4)

let window = NSWindow(
    contentRect: NSMakeRect(0, 0, 480, 300),
    styleMask: [.titled, .closable, .resizable],
    backing: .buffered,
    defer: false
)
window.title = "LinChocolate Demo"

let contentView = NSView(frame: NSMakeRect(0, 0, 480, 300))

// AppKit uses a bottom-left origin, so larger y sits higher on screen.
let counter  = NSTextField(labelWithString: "Clicks: 0", frame: NSMakeRect(24, 250, 260, 24))
let button   = NSButton(title: "Click me", frame: NSMakeRect(24, 200, 140, 36))
let disable  = NSButton(checkboxWithTitle: "Disable button", frame: NSMakeRect(24, 156, 220, 28))
let field    = NSTextField(string: "type here", frame: NSMakeRect(24, 104, 300, 32))
let echo     = NSTextField(labelWithString: "You typed: ", frame: NSMakeRect(24, 60, 420, 24))

var clicks = 0
button.onAction = { _ in
    clicks += 1
    counter.stringValue = "Clicks: \(clicks)"
}
disable.onAction = { checkbox in
    button.isEnabled = !checkbox.isOn
}
field.onTextChange = { textField in
    echo.stringValue = "You typed: \(textField.stringValue)"
}

for control in [counter, button, disable, field, echo] as [NSView] {
    contentView.addSubview(control)
}
window.contentView = contentView
window.makeKeyAndOrderFront(nil)

app.run()
