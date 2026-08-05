// The Linux façade over the shared AppKit core — the mirror of
// Sources/WinChocolate/WinChocolate.swift (Unified Chocolate, plan 1.3).
//
// It exists so a Linux app writes `import LinChocolate` and gets the same
// surface a Windows app gets from `import WinChocolate` and a Mac app gets from
// `import AppKit`. All three resolve to one implementation: ChocolateKit.
//
// This module MUST NOT be importable on Windows. The shared demo's import
// switch tests `canImport(LinChocolate)` *first*, so a LinChocolate that
// resolves on Windows would capture the Windows build and import a module whose
// backend cannot run there. The manifest therefore depends on this target only
// under `.when(platforms: [.linux])` — SwiftPM target dependencies are
// conditional even though targets themselves are not, which is what keeps
// `canImport(LinChocolate)` false on Windows.

@_exported import ChocolateKit
