import Foundation

// Extension-only compatibility the shared demo uses. Computed/no-op members are
// safe to add here; stored properties live on their classes.

// MARK: - String drawing (immediate-mode text)

public extension String {
    /// Draws the string at a point. No-op until Cairo/Pango text rendering
    /// lands (custom-drawn text labels won't show yet, but the app runs).
    func draw(at point: NSPoint, withAttributes attrs: [NSAttributedString.Key: Any]?) {}
    func draw(in rect: NSRect, withAttributes attrs: [NSAttributedString.Key: Any]?) {}
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
    init(calibratedWhite white: CGFloat, alpha: CGFloat) {
        self.init(red: white, green: white, blue: white, alpha: alpha)
    }
    init(white: CGFloat, alpha: CGFloat) {
        self.init(red: white, green: white, blue: white, alpha: alpha)
    }
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

    static var windowBackgroundColor: NSColor {
        isDarkAppearance ? NSColor(red: 0.16, green: 0.16, blue: 0.17) : NSColor(red: 0.93, green: 0.93, blue: 0.93)
    }
    static var controlBackgroundColor: NSColor {
        isDarkAppearance ? NSColor(red: 0.12, green: 0.12, blue: 0.13) : NSColor(red: 0.98, green: 0.98, blue: 0.98)
    }
    static var controlColor: NSColor {
        isDarkAppearance ? NSColor(red: 0.25, green: 0.25, blue: 0.26) : NSColor(red: 0.90, green: 0.90, blue: 0.90)
    }
    static var textColor: NSColor {
        isDarkAppearance ? NSColor(red: 0.92, green: 0.92, blue: 0.92) : .black
    }
    static var labelColor: NSColor {
        isDarkAppearance ? NSColor(red: 0.92, green: 0.92, blue: 0.92) : .black
    }
    static var secondaryLabelColor: NSColor {
        isDarkAppearance ? NSColor(red: 0.63, green: 0.63, blue: 0.65) : NSColor(red: 0.4, green: 0.4, blue: 0.4)
    }
    static var systemBlue: NSColor { NSColor(red: 0.0, green: 0.48, blue: 1.0) }
    static var systemGray: NSColor { NSColor(red: 0.56, green: 0.56, blue: 0.58) }
    static var systemRed: NSColor { NSColor(red: 1.0, green: 0.23, blue: 0.19) }
    static var systemGreen: NSColor { NSColor(red: 0.20, green: 0.78, blue: 0.35) }
}

// MARK: - Toolbar identifier / String bridging (temporary; see L15.3)

public extension String {
    /// `NSToolbarItem.Identifier` is currently a `String` typealias, so these
    /// AppKit member forms live on `String` until the type is promoted (L15.3).
    var rawValue: String { self }
    static var flexibleSpace: String { NSToolbarItem.flexibleSpaceIdentifier }
    static var space: String { "NSToolbarSpaceItem" }
    static var separator: String { "NSToolbarSeparatorItem" }
    static var print: String { "NSToolbarPrintItem" }
    static var showColors: String { "NSToolbarShowColorsItem" }
    static var showFonts: String { "NSToolbarShowFontsItem" }
    static var toggleSidebar: String { "NSToolbarToggleSidebarItem" }
    static var toggleInspector: String { "NSToolbarToggleInspectorItem" }
    static var sidebarTrackingSeparator: String { "NSToolbarSidebarTrackingSeparatorItem" }
    static var cloudSharing: String { "NSToolbarCloudSharingItem" }
}

// MARK: - Control integer values

public extension NSSlider {
    var intValue: Int { Int(doubleValue) }
    var numberOfTickMarks: Int { get { 0 } set {} }
    var allowsTickMarkValuesOnly: Bool { get { false } set {} }
    var tickMarkPosition: Int { get { 0 } set {} }
    var onAction: ((NSSlider) -> Void)? { get { onValueChange } set { onValueChange = newValue } }
}
public extension NSStepper { var intValue: Int { Int(doubleValue) } }
public extension NSLevelIndicator { var intValue: Int { Int(doubleValue) } }

// MARK: - Assorted control conveniences (accepted for API parity)

public extension NSPopUpButton {
    var onAction: ((NSPopUpButton) -> Void)? {
        get { onSelectionChange }
        set { onSelectionChange = newValue }
    }
}

public extension NSColorWell {
    func activate(_ exclusive: Bool) {}
    func deactivate() {}
    var colorWellStyle: NSColorWellStyle { get { .default } set {} }
}

public extension NSImageView {
    var onAction: ((NSImageView) -> Void)? { get { nil } set {} }
    var imageFrameStyle: NSImageFrameStyle { get { .none } set {} }
    var isEditable: Bool { get { false } set {} }
}

public extension NSImage {
    func draw(in rect: NSRect) {}
    func draw(at point: NSPoint, from: NSRect, operation: Int, fraction: CGFloat) {}
}

public extension NSMenu {
    func insertItem(_ item: NSMenuItem, at index: Int) { addItem(item) }
    func item(at index: Int) -> NSMenuItem? { index < items.count ? items[index] : nil }
    var numberOfItems: Int { items.count }
}

public extension NSTextView {
    var undoManager: UndoManager? { UndoManager() }
    var isRichText: Bool { get { false } set {} }
    var allowsUndo: Bool { get { false } set {} }
    var isEditable: Bool { get { true } set {} }
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
    func insertText(_ text: Any, replacementRange: NSRange) { insertText(text) }
    /// Backing attributed storage (stub reflecting the current string).
    var textStorage: NSTextStorage? { NSTextStorage(string: string) }
    /// The current selection range (accepted for parity; selection tracking is
    /// a later item).
    func setSelectedRange(_ range: NSRange) {}
    var selectedRange: NSRange { NSMakeRange(0, 0) }
    func selectedRanges() -> [NSValue] { [] }
}

public extension NSTableView {
    func scrollRowToVisible(_ row: Int) {}
    func reloadData(forRowIndexes rows: IndexSet, columnIndexes cols: IndexSet) { reloadData() }
    func tableColumn(at index: Int) -> NSTableColumn? {
        tableColumns.indices.contains(index) ? tableColumns[index] : nil
    }
}

public extension NSSavePanel {
    var allowsOtherFileTypes: Bool { get { false } set {} }
    var canCreateDirectories: Bool { get { true } set {} }
    var nameFieldLabel: String { get { "" } set {} }
    func beginSheetModal(for window: NSWindow, completionHandler: ((Int) -> Void)? = nil) {
        completionHandler?(runModal())
    }
}

public extension NSTextView {
    func performTextFinderAction(_ sender: Any?) {}
}

public extension NSComboBox {
    var numberOfVisibleItems: Int { get { 5 } set {} }
    var completes: Bool { get { false } set {} }
    var hasVerticalScroller: Bool { get { true } set {} }
    var usesDataSource: Bool { get { false } set {} }
    var numberOfItems: Int { itemTitles.count }
    func addItems(withObjectValues objects: [Any]) {
        itemTitles.append(contentsOf: objects.map { "\($0)" })
    }
    func addItem(withObjectValue object: Any) { itemTitles.append("\(object)") }
    func removeAllItems() { itemTitles.removeAll() }
    func selectItem(at index: Int) {
        if itemTitles.indices.contains(index) { stringValue = itemTitles[index] }
    }
}

public extension NSSearchField {
    var sendsSearchStringImmediately: Bool { get { true } set {} }
    var sendsWholeSearchString: Bool { get { false } set {} }
    var maximumRecents: Int { get { 0 } set {} }
    var recentSearches: [String] { get { [] } set {} }
}

public extension NSLevelIndicator {
    var isEditable: Bool { get { false } set {} }
    var numberOfTickMarks: Int { get { 0 } set {} }
    var numberOfMajorTickMarks: Int { get { 0 } set {} }
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
    func isItemExpanded(_ item: Any) -> Bool { false }
}

// Backend conveniences the shared demo calls. Default no-op / delegation so
// neither native backend has to implement them for the demo to build.
public extension NativeControlBackend {
    func scrollTableRowToVisible(_ row: Int, for handle: NativeHandle) {}
    func dispatchAsync(_ work: @escaping () -> Void) { work() }
}

public extension NSApplication {
    var keyWindow: NSWindow? { windows.first }
    var mainWindow: NSWindow? { windows.first }
    nonisolated static var winEffectiveAppearanceDidChangeNotification: Notification.Name {
        Notification.Name("LinChocolateEffectiveAppearanceDidChange")
    }
}

public extension NSSavePanel {
    static func savePanel() -> NSSavePanel { NSSavePanel() }
    var message: String { get { "" } set {} }
    var prompt: String { get { "" } set {} }
    var allowedFileTypes: [String]? { get { nil } set {} }
}
public extension NSOpenPanel {
    static func openPanel() -> NSOpenPanel { NSOpenPanel() }
}

public extension NSColor {
    static var darkGray: NSColor { NSColor(red: 0.33, green: 0.33, blue: 0.33) }
    static var lightGray: NSColor { NSColor(red: 0.66, green: 0.66, blue: 0.66) }
}

public extension NSGraphicsContext {
    static func saveGraphicsState() { current?.native.saveState() }
    static func restoreGraphicsState() { current?.native.restoreState() }
}

public extension NSBezierPath {
    func addClip() { }
    func setClip() { }
}

public extension NSAlert {
    var accessoryView: NSView? { get { nil } set {} }
    var icon: NSImage? { get { nil } set {} }
    func beginSheetModal(for window: NSWindow, completionHandler: ((Int) -> Void)? = nil) {
        completionHandler?(runModal())
    }
}

public extension NSView {
    func beginDraggingSession(with items: [NSDraggingItem], event: NSEvent, source: NSDraggingSource) -> NSDraggingSession {
        NSDraggingSession()
    }
}

public extension NSCollectionView {
    func item(at indexPath: IndexPath) -> NSCollectionViewItem? { nil }
    func item(at index: Int) -> NSCollectionViewItem? { nil }
    // elementKindSectionHeader/Footer now live on NSCollectionView itself,
    // alongside the register/makeSupplementaryView pipeline they belong to.
    func reloadSections(_ sections: IndexSet) { reloadData() }
    func register(_ itemClass: AnyClass?, forItemWithIdentifier identifier: String) {}
}

public extension NSPasteboard {
    func readObjects(forClasses classes: [AnyClass], options: [AnyHashable: Any]? = nil) -> [Any]? {
        string(forType: .string).map { [$0] }
    }
    func writeObjects(_ objects: [Any]) -> Bool { true }
}

public extension NSMenu {
    func popUp(positioning item: NSMenuItem?, at location: NSPoint, in view: NSView?) -> Bool { false }
}

public extension NSSplitView {
    var delegate: NSSplitViewDelegate? { get { nil } set {} }
    var dividerStyle: Int { get { 0 } set {} }
}

public extension NSOutlineView {
    var outlineDataSource: NSOutlineViewDataSource? {
        get { dataSource }
        set { dataSource = newValue }
    }
    var onSelectionChanged: ((NSOutlineView) -> Void)? {
        get { onSelectionChange }
        set { onSelectionChange = newValue }
    }
    var onAction: ((NSOutlineView) -> Void)? { get { onSelectionChange } set { onSelectionChange = newValue } }
    var winOutlineReorderHandler: ((Any, Any?, Int) -> Void)? { get { nil } set {} }
    func selectRowIndexes(_ indexes: IndexSet, byExtendingSelection extend: Bool) {}
    func item(atRow row: Int) -> Any? { nil }
    func row(forItem item: Any?) -> Int { -1 }
    func isItemExpandable(_ item: Any) -> Bool {
        dataSource?.outlineView(self, isItemExpandable: item) ?? false
    }
    func isExpandable(_ item: Any) -> Bool { isItemExpandable(item) }
    func level(forItem item: Any?) -> Int { 0 }
}

public extension NSCollectionView {
    var selectionIndexPaths: Set<IndexPath> { get { [] } set {} }
    var onAction: ((NSCollectionView) -> Void)? { get { onSelectionChange } set { onSelectionChange = newValue } }
}

public extension NSDatePicker {
    var datePickerElements: NSDatePickerElementFlags { get { .yearMonthDay } set {} }
    var datePickerMode: Int { get { 0 } set {} }
    var minDate: Date? { get { nil } set {} }
    var maxDate: Date? { get { nil } set {} }
}

public extension NSLevelIndicator {
    var levelIndicatorStyle: NSLevelIndicatorStyle { get { .continuousCapacity } set {} }
    var warningValue: Double { get { 0 } set {} }
    var criticalValue: Double { get { 0 } set {} }
}

public extension NSAlert {
    var showsSuppressionButton: Bool { get { false } set {} }
    var suppressionButton: NSButton? { nil }
}

public extension NSSecureTextField {
    var onTextChanged: ((NSSecureTextField) -> Void)? {
        get { onTextChange }
        set { onTextChange = newValue }
    }
}

// MARK: - Window zoom state

public extension NSWindow {
    var isZoomed: Bool { false }
}

// MARK: - IndexPath (collection-view conveniences)

public extension IndexPath {
    var item: Int { last ?? 0 }
    var section: Int { first ?? 0 }
    init(item: Int, section: Int) { self.init(indexes: [section, item]) }
}

// MARK: - Text view editing actions (no-op stubs)

public extension NSTextView {
    func cut(_ sender: Any?) {}
    func copy(_ sender: Any?) {}
    func paste(_ sender: Any?) {}
    func selectAll(_ sender: Any?) {}
}

// MARK: - Toolbar validation (no-op)

public extension NSToolbar {
    func validateVisibleItems() {}
}

// MARK: - Window commands (accepted for API parity; mostly GTK-managed)

public extension NSWindow {
    var isKeyWindow: Bool { true }
    var isMainWindow: Bool { true }
    var firstResponder: NSView? { nil }
    func makeKey() {}
    func makeMain() {}
    func makeKeyAndOrderFront() { makeKeyAndOrderFront(nil) }
    func orderFront(_ sender: Any?) { makeKeyAndOrderFront(sender) }
    func orderOut(_ sender: Any?) {}
    func close() {}
    func performClose(_ sender: Any?) {}
    func zoom(_ sender: Any?) {}
    func miniaturize(_ sender: Any?) {}
    func toggleToolbarShown(_ sender: Any?) {}
    func selectNextKeyView(_ sender: Any?) {}
    func selectPreviousKeyView(_ sender: Any?) {}
    @discardableResult func makeFirstResponder(_ responder: NSView?) -> Bool { true }
    func realizeNativePeer() {}
    var nativeHandle: NativeHandle? { handle }
    func recalculateKeyViewLoop() {}
}

// MARK: - Outline / table / collection conveniences

public extension NSOutlineView {
    func expandItem(_ item: Any?) {}
    func expandItem(_ item: Any?, expandChildren: Bool) {}
    func collapseItem(_ item: Any?) {}
    func isItemExpanded(_ item: Any?) -> Bool { false }
    func reloadItem(_ item: Any?) { reloadData() }
}
