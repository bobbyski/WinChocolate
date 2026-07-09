import Foundation

/// The substitution point between LinChocolate's AppKit-shaped API and the
/// platform. The GTK backend is the real one; the in-memory backend keeps the
/// API testable without a display.
///
/// This is intentionally a *narrow* slice — just the app/window/view/button/
/// label surface Phase L3 needs. It mirrors the shape and naming of
/// WinChocolate's much larger `NativeControlBackend` so that, once WinChocolate
/// stabilizes, the platform-neutral parts of both can be hoisted into one
/// shared core (LinChocolatePlan Phase L6) mechanically rather than by rewrite.
public protocol NativeControlBackend: AnyObject {

    // MARK: Application lifecycle
    /// Runs the platform event loop until the application terminates.
    func runApplication()
    /// Stops the event loop started by `runApplication()`.
    func terminateApplication()

    // MARK: Windows
    /// Creates a top-level window and returns its handle.
    func createWindow(title: String, frame: NSRect, styleMask: NSWindow.StyleMask) -> NativeHandle
    /// Installs `view` as the window's content area.
    func setContentView(_ view: NativeHandle, for window: NativeHandle)
    /// Shows and orders the window to the front.
    func showWindow(_ handle: NativeHandle)
    /// Updates a window's title-bar text.
    func setWindowTitle(_ title: String, for handle: NativeHandle)
    /// Registers the action to run when the window is closed by the user.
    func registerWindowCloseAction(for handle: NativeHandle, action: @escaping () -> Void)

    // MARK: Views & controls
    /// Creates a container view (absolute child placement, like AppKit frames).
    func createView(frame: NSRect) -> NativeHandle
    /// Creates a push button.
    func createButton(title: String, frame: NSRect) -> NativeHandle
    /// Creates a static text label.
    func createLabel(text: String, frame: NSRect) -> NativeHandle
    /// Creates an editable single-line text field.
    func createTextField(text: String, frame: NSRect) -> NativeHandle
    /// Creates a masked (password) text field.
    func createSecureTextField(text: String, frame: NSRect) -> NativeHandle
    /// Creates a search field.
    func createSearchField(text: String, frame: NSRect) -> NativeHandle
    /// Creates an editable combo box (text field + dropdown list).
    func createComboBox(items: [String], text: String, frame: NSRect) -> NativeHandle
    /// Creates a checkbox (labelled on/off toggle).
    func createCheckbox(title: String, frame: NSRect) -> NativeHandle
    /// Creates a radio button (group for mutual exclusion via `groupRadioButtons`).
    func createRadioButton(title: String, frame: NSRect) -> NativeHandle
    /// Groups radio buttons so at most one is selected at a time.
    func groupRadioButtons(_ handles: [NativeHandle])
    /// Creates a horizontal slider over `[minValue, maxValue]`.
    func createSlider(value: Double, minValue: Double, maxValue: Double, frame: NSRect) -> NativeHandle
    /// Creates a determinate progress indicator over `[minValue, maxValue]`.
    func createProgressIndicator(value: Double, minValue: Double, maxValue: Double, frame: NSRect) -> NativeHandle
    /// Creates a pop-up (dropdown) button.
    func createPopUpButton(items: [String], selectedIndex: Int, frame: NSRect) -> NativeHandle
    /// Places `child` inside `parent` at the child's frame origin.
    func addSubview(_ child: NativeHandle, to parent: NativeHandle)

    // MARK: Mutators
    /// Updates the text/title shown by a control.
    func setText(_ text: String, for handle: NativeHandle)
    /// Updates a control's frame (size, and position within its parent).
    func setFrame(_ frame: NSRect, for handle: NativeHandle)
    /// Enables or disables a control.
    func setEnabled(_ isEnabled: Bool, for handle: NativeHandle)
    /// Sets a checkbox/radio's on/off state.
    func setButtonState(_ on: Bool, for handle: NativeHandle)
    /// Sets a slider's or progress indicator's value.
    func setDoubleValue(_ value: Double, for handle: NativeHandle)
    /// Sets a pop-up button's selected item index.
    func setSelectedIndex(_ index: Int, for handle: NativeHandle)
    /// Releases the native resources for a control.
    func destroyControl(_ handle: NativeHandle)

    // MARK: Events
    /// Registers the action to perform when a control fires (e.g. a click).
    func registerAction(for handle: NativeHandle, action: @escaping () -> Void)
    /// Registers the action to perform when a text field's contents change.
    func setTextChangeAction(for handle: NativeHandle, action: @escaping (String) -> Void)
    /// Registers the action to perform when a checkbox/radio toggles; passes the new state.
    func setToggleAction(for handle: NativeHandle, action: @escaping (Bool) -> Void)
    /// Registers the action to perform when a slider's value changes; passes the value.
    func setValueChangeAction(for handle: NativeHandle, action: @escaping (Double) -> Void)
    /// Registers the action to perform when a pop-up's selection changes; passes the index.
    func setSelectionChangeAction(for handle: NativeHandle, action: @escaping (Int) -> Void)
}
