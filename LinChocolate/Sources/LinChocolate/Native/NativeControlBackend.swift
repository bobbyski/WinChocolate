import Foundation

/// Platform-neutral font description carried across the backend seam.
public struct NativeFontSpec: Equatable {
    /// Font family, or nil for the platform default.
    public let family: String?
    public let size: Double
    public let bold: Bool
    public let italic: Bool
    public init(family: String?, size: Double, bold: Bool = false, italic: Bool = false) {
        self.family = family
        self.size = size
        self.bold = bold
        self.italic = italic
    }
}

/// Platform-neutral description of one toolbar item carried across the seam.
public struct NativeToolbarItemSpec {
    public let identifier: String
    public let label: String
    public let isFlexibleSpace: Bool
    public let action: (() -> Void)?
    public init(identifier: String, label: String, isFlexibleSpace: Bool = false, action: (() -> Void)? = nil) {
        self.identifier = identifier
        self.label = label
        self.isFlexibleSpace = isFlexibleSpace
        self.action = action
    }
}

/// One color stop of a gradient (location in 0...1).
public struct NativeGradientStop: Equatable {
    public let color: NSColor
    public let location: CGFloat
    public init(color: NSColor, location: CGFloat) {
        self.color = color
        self.location = location
    }
}

/// Platform drawing surface handed to a view's draw handler. Path-based:
/// build a path with the primitive ops, then fill or stroke it (both consume
/// the path). Backed by Cairo on GTK and by an op recorder in tests.
public protocol NativeGraphicsContext: AnyObject {
    func setFillColor(_ color: NSColor)
    func setStrokeColor(_ color: NSColor)
    func setLineWidth(_ width: Double)
    func beginPath()
    func move(toX x: Double, y: Double)
    func line(toX x: Double, y: Double)
    func curve(toX x: Double, y: Double, c1x: Double, c1y: Double, c2x: Double, c2y: Double)
    /// Appends an arc to the current path (angles in radians, AppKit space).
    func addArc(centerX: Double, centerY: Double, radius: Double, startAngleRadians: Double, endAngleRadians: Double, clockwise: Bool)
    func closePath()
    func fillPath()
    func strokePath()
    /// Saves / restores the drawing state (clip, source) for scoped clipping.
    func saveState()
    func restoreState()
    /// Intersects the clip region with the current path (consumes the path).
    func clipToCurrentPath()
    /// Fills `rect` with a linear gradient at `angleDegrees` (0 = left→right,
    /// 90 = bottom→top, AppKit convention).
    func fillLinearGradient(_ stops: [NativeGradientStop], inRect rect: NSRect, angleDegrees: Double)
    /// Fills `rect` with a radial gradient centered in it.
    func fillRadialGradient(_ stops: [NativeGradientStop], inRect rect: NSRect)
}

/// One styled run of text (carries `NSAttributedString` content across the seam).
public struct NativeTextRun: Equatable {
    public let text: String
    public let color: NSColor?
    public let font: NativeFontSpec?
    public init(text: String, color: NSColor? = nil, font: NativeFontSpec? = nil) {
        self.text = text
        self.color = color
        self.font = font
    }
}

/// Platform-neutral description of one menu-bar item, used to carry `NSMenu`
/// structures across the backend seam without the seam knowing API types.
public struct NativeMenuItemSpec {
    public let title: String
    public let isSeparator: Bool
    /// GTK accelerator string for the key equivalent (e.g. "<Control>n"), or nil.
    public let accelerator: String?
    public let action: (() -> Void)?
    public init(title: String, isSeparator: Bool = false, accelerator: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.isSeparator = isSeparator
        self.accelerator = accelerator
        self.action = action
    }
}

/// Platform-neutral description of one top-level menu (e.g. "File").
public struct NativeMenuSpec {
    public let title: String
    public let items: [NativeMenuItemSpec]
    public init(title: String, items: [NativeMenuItemSpec]) {
        self.title = title
        self.items = items
    }
}

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
    /// Installs (or replaces) the menu bar shown at the top of `window`.
    func installMenuBar(_ menus: [NativeMenuSpec], on window: NativeHandle)
    /// Installs (or replaces) the Apple-look toolbar under the menu bar.
    func installToolbar(_ items: [NativeToolbarItemSpec], on window: NativeHandle)
    /// Shows a modal alert and blocks until a button is pressed; returns the
    /// pressed button's index in `buttons` (AppKit order: first = default,
    /// shown rightmost).
    func runAlert(message: String, informative: String, buttons: [String], for window: NativeHandle?) -> Int
    /// Shows a modal open-file dialog; returns the chosen path, or nil on cancel.
    func runOpenPanel(directory: String?, for window: NativeHandle?) -> String?
    /// Shows a modal save-file dialog; returns the chosen path, or nil on cancel.
    func runSavePanel(directory: String?, suggestedName: String?, for window: NativeHandle?) -> String?

    // MARK: Appearance
    /// Switches the whole app between light and dark themes. Existing controls
    /// re-theme in place.
    func setAppearanceDark(_ dark: Bool)

    // MARK: Pasteboard & drag-and-drop
    /// Pushes a string to the system clipboard.
    func setClipboardString(_ string: String)
    /// Reads the last string set on the clipboard (nil if none).
    func clipboardString() -> String?
    /// Registers `handle` as a drop destination for `types`. On a drop, calls
    /// `onDrop(droppedString, x, y)` in the view's AppKit coordinates; the
    /// return value reports whether the drop was accepted.
    func registerDropTarget(for handle: NativeHandle, types: [String], onDrop: @escaping (String, Double, Double) -> Bool)
    /// Registers `handle` as a drag source; `provider` supplies the string
    /// carried when the user drags it (nil cancels).
    func registerDragSource(for handle: NativeHandle, provider: @escaping () -> String?)

    // MARK: Popover
    /// Creates a popover (a `GtkPopover`), initially empty and unattached.
    func createPopover() -> NativeHandle
    /// Installs `content` as the popover's child and sizes it.
    func setPopoverContent(_ content: NativeHandle, size: NSSize, for popover: NativeHandle)
    /// Anchors the popover to `view` (pointing at `rect` in the view's AppKit
    /// coordinates, `edge` = `NSRectEdge` raw value) and pops it up.
    func showPopover(_ popover: NativeHandle, relativeTo view: NativeHandle, rect: NSRect, edge: Int)
    /// Pops the popover down.
    func closePopover(_ popover: NativeHandle)

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
    /// Creates a segmented control (`setSelectedIndex` selects a segment;
    /// `setSelectionChangeAction` reports user selection).
    func createSegmentedControl(labels: [String], frame: NSRect) -> NativeHandle
    /// Creates an image view (set content with `setImagePath`).
    func createImageView(frame: NSRect) -> NativeHandle
    /// Creates a scrolling, column-based table. Selection uses
    /// `setSelectedIndex`/`setSelectionChangeAction` (row index).
    func createTableView(frame: NSRect) -> NativeHandle
    /// Appends a titled column to a table.
    func addTableColumn(title: String, to table: NativeHandle)
    /// Updates an existing column's header title.
    func setTableColumnTitle(_ title: String, columnIndex: Int, for table: NativeHandle)
    /// Makes a column's header clickable to sort (reports via `setSortChangeAction`).
    func setColumnSortable(_ columnIndex: Int, for table: NativeHandle)
    /// Registers the action fired when the user clicks a sortable header;
    /// passes the column index and whether the new order is ascending.
    func setSortChangeAction(for table: NativeHandle, action: @escaping (Int, Bool) -> Void)
    /// Registers the action fired when a row is activated (double-click / Enter);
    /// passes the row index.
    func setRowActivateAction(for table: NativeHandle, action: @escaping (Int) -> Void)
    /// Sets the number of rows and re-binds visible cells.
    func setTableRowCount(_ count: Int, for table: NativeHandle)
    /// Supplies cell text on demand: `(row, columnIndex) -> String`.
    func setTableCellProvider(for table: NativeHandle, provider: @escaping (Int, Int) -> String)
    /// Creates a tree table (expandable rows). Items are addressed by dot-paths
    /// ("2", "0.1"); selection is by visible row via `setSelectionChangeAction`.
    func createOutlineView(frame: NSRect) -> NativeHandle
    /// Appends a titled column (column 0 carries the expand arrows).
    func addOutlineColumn(title: String, to outline: NativeHandle)
    /// Sets the number of root items and re-binds (= reload).
    func setOutlineRootCount(_ count: Int, for outline: NativeHandle)
    /// Supplies tree shape and cell text by item path.
    func setOutlineProviders(
        for outline: NativeHandle,
        childCount: @escaping (String) -> Int,
        cellText: @escaping (String, Int) -> String
    )
    /// Creates a grid collection view. Selection uses the shared
    /// `setSelectedIndex`/`setSelectionChangeAction` (item index).
    func createCollectionView(frame: NSRect) -> NativeHandle
    /// Sets the number of items and re-binds visible tiles (= reload).
    func setCollectionItemCount(_ count: Int, for collection: NativeHandle)
    /// Supplies tile text on demand by item index.
    func setCollectionItemProvider(for collection: NativeHandle, provider: @escaping (Int) -> String)
    /// Creates a token field (chips + text entry; Enter commits a token,
    /// clicking a chip removes it).
    func createTokenField(tokens: [String], frame: NSRect) -> NativeHandle
    /// Replaces a token field's tokens.
    func setTokens(_ tokens: [String], for handle: NativeHandle)
    /// Registers the action fired when the user adds or removes a token.
    func setTokensChangeAction(for handle: NativeHandle, action: @escaping ([String]) -> Void)
    /// Shows the image file at `path` in an image view (nil clears it).
    func setImagePath(_ path: String?, for handle: NativeHandle)
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
    /// Sets whether each scroller may appear (true = show when needed).
    func setScrollerPolicy(vertical: Bool, horizontal: Bool, for handle: NativeHandle)
    /// Scrolls so the content offset (distance from the top-left of the
    /// document) becomes `(x, y)`, clamped to the scrollable range.
    func setScrollOffset(x: Double, y: Double, for handle: NativeHandle)
    /// The current content offset (distance scrolled from the top-left).
    func scrollOffset(for handle: NativeHandle) -> (x: Double, y: Double)
    /// The document (total scrollable content) size.
    func scrollDocumentSize(for handle: NativeHandle) -> (width: Double, height: Double)
    /// The visible viewport size (the clip view's size).
    func scrollVisibleSize(for handle: NativeHandle) -> (width: Double, height: Double)
    /// Registers the action fired when the scroll offset changes; passes `(x, y)`.
    func setScrollChangeAction(for handle: NativeHandle, action: @escaping (Double, Double) -> Void)
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
    /// Applies a font to a control's text.
    func setFont(_ font: NativeFontSpec, for handle: NativeHandle)
    /// Applies a foreground text color to a control.
    func setTextColor(_ color: NSColor, for handle: NativeHandle)
    /// Applies a material (`NSVisualEffectView.Material` raw value) to a view,
    /// giving it a theme-aware tinted background.
    func setMaterial(_ material: String, for handle: NativeHandle)
    /// Replaces a label's content with styled runs (attributed text).
    func setStyledText(_ runs: [NativeTextRun], for handle: NativeHandle)
    /// Registers custom drawing for a container view: `(context, width, height)`
    /// in AppKit's bottom-left coordinate space.
    func setDrawHandler(for handle: NativeHandle, handler: @escaping (NativeGraphicsContext, Double, Double) -> Void)
    /// Requests a redraw of a view with a draw handler.
    func setNeedsDisplay(_ handle: NativeHandle)
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
