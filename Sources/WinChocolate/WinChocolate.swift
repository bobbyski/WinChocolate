// WinChocolate — the Windows façade over the shared Chocolate core.
//
// Unified Chocolate, Phase 1 (see Docs/UnifiedChocolatePlan.md). The AppKit
// surface now lives once, in `ChocolateKit`, and is compiled for every platform;
// the Win32 and GTK backends sit behind the `NativeControlBackend` seam inside
// it. This target exists so that the public spelling never changed:
//
//     import WinChocolate        // still works, still Windows
//     #if canImport(WinChocolate) // still selects the Windows branch
//
// which is what protects the imports-only promise (an app differs from its macOS
// form by the import header alone) and every downstream consumer — ActiveUI,
// WinSwiftUI, WinSwiftData, the frozen demo, and the contract suite — none of
// which had to change.
//
// There is deliberately nothing else here: adding API to this target would
// create a Windows-only surface, which Rule One forbids. New AppKit surface
// belongs in ChocolateKit, and anything genuinely Win32 belongs behind the
// backend protocol.

@_exported import ChocolateKit
