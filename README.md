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
- Application window list plus key/main window tracking
- Menu bar with Quit item
- Native buttons
- Native checkboxes through switch-style `NSButton`
- Native radio buttons through radio-style `NSButton`
- Static and editable `NSTextField`
- Secure text entry through `NSSecureTextField`
- Multiline `NSTextView`
- Editable `NSComboBox`
- Initial `NSSearchField`, `NSTokenField`, `NSForm`, `NSPathControl`, `NSLevelIndicator`, and `NSColorWell`
- Initial composed `NSSegmentedControl`
- Initial bitmap-backed `NSImageView` with scaling/alignment state and `NSTabView`
- `NSSlider`, `NSProgressIndicator`, and `NSStepper` value controls
- Initial standalone `NSScroller`
- Initial `NSDatePicker`
- Initial `NSSplitView` pane layout and programmatic divider positioning
- First `NSClipView`, `NSScrollView`, `NSTableColumn`, `NSTableView`, table cell/view, row/column selection, action/double-action, and sort-descriptor compatibility slice
- Native text, frame, hidden, and enabled updates
- Native modal `NSAlert` through `MessageBoxW`
- Initial `NSColor` support for view backgrounds and text field text color
- Initial `NSFont` support for text field fonts
- Initial `NSResponder` chain support for windows and views
- Initial `NSWindow.firstResponder` and `makeFirstResponder(_:)` support
- Initial `NSView.nextKeyView` and `NSWindow.selectNextKeyView(_:)` support
- Initial `NSApp`, `NSApplication.keyWindow`, and `NSApplication.mainWindow` support
- Native mouse-down/up/move dispatch into `NSView` responder methods
- Native key-down/up dispatch with key code, basic characters, and modifier flags
- Experimental editable text-field Tab interception for key-view traversal
- SwiftPM demo app with a click counter, editable/secure/combo/token text, path display, multiline notes, tabs, segmented controls, bitmap image tests, clip-view scrolling, split view panes, value controls, a standalone scroller, and a larger table-selection/action exercise

The Win32 backend currently uses a narrow manual User32/Gdi32 FFI layer because this local ARM64 Swift toolchain cannot import `WinSDK` cleanly.

Foundation is the intended default for Foundation-shaped API. The current local Windows ARM64 toolchain cannot compile `import Foundation`, so Windows builds define `USE_WIN_FOUNDATION` and use the small repo-local `WinFoundation` target as a temporary bridge. Pass `-Xswiftc -DUSE_REAL_FOUNDATION` to force real Foundation when testing a newer toolchain.

`WinFoundation.URL` is the first compatibility priority because file URLs will underpin `NSPathControl`, open/save panels, resource lookup, image loading, and document APIs. The bridge should stay small and source-compatible, with real Foundation kept as the default path whenever the toolchain supports it.

See [FOUNDATION_SHIMS.md](FOUNDATION_SHIMS.md) for the active shim surface, maintenance rules, and the canary commands for deciding when a newer Swift/Foundation release makes the shim unnecessary.

The current visual style is the classic Win32 look on purpose. That should remain available for apps that want a retro or very small native-tool feel. The roadmap now tracks a separate modern Windows appearance layer as the eventual default, with backend or appearance selection so app code can keep the same AppKit-shaped API.

The table plan is Mac-first: application code should use AppKit-shaped `NSTableView`, `NSTableColumn`, data source, delegate, sort descriptors, cell/view helpers, and `NSScrollView.documentView` patterns. The current classic backend renderer is temporary and deliberately hidden behind the same native backend boundary as the other controls.

The layout plan is also Mac-first. Early demos use manual frames, but the roadmap includes AppKit-style Auto Layout support later: `NSLayoutConstraint`, layout anchors, intrinsic content size, priorities, hugging, compression resistance, and `translatesAutoresizingMaskIntoConstraints`.

## Build And Run

From this directory:

```bat
buildandrun.bat
```

The script builds the Swift package, runs the contract tests, checks native demo window creation, and launches the demo app.

## Package Layout

```text
Package.swift
Sources/WinFoundation
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
