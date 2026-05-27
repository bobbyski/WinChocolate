# WinChocolate Architecture

## Summary

WinChocolate is an AppKit-shaped SwiftPM framework for Windows. The goal is to let application code replace `import Cocoa` or `import AppKit` with `import WinChocolate` and keep familiar names such as `NSApplication`, `NSWindow`, `NSView`, `NSButton`, and `NSTextField`, while the implementation wraps native Windows controls behind a backend boundary.

Overall planned-code progress: `█████░░░░░` 54%

## First Milestone

The first milestone is a runnable AppKit-shaped Windows application slice:

- [x] `NSApplication` exists and owns lifecycle.
- [x] A menu bar model exists through `NSApplication.mainMenu`.
- [x] A Quit submenu item can terminate the application.
- [x] A demo window contains a classic click counter.
- [x] The menu bar and click counter are backed by real HWND/message dispatch.
- [x] The demo executable uses the Windows subsystem so launching it does not create a separate console window.
- [x] The demo visibly exercises title, text, enabled, hidden, and frame updates.

## Project Dashboard

| Phase | Status | Progress | Planned Commands | Notes |
|---|---:|---:|---|---|
| 1: SwiftPM Shape And Core Names | Implemented | 100% | package, sources, tests, docs | Initial AppKit-compatible public type names are in place. |
| 2: Classic Win32 Backend | Partial | 91% | HWND creation, message loop, child controls | User32-backed window, custom view container, menu, button, checkbox, radio button, combo box, group box, static/edit text, text/frame/visibility/enabled updates, native cleanup, mouse-down event dispatch, and command dispatch are in place. This backend should keep the classic Win32 look available for apps that want it. |
| 3: AppKit Surface Expansion | Partial | 39% | menus, dialogs, responders, layout, text, images | Initial `NSMenu`, `NSMenuItem`, `NSAlert`, `NSBox`, `NSColor`, `NSFont`, `NSResponder`, editable `NSTextField`, `NSPopUpButton`, and push/switch/radio `NSButton` APIs are present. |
| 4: Demo Application | Partial | 81% | SwiftPM demo app | Demo source builds as a SwiftPM executable and visibly exercises native state APIs, modal alerts, editable text, checkbox state, radio groups, and pop-up selection. |
| 5: Modern Windows Appearance | Planned | 0% | visual manager, themed controls, modern backend option | The eventual default should look like a modern Windows app while preserving the classic Win32 backend as an opt-in retro/native-simple mode. |
| 6: Backend Selection And Theming | Planned | 0% | app/config API, backend factory, tests | Add an AppKit-shaped way to choose the classic or modern presentation without changing application UI code. |

## Checklist

- [x] Create SwiftPM package in `Code/WinChocolate`.
- [x] Add AppKit-shaped core public names.
- [x] Add architecture documentation.
- [x] Add unit tests for public hierarchy behavior.
- [x] Replace the temporary Win32 backend fallback with first real HWND creation.
- [x] Add initial menu APIs.
- [x] Add initial `NSAlert` API backed by native modal dialogs.
- [x] Add editable `NSTextField` backed by native edit controls.
- [x] Add switch-style `NSButton` backed by native checkboxes.
- [x] Add radio-style `NSButton` backed by native radio buttons.
- [x] Add `NSPopUpButton` backed by native combo boxes.
- [x] Add `NSBox` backed by native group boxes.
- [x] Add initial `NSColor` and color propagation for views and text fields.
- [x] Add initial `NSFont` and font propagation for text fields.
- [x] Add initial `NSResponder` chain support for windows and views.
- [x] Add native mouse-down dispatch into `NSView.mouseDown(with:)`.
- [x] Add native state updates for title/text, frame, hidden, enabled, and destroyed views.
- [ ] Preserve the current classic Win32 look as an explicit supported presentation mode.
- [ ] Add a modern Windows presentation layer as the eventual default.
- [ ] Add backend or appearance selection APIs so apps can opt into classic mode.
- [ ] Add `NSResponder`, image, font, color, layout, and deeper event APIs.
- [x] Add a Swift demo application skeleton under `Demo`.

## Layering

```text
Application code
   |
   v
AppKit-compatible public API
   |
   v
NSApplication / NSWindow / NSView / NSControl
   |
   v
NativeControlBackend
   |
   v
Win32 HWND-backed implementation
```

## Compatibility Strategy

The public API uses Apple counterpart names exactly where implemented. The first compatibility slice focuses on the smallest useful application shape: application lifecycle, windows, views, buttons, text fields, geometry, notifications, events, and selector-shaped control actions.

Objective-C runtime behavior is not available in normal Swift on Windows. Where AppKit depends on Objective-C selectors, WinChocolate preserves the property names and adds Swift-native closure dispatch so native Windows applications can still be ergonomic.

Foundation should be preferred for shared data structures and platform-neutral behavior whenever it is available and appropriate. Windows-native data constructs should stay behind backend boundaries or be used only when Foundation does not provide a suitable cross-platform representation.

## Native Control Strategy

Native code is isolated behind `NativeControlBackend`. Public controls do not call Win32 directly; they ask the backend to create or update peers. This keeps tests deterministic and makes future platform work easier to review.

`InMemoryNativeControlBackend` records native creation requests for tests. `Win32NativeControlBackend` owns the current native Windows path for windows, menu items, static text, push buttons, text updates, and command dispatch.

The current `Win32NativeControlBackend` is intentionally allowed to keep its classic Windows look. That appearance is useful for retro apps, very small tools, and as a simple correctness backend. The long-term default should become a modern Windows presentation, likely through a separate appearance/backend layer rather than by breaking the classic backend.

Modern appearance work is not part of the first native milestone. It should be tracked separately from API compatibility because visual polish, theming, high-DPI behavior, font/color systems, dark mode, and modern control rendering are substantial work on their own.

`NSColor` is the first appearance primitive. It stores normalized RGBA components and currently drives `NSView.backgroundColor` plus `NSTextField.textColor`. The classic Win32 backend maps these values to simple `COLORREF` and brush handling for native static/edit controls and custom view background painting; future modern rendering should build on the same public properties.

`NSFont` stores a portable font request with family name, point size, and regular/bold weight. `NSTextField.font` is the first consumer. The classic Win32 backend maps this to `CreateFontW` and applies it with `WM_SETFONT`, while the in-memory backend records the requested font for contract tests.

`NSResponder` now sits between `NSObject` and visible objects such as `NSView` and `NSWindow`. The first implementation provides `nextResponder`, first-responder hooks, and default mouse/key forwarding. `NSView.addSubview(_:)` wires child views to their superview, and `NSWindow.contentView` wires the content view back to the window.

Native mouse-down dispatch now reaches realized `NSView` instances. The Win32 backend translates `WM_LBUTTONDOWN` on WinChocolate view HWNDs into `NSEvent(type: .leftMouseDown, locationInWindow:)`, then invokes `NSView.mouseDown(with:)` through the backend registration path.

`NSView` maps to a lightweight custom child HWND. The same WinChocolate window procedure handles top-level windows and view containers, while only top-level window destruction terminates the application. This allows nested view hierarchies without losing button `WM_COMMAND` dispatch.

Realized views and controls now propagate common state changes to native peers. `NSWindow.title`, `NSWindow.setFrame(_:display:)`, `NSView.frame`, `NSView.isHidden`, and `NSControl.isEnabled` update the backend after realization. Removing a realized subview recursively destroys its native peer.

`NSAlert` runs through the backend and currently maps to native `MessageBoxW`. This gives real modal behavior for the first milestone. Custom alert button captions are recorded in the public API, but the Win32 backend still uses standard MessageBox button sets until a custom dialog backend is added.

`NSTextField` now supports editable and static modes. Static fields map to native `STATIC` controls; editable fields map to native `EDIT` controls and use `EN_CHANGE` notifications to update `stringValue` and invoke `onTextChanged`.

`NSButton` now supports `momentaryPushIn` and `switchButton` modes. Switch buttons map to native auto-checkbox controls and synchronize `NSControl.StateValue` through `BM_GETCHECK` and `BM_SETCHECK`.

Radio-style `NSButton` controls map to native auto-radio buttons and enforce sibling exclusivity in the Swift view hierarchy. This keeps the public behavior AppKit-shaped while the backend handles native check state.

`NSPopUpButton` maps to a native Windows `COMBOBOX` in dropdown-list mode. The Swift control owns item titles and AppKit-shaped selection APIs such as `addItems(withTitles:)`, `selectItem(at:)`, `selectItem(withTitle:)`, `indexOfSelectedItem`, and `titleOfSelectedItem`, while the backend synchronizes native items and reads selection changes through `CBN_SELCHANGE`.

`NSBox` maps to a native Windows group box. It is intentionally simple today: title and frame sync through the shared backend state update path, and child controls remain normal sibling views layered above it.

## Review Notes

The framework is intentionally incomplete. Matching Cocoa and AppKit is a large, multi-phase compatibility project. Each new API should add:

- Apple-compatible public names and initializer shapes.
- Documentation comments for every public symbol.
- Native backend behavior or an explicit backend extension point.
- Tests that verify public contracts without requiring a visible window when possible.
