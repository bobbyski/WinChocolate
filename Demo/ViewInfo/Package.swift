// swift-tools-version: 6.0

import PackageDescription

// ViewInfo is a standalone package on purpose: it depends on swift-syntax, and
// the root WinChocolate package must stay dependency-light for Windows builds.
let package = Package(
    name: "ViewInfo",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ViewInfo", targets: ["ViewInfo"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0")
    ],
    targets: [
        .executableTarget(
            name: "ViewInfo",
            dependencies: [
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftOperators", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax")
            ]
        )
    ]
)

