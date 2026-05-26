# WinChocolate Architecture

## Summary

WinChocolate is an AppKit-shaped SwiftPM framework for Windows. The goal is to let application code replace `import Cocoa` or `import AppKit` with `import WinChocolate` and keep familiar names such as `NSApplication`, `NSWindow`, `NSView`, `NSButton`, and `NSTextField`, while the implementation wraps native Windows controls behind a backend boundary.

Overall planned-code progress: `████░░░░░░` 40%

## First Milestone

The first milestone is a runnable AppKit-shaped Windows application slice:

- [x] `NSApplication` exists and owns lifecycle.
- [x] A menu bar model exists through `NSApplication.mainMenu`.
- [x] A Quit submenu item can terminate the application.
- [x] A demo window contains a classic click counter.
- [x] The menu bar and click counter are backed by real HWND/message dispatch.
- [x] The demo executable uses the Windows subsystem so launching it does not create a separate console window.

## Project Dashboard

| Phase | Status | Progress | Planned Commands | Notes |
|---|---:|---:|---|---|
| 1: SwiftPM Shape And Core Names | Implemented | 100% | package, sources, tests, docs | Initial AppKit-compatible public type names are in place. |
| 2: Native Backend Boundary | Partial | 65% | HWND creation, message loop, child controls | First real User32-backed window, menu, button, static text, and command dispatch path is in place. |
| 3: AppKit Surface Expansion | Partial | 10% | menus, responders, layout, text, images | Initial `NSMenu` and `NSMenuItem` APIs are present. |
| 4: Demo Application | Partial | 45% | SwiftPM demo app | Demo source now builds as a SwiftPM executable and models the click counter milestone. |

## Checklist

- [x] Create SwiftPM package in `Code/WinChocolate`.
- [x] Add AppKit-shaped core public names.
- [x] Add architecture documentation.
- [x] Add unit tests for public hierarchy behavior.
- [x] Replace the temporary Win32 backend fallback with first real HWND creation.
- [x] Add initial menu APIs.
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

Plain `NSView` is currently treated as a transparent container by the Win32 backend. Child controls are parented directly to the containing window so button `WM_COMMAND` messages reach the top-level WinChocolate window procedure. A later milestone should replace this with a custom container HWND for nested view hierarchies.

## Review Notes

The framework is intentionally incomplete. Matching Cocoa and AppKit is a large, multi-phase compatibility project. Each new API should add:

- Apple-compatible public names and initializer shapes.
- Documentation comments for every public symbol.
- Native backend behavior or an explicit backend extension point.
- Tests that verify public contracts without requiring a visible window when possible.
