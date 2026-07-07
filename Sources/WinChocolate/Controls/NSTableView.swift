/// Data source for an AppKit-shaped table view.
public protocol NSTableViewDataSource: AnyObject {
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
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> Any?

    /// Accepts a drop of external (or cross-view) content at a target row,
    /// returning whether it was consumed — matching AppKit's
    /// `tableView(_:acceptDrop:row:dropOperation:)`. Read the payload from
    /// `info.draggingPasteboard`. The table must be registered for the dragged
    /// types (`registerForDraggedTypes`).
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int) -> Bool
}

/// Delegate for table-view notifications.
public protocol NSTableViewDelegate: AnyObject {
    /// Called after the selected row changes.
    func tableViewSelectionDidChange(_ notification: NSNotification)

    /// Returns a view for a row/column in view-based table configurations.
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?

    /// Returns a full-width background/row view for a row in view-based tables.
    func tableView(_ tableView: NSTableView, rowViewFor row: Int) -> NSTableRowView?

    /// Returns a custom height for a row.
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat

    /// Called after table sort descriptors change.
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor])
}

public extension NSTableViewDataSource {
    /// Default no-op setter for read-only tables.
    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {}

    /// Default: rows are not draggable out of the table.
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> Any? {
        nil
    }

    /// Default: the table refuses external drops.
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int) -> Bool {
        false
    }
}

public extension NSTableViewDelegate {
    /// Default table selection notification.
    func tableViewSelectionDidChange(_ notification: NSNotification) {}

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
    /// Grid-line drawing options.
    public struct GridLineStyle: OptionSet, Sendable {
        /// Raw option value.
        public let rawValue: UInt

        /// Creates grid-line options from a raw value.
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// Horizontal grid lines.
        public static let solidHorizontalGridLineMask = GridLineStyle(rawValue: 1 << 0)

        /// Vertical grid lines.
        public static let solidVerticalGridLineMask = GridLineStyle(rawValue: 1 << 1)
    }

    /// Selection highlight style.
    public enum SelectionHighlightStyle: Sendable {
        /// Regular table selection highlight.
        case regular

        /// Source-list style selection highlight.
        case sourceList

        /// No visible highlight.
        case none
    }

    /// Column autoresizing style.
    public enum ColumnAutoresizingStyle: Sendable {
        /// No automatic column resizing.
        case noColumnAutoresizing

        /// Uniformly resize columns.
        case uniformColumnAutoresizingStyle

        /// Resize the last column.
        case lastColumnOnlyAutoresizingStyle
    }

    /// Selection-changed notification name.
    public static let selectionDidChangeNotification = "NSTableViewSelectionDidChangeNotification"

    /// Table columns in display order.
    public private(set) var tableColumns: [NSTableColumn] = []

    /// Object that provides row values.
    open weak var dataSource: NSTableViewDataSource?

    /// Object notified about selection changes.
    open weak var delegate: NSTableViewDelegate?

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

    /// Space between table cells.
    open var intercellSpacing: NSSize = NSMakeSize(3, 2)

    /// Grid-line style.
    open var gridStyleMask: GridLineStyle = []

    /// Selection highlight style.
    open var selectionHighlightStyle: SelectionHighlightStyle = .regular

    /// Column autoresizing style. Applied when `sizeToFit()` runs (AppKit also
    /// applies it during live resize; here it is driven explicitly).
    open var columnAutoresizingStyle: ColumnAutoresizingStyle = .uniformColumnAutoresizingStyle

    /// Clamps a proposed column width to the column's `minWidth`/`maxWidth`
    /// (`maxWidth <= 0` means unbounded).
    private func winClampedColumnWidth(_ width: CGFloat, for column: NSTableColumn) -> CGFloat {
        var w = max(width, column.minWidth)
        if column.maxWidth > 0 {
            w = min(w, column.maxWidth)
        }
        return w
    }

    /// Reflows the drawn table after column widths change (a no-op for the
    /// native-list peer, whose column widths are fixed at creation — the same
    /// boundary as interactive resize).
    private func winApplyColumnWidths() {
        if winIsDrawn {
            winRebuildHostedViews()
            needsDisplay = true
        }
    }

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
        guard !tableColumns.isEmpty else {
            return
        }
        switch columnAutoresizingStyle {
        case .noColumnAutoresizing:
            return
        case .lastColumnOnlyAutoresizingStyle:
            sizeLastColumnToFit()
        case .uniformColumnAutoresizingStyle:
            let spacing = intercellSpacing.width * CGFloat(max(0, tableColumns.count - 1))
            let current = tableColumns.reduce(0) { $0 + $1.width }
            let delta = frame.size.width - spacing - current
            guard abs(delta) > 0.5 else {
                return
            }
            let share = delta / CGFloat(tableColumns.count)
            for index in tableColumns.indices {
                tableColumns[index].width = winClampedColumnWidth(tableColumns[index].width + share, for: tableColumns[index])
            }
            winApplyColumnWidths()
        }
    }

    /// Current table sort descriptors.
    open var sortDescriptors: [NSSortDescriptor] = [] {
        didSet {
            delegate?.tableView(self, sortDescriptorsDidChange: oldValue)
        }
    }

    /// The table's column-header view. Auto-created; set to `nil` to hide the
    /// header (e.g. inside `NSBrowser` columns).
    open lazy var headerView: NSTableHeaderView? = {
        let header = NSTableHeaderView(frame: .zero)
        header.tableView = self
        return header
    }()

    /// Swift-native selection callback.
    open var onSelectionChanged: ((NSTableView) -> Void)?

    /// Current selected row, or `-1` when nothing is selected.
    public private(set) var selectedRow: Int = -1

    /// Current selected column, or `-1` when nothing is selected.
    public private(set) var selectedColumn: Int = -1

    /// Current selected row indexes.
    public private(set) var selectedRowIndexes: Set<Int> = []

    private var rowValues: [[String]] = []
    /// The raw object values behind `rowValues`, kept in parallel so the drawn
    /// table can render an `NSAttributedString` cell with its own attributes.
    private var rowRawValues: [[Any?]] = []
    private var isUpdatingSelectionFromNative = false

    /// The plain display string for a data-source object value (an
    /// `NSAttributedString`'s `.string`, else the value's description).
    func winDisplayString(from value: Any?) -> String {
        if let attributed = value as? NSAttributedString {
            return attributed.string
        }
        return value.map { String(describing: $0) } ?? ""
    }

    /// The `NSAttributedString` behind a drawn cell, when the data source vended
    /// one — used to render the cell with the attributed value's own attributes.
    func winAttributedValue(atColumn columnIndex: Int, row rowIndex: Int) -> NSAttributedString? {
        guard rowRawValues.indices.contains(rowIndex),
              rowRawValues[rowIndex].indices.contains(columnIndex) else {
            return nil
        }
        return rowRawValues[rowIndex][columnIndex] as? NSAttributedString
    }

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

    /// When set, drawn-table rows can be reordered by dragging: the handler is
    /// called with the source row and the destination insertion index (0...n)
    /// on drop. A convenience ahead of the full `NSDraggingSession` protocol.
    open var winRowReorderHandler: ((_ fromRows: IndexSet, _ toIndex: Int) -> Void)?
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
    private enum TableKeyCode {
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
        guard let keyCode = event.keyCode else {
            super.keyDown(with: event)
            return
        }

        switch keyCode {
        case TableKeyCode.tab:
            moveFocusWithTab(event)
        case TableKeyCode.upArrow:
            moveSelection(by: -1, extending: event.modifierFlags.contains(.shift))
        case TableKeyCode.downArrow:
            moveSelection(by: 1, extending: event.modifierFlags.contains(.shift))
        case TableKeyCode.pageUp:
            moveSelection(by: -10, extending: event.modifierFlags.contains(.shift))
        case TableKeyCode.pageDown:
            moveSelection(by: 10, extending: event.modifierFlags.contains(.shift))
        case TableKeyCode.home:
            selectKeyboardRow(0, extending: event.modifierFlags.contains(.shift))
        case TableKeyCode.end:
            selectKeyboardRow(max(0, numberOfRows - 1), extending: event.modifierFlags.contains(.shift))
        case TableKeyCode.return:
            // Return begins editing the selected row's first editable drawn cell
            // (AppKit convention); if nothing is editable, it acts as the row
            // action instead.
            if !winBeginEditSelectedRow() {
                sendAction()
            }
        case TableKeyCode.space:
            sendAction()
        default:
            super.keyDown(with: event)
        }
    }

    private func moveFocusWithTab(_ event: NSEvent) {
        if event.modifierFlags.contains(.shift) {
            window?.selectPreviousKeyView(nil)
        } else {
            window?.selectNextKeyView(nil)
        }
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
    open func tableColumn(at columnIndex: Int) -> NSTableColumn? {
        guard tableColumns.indices.contains(columnIndex) else {
            return nil
        }

        return tableColumns[columnIndex]
    }

    /// Selects one row.
    open func selectRowIndexes(_ indexes: Set<Int>, byExtendingSelection extend: Bool) {
        let validIndexes = indexes.filter { rowValues.indices.contains($0) }
        guard !validIndexes.isEmpty else {
            if allowsEmptySelection {
                deselectAll(nil)
            }
            return
        }

        let oldSelection = selectedRowIndexes
        // With multiple selection, replace with (or extend by) the whole set;
        // single-selection tables keep only the first index.
        if allowsMultipleSelection {
            selectedRowIndexes = extend ? selectedRowIndexes.union(validIndexes) : validIndexes
        } else {
            selectedRowIndexes = [validIndexes.min() ?? -1]
        }
        selectedRow = selectedRowIndexes.min() ?? -1
        selectedColumn = numberOfColumns > 0 ? 0 : -1
        if !isUpdatingSelectionFromNative, let nativeHandle {
            realizedBackend?.setTableSelectedRows(selectedRowIndexes, for: nativeHandle)
        }

        if selectedRowIndexes != oldSelection {
            notifySelectionChanged()
        }
    }

    /// Deselects all rows.
    open func deselectAll(_ sender: Any?) {
        guard allowsEmptySelection else {
            return
        }

        selectedRow = -1
        selectedColumn = -1
        selectedRowIndexes = []
        if let nativeHandle {
            realizedBackend?.setTableSelectedRows([], for: nativeHandle)
        }

        notifySelectionChanged()
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
        guard allowsMultipleSelection else {
            if !rowValues.isEmpty {
                selectRowIndexes([0], byExtendingSelection: false)
            }
            return
        }

        let oldSelection = selectedRowIndexes
        selectedRowIndexes = Set(rowValues.indices)
        selectedRow = selectedRowIndexes.min() ?? -1
        selectedColumn = selectedRow >= 0 && numberOfColumns > 0 ? 0 : -1

        if let nativeHandle {
            realizedBackend?.setTableSelectedRows(selectedRowIndexes, for: nativeHandle)
        }

        if selectedRowIndexes != oldSelection {
            notifySelectionChanged()
        }
    }

    /// Returns whether a row is selected.
    open func isRowSelected(_ row: Int) -> Bool {
        selectedRowIndexes.contains(row)
    }

    /// Scrolls a row into view. Stored for compatibility; native scrolling is future work.
    open func scrollRowToVisible(_ row: Int) {}

    /// Scrolls a column into view. Stored for compatibility; native scrolling is future work.
    open func scrollColumnToVisible(_ column: Int) {}

    /// Returns a view from the delegate for a row/column, when provided.
    open func view(atColumn column: Int, row: Int, makeIfNecessary: Bool) -> NSView? {
        guard makeIfNecessary,
              rowValues.indices.contains(row) else {
            return nil
        }

        return delegate?.tableView(self, viewFor: tableColumn(at: column), row: row)
    }

    /// Returns the delegate-provided height for a row.
    open func heightOfRow(_ row: Int) -> CGFloat {
        delegate?.tableView(self, heightOfRow: row) ?? rowHeight
    }

    /// Sets a model value through the data source.
    open func setObjectValue(_ object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        guard rowValues.indices.contains(row) else {
            return
        }

        dataSource?.tableView(self, setObjectValue: object, for: tableColumn, row: row)
        reloadData()
    }

    /// Returns the display value for a loaded row and column.
    open func value(atColumn columnIndex: Int, row rowIndex: Int) -> String? {
        guard rowValues.indices.contains(rowIndex),
              rowValues[rowIndex].indices.contains(columnIndex) else {
            return nil
        }

        return rowValues[rowIndex][columnIndex]
    }

    /// Returns the value for a column object and row.
    open func value(for tableColumn: NSTableColumn?, row rowIndex: Int) -> String? {
        guard let tableColumn else {
            return nil
        }

        return value(atColumn: column(withIdentifier: tableColumn.identifier), row: rowIndex)
    }

    /// Reloads only the given cells from the data source, updating each in
    /// place natively instead of rebuilding the whole table.
    open func reloadData(forRowIndexes rowIndexes: Set<Int>, columnIndexes: Set<Int>) {
        let columns = columnIndexes.isEmpty ? Set(tableColumns.indices) : columnIndexes
        for row in rowIndexes where rowValues.indices.contains(row) {
            for column in columns where tableColumns.indices.contains(column) {
                let value = dataSource?.tableView(self, objectValueFor: tableColumns[column], row: row)
                let text = winDisplayString(from: value)
                rowValues[row][column] = text
                if rowRawValues.indices.contains(row), rowRawValues[row].indices.contains(column) {
                    rowRawValues[row][column] = value
                }
                if let nativeHandle {
                    realizedBackend?.setTableCellText(text, row: row, column: column, for: nativeHandle)
                }
            }
        }
    }

    /// Reloads all rows from the data source.
    open func reloadData() {
        let count = dataSource?.numberOfRows(in: self) ?? 0
        var nextRows: [[String]] = []
        var nextRaw: [[Any?]] = []

        for row in 0..<count {
            var strings: [String] = []
            var raws: [Any?] = []
            for column in tableColumns {
                let value = dataSource?.tableView(self, objectValueFor: column, row: row)
                raws.append(value)
                strings.append(winDisplayString(from: value))
            }
            nextRows.append(strings)
            nextRaw.append(raws)
        }

        rowValues = nextRows
        rowRawValues = nextRaw
        if selectedRow >= rowValues.count {
            selectedRow = rowValues.isEmpty ? -1 : rowValues.count - 1
        }
        selectedRowIndexes = selectedRow >= 0 ? [selectedRow] : []
        selectedColumn = selectedRow >= 0 && numberOfColumns > 0 ? max(selectedColumn, 0) : -1

        if winIsDrawn {
            winRebuildHostedViews()
            needsDisplay = true
        } else {
            syncRowsToNative()
        }
    }

    /// Creates the native table peer (or a custom-drawn view for view-based
    /// tables that host cell views).
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        if winIsDrawn {
            return backend.createView(frame: frame, parent: parent)
        }
        return backend.createTableView(columns: tableColumns.map(\.title), rows: rowValues, selectedRow: selectedRow, frame: frame, parent: parent)
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
        guard let dataSource else {
            return false
        }
        let row = winIsDrawn ? winDropInsertionIndex(atY: sender.draggingLocation.y) : numberOfRows
        return dataSource.tableView(self, acceptDrop: sender, row: row)
    }

    /// Ensures native table state and selection dispatch are wired.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        reloadData()
        winIsDrawn = winShouldUseDrawnCells
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        if winIsDrawn {
            winRebuildHostedViews()
            needsDisplay = true
            return handle
        }
        if allowsMultipleSelection {
            backend.setTableAllowsMultipleSelection(true, for: handle)
        }
        // First-column in-place editing when the first column opts in.
        if tableColumns.first?.isEditable == true {
            backend.setTableEditable(true, for: handle)
        }
        backend.registerTableEditAction(for: handle) { [weak self] row, column, text in
            self?.commitEdit(row: row, column: column, text: text)
        }
        backend.registerAction(for: handle) { [weak self, weak backend] in
            guard let self, let backend, let nativeHandle = self.nativeHandle else {
                return
            }

            // A header click (column set, no row) applies the column's sort
            // prototype + indicator, then sends the table action so apps that
            // re-sort their model on the action (reading `sortDescriptors`) run.
            let clickedColumn = backend.tableClickedColumn(for: nativeHandle)
            let clickedRow = backend.tableClickedRow(for: nativeHandle)
            if clickedColumn >= 0, clickedRow < 0 {
                self.handleHeaderClick(column: clickedColumn)
                self.sendAction()
                return
            }

            self.updateSelectionFromNative(rows: backend.tableSelectedRows(for: nativeHandle))
            _ = self.window?.makeFirstResponder(self)
            self.sendAction()
            self.notifySelectionChanged()
        }
        return handle
    }

    /// Begins editing a cell. The framework-drawn table edits any column via the
    /// overlay editor; the native list edits its first column.
    open func editColumn(_ column: Int, row: Int, with event: NSEvent?, select: Bool) {
        guard rowValues.indices.contains(row) else {
            return
        }
        if winIsDrawn {
            selectRowIndexes([row], byExtendingSelection: false)
            winUpdateHostedRowSelection()
            winBeginDrawnEdit(row: row, column: column)
            return
        }
        guard let nativeHandle else {
            return
        }
        realizedBackend?.editTableCell(row: row, column: column, for: nativeHandle)
    }

    private func commitEdit(row: Int, column: Int, text: String) {
        guard rowValues.indices.contains(row) else {
            return
        }
        setObjectValue(text, for: tableColumn(at: column), row: row)
    }

    private func handleHeaderClick(column: Int) {
        headerView?.clickedColumn = column
        guard let sort = sortUsingDescriptorPrototype(forColumn: column) else {
            return
        }
        if let nativeHandle {
            realizedBackend?.setTableSortIndicator(column: column, ascending: sort.ascending, for: nativeHandle)
        }
    }

    private func syncRowsToNative() {
        guard let nativeHandle else {
            return
        }

        realizedBackend?.setTableRows(rowValues, selectedRow: selectedRow, for: nativeHandle)
    }

    private func updateSelectionFromNative(rows: [Int]) {
        isUpdatingSelectionFromNative = true
        let valid = Set(rows.filter { rowValues.indices.contains($0) })
        selectedRowIndexes = valid
        selectedRow = valid.min() ?? -1
        selectedColumn = selectedRow >= 0 && numberOfColumns > 0 ? 0 : -1
        isUpdatingSelectionFromNative = false
    }

    private func moveSelection(by offset: Int, extending: Bool) {
        guard numberOfRows > 0 else {
            return
        }

        let base = selectedRow >= 0 ? selectedRow : (offset < 0 ? numberOfRows : -1)
        selectKeyboardRow(base + offset, extending: extending)
    }

    private func selectKeyboardRow(_ row: Int, extending: Bool) {
        guard numberOfRows > 0 else {
            return
        }

        let clampedRow = max(0, min(row, numberOfRows - 1))
        selectRowIndexes([clampedRow], byExtendingSelection: extending)
        scrollRowToVisible(clampedRow)
    }

    private func notifySelectionChanged() {
        if winIsDrawn {
            needsDisplay = true
        }
        onSelectionChanged?(self)
        delegate?.tableViewSelectionDidChange(NSNotification(name: Self.selectionDidChangeNotification, object: self))
    }
}

/// AppKit-compatible table selection notification name.
public let NSTableViewSelectionDidChangeNotification = NSTableView.selectionDidChangeNotification

extension NSTableView: NSDraggingSource {
    /// The operations the table permits when dragging a row out. A reorder-
    /// enabled table moves; otherwise it copies the row's pasteboard content.
    public func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        winRowReorderHandler != nil ? .move : .copy
    }
}
