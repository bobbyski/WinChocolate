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
        // NOTE: the shared WinChocolate demo ("RealDemo") is a work-in-progress
        // port (plan L15) and is intentionally NOT wired into this package yet:
        // its source is a symlink into the parent repo (../Demo/DemoApplication),
        // which only resolves when the *repo root* is mounted — not under
        // run-linux.sh's LinChocolate-only mount. It also doesn't compile yet.
        // Build it during development from the repo root:
        //   docker run --rm -v "$PWD":/work -w /work/LinChocolate \
        //     linchocolate-dev swift build --target RealDemo
        // (re-enable the product/target below once it compiles cleanly.)
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

        // The shared WinChocolate demo source (symlinked from ../Demo), built
        // against LinChocolate — the AppKit-compat proof (plan L15). Kept out of
        // the default build for now; re-enable + add the product above once it
        // compiles (build it via the repo-root mount shown above meanwhile).
        // .executableTarget(
        //     name: "RealDemo",
        //     dependencies: ["LinChocolate"],
        //     path: "Sources/RealDemo"
        // ),

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
