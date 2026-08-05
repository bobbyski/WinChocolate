// The Foundation seam — conditional C1 of the four sanctioned platform switches
// (see Docs/UnifiedChocolatePlan.md §"The four sanctioned conditionals").
//
// The shared AppKit core is written against one Foundation surface; only the
// implementation supplying it varies:
//
//   Windows  →  WinFoundation, because this Swift toolchain cannot compile real
//               `import Foundation` (see FOUNDATION_SHIMS.md and the toolchain
//               canary in NEEDS_HUMAN.md).
//   Linux    →  real corelibs-foundation, which is present and preferred.
//   macOS    →  real Foundation (the cross-check build).
//
// `USE_WIN_FOUNDATION` is defined by the manifest with
// `.when(platforms: [.windows])`, so this resolves without an `os()` test.
//
// Everything downstream — every control, view, and window in the core — sees the
// same spellings (`Date`, `URL`, `Data`, `Timer`, `NSRect`, …). Where the two
// implementations genuinely differ in behavior, the fix belongs in WinFoundation
// (the deliberately-compatible one), NOT in a second conditional up here. That
// reconciliation is the Foundation parity ledger, Phase 2 of the plan.

#if USE_REAL_FOUNDATION
@_exported import Foundation
#elseif USE_WIN_FOUNDATION
@_exported import WinFoundation
#else
@_exported import Foundation
#endif
