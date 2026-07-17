// RunLoopDemo — exercises the run loop and its timers, and proves both share
// one loop: a repeating Timer keeps ticking while buttons stay responsive, a
// nested `RunLoop.main.run(mode:before:)` returns after its window, and
// `RunLoop.main.perform` runs its block on the next iteration.
//
// This is an AppKit-compatibility proof: the SAME source builds against real
// Apple AppKit/Foundation and against WinChocolate/LinChocolate. The only `#if`
// here is the framework-import switch below; every other line runs once and
// means the same on each target. The demo-local `onAction` sugar (a closure over
// a control's REAL target/action) lives in RunLoopDemoConveniences.swift and is
// AppKit-compatible. The frozen demo is untouched.

#if canImport(LinChocolate)
import LinChocolate
#elseif canImport(WinChocolate)
import WinChocolate
#elseif canImport(AppKit)
import AppKit
#endif

let app = NSApplication.shared

let menuBar = NSMenu()
let appMenuItem = NSMenuItem(title: "RunLoopDemo", action: nil, keyEquivalent: "")
let appMenu = NSMenu(title: "RunLoopDemo")
let quitItem = NSMenuItem(title: "Quit RunLoopDemo", action: "terminate:", keyEquivalent: "q")
quitItem.target = app
appMenu.addItem(quitItem)
appMenuItem.submenu = appMenu
menuBar.addItem(appMenuItem)
app.mainMenu = menuBar

let window = NSWindow(
    contentRect: NSMakeRect(120, 120, 560, 300),
    styleMask: [.titled, .closable, .miniaturizable],
    backing: .buffered,
    defer: false
)
window.title = "RunLoop Demo"

/// A top-left-origin content view, matching the frozen demo's convention so the
/// explicit frames below read the same on every target.
final class ContentView: NSView {
    override var isFlipped: Bool { true }
}
let content = ContentView(frame: NSMakeRect(0, 0, 560, 300))
window.contentView = content

let ticksLabel = NSTextField(labelWithString: "Ticks: 0", frame: NSMakeRect(24, 24, 512, 24))
let bumpsLabel = NSTextField(labelWithString: "Bumps: 0", frame: NSMakeRect(24, 56, 512, 24))
let nestedLabel = NSTextField(labelWithString: "Nested run: (not run yet)", frame: NSMakeRect(24, 88, 512, 24))
let performLabel = NSTextField(labelWithString: "Perform: (not run yet)", frame: NSMakeRect(24, 120, 512, 24))
let hintLabel = NSTextField(labelWithString: "The tick count must keep rising while you click — one loop, both jobs.",
                            frame: NSMakeRect(24, 156, 512, 24))
for label in [ticksLabel, bumpsLabel, nestedLabel, performLabel, hintLabel] {
    content.addSubview(label)
}

var ticks = 0
var bumps = 0

let bumpButton = NSButton(title: "Bump", frame: NSMakeRect(24, 200, 120, 32))
bumpButton.onAction = {
    // A button click — proves input is serviced while the timer ticks.
    bumps += 1
    bumpsLabel.stringValue = "Bumps: \(bumps)"
}
content.addSubview(bumpButton)

let nestedButton = NSButton(title: "Run nested 2s", frame: NSMakeRect(156, 200, 160, 32))
nestedButton.onAction = {
    // Enter a nested run loop for two seconds and report how many timer ticks
    // landed during it — proof the loop keeps running when re-entered.
    let before = ticks
    nestedLabel.stringValue = "Nested run: running for 2s…"
    _ = RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 2))
    nestedLabel.stringValue = "Nested run: returned; \(ticks - before) ticks fired during it"
}
content.addSubview(nestedButton)

let performButton = NSButton(title: "Perform", frame: NSMakeRect(328, 200, 120, 32))
performButton.onAction = {
    // Enqueue a block for the next loop iteration.
    performLabel.stringValue = "Perform: queued…"
    RunLoop.main.perform {
        performLabel.stringValue = "Perform: block ran on the next iteration"
    }
}
content.addSubview(performButton)

// The repeating timer that must keep ticking regardless of what the loop is
// doing. `Timer.scheduledTimer`'s block form is a plain Swift closure.
let ticker = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
    ticks += 1
    ticksLabel.stringValue = "Ticks: \(ticks)"
}
_ = ticker

window.makeKeyAndOrderFront(nil)
app.run()
