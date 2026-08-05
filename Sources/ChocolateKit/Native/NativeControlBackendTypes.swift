// Backend-seam vocabulary — Unified Chocolate Phase 3.
//
// The merge took the Win32 core's version of every same-named file, so the
// shared core arrived speaking only the Win32 half of the seam's vocabulary
// while the GTK backend was written against the other half. These are the
// types the GTK backend passes across `NativeControlBackend` that the Win32
// side never needed a name for.
//
// They are platform-neutral by construction — plain values and one drawing
// protocol, no GTK and no Win32 in any signature — so they belong in the core
// next to the protocol that uses them, not behind a conditional. The Win32
// backend simply doesn't implement the requirements that mention them; the
// protocol's default implementations cover it (see NativeControlBackend.swift).

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

/// Every kind of native object the seam can be asked to create.
///
/// A backend that has to answer questions about a handle after the fact —
/// "is this a slider or a stepper?" — needs a name for the answer. The Win32
/// backend records `Record.kind` as a free-form `String`; the GTK backend
/// keeps a typed table because it dispatches on the kind at runtime. This is
/// that vocabulary, shared so the two can't drift.
public enum NativeControlKind: Equatable {
    case window, view, button, label, textField, secureField, searchField, comboBox
    case checkbox, radio, slider, progress, popUp, stepper, level, textView
    case datePicker, colorWell, tabView, box, scrollView, splitView, segmented, imageView
    case tokenField, table, outline, collection, scroller
}

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
    /// Icon-theme name for the item's image, or nil for a text-only item.
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
    public init(imagePath: String? = nil, imageIsTemplate: Bool = false, identifier: String,
                label: String, iconName: String? = nil, isFlexibleSpace: Bool = false,
                viewHandle: NativeHandle? = nil, action: (() -> Void)? = nil) {
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

/// One section of a collection view: an optional header band, `itemCount`
/// items (addressed by their FLAT index across all sections), and an optional
/// footer band.
public struct NativeCollectionSection {
    /// The section's header view, or nil for no header band.
    public var header: NativeHandle?
    /// The section's footer view, or nil for no footer band.
    public var footer: NativeHandle?
    /// How many items this section holds.
    public var itemCount: Int
    /// Creates a section description.
    public init(header: NativeHandle? = nil, footer: NativeHandle? = nil, itemCount: Int) {
        self.header = header
        self.footer = footer
        self.itemCount = itemCount
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
    /// Appends a cubic Bezier curve from the current point to `(x, y)` with
    /// control points `(c1x, c1y)` and `(c2x, c2y)`.
    func curve(toX x: Double, y: Double, c1x: Double, c1y: Double, c2x: Double, c2y: Double)
    /// Appends an arc to the current path (angles in radians, AppKit space).
    func addArc(centerX: Double, centerY: Double, radius: Double,
                startAngleRadians: Double, endAngleRadians: Double, clockwise: Bool)
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
    /// Icons with their labels underneath.
    case iconAndLabel
    /// Icons only, no labels.
    case iconOnly
    /// Labels only, no icons.
    case labelOnly
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
    /// Icon-theme name for the tile, or nil for a text-only tile.
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
    /// Accelerator string for the key equivalent (e.g. "<Control>n"), or nil.
    public let accelerator: String?
    /// Handler invoked when the item is selected.
    public let action: (() -> Void)?
    /// Creates a menu item spec.
    public init(title: String, isSeparator: Bool = false, accelerator: String? = nil,
                action: (() -> Void)? = nil) {
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
