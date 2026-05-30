# WinChocolate Architecture

## Summary

WinChocolate is an AppKit-shaped SwiftPM framework for Windows. The goal is to let application code replace `import Cocoa` or `import AppKit` with `import WinChocolate` and keep familiar names such as `NSApplication`, `NSWindow`, `NSView`, `NSButton`, and `NSTextField`, while the implementation wraps native Windows controls behind a backend boundary.

Overall planned-code progress: `█████░░░░░` 54%

Current planned-code progress after the scroller update: `██████░░░░` 60%

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
| 2: Classic Win32 Backend | Partial | 96% | HWND creation, message loop, child controls | User32-backed window, custom view container, menu, button, checkbox, radio button, pop-up/combo box, group box, static/edit/secure/multiline text, image placeholder, tab view, slider, progress, stepper, text/frame/visibility/enabled updates, native cleanup, mouse/key event dispatch, experimental child-control Tab interception, and command dispatch are in place. This backend should keep the classic Win32 look available for apps that want it. |
| 3: AppKit Surface Expansion | Partial | 67% | menus, dialogs, responders, layout, text, tables, images | Initial `NSMenu`, `NSMenuItem`, `NSAlert`, `NSBox`, `NSColor`, `NSFont`, `NSEvent`, `NSResponder`, `NSApp`, `NSWindow.firstResponder`, key-view loop APIs, key/main window tracking, editable `NSTextField`, `NSSecureTextField`, `NSSearchField`, multiline `NSTextView`, `NSPopUpButton`, `NSComboBox`, `NSImageView`, `NSTabView`, `NSSlider`, `NSScroller`, `NSProgressIndicator`, `NSLevelIndicator`, `NSStepper`, `NSColorWell`, `NSScrollView`, `NSSplitView`, `NSTableColumn`, `NSTableView`, `NSCell`, `NSTableCellView`, `NSTableRowView`, `NSSortDescriptor`, and push/switch/radio `NSButton` APIs are present. |
| 4: Demo Application | Partial | 96% | SwiftPM demo app | Demo source builds as a SwiftPM executable and visibly exercises native state APIs, modal alerts, editable/secure/combo text, multiline notes, checkbox state, radio groups, pop-up selection, bitmap image tests, split view pane layout, tab selection, slider/progress/scroller/stepper values, table selection/action, mouse events, and key events. |
| 5: AppKit Tables And Collection Controls | Partial | 27% | `NSTableView`, `NSOutlineView`, collection/list selection, cells/views | First AppKit-shaped `NSTableView` slice exists with columns, data source, delegate, row and column selection helpers, sort descriptors, row/cell-view placeholders, scroll-view hosting, table action/double-action surface, tests, and a temporary classic backend renderer. Future work should move toward visible headers, column resizing, sorting behavior, editing, reuse identifiers, and native accessibility. |
| 6: Modern Windows Appearance | Planned | 0% | visual manager, themed controls, modern backend option | The eventual default should look like a modern Windows app while preserving the classic Win32 backend as an opt-in retro/native-simple mode. |
| 7: Backend Selection And Theming | Planned | 0% | app/config API, backend factory, tests | Add an AppKit-shaped way to choose the classic or modern presentation without changing application UI code. |
| 8: Auto Layout And Constraints | Planned | 0% | `NSLayoutConstraint`, anchors, intrinsic sizes, priorities | Add AppKit-shaped constraint APIs after the core view/control surface is stable, so Mac-style layout code can move across without leaking Windows layout primitives. |

## Checklist

- [x] Create SwiftPM package in `Code/WinChocolate`.
- [x] Add AppKit-shaped core public names.
- [x] Add architecture documentation.
- [x] Add unit tests for public hierarchy behavior.
- [x] Replace the temporary Win32 backend fallback with first real HWND creation.
- [x] Add initial menu APIs.
- [x] Add initial `NSAlert` API backed by native modal dialogs.
- [x] Add editable `NSTextField` backed by native edit controls.
- [x] Add initial `NSSecureTextField` backed by native password edit controls.
- [x] Add multiline `NSTextView` backed by native edit controls.
- [x] Add switch-style `NSButton` backed by native checkboxes.
- [x] Add radio-style `NSButton` backed by native radio buttons.
- [x] Add `NSPopUpButton` backed by native combo boxes.
- [x] Add initial `NSComboBox` backed by editable native combo boxes.
- [x] Add initial `NSImageView` and `NSTabView` backed by native placeholders/tab controls.
- [x] Add `NSSlider`, `NSProgressIndicator`, and `NSStepper` value controls backed by native controls.
- [x] Add first `NSSearchField`, `NSLevelIndicator`, and `NSColorWell` slices.
- [x] Add first standalone `NSScroller` slice.
- [x] Add `NSBox` backed by native group boxes.
- [x] Add first `NSScrollView` and `NSTableView` public API slice with AppKit-shaped data-source contracts.
- [x] Add first table cell/view, sort-descriptor, column movement, and selection helper contracts.
- [x] Add table column-selection helpers and double-action compatibility surface.
- [x] Add first `NSSplitView` pane-layout and divider-positioning slice.
- [ ] Replace the temporary classic table renderer with a fuller Mac-like table implementation: headers, columns, selection, editing, sorting, and view/cell reuse.
- [x] Add initial `NSColor` and color propagation for views and text fields.
- [x] Add initial `NSFont` and font propagation for text fields.
- [x] Add initial `NSResponder` chain support for windows and views.
- [x] Add initial `NSWindow.firstResponder` and `makeFirstResponder(_:)` support.
- [x] Add initial `NSView.nextKeyView`, `previousKeyView`, and window key-view selection.
- [x] Add initial `NSApp`, application window list, and key/main window tracking.
- [x] Add native mouse-down/up/move dispatch into `NSView` responder methods.
- [x] Add native key-down/up dispatch into `NSView.keyDown(with:)` and `NSView.keyUp(with:)`.
- [ ] Stabilize native child-control Tab interception across all focusable controls.
- [x] Fix key-loop parity for display-only controls: `NSLevelIndicator` should not accept first responder by default and should be skipped during normal Tab traversal.
- [x] Add `NSEvent.characters` and `NSEvent.modifierFlags` for native key and mouse events.
- [x] Add native state updates for title/text, frame, hidden, enabled, and destroyed views.
- [ ] Preserve the current classic Win32 look as an explicit supported presentation mode.
- [ ] Add a modern Windows presentation layer as the eventual default.
- [ ] Add backend or appearance selection APIs so apps can opt into classic mode.
- [ ] Add AppKit-style Auto Layout and constraint APIs: `NSLayoutConstraint`, layout anchors, intrinsic content size, priorities, hugging, compression resistance, and `translatesAutoresizingMaskIntoConstraints`.
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

For complex controls, WinChocolate should model AppKit first and treat Windows controls as replaceable renderers. `NSTableView`, `NSTableColumn`, and `NSScrollView.documentView` should grow in the Mac direction: data source and delegate ownership, column identifiers, selection notifications, headers, cell/view reuse, editing, sorting, and keyboard behavior. Native Windows list/list-view controls can be used behind the backend boundary, but their API shape should not leak into application code.

Foundation should be preferred for shared data structures and platform-neutral behavior whenever it is available and appropriate. Windows-native data constructs should stay behind backend boundaries or be used only when Foundation does not provide a suitable cross-platform representation.

Layout should stay Mac-first. Manual frames are enough for the early controls and demo, but the long-term compatibility plan includes AppKit-style Auto Layout rather than a Windows layout model. `NSLayoutConstraint`, layout anchors, intrinsic content size, priority handling, content hugging, compression resistance, and `translatesAutoresizingMaskIntoConstraints` should be added after the core view hierarchy and native control wrappers are stable enough to make constraint solving meaningful.

## Native Control Strategy

Native code is isolated behind `NativeControlBackend`. Public controls do not call Win32 directly; they ask the backend to create or update peers. This keeps tests deterministic and makes future platform work easier to review.

`InMemoryNativeControlBackend` records native creation requests for tests. `Win32NativeControlBackend` owns the current native Windows path for windows, menu items, static text, push buttons, text updates, and command dispatch.

The current `Win32NativeControlBackend` is intentionally allowed to keep its classic Windows look. That appearance is useful for retro apps, very small tools, and as a simple correctness backend. The long-term default should become a modern Windows presentation, likely through a separate appearance/backend layer rather than by breaking the classic backend.

Modern appearance work is not part of the first native milestone. It should be tracked separately from API compatibility because visual polish, theming, high-DPI behavior, font/color systems, dark mode, and modern control rendering are substantial work on their own.

`NSColor` is the first appearance primitive. It stores normalized RGBA components and currently drives `NSView.backgroundColor` plus `NSTextField.textColor`. The classic Win32 backend maps these values to simple `COLORREF` and brush handling for native static/edit controls and custom view background painting; future modern rendering should build on the same public properties.

`NSFont` stores a portable font request with family name, point size, and regular/bold weight. `NSTextField.font` is the first consumer. The classic Win32 backend maps this to `CreateFontW` and applies it with `WM_SETFONT`, while the in-memory backend records the requested font for contract tests.

`NSResponder` now sits between `NSObject` and visible objects such as `NSView` and `NSWindow`. The first implementation provides `nextResponder`, first-responder hooks, and default mouse/key forwarding. `NSView.addSubview(_:)` wires child views to their superview, and `NSWindow.contentView` wires the content view back to the window.

`NSWindow.firstResponder` and `makeFirstResponder(_:)` now provide a first pass at AppKit-shaped focus ownership. The method honors `resignFirstResponder()` and `becomeFirstResponder()`, records the active responder, and asks the backend to move native focus when the responder is a realized view. Mouse-down dispatch attempts to make the clicked view first responder before delivering the mouse event.

`NSApplication` now keeps an AppKit-shaped window list with `windows`, `keyWindow`, and `mainWindow`, plus the global `NSApp` alias. `NSWindow.makeKeyAndOrderFront(_:)` realizes the native peer, marks the window key and main, and shows it. Closing a tracked window clears key/main references when appropriate.

Key-view traversal has an initial explicit loop. `NSView.nextKeyView` and `previousKeyView` can be wired by application code, while `NSWindow.selectNextKeyView(_:)` and `selectPreviousKeyView(_:)` move first responder and native focus to the next enabled visible view. Automatic AppKit-style key-view recalculation is still future work.

Native child-control Tab interception is being introduced narrowly. A first broad subclassing attempt proved too risky because it touched every child HWND during startup. The current experimental path subclasses only editable `NSTextField` peers, preserves the original edit-control window procedure, and asks the edit control to report `DLGC_WANTTAB` so Tab can travel through the WinChocolate key-view loop. Other native controls should be added one family at a time.

Native mouse dispatch now reaches realized `NSView` instances. The Win32 backend translates `WM_LBUTTONDOWN`, `WM_LBUTTONUP`, and `WM_MOUSEMOVE` on WinChocolate view HWNDs into `NSEvent` values, then invokes `NSView.mouseDown(with:)`, `NSView.mouseUp(with:)`, or `NSView.mouseMoved(with:)` through the backend registration path. Mouse events include the current modifier flags.

Native keyboard dispatch now reaches focused WinChocolate views. Clicking a WinChocolate view sets Win32 keyboard focus to that HWND, then `WM_KEYDOWN`, `WM_KEYUP`, `WM_SYSKEYDOWN`, and `WM_SYSKEYUP` are translated into `NSEvent` values with `keyCode` populated from the native virtual-key code, `characters` populated for common keys, and `modifierFlags` populated from the current Shift, Control, Alt, and Windows-key state. System-key handling is required for Alt because Windows routes that key through the menu-oriented message path.

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
