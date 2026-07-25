import Foundation

/// Platform-neutral font description carried across the backend seam.
public struct NativeFontSpec: Equatable {
    /// Font family, or nil for the platform default.
    public let family: String?
    /// Font size in points.
    public let size: Double
    /// Whether the font is drawn bold.
    public let bold: Bool
    /// Whether the font is drawn italic.
    public let italic: Bool
    /// Creates a font description with the given family, size, and traits.
    public init(family: String?, size: Double, bold: Bool = false, italic: Bool = false) {
        self.family = family
        self.size = size
        self.bold = bold
        self.italic = italic
    }
}

/// The concrete kind a button should take on (AppKit's button types collapse
/// to these three native shapes).
public enum NativeButtonKind: Sendable { case push, checkbox, radio }

/// Platform-neutral description of one toolbar item carried across the seam.
public struct NativeToolbarItemSpec {
    /// File-backed icon (PNG/BMP path) and whether to tint it as a template.
    public var imagePath: String?
    /// Whether the file-backed image should be tinted as a template.
    public var imageIsTemplate: Bool = false
    /// Stable identifier for this item (matches AppKit's `NSToolbarItem.identifier`).
    public let identifier: String
    /// User-visible label displayed under the icon.
    public let label: String
    /// GTK icon-theme name for the item's image, or nil for a text-only item.
    public let iconName: String?
    /// Whether the item is a flexible space that expands between other items.
    public let isFlexibleSpace: Bool
    /// A custom control to embed for this item (AppKit's `NSToolbarItem.view`),
    /// e.g. the page-selector pop-up or a search field. When set, the toolbar
    /// hosts this widget instead of a plain button.
    public let viewHandle: NativeHandle?
    /// Handler invoked when the toolbar item is clicked.
    public let action: (() -> Void)?
    /// Creates a toolbar item spec.
    public init(imagePath: String? = nil, imageIsTemplate: Bool = false, identifier: String, label: String, iconName: String? = nil, isFlexibleSpace: Bool = false, viewHandle: NativeHandle? = nil, action: (() -> Void)? = nil) {
        self.imagePath = imagePath
        self.imageIsTemplate = imageIsTemplate
        self.identifier = identifier
        self.label = label
        self.iconName = iconName
        self.isFlexibleSpace = isFlexibleSpace
        self.viewHandle = viewHandle
        self.action = action
    }
}

/// One color stop of a gradient (location in 0...1).
public struct NativeGradientStop: Equatable {
    /// The stop's color.
    public let color: NSColor
    /// Normalized position of the stop along the gradient (0...1).
    public let location: CGFloat
    /// Creates a gradient stop at `location` with the given `color`.
    public init(color: NSColor, location: CGFloat) {
        self.color = color
        self.location = location
    }
}

/// A pointer event delivered to a custom view (positions in the view's own
/// top-left coordinates).
public enum NativeMouseEvent {
    /// The pointer entered the view at `(x, y)`.
    case entered(x: Double, y: Double)
    /// The pointer exited the view.
    case exited
    /// A mouse button was pressed at `(x, y)`.
    case down(x: Double, y: Double, clickCount: Int, rightButton: Bool)
    /// The scroll wheel / trackpad moved by `(deltaX, deltaY)`, already in
    /// AppKit's sign convention (positive dy = scroll up).
    case scroll(deltaX: Double, deltaY: Double)
}

/// Platform drawing surface handed to a view's draw handler. Path-based:
/// build a path with the primitive ops, then fill or stroke it (both consume
/// the path). Backed by Cairo on GTK and by an op recorder in tests.
public protocol NativeGraphicsContext: AnyObject {
    /// Sets the fill color used by subsequent `fillPath` calls.
    func setFillColor(_ color: NSColor)
    /// Sets the stroke color used by subsequent `strokePath` calls.
    func setStrokeColor(_ color: NSColor)
    /// Sets the line width in points used by subsequent `strokePath` calls.
    func setLineWidth(_ width: Double)
    /// Begins a new empty path.
    func beginPath()
    /// Moves the current path point to `(x, y)` without adding a segment.
    func move(toX x: Double, y: Double)
    /// Appends a straight line segment from the current point to `(x, y)`.
    func line(toX x: Double, y: Double)
    /// Appends a cubic Bezier curve from the current point to `(x, y)` with control points `(c1x, c1y)` and `(c2x, c2y)`.
    func curve(toX x: Double, y: Double, c1x: Double, c1y: Double, c2x: Double, c2y: Double)
    /// Appends an arc to the current path (angles in radians, AppKit space).
    func addArc(centerX: Double, centerY: Double, radius: Double, startAngleRadians: Double, endAngleRadians: Double, clockwise: Bool)
    /// Closes the current subpath with a straight line back to its start.
    func closePath()
    /// Fills the current path with the fill color (consumes the path).
    func fillPath()
    /// Strokes the current path with the stroke color and line width (consumes the path).
    func strokePath()
    /// Saves the drawing state (clip, source) so it can be restored later.
    func saveState()
    /// Restores the drawing state saved by the matching `saveState`.
    func restoreState()
    /// Intersects the clip region with the current path (consumes the path).
    func clipToCurrentPath()
    /// Fills `rect` with a linear gradient at `angleDegrees` (0 = left→right,
    /// 90 = bottom→top, AppKit convention).
    func fillLinearGradient(_ stops: [NativeGradientStop], inRect rect: NSRect, angleDegrees: Double)
    /// Fills `rect` with a radial gradient centered in it.
    func fillRadialGradient(_ stops: [NativeGradientStop], inRect rect: NSRect)
    /// Draws `text` with its TOP-LEFT at `point` (AppKit's `String.draw(at:)`).
    func drawText(_ text: String, at point: NSPoint, font: NativeFontSpec?, color: NSColor)
    /// Draws the image at `path` scaled to fill `rect` (AppKit's `NSImage.draw(in:)`).
    func drawImage(atPath path: String, inRect rect: NSRect)
}

/// One styled run of text (carries `NSAttributedString` content across the seam).
public struct NativeTextRun: Equatable {
    /// The run's text.
    public let text: String
    /// Foreground color, or nil to use the control's default.
    public let color: NSColor?
    /// Font spec, or nil to use the control's default.
    public let font: NativeFontSpec?
    /// Creates a styled text run.
    public init(text: String, color: NSColor? = nil, font: NativeFontSpec? = nil) {
        self.text = text
        self.color = color
        self.font = font
    }
}

/// AppKit's `NSLevelIndicator.Style` raw values, so the backend can name them
/// instead of matching bare integers. Apple's values, read from real AppKit.
public enum NativeLevelIndicatorStyle {
    /// Relevancy style (`NSLevelIndicator.Style.relevancy`).
    public static let relevancy = 0
    /// Continuous capacity bar (`NSLevelIndicator.Style.continuousCapacity`).
    public static let continuousCapacity = 1
    /// Discrete capacity segments (`NSLevelIndicator.Style.discreteCapacity`).
    public static let discreteCapacity = 2
    /// Rating stars (`NSLevelIndicator.Style.rating`).
    public static let rating = 3
}

/// Toolbar-wide rendering mode (AppKit's `NSToolbar.DisplayMode`).
public enum NativeToolbarDisplayMode: Sendable {
    case iconAndLabel, iconOnly, labelOnly
}

/// Everything the customization panel shows: the live strip (a duplicate of
/// the current toolbar — the drag-and-drop surface), the palette of allowed
/// items, the default set, and the current display mode.
public struct NativeToolbarCustomizationSession {
    /// The live strip mirroring the toolbar; the drag-and-drop editing surface.
    public var strip: [NativeToolbarItemSpec]
    /// The palette of items the user may drag into the strip.
    public var palette: [NativeToolbarPaletteItem]
    /// The default item set used by the "reset" affordance.
    public var defaultSet: [NativeToolbarPaletteItem]
    /// Current display mode as a `NativeToolbarDisplayMode` raw ordinal.
    public var displayModeIndex: Int
    /// Creates a customization session snapshot.
    public init(strip: [NativeToolbarItemSpec], palette: [NativeToolbarPaletteItem],
                defaultSet: [NativeToolbarPaletteItem], displayModeIndex: Int) {
        self.strip = strip
        self.palette = palette
        self.defaultSet = defaultSet
        self.displayModeIndex = displayModeIndex
    }
}

/// The customization panel's edit callbacks — Apple's drag model, not a
/// toggle list: drag a palette item in (insert), drag a strip item out
/// (remove), drag within the strip (move), drag the default set in (reset).
public struct NativeToolbarCustomizationHandlers {
    /// Called when a palette item is dragged into the strip at `(identifier, index)`.
    public let onInsert: (String, Int) -> Void
    /// Called when a strip item is dragged to a new position `(from, to)`.
    public let onMove: (Int, Int) -> Void
    /// Called when a strip item is dragged out to be removed.
    public let onRemove: (Int) -> Void
    /// Called when the user drags the default-set tile into the strip.
    public let onResetToDefault: () -> Void
    /// Called when the user selects a different display mode ordinal.
    public let onDisplayMode: (Int) -> Void
    /// Called when the customization panel is dismissed.
    public let onClose: () -> Void
    /// Creates the handler bundle for a customization session.
    public init(onInsert: @escaping (String, Int) -> Void, onMove: @escaping (Int, Int) -> Void,
                onRemove: @escaping (Int) -> Void, onResetToDefault: @escaping () -> Void,
                onDisplayMode: @escaping (Int) -> Void, onClose: @escaping () -> Void) {
        self.onInsert = onInsert
        self.onMove = onMove
        self.onRemove = onRemove
        self.onResetToDefault = onResetToDefault
        self.onDisplayMode = onDisplayMode
        self.onClose = onClose
    }
}

/// One row of the toolbar customization palette.
public struct NativeToolbarPaletteItem {
    /// Stable identifier matching the toolbar item's identifier.
    public let identifier: String
    /// User-visible label displayed under the tile.
    public let label: String
    /// Whether the item is currently in the toolbar (shown checked/dimmed).
    public let isInToolbar: Bool
    /// Tile artwork: a file-backed image (recolored when template) or a theme
    /// icon name, mirroring `NativeToolbarItemSpec`.
    public var imagePath: String?
    /// Whether the file-backed image should be tinted as a template.
    public var imageIsTemplate: Bool = false
    /// GTK icon-theme name for the tile, or nil for a text-only tile.
    public var iconName: String?
    /// Creates a palette item.
    public init(identifier: String, label: String, isInToolbar: Bool) {
        self.identifier = identifier
        self.label = label
        self.isInToolbar = isInToolbar
    }
}

/// Platform-neutral description of one menu-bar item, used to carry `NSMenu`
/// structures across the backend seam without the seam knowing API types.
public struct NativeMenuItemSpec {
    /// The item's title.
    public let title: String
    /// Whether the item is a separator line rather than an activatable entry.
    public let isSeparator: Bool
    /// GTK accelerator string for the key equivalent (e.g. "<Control>n"), or nil.
    public let accelerator: String?
    /// Handler invoked when the item is selected.
    public let action: (() -> Void)?
    /// Creates a menu item spec.
    public init(title: String, isSeparator: Bool = false, accelerator: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.isSeparator = isSeparator
        self.accelerator = accelerator
        self.action = action
    }
}

/// Platform-neutral description of one top-level menu (e.g. "File").
public struct NativeMenuSpec {
    /// The menu's title as shown in the menu bar.
    public let title: String
    /// The menu's items in display order.
    public let items: [NativeMenuItemSpec]
    /// Creates a menu spec.
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
    /// Schedules `block` after `interval` seconds (repeating if asked) on the
    /// platform's real main loop. Under GTK, Foundation's Timer can't be used:
    /// RunLoop.main is unpumped, and swift-corelibs' RunLoop fires a repeating
    /// timer only once. The Timer shadow routes here instead.
    func scheduleTimer(interval: Double, repeats: Bool, _ block: @escaping () -> Void)
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
    /// Hides a window without destroying it (AppKit's `orderOut`): the native
    /// window survives, so `showWindow` can re-present it — what a reusable
    /// panel needs.
    func hideWindow(_ handle: NativeHandle)
    /// Updates a window's title-bar text.
    func setWindowTitle(_ title: String, for handle: NativeHandle)
    /// Registers the action to run when the window is closed by the user.
    func registerWindowCloseAction(for handle: NativeHandle, action: @escaping () -> Void)
    /// Installs (or replaces) the menu bar shown at the top of `window`.
    func installMenuBar(_ menus: [NativeMenuSpec], on window: NativeHandle)
    /// Records whether `handle` uses a top-left (flipped) coordinate system for
    /// positioning its children, so subview placement flips Y appropriately.
    func setViewFlipped(_ flipped: Bool, for handle: NativeHandle)
    /// Clips a view's children to its bounds (AppKit's `clipsToBounds`) — a
    /// clip view's document is larger than the viewport and must not overflow.
    func setClipsToBounds(_ clips: Bool, for handle: NativeHandle)
    /// Installs (or replaces) the Apple-look toolbar under the menu bar.
    func installToolbar(_ items: [NativeToolbarItemSpec], displayMode: NativeToolbarDisplayMode, on window: NativeHandle)
    /// Shows the toolbar customization panel: a duplicate of the live bar as
    /// the drag surface, the palette of allowed items, and the default set.
    /// Edits arrive through `handlers`; the framework then pushes a refreshed
    /// session via `updateToolbarCustomization` while the panel stays open.
    func runToolbarCustomization(_ session: NativeToolbarCustomizationSession,
                                 handlers: NativeToolbarCustomizationHandlers,
                                 for window: NativeHandle)

    /// Rebuilds the open customization panel's strip/palette after an edit.
    func updateToolbarCustomization(_ session: NativeToolbarCustomizationSession)
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
    /// Determinate (fills to a value) vs indeterminate (an animated barber-pole).
    func setProgressIndeterminate(_ indeterminate: Bool, for handle: NativeHandle)
    /// Starts/stops an indeterminate bar's animation (AppKit's start/stopAnimation).
    func setProgressAnimating(_ animating: Bool, for handle: NativeHandle)
    /// Spinner (a rotating GtkSpinner) vs bar (AppKit's `NSProgressIndicator.style`).
    func setProgressSpinning(_ spinning: Bool, for handle: NativeHandle)
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

    /// Scrolls `row` into view without disturbing the selection
    /// (AppKit's `NSTableView.scrollRowToVisible(_:)`).
    func scrollTableRowToVisible(_ row: Int, for table: NativeHandle)
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
    /// The native widget for a collection item, or nil to fall back to the
    /// text provider. Apple's collection hosts each item's real VIEW (the
    /// demo's items are buttons); this is what renders them as such.
    func setCollectionItemViewProvider(for collection: NativeHandle, provider: @escaping (Int) -> NativeHandle?)
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
    /// The level indicator's presentation style (AppKit's `NSLevelIndicator.Style`
    /// raw value: 0 relevancy, 1 continuousCapacity, 2 discreteCapacity, 3 rating).
    func setLevelIndicatorStyle(_ rawValue: Int, for handle: NativeHandle)
    /// Whether the user can set the level by clicking it.
    func setLevelIndicatorEditable(_ editable: Bool, for handle: NativeHandle)
    /// The indicator's range. For `.rating` the span is the number of stars.
    func setLevelIndicatorRange(min: Double, max: Double, for handle: NativeHandle)
    /// The values at which the fill turns warning/critical coloured; 0 = none.
    func setLevelThresholds(warning: Double, critical: Double, for handle: NativeHandle)
    /// Fires when the user sets an editable indicator's level.
    func setLevelChangeAction(for handle: NativeHandle, action: @escaping (Double) -> Void)

    /// A standalone scrollbar (AppKit's `NSScroller` used directly, rather than
    /// as an `NSScrollView`'s bar). Starts **disabled**, as AppKit's does.
    func createScroller(vertical: Bool, frame: NSRect) -> NativeHandle
    /// Positions a standalone scroller: `value` and `knobProportion` are both
    /// AppKit's `0...1` fractions.
    func setScrollerGeometry(value: Double, knobProportion: Double, for handle: NativeHandle)
    /// Fires when the *user* drags the scroller, with the new `0...1` value.
    func setScrollerAction(for handle: NativeHandle, action: @escaping (Double) -> Void)
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
    /// Scales the view's custom drawing by `magnification` and grows the
    /// widget's requested size by the same factor so a hosting scroll view
    /// reports the enlarged scrollable extent (AppKit's `NSScrollView.magnification`).
    func setViewMagnification(_ magnification: Double, for handle: NativeHandle)
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
    /// Shows or hides a control.
    func setHidden(_ isHidden: Bool, for handle: NativeHandle)
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
    /// Fires when the view is clicked, with the position in the view's own
    /// coordinates — the seam behind `NSView.mouseDown(with:)` for views whose
    /// widget has no built-in action (image views; custom views use the draw
    /// area's gestures).
    func setClickAction(for handle: NativeHandle, action: @escaping (Double, Double) -> Void)
    /// Routes a custom view's pointer events to its responder methods
    /// (`mouseEntered`/`mouseExited`/`mouseDown`/`rightMouseDown`). The demo's
    /// hover box, drag handle, and custom canvases rely on these.
    func setMouseHandler(for handle: NativeHandle, _ handler: @escaping (NativeMouseEvent) -> Void)
    /// Requests a redraw of a view with a draw handler.
    func setNeedsDisplay(_ handle: NativeHandle)
    /// Sets a checkbox/radio's on/off state.
    func setButtonState(_ on: Bool, for handle: NativeHandle)
    /// Sets a slider's or progress indicator's value.
    func setDoubleValue(_ value: Double, for handle: NativeHandle)
    /// Sets a pop-up button's selected item index.
    func setSelectedIndex(_ index: Int, for handle: NativeHandle)
    /// Orients a slider vertically or horizontally (AppKit's `isVertical`).
    func setSliderVertical(_ vertical: Bool, for handle: NativeHandle)
    /// Switches a date picker between the graphical calendar and the compact
    /// text-field style (AppKit's `datePickerStyle`).
    func setDatePickerGraphical(_ graphical: Bool, for handle: NativeHandle)
    /// Clamps the picker's selectable range (AppKit's `minDate`/`maxDate`).
    func setDateRange(min: Date?, max: Date?, for handle: NativeHandle)
    /// Sets the compact picker's display text. The **framework** formats it
    /// (locale, elements, calendar all being AppKit semantics, not GTK's), so
    /// the backend only renders what it is given.
    func setDatePickerText(_ text: String, for handle: NativeHandle)
    /// Highlights the selected element's character range in the compact field.
    func setDatePickerSelection(location: Int, length: Int, for handle: NativeHandle)
    /// The stepper reports a direction (+1/-1); the framework decides which
    /// element that moves.
    func setDateStepAction(for handle: NativeHandle, action: @escaping (Int) -> Void)
    /// A click in the compact field reports the character offset hit.
    func setDatePickerCursorAction(for handle: NativeHandle, action: @escaping (Int) -> Void)
    /// Left/right keys report -1/+1 to move the selected element.
    func setDatePickerMoveAction(for handle: NativeHandle, action: @escaping (Int) -> Void)
    /// A typed character (a digit, or "a"/"p" for AM/PM) reaches the selected
    /// element — AppKit's date field is type-to-edit, not stepper-only.
    func setDatePickerTypeAction(for handle: NativeHandle, action: @escaping (String) -> Void)
    /// Rebuilds a button as a push button, checkbox, or radio (AppKit's
    /// `setButtonType(_:)` applied to a control created as a plain button).
    func setButtonKind(_ kind: NativeButtonKind, title: String, for handle: NativeHandle)
    /// Toggles a text field between an editable, framed field and a borderless
    /// static label (AppKit's `isEditable`; the frame follows editability).
    func setTextEditable(_ editable: Bool, for handle: NativeHandle)
    /// Paints the view's background (`NSView.backgroundColor`); nil clears it.
    func setBackgroundColor(_ color: NSColor?, for handle: NativeHandle)
    /// Rebuilds a pop-up button's item list (AppKit's `addItems`/`removeAllItems`)
    /// and selects `selectedIndex`.
    func setPopUpItems(_ titles: [String], selectedIndex: Int, for handle: NativeHandle)
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
    /// Fires when the field is submitted (Enter) — AppKit's control action for
    /// a text field, distinct from per-keystroke text change.
    func setSubmitAction(for handle: NativeHandle, action: @escaping () -> Void)
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
