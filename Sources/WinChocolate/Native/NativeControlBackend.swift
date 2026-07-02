/// Native toolbar item descriptor used by backend toolbar renderers.
public struct NativeToolbarItem: Equatable, Sendable {
    /// Stable item identifier.
    public var identifier: String

    /// Visible toolbar label.
    public var label: String

    /// Optional named image or symbol.
    public var imageName: String?

    /// Whether this item is a separator.
    public var isSeparator: Bool

    /// Whether this item consumes flexible toolbar space.
    public var isFlexibleSpace: Bool

    /// Width reserved for an overlaid custom toolbar view, when any.
    public var customViewWidth: CGFloat?

    /// Whether this item is enabled.
    public var isEnabled: Bool

    /// Creates a native toolbar item descriptor.
    public init(
        identifier: String,
        label: String,
        imageName: String? = nil,
        isSeparator: Bool = false,
        isFlexibleSpace: Bool = false,
        customViewWidth: CGFloat? = nil,
        isEnabled: Bool = true
    ) {
        self.identifier = identifier
        self.label = label
        self.imageName = imageName
        self.isSeparator = isSeparator
        self.isFlexibleSpace = isFlexibleSpace
        self.customViewWidth = customViewWidth
        self.isEnabled = isEnabled
    }
}

/// Native file dialog descriptor used by backend save/open panel renderers.
public struct NativeFileDialogOptions: Equatable, Sendable {
    /// File dialog interaction style.
    public enum Kind: Sendable {
        /// Choose one or more existing files or directories.
        case open

        /// Choose a destination file name for saving.
        case save
    }

    /// Whether this is an open or save dialog.
    public var kind: Kind

    /// Dialog title text.
    public var title: String

    /// Custom accept-button label, when the platform dialog supports one.
    public var prompt: String

    /// Initial directory path, when any.
    public var directoryPath: String?

    /// Initial file name, when any.
    public var fileName: String

    /// Allowed file-name extensions without dots, such as `["png", "jpg"]`.
    public var fileTypes: [String]

    /// Whether file names outside `fileTypes` are allowed.
    public var allowsOtherFileTypes: Bool

    /// Whether existing files can be chosen.
    public var canChooseFiles: Bool

    /// Whether directories can be chosen.
    public var canChooseDirectories: Bool

    /// Whether multiple entries can be chosen.
    public var allowsMultipleSelection: Bool

    /// Whether the dialog should offer directory creation.
    public var canCreateDirectories: Bool

    /// Whether hidden files should be shown.
    public var showsHiddenFiles: Bool

    /// Creates a native file dialog descriptor.
    public init(
        kind: Kind,
        title: String = "",
        prompt: String = "",
        directoryPath: String? = nil,
        fileName: String = "",
        fileTypes: [String] = [],
        allowsOtherFileTypes: Bool = true,
        canChooseFiles: Bool = true,
        canChooseDirectories: Bool = false,
        allowsMultipleSelection: Bool = false,
        canCreateDirectories: Bool = true,
        showsHiddenFiles: Bool = false
    ) {
        self.kind = kind
        self.title = title
        self.prompt = prompt
        self.directoryPath = directoryPath
        self.fileName = fileName
        self.fileTypes = fileTypes
        self.allowsOtherFileTypes = allowsOtherFileTypes
        self.canChooseFiles = canChooseFiles
        self.canChooseDirectories = canChooseDirectories
        self.allowsMultipleSelection = allowsMultipleSelection
        self.canCreateDirectories = canCreateDirectories
        self.showsHiddenFiles = showsHiddenFiles
    }
}

/// A path segment in view-local coordinates used by native drawing contexts.
public enum NativePathSegment: Equatable, Sendable {
    /// Begins a new subpath at a point.
    case move(NSPoint)

    /// Adds a straight line to a point.
    case line(NSPoint)

    /// Adds a cubic Bezier curve to an end point with two control points.
    case curve(to: NSPoint, control1: NSPoint, control2: NSPoint)

    /// Closes the current subpath.
    case close
}

/// Immediate-mode drawing surface handed to views during a native paint pass.
///
/// `NSBezierPath` and related AppKit drawing APIs reduce to these primitives
/// so backends can rasterize with their native graphics stack (GDI paths on
/// the classic backend, a recording context in tests).
public protocol NativeDrawingContext: AnyObject {
    /// Fills a path with a color using the nonzero winding rule.
    func fillPath(_ segments: [NativePathSegment], color: NSColor)

    /// Strokes a path with a color and line width.
    func strokePath(_ segments: [NativePathSegment], color: NSColor, lineWidth: CGFloat)

    /// Draws a single-line text run with its top-left corner at a point.
    func drawText(_ text: String, at point: NSPoint, color: NSColor, fontName: String, fontSize: CGFloat, bold: Bool)

    /// Draws an image file scaled to fill a rectangle.
    func drawImage(atPath path: String, in rect: NSRect)
}

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
    func createWindow(title: String, frame: NSRect, styleMask: NSWindow.StyleMask, usesMainMenu: Bool) -> NativeHandle

    /// Shows a previously created native window.
    func showWindow(_ handle: NativeHandle)

    /// Closes a previously created native window.
    func closeWindow(_ handle: NativeHandle)

    /// Registers the action to perform when a native top-level window closes.
    func registerWindowCloseAction(for handle: NativeHandle, action: @escaping () -> Void)

    /// Registers the action to perform when a native top-level window resizes.
    func registerWindowResizeAction(for handle: NativeHandle, action: @escaping (NSSize) -> Void)

    /// Destroys a previously created native child control.
    func destroyControl(_ handle: NativeHandle)

    /// Creates a native view-like child.
    func createView(frame: NSRect, parent: NativeHandle?) -> NativeHandle

    /// Creates a native push button child.
    func createButton(title: String, frame: NSRect, parent: NativeHandle?, isBordered: Bool) -> NativeHandle

    /// Creates a native checkbox child.
    func createCheckbox(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle

    /// Creates a native radio button child.
    func createRadioButton(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle

    /// Creates a native box child.
    func createBox(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle

    /// Creates a native text field child.
    func createTextField(text: String, frame: NSRect, parent: NativeHandle?, isEditable: Bool, isBordered: Bool) -> NativeHandle

    /// Creates a native secure text field child.
    func createSecureTextField(text: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle

    /// Creates a native multiline text view child.
    func createTextView(text: String, frame: NSRect, parent: NativeHandle?, isEditable: Bool) -> NativeHandle

    /// Creates a native pop-up button child.
    func createPopUpButton(items: [String], selectedIndex: Int, frame: NSRect, parent: NativeHandle?) -> NativeHandle

    /// Creates a native editable combo box child.
    func createComboBox(items: [String], text: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle

    /// Creates a native image-view child.
    func createImageView(description: String, imagePath: String?, frame: NSRect, parent: NativeHandle?) -> NativeHandle

    /// Creates a native tab-view child.
    func createTabView(items: [String], selectedIndex: Int, frame: NSRect, parent: NativeHandle?) -> NativeHandle

    /// Creates a native toolbar child.
    func createToolbar(items: [NativeToolbarItem], frame: NSRect, parent: NativeHandle?) -> NativeHandle

    /// Replaces native toolbar items.
    func setToolbarItems(_ items: [NativeToolbarItem], for handle: NativeHandle)

    /// Returns the native frame for a toolbar item after platform layout.
    func toolbarItemFrame(at index: Int, for handle: NativeHandle) -> NSRect?

    /// Registers the action to perform when a native toolbar item is activated.
    func registerToolbarAction(for handle: NativeHandle, action: @escaping (String) -> Void)

    /// Creates a native slider child.
    func createSlider(value: Double, minValue: Double, maxValue: Double, frame: NSRect, parent: NativeHandle?) -> NativeHandle

    /// Creates a native progress-indicator child.
    func createProgressIndicator(value: Double, minValue: Double, maxValue: Double, frame: NSRect, parent: NativeHandle?) -> NativeHandle

    /// Creates a native scroller child.
    func createScroller(value: Double, knobProportion: Double, isVertical: Bool, frame: NSRect, parent: NativeHandle?) -> NativeHandle

    /// Creates a native stepper child.
    func createStepper(value: Double, minValue: Double, maxValue: Double, increment: Double, frame: NSRect, parent: NativeHandle?) -> NativeHandle

    /// Creates a native date-picker child.
    func createDatePicker(date: Date, minDate: Date?, maxDate: Date?, frame: NSRect, parent: NativeHandle?) -> NativeHandle

    /// Creates a native scroll-view child.
    func createScrollView(frame: NSRect, parent: NativeHandle?, hasVerticalScroller: Bool, hasHorizontalScroller: Bool) -> NativeHandle

    /// Updates native scroll-view document and viewport geometry.
    func setScrollViewContentSize(_ contentSize: NSSize, viewportSize: NSSize, hasVerticalScroller: Bool, hasHorizontalScroller: Bool, for handle: NativeHandle)

    /// Updates the native scroll-view visible document origin.
    func setScrollViewContentOffset(_ offset: NSPoint, for handle: NativeHandle)

    /// Reads the native scroll-view visible document origin.
    func scrollViewContentOffset(for handle: NativeHandle) -> NSPoint

    /// Creates a native table-view child.
    func createTableView(columns: [String], rows: [[String]], selectedRow: Int, frame: NSRect, parent: NativeHandle?) -> NativeHandle

    /// Creates a native table-view child with explicit column widths.
    func createTableView(columns: [String], columnWidths: [CGFloat], rows: [[String]], selectedRow: Int, frame: NSRect, parent: NativeHandle?) -> NativeHandle

    /// Updates the visible text for a native control.
    func setText(_ text: String, for handle: NativeHandle)

    /// Reads the native text selection of an edit control in UTF-16 units.
    func textSelection(for handle: NativeHandle) -> (location: Int, length: Int)

    /// Updates the native text selection of an edit control and scrolls the
    /// caret into view.
    func setTextSelection(location: Int, length: Int, for handle: NativeHandle)

    /// Replaces the selected native text of an edit control as an undoable edit.
    func replaceSelectedText(_ text: String, for handle: NativeHandle)

    /// Updates whether a native edit control accepts keyboard editing while
    /// still allowing selection and scrolling.
    func setTextEditable(_ isEditable: Bool, for handle: NativeHandle)

    /// Updates the native frame for a window or control.
    func setFrame(_ frame: NSRect, for handle: NativeHandle)

    /// Raises a native child control above sibling child controls.
    func raiseControl(_ handle: NativeHandle)

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

    /// Updates whether a native control paints its own background.
    func setDrawsBackground(_ drawsBackground: Bool, for handle: NativeHandle)

    /// Updates a native control's tooltip text.
    func setToolTip(_ toolTip: String?, for handle: NativeHandle)

    /// Updates a native control's font.
    func setFont(_ font: NSFont?, for handle: NativeHandle)

    /// Updates a native image-view bitmap source.
    func setImagePath(_ imagePath: String?, description: String, for handle: NativeHandle)

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

    /// Replaces native combo-box items.
    func setComboBoxItems(_ items: [String], text: String, for handle: NativeHandle)

    /// Reads native combo-box text.
    func comboBoxText(for handle: NativeHandle) -> String

    /// Replaces native tab-view items.
    func setTabViewItems(_ items: [String], selectedIndex: Int, for handle: NativeHandle)

    /// Updates native tab-view selection.
    func setTabViewSelectedIndex(_ selectedIndex: Int, for handle: NativeHandle)

    /// Reads native tab-view selection.
    func tabViewSelectedIndex(for handle: NativeHandle) -> Int

    /// Updates native slider range.
    func setSliderRange(minValue: Double, maxValue: Double, for handle: NativeHandle)

    /// Updates native slider value.
    func setSliderValue(_ value: Double, for handle: NativeHandle)

    /// Reads native slider value.
    func sliderValue(for handle: NativeHandle) -> Double

    /// Updates native progress-indicator range.
    func setProgressIndicatorRange(minValue: Double, maxValue: Double, for handle: NativeHandle)

    /// Updates native progress-indicator value.
    func setProgressIndicatorValue(_ value: Double, for handle: NativeHandle)

    /// Updates native scroller state.
    func setScrollerValue(_ value: Double, knobProportion: Double, for handle: NativeHandle)

    /// Reads native scroller value.
    func scrollerValue(for handle: NativeHandle) -> Double

    /// Updates native stepper range.
    func setStepperRange(minValue: Double, maxValue: Double, increment: Double, for handle: NativeHandle)

    /// Updates native stepper value.
    func setStepperValue(_ value: Double, for handle: NativeHandle)

    /// Reads native stepper value.
    func stepperValue(for handle: NativeHandle) -> Double

    /// Updates native date-picker state.
    func setDatePickerDate(_ date: Date, minDate: Date?, maxDate: Date?, for handle: NativeHandle)

    /// Reads native date-picker value.
    func datePickerDate(for handle: NativeHandle) -> Date?

    /// Replaces native table rows.
    func setTableRows(_ rows: [[String]], selectedRow: Int, for handle: NativeHandle)

    /// Updates native table selection.
    func setTableSelectedRow(_ selectedRow: Int, for handle: NativeHandle)

    /// Scrolls a native table row into view when possible.
    func scrollTableRowToVisible(_ row: Int, for handle: NativeHandle)

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

    /// Registers the action to perform when a native view receives a right mouse-down event.
    func registerRightMouseDownAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void)

    /// Registers the action to perform when a native view receives a right mouse-up event.
    func registerRightMouseUpAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void)

    /// Registers the action to perform when a native view receives a tertiary mouse-down event.
    func registerOtherMouseDownAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void)

    /// Registers the action to perform when a native view receives a tertiary mouse-up event.
    func registerOtherMouseUpAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void)

    /// Registers the action to perform when a native view receives a scroll-wheel event.
    func registerScrollWheelAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void)

    /// Registers the action that paints custom view content during a native paint pass.
    func registerDrawAction(for handle: NativeHandle, action: @escaping (NativeDrawingContext, NSRect) -> Void)

    /// Requests a repaint of a native control.
    func invalidateControl(_ handle: NativeHandle)

    /// Registers the action to perform when a native view receives a mouse-dragged event.
    func registerMouseDraggedAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void)

    /// Registers the action to perform when a native view receives a key-down event.
    func registerKeyDownAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void)

    /// Registers the action to perform when a native view receives a key-up event.
    func registerKeyUpAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void)

    /// Runs a native modal alert.
    func runAlert(_ alert: NSAlert) -> NSApplication.ModalResponse

    /// Runs a native modal file dialog, returning chosen paths or `nil` on cancel.
    func runFileDialog(_ options: NativeFileDialogOptions) -> [String]?

    /// Runs a native modal color chooser, returning the chosen color or `nil` on cancel.
    func runColorChooser(initialColor: NSColor) -> NSColor?

    /// Runs a native modal font chooser, returning the chosen font or `nil` on cancel.
    func runFontChooser(initialFont: NSFont?) -> NSFont?

    /// Runs a nested modal event loop for a window, returning the stop code.
    func runModal(for handle: NativeHandle) -> Int

    /// Stops the innermost modal event loop with a response code.
    func stopModal(withCode code: Int)

    /// Updates whether a native progress indicator animates indeterminately.
    func setProgressIndicatorIndeterminate(_ isIndeterminate: Bool, animating: Bool, for handle: NativeHandle)

    /// Makes the named framework cursor the active pointer image.
    func setCursor(named name: String)

    /// Registers the handler consulted for menu key equivalents before key-down routing.
    func registerKeyEquivalentHandler(_ handler: @escaping (NSEvent) -> Bool)

    /// Runs a context menu at a screen point, returning the performed item or `nil` on cancel.
    func runContextMenu(_ menu: NSMenu, atScreenPoint point: NSPoint) -> NSMenuItem?
}
