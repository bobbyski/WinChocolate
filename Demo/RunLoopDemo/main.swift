// RunLoopDemo — exercises the run loop and timers, and proves both share one
// loop: a repeating timer keeps ticking while buttons stay responsive, a nested
// `RunLoop.run(mode:before:)` returns after its window, and `RunLoop.perform`
// runs its block on the next iteration.
//
// Like the main demo this is one source compiled three ways — `import
// WinChocolate` (Win32), `import AppKit` (real AppKit, the faithfulness gate),
// `import LinChocolate` (GTK) — so everything here is plain AppKit/Foundation
// API that means the same thing on each. It is a *separate* app from the frozen
// demo, which is untouched.

#if canImport(LinChocolate)
import LinChocolate
#elseif canImport(WinChocolate)
import WinChocolate
#elseif canImport(AppKit)
import AppKit
#endif

let app = NSApplication.shared
#if canImport(LinChocolate)
app.nativeBackend = GTKNativeControlBackend()
NSView.defaultIsFlipped = true
#endif

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
    contentRect: NSMakeRect(120, 120, 560, 320),
    styleMask: [.titled, .closable, .miniaturizable],
    backing: .buffered,
    defer: false
)
window.title = "RunLoop Demo"

/// A top-left-origin content view, matching the frozen demo's convention so the
/// explicit frames below read the same on Win32 and AppKit.
final class ContentView: NSView {
    override var isFlipped: Bool { true }
}
let content = ContentView(frame: NSMakeRect(0, 0, 560, 320))
window.contentView = content

/// A left-aligned label at an explicit frame, built from the real AppKit
/// `labelWithString:` initializer so it means the same on every target.
@MainActor
func makeLabel(_ text: String, _ frame: NSRect) -> NSTextField {
    let label = NSTextField(labelWithString: text)
    label.frame = frame
    content.addSubview(label)
    return label
}

let ticksLabel = makeLabel("Ticks: 0", NSMakeRect(24, 24, 280, 24))
let bumpsLabel = makeLabel("Bumps: 0", NSMakeRect(24, 56, 280, 24))
let nestedLabel = makeLabel("Nested run: (not run yet)", NSMakeRect(24, 88, 512, 24))
let performLabel = makeLabel("Perform: (not run yet)", NSMakeRect(24, 120, 512, 24))
_ = makeLabel("The tick count must keep rising while you click — one loop, both jobs.",
              NSMakeRect(24, 152, 512, 24))

var ticks = 0
var bumps = 0

/// A closure wired through a control's REAL `target`/`action`. On AppKit the
/// ObjC runtime dispatches the selector; on WinChocolate/LinChocolate the
/// framework sends it through `perform(_:with:)`, which this overrides by name
/// — the same dispatch surface without an ObjC runtime. (The frozen demo's
/// `DemoConveniences` does this too; kept inline here so the demo stands alone.)
final class ActionTarget: NSObject {
    let handler: @MainActor () -> Void
    init(_ handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init()
    }

    #if canImport(AppKit) && !canImport(WinChocolate) && !canImport(LinChocolate)
    @objc func fire(_ sender: Any?) {
        nonisolated(unsafe) let block = handler
        MainActor.assumeIsolated { block() }
    }
    static let selector = #selector(ActionTarget.fire(_:))
    #else
    override func responds(to aSelector: Selector?) -> Bool {
        aSelector?.name == "fire:" || super.responds(to: aSelector)
    }

    @discardableResult
    override func perform(_ aSelector: Selector, with object: Any?) -> Any? {
        guard aSelector.name == "fire:" else {
            return super.perform(aSelector, with: object)
        }
        // Actions arrive on the UI thread; the unsafe copy hops the @MainActor
        // handler across the nonisolated override, as the frozen demo does.
        nonisolated(unsafe) let block = handler
        MainActor.assumeIsolated { block() }
        return nil
    }
    static let selector = Selector("fire:")
    #endif
}

// Targets are held weakly by controls, so keep them alive here.
var actionTargets: [ActionTarget] = []

/// A button at an explicit frame whose click runs `handler`, through real
/// target/action.
@MainActor
func makeButton(_ title: String, _ frame: NSRect, _ handler: @escaping @MainActor () -> Void) -> NSButton {
    let target = ActionTarget(handler)
    actionTargets.append(target)
    let button = NSButton(title: title, target: target, action: ActionTarget.selector)
    button.frame = frame
    content.addSubview(button)
    return button
}

_ = makeButton("Bump", NSMakeRect(24, 200, 120, 32)) {
    // A button click — proves input is serviced while the timer ticks.
    bumps += 1
    bumpsLabel.stringValue = "Bumps: \(bumps)"
}
_ = makeButton("Run nested 2s", NSMakeRect(156, 200, 160, 32)) {
    // Enter a nested run loop for two seconds and report how many timer ticks
    // landed during it — proof the loop keeps running when re-entered.
    let before = ticks
    nestedLabel.stringValue = "Nested run: running for 2s…"
    _ = RunLoop.main.run(mode: .default, before: Date(timeIntervalSinceNow: 2))
    nestedLabel.stringValue = "Nested run: returned; \(ticks - before) ticks fired during it"
}
_ = makeButton("Perform", NSMakeRect(328, 200, 120, 32)) {
    // Enqueue a block for the next loop iteration.
    performLabel.stringValue = "Perform: queued…"
    RunLoop.main.perform {
        performLabel.stringValue = "Perform: block ran on the next iteration"
    }
}

// The repeating timer that must keep ticking regardless of what the loop is
// doing. `Timer.scheduledTimer` adds it to the current run loop.
let ticker = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
    ticks += 1
    ticksLabel.stringValue = "Ticks: \(ticks)"
}
_ = ticker

window.makeKeyAndOrderFront(nil)
app.run()
