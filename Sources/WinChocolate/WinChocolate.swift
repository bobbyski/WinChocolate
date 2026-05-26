/// WinChocolate is an AppKit-shaped framework for Windows Swift applications.
///
/// The package intentionally exports Apple-compatible type names such as
/// `NSApplication`, `NSWindow`, `NSView`, and `NSButton` so an application can
/// move from `import AppKit` or `import Cocoa` to `import WinChocolate` with a
/// small surface of source changes. The public API follows AppKit naming while
/// native Windows behavior is isolated behind backend adapters.
///
/// ```text
/// App source
///    |
///    v
/// WinChocolate AppKit-compatible API
///    |
///    v
/// NativeControlBackend
///    |
///    v
/// Win32 HWND-backed controls
/// ```
public enum WinChocolate {
    /// Current framework version.
    public static let version = "0.1.0"
}
