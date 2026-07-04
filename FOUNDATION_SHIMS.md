# Foundation Shims

WinChocolate should use real Swift Foundation wherever the Windows toolchain can build it. The `WinFoundation` target exists only to keep AppKit-shaped work moving while the current local Windows ARM64 Swift toolchain fails on `import Foundation`.

The shim goal is source compatibility with Foundation APIs that WinChocolate exposes or depends on. It is not a separate product direction. Every public shim should use the same type and member names as Foundation, should be covered by contract tests, and should be easy to remove once real Foundation works.

## Current Switches

Windows builds currently define `USE_WIN_FOUNDATION` for the `WinChocolate` target. `Sources/WinChocolate/Runtime/FoundationBridge.swift` re-exports the active Foundation surface:

```swift
#if USE_REAL_FOUNDATION
@_exported import Foundation
#elseif USE_WIN_FOUNDATION
@_exported import WinFoundation
#else
@_exported import Foundation
#endif
```

Use `USE_REAL_FOUNDATION` as the canary when testing a new Swift toolchain. It intentionally bypasses the shim.

## Release Canary

Run this from `Code/WinChocolate` after installing a new Windows Swift toolchain:

```powershell
swift build -Xswiftc -DUSE_REAL_FOUNDATION
```

If that succeeds, run:

```powershell
swift test -Xswiftc -DUSE_REAL_FOUNDATION
.build\aarch64-unknown-windows-msvc\debug\WinChocolateContractTests.exe
.build\aarch64-unknown-windows-msvc\debug\WinChocolateDemo.exe --diagnose
```

Then try a normal build without the canary:

```powershell
swift build
```

The shim is no longer required when all of these are true:

- `swift build -Xswiftc -DUSE_REAL_FOUNDATION` succeeds.
- Contract tests pass with real Foundation enabled.
- The demo diagnostic passes with real Foundation enabled.
- Normal builds still pass after removing `USE_WIN_FOUNDATION` from `Package.swift`.
- Public WinChocolate APIs compile when client code imports only `WinChocolate`.

## Current Shim Surface

| Type | Status | Current purpose | Next compatibility work |
|---|---:|---|---|
| `URL` | Partial | File URLs for `NSPathControl`, future panels, image/resource loading, and document APIs. Current tests cover file and web URL creation, scheme/host/path/query/fragment components, percent-encoded path/query/fragment strings, relative URLs with bases, path standardization, Windows drive roots, and UNC shares. | Continue matching common Foundation URL behavior: richer base URL resolution, URL mutation helpers, resource values, path standardization edge cases, and broader file URL handling. |
| `Data` | Partial | Byte buffer shape for future image/resource APIs. Current tests cover repeated-byte initialization, sequence initialization, collection iteration, mutable indexing, append operations, range replacement, subdata, unsafe byte access, clearing, `Data(contentsOf:)`, and `write(to:)` round trips through file URLs. | Add base64 helpers and any missing Foundation byte APIs once image/resource loading needs them. |
| `Date` | Partial | Comparable timestamp shape for AppKit-facing APIs. Current tests cover Unix/reference-date conversion, real current clock, `Date.now`, interval initialization, comparison, distance, advancing, and adding intervals. | Add formatting-adjacent helpers only if AppKit APIs require them; richer calendar/time-zone behavior belongs in later Foundation parity work. |
| `DateFormatter` | Partial | Date/time formatting so controls (`NSDatePicker.stringValue`) and app code do not hand-roll calendar math. Explicit `dateFormat` patterns use a token engine (`yyyy`/`MM`/`dd`/`HH`/`mm`/`ss`, 12-hour `h`+`a`, month names `MMM`/`MMMM`, weekday `EEEE`, quoted literals) with English symbols; `dateStyle`/`timeStyle` presets format through the OS `GetDateFormatEx`/`GetTimeFormatEx` for the formatter's `locale`, so styled output matches the system (US dates on a US machine). Tests cover both paths, `string(from:)`, a `date(from:)` round trip, and nil-on-bad-input. UTC clock. | Localized month/day symbols on the explicit-pattern path, time zones, and calendar selection when real Foundation parity work needs them; the API shape already matches so it is a drop-in once Foundation builds. |
| `Locale` | Partial | Backs `DateFormatter`'s locale-aware presets. `Locale.current` reads the user's Windows locale name (`GetUserDefaultLocaleName`); exposes `identifier`, `shortDatePattern`/`timePattern` (from `GetLocaleInfoEx`, used to drive the native `NSDatePicker`). Tests cover current-locale patterns, identifier storage, and locale-driven formatting. | Add region/language components, number/currency formats, and full identifier↔Windows-name mapping as parity grows. |
| `IndexSet` | Partial | Selection ranges for table/list APIs. Current tests cover single indexes, open and closed ranges, range insertion/removal, first/last lookup, neighbor lookup, range containment/intersection, union, intersection, and subtraction. | Add range views, enumeration helpers, and any missing Foundation selection APIs as table/list parity grows. |
| `IndexPath` | Partial | Section/item addresses for `NSCollectionView` and future outline/list APIs. Current tests cover `IndexPath(item:section:)`, `section`, `item`, collection indexing, hashing/equality, and appending components. | Compare with real Foundation for additional initializers and mutation helpers as collection-view parity grows. |
| `UUID` | Partial | Stable identifiers for resources, controls, and future document APIs. Current tests cover native Windows GUID generation, canonical uppercase string formatting, compact/lowercase parsing, invalid parsing, raw `uuid_t` tuple initialization, equality, hashing, and `description`. | Add codable/custom reflection behavior only when needed, and compare against real Foundation once the release canary passes. |
| `Bundle` | Partial | Resource lookup for image loading, demo assets, and future document/app resource APIs. Current tests cover `Bundle(path:)`, `Bundle(url:)`, `Bundle.main`, bundle/resource URLs and paths, executable URL, package-working-directory resource lookup, and missing-resource nil behavior. | Add richer bundle metadata only when needed. SPM `Bundle.module` parity will need a separate plan because it is generated by SwiftPM rather than Foundation alone. |
| `TimeInterval` | Done | Source-compatible alias for date and animation/timer-style APIs. | No extra shim work expected unless real Foundation exposes a conflicting edge case. |
| `Notification`, `NotificationCenter`, `OperationQueue` | Partial | Foundation-style loose event delivery for future AppKit notifications and app code that uses block observers. Current tests cover `Notification.Name`, synchronous block delivery, object filtering, wildcard observers, `userInfo`, `post(_:)`, `post(name:object:userInfo:)`, `OperationQueue.main`, and observer removal. | Add selector-based observer APIs only if WinChocolate grows an Objective-C-style selector bridge. Add queue/asynchronous delivery only when needed. |

## Maintenance Rules

- Prefer adding only the Foundation API needed by WinChocolate or by demo/client compatibility tests.
- Match Foundation names and call shapes even if the implementation is temporarily incomplete.
- Add a contract test for every new public shim member.
- Keep Windows-specific code behind the shim or backend boundary.
- Do not let app-facing WinChocolate APIs expose a type that will be hard to replace with real Foundation later.
- When real Foundation starts working, remove shim use in small steps and keep this file updated until `WinFoundation` can be deleted.

## Known Current Toolchain Failure

The current local failure is not caused by WinChocolate source alone. A plain real-Foundation build fails while importing Windows SDK/UCRT overlay module maps on the installed ARM64 Windows Swift toolchain. The canary command above is the project-level test for whether a newer toolchain has fixed that root issue.

Canary re-run 2026-07-04: still failing with `time.modulemap:18: error: module '_visualc_intrinsics.arm.neon' requires feature 'armv7'` → `could not build C module 'SwiftOverlayShims'` / `could not build module 'ucrt'`. Real Foundation (and therefore its `DateFormatter`) remains unavailable, which is why `DateFormatter` was added as a WinFoundation shim rather than imported.

SwiftPM target `resources` currently triggers the same failure because it generates a Foundation-backed `resource_bundle_accessor.swift`. Demo resources are excluded from SwiftPM target compilation for now and located through explicit `Bundle` path lookup instead.
