# WinChocolate

WinChocolate is an AppKit-shaped Swift framework for Windows. The goal is to let simple Cocoa/AppKit-style Swift apps move toward Windows by replacing:

```swift
import Cocoa
```

or:

```swift
import AppKit
```

with:

```swift
import WinChocolate
```

The public API intentionally uses familiar Apple names such as `NSApplication`, `NSWindow`, `NSView`, `NSButton`, `NSTextField`, `NSMenu`, `NSMenuItem`, and `NSAlert`, while the implementation wraps native Windows controls.

## Status

WinChocolate is early and intentionally incomplete. The current milestone proves the basic native loop:

- `NSApplication` lifecycle
- Top-level native window
- Menu bar with Quit item
- Native buttons
- Native checkboxes through switch-style `NSButton`
- Native radio buttons through radio-style `NSButton`
- Static and editable `NSTextField`
- Native text, frame, hidden, and enabled updates
- Native modal `NSAlert` through `MessageBoxW`
- SwiftPM demo app with a click counter and editable text field

The Win32 backend currently uses a narrow manual User32/Gdi32 FFI layer because this local ARM64 Swift toolchain cannot import `WinSDK` cleanly.

## Build And Run

From this directory:

```bat
buildandrun.bat
```

The script builds the Swift package, runs the contract tests, checks native demo window creation, and launches the demo app.

## Package Layout

```text
Package.swift
Sources/WinChocolate
Tests/WinChocolateContractTests
Demo/DemoApplication
Docs/Architecture.md
NEEDS_HUMAN.md
```

## Example

```swift
import WinChocolate

let app = NSApplication.shared

let window = NSWindow(
    contentRect: NSMakeRect(100, 100, 480, 320),
    styleMask: [.titled, .closable, .miniaturizable, .resizable],
    backing: .buffered,
    defer: false
)
window.title = "Hello WinChocolate"

let contentView = NSView(frame: NSMakeRect(0, 0, 480, 320))
let label = NSTextField(string: "Clicks: 0", frame: NSMakeRect(24, 240, 200, 24))
let button = NSButton(title: "Click", frame: NSMakeRect(24, 196, 88, 32))

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
```

## License

MIT. See [LICENSE](LICENSE).
