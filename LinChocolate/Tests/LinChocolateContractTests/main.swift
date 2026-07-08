// LinChocolate contract tests — hermetic, no display.
//
// These run against the in-memory backend and prove the AppKit-shaped API is
// genuinely backend-swappable (validation spike S4): the exact code path a real
// GTK click would take is exercised here through simulated input. Mirrors
// WinChocolate's executable contract-test style; exits non-zero on any failure.

import LinChocolate
import Foundation

var failures = 0
// Top-level `main.swift` code is @MainActor in Swift 6, so `failures` is
// main-actor-isolated; the helper must share that isolation to mutate it.
@MainActor
func check(_ condition: Bool, _ message: String) {
    if condition {
        print("PASS: \(message)")
    } else {
        print("FAIL: \(message)")
        failures += 1
    }
}

// MARK: 1 — Backend contract (in-memory)
do {
    let backend = InMemoryNativeControlBackend()

    let window = backend.createWindow(title: "T", frame: NSMakeRect(0, 0, 100, 50), styleMask: [])
    let button = backend.createButton(title: "B", frame: NSMakeRect(0, 0, 10, 10))
    check(window != button, "distinct handles are allocated")
    check(backend.text(for: button) == "B", "button title is recorded")

    backend.setText("B2", for: button)
    check(backend.text(for: button) == "B2", "setText updates recorded text")

    backend.setEnabled(false, for: button)
    check(backend.isEnabled(button) == false, "setEnabled updates state")

    var fired = false
    backend.registerAction(for: button) { fired = true }
    backend.simulateClick(button)
    check(fired, "registered action fires on simulated click")

    check(backend.isVisible(window) == false, "window starts hidden")
    backend.showWindow(window)
    check(backend.isVisible(window), "showWindow marks the window visible")
}

// MARK: 2 — AppKit-shaped API over the backend (the click-counter, headless)
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 480, 220),
        styleMask: [.titled, .closable],
        backing: .buffered, defer: false
    )
    window.title = "Counter"
    check(backend.titles[window.handle.rawValue] == "Counter", "NSWindow.title reaches the backend")

    let content = NSView(frame: NSMakeRect(0, 0, 480, 220))
    let label = NSTextField(string: "Clicks: 0", frame: NSMakeRect(24, 24, 240, 24))
    let button = NSButton(title: "Click me", frame: NSMakeRect(24, 64, 140, 36))

    var clicks = 0
    button.onAction = { _ in
        clicks += 1
        label.stringValue = "Clicks: \(clicks)"
    }
    content.addSubview(label)
    content.addSubview(button)
    window.contentView = content
    window.makeKeyAndOrderFront(nil)

    check(backend.isVisible(window.handle), "makeKeyAndOrderFront shows the window")
    check(backend.subviews[content.handle.rawValue]?.count == 2, "content view has two subviews")

    // The crux: a native click (simulated) drives onAction through the backend,
    // updating the label — same path GTK's "clicked" signal would take.
    backend.simulateClick(button.handle)
    check(clicks == 1, "NSButton.onAction fires via the backend action")
    check(backend.text(for: label.handle) == "Clicks: 1", "label text updated through the backend")

    backend.simulateClick(button.handle)
    check(backend.text(for: label.handle) == "Clicks: 2", "second click accumulates")
}

if failures == 0 {
    print("\nAll contract tests passed.")
} else {
    print("\n\(failures) contract test(s) FAILED.")
    exit(1)
}
