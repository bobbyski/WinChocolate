#if os(Windows)
/// Win32 implementation of WinChocolate's native backend.
///
/// This is the platform boundary where AppKit-shaped controls become native
/// Windows controls. The current implementation is intentionally conservative:
/// it establishes the backend contract while the detailed HWND message bridge is
/// filled in type by type.
public final class Win32NativeControlBackend: NativeControlBackend {
    private let fallback = InMemoryNativeControlBackend()

    /// Creates a Win32 backend.
    public init() {}

    /// Starts the native event loop.
    public func runApplication() {
        fallback.runApplication()
    }

    /// Requests native application termination.
    public func terminateApplication() {
        fallback.terminateApplication()
    }

    /// Installs the native application menu bar.
    public func installMainMenu(_ menu: NSMenu?) {
        fallback.installMainMenu(menu)
    }

    /// Creates a native top-level window.
    public func createWindow(title: String, frame: NSRect, styleMask: NSWindow.StyleMask) -> NativeHandle {
        fallback.createWindow(title: title, frame: frame, styleMask: styleMask)
    }

    /// Shows a native window.
    public func showWindow(_ handle: NativeHandle) {
        fallback.showWindow(handle)
    }

    /// Closes a native window.
    public func closeWindow(_ handle: NativeHandle) {
        fallback.closeWindow(handle)
    }

    /// Creates a native view child.
    public func createView(frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        fallback.createView(frame: frame, parent: parent)
    }

    /// Creates a native button child.
    public func createButton(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        fallback.createButton(title: title, frame: frame, parent: parent)
    }

    /// Creates a native text field child.
    public func createTextField(text: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        fallback.createTextField(text: text, frame: frame, parent: parent)
    }
}
#endif
