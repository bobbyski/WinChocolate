// CounterDemo — the click counter, on whichever framework it was built against.
//
// This file is character-for-character identical in every Chocolate's copy of
// the demo — WinChocolate's `Demo/CounterDemo` and TUIChocolate's
// `Code/Demo/TUICounterDemo` are the same source. That sameness is the claim
// the whole family rests on: one app, five renderers, and the only thing that
// differs is which framework the compiler was pointed at.
//
// The import switch below is the entire integration point. `TUIChocolate` is
// tested first because it is the only arm that can be true *alongside* another
// one: on macOS the real AppKit is always importable, so a terminal build has
// to win explicitly or it would silently link Apple's implementation instead.
// The rest are mutually exclusive by platform.
//
// Every line after it is ordinary AppKit. Nothing here knows about cells, or
// the DOM, or Win32.

#if canImport(TUIChocolate)
import TUIChocolate
#elseif os(WASI)
import WASMChocolate
#elseif os(Linux)
import LinChocolate
#elseif os(Windows)
import WinChocolate
#elseif canImport(AppKit)
import AppKit
#endif

let app = NSApplication.shared

let menuBar = NSMenu()
let fileMenuItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
let fileMenu = NSMenu(title: "File")
let quitItem = NSMenuItem(title: "Quit CounterDemo", action: "terminate:", keyEquivalent: "q")
quitItem.target = app
fileMenu.addItem(quitItem)
fileMenuItem.submenu = fileMenu
menuBar.addItem(fileMenuItem)
app.mainMenu = menuBar

let window = NSWindow(
    contentRect: NSMakeRect(120, 120, 420, 220),
    styleMask: [.titled, .closable, .miniaturizable],
    backing: .buffered,
    defer: false
)
window.title = "Counter Demo"

/// A top-left-origin content view, matching the other demos' convention.
final class ContentView: NSView {
    override var isFlipped: Bool { true }
}
let content = ContentView(frame: NSMakeRect(0, 0, 420, 220))
window.contentView = content

var count = 0

let countLabel = NSTextField(labelWithString: "Count: 0", frame: NSMakeRect(24, 32, 372, 24))
let hintLabel = NSTextField(labelWithString: "Click Increment, or Tab to a button and press Return.",
                            frame: NSMakeRect(24, 64, 372, 24))
for label in [countLabel, hintLabel] {
    content.addSubview(label)
}

let incrementButton = NSButton(title: "Increment", frame: NSMakeRect(24, 120, 140, 32))
incrementButton.onAction = {
    count += 1
    countLabel.stringValue = "Count: \(count)"
}
content.addSubview(incrementButton)

let resetButton = NSButton(title: "Reset", frame: NSMakeRect(180, 120, 140, 32))
resetButton.onAction = {
    count = 0
    countLabel.stringValue = "Count: 0"
}
content.addSubview(resetButton)

window.makeKeyAndOrderFront(nil)
app.run()
