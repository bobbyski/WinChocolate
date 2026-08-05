# Foundation Parity Ledger

**Plan item:** Unified Chocolate Phase 2.1 · **Last measured:** 2026-08-05

The shared core (`Sources/ChocolateKit`) is compiled against a *different
Foundation on every platform*: `WinFoundation` on Windows, real
corelibs-foundation on Linux, real Foundation on macOS (see
`Sources/ChocolateKit/Runtime/FoundationBridge.swift`, conditional C1). One
source, three Foundations — so wherever `WinFoundation` differs from the real
thing, the core silently means something different depending on where it is
built.

This ledger is the list of those differences. It exists so the divergences are
*known and decided* rather than discovered by a Linux build failure.

**The rule this enforces:** where the two differ, the fix belongs in
`WinFoundation` — the deliberately-compatible one — never in a second
conditional in the core. A `#if` in the core would defeat the entire point of
the merge.

## How to use it

- Adding a Foundation type or method to the core? Check it here first.
- Fixing a divergence? Move its row to **Reconciled**, and add a contract test
  so it cannot regress.
- Accepting one? Put it in **Accepted divergences** *with the reason*. An
  undocumented divergence is a bug waiting for Phase 3.

---

## Reconciled in Phase 2

Each row was a real difference; each is now fixed and pinned by
`testFoundationTypesMatchApplesShapes()` in
`Tests/WinChocolateContractTests/main.swift`.

| Area | What differed | Why it mattered | Fix |
|------|---------------|-----------------|-----|
| `DateFormatter` | Standalone `final class`; Foundation's is `open class DateFormatter: Formatter` | `NSControl.formatter` is typed `Formatter?`. `field.formatter = DateFormatter()` compiles on macOS and was a **Windows-only compile error** — a direct imports-only break | Inherits `Formatter`, overrides `string(for:)`, declared `open` |
| `NumberFormatter` | `final` | Foundation's is `open`. Subclassing a formatter to adjust one method is ordinary AppKit practice; `final` forced a source change | `open class`, `string(for:)` marked `open` |
| `NSNib.instantiate` | Took `inout [Any]?`; AppKit takes `inout NSArray?` | Identical on Windows (`NSArray` *is* `[Any]` here) but **would not compile on Linux/macOS**, where `NSArray` is a class. An app's `var topLevelObjects: NSArray?` had nowhere to go | Signature spells `NSArray?`, as AppKit does. Same for `Bundle.loadNibNamed` |
| `URL` round-trip | `URL(string: "file://…")` normalized separators to `\`; `URL(fileURLWithPath:)` kept whatever the caller passed | `absoluteString` is lossy — it always emits `/`. With the two entry points disagreeing, `URL(string: u.absoluteString) != u`, so **any app persisting a URL** (JSON, defaults, pasteboard) read back a value comparing unequal to what it wrote | `init(fileURLWithPath:)` normalizes to the native separator, matching the parser and the file's own storage convention |
| `Locale`, `TimeZone` | Neither `Hashable` nor `Codable`; Foundation's are both | A preferences struct holding either **could not synthesize `Codable` at all**, and neither could key a dictionary | Added both. Encoded form is Foundation's — a keyed container carrying `identifier` — so a file written on a Mac reads here |
| `Data`, `URL` | Not `Codable` | Blocked `Codable` synthesis for any struct holding one; `Data` also never got its base64 treatment | Conformances added (earlier in this phase); `Data` encodes base64, as Foundation's does |

## Accepted divergences

Known, deliberate, and **not** scheduled to change. Each carries its reason.

| Area | Divergence | Why it is accepted |
|------|-----------|--------------------|
| `NSArray` = `[Any]` | Foundation's is a class | Making it a real class needs `_ObjectiveCBridgeable`, which needs ObjC interop this toolchain does not have. As an alias it behaves correctly on both sides — `topLevel as? [Any]` bridges on Apple and is a no-op here. Cost: two "conditional downcast does nothing" warnings in `DemoNibConveniences.swift`. **Correct everywhere, noisy here.** |
| `NSString` = `String`, `NSURL` = `URL` | Foundation's are classes | Same reason. The shared core does not use either name outside comments (verified 2026-08-05), so the alias only affects app-level source, where it behaves correctly. |
| `Notification` | Not `Equatable`; Foundation's is | Foundation's `==` compares a `[AnyHashable: Any]?` userInfo through ObjC bridging. Reproducing that without interop is disproportionate to the demand — no known caller compares notifications. |
| `IndexSet` | `Sequence`; Foundation's is a `BidirectionalCollection` + `SetAlgebra` | The core uses it for row/column index passing only. Widening it is Phase 5 work if a caller ever needs it. |
| `Bundle`, `Timer`, `RunLoop`, `NotificationCenter`, `OperationQueue`, `ProcessInfo`, `JSONEncoder`, `JSONDecoder` | `final`; Foundation's are `open` | Subclassing these is rare in app code, unlike the formatters. Left `final` deliberately; drop it the moment a real app needs it — the change is source-compatible in that direction. |
| `TimeZone(identifier:)` | Resolves a narrower set than Foundation's tz database | Windows has no tz database. Decoding an unresolvable identifier falls back to the current zone rather than throwing, so a document written on a Mac still opens. |

## Verified same

Checked and found to match Foundation — recorded so they are not re-litigated.

| Area | Finding |
|------|---------|
| `TimeInterval` = `Double` | Foundation defines exactly this alias. ✅ |
| Struct-vs-class kinds | All 20 shared value types are structs where Foundation's are structs (`Data`, `Date`, `URL`, `UUID`, `IndexPath`, `IndexSet`, `Locale`, `TimeZone`, `NSRange`, `Notification`, `URLRequest`), and classes where Foundation's are classes. No silent value/reference flip. ✅ |
| `ObjCBool` | Used by `NSAttributedString.enumerateAttributes` as `UnsafeMutablePointer<ObjCBool>` — Foundation's exact shape, and `ObjCBool` exists in corelibs-foundation too. ✅ |
| `JSONEncoder`/`JSONDecoder` URL handling | Both special-case `URL` to `absoluteString`, which is what Foundation's coders do (they do *not* route through `URL.Codable`). Symmetric on both sides. ✅ |
| `Data` JSON encoding | base64, matching Foundation's default `DataEncodingStrategy`. ✅ |
| `Date`, `UUID`, `IndexPath` | `Codable` present via extensions. ✅ |
| Core usage of the risky aliases | `NSArray` 0 files, `NSString` 0 (comments only), `NSURL` 0 (comments only), `NSNumber` 0. The **shared core does not depend on the divergent aliases** — they are app-surface only. ✅ |

## Open — carry into Phase 3

Real-Foundation-only behavior that cannot be settled on Windows and must be
confirmed on the first Linux build:

- **`@Sendable` / isolation on `Timer` blocks.** Real Foundation types the timer
  block `@Sendable`; `WinFoundation`'s does not. The frozen demo already handles
  this with `MainActor.assumeIsolated`, which is correct on both, but other
  closure-taking APIs have not been swept.
- **`Bundle` resource lookup.** `NSNib(nibNamed:bundle:)` searches
  `Bundle.main`, then `.`, then `Resources/` — a bundle-less-executable
  accommodation. Whether real `Bundle.main` resolves the same way on Linux is
  untested.
- **`String(contentsOf:)` encoding defaults** and the `StringIOError` surface.
- **`ProcessInfo.processInfo.environment`** and argument handling under a real
  Foundation.

---

*Recorded by the plan's Phase 2. Divergences fixed here are pinned by contract
tests; divergences accepted here are documented above with their reasons.*
