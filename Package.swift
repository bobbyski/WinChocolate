// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WinChocolate",
    products: [
        .library(
            name: "WinChocolate",
            targets: ["WinChocolate"]
        ),
        .library(
            name: "WinCoreGraphics",
            targets: ["WinCoreGraphics"]
        ),
        .executable(
            name: "WinChocolateDemo",
            targets: ["WinChocolateDemo"]
        )
    ],
    dependencies: [
        // WinFoundation is a standalone nested package (plan 7.10) so
        // downstream projects can depend on it without pulling in the
        // AppKit layer. WinSwiftData path-depends on it directly.
        .package(path: "WinFoundation")
    ],
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
            path: "LinChocolate/Sources/CGTK",
            pkgConfig: "gtk4",
            providers: [.apt(["libgtk-4-dev"])]
        ),
        // C wrappers for deliberately-used deprecated GTK calls, so the Swift
        // side stays warning-clean.
        .target(
            name: "CGTKCompat",
            dependencies: ["CGTK"],
            path: "LinChocolate/Sources/CGTKCompat",
            linkerSettings: [
                .linkedLibrary("X11", .when(platforms: [.linux]))
            ]
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
                .swiftLanguageVersion(.v5)
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
                .target(name: "CGTKCompat", condition: .when(platforms: [.linux]))
            ],
            swiftSettings: [
                .define("USE_WIN_FOUNDATION", .when(platforms: [.windows])),
                // The framework is single-threaded by design (everything
                // runs on the Win32 UI thread), and its delegate protocols
                // are @MainActor to match AppKit's annotations for strict-
                // concurrency consumers. Internally that pairing would
                // demand isolation ceremony on every nonisolated dispatch
                // site, so the framework itself builds in Swift 5 mode;
                // consumers get the full Swift 6 annotations either way.
                .swiftLanguageVersion(.v5)
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
                .swiftLanguageVersion(.v5)
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
                .swiftLanguageVersion(.v5)
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
                .target(name: "LinChocolate", condition: .when(platforms: [.linux]))
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
