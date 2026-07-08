// LinChocolate demo — the click-counter, written against the AppKit-shaped API,
// rendered as native GTK controls on Linux. This is the same program shape as
// WinChocolate's README example; only the backend line is Linux-specific.
//
// Run it through the Ring 1 harness so the window shows on the Mac via XQuartz:
//   ./run-linux.sh LinChocolateDemo

import LinChocolate
import Foundation

let app = NSApplication.shared
app.nativeBackend = GTKNativeControlBackend()   // native Linux backend (GTK4)

let window = NSWindow(
    contentRect: NSMakeRect(0, 0, 480, 220),
    styleMask: [.titled, .closable, .resizable],
    backing: .buffered,
    defer: false
)
window.title = "LinChocolate Demo"

let contentView = NSView(frame: NSMakeRect(0, 0, 480, 220))
let label = NSTextField(string: "Clicks: 0", frame: NSMakeRect(24, 24, 240, 24))
let button = NSButton(title: "Click me", frame: NSMakeRect(24, 64, 140, 36))

var clicks = 0
button.onAction = { _ in
    clicks += 1
    label.stringValue = "Clicks: \(clicks)"
}

contentView.addSubview(label)
contentView.addSubview(button)
window.contentView = contentView
window.makeKeyAndOrderFront(nil)

app.run()
