# ChocolateKit / WinChocolate

ChocolateKit is one AppKit-compatible Swift framework with native Win32 and
GTK4 backends. `WinChocolate` and `LinChocolate` are thin platform-facing
module names over the same shared implementation.

The goal is to let simple Cocoa/AppKit Swift apps move toward Windows or Linux
by replacing:

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

## The Rule (set in stone)

> **We are implementing the Apple API, not creating something similar.**

Apple's implementation is the specification, and the demo's macOS build against real AppKit is the ground truth. Any divergence from it is a backend bug. The framework must match Apple's API exactly — including **defaults** — and must **never substitute or combine controls on the app's behalf**. Where a platform has no native equivalent, implement the Apple control as a **custom compound control** built from the primitives that do exist, exposing the **exact Apple API**. It may look like a Windows or Linux app; it must still *be* the Apple control.

See [CONTROL_PARITY.md](CONTROL_PARITY.md#the-rule-set-in-stone) for the full rule, the obligations it implies, and the `NSDatePicker` case that established it.

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
- Initial `NSSearchField`, `NSTokenField`, `NSForm`, `NSMatrix`, `NSPathControl`, `NSLevelIndicator`, and `NSColorWell`
- Initial composed `NSSegmentedControl`
- Initial bitmap-backed `NSImageView` with scaling/alignment state and `NSTabView`
- `NSSlider`, `NSProgressIndicator`, and `NSStepper` value controls
- Initial standalone `NSScroller`
- Initial `NSDatePicker`
- Initial `NSSplitView` pane layout and programmatic divider positioning
- Initial `NSVisualEffectView` material/blending/state surface with a classic fallback background
- First `NSPanel` subclass slice with common panel flags
- First `NSPopover` slice hosted by a menu-less borderless panel
- First `NSToolbar` / `NSToolbarItem` model slice docked through `NSWindow.toolbar` with classic `ToolbarWindow32` rendering
- First `NSClipView`, `NSScrollView`, `NSTableColumn`, `NSTableView`, `NSOutlineView`, `NSBrowser`, `NSCollectionView`, table cell/view, row/column selection, action/double-action, and sort-descriptor compatibility slice
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
- Tab-order/focus visibility is now tracked as a dedicated late-stage deep dive instead of an ad hoc smoke test
- SwiftPM demo app with a click counter, editable/secure/combo/token text, path display, multiline notes, tabs, segmented controls, bitmap image tests, clip-view scrolling, split view panes, value controls, a standalone scroller, and larger table/outline/collection selection exercises

The Win32 backend currently uses a narrow manual User32/Gdi32 FFI layer because
the ARM64 Swift toolchain used during its development could not import `WinSDK`
cleanly. The same sources are retained for x64 and ARM64 Windows builds.

Foundation is the intended default for Foundation-shaped API. The current local Windows ARM64 toolchain cannot compile `import Foundation`, so Windows builds define `USE_WIN_FOUNDATION` and use the small repo-local `WinFoundation` target as a temporary bridge. Pass `-Xswiftc -DUSE_REAL_FOUNDATION` to force real Foundation when testing a newer toolchain.

`WinFoundation.URL` is the first compatibility priority because file URLs will underpin `NSPathControl`, open/save panels, resource lookup, image loading, and document APIs. The bridge should stay small and source-compatible, with real Foundation kept as the default path whenever the toolchain supports it.

See [FOUNDATION_SHIMS.md](FOUNDATION_SHIMS.md) for the active shim surface, maintenance rules, and the canary commands for deciding when a newer Swift/Foundation release makes the shim unnecessary.

See [Docs/ProjectPlan.md](Docs/ProjectPlan.md) for the dashboard-style build plan and active project tracker.

See [Docs/TermChocolatePlan.md](Docs/TermChocolatePlan.md) for the future terminal backend plan (TermChocolate): a `TUINativeControlBackend` inside `ChocolateKit` driven by TUIKit. Plan only, not scheduled work.

See [Docs/WASMChocolatePlan.md](Docs/WASMChocolatePlan.md) for the future browser backend plan (WASMChocolate): a `WASMNativeControlBackend` inside `ChocolateKit` driven by SwiftDOM, compiled to WebAssembly. Plan only, not scheduled work.

See [Docs/RADICALLY_DIFFERENT_UI_SPIKE.md](Docs/RADICALLY_DIFFERENT_UI_SPIKE.md) for the spike that executes the first slice of both: one unmodified click-counter demo running on Win32, GTK, a terminal, and the browser.

The current visual style is the classic Win32 look on purpose. That should remain available for apps that want a retro or very small native-tool feel. The roadmap now tracks a separate modern Windows appearance layer as the eventual default, with backend or appearance selection so app code can keep the same AppKit-shaped API.

The table plan is Mac-first: application code should use AppKit-shaped `NSTableView`, `NSTableColumn`, data source, delegate, sort descriptors, cell/view helpers, and `NSScrollView.documentView` patterns. The current classic backend renderer is temporary and deliberately hidden behind the same native backend boundary as the other controls.

The layout plan is also Mac-first. Early demos use manual frames, but the roadmap includes AppKit-style Auto Layout support later: `NSLayoutConstraint`, layout anchors, intrinsic content size, priorities, hugging, compression resistance, and `translatesAutoresizingMaskIntoConstraints`.

## Build And Run

From this directory:

```bat
buildandrun.bat
```

The script builds the Swift package, runs the contract tests, checks native demo window creation, and launches the demo app.

An optional first argument selects which demo to build and run:

```bat
buildandrun.bat demo       rem the main WinChocolate demo (default)
buildandrun.bat runloop    rem the RunLoop / Timer demo
```

Any other arguments pass straight through to the app, so `buildandrun.bat --dark`
still runs the main demo (with `--dark`), and `buildandrun.bat runloop --dark`
runs the run-loop demo. The `runloop` app has no `--diagnose` self-check or
bundled resources, so those steps are skipped for it.

### WSL / Linux

From PowerShell in the repository root, build and run the same combined
`ChocolateKit` framework through its GTK backend:

```bat
run-wsl.bat
run-wsl.bat runloop
run-wsl.bat --build
run-wsl.bat --tests
run-wsl.bat --diagnose
```

The runner mirrors the checkout onto WSL's native filesystem before building,
which avoids SwiftPM and symlink problems under `/mnt/c`. Initial WSL/GTK setup
is one command from the repository root:

```bat
setup-wsl.bat
```

On macOS with Docker and XQuartz, use `./run-linux.sh`; it builds this same root
package in an architecture-native Linux container (including Apple Silicon ARM64).

## Package Layout

```text
Package.swift
Sources/ChocolateKit
Sources/CGTK
Sources/CGTKCompat
Sources/WinChocolate
Sources/LinChocolate
WinFoundation
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
