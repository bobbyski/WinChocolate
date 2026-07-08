/// LinChocolate — an AppKit-compatible Swift framework for Linux (GTK backend).
///
/// Sibling of WinChocolate: application code is written against Apple's AppKit
/// API (`NSApplication`, `NSWindow`, `NSButton`, …) and renders as native GTK
/// controls. Only the code behind `NativeControlBackend` is Linux-specific.
///
/// See ../Docs/LinChocolatePlan.md and ../Docs/LinChocolateSubstrate.md.
public enum LinChocolate {
    /// Framework version.
    public static let version = "0.0.1"
}
