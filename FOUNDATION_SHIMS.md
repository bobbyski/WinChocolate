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
| `URL` | Partial | File URLs for `NSPathControl`, future panels, image/resource loading, and document APIs. | Continue matching common Foundation URL behavior: base URLs, relative paths, percent encoding/decoding, resource values, path standardization, and richer file URL handling. |
| `Data` | Minimal | Byte buffer shape for future image/resource APIs. | Add common initializers, collection/subscript APIs, append/mutation, file loading once needed. |
| `Date` | Minimal | Comparable timestamp shape for AppKit-facing APIs. | Replace the placeholder clock with a real Windows clock bridge and add interval arithmetic. |
| `IndexSet` | Minimal | Selection ranges for table/list APIs. | Add closed ranges, range views, union/intersection, first/last indexes, and mutation helpers as table parity grows. |

## Maintenance Rules

- Prefer adding only the Foundation API needed by WinChocolate or by demo/client compatibility tests.
- Match Foundation names and call shapes even if the implementation is temporarily incomplete.
- Add a contract test for every new public shim member.
- Keep Windows-specific code behind the shim or backend boundary.
- Do not let app-facing WinChocolate APIs expose a type that will be hard to replace with real Foundation later.
- When real Foundation starts working, remove shim use in small steps and keep this file updated until `WinFoundation` can be deleted.

## Known Current Toolchain Failure

The current local failure is not caused by WinChocolate source alone. A plain real-Foundation build fails while importing Windows SDK/UCRT overlay module maps on the installed ARM64 Windows Swift toolchain. The canary command above is the project-level test for whether a newer toolchain has fixed that root issue.
