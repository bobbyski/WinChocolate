# WinChocolate Architecture

## Summary

WinChocolate is an AppKit-shaped SwiftPM framework for Windows. The goal is to let application code replace `import Cocoa` or `import AppKit` with `import WinChocolate` and keep familiar names such as `NSApplication`, `NSWindow`, `NSView`, `NSButton`, and `NSTextField`, while the implementation wraps native Windows controls behind a backend boundary.

Overall planned-code progress: `█████░░░░░` 50%

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
| 2: Native Backend Boundary | Partial | 78% | HWND creation, message loop, child controls | User32-backed window, custom view container, menu, button, static text, text/frame/visibility/enabled updates, native cleanup, and command dispatch are in place. |
| 3: AppKit Surface Expansion | Partial | 10% | menus, responders, layout, text, images | Initial `NSMenu` and `NSMenuItem` APIs are present. |
| 4: Demo Application | Partial | 60% | SwiftPM demo app | Demo source builds as a SwiftPM executable and visibly exercises the first native state APIs. |

## Checklist

- [x] Create SwiftPM package in `Code/WinChocolate`.
- [x] Add AppKit-shaped core public names.
- [x] Add architecture documentation.
- [x] Add unit tests for public hierarchy behavior.
- [x] Replace the temporary Win32 backend fallback with first real HWND creation.
- [x] Add initial menu APIs.
- [x] Add native state updates for title/text, frame, hidden, enabled, and destroyed views.
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

## Native Control Strategy

Native code is isolated behind `NativeControlBackend`. Public controls do not call Win32 directly; they ask the backend to create or update peers. This keeps tests deterministic and makes future platform work easier to review.

`InMemoryNativeControlBackend` records native creation requests for tests. `Win32NativeControlBackend` owns the current native Windows path for windows, menu items, static text, push buttons, text updates, and command dispatch.

`NSView` maps to a lightweight custom child HWND. The same WinChocolate window procedure handles top-level windows and view containers, while only top-level window destruction terminates the application. This allows nested view hierarchies without losing button `WM_COMMAND` dispatch.

Realized views and controls now propagate common state changes to native peers. `NSWindow.title`, `NSWindow.setFrame(_:display:)`, `NSView.frame`, `NSView.isHidden`, and `NSControl.isEnabled` update the backend after realization. Removing a realized subview recursively destroys its native peer.

## Review Notes

The framework is intentionally incomplete. Matching Cocoa and AppKit is a large, multi-phase compatibility project. Each new API should add:

- Apple-compatible public names and initializer shapes.
- Documentation comments for every public symbol.
- Native backend behavior or an explicit backend extension point.
- Tests that verify public contracts without requiring a visible window when possible.
