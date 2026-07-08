// LinChocolate demo — a Controls page written against the AppKit-shaped API,
// rendered as native GTK controls on Linux. Same program shape as WinChocolate's
// demo; only the backend line is Linux-specific.
//
// Run it through the Ring 1 harness so the window shows on the Mac via XQuartz:
//   ./run-linux.sh LinChocolateDemo

import LinChocolate
import Foundation

let app = NSApplication.shared
app.nativeBackend = GTKNativeControlBackend()   // native Linux backend (GTK4)

let window = NSWindow(
    contentRect: NSMakeRect(0, 0, 520, 620),
    styleMask: [.titled, .closable, .resizable],
    backing: .buffered,
    defer: false
)
window.title = "LinChocolate Controls"

let content = NSView(frame: NSMakeRect(0, 0, 520, 620))

// AppKit uses a bottom-left origin, so larger y sits higher on screen.
let counter = NSTextField(labelWithString: "Clicks: 0", frame: NSMakeRect(24, 580, 260, 24))
let button  = NSButton(title: "Click me", frame: NSMakeRect(24, 532, 140, 36))
let disable = NSButton(checkboxWithTitle: "Disable button", frame: NSMakeRect(24, 492, 220, 28))

let sizeLabel  = NSTextField(labelWithString: "Choose a size:", frame: NSMakeRect(24, 452, 200, 22))
let small  = NSButton(radioWithTitle: "Small",  frame: NSMakeRect(40, 424, 120, 26))
let medium = NSButton(radioWithTitle: "Medium", frame: NSMakeRect(40, 396, 120, 26))
let large  = NSButton(radioWithTitle: "Large",  frame: NSMakeRect(40, 368, 120, 26))
let sizeResult = NSTextField(labelWithString: "Size: —", frame: NSMakeRect(200, 396, 280, 24))

let volumeLabel = NSTextField(labelWithString: "Volume:", frame: NSMakeRect(24, 330, 120, 22))
let slider = NSSlider(value: 30, minValue: 0, maxValue: 100, frame: NSMakeRect(24, 300, 320, 30))
let volumeValue = NSTextField(labelWithString: "30", frame: NSMakeRect(356, 300, 120, 24))
let progress = NSProgressIndicator(value: 30, minValue: 0, maxValue: 100, frame: NSMakeRect(24, 262, 452, 20))

let themeLabel = NSTextField(labelWithString: "Theme:", frame: NSMakeRect(24, 220, 120, 22))
let theme = NSPopUpButton(items: ["System", "Light", "Dark"], frame: NSMakeRect(24, 186, 200, 34))
let themeResult = NSTextField(labelWithString: "Theme: System", frame: NSMakeRect(240, 192, 240, 24))

let field = NSTextField(string: "type here", frame: NSMakeRect(24, 132, 320, 32))
let echo  = NSTextField(labelWithString: "You typed: ", frame: NSMakeRect(24, 92, 460, 24))

// --- Wiring: every control drives something visible ---
var clicks = 0
button.onAction = { _ in
    clicks += 1
    counter.stringValue = "Clicks: \(clicks)"
}
disable.onAction = { checkbox in
    button.isEnabled = !checkbox.isOn
}
NSButton.group([small, medium, large])
for radio in [small, medium, large] {
    radio.onAction = { sizeResult.stringValue = "Size: \($0.title)" }
}
slider.onValueChange = { s in
    progress.doubleValue = s.doubleValue
    volumeValue.stringValue = "\(Int(s.doubleValue))"
}
theme.onSelectionChange = { popup in
    themeResult.stringValue = "Theme: \(popup.titleOfSelectedItem ?? "—")"
}
field.onTextChange = { textField in
    echo.stringValue = "You typed: \(textField.stringValue)"
}

for control in [
    counter, button, disable,
    sizeLabel, small, medium, large, sizeResult,
    volumeLabel, slider, volumeValue, progress,
    themeLabel, theme, themeResult,
    field, echo
] as [NSView] {
    content.addSubview(control)
}
window.contentView = content
window.makeKeyAndOrderFront(nil)

app.run()
