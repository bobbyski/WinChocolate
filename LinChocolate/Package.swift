// swift-tools-version: 6.0
//
// LinChocolate — sibling of WinChocolate (see ../Docs/LinChocolatePlan.md).
//
// This is currently just the Phase L2 harness: a system-library binding to
// GTK4 and a hello-world spike that proves the Ring 1 inner loop
// (Mac + Docker + XQuartz). The AppKit-shaped API and the LinChocolate
// Native/Linux backend land in Phase L3; this package grows into them.

import PackageDescription

let package = Package(
    name: "LinChocolate",
    products: [
        .executable(name: "GTKHelloSpike", targets: ["GTKHelloSpike"])
    ],
    targets: [
        // Thin C-interop binding to GTK4, resolved via pkg-config `gtk4`.
        // This is the narrow, hand-written module map the substrate decision
        // (Docs/LinChocolateSubstrate.md §6) recommends starting from.
        .systemLibrary(
            name: "CGTK",
            path: "Sources/CGTK",
            pkgConfig: "gtk4",
            providers: [
                .apt(["libgtk-4-dev"])
            ]
        ),
        // Validation spike S1/S2: build against GTK4 from Swift and open a
        // window that renders on the Mac through XQuartz.
        .executableTarget(
            name: "GTKHelloSpike",
            dependencies: ["CGTK"],
            path: "Sources/GTKHelloSpike"
        )
    ]
)
