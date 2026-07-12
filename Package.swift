// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WinChocolate",
    products: [
        .library(
            name: "WinChocolate",
            targets: ["WinChocolate"]
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
        .target(
            name: "WinChocolate",
            dependencies: [
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
                .linkedLibrary("User32"),
                .linkedLibrary("Gdi32"),
                .linkedLibrary("Gdiplus"),
                .linkedLibrary("Comctl32"),
                .linkedLibrary("Comdlg32"),
                .linkedLibrary("Shell32"),
                .linkedLibrary("Ole32"),
                .linkedLibrary("Winmm"),
                .linkedLibrary("Advapi32"),
                .linkedLibrary("Dwmapi"),
                .linkedLibrary("UxTheme")
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
            dependencies: ["WinChocolate"],
            path: "Demo/DemoApplication",
            exclude: ["Resources"],
            linkerSettings: [
                .unsafeFlags(
                    ["-Xlinker", "/SUBSYSTEM:WINDOWS", "-Xlinker", "/ENTRY:mainCRTStartup"],
                    .when(platforms: [.windows])
                )
            ]
        )
    ]
)
