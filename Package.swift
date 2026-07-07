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
                .define("USE_WIN_FOUNDATION", .when(platforms: [.windows]))
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
