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
    targets: [
        .target(
            name: "WinChocolate",
            linkerSettings: [
                .linkedLibrary("User32"),
                .linkedLibrary("Gdi32"),
                .linkedLibrary("Comctl32")
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
            linkerSettings: [
                .unsafeFlags(
                    ["-Xlinker", "/SUBSYSTEM:WINDOWS", "-Xlinker", "/ENTRY:mainCRTStartup"],
                    .when(platforms: [.windows])
                )
            ]
        )
    ]
)
