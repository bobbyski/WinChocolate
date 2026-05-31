# Foundation On Windows Issue

## Summary

WinChocolate should use Foundation wherever AppKit-compatible APIs naturally use Foundation types. That is the right long-term direction for this project.

The current blocker is not WinChocolate code. On this machine, the installed Windows Swift toolchain cannot compile a minimal package that imports `Foundation`. The failure happens while Swift is building its Windows C overlay modules, before any WinChocolate source is involved.

Until the toolchain issue is resolved, WinChocolate must avoid `import Foundation` in ordinary Windows package builds. The project now has a repo-local `WinFoundation` target as a temporary compatibility bridge, not a desired permanent architecture.

## Current Bridge

The package defines a `WinFoundation` target with small source-compatible subsets of Foundation types that WinChocolate needs while the installed Windows toolchain cannot import real Foundation.

Current first-slice types:

- `URL`
- `Data`
- `Date`
- `IndexSet`

WinChocolate imports Foundation-shaped APIs through:

`C:\AIResearch\WinChocolate\Code\WinChocolate\Sources\WinChocolate\Runtime\FoundationBridge.swift`

The bridge logic is:

```swift
#if USE_REAL_FOUNDATION
@_exported import Foundation
#elseif USE_WIN_FOUNDATION
@_exported import WinFoundation
#else
@_exported import Foundation
#endif
```

`Package.swift` currently defines `USE_WIN_FOUNDATION` for Windows builds so `buildandrun.bat` keeps working with this local toolchain. To test a newer Windows Swift toolchain against real Foundation, build with:

```powershell
swift build -Xswiftc -DUSE_REAL_FOUNDATION
```

On Apple platforms or any non-Windows environment where no shim flag is defined, doing nothing uses real Foundation.

## Current Environment

Observed local Swift installation:

- Toolchain: `C:\Users\bobby\AppData\Local\Programs\Swift\Toolchains\0.0.0+Asserts`
- Platform SDK: `C:\Users\bobby\AppData\Local\Programs\Swift\Platforms\0.0.0`
- Default target in package builds: `aarch64-unknown-windows-msvc`
- Windows SDKs installed:
  - `10.0.22621.0`
  - `10.0.26100.0`
- Visual Studio installations present:
  - Visual Studio 2022
  - Visual Studio 18 Insiders

## Minimal Reproduction

I created a throwaway package at:

`C:\AIResearch\WinChocolate\Temp\FoundationProbe`

Minimal source:

```swift
import Foundation

let url = URL(fileURLWithPath: "C:\\AIResearch\\WinChocolate")
print(url.path)
```

Build command:

```powershell
& 'C:\Users\bobby\AppData\Local\Programs\Swift\Toolchains\0.0.0+Asserts\usr\bin\swift.exe' build
```

Result: build fails before compiling useful application logic.

Key diagnostic:

```text
could not build C module 'SwiftOverlayShims'
could not build module 'ucrt'
module '_visualc_intrinsics.arm.neon' requires feature 'armv7'
```

The failure path in the diagnostic is:

```text
Foundation import
SwiftOverlayShims
LibcOverlayShims.h
ucrt
wchar.h
intrin.h
arm_neon.h
vcruntime.modulemap
```

The important part is that the Windows UCRT header includes ARM NEON headers for ARM64, but Swift's installed `vcruntime.modulemap` maps `arm_neon.h` under an ARMv7-only module:

```text
explicit module arm {
  requires armv7
  header "armintr.h"

  explicit module neon {
    requires neon
    header "arm_neon.h"
  }
}
```

On ARM64, that makes Clang's module importer reject the import.

## Other Probes

### Visual Studio 2022 Environment

I tested the same reproduction through the Visual Studio 2022 ARM64 developer environment:

```cmd
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" arm64
swift build
```

That correctly switched the MSVC include path from VS 18 Insiders to VS 2022, but the same Swift SDK module-map failure remained.

### Older Windows SDK

I tested pinning the Visual Studio environment to Windows SDK `10.0.22621.0`.

That avoided the original exact header path, but failed earlier with:

```text
missing required module 'ucrt'
```

So simply selecting the older installed SDK was not a solution.

### x86_64 Target

I tested:

```powershell
swift build --triple x86_64-unknown-windows-msvc
```

That failed too, with a different C module problem:

```text
cyclic dependency in module 'ucrt': ucrt -> _visualc_intrinsics -> ucrt
```

So switching architecture is not an immediate solution with this installed toolchain.

### FoundationEssentials

I also tested:

```swift
import FoundationEssentials
```

Result:

```text
no such module 'FoundationEssentials'
```

So this installed toolchain does not expose `FoundationEssentials` as a separate module we can import as a lighter bridge.

## What Counts As "Basic Types"

Swift has two important layers here:

### Swift Standard Library

These are available without Foundation:

- `String`
- `Int`, `Double`, `Bool`
- `Array`
- `Dictionary`
- `Set`
- `Optional`
- ranges
- closures
- protocols
- generics
- basic concurrency language features, subject to toolchain support

WinChocolate can and does use these normally.

### Foundation

These require Foundation or Foundation-family modules:

- `URL`
- `Date`
- `Data`
- `UUID`
- `Calendar`
- `Locale`
- `TimeZone`
- `NotificationCenter`
- `Bundle`
- `RunLoop`
- `Timer`
- `IndexSet`
- `CharacterSet`
- `FileManager`
- `ProcessInfo`

These are the types AppKit-shaped APIs will increasingly want.

The current `URL` shim exists only because `NSPathControl.url` is naturally a Foundation `URL`. It is not the only Foundation type the project will need; it is just the first one we hit.

## Current WinChocolate State

Current local bridge:

`C:\AIResearch\WinChocolate\Code\WinChocolate\Sources\WinFoundation`

The first `URL` slice provides:

- `URL(fileURLWithPath:)`
- `path`
- `pathComponents`
- `lastPathComponent`
- `appendingPathComponent(_:)`

It is enough for the first `NSPathControl` slice, but it is not a replacement for real Foundation.

No ordinary Windows WinChocolate build currently imports real Foundation, because a single `import Foundation` breaks the build with the installed toolchain.

## Can We Fork Foundation?

Short answer: yes, we can create a `WinFoundation` bridge, and the project now has a first slice of that. Forking the full upstream Foundation source is probably not the first fix.

Apple/Swift's newer Foundation work lives in the open-source `swift-foundation` repository. That repository is real and relevant, but the failure we are seeing occurs before Foundation source code is the useful thing to debug. The compiler is failing while importing Swift's Windows SDK C overlay modules, specifically around UCRT and Visual C intrinsic module maps.

The current `WinFoundation` approach does not fork all of Foundation. It implements the specific types WinChocolate needs under familiar names, behind conditional compilation. That is repo-local, repeatable, and removable.

A full Foundation fork alone probably will not fix this exact failure unless one of these is also true:

- the fork is built in a way that avoids the failing Windows C overlay imports,
- the fork includes a workaround for this specific Windows ARM64 module-map issue,
- or we use a newer Swift toolchain where `FoundationEssentials` / `Foundation` already imports cleanly.

A local Foundation fork may become useful after we have a compatible Swift toolchain baseline. It is less attractive as the first move because we would be taking on upstream Foundation maintenance while the root issue appears to be in the installed Swift platform SDK/module-map layer.

## Better Solution Path

Recommended order:

1. Install or switch to a known-good official Swift for Windows toolchain where a minimal `import Foundation` package builds.
2. Keep the tiny `FoundationProbe` package as the acceptance test.
3. Once the probe passes, migrate WinChocolate away from local Foundation-shaped shims.
4. Replace `WinChocolate.URL` with real `Foundation.URL`.
5. Add Foundation-backed public APIs as soon as the toolchain permits:
   - `URL`
   - `IndexSet`
   - `NotificationCenter`
   - `Timer`
   - `RunLoop`
   - `Bundle`
   - `Date`
   - `Data`
   - `UUID`
6. Remove or quarantine compatibility shims so app code sees real Foundation types wherever AppKit expects them.

## Risk Of Patching The Installed SDK

It may be possible to patch:

```text
C:\Users\bobby\AppData\Local\Programs\Swift\Platforms\0.0.0\Windows.platform\Developer\SDKs\Windows.sdk\usr\share\vcruntime.modulemap
```

For example, one might try mapping `arm_neon.h` under the ARM64/aarch64 module instead of the ARMv7 module.

I do not recommend this as the project solution. It would be machine-local, fragile, and hard for another developer to reproduce. It might be acceptable only as a short experiment to confirm the root cause before filing/upstreaming a toolchain issue.

## Compatibility Notes

Swift modules are nominal. `Foundation.URL` and `WinFoundation.URL` are not the same binary type. In normal source, explicit `Foundation.URL` qualification is rare, so source compatibility should still be good for common Cocoa/AppKit-style app code that writes `URL(...)`.

This bridge is intended to be source-compatible enough for WinChocolate API work, not binary-compatible with real Foundation or third-party packages expecting Foundation's concrete types.

## Source Links

- Swift Foundation repository: https://github.com/swiftlang/swift-foundation
- Swift project repository: https://github.com/swiftlang/swift
- Swift language guide, basics: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/thebasics/
- Swift standard library documentation: https://developer.apple.com/documentation/swift

## Local Evidence

Local files and paths used during investigation:

- Repro package: `C:\AIResearch\WinChocolate\Temp\FoundationProbe`
- WinFoundation bridge target: `C:\AIResearch\WinChocolate\Code\WinChocolate\Sources\WinFoundation`
- Architecture note: `C:\AIResearch\WinChocolate\Code\WinChocolate\Docs\Architecture.md`
- Installed Swift module map: `C:\Users\bobby\AppData\Local\Programs\Swift\Platforms\0.0.0\Windows.platform\Developer\SDKs\Windows.sdk\usr\share\vcruntime.modulemap`

## Bottom Line

Foundation support is a requirement for WinChocolate. The current local toolchain cannot import Foundation at all, even in a minimal standalone package. We should treat the shim as temporary, keep the reproduction package around, and make "minimal Foundation import builds successfully" a prerequisite before expanding the API surface much deeper into Foundation-shaped AppKit behavior.
