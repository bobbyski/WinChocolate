// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "WinChocolate",
    products: [
        .library(
            name: "WinFoundation",
            targets: ["WinFoundation"]
        ),
        .library(
            name: "WinChocolate",
            targets: ["WinChocolate"]
        ),
        .executable(
            name: "WinChocolateDemo",
            targets: ["WinChocolateDemo"]
        )
    ],
    targets: [
        .target(
            name: "WinFoundation",
            linkerSettings: [
                .linkedLibrary("Ole32"),
                .linkedLibrary("Shell32")
            ]
        ),
        .target(
            name: "WinChocolate",
            dependencies: ["WinFoundation"],
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
                .linkedLibrary("Ole32")
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
