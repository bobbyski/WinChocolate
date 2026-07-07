/// Backend-neutral scroller part, mapped from the platform scroll gesture.
///
/// This lets the AppKit-facing `NSScroller.hitPart` reflect what the user
/// actually touched (a line arrow, a page area, or the knob) without the
/// control layer knowing about Win32 scroll notification codes.
public enum NativeScrollerPart: Sendable {
    case none
    case decrementLine
    case decrementPage
    case knob
    case incrementPage
    case incrementLine
}

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

    /// Window frame the dialog should attach to, when presenting as a sheet.
    ///
    /// The classic backend positions the native dialog under this frame's
    /// title area; `nil` lets the platform choose the position.
    public var anchorFrame: NSRect?

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
        showsHiddenFiles: Bool = false,
        anchorFrame: NSRect? = nil
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
        self.anchorFrame = anchorFrame
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

/// One hover cursor region of a native view.
public struct NativeCursorRegion: Equatable {
    /// The region rectangle in view-local coordinates.
    public var rect: NSRect

    /// The framework cursor name shown while hovering the rectangle.
    public var cursorName: String

    /// Creates a cursor region.
    public init(rect: NSRect, cursorName: String) {
        self.rect = rect
        self.cursorName = cursorName
    }
}

/// One color stop of a linear gradient in backend drawing terms.
public struct NativeGradientStop: Equatable {
    /// The stop color.
    public var color: NSColor

    /// The stop position from 0 (start point) to 1 (end point).
    public var location: CGFloat

    /// Creates a gradient stop.
    public init(color: NSColor, location: CGFloat) {
        self.color = color
        self.location = location
    }
}

/// Immediate-mode drawing surface handed to views during a native paint pass.
///
/// The payload of a native drag: plain text and/or absolute file paths.
public struct NativeDropContent: Equatable, Sendable {
    /// The dragged plain text, when any.
    public let text: String?

    /// The dragged absolute file paths, when any.
    public let filePaths: [String]

    /// Creates drop content.
    public init(text: String?, filePaths: [String]) {
        self.text = text
        self.filePaths = filePaths
    }
}

/// The callbacks a registered drop target receives during a native drag.
///
/// Return `true` from `entered`/`moved`/`performed` to accept (a copy
/// operation); `false` refuses the drop at that position.
public struct NativeDropHandler {
    /// A drag entered the control with this content.
    public let entered: (NativeDropContent, NSPoint) -> Bool

    /// The drag moved over the control.
    public let moved: (NSPoint) -> Bool

    /// The drag left the control without dropping.
    public let exited: () -> Void

    /// The content was dropped on the control.
    public let performed: (NativeDropContent, NSPoint) -> Bool

    /// Creates a drop handler.
    public init(
        entered: @escaping (NativeDropContent, NSPoint) -> Bool,
        moved: @escaping (NSPoint) -> Bool,
        exited: @escaping () -> Void,
        performed: @escaping (NativeDropContent, NSPoint) -> Bool
    ) {
        self.entered = entered
        self.moved = moved
        self.exited = exited
        self.performed = performed
    }
}

/// One attached display: its full pixel frame and the work-area frame that
/// excludes the taskbar and docked bars.
public struct NativeScreenDescription: Equatable, Sendable {
    /// The display's full frame.
    public let frame: NSRect

    /// The display's work-area frame.
    public let visibleFrame: NSRect

    /// Creates a screen description.
    public init(frame: NSRect, visibleFrame: NSRect) {
        self.frame = frame
        self.visibleFrame = visibleFrame
    }
}

/// `NSBezierPath` and related AppKit drawing APIs reduce to these primitives
/// so backends can rasterize with their native graphics stack (GDI paths on
/// the classic backend, a recording context in tests).
public protocol NativeDrawingContext: AnyObject {
    /// Fills a path with a color using the nonzero winding rule.
    func fillPath(_ segments: [NativePathSegment], color: NSColor)

    /// Strokes a path with a color and line width.
    func strokePath(_ segments: [NativePathSegment], color: NSColor, lineWidth: CGFloat)

    /// Draws a single-line text run with its top-left corner at a point.
    func drawText(_ text: String, at point: NSPoint, color: NSColor, fontName: String, fontSize: CGFloat, weight: Int, italic: Bool)

    /// Draws an image file scaled to fill a rectangle.
    ///
    /// A non-nil `tint` renders the image as a template: every pixel takes the
    /// tint color while the image's own alpha shapes the result.
    func drawImage(atPath path: String, in rect: NSRect, tint: NSColor?)

    /// Fills a rectangle with a linear gradient along an angle in degrees.
    ///
    /// Stops are ordered by location within 0...1. Angle 0 runs left to right
    /// and positive angles rotate toward the top of the view, matching
    /// AppKit's convention. The gradient respects the current clip, so
    /// callers clip first to fill non-rectangular shapes.
    func drawLinearGradient(_ stops: [NativeGradientStop], in rect: NSRect, angle: CGFloat)

    /// Intersects the current clip region with a path for later drawing.
    func clip(to segments: [NativePathSegment])

    /// Saves the drawing state, including the clip region.
    func saveState()

    /// Restores the most recently saved drawing state.
    func restoreState()
}

extension NativeDrawingContext {
    /// Draws an image file with no tint (the common non-template case).
    public func drawImage(atPath path: String, in rect: NSRect) {
        drawImage(atPath: path, in: rect, tint: nil)
    }
}

extension NativeControlBackend {
    /// Updates an image-view bitmap source with no tint.
    public func setImagePath(_ imagePath: String?, description: String, for handle: NativeHandle) {
        setImagePath(imagePath, description: description, tint: nil, for: handle)
    }

    /// Replaces the clipboard with text and data representations, no file list.
    public func setClipboardContents(text: String?, dataRepresentations: [String: [UInt8]]) {
        setClipboardContents(text: text, dataRepresentations: dataRepresentations, filePaths: [])
    }
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

    /// Shows or hides a native window with a fade animation.
    func fadeWindow(_ handle: NativeHandle, visible: Bool)

    /// Reflects hidden standard title-bar buttons onto the native caption:
    /// a hidden minimize/zoom button grays the matching caption box; a hidden
    /// close button disables the system-menu close command.
    func setWindowButtonsHidden(closeHidden: Bool, minimizeHidden: Bool, zoomHidden: Bool, for handle: NativeHandle)

    /// Whether the user's system theme prefers a dark appearance (Windows
    /// "dark mode" for applications). Drives `NSAppearance` resolution.
    func systemPrefersDarkAppearance() -> Bool

    /// The primary screen's pixel frame, used for on-screen placement.
    func primaryScreenFrame() -> NSRect

    /// Descriptions of every attached display, primary first.
    func screenDescriptions() -> [NativeScreenDescription]

    /// Minimizes or restores a native window.
    func setWindowMinimized(_ minimized: Bool, for handle: NativeHandle)

    /// Toggles a native window between zoomed (maximized) and normal.
    func toggleWindowZoom(_ handle: NativeHandle)

    /// Moves a native window to the bottom of the z-order without activating.
    func orderWindowBack(_ handle: NativeHandle)

    /// Whether a native window is currently on screen (shown, not minimized).
    func isWindowVisible(_ handle: NativeHandle) -> Bool

    /// Whether a native window is currently minimized.
    func isWindowMinimized(_ handle: NativeHandle) -> Bool

    /// Whether a native window is currently zoomed (maximized).
    func isWindowZoomed(_ handle: NativeHandle) -> Bool

    /// Registers the action to perform when a native window moves; the point
    /// is the window's new top-left origin in screen coordinates.
    func registerWindowMoveAction(for handle: NativeHandle, action: @escaping (NSPoint) -> Void)

    /// Makes a control a drop target for native drags (text and file lists),
    /// routing the drag lifecycle through the handler.
    func registerDropTarget(for handle: NativeHandle, handler: NativeDropHandler)

    /// Removes a control's drop-target registration.
    func unregisterDropTarget(for handle: NativeHandle)

    /// Starts a native drag carrying the given content from a control and
    /// blocks until it completes. Returns `true` when the content was dropped
    /// on a target, `false` when the drag was canceled.
    func performDrag(content: NativeDropContent, from handle: NativeHandle) -> Bool

    /// Shows the platform print dialog and, when confirmed, renders a view's
    /// custom drawing into the printer at point scale. Returns `true` when a
    /// job was printed and `false` when the dialog was canceled.
    func runPrintOperation(for handle: NativeHandle, jobName: String, contentSize: NSSize) -> Bool

    /// Closes a previously created native window.
    func closeWindow(_ handle: NativeHandle)

    /// Updates a native top-level window's z-ordering level.
    ///
    /// Levels above `.normal` float over the application's normal windows
    /// with tool-window chrome and no taskbar presence.
    func setWindowLevel(_ level: NSWindow.Level, for handle: NativeHandle)

    /// Updates whether a native top-level window hides while the application
    /// is inactive and reappears when it activates again.
    func setHidesOnDeactivate(_ hidesOnDeactivate: Bool, for handle: NativeHandle)

    /// Returns the installed font family names sorted for display.
    func fontFamilyNames() -> [String]

    /// Reads the system clipboard's plain text, when any.
    func clipboardString() -> String?

    /// Replaces the system clipboard contents with plain text.
    func setClipboardString(_ string: String)

    /// Reads the absolute file paths on the clipboard (a file-copy from the
    /// system file manager), in order. Empty when no file list is present.
    func clipboardFilePaths() -> [String]

    /// Replaces the system clipboard with several representations at once —
    /// text, data, and a file list — as one clipboard update.
    ///
    /// Format names are platform clipboard format identifiers (for example
    /// `"Rich Text Format"` or `"PNG"`); the text, when present, is written
    /// as the plain-text representation alongside them, and the file paths as
    /// the platform file-list format.
    func setClipboardContents(text: String?, dataRepresentations: [String: [UInt8]], filePaths: [String])

    /// Reads the bytes of a named clipboard format, when present.
    func clipboardData(forFormat formatName: String) -> [UInt8]?

    /// Returns whether a named clipboard format is currently available.
    func clipboardHasData(forFormat formatName: String) -> Bool

    /// Empties the system clipboard.
    func clearClipboard()

    /// Returns a counter that changes whenever the clipboard contents change,
    /// including changes made by other applications.
    func clipboardChangeCount() -> Int

    /// Registers the action to perform when a native top-level window closes.
    func registerWindowCloseAction(for handle: NativeHandle, action: @escaping () -> Void)

    /// Registers the handler consulted before a title-bar close proceeds.
    ///
    /// Returning false vetoes the close, leaving the window open (AppKit's
    /// `windowShouldClose` contract). Programmatic `closeWindow` calls skip
    /// the handler.
    func registerWindowShouldCloseHandler(for handle: NativeHandle, handler: @escaping () -> Bool)

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
    func createTextField(text: String, frame: NSRect, parent: NativeHandle?, isEditable: Bool, isBordered: Bool, isMultiline: Bool) -> NativeHandle

    /// Creates a native secure text field child.
    func createSecureTextField(text: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle

    /// Sets the placeholder (cue banner) text shown in an empty edit field.
    func setTextPlaceholder(_ placeholder: String?, for handle: NativeHandle)

    /// Sets the horizontal text alignment of an edit field.
    func setTextAlignment(_ alignment: NSTextAlignment, for handle: NativeHandle)

    /// Sets the tick-mark count on a slider (0 clears the ticks).
    func setSliderTickMarks(count: Int, for handle: NativeHandle)

    /// Sets whether a slider is drawn vertically.
    func setSliderVertical(_ isVertical: Bool, for handle: NativeHandle)

    /// Sets how many items a combo box shows before scrolling.
    func setComboBoxVisibleItems(_ count: Int, for handle: NativeHandle)

    /// Sets the fill color of a progress/level bar (nil restores the default).
    func setProgressBarColor(_ color: NSColor?, for handle: NativeHandle)

    /// Constrains a top-level window's content size during user resizing.
    func setWindowContentSizeLimits(minSize: NSSize?, maxSize: NSSize?, for handle: NativeHandle)

    /// Sets whether a background click on a view drags its top-level window.
    ///
    /// Used by `isMovableByWindowBackground`: a mouse-down on the view (where
    /// no child control consumes it) initiates a window move.
    func setViewDragsParentWindow(_ enabled: Bool, for handle: NativeHandle)

    /// Starts watching for a mouse click outside a window, dismissing it.
    ///
    /// Used by transient popovers: a click anywhere outside the window (or its
    /// children) fires `onDismiss`. Only one watch is active at a time.
    func beginOutsideClickDismiss(for handle: NativeHandle, onDismiss: @escaping () -> Void)

    /// Stops the active outside-click dismiss watch.
    func endOutsideClickDismiss()

    /// Creates a native multiline text view child.
    ///
    /// Rich text views use the platform's rich-edit control so per-range
    /// character formatting through `setTextRangeFormat` works.
    func createTextView(text: String, frame: NSRect, parent: NativeHandle?, isEditable: Bool, isRichText: Bool) -> NativeHandle

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
    ///
    /// `showsCalendar` selects a month-calendar peer (AppKit's
    /// clock-and-calendar style) instead of the compact text-field picker.
    func createDatePicker(date: Date, minDate: Date?, maxDate: Date?, showsCalendar: Bool, frame: NSRect, parent: NativeHandle?) -> NativeHandle

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

    /// Applies character formatting to a text range of a rich text view.
    ///
    /// A `nil` font, color, underline, or strikethrough leaves that aspect of
    /// the range unchanged; `false` explicitly clears an effect. The user's
    /// selection is preserved across the formatting change.
    func setTextRangeFormat(font: NSFont?, color: NSColor?, underline: Bool?, strikethrough: Bool?, location: Int, length: Int, for handle: NativeHandle)

    /// Applies paragraph alignment to the paragraphs covering a character
    /// range of a rich text view.
    func setTextRangeAlignment(_ alignment: NSTextAlignment, location: Int, length: Int, for handle: NativeHandle)

    /// Updates whether a native edit control accepts keyboard editing while
    /// still allowing selection and scrolling.
    func setTextEditable(_ isEditable: Bool, for handle: NativeHandle)

    /// Updates the native frame for a window or control.
    func setFrame(_ frame: NSRect, for handle: NativeHandle)

    /// Updates the content scale applied to a custom-drawn view.
    ///
    /// Scales other than 1 magnify: frames set through `setFrame` grow by
    /// the scale and custom drawing renders through a matching transform, so
    /// `draw(_:)` code keeps working in logical coordinates. Native child
    /// controls do not scale; scroll-view magnification applies this to
    /// custom-drawn document views.
    func setContentScale(_ scale: CGFloat, for handle: NativeHandle)

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
    ///
    /// A non-nil `tint` renders the image as a template shape in that color.
    func setImagePath(_ imagePath: String?, description: String, tint: NSColor?, for handle: NativeHandle)

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

    /// Reports which part of a scroller the user last actuated.
    func scrollerPart(for handle: NativeHandle) -> NativeScrollerPart

    /// Sets which side of the track a slider's tick marks are drawn on.
    func setSliderTickMarkPosition(aboveOrLeading: Bool, for handle: NativeHandle)

    /// Renders a push button with a flat (square) bezel or the standard one.
    func setButtonBezelFlat(_ flat: Bool, for handle: NativeHandle)

    /// Gives a text field a sunken client-edge bezel, or removes it.
    func setTextFieldBezeled(_ bezeled: Bool, for handle: NativeHandle)

    /// Makes a level indicator respond to click/drag as a value setter.
    ///
    /// When editable, a click or drag maps the horizontal position to a value in
    /// `[minValue, maxValue]`, updates the bar, and fires the control action.
    func setLevelIndicatorEditable(_ editable: Bool, minValue: Double, maxValue: Double, for handle: NativeHandle)

    /// Reads the value a click/drag last set on an editable level indicator.
    func levelIndicatorValue(for handle: NativeHandle) -> Double

    /// Updates native stepper range.
    func setStepperRange(minValue: Double, maxValue: Double, increment: Double, for handle: NativeHandle)

    /// Updates native stepper value.
    func setStepperValue(_ value: Double, for handle: NativeHandle)

    /// Reads native stepper value.
    func stepperValue(for handle: NativeHandle) -> Double

    /// Sets whether the native stepper wraps past its range ends.
    func setStepperWraps(_ wraps: Bool, for handle: NativeHandle)

    /// Updates native date-picker state.
    func setDatePickerDate(_ date: Date, minDate: Date?, maxDate: Date?, for handle: NativeHandle)

    /// Reads native date-picker value.
    func datePickerDate(for handle: NativeHandle) -> Date?

    /// Sets a native date-picker display format string (nil restores the
    /// locale default). The format follows the platform date-time format
    /// syntax the backend understands.
    func setDatePickerFormat(_ format: String?, for handle: NativeHandle)

    /// Sets a button's image from a file path (nil clears it).
    func setButtonImage(imagePath: String?, for handle: NativeHandle)

    /// Replaces native table rows.
    func setTableRows(_ rows: [[String]], selectedRow: Int, for handle: NativeHandle)

    /// Updates a single native table cell's text in place (no full rebuild).
    func setTableCellText(_ text: String, row: Int, column: Int, for handle: NativeHandle)

    /// Updates native table selection.
    func setTableSelectedRow(_ selectedRow: Int, for handle: NativeHandle)

    /// Enables or disables native multiple-row selection.
    func setTableAllowsMultipleSelection(_ allows: Bool, for handle: NativeHandle)

    /// Replaces the native table's selected rows with the given set.
    func setTableSelectedRows(_ rows: Set<Int>, for handle: NativeHandle)

    /// Reads all currently selected native table rows, in ascending order.
    func tableSelectedRows(for handle: NativeHandle) -> [Int]

    /// Enables or disables in-place editing of native table cells.
    func setTableEditable(_ editable: Bool, for handle: NativeHandle)

    /// Begins editing a table cell's text in place, when the backend supports it.
    func editTableCell(row: Int, column: Int, for handle: NativeHandle)

    /// Shows a sort indicator on a table column header (ascending/descending),
    /// or clears all indicators when `column` is negative.
    func setTableSortIndicator(column: Int, ascending: Bool, for handle: NativeHandle)

    /// Registers the action invoked when an in-place table-cell edit commits,
    /// carrying the row, column, and new text.
    func registerTableEditAction(for handle: NativeHandle, action: @escaping (Int, Int, String) -> Void)

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

    /// Registers the action to perform when a control gains (`true`) or loses
    /// (`false`) native keyboard focus.
    func registerFocusChangeAction(for handle: NativeHandle, action: @escaping (Bool) -> Void)

    /// Registers the action to perform when a native view receives a mouse-down event.
    func registerMouseDownAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void)

    /// Registers the action to perform when a native view receives a mouse-up event.
    func registerMouseUpAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void)

    /// Registers the action to perform when a native view receives a mouse-moved event.
    func registerMouseMovedAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void)

    /// Registers the action invoked when the cursor leaves a control entirely,
    /// so hover state (tracking areas) can resolve exits.
    func registerMouseLeftAction(for handle: NativeHandle, action: @escaping () -> Void)

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

    /// Requests a repaint of a native control and all of its descendant views.
    ///
    /// Needed when a custom view's background changes beneath transparent child
    /// views (e.g. a table selection band under borderless cell labels): the
    /// children must repaint over the new background, which a plain invalidate
    /// of only the parent does not trigger.
    func invalidateControlTree(_ handle: NativeHandle)

    /// Repaints a native control (and its children) **synchronously**, so
    /// custom-drawn views update mid-gesture instead of waiting for `WM_PAINT`
    /// to be scheduled (which is starved during a rapid drag).
    func redrawControlImmediately(_ handle: NativeHandle)

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

    /// Replaces a native view's hover cursor regions.
    ///
    /// Regions pair view-local rectangles with framework cursor names. The
    /// backend resolves the pointer image per hover position, first matching
    /// region wins, and positions outside every region show the arrow.
    func setCursorRegions(_ regions: [NativeCursorRegion], for handle: NativeHandle)

    /// Schedules a repeating run-loop timer, returning its identifier.
    ///
    /// The action fires on the UI thread from the native message loop until
    /// the timer is canceled. One-shot behavior is layered above by the
    /// caller canceling after the first fire.
    func scheduleNativeTimer(intervalMilliseconds: Int, action: @escaping () -> Void) -> UInt

    /// Cancels a scheduled run-loop timer.
    func cancelNativeTimer(_ identifier: UInt)

    /// Registers the handler consulted for menu key equivalents before key-down routing.
    func registerKeyEquivalentHandler(_ handler: @escaping (NSEvent) -> Bool)

    /// Runs a context menu at a screen point, returning the performed item or `nil` on cancel.
    func runContextMenu(_ menu: NSMenu, atScreenPoint point: NSPoint) -> NSMenuItem?

    /// Measures the rendered size of a single-line text run.
    func measureText(_ text: String, fontName: String, fontSize: CGFloat, weight: Int, italic: Bool) -> NSSize
}
