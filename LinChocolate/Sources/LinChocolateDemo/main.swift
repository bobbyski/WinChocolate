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

let width = 540.0, height = 760.0
let window = NSWindow(
    contentRect: NSMakeRect(0, 0, width, height),
    styleMask: [.titled, .closable, .resizable],
    backing: .buffered,
    defer: false
)
window.title = "LinChocolate Controls"
let content = NSView(frame: NSMakeRect(0, 0, width, height))

// Top-down row stacker over AppKit's bottom-left coordinates: each call reserves
// a row of the given height below the previous one and returns its y.
// @MainActor because top-level `main.swift` state is main-actor-isolated in Swift 6.
var cursor = height - 20
@MainActor func row(_ rowHeight: Double) -> Double { cursor -= rowHeight; defer { cursor -= 14 }; return cursor }

let counter = NSTextField(labelWithString: "Clicks: 0", frame: NSMakeRect(24, row(24), 300, 24))
let button  = NSButton(title: "Click me", frame: NSMakeRect(24, row(36), 140, 36))
let disable = NSButton(checkboxWithTitle: "Disable button", frame: NSMakeRect(24, row(28), 220, 28))

let sizeY = row(24)
let sizeLabel  = NSTextField(labelWithString: "Choose a size:", frame: NSMakeRect(24, sizeY, 200, 24))
let sizeResult = NSTextField(labelWithString: "Size: —", frame: NSMakeRect(260, sizeY, 250, 24))
let small  = NSButton(radioWithTitle: "Small",  frame: NSMakeRect(40, row(26), 120, 26))
let medium = NSButton(radioWithTitle: "Medium", frame: NSMakeRect(40, row(26), 120, 26))
let large  = NSButton(radioWithTitle: "Large",  frame: NSMakeRect(40, row(26), 120, 26))

let volumeY = row(30)
let volumeLabel = NSTextField(labelWithString: "Volume:", frame: NSMakeRect(24, volumeY + 3, 90, 24))
let slider = NSSlider(value: 30, minValue: 0, maxValue: 100, frame: NSMakeRect(120, volumeY, 300, 30))
let volumeValue = NSTextField(labelWithString: "30", frame: NSMakeRect(430, volumeY + 3, 80, 24))
let progress = NSProgressIndicator(value: 30, minValue: 0, maxValue: 100, frame: NSMakeRect(24, row(20), 486, 20))

let themeY = row(34)
let themeLabel = NSTextField(labelWithString: "Theme:", frame: NSMakeRect(24, themeY + 4, 90, 24))
let theme = NSPopUpButton(items: ["System", "Light", "Dark"], frame: NSMakeRect(120, themeY, 180, 34))
let themeResult = NSTextField(labelWithString: "Theme: System", frame: NSMakeRect(320, themeY + 4, 200, 24))

let searchY = row(32)
let searchLabel = NSTextField(labelWithString: "Search:", frame: NSMakeRect(24, searchY + 4, 90, 24))
let search = NSSearchField(string: "", frame: NSMakeRect(120, searchY, 290, 32))

let comboY = row(34)
let comboLabel = NSTextField(labelWithString: "Fruit:", frame: NSMakeRect(24, comboY + 4, 90, 24))
let combo = NSComboBox(items: ["Apple", "Banana", "Cherry"], frame: NSMakeRect(120, comboY, 200, 34))

let passwordY = row(32)
let passwordLabel = NSTextField(labelWithString: "Password:", frame: NSMakeRect(24, passwordY + 4, 90, 24))
let password = NSSecureTextField(string: "", frame: NSMakeRect(120, passwordY, 290, 32))

let echo = NSTextField(labelWithString: "Last edit: —", frame: NSMakeRect(24, row(24), 486, 24))

// --- Wiring: every control drives something visible ---
var clicks = 0
button.onAction = { _ in clicks += 1; counter.stringValue = "Clicks: \(clicks)" }
disable.onAction = { button.isEnabled = !$0.isOn }
NSButton.group([small, medium, large])
for radio in [small, medium, large] { radio.onAction = { sizeResult.stringValue = "Size: \($0.title)" } }
slider.onValueChange = { s in
    progress.doubleValue = s.doubleValue
    volumeValue.stringValue = "\(Int(s.doubleValue))"
}
theme.onSelectionChange = { themeResult.stringValue = "Theme: \($0.titleOfSelectedItem ?? "—")" }
search.onTextChange = { echo.stringValue = "Search: \($0.stringValue)" }
combo.onTextChange = { echo.stringValue = "Fruit: \($0.stringValue)" }
password.onTextChange = { echo.stringValue = "Password length: \($0.stringValue.count)" }

for control in [
    counter, button, disable,
    sizeLabel, sizeResult, small, medium, large,
    volumeLabel, slider, volumeValue, progress,
    themeLabel, theme, themeResult,
    searchLabel, search,
    comboLabel, combo,
    passwordLabel, password,
    echo
] as [NSView] {
    content.addSubview(control)
}
window.contentView = content
window.makeKeyAndOrderFront(nil)

app.run()
