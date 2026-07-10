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
    /// Installs `view` as the single content child of `window` — also used for
    /// other single-child containers (box, scroll view), routed by kind.
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
    /// Creates a stepper (numeric up/down) over `[minValue, maxValue]`.
    func createStepper(value: Double, minValue: Double, maxValue: Double, stepSize: Double, frame: NSRect) -> NativeHandle
    /// Creates a determinate level indicator over `[minValue, maxValue]`.
    func createLevelIndicator(value: Double, minValue: Double, maxValue: Double, frame: NSRect) -> NativeHandle
    /// Creates a multi-line, scrollable, editable text view.
    func createTextView(text: String, frame: NSRect) -> NativeHandle
    /// Creates a calendar-style date picker showing `date`.
    func createDatePicker(date: Date, frame: NSRect) -> NativeHandle
    /// Creates a color well (swatch button that opens a color chooser).
    func createColorWell(color: NSColor, frame: NSRect) -> NativeHandle
    /// Creates a tabbed page container.
    func createTabView(frame: NSRect) -> NativeHandle
    /// Appends `page` as a new tab titled `label`. `setSelectedIndex` switches
    /// tabs; `setSelectionChangeAction` reports user tab switches.
    func addTabPage(_ page: NativeHandle, label: String, to tabView: NativeHandle)
    /// Creates a titled group box (`setContentView` installs its content).
    func createBox(title: String, frame: NSRect) -> NativeHandle
    /// Creates a scroll container (`setContentView` installs its document view).
    func createScrollView(frame: NSRect) -> NativeHandle
    /// Creates a two-pane split container. `vertical` follows AppKit: a
    /// vertical *divider*, panes side by side.
    func createSplitView(vertical: Bool, frame: NSRect) -> NativeHandle
    /// Adds the next pane (first call = leading/top, second = trailing/bottom).
    func addSplitPane(_ pane: NativeHandle, to splitView: NativeHandle)
    /// Moves the split divider to `position` (pixels from the leading edge).
    func setDividerPosition(_ position: Double, for splitView: NativeHandle)
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
    /// Sets a date picker's date.
    func setDateValue(_ date: Date, for handle: NativeHandle)
    /// Sets a color well's color.
    func setColor(_ color: NSColor, for handle: NativeHandle)
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
    /// Registers the action to perform when a date picker's date changes.
    func setDateChangeAction(for handle: NativeHandle, action: @escaping (Date) -> Void)
    /// Registers the action to perform when a color well's color changes.
    func setColorChangeAction(for handle: NativeHandle, action: @escaping (NSColor) -> Void)
}
