import Foundation

// Extension-only compatibility the shared demo uses. Computed/no-op members are
// safe to add here; stored properties live on their classes.

// MARK: - String drawing (immediate-mode text)

public extension String {
    /// Draws the string at a point. No-op until Cairo/Pango text rendering
    /// lands (custom-drawn text labels won't show yet, but the app runs).
    func draw(at point: NSPoint, withAttributes attrs: [NSAttributedString.Key: Any]?) {
        guard let context = NSGraphicsContext.current?.native else { return }
        let font = (attrs?[.font] as? NSFont)?.spec
        let color = (attrs?[.foregroundColor] as? NSColor) ?? .black
        context.drawText(self, at: point, font: font, color: color)
    }
    /// Draws the string starting at `rect.origin` (does not clip to `rect` yet).
    func draw(in rect: NSRect, withAttributes attrs: [NSAttributedString.Key: Any]?) {
        draw(at: rect.origin, withAttributes: attrs)
    }
    /// A rough size estimate (monospace-ish) so layout math compiles.
    func size(withAttributes attrs: [NSAttributedString.Key: Any]?) -> NSSize {
        NSMakeSize(CGFloat(count) * 7, 15)
    }
}

// MARK: - Appearance conveniences (WinChocolate spelling)

public extension NSAppearance {
    /// Dark detection (WinChocolate's `winIsDark`), mapped to `isDark`.
    var winIsDark: Bool { isDark }
}

// MARK: - Color conveniences

public extension NSColor {
    /// Builds a grayscale color in the calibrated color space.
    init(calibratedWhite white: CGFloat, alpha: CGFloat) {
        self.init(red: white, green: white, blue: white, alpha: alpha)
    }
    /// Builds a grayscale color.
    init(white: CGFloat, alpha: CGFloat) {
        self.init(red: white, green: white, blue: white, alpha: alpha)
    }
    /// Builds a grayscale color in the device color space.
    init(deviceWhite white: CGFloat, alpha: CGFloat) {
        self.init(red: white, green: white, blue: white, alpha: alpha)
    }
}

public extension NSColor {
    // The system colors are DYNAMIC on Apple — they resolve against the current
    // appearance every time they're read. Hardcoding them light was the cause of
    // the invisible-dark-mode bug: GTK's dark theme paints white label text, and
    // the demo painted its pages with a permanently light windowBackgroundColor
    // underneath it.
    private static var isDarkAppearance: Bool {
        NSApplication.shared.effectiveAppearance.isDark
    }

    /// Dynamic window background — light gray in light mode, near-black in dark.
    static var windowBackgroundColor: NSColor {
        isDarkAppearance ? NSColor(red: 0.16, green: 0.16, blue: 0.17) : NSColor(red: 0.93, green: 0.93, blue: 0.93)
    }
    /// Dynamic control background (e.g. text field fill).
    static var controlBackgroundColor: NSColor {
        isDarkAppearance ? NSColor(red: 0.12, green: 0.12, blue: 0.13) : NSColor(red: 0.98, green: 0.98, blue: 0.98)
    }
    /// Dynamic default control fill.
    static var controlColor: NSColor {
        isDarkAppearance ? NSColor(red: 0.25, green: 0.25, blue: 0.26) : NSColor(red: 0.90, green: 0.90, blue: 0.90)
    }
    /// Dynamic primary text color.
    static var textColor: NSColor {
        isDarkAppearance ? NSColor(red: 0.92, green: 0.92, blue: 0.92) : .black
    }
    /// Dynamic primary label color.
    static var labelColor: NSColor {
        isDarkAppearance ? NSColor(red: 0.92, green: 0.92, blue: 0.92) : .black
    }
    /// Dynamic secondary (dimmer) label color.
    static var secondaryLabelColor: NSColor {
        isDarkAppearance ? NSColor(red: 0.63, green: 0.63, blue: 0.65) : NSColor(red: 0.4, green: 0.4, blue: 0.4)
    }
    /// System accent blue.
    static var systemBlue: NSColor { NSColor(red: 0.0, green: 0.48, blue: 1.0) }
    /// System accent gray.
    static var systemGray: NSColor { NSColor(red: 0.56, green: 0.56, blue: 0.58) }
    /// System accent red.
    static var systemRed: NSColor { NSColor(red: 1.0, green: 0.23, blue: 0.19) }
    /// System accent green.
    static var systemGreen: NSColor { NSColor(red: 0.20, green: 0.78, blue: 0.35) }
}

// MARK: - Toolbar identifier / String bridging (temporary; see L15.3)

public extension String {
    /// `NSToolbarItem.Identifier` is currently a `String` typealias, so these
    /// AppKit member forms live on `String` until the type is promoted (L15.3).
    /// AppKit's `Identifier.rawValue` — identity here since the identifier is `String`.
    var rawValue: String { self }
    /// Standard toolbar identifier: a flexible-width spacer.
    static var flexibleSpace: String { NSToolbarItem.flexibleSpaceIdentifier }
    /// Standard toolbar identifier: a fixed-width spacer.
    static var space: String { "NSToolbarSpaceItem" }
    /// Standard toolbar identifier: a vertical separator.
    static var separator: String { "NSToolbarSeparatorItem" }
    /// Standard toolbar identifier: the Print item.
    static var print: String { "NSToolbarPrintItem" }
    /// Standard toolbar identifier: the Show Colors item.
    static var showColors: String { "NSToolbarShowColorsItem" }
    /// Standard toolbar identifier: the Show Fonts item.
    static var showFonts: String { "NSToolbarShowFontsItem" }
    /// Standard toolbar identifier: the Toggle Sidebar item.
    static var toggleSidebar: String { "NSToolbarToggleSidebarItem" }
    /// Standard toolbar identifier: the Toggle Inspector item.
    static var toggleInspector: String { "NSToolbarToggleInspectorItem" }
    /// Standard toolbar identifier: the sidebar tracking separator.
    static var sidebarTrackingSeparator: String { "NSToolbarSidebarTrackingSeparatorItem" }
    /// Standard toolbar identifier: the Cloud Sharing item.
    static var cloudSharing: String { "NSToolbarCloudSharingItem" }
}

// MARK: - Control integer values

public extension NSSlider {
    /// The slider's current value truncated to `Int`.
    var intValue: Int { Int(doubleValue) }
    /// Number of tick marks along the slider (stub — accepted for parity).
    var numberOfTickMarks: Int { get { 0 } set {} }
    /// Whether the slider snaps to tick-mark values (stub).
    var allowsTickMarkValuesOnly: Bool { get { false } set {} }
    /// Which side of the slider draws tick marks (stub).
    var tickMarkPosition: Int { get { 0 } set {} }
    /// AppKit-shaped action hook; write-only alias for `onValueChange`.
    var onAction: ((NSControl) -> Void)? { get { nil } set { onValueChange = newValue } }
}
public extension NSStepper {
    /// The stepper's current value truncated to `Int`.
    var intValue: Int { Int(doubleValue) }
}
public extension NSLevelIndicator {
    /// The indicator's current value truncated to `Int`.
    var intValue: Int { Int(doubleValue) }
}

// MARK: - Assorted control conveniences (accepted for API parity)

public extension NSPopUpButton {
    /// AppKit-shaped action hook; write-only alias for `onSelectionChange`.
    var onAction: ((NSControl) -> Void)? {
        // Write-only: a ((NSControl) -> Void) may stand in for a ((NSPopUpButton) -> Void)
        // (parameters are contravariant), but not the reverse, so there is no
        // getter. AppKit's action sender is the control, matching `NSControl`.
        get { nil }
        set { onSelectionChange = newValue }
    }
}

public extension NSColorWell {
    /// Activates the well so it becomes the color panel's target (no-op stub).
    func activate(_ exclusive: Bool) {}
    /// Deactivates the well (no-op stub).
    func deactivate() {}
    /// Visual style of the well (10.15+; stub — accepted for parity).
    var colorWellStyle: NSColorWellStyle { get { .default } set {} }
}

public extension NSImageView {
    /// AppKit-shaped action hook (stub — accepted for parity).
    var onAction: ((NSControl) -> Void)? { get { nil } set {} }
    /// Frame style drawn around the image (stub — accepted for parity).
    var imageFrameStyle: NSImageFrameStyle { get { .none } set {} }
    /// Whether the user can drop images onto the view (stub).
    var isEditable: Bool { get { false } set {} }
}

public extension NSImage {
    /// Draws the (file-backed) image scaled to fill `rect`, through the current
    /// graphics context — AppKit's `NSImage.draw(in:)`. The demo's Drawing page
    /// paints its artwork this way.
    func draw(in rect: NSRect) {
        guard let path, let context = NSGraphicsContext.current?.native else { return }
        context.drawImage(atPath: path, inRect: rect)
    }
    /// Draws the image at `point` using `from` as the source rect (stub uses `from` for size).
    func draw(at point: NSPoint, from: NSRect, operation: Int, fraction: CGFloat) {
        // `from` carries the source rect; fall back to it for the draw size.
        draw(in: NSMakeRect(point.x, point.y, from.width, from.height))
    }
}

public extension NSMenu {
    /// Inserts `item` at `index` (stub appends).
    func insertItem(_ item: NSMenuItem, at index: Int) { addItem(item) }
    /// The item at `index`, or `nil` if out of range.
    func item(at index: Int) -> NSMenuItem? { index < items.count ? items[index] : nil }
    /// Total number of items in the menu.
    var numberOfItems: Int { items.count }
}

public extension NSTextView {
    /// Undo manager scoped to this text view (fresh instance in the stub).
    var undoManager: UndoManager? { UndoManager() }
    /// Whether the view accepts rich-text attributes (stub — plain text only).
    var isRichText: Bool { get { false } set {} }
    /// Whether edits register with an undo manager (stub).
    var allowsUndo: Bool { get { false } set {} }
    /// Whether the user can edit the text.
    var isEditable: Bool { get { true } set {} }
    /// Whether the user can select the text.
    var isSelectable: Bool { get { true } set {} }
    /// AppKit-shaped alias for `onTextChange`.
    var onTextChanged: ((NSTextView) -> Void)? {
        get { onTextChange }
        set { onTextChange = newValue }
    }
    /// Appends `text` at the end of the contents (minimal `insertText`).
    func insertText(_ text: Any) {
        string += (text as? String) ?? "\(text)"
    }
    /// Inserts `text`, discarding `replacementRange` in the stub.
    func insertText(_ text: Any, replacementRange: NSRange) { insertText(text) }
    /// Backing attributed storage (stub reflecting the current string).
    var textStorage: NSTextStorage? { NSTextStorage(string: string) }
    /// The current selection range (accepted for parity; selection tracking is
    /// a later item).
    func setSelectedRange(_ range: NSRange) {}
    /// The current selection range (empty in the stub).
    var selectedRange: NSRange { NSMakeRange(0, 0) }
    /// All current selection ranges (empty in the stub).
    func selectedRanges() -> [NSValue] { [] }
}

public extension NSTableView {
    /// Reloads only the specified rows/columns (stub reloads everything).
    func reloadData(forRowIndexes rows: IndexSet, columnIndexes cols: IndexSet) { reloadData() }
    /// The table column at `index`, or `nil` if out of range.
    func tableColumn(at index: Int) -> NSTableColumn? {
        tableColumns.indices.contains(index) ? tableColumns[index] : nil
    }
}

public extension NSSavePanel {
    /// Whether the user can enter file types outside `allowedFileTypes` (stub).
    var allowsOtherFileTypes: Bool { get { false } set {} }
    /// Whether the New Folder button is available (stub — always yes here).
    var canCreateDirectories: Bool { get { true } set {} }
    /// Label shown next to the filename field (stub).
    var nameFieldLabel: String { get { "" } set {} }
    /// Runs the save panel as a sheet on `window`; here it runs modally and
    /// forwards the response.
    func beginSheetModal(for window: NSWindow, completionHandler: ((Int) -> Void)? = nil) {
        completionHandler?(runModal())
    }
}

public extension NSTextView {
    /// Forwards a text-finder action from a responder (no-op stub).
    func performTextFinderAction(_ sender: Any?) {}
}

public extension NSComboBox {
    /// Number of items shown in the dropdown before scrolling kicks in (stub).
    var numberOfVisibleItems: Int { get { 5 } set {} }
    /// Whether the field completes as the user types (stub).
    var completes: Bool { get { false } set {} }
    /// Whether the dropdown has a vertical scroller (stub — always yes here).
    var hasVerticalScroller: Bool { get { true } set {} }
    /// Whether the combo pulls its items from a data source (stub).
    var usesDataSource: Bool { get { false } set {} }
    /// Total number of items currently in the popup.
    var numberOfItems: Int { itemTitles.count }
    /// Appends each object's `String(describing:)` to the item list.
    func addItems(withObjectValues objects: [Any]) {
        itemTitles.append(contentsOf: objects.map { "\($0)" })
    }
    /// Appends a single object's string form to the item list.
    func addItem(withObjectValue object: Any) { itemTitles.append("\(object)") }
    /// Empties the item list.
    func removeAllItems() { itemTitles.removeAll() }
    /// Selects the item at `index`, copying its text into the field.
    func selectItem(at index: Int) {
        if itemTitles.indices.contains(index) { stringValue = itemTitles[index] }
    }
}

public extension NSSearchField {
    /// Whether the search action fires on every keystroke (stub).
    var sendsSearchStringImmediately: Bool { get { true } set {} }
    /// Whether the search action fires only when the user presses Return (stub).
    var sendsWholeSearchString: Bool { get { false } set {} }
    /// Maximum number of recent searches remembered (stub).
    var maximumRecents: Int { get { 0 } set {} }
    /// Recent search strings (stub — always empty).
    var recentSearches: [String] { get { [] } set {} }
}

public extension NSLevelIndicator {
    /// Number of tick marks (stub — accepted for parity).
    var numberOfTickMarks: Int { get { 0 } set {} }
    /// Number of major tick marks (stub).
    var numberOfMajorTickMarks: Int { get { 0 } set {} }
    /// Which side the tick marks appear on (stub).
    var tickMarkPosition: Int { get { 0 } set {} }
}

public extension NSAlert {
    /// WinChocolate's help-button hook (accepted for parity).
    var winHelpButtonAction: (() -> Void)? { get { nil } set {} }
}

public extension NSOutlineView {
    /// Toggles an item's expansion state (expand if collapsed, else collapse).
    func toggleItem(_ item: Any) {
        if isItemExpanded(item) { collapseItem(item) } else { expandItem(item) }
    }
    /// Whether `item` is currently expanded (stub — always `false`).
    func isItemExpanded(_ item: Any) -> Bool { false }
}

// Backend conveniences the shared demo calls. Default no-op / delegation so
// neither native backend has to implement them for the demo to build.
public extension NativeControlBackend {
    /// Scrolls a table row into view (default no-op).
    func scrollTableRowToVisible(_ row: Int, for handle: NativeHandle) {}
    /// Schedules `work` on the backend's main queue (default runs inline).
    func dispatchAsync(_ work: @escaping () -> Void) { work() }
}

public extension NSApplication {
    /// The application's key window (first window in the stub).
    var keyWindow: NSWindow? { windows.first }
    /// The application's main window (first window in the stub).
    var mainWindow: NSWindow? { windows.first }
    /// Notification posted when the effective appearance (light/dark) changes.
    nonisolated static var winEffectiveAppearanceDidChangeNotification: Notification.Name {
        Notification.Name("LinChocolateEffectiveAppearanceDidChange")
    }
}

public extension NSSavePanel {
    /// Convenience factory matching Apple's spelling.
    static func savePanel() -> NSSavePanel { NSSavePanel() }
    /// Message shown at the top of the panel (stub).
    var message: String { get { "" } set {} }
    /// Label on the panel's default (Save) button (stub).
    var prompt: String { get { "" } set {} }
    /// File extensions the user is allowed to save (stub).
    var allowedFileTypes: [String]? { get { nil } set {} }
}
public extension NSOpenPanel {
    /// Convenience factory matching Apple's spelling.
    static func openPanel() -> NSOpenPanel { NSOpenPanel() }
}

public extension NSColor {
    /// A dark gray color.
    static var darkGray: NSColor { NSColor(red: 0.33, green: 0.33, blue: 0.33) }
    /// A light gray color.
    static var lightGray: NSColor { NSColor(red: 0.66, green: 0.66, blue: 0.66) }
}

public extension NSGraphicsContext {
    /// Pushes the current graphics state onto the state stack.
    static func saveGraphicsState() { current?.native.saveState() }
    /// Pops and restores the most recently saved graphics state.
    static func restoreGraphicsState() { current?.native.restoreState() }
}

public extension NSBezierPath {
    /// Intersects the graphics context's clip region with this path (AppKit's
    /// `addClip()`). Scoped by `NSGraphicsContext.save/restoreGraphicsState()`,
    /// as the demo's oval-clipped stripes do. Was a no-op, so the stripes filled
    /// their whole rectangle instead of being confined to the oval.
    func addClip() {
        guard let context = NSGraphicsContext.current?.native else { return }
        replay(into: context)
        context.clipToCurrentPath()
    }
    /// AppKit's `setClip()` replaces the clip; here the enclosing
    /// save/restore already gives a fresh region, so it behaves like addClip.
    func setClip() { addClip() }
}

public extension NSAlert {
    /// Extra view shown below the alert's message (stub).
    var accessoryView: NSView? { get { nil } set {} }
    /// Custom icon shown next to the message (stub).
    var icon: NSImage? { get { nil } set {} }
    /// Runs the alert as a sheet on `window`; here it runs modally and
    /// forwards the response.
    func beginSheetModal(for window: NSWindow, completionHandler: ((Int) -> Void)? = nil) {
        completionHandler?(runModal())
    }
}

public extension NSView {
    /// AppKit starts the drag imperatively here; GTK drives drags from a
    /// `GtkDragSource` controller on the widget. We arm that controller with the
    /// item's string payload so a native press-drag from this view carries it.
    func beginDraggingSession(with items: [NSDraggingItem], event: NSEvent, source: NSDraggingSource) -> NSDraggingSession {
        if let payload = items.first?.payloadString {
            registerDraggingSource { payload }
        }
        return NSDraggingSession()
    }
}

public extension NSCollectionView {
    // item(at:) now lives on NSCollectionView itself (items are materialized).
    /// Reloads the items in `sections` (stub reloads everything).
    func reloadSections(_ sections: IndexSet) { reloadData() }
    /// Registers an item class for reuse under `identifier` (no-op stub).
    func register(_ itemClass: AnyClass?, forItemWithIdentifier identifier: String) {}
}

public extension NSPasteboard {
    /// Reads objects of the requested classes; here returns the string payload if any.
    func readObjects(forClasses classes: [AnyClass], options: [AnyHashable: Any]? = nil) -> [Any]? {
        string(forType: .string).map { [$0] }
    }
    /// Writes objects to the pasteboard (stub returns `true`).
    func writeObjects(_ objects: [Any]) -> Bool { true }
}

public extension NSMenu {
    /// Pops the menu up anchored under `item` at `location` in `view` (stub).
    @discardableResult
    func popUp(positioning item: NSMenuItem?, at location: NSPoint, in view: NSView?) -> Bool { false }
}

public extension NSSplitView {
    /// The split view's delegate (stub — not wired).
    var delegate: NSSplitViewDelegate? { get { nil } set {} }
    /// Visual style of the divider (raw integer, stub).
    var dividerStyle: Int { get { 0 } set {} }
}

public extension NSOutlineView {
    /// WinChocolate spelling for `dataSource`.
    var outlineDataSource: NSOutlineViewDataSource? {
        get { dataSource }
        set { dataSource = newValue }
    }
    /// WinChocolate spelling for `onSelectionChange`.
    var onSelectionChanged: ((NSOutlineView) -> Void)? {
        get { onSelectionChange }
        set { onSelectionChange = newValue }
    }
    /// AppKit-shaped action hook; write-only alias for `onSelectionChange`.
    var onAction: ((NSControl) -> Void)? { get { nil } set { onSelectionChange = newValue } }
    /// WinChocolate's outline drag-and-drop reorder callback (stub).
    var winOutlineReorderHandler: ((Any, Any?, Int) -> Void)? { get { nil } set {} }
    /// Selects the given rows (stub).
    func selectRowIndexes(_ indexes: IndexSet, byExtendingSelection extend: Bool) {}
    /// The item shown at `row` (stub returns `nil`).
    func item(atRow row: Int) -> Any? { nil }
    /// The row displaying `item` (stub returns `-1`).
    func row(forItem item: Any?) -> Int { -1 }
    /// Whether `item` can be expanded, delegated to the data source.
    func isItemExpandable(_ item: Any) -> Bool {
        dataSource?.outlineView(self, isItemExpandable: item) ?? false
    }
    /// Alias for `isItemExpandable`.
    func isExpandable(_ item: Any) -> Bool { isItemExpandable(item) }
    /// Indentation level for `item` (stub returns 0).
    func level(forItem item: Any?) -> Int { 0 }
}

public extension NSCollectionView {
    /// AppKit-shaped action hook; aliases `onSelectionChange`.
    var onAction: ((NSCollectionView) -> Void)? { get { onSelectionChange } set { onSelectionChange = newValue } }
}

public extension NSDatePicker {
    /// Picker mode (raw integer, stub — accepted for parity).
    var datePickerMode: Int { get { 0 } set {} }
}

public extension NSAlert {
    /// Whether the alert shows a "Do not show again" checkbox (stub).
    var showsSuppressionButton: Bool { get { false } set {} }
    /// The suppression checkbox, if one is shown (stub — always `nil`).
    var suppressionButton: NSButton? { nil }
}

public extension NSSecureTextField {
    /// AppKit-shaped alias for `onTextChange` typed for `NSSecureTextField`.
    var onTextChanged: ((NSSecureTextField) -> Void)? {
        get { onTextChange }
        set { onTextChange = newValue }
    }
}

// MARK: - Window zoom state

public extension NSWindow {
    /// Whether the window is currently zoomed (stub returns `false`).
    var isZoomed: Bool { false }
}

// MARK: - IndexPath (collection-view conveniences)

public extension IndexPath {
    /// The item index (last component of the path).
    var item: Int { last ?? 0 }
    /// The section index (first component of the path).
    var section: Int { first ?? 0 }
    /// Builds an index path with a section and item component.
    init(item: Int, section: Int) { self.init(indexes: [section, item]) }
}

// MARK: - Text view editing actions (no-op stubs)

public extension NSTextView {
    /// Standard responder Cut action (no-op stub).
    func cut(_ sender: Any?) {}
    /// Standard responder Copy action (no-op stub).
    func copy(_ sender: Any?) {}
    /// Standard responder Paste action (no-op stub).
    func paste(_ sender: Any?) {}
    /// Standard responder Select All action (no-op stub).
    func selectAll(_ sender: Any?) {}
}

// MARK: - Toolbar validation (no-op)

public extension NSToolbar {
    /// Re-runs validation on every visible toolbar item (no-op stub).
    func validateVisibleItems() {}
}

// MARK: - Window commands (accepted for API parity; mostly GTK-managed)

public extension NSWindow {
    /// Whether the window is the key window (stub — always yes).
    var isKeyWindow: Bool { true }
    /// Whether the window is the main window (stub — always yes).
    var isMainWindow: Bool { true }
    /// The window's current first responder (stub — none).
    var firstResponder: NSResponder? { nil }
    /// Makes the window the key window (no-op stub — GTK-managed).
    func makeKey() {}
    /// Makes the window the main window (no-op stub — GTK-managed).
    func makeMain() {}
    /// Convenience: brings the window forward with no sender.
    func makeKeyAndOrderFront() { makeKeyAndOrderFront(nil) }
    /// Brings the window forward without changing key status.
    func orderFront(_ sender: Any?) { makeKeyAndOrderFront(sender) }
    /// Toggles zoom (no-op stub — GTK-managed).
    func zoom(_ sender: Any?) {}
    /// Minimizes the window (no-op stub — GTK-managed).
    func miniaturize(_ sender: Any?) {}
    /// Toggles toolbar visibility (no-op stub).
    func toggleToolbarShown(_ sender: Any?) {}
    /// Advances the key view loop (no-op stub).
    func selectNextKeyView(_ sender: Any?) {}
    /// Steps the key view loop backwards (no-op stub).
    func selectPreviousKeyView(_ sender: Any?) {}
    /// Attempts to make `responder` first responder (stub — always succeeds).
    @discardableResult func makeFirstResponder(_ responder: NSView?) -> Bool { true }
    /// Forces the window's native peer to be created (no-op stub).
    func realizeNativePeer() {}
    /// The window's native handle (its GTK widget handle).
    var nativeHandle: NativeHandle? { handle }
    /// Rebuilds the key-view chain (no-op stub).
    func recalculateKeyViewLoop() {}
}

// MARK: - Outline / table / collection conveniences

public extension NSOutlineView {
    /// Expands `item` in the outline (no-op stub).
    func expandItem(_ item: Any?) {}
    /// Expands `item`, optionally including all its descendants (no-op stub).
    func expandItem(_ item: Any?, expandChildren: Bool) {}
    /// Collapses `item` in the outline (no-op stub).
    func collapseItem(_ item: Any?) {}
    /// Whether `item` is currently expanded (stub returns `false`).
    func isItemExpanded(_ item: Any?) -> Bool { false }
    /// Reloads the row for `item` (stub reloads everything).
    func reloadItem(_ item: Any?) { reloadData() }
}
