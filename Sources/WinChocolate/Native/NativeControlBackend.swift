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

    /// Schedules work after the current native message dispatch returns.
    func dispatchAsync(_ action: @escaping () -> Void)

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

    /// Creates a native box child.
    func createBox(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle

    /// Creates a native text field child.
    func createTextField(text: String, frame: NSRect, parent: NativeHandle?, isEditable: Bool) -> NativeHandle

    /// Creates a native pop-up button child.
    func createPopUpButton(items: [String], selectedIndex: Int, frame: NSRect, parent: NativeHandle?) -> NativeHandle

    /// Creates a native scroll-view child.
    func createScrollView(frame: NSRect, parent: NativeHandle?, hasVerticalScroller: Bool, hasHorizontalScroller: Bool) -> NativeHandle

    /// Creates a native table-view child.
    func createTableView(columns: [String], rows: [[String]], selectedRow: Int, frame: NSRect, parent: NativeHandle?) -> NativeHandle

    /// Creates a native table-view child with explicit column widths.
    func createTableView(columns: [String], columnWidths: [CGFloat], rows: [[String]], selectedRow: Int, frame: NSRect, parent: NativeHandle?) -> NativeHandle

    /// Updates the visible text for a native control.
    func setText(_ text: String, for handle: NativeHandle)

    /// Updates the native frame for a window or control.
    func setFrame(_ frame: NSRect, for handle: NativeHandle)

    /// Updates whether a native control is hidden.
    func setHidden(_ isHidden: Bool, for handle: NativeHandle)

    /// Updates whether a native control is enabled.
    func setEnabled(_ isEnabled: Bool, for handle: NativeHandle)

    /// Moves native keyboard focus to a control.
    func focusControl(_ handle: NativeHandle)

    /// Updates a native control's text color.
    func setTextColor(_ color: NSColor?, for handle: NativeHandle)

    /// Updates a native control's background color.
    func setBackgroundColor(_ color: NSColor?, for handle: NativeHandle)

    /// Updates a native control's font.
    func setFont(_ font: NSFont?, for handle: NativeHandle)

    /// Updates a native button check state.
    func setButtonState(_ state: NSControl.StateValue, for handle: NativeHandle)

    /// Reads a native button check state.
    func buttonState(for handle: NativeHandle) -> NSControl.StateValue

    /// Replaces native pop-up button items.
    func setPopUpButtonItems(_ items: [String], selectedIndex: Int, for handle: NativeHandle)

    /// Updates native pop-up button selection.
    func setPopUpButtonSelectedIndex(_ selectedIndex: Int, for handle: NativeHandle)

    /// Reads native pop-up button selection.
    func popUpButtonSelectedIndex(for handle: NativeHandle) -> Int

    /// Replaces native table rows.
    func setTableRows(_ rows: [[String]], selectedRow: Int, for handle: NativeHandle)

    /// Updates native table selection.
    func setTableSelectedRow(_ selectedRow: Int, for handle: NativeHandle)

    /// Reads native table selection.
    func tableSelectedRow(for handle: NativeHandle) -> Int

    /// Reads the most recent native table row activation.
    func tableClickedRow(for handle: NativeHandle) -> Int

    /// Reads the most recent native table column activation.
    func tableClickedColumn(for handle: NativeHandle) -> Int

    /// Registers the action to perform when a native control is activated.
    func registerAction(for handle: NativeHandle, action: @escaping () -> Void)

    /// Registers the action to perform when native text changes.
    func registerTextChangeAction(for handle: NativeHandle, action: @escaping (String) -> Void)

    /// Registers the action to perform when a native view receives a mouse-down event.
    func registerMouseDownAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void)

    /// Registers the action to perform when a native view receives a mouse-up event.
    func registerMouseUpAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void)

    /// Registers the action to perform when a native view receives a mouse-moved event.
    func registerMouseMovedAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void)

    /// Registers the action to perform when a native view receives a key-down event.
    func registerKeyDownAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void)

    /// Registers the action to perform when a native view receives a key-up event.
    func registerKeyUpAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void)

    /// Runs a native modal alert.
    func runAlert(_ alert: NSAlert) -> NSApplication.ModalResponse
}
