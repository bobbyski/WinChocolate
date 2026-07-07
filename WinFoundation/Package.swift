// swift-tools-version: 6.0

import PackageDescription

// WinFoundation: the Foundation-shaped shim library for Windows Swift
// toolchains that cannot import real Foundation (see FOUNDATION_SHIMS.md in
// the WinChocolate repo root). A standalone package (plan 7.10) so downstream
// projects — WinChocolate itself, WinSwiftData — can depend on it cleanly by
// path. The product name and its public Date/UUID/Data API pairs are under a
// downstream stability contract (Docs/ProjectPlan.md, Phase 7 intro).
let package = Package(
    name: "WinFoundation",
    products: [
        .library(
            name: "WinFoundation",
            targets: ["WinFoundation"]
        )
    ],
    targets: [
        .target(
            name: "WinFoundation",
            linkerSettings: [
                .linkedLibrary("Ole32"),
                .linkedLibrary("Shell32")
            ]
        )
    ]
)
