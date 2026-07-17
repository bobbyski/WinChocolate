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
        // CoreGraphics-shaped value types (plan Phase 13): pure geometry +
        // bitmap types with no platform dependencies. WinChocolate re-exports
        // it, so `CGRect`/`CGImage`-shaped source compiles unchanged; the
        // drawing-facing CG surface (CGContext/CGColor/CGPath over the native
        // backend) stays in WinChocolate's compat layer, where those types
        // genuinely are the AppKit objects.
        .target(
            name: "WinCoreGraphics",
            dependencies: [
                // CoreFoundation sits below CoreGraphics on Apple; here that is
                // WinFoundation, which supplies `Data`/`CFData` for
                // `CGDataProvider` and the bitmap `CGImage` initializer.
                .product(name: "WinFoundation", package: "WinFoundation")
            ],
            swiftSettings: [
                .swiftLanguageVersion(.v5)
            ]
        ),
        .target(
            name: "WinChocolate",
            dependencies: [
                "WinCoreGraphics",
                .product(name: "WinFoundation", package: "WinFoundation")
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
                .target(name: "WinChocolate", condition: .when(platforms: [.windows]))
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
                .target(name: "WinChocolate", condition: .when(platforms: [.windows]))
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
