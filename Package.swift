// swift-tools-version: 6.0

import PackageDescription
import Foundation

// The WebAssembly backend is opt-in, and it has to be: `.when(platforms:)`
// gates whether a dependency is *used*, not whether it is *resolved*. SwiftPM
// resolves every dependency in this manifest on every platform, so naming
// SwiftDOM unconditionally breaks the Linux and Windows builds outright — the
// path does not exist inside the Linux container, and JavaScriptKit's manifest
// needs a newer toolchain than that container carries.
//
// A manifest is a Swift program, so the honest fix is to not name them at all
// unless asked. `build-wasm.sh` sets this; nothing else does, which is what
// keeps `buildandrun.bat`, `run-wsl.bat` and `./run-linux.sh` untouched.
let wasmBackendEnabled = ProcessInfo.processInfo.environment["CHOCOLATE_WASM"] != nil

let wasmPackages: [Package.Dependency] = wasmBackendEnabled ? [
    // Drives the browser backend (Docs/WASMChocolatePlan.md).
    //
    // A path dependency is a spike decision, not a shipping one: it is
    // machine-specific, so a fresh clone cannot build the WASM backend.
    // Publishing a tag is the gate item before this leaves the branch.
    .package(path: "/Users/bobby/AIResearch/WASM/Code/SwiftDOM"),
    // SwiftDOM already brings JavaScriptKit in, but `JavaScriptEventLoop` is a
    // separate product of it, and a product can only be requested from a
    // package this manifest names directly.
    .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.50.2")
] : []

// The façade is exported as a product only when the backend is asked for, for
// the same reason the dependencies are: a product costs nothing to declare, but
// declaring it unconditionally puts `WASMChocolate` into `swift build`'s set of
// things to build on Windows and Linux, where it has no business existing.
//
// Downstream packages need the product because a *target* dependency is only
// expressible inside this package — which is why the demos below can use one
// and ActiveUI cannot. ActiveUI's browser build sets `CHOCOLATE_WASM` alongside
// its own `ACTIVEUI_WASM` so this manifest, evaluated in the same environment,
// offers the product its manifest asks for.
let wasmProducts: [Product] = wasmBackendEnabled ? [
    .library(
        name: "WASMChocolate",
        targets: ["WASMChocolate"]
    )
] : []

let wasmCoreDependencies: [Target.Dependency] = wasmBackendEnabled ? [
    .product(name: "SwiftDOM", package: "SwiftDOM",
             condition: .when(platforms: [.wasi])),
    // What lets `Task` and `@MainActor` run on the browser's event loop.
    .product(name: "JavaScriptEventLoop", package: "JavaScriptKit",
             condition: .when(platforms: [.wasi]))
] : []

// SwiftPM parses .pc files itself and rejects compiler-driver flags such as
// GTK's transitive -pthread/SSE entries. Point it at package-owned equivalent
// metadata with only include and link flags. #filePath keeps this relocatable.
let packageRoot = String(#filePath.dropLast("Package.swift".count))
let gtkPkgConfig = packageRoot + "Sources/CGTK/gtk4-winchocolate.pc"

let package = Package(
    name: "WinChocolate",
    // Apple-only deployment floor, and only the demos ever build here: there is
    // no Chocolate for macOS — ChocolateKit *is* a reimplementation of AppKit
    // and CoreGraphics, so on macOS the demos compile against the real ones as
    // the control group. Without a floor SwiftPM assumes 10.13 and the demos'
    // `MainActor` use fails to compile. `platforms:` constrains Apple platforms
    // only; the Windows and Linux builds are unaffected by this line.
    platforms: [.macOS(.v13)],
    products: [
        .library(
            name: "WinChocolate",
            targets: ["WinChocolate"]
        ),
        .library(
            name: "LinChocolate",
            targets: ["LinChocolate"]
        ),
        .library(
            name: "WinCoreGraphics",
            targets: ["WinCoreGraphics"]
        ),
        .executable(
            name: "WinChocolateDemo",
            targets: ["WinChocolateDemo"]
        )
    ] + wasmProducts,
    dependencies: [
        // WinFoundation is a standalone nested package (plan 7.10) so
        // downstream projects can depend on it without pulling in the
        // AppKit layer. WinSwiftData path-depends on it directly.
        .package(path: "WinFoundation")
    ] + wasmPackages,
    targets: [
        // --- GTK interop (Linux only) -------------------------------------
        //
        // Unified Chocolate, Phase 0 (see Docs/UnifiedChocolatePlan.md): the
        // GTK targets live in the root manifest so one package can build the
        // Win32 and GTK backends from one shared core. They are only ever
        // *depended on* under `.when(platforms: [.linux])`, so `pkg-config
        // gtk4` — which cannot resolve on Windows — is never consulted here.
        .systemLibrary(
            name: "CGTK",
            path: "Sources/CGTK",
            pkgConfig: gtkPkgConfig,
            providers: [.apt(["libgtk-4-dev"])]
        ),
        // C wrappers for deliberately-used deprecated GTK calls, so the Swift
        // side stays warning-clean.
        .target(
            name: "CGTKCompat",
            dependencies: ["CGTK"],
            path: "Sources/CGTKCompat",
            linkerSettings: [
                .linkedLibrary("X11", .when(platforms: [.linux]))
            ]
        ),
        .target(
            name: "CWin32Compat",
            path: "Sources/CWin32Compat"
        ),

        // CoreGraphics-shaped value types (plan Phase 13): pure geometry +
        // bitmap types with no platform dependencies. WinChocolate re-exports
        // it, so `CGRect`/`CGImage`-shaped source compiles unchanged; the
        // drawing-facing CG surface (CGContext/CGColor/CGPath over the native
        // backend) stays in WinChocolate's compat layer, where those types
        // genuinely are the AppKit objects.
        .target(
            name: "WinCoreGraphics",
            dependencies: [
                // CoreFoundation sits below CoreGraphics on Apple; on Windows
                // that is WinFoundation, which supplies `Data`/`CFData` for
                // `CGDataProvider` and the bitmap `CGImage` initializer.
                // Windows-only, for the same reason as the core's dependency
                // below: on Linux real Foundation already defines `Data`, and
                // both being visible makes every use ambiguous.
                .product(name: "WinFoundation", package: "WinFoundation",
                         condition: .when(platforms: [.windows]))
            ],
            swiftSettings: [
                // Conditional C1 (the Foundation seam) reaches down here too:
                // on Windows this module owns CGFloat/CGPoint/CGSize/CGRect,
                // and everywhere else it defers to the platform's own.
                .define("USE_WIN_FOUNDATION", .when(platforms: [.windows])),
                .swiftLanguageMode(.v5)
            ]
        ),
        // The shared AppKit core. One surface, every platform; the Win32 and
        // GTK backends live behind the NativeControlBackend seam inside it.
        // `WinChocolate` (below) is a façade over this, so the public import
        // spelling is unchanged.
        .target(
            name: "ChocolateKit",
            dependencies: [
                "WinCoreGraphics",
                // Windows-only. On Linux and macOS real Foundation is present
                // and preferred (see Runtime/FoundationBridge.swift), and a
                // WinFoundation visible *alongside* it makes every `Data`,
                // `URL`, and `NSRange` in the core ambiguous for type lookup.
                .product(name: "WinFoundation", package: "WinFoundation",
                         condition: .when(platforms: [.windows])),
                // Linux-only: the GTK backend's C interop. Conditional so the
                // Windows build never resolves `pkg-config gtk4`.
                .target(name: "CGTK", condition: .when(platforms: [.linux])),
                .target(name: "CGTKCompat", condition: .when(platforms: [.linux])),
                .target(name: "CWin32Compat", condition: .when(platforms: [.windows]))
                // WASI-only, and only when CHOCOLATE_WASM asked for it: the
                // browser backend's substrate, invisible to every other build.
            ] + wasmCoreDependencies,
            swiftSettings: [
                .define("USE_WIN_FOUNDATION", .when(platforms: [.windows])),
                // The framework is single-threaded by design (everything
                // runs on the Win32 UI thread), and its delegate protocols
                // are @MainActor to match AppKit's annotations for strict-
                // concurrency consumers. Internally that pairing would
                // demand isolation ceremony on every nonisolated dispatch
                // site, so the framework itself builds in Swift 5 mode;
                // consumers get the full Swift 6 annotations either way.
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedLibrary("User32", .when(platforms: [.windows])),
                .linkedLibrary("Gdi32", .when(platforms: [.windows])),
                .linkedLibrary("Gdiplus", .when(platforms: [.windows])),
                .linkedLibrary("Comctl32", .when(platforms: [.windows])),
                .linkedLibrary("Comdlg32", .when(platforms: [.windows])),
                .linkedLibrary("Shell32", .when(platforms: [.windows])),
                .linkedLibrary("Ole32", .when(platforms: [.windows])),
                .linkedLibrary("Winmm", .when(platforms: [.windows])),
                .linkedLibrary("Advapi32", .when(platforms: [.windows])),
                .linkedLibrary("Dwmapi", .when(platforms: [.windows])),
                .linkedLibrary("UxTheme", .when(platforms: [.windows]))
            ]
        ),
        // The Windows façade: `@_exported import ChocolateKit` and nothing else,
        // so `import WinChocolate` / `canImport(WinChocolate)` keep working.
        .target(
            name: "WinChocolate",
            dependencies: ["ChocolateKit"],
            path: "Sources/WinChocolate",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        // The matching Linux façade (plan 1.3). It is only ever *depended on*
        // under `.when(platforms: [.linux])` — see the demo target below —
        // because the shared demo tests `canImport(LinChocolate)` first, and a
        // LinChocolate that resolved on Windows would capture the Windows build.
        .target(
            name: "LinChocolate",
            dependencies: ["ChocolateKit"],
            path: "Sources/LinChocolate",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        // The WebAssembly façade (Docs/WASMChocolatePlan.md). Same rule as
        // LinChocolate: only ever depended on for its own platform.
        .target(
            name: "WASMChocolate",
            dependencies: ["ChocolateKit"],
            path: "Sources/WASMChocolate",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .executableTarget(
            name: "WinChocolateContractTests",
            dependencies: ["WinChocolate"],
            path: "Tests/WinChocolateContractTests"
            // Swift 6 mode: top-level code runs on the main actor, matching
            // the @MainActor test functions and delegate conformances (the
            // suite is single-threaded on the main thread).
        ),
        .executableTarget(
            name: "WinChocolateDemo",
            // On Windows the demo runs over WinChocolate; on macOS it builds
            // against the real AppKit instead (plan Phase 16, the rendering
            // cross-check), so the framework dependency is Windows-only.
            dependencies: [
                .target(name: "WinChocolate", condition: .when(platforms: [.windows])),
                .target(name: "LinChocolate", condition: .when(platforms: [.linux])),
                // The browser build of the same frozen demo
                // (Docs/WASMChocolatePlan.md, phase P3). Same rule as the other
                // two: depended on only for its own platform, so `canImport`
                // in the demo's import switch cannot pick the wrong framework.
                .target(name: "WASMChocolate", condition: .when(platforms: [.wasi]))
            ],
            path: "Demo/DemoApplication",
            exclude: ["Resources"],
            linkerSettings: [
                .unsafeFlags(
                    ["-Xlinker", "/SUBSYSTEM:WINDOWS", "-Xlinker", "/ENTRY:mainCRTStartup"],
                    .when(platforms: [.windows])
                )
            ]
        ),
        // The spike's shared proof app (Docs/RADICALLY_DIFFERENT_UI_SPIKE.md):
        // one click counter, unmodified, on every backend. Same tri-target rule
        // as the other demos — on macOS it builds against real AppKit, which is
        // the control group the other backends are measured against.
        .executableTarget(
            name: "CounterDemo",
            dependencies: [
                .target(name: "WinChocolate", condition: .when(platforms: [.windows])),
                .target(name: "LinChocolate", condition: .when(platforms: [.linux])),
                .target(name: "WASMChocolate", condition: .when(platforms: [.wasi]))
            ],
            path: "Demo/CounterDemo",
            linkerSettings: [
                .unsafeFlags(
                    ["-Xlinker", "/SUBSYSTEM:WINDOWS", "-Xlinker", "/ENTRY:mainCRTStartup"],
                    .when(platforms: [.windows])
                )
            ]
        ),
        // The document-architecture proof (Docs/NSDOCUMENT_PLAN.md, Phase 7):
        // a Windows-Notepad-shaped editor as ONE source on every backend. Same
        // tri-target rule as the other demos — on macOS it builds against real
        // AppKit, which is the control group.
        .executableTarget(
            name: "ChocolateNoteDemo",
            dependencies: [
                .target(name: "WinChocolate", condition: .when(platforms: [.windows])),
                .target(name: "LinChocolate", condition: .when(platforms: [.linux])),
                .target(name: "WASMChocolate", condition: .when(platforms: [.wasi]))
            ],
            path: "Demo/ChocolateNoteDemo",
            linkerSettings: [
                .unsafeFlags(
                    ["-Xlinker", "/SUBSYSTEM:WINDOWS", "-Xlinker", "/ENTRY:mainCRTStartup"],
                    .when(platforms: [.windows])
                )
            ]
        ),
        // A separate app that exercises the run loop and timers (request #7).
        // Same tri-target rule as the main demo; the frozen demo is untouched.
        .executableTarget(
            name: "RunLoopDemo",
            dependencies: [
                .target(name: "WinChocolate", condition: .when(platforms: [.windows])),
                .target(name: "LinChocolate", condition: .when(platforms: [.linux]))
            ],
            path: "Demo/RunLoopDemo",
            linkerSettings: [
                .unsafeFlags(
                    ["-Xlinker", "/SUBSYSTEM:WINDOWS", "-Xlinker", "/ENTRY:mainCRTStartup"],
                    .when(platforms: [.windows])
                )
            ]
        )
    ]
)
