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
            name: "CWinFoundationCompat",
            path: "Sources/CWinFoundationCompat"
        ),
        .target(
            name: "WinFoundation",
            dependencies: ["CWinFoundationCompat"],
            swiftSettings: [
                // The current ARM64 Windows Swift 6 development toolchain
                // asserts in TransferNonSendable during optimized builds of
                // FileManager. WinFoundation is a compatibility shim whose
                // public surface predates strict concurrency, so build it in
                // Swift 5 language mode while Swift 6 clients continue to
                // validate the exposed API.
                .swiftLanguageMode(.v5)
            ],
            linkerSettings: [
                .linkedLibrary("Ole32"),
                .linkedLibrary("Shell32"),
                .linkedLibrary("Winhttp")
            ]
        )
    ]
)
