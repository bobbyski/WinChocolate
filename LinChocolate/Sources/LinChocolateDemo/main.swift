// LinChocolate demo — a tabbed Controls app written against the AppKit-shaped
// API, rendered as native GTK controls on Linux. Mirrors the WinChocolate
// demo's paged structure; only the backend line is Linux-specific.
//
// Run it through the Ring 1 harness so the window shows on the Mac via XQuartz:
//   ./run-linux.sh LinChocolateDemo

import LinChocolate
import Foundation

let app = NSApplication.shared
app.nativeBackend = GTKNativeControlBackend()   // native Linux backend (GTK4)

let pageWidth = 540.0, pageHeight = 540.0

/// Top-down row stacker over AppKit's bottom-left coordinates: each call
/// reserves a row of the given height below the previous one and returns its y.
struct Rows {
    var cursor: Double
    init(top: Double) { cursor = top }
    mutating func next(_ rowHeight: Double, gap: Double = 14) -> Double {
        cursor -= rowHeight
        defer { cursor -= gap }
        return cursor
    }
}

let window = NSWindow(
    contentRect: NSMakeRect(0, 0, pageWidth, pageHeight + 60),
    styleMask: [.titled, .closable, .resizable],
    backing: .buffered,
    defer: false
)
window.title = "LinChocolate Controls"

// MARK: - Page 1 · Basics
let basics = NSView(frame: NSMakeRect(0, 0, pageWidth, pageHeight))
var r1 = Rows(top: pageHeight - 16)

let counter = NSTextField(labelWithString: "Clicks: 0", frame: NSMakeRect(24, r1.next(24), 300, 24))
let button  = NSButton(title: "Click me", frame: NSMakeRect(24, r1.next(36), 140, 36))
let disable = NSButton(checkboxWithTitle: "Disable button", frame: NSMakeRect(24, r1.next(28), 220, 28))

let sizeY = r1.next(24)
let sizeLabel  = NSTextField(labelWithString: "Choose a size:", frame: NSMakeRect(24, sizeY, 200, 24))
let sizeResult = NSTextField(labelWithString: "Size: —", frame: NSMakeRect(260, sizeY, 250, 24))
let small  = NSButton(radioWithTitle: "Small",  frame: NSMakeRect(40, r1.next(26), 120, 26))
let medium = NSButton(radioWithTitle: "Medium", frame: NSMakeRect(40, r1.next(26), 120, 26))
let large  = NSButton(radioWithTitle: "Large",  frame: NSMakeRect(40, r1.next(26), 120, 26))

let searchY = r1.next(32)
let searchLabel = NSTextField(labelWithString: "Search:", frame: NSMakeRect(24, searchY + 4, 90, 24))
let search = NSSearchField(string: "", frame: NSMakeRect(120, searchY, 290, 32))

let comboY = r1.next(34)
let comboLabel = NSTextField(labelWithString: "Fruit:", frame: NSMakeRect(24, comboY + 4, 90, 24))
let combo = NSComboBox(items: ["Apple", "Banana", "Cherry"], frame: NSMakeRect(120, comboY, 200, 34))

let passwordY = r1.next(32)
let passwordLabel = NSTextField(labelWithString: "Password:", frame: NSMakeRect(24, passwordY + 4, 90, 24))
let password = NSSecureTextField(string: "", frame: NSMakeRect(120, passwordY, 290, 32))

let echo = NSTextField(labelWithString: "Last edit: —", frame: NSMakeRect(24, r1.next(24), 486, 24))

for control in [counter, button, disable, sizeLabel, sizeResult, small, medium, large,
                searchLabel, search, comboLabel, combo, passwordLabel, password, echo] as [NSView] {
    basics.addSubview(control)
}

// MARK: - Page 2 · Values
let values = NSView(frame: NSMakeRect(0, 0, pageWidth, pageHeight))
var r2 = Rows(top: pageHeight - 16)

let volumeY = r2.next(30)
let volumeLabel = NSTextField(labelWithString: "Volume:", frame: NSMakeRect(24, volumeY + 3, 90, 24))
let slider = NSSlider(value: 30, minValue: 0, maxValue: 100, frame: NSMakeRect(120, volumeY, 300, 30))
let volumeValue = NSTextField(labelWithString: "30", frame: NSMakeRect(430, volumeY + 3, 80, 24))
let progress = NSProgressIndicator(value: 30, minValue: 0, maxValue: 100, frame: NSMakeRect(24, r2.next(20), 486, 20))

let stepperY = r2.next(34)
let stepperLabel = NSTextField(labelWithString: "Quantity:", frame: NSMakeRect(24, stepperY + 4, 90, 24))
let stepper = NSStepper(value: 1, minValue: 0, maxValue: 10, increment: 1, frame: NSMakeRect(120, stepperY, 120, 34))
let stepperResult = NSTextField(labelWithString: "Qty: 1", frame: NSMakeRect(260, stepperY + 4, 200, 24))

let levelY = r2.next(24)
let levelLabel = NSTextField(labelWithString: "Level:", frame: NSMakeRect(24, levelY, 90, 24))
let level = NSLevelIndicator(value: 6, minValue: 0, maxValue: 10, frame: NSMakeRect(120, levelY, 300, 22))

for control in [volumeLabel, slider, volumeValue, progress,
                stepperLabel, stepper, stepperResult, levelLabel, level] as [NSView] {
    values.addSubview(control)
}

// MARK: - Page 3 · Pickers
let pickers = NSView(frame: NSMakeRect(0, 0, pageWidth, pageHeight))
var r3 = Rows(top: pageHeight - 16)

let themeY = r3.next(34)
let themeLabel = NSTextField(labelWithString: "Theme:", frame: NSMakeRect(24, themeY + 4, 90, 24))
let theme = NSPopUpButton(items: ["System", "Light", "Dark"], frame: NSMakeRect(120, themeY, 180, 34))
let themeResult = NSTextField(labelWithString: "Theme: System", frame: NSMakeRect(320, themeY + 4, 200, 24))

let colorY = r3.next(34)
let colorLabel = NSTextField(labelWithString: "Color:", frame: NSMakeRect(24, colorY + 4, 90, 24))
let colorWell = NSColorWell(color: .orange, frame: NSMakeRect(120, colorY, 60, 34))
let colorResult = NSTextField(labelWithString: "Color: orange-ish", frame: NSMakeRect(200, colorY + 4, 280, 24))

let dateLabel = NSTextField(labelWithString: "Date:", frame: NSMakeRect(24, r3.next(24), 90, 24))
let datePicker = NSDatePicker(frame: NSMakeRect(24, r3.next(230), 320, 230))
let dateResult = NSTextField(labelWithString: "Picked: —", frame: NSMakeRect(24, r3.next(24), 486, 24))

for control in [themeLabel, theme, themeResult, colorLabel, colorWell, colorResult,
                dateLabel, datePicker, dateResult] as [NSView] {
    pickers.addSubview(control)
}

// MARK: - Page 4 · Text
let textPage = NSView(frame: NSMakeRect(0, 0, pageWidth, pageHeight))
var r4 = Rows(top: pageHeight - 16)

let notesLabel = NSTextField(labelWithString: "Notes:", frame: NSMakeRect(24, r4.next(24), 200, 24))
let notes = NSTextView(string: "Type multi-line notes here…", frame: NSMakeRect(24, r4.next(160), 486, 160))
let notesEdit = NSTextField(labelWithString: "Last edit: —", frame: NSMakeRect(24, r4.next(24), 486, 24))

for control in [notesLabel, notes, notesEdit] as [NSView] {
    textPage.addSubview(control)
}

// MARK: - Tab view assembly
let tabView = NSTabView(frame: NSMakeRect(0, 0, pageWidth, pageHeight + 60))
for (label, page) in [("Basics", basics), ("Values", values), ("Pickers", pickers), ("Text", textPage)] {
    let item = NSTabViewItem()
    item.label = label
    item.view = page
    tabView.addTabViewItem(item)
}

// MARK: - Wiring: every control drives something visible
var clicks = 0
button.onAction = { _ in clicks += 1; counter.stringValue = "Clicks: \(clicks)" }
disable.onAction = { button.isEnabled = !$0.isOn }
NSButton.group([small, medium, large])
for radio in [small, medium, large] { radio.onAction = { sizeResult.stringValue = "Size: \($0.title)" } }
search.onTextChange = { echo.stringValue = "Search: \($0.stringValue)" }
combo.onTextChange = { echo.stringValue = "Fruit: \($0.stringValue)" }
password.onTextChange = { echo.stringValue = "Password length: \($0.stringValue.count)" }

slider.onValueChange = { s in
    progress.doubleValue = s.doubleValue
    volumeValue.stringValue = "\(Int(s.doubleValue))"
}
stepper.onValueChange = { s in
    stepperResult.stringValue = "Qty: \(Int(s.doubleValue))"
    level.doubleValue = s.doubleValue          // the stepper drives the level gauge
}

theme.onSelectionChange = { themeResult.stringValue = "Theme: \($0.titleOfSelectedItem ?? "—")" }
colorWell.onColorChange = { well in
    let c = well.color
    colorResult.stringValue = String(format: "Color: %.2f, %.2f, %.2f", c.redComponent, c.greenComponent, c.blueComponent)
}
let dateFormatter = DateFormatter()
dateFormatter.dateStyle = .medium
datePicker.onDateChange = { dateResult.stringValue = "Picked: \(dateFormatter.string(from: $0.dateValue))" }

notes.onTextChange = { notesEdit.stringValue = "Last edit: \($0.string.count) chars" }

window.contentView = tabView
window.makeKeyAndOrderFront(nil)

app.run()
