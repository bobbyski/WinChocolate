// swift-tools-version: 6.0
//
// LinChocolate — sibling of WinChocolate (see ../Docs/LinChocolatePlan.md).
//
// Layout mirrors WinChocolate: an AppKit-shaped `LinChocolate` library with a
// narrow `NativeControlBackend` seam (GTK backend + in-memory backend), a demo,
// and executable contract tests. `CGTK` is the hand-written GTK4 C-interop.

import PackageDescription

let package = Package(
    name: "LinChocolate",
    products: [
        .library(name: "LinChocolate", targets: ["LinChocolate"]),
        .executable(name: "LinChocolateDemo", targets: ["LinChocolateDemo"])
    ],
    targets: [
        // Thin C-interop binding to GTK4, resolved via pkg-config `gtk4`.
        .systemLibrary(
            name: "CGTK",
            path: "Sources/CGTK",
            pkgConfig: "gtk4",
            providers: [.apt(["libgtk-4-dev"])]
        ),

        // AppKit-shaped API + the platform backends (GTK, in-memory).
        .target(
            name: "LinChocolate",
            dependencies: ["CGTK"],
            path: "Sources/LinChocolate"
        ),

        // The click-counter demo, written against the AppKit-shaped API.
        // Resources/ holds demo artwork, loaded by path at run time.
        .executableTarget(
            name: "LinChocolateDemo",
            dependencies: ["LinChocolate"],
            path: "Sources/LinChocolateDemo",
            exclude: ["Resources"]
        ),

        // Hermetic contract tests (in-memory backend, no display).
        .executableTarget(
            name: "LinChocolateContractTests",
            dependencies: ["LinChocolate"],
            path: "Tests/LinChocolateContractTests"
        ),

        // Original Ring 1 harness spike (raw GTK4 from Swift) — kept as the
        // minimal S1/S2 smoke test independent of the framework.
        .executableTarget(
            name: "GTKHelloSpike",
            dependencies: ["CGTK"],
            path: "Sources/GTKHelloSpike"
        )
    ]
)
