# AppKit Compatibility Divergences — Shared Demo vs. real Apple AppKit

**Status:** proposal (drop into the WinChocolate plan)
**Found:** 2026-07-12, by type-checking the shared demo (`Demo/DemoApplication/main.swift`)
against genuine Apple AppKit on macOS: `swiftc -typecheck main.swift AppKitCompat.swift`.

## Context

The demo is now built from **one source** against three libraries via a conditional
import — LinChocolate (Linux/GTK), WinChocolate (Windows/Win32), and **real Apple
AppKit (macOS)** as the ground truth:

```swift
#if canImport(LinChocolate)
import LinChocolate
#elseif canImport(WinChocolate)
import WinChocolate
#elseif canImport(AppKit)
import AppKit
#endif
```

Most of the AppKit gap is *additive* — WinChocolate/LinChocolate ergonomics that raw
AppKit lacks (frame-based initializers, closure `onAction`, `NSView.backgroundColor`,
`winIsDark`, `NSForm.textField(at:)`, `NSToolbar.addItem`). Those are handled by a small
AppKit-only shim (`Demo/AppKitCompat.swift`) that re-adds them as extensions on Apple's
types, and shrink as the demo is tidied.

This document covers the **hard divergences** — places where a WinChocolate ergonomic
*conflicts* with real AppKit's actual API and therefore **cannot** be papered over by an
extension. Each needs a small source change (or `#if` guard) to compile on genuine AppKit.

## Summary

| # | Divergence | Sites | Root cause | Recommended fix |
|---|---|---:|---|---|
| 1 | `NSToolbarItem.Identifier` treated as `String` | ~70 | WinChocolate typealiases `Identifier = String`; AppKit's is a distinct `RawRepresentable` struct (`ExpressibleByStringLiteral`) | Make `Identifier` a real struct in both frameworks |
| 2 | Global helpers not `@MainActor` | ~88 | Real AppKit is `@MainActor`; the demo's top-level code is isolated but its global helper funcs are not, so calls cross actors (Swift 6 strict concurrency) | Annotate the demo's global helpers `@MainActor` |
| 3 | `previousKeyView` set as if read-write | ~30 | AppKit's `previousKeyView` is **get-only** (derived from `nextKeyView`); WinChocolate made it settable | Demo sets only `nextKeyView`; make `previousKeyView` get-only in both frameworks |

---

## Divergence 1 — `NSToolbarItem.Identifier` is a distinct type, not `String`

**Real AppKit:**
```swift
extension NSToolbarItem {
    struct Identifier: RawRepresentable, ExpressibleByStringLiteral, Hashable { ... }
}
```
`NSUserInterfaceItemIdentifier` is the same shape. String **literals** coerce
(`ExpressibleByStringLiteral`), but a `String` **value** or a `[String]` array does not.

**WinChocolate / LinChocolate today:** `public typealias Identifier = String`, so the demo
passes bare `String`s and `[String]` arrays everywhere.

**Errors (~70):**
```
cannot convert value of type 'String' to expected element type '…NSToolbarItem.Identifier'
cannot convert value of type 'String' to expected argument type 'NSUserInterfaceItemIdentifier'
conflicting arguments to generic parameter 'Self' ('NSUserInterfaceItemIdentifier?' vs 'String')
```

**Proposed fix (both frameworks):** replace the `String` typealias with an AppKit-shaped
struct:
```swift
public struct Identifier: RawRepresentable, Hashable, ExpressibleByStringLiteral, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
}
```
- String **literals** (the common demo case) then compile unchanged on all three.
- The few spots passing a `String` **variable** or building `[String]` should switch to
  `Identifier(...)` / `[Identifier]` — a handful of demo edits.
- Also give `NSView.identifier` the `NSUserInterfaceItemIdentifier` type (same struct).

---

## Divergence 2 — Global helper functions must be `@MainActor`

**Real AppKit** annotates its UI types `@MainActor`. In `main.swift`, top-level statements
are implicitly `@MainActor`, but **global helper functions** the demo defines
(`bezelCaption`, `showcaseSectionLabel`, `updateFocusDisplay`, `showDemoPage`,
`reflowAutoLayoutPage`, `configureToolbarKeyLoop`, …) are *non-isolated*, so calling them
from the isolated top level is a cross-actor call under Swift 6 strict concurrency.

WinChocolate/LinChocolate don't yet mark their AppKit-shaped types `@MainActor`, so this
never surfaces there.

**Errors (~88):**
```
call to main actor-isolated global function 'bezelCaption' in a synchronous nonisolated context
call to main actor-isolated global function 'showcaseSectionLabel' in a synchronous nonisolated context
…
```

**Proposed fix (demo):** mark each global helper that touches UI `@MainActor`:
```swift
@MainActor func bezelCaption(...) -> NSTextField { ... }
@MainActor func showcaseSectionLabel(...) -> NSTextField { ... }
```
This is AppKit-correct and a no-op on WinChocolate/LinChocolate. (Longer term, both
frameworks could annotate their AppKit-shaped types `@MainActor` to match Apple exactly —
more faithful, but then the annotations are required on all three targets. Marking the
demo helpers is the low-friction path and is strictly correct.)

---

## Divergence 3 — `previousKeyView` is get-only in AppKit

**Real AppKit:** you set `nextKeyView`; `previousKeyView` is maintained automatically and
is **get-only**. WinChocolate exposes a settable `previousKeyView` for symmetry, and the
demo sets both directions when wiring its key-view loop.

**Errors (~30):**
```
cannot assign to property: 'previousKeyView' is a get-only property
```

**Proposed fix:**
- **Demo:** set only `nextKeyView` (AppKit derives the reverse link). If an explicit
  bidirectional helper is wanted, wrap it: `func link(_ a: NSView, _ b: NSView) { a.nextKeyView = b }`.
- **Frameworks:** make `previousKeyView` get-only in WinChocolate/LinChocolate too and
  maintain it internally from `nextKeyView` assignments — matching AppKit exactly.

---

## Recommended approach

1. **Frameworks** (WinChocolate first, then mirror in LinChocolate): promote
   `NSToolbarItem.Identifier` / `NSUserInterfaceItemIdentifier` to real structs; make
   `previousKeyView` get-only + internally derived.
2. **Demo:** annotate global UI helpers `@MainActor`; set only `nextKeyView`; use
   `Identifier(...)` at the few variable/array sites.

After (1) + (2), the single shared source compiles on **all three** targets with only the
purely-additive AppKit shim (frame inits, closure actions, `backgroundColor`, `winIsDark`,
`NSForm.textField(at:)`, `NSToolbar.addItem`) — no divergence guards.
