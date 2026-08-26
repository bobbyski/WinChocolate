/// Data source for an AppKit-shaped table view.
@MainActor
public protocol NSTableViewDataSource: NSObjectProtocol {
    /// Returns the number of rows in the table.
    func numberOfRows(in tableView: NSTableView) -> Int

    /// Returns a display value for a column and row.
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any?

    /// Updates the model after an editable value changes.
    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int)

    /// Returns the object that supplies a row's pasteboard representation for a
    /// drag out of the table (a `String`, file `URL`, or `NSPasteboardItem`), or
    /// `nil` if the row is not draggable — matching AppKit's
    /// `tableView(_:pasteboardWriterForRow:)`.
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting?

    /// Accepts a drop at a target row, returning whether it was consumed —
    /// AppKit's exact `tableView(_:acceptDrop:row:dropOperation:)`. Covers
    /// external (or cross-view) content drops AND the table's own row-reorder
    /// drops (a `.move`-masked local drag whose pasteboard carries the dragged
    /// row indexes as a comma-separated string). Read the payload from
    /// `info.draggingPasteboard`; external drops require the table to be
    /// registered for the dragged types (`registerForDraggedTypes`).
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool
}

/// Delegate for table-view notifications.
@MainActor
public protocol NSTableViewDelegate: NSObjectProtocol {
    /// Called after the selected row changes.
    func tableViewSelectionDidChange(_ notification: Notification)

    /// Returns a view for a row/column in view-based table configurations.
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?

    /// Returns a full-width background/row view for a row in view-based tables.
    func tableView(_ tableView: NSTableView, rowViewFor row: Int) -> NSTableRowView?

    /// Returns a custom height for a row.
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat

    /// Called after table sort descriptors change.
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor])
}

/// Adds public behavior to `NSTableViewDataSource`.
public extension NSTableViewDataSource {
    /// Default: no display value (view-based tables vend views instead).
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        nil
    }

    /// Default no-op setter for read-only tables.
    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {}

    /// Default: rows are not draggable out of the table.
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        nil
    }

    /// Default: the table refuses drops.
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        false
    }
}

/// Adds public behavior to `NSTableViewDelegate`.
public extension NSTableViewDelegate {
    /// Default table selection notification.
    func tableViewSelectionDidChange(_ notification: Notification) {}

    /// Default view-based table hook.
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        nil
    }

    /// Default row-view hook (no custom row view).
    func tableView(_ tableView: NSTableView, rowViewFor row: Int) -> NSTableRowView? {
        nil
    }

    /// Default row height.
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        tableView.rowHeight
    }

    /// Default sort-descriptor notification.
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {}
}

/// A row-and-column data view.
///
/// This first WinChocolate slice preserves AppKit's common data-source shape
/// and maps the classic backend to a native list box until a full ListView
/// implementation lands.
open class NSTableView: NSControl {

    /// The operations this table permits as a drag source, split by
    /// destination locality — AppKit's `setDraggingSourceOperationMask(_:forLocal:)`.
    /// A **local mask containing `.move`** (plus a data source that vends
    /// `pasteboardWriterForRow`) enables drag-to-reorder: the drop arrives at
    /// the data source's `tableView(_:acceptDrop:row:dropOperation:)` with
    /// `.above`, carrying the dragged row indexes on the pasteboard.
    open func setDraggingSourceOperationMask(_ mask: NSDragOperation, forLocal isLocal: Bool) {
        if isLocal {
            winLocalDragOperationMask = mask
        } else {
            winExternalDragOperationMask = mask
        }
    }

    /// The local-destination source mask (see
    /// `setDraggingSourceOperationMask(_:forLocal:)`). WinChocolate defaults
    /// to no `.move` so reorder is opt-in, as porting apps expect to call the
    /// mask setter explicitly.
    package var winLocalDragOperationMask: NSDragOperation = [.copy, .link, .generic]

    /// The external-destination source mask.
    package var winExternalDragOperationMask: NSDragOperation = [.copy, .link, .generic]

    /// The drop row/operation a data source retargeted the current drop to via
    /// `setDropRow(_:dropOperation:)`.
    package var winProposedDropRow: Int = -1
    package var winProposedDropOperation: DropOperation = .above

    /// Retargets the current drop to a row and operation — AppKit's
    /// `setDropRow(_:dropOperation:)`. Called from `validateDrop` to convert a
    /// proposed `.on` (pointer over a row body) into the reorder gap (`.above`),
    /// which is the only way to make the whole table a valid reorder target.
    /// WinChocolate's drawn reorder path already lands on the inter-row gap, so
    /// this records the retarget for source-compatibility with that recipe.
    open func setDropRow(_ row: Int, dropOperation: DropOperation) {
        winProposedDropRow = row
        winProposedDropOperation = dropOperation
    }

    /// Whether a reorder drag may start from a row: the explicit handler
    /// (framework-internal path), or AppKit's recipe — a `.move` local mask
    /// plus a data-source pasteboard writer for the row.
    package func winReorderDragEnabled(forRow row: Int) -> Bool {
        if winRowReorderHandler != nil {
            return true
        }

        return winLocalDragOperationMask.contains(.move)
            && winMainActor { winEffectiveDataSource?.tableView(self, pasteboardWriterForRow: row) } != nil
    }

    /// Selection-changed notification name.
    public static let selectionDidChangeNotification = "NSTableViewSelectionDidChangeNotification"

    /// Table columns in display order.
    public internal(set) var tableColumns: [NSTableColumn] = []

    /// Object that provides row values.
    open weak var dataSource: NSTableViewDataSource?

    /// Object notified about selection changes.
    open weak var delegate: NSTableViewDelegate?

    /// The data source the table machinery actually reads: `dataSource` for a
    /// plain table; `NSOutlineView` overrides this to interpose its
    /// row-flattening adapter while `dataSource` keeps AppKit's semantics
    /// (returning the outline data source the app assigned).
    var winEffectiveDataSource: NSTableViewDataSource? { dataSource }

    /// The delegate the table machinery actually consults (see
    /// `winEffectiveDataSource`).
    var winEffectiveDelegate: NSTableViewDelegate? { delegate }

    /// Whether multiple rows may be selected.
    open var allowsMultipleSelection: Bool = false {
        didSet {
            guard let nativeHandle else {
                return
            }
            realizedBackend?.setTableAllowsMultipleSelection(allowsMultipleSelection, for: nativeHandle)
        }
    }

    /// Whether an empty selection is allowed.
    open var allowsEmptySelection: Bool = true

    /// Whether columns can be reordered by table UI.
    open var allowsColumnReordering: Bool = false

    /// Whether columns can be resized by table UI.
    open var allowsColumnResizing: Bool = true

    /// Whether alternating row backgrounds are requested.
    open var usesAlternatingRowBackgroundColors: Bool = false

    /// Requested row height.
    open var rowHeight: CGFloat = 17

    /// Whether rows measure themselves automatically. Stored for AppKit
    /// shape; the drawn table asks the delegate's `heightOfRow` either way.
    open var usesAutomaticRowHeights: Bool = false

    /// Re-reads the heights of the given rows from the delegate.
    ///
    /// The drawn table queries heights on every paint, so a repaint is the
    /// whole refresh.
    open func noteHeightOfRows(withIndexesChanged indexes: IndexSet) {
        needsDisplay = true
    }

    /// Selects rows by an `IndexSet`, matching AppKit's signature.
    open func selectRowIndexes(_ indexes: IndexSet, byExtendingSelection extend: Bool) {
        selectRows(Set(indexes), byExtendingSelection: extend)
    }

    /// Reloads specific rows/columns by `IndexSet`, matching AppKit's
    /// signature.
    /// Row insert/remove animations, matching AppKit's option set.
    ///
    /// Accepted everywhere AppKit accepts it. No Chocolate backend animates row
    /// changes yet, so the rows appear and disappear without sliding — the set
    /// exists so the call sites that describe the animation they want keep
    /// compiling, and keep describing it for when a backend can.
    public struct AnimationOptions: OptionSet, Sendable {
        /// Raw option value.
        public let rawValue: UInt

        /// Creates options from a raw value.
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// No animation.
        public static let effectNone = AnimationOptions(rawValue: 0)
        /// Fade the rows in or out.
        public static let effectFade = AnimationOptions(rawValue: 1 << 1)
        /// Slide the rows up.
        public static let effectGap = AnimationOptions(rawValue: 1 << 2)
        /// Slide the rows in from the top.
        public static let slideUp = AnimationOptions(rawValue: 1 << 4)
        /// Slide the rows in from the bottom.
        public static let slideDown = AnimationOptions(rawValue: 1 << 5)
        /// Slide the rows in from the left.
        public static let slideLeft = AnimationOptions(rawValue: 1 << 6)
        /// Slide the rows in from the right.
        public static let slideRight = AnimationOptions(rawValue: 1 << 7)
    }

    open func reloadData(forRowIndexes rowIndexes: IndexSet, columnIndexes: IndexSet) {
        winReloadData(forRowIndexes: rowIndexes, columnIndexes: columnIndexes)
    }

    /// Space between table cells.
    open var intercellSpacing: NSSize = NSMakeSize(3, 2)

    /// Grid-line style.
    open var gridStyleMask: GridLineStyle = []

    /// Selection highlight style.
    open var selectionHighlightStyle: SelectionHighlightStyle = .regular

    /// Column autoresizing style. Applied when `sizeToFit()` runs (AppKit also
    /// applies it during live resize; here it is driven explicitly).
    open var columnAutoresizingStyle: ColumnAutoresizingStyle = .uniformColumnAutoresizingStyle

    /// The table's overall look, as AppKit's `NSTableView.Style`.
    ///
    /// `.sourceList` is the one that matters: it is what makes a sidebar table
    /// look like a sidebar rather than a spreadsheet. The backends draw their
    /// own platform's list, so the value is carried and read by the drawn path
    /// rather than reshaping a native control.
    public enum Style: Sendable {
        /// The system decides from context.
        case automatic
        /// A full-width table.
        case fullWidth
        /// An inset table.
        case inset
        /// The sidebar look.
        case sourceList
        /// A plain table.
        case plain
    }

    /// The table's overall look.
    open var style: Style = .automatic {
        didSet { needsDisplay = true }
    }

    /// The colour drawn behind the rows.
    open var backgroundColor: NSColor? {
        didSet { needsDisplay = true }
    }

    /// The name column widths and order are remembered under.
    ///
    /// Persisted through the same preferences store the rest of the framework
    /// uses, so a table restores its layout on every platform rather than only
    /// where a defaults database exists.
    open var autosaveName: String?

    /// Whether column widths and order are saved automatically.
    open var autosaveTableColumns: Bool = false

    /// Runs a body for each row view currently realized.
    ///
    /// AppKit's way of reaching the row views without asking the delegate to
    /// remake them — used to re-theme rows in place. The rows a backend has
    /// realized are the ones it hands back.
    open func enumerateAvailableRowViews(_ handler: (NSTableRowView, Int) -> Void) {
        for (index, view) in winRealizedRowViews.sorted(by: { $0.key < $1.key }) {
            handler(view, index)
        }
    }

    /// Inserts rows at a set of indexes.
    ///
    /// The rows come from the data source, so this reloads: the animation
    /// option is accepted and not performed — the rows appear, they just do
    /// not slide in.
    open func insertRows(at indexes: IndexSet, withAnimation options: AnimationOptions = []) {
        reloadData()
    }

    /// Removes rows at a set of indexes.
    open func removeRows(at indexes: IndexSet, withAnimation options: AnimationOptions = []) {
        reloadData()
    }

    /// Row views the backend has realized, keyed by row.
    var winRealizedRowViews: [Int: NSTableRowView] = [:]

    /// Resizes the last column so the columns exactly fill the table's width,
    /// clamped to that column's min/max — AppKit's `sizeLastColumnToFit()`.
    open func sizeLastColumnToFit() {
        guard let lastIndex = tableColumns.indices.last else {
            return
        }
        let spacing = intercellSpacing.width * CGFloat(max(0, tableColumns.count - 1))
        let others = tableColumns.dropLast().reduce(0) { $0 + $1.width }
        let target = frame.size.width - spacing - others
        tableColumns[lastIndex].width = winClampedColumnWidth(target, for: tableColumns[lastIndex])
        winApplyColumnWidths()
    }

    /// Resizes columns to fill the table's width per `columnAutoresizingStyle`,
    /// clamped to each column's min/max — AppKit's `sizeToFit()`.
    open override func sizeToFit() {
        winSizeToFit()
    }

    /// Current table sort descriptors.
    open var sortDescriptors: [NSSortDescriptor] = [] {
        didSet {
            winMainActor { winEffectiveDelegate?.tableView(self, sortDescriptorsDidChange: oldValue) }
        }
    }

    /// The table's column-header view. Auto-created; set to `nil` to hide the
    /// header (e.g. inside `NSBrowser` columns).
    open lazy var headerView: NSTableHeaderView? = {
        let header = NSTableHeaderView(frame: .zero)
        header.tableView = self
        return header
    }()

    /// Framework-internal selection hook (browser columns, the font panel's
    /// family list). Not API: applications use
    /// `tableViewSelectionDidChange(_:)` on the delegate, as in AppKit.
    var winInternalSelectionChanged: ((NSTableView) -> Void)?

    /// Current selected row, or `-1` when nothing is selected.
    public internal(set) var selectedRow: Int = -1

    /// Current selected column, or `-1` when nothing is selected.
    public internal(set) var selectedColumn: Int = -1

    /// Current selected row indexes.
    public internal(set) var selectedRowIndexes: Set<Int> = []

    internal var rowValues: [[String]] = []
    /// The raw object values behind `rowValues`, kept in parallel so the drawn
    /// table can render an `NSAttributedString` cell with its own attributes.
    internal var rowRawValues: [[Any?]] = []
    internal var isUpdatingSelectionFromNative = false

    // MARK: - Framework-drawn (view-based) table state
    //
    // When the delegate vends cell views, the table realizes a custom-drawn
    // peer that draws the header/grid/selection itself and hosts those views
    // per cell — something the native list-view can't do.
    /// Forces this table onto the framework-drawn, view-based rendering path.
    ///
    /// This is normally unnecessary: the table now auto-detects view-based mode
    /// the way AppKit does — if the delegate vends a cell view (or a row view),
    /// it uses the drawn peer that draws its own header/grid/selection and hosts
    /// those views. Set this `true` only to force the drawn (all-text) peer for
    /// a table whose delegate vends no views. Cell-based tables (no `viewFor`)
    /// keep the native list-view.
    open var winUsesViewBasedCells: Bool = false
    var winIsDrawn = false
    var winHostedCellViews: [NSView] = []
    /// Recycled hosted cell/row views available for reuse, keyed by identifier —
    /// populated from the outgoing views at the start of each drawn rebuild and
    /// drained by `makeView(withIdentifier:owner:)`.
    var winCellViewReusePool: [String: [NSView]] = [:]

    /// Returns a recycled hosted view previously created with `identifier`, or
    /// `nil` when none is available — matching AppKit's
    /// `makeView(withIdentifier:owner:)` for a view-based table with no nib/class
    /// registered (the delegate creates a fresh view, stamping its `identifier`,
    /// on a `nil` result). Reused views are handed back during a drawn rebuild.
    open func makeView(withIdentifier identifier: NSUserInterfaceItemIdentifier, owner: Any?) -> NSView? {
        guard var pooled = winCellViewReusePool[identifier.rawValue], let reused = pooled.popLast() else {
            return nil
        }
        winCellViewReusePool[identifier.rawValue] = pooled
        reused.identifier = identifier
        return reused
    }
    var winDrawnRowHeight: CGFloat = 24
    var winDrawnHeaderHeight: CGFloat = 24
    /// Per-row heights, cached on each rebuild (honors the delegate's
    /// `heightOfRow`); empty until the first drawn rebuild.
    var winRowHeights: [CGFloat] = []
    /// Encoded `(row, column)` keys of cells that host a delegate view, so the
    /// drawn paint knows which cells to draw text for instead (mixed tables).
    var winHostedCellKeys: Set<Int> = []
    /// Delegate-vended full-width row background views, by row.
    var winHostedRowViews: [Int: NSTableRowView] = [:]

    /// Framework-internal reorder hook (the outline's row bridge uses it).
    /// Not API (18.8): applications enable reorder with AppKit's recipe —
    /// `setDraggingSourceOperationMask(.move, forLocal: true)`, a data-source
    /// `pasteboardWriterForRow`, and `tableView(_:acceptDrop:row:dropOperation:)`.
    package var winRowReorderHandler: ((_ fromRows: IndexSet, _ toIndex: Int) -> Void)?
    /// The row the reorder drag started on, or `-1`.
    var winDraggingRow = -1
    /// The set of rows being dragged (the pressed row, or the whole selection
    /// when the pressed row is part of a multi-row selection).
    var winDraggingRows: IndexSet = IndexSet()
    /// The insertion index the drag currently targets, or `-1`.
    var winDropIndex = -1
    /// A row whose selection collapse was deferred to mouse-up (AppKit lets you
    /// drag a multi-row selection by not collapsing on mouse-down), or `-1`.
    var winPendingCollapseRow = -1
    /// A row armed to begin an external (system/OLE) drag on the next drag move,
    /// or `-1`. Used when the data source vends a pasteboard writer for the row.
    var winExternalDragRow = -1
    /// The pinned header strip installed on the enclosing scroll view, if any.
    var winPinnedHeaderStrip: WinDrawnHeaderStrip?
    /// The column being interactively resized from the header, or `-1`.
    var winResizingColumn = -1
    /// The column pressed for a potential reorder drag, or `-1`.
    var winHeaderDragColumn = -1
    /// The x where the header press began (for the reorder drag threshold).
    var winHeaderDragStartX: CGFloat = 0
    /// The column insertion index a reorder drag currently targets, or `-1`.
    var winHeaderDropIndex = -1
    var winResizeStartX: CGFloat = 0
    var winResizeStartWidth: CGFloat = 0
    /// The live in-place editor overlay for a drawn cell, if any.
    var winDrawnEditField: NSTextField?
    var winDrawnEditRow = -1
    var winDrawnEditColumn = -1

    /// Whether a drawn cell is currently being edited in the overlay editor.
    public var winIsEditingDrawnCell: Bool { winDrawnEditField != nil }
    /// The row currently being edited in the drawn overlay, or `-1`.
    public var winEditingRow: Int { winDrawnEditRow }
    /// The column currently being edited in the drawn overlay, or `-1`.
    public var winEditingColumn: Int { winDrawnEditColumn }
    /// Shared delegate that commits the drawn-cell overlay on editing end.
    lazy var winCellEditor: WinDrawnCellEditor = {
        let editor = WinDrawnCellEditor()
        editor.table = self
        return editor
    }()

    // MARK: Drawn-cell customization hooks (overridable — used by NSOutlineView)

    /// Extra leading inset (points) for a drawn cell's content — e.g. the
    /// indentation + disclosure-triangle space an outline view needs on its
    /// first column. Applied to drawn text and to hosted cell-view frames.
    /// Default 0.
    open func winDrawnLeadingInset(forRow row: Int, column: Int) -> CGFloat {
        0
    }

    /// Extra trailing inset (points) for a drawn cell's content — space reserved
    /// at the cell's right edge so drawn text is clipped short of it (e.g. an
    /// `NSBrowser` branch chevron). Default 0.
    open func winDrawnTrailingInset(forRow row: Int, column: Int) -> CGFloat {
        0
    }

    /// Draws per-cell decoration (e.g. an outline disclosure triangle) inside a
    /// drawn cell's rect, above the row background and below the cell text.
    /// Default no-op.
    open func winDrawnDrawDecoration(forRow row: Int, column: Int, cellRect: NSRect) {}

    /// Handles a click inside a drawn cell before row selection. Returns `true`
    /// when the click was consumed (e.g. it toggled a disclosure triangle) and
    /// the row should therefore not be selected. Default `false`.
    open func winDrawnHandleDecorationClick(forRow row: Int, column: Int, at point: NSPoint) -> Bool {
        false
    }

    /// Windows virtual-key codes for the keys `keyDown` interprets, as delivered
    /// in `NSEvent.keyCode`. Named so the switch below reads by intent rather
    /// than by magic hex. (Case patterns need constants, not locals, so these
    /// live here as static values.)
    internal enum TableKeyCode {
        static let tab: UInt16 = 0x09
        static let `return`: UInt16 = 0x0d
        static let space: UInt16 = 0x20
        static let pageUp: UInt16 = 0x21
        static let pageDown: UInt16 = 0x22
        static let end: UInt16 = 0x23
        static let home: UInt16 = 0x24
        static let upArrow: UInt16 = 0x26
        static let downArrow: UInt16 = 0x28
    }

    /// Tables handle standard navigation keys as part of their component behavior.
    open override func keyDown(with event: NSEvent) {
        winKeyDown(with: event)
    }

    /// Number of columns.
    open var numberOfColumns: Int {
        tableColumns.count
    }

    /// Number of currently loaded rows.
    open var numberOfRows: Int {
        rowValues.count
    }

    /// Number of selected rows.
    open var numberOfSelectedRows: Int {
        selectedRowIndexes.count
    }

    /// Adds a column.
    open func addTableColumn(_ tableColumn: NSTableColumn) {
        tableColumns.append(tableColumn)
        reloadData()
    }

    /// Removes a column.
    open func removeTableColumn(_ tableColumn: NSTableColumn) {
        tableColumns.removeAll { $0 === tableColumn }
        reloadData()
    }

    /// Moves a column from one index to another.
    open func moveColumn(_ oldIndex: Int, toColumn newIndex: Int) {
        guard tableColumns.indices.contains(oldIndex) else {
            return
        }

        let clampedIndex = max(0, min(newIndex, tableColumns.count - 1))
        let column = tableColumns.remove(at: oldIndex)
        tableColumns.insert(column, at: clampedIndex)
        reloadData()
    }

    /// Returns a column with the given identifier, when present.
    open func tableColumn(withIdentifier identifier: NSUserInterfaceItemIdentifier) -> NSTableColumn? {
        tableColumns.first { $0.identifier == identifier }
    }

    /// Returns the index of a column identifier, or `-1` when absent.
    open func column(withIdentifier identifier: NSUserInterfaceItemIdentifier) -> Int {
        tableColumns.firstIndex { $0.identifier == identifier } ?? -1
    }

    /// Returns a column at an index.
    package func tableColumn(at columnIndex: Int) -> NSTableColumn? {
        guard tableColumns.indices.contains(columnIndex) else {
            return nil
        }

        return tableColumns[columnIndex]
    }

    /// Deselects all rows.
    open func deselectAll(_ sender: Any?) {
        winDeselectAll(sender)
    }

    /// Deselects a specific row.
    open func deselectRow(_ row: Int) {
        let oldSelection = selectedRowIndexes
        selectedRowIndexes.remove(row)
        selectedRow = selectedRowIndexes.min() ?? -1
        selectedColumn = selectedRow >= 0 && numberOfColumns > 0 ? 0 : -1

        if let nativeHandle {
            realizedBackend?.setTableSelectedRows(selectedRowIndexes, for: nativeHandle)
        }

        if selectedRowIndexes != oldSelection {
            notifySelectionChanged()
        }
    }

    /// Selects all rows when multiple selection is enabled.
    open func selectAll(_ sender: Any?) {
        winSelectAll(sender)
    }

    /// Returns whether a row is selected.
    open func isRowSelected(_ row: Int) -> Bool {
        selectedRowIndexes.contains(row)
    }

    /// Scrolls the enclosing scroll view so a row is visible — AppKit's
    /// `scrollRowToVisible(_:)`. Uses the drawn table's row geometry
    /// (`winRowY`/`winRowHeightAt`) and nudges the clip view only as far as
    /// needed, exactly like AppKit (an already-visible row does not move).
    open func scrollRowToVisible(_ row: Int) {
        winScrollRowToVisible(row)
    }

    /// Scrolls a column into view. Stored for compatibility; native scrolling is future work.
    open func scrollColumnToVisible(_ column: Int) {}

    /// Returns a view from the delegate for a row/column, when provided.
    open func view(atColumn column: Int, row: Int, makeIfNecessary: Bool) -> NSView? {
        guard makeIfNecessary,
              rowValues.indices.contains(row) else {
            return nil
        }

        return winMainActor { winEffectiveDelegate?.tableView(self, viewFor: tableColumn(at: column), row: row) }
    }

    /// Returns the delegate-provided height for a row.
    open func heightOfRow(_ row: Int) -> CGFloat {
        winMainActor { winEffectiveDelegate?.tableView(self, heightOfRow: row) } ?? rowHeight
    }

    /// Sets a model value through the data source.
    open func setObjectValue(_ object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        guard rowValues.indices.contains(row) else {
            return
        }

        winMainActor { winEffectiveDataSource?.tableView(self, setObjectValue: object, for: tableColumn, row: row) }
        reloadData()
    }

    /// Returns the display value for a loaded row and column.
    package func value(atColumn columnIndex: Int, row rowIndex: Int) -> String? {
        guard rowValues.indices.contains(rowIndex),
              rowValues[rowIndex].indices.contains(columnIndex) else {
            return nil
        }

        return rowValues[rowIndex][columnIndex]
    }

    // MARK: Accessibility
    //
    // The framework-drawn table draws its own cells, so — unlike a control
    // backed by a native window — it has no child views for assistive tech to
    // find. Instead it publishes a synthetic element tree: the table is an
    // `AXTable` whose children are `AXRow`s, each holding one `AXCell` per
    // column carrying that cell's text. This is the moved-from-5.1 data-view
    // accessibility work; `NSOutlineView` refines the rows to `AXOutline`.

    /// The role the drawn table reports. A single-column table with no header
    /// reads as a list, matching AppKit's source-list heuristic.
    open override var winIntrinsicAccessibilityRole: NSAccessibilityRole {
        tableColumns.count <= 1 && !winReportsAsOutline ? .list : winReportsAsOutline ? .outline : .table
    }

    /// Subclasses (`NSOutlineView`) set this so the shared child-building path
    /// tags rows as outline rows.
    open var winReportsAsOutline: Bool { false }

    /// Approximate window-space frame of a data row, derived from `rowHeight`.
    /// Assistive technology uses it only for hit-testing, so the fixed-height
    /// approximation is acceptable for variable-height rows.
    open func winAccessibilityRowFrame(_ row: Int) -> NSRect {
        let step = rowHeight + intercellSpacing.height
        let local = NSRect(x: 0, y: CGFloat(row) * step, width: bounds.width, height: rowHeight)
        return convert(local, to: nil)
    }

    /// Returns accessibility elements for the table's currently represented rows.
    open override func accessibilityChildren() -> [Any]? {
        return winAccessibilityChildren()
    }

    /// Returns the value for a column object and row.
    open func value(for tableColumn: NSTableColumn?, row rowIndex: Int) -> String? {
        guard let tableColumn else {
            return nil
        }

        return value(atColumn: column(withIdentifier: tableColumn.identifier), row: rowIndex)
    }

    /// Reloads all rows from the data source.
    open func reloadData() {
        winReloadAllData()
    }

    /// Creates the native table peer (or a custom-drawn view for view-based
    /// tables that host cell views).
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        if winIsDrawn {
            return backend.createView(frame: frame, parent: parent)
        }
        return backend.createTableView(
            columns: tableColumns.map(\.title),
            content: NativeTableContent(rows: rowValues, selectedRow: selectedRow),
            frame: frame,
            parent: parent
        )
    }

    /// Draws the header/grid/selection for a framework-drawn table.
    open override func draw(_ dirtyRect: NSRect) {
        if winIsDrawn {
            winDrawTable(dirtyRect)
        } else {
            super.draw(dirtyRect)
        }
    }

    /// Routes clicks in a framework-drawn table to row selection / sorting.
    /// Double-click dispatch lives in the selection extension
    /// (NSTableViewSelection.swift).
    open override func mouseDown(with event: NSEvent) {
        if winIsDrawn {
            winDrawnMouseDown(event)
        } else {
            super.mouseDown(with: event)
        }
    }

    /// Tracks a reorder drag (or starts an external drag) in a drawn table.
    open override func mouseDragged(with event: NSEvent) {
        if winIsDrawn, winDraggingRow >= 0 || winExternalDragRow >= 0 {
            winDrawnMouseDragged(event)
        } else {
            super.mouseDragged(with: event)
        }
    }

    /// Commits a reorder drag in a framework-drawn table.
    open override func mouseUp(with event: NSEvent) {
        if winIsDrawn, winDraggingRow >= 0 || winExternalDragRow >= 0 {
            winDrawnMouseUp(event)
        } else {
            super.mouseUp(with: event)
        }
    }

    /// Accepts an external (or cross-view) drop: computes the target row from the
    /// drop location and forwards to the data source's `acceptDrop` hook. The
    /// table must be registered for the dragged types to receive the drop.
    open override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let dataSource = winEffectiveDataSource else {
            return false
        }
        let row = winIsDrawn ? winDropInsertionIndex(atY: sender.draggingLocation.y) : numberOfRows
        return winMainActor { dataSource.tableView(self, acceptDrop: sender, row: row, dropOperation: .above) }
    }

    /// Ensures native table state and selection dispatch are wired.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        return winRealizeNativePeer(in: backend, parent: parent)
    }

    /// Begins editing a cell. The framework-drawn table edits any column via the
    /// overlay editor; the native list edits its first column.
    open func editColumn(_ column: Int, row: Int, with event: NSEvent?, select: Bool) {
        winEditColumn(column, row: row, with: event, select: select)
    }
}

/// AppKit-compatible table selection notification name.
public let NSTableViewSelectionDidChangeNotification = NSTableView.selectionDidChangeNotification

extension NSTableView: NSDraggingSource {
    /// The operations the table permits when dragging a row out. A reorder-
    /// enabled table moves; otherwise it copies the row's pasteboard content.
    public func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        switch context {
        case .withinApplication:
            return winRowReorderHandler != nil ? .move : winLocalDragOperationMask
        case .outsideApplication:
            return winExternalDragOperationMask
        }
    }
}
