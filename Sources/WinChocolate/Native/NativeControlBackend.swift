/// Native control creation and lifetime boundary.
///
/// `NSWindow`, `NSView`, and controls ask this backend for HWND-backed peers.
/// Keeping the Win32 layer behind a protocol lets the public AppKit-shaped API
/// stay testable and gives future backends a narrow substitution point.
public protocol NativeControlBackend: AnyObject {
    /// Starts the platform event loop.
    func runApplication()

    /// Requests application termination.
    func terminateApplication()

    /// Installs the application's main menu.
    func installMainMenu(_ menu: NSMenu?)

    /// Creates a native top-level window.
    func createWindow(title: String, frame: NSRect, styleMask: NSWindow.StyleMask) -> NativeHandle

    /// Shows a previously created native window.
    func showWindow(_ handle: NativeHandle)

    /// Closes a previously created native window.
    func closeWindow(_ handle: NativeHandle)

    /// Destroys a previously created native child control.
    func destroyControl(_ handle: NativeHandle)

    /// Creates a native view-like child.
    func createView(frame: NSRect, parent: NativeHandle?) -> NativeHandle

    /// Creates a native push button child.
    func createButton(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle

    /// Creates a native checkbox child.
    func createCheckbox(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle

    /// Creates a native radio button child.
    func createRadioButton(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle

    /// Creates a native text field child.
    func createTextField(text: String, frame: NSRect, parent: NativeHandle?, isEditable: Bool) -> NativeHandle

    /// Updates the visible text for a native control.
    func setText(_ text: String, for handle: NativeHandle)

    /// Updates the native frame for a window or control.
    func setFrame(_ frame: NSRect, for handle: NativeHandle)

    /// Updates whether a native control is hidden.
    func setHidden(_ isHidden: Bool, for handle: NativeHandle)

    /// Updates whether a native control is enabled.
    func setEnabled(_ isEnabled: Bool, for handle: NativeHandle)

    /// Updates a native button check state.
    func setButtonState(_ state: NSControl.StateValue, for handle: NativeHandle)

    /// Reads a native button check state.
    func buttonState(for handle: NativeHandle) -> NSControl.StateValue

    /// Registers the action to perform when a native control is activated.
    func registerAction(for handle: NativeHandle, action: @escaping () -> Void)

    /// Registers the action to perform when native text changes.
    func registerTextChangeAction(for handle: NativeHandle, action: @escaping (String) -> Void)

    /// Runs a native modal alert.
    func runAlert(_ alert: NSAlert) -> NSApplication.ModalResponse
}
