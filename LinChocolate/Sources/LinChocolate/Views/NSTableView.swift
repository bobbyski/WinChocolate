import Foundation

/// One column of an `NSTableView`: an identifier plus a header title.
public final class NSTableColumn {

    /// Stable identifier used by data sources to tell columns apart.
    public let identifier: String

    /// The table + index this column was added to (set on `addTableColumn`).
    weak var table: NSTableView?
    var columnIndex: Int = -1

    /// The header title. Updating it re-titles the live header.
    public var title: String {
        didSet { table?.retitleColumn(columnIndex, title) }
    }

    /// Column width (accepted for API parity; GtkColumnView sizes columns).
    public var width: CGFloat = 100
    public var minWidth: CGFloat = 0
    public var maxWidth: CGFloat = 1000
    public var isEditable: Bool = false

    /// If set, the column's header becomes clickable and clicking it delivers a
    /// derived `NSSortDescriptor` to the data source.
    public var sortDescriptorPrototype: NSSortDescriptor? {
        didSet { if sortDescriptorPrototype != nil { table?.makeColumnSortable(columnIndex) } }
    }

    public init(identifier: String) {
        self.identifier = identifier
        self.title = identifier
    }
}

/// AppKit-shaped table data source: row count plus per-cell values, and an
/// optional sort-change hook.
public protocol NSTableViewDataSource: AnyObject {
    func numberOfRows(in tableView: NSTableView) -> Int
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any?
    /// Called after the user clicks a sortable header and `sortDescriptors`
    /// updates; the data source re-sorts its model and reloads. Default: no-op.
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor])
}

public extension NSTableViewDataSource {
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {}
}

/// AppKit-shaped column table (GtkColumnView in a scroller). Configure columns
/// with `addTableColumn(_:)`, assign a `dataSource`, and call `reloadData()`
/// after the underlying data changes. Single-row selection in this slice.
public final class NSTableView: NSView {

    /// The columns, in display order.
    public private(set) var tableColumns: [NSTableColumn] = []

    /// Supplies row count and cell values. Assigning reloads.
    public weak var dataSource: NSTableViewDataSource? {
        didSet { reloadData() }
    }

    /// The selected row (−1 when nothing is selected).
    public private(set) var selectedRow: Int = -1

    /// The active sort descriptors (updated when a sortable header is clicked).
    public var sortDescriptors: [NSSortDescriptor] = []

    /// The delegate (accepted for API parity; dispatch is a later item).
    public weak var delegate: NSTableViewDelegate?

    // Selection / column / grid options accepted for API parity.
    public var usesAlternatingRowBackgroundColors: Bool = false
    public var allowsMultipleSelection: Bool = false
    public var allowsEmptySelection: Bool = true
    public var allowsColumnSelection: Bool = false
    public var allowsColumnReordering: Bool = true
    public var allowsColumnResizing: Bool = true
    public var gridStyleMask: NSTableViewGridLineStyle = .gridNone
    public var rowHeight: CGFloat = 24
    public var doubleAction: String?
    public var nativeHandle: NativeHandle? { handle }
    public var numberOfColumns: Int { tableColumns.count }
    public var clickedRow: Int { selectedRow }
    public var clickedColumn: Int { -1 }
    /// WinChocolate-named action aliases (accepted for parity).
    public var onAction: ((NSTableView) -> Void)?
    public var onDoubleAction: ((NSTableView) -> Void)? {
        get { _onDoubleAction }
        set { _onDoubleAction = newValue; onDoubleClick = { [weak self] _ in if let self { newValue?(self) } } }
    }
    private var _onDoubleAction: ((NSTableView) -> Void)?
    public var onSelectionChanged: ((NSTableView) -> Void)? {
        get { onSelectionChange }
        set { onSelectionChange = newValue }
    }
    /// Windows-only reorder handler (accepted no-op here).
    public var winRowReorderHandler: (([Int], Int) -> Void)?
    public func tableColumn(withIdentifier id: String) -> NSTableColumn? {
        tableColumns.first { $0.identifier == id }
    }
    public func selectColumnIndexes(_ indexes: IndexSet, byExtendingSelection extend: Bool) {}

    /// The current row count (from the data source).
    public var numberOfRows: Int { dataSource?.numberOfRows(in: self) ?? 0 }

    /// Selects rows by index set (single-selection today: the first index).
    public func selectRowIndexes(_ indexes: IndexSet, byExtendingSelection extend: Bool) {
        if let first = indexes.first { selectRow(at: first) }
    }
    public func value(atColumn column: Int, row: Int) -> String? {
        guard column < tableColumns.count else { return nil }
        let value = dataSource?.tableView(self, objectValueFor: tableColumns[column], row: row)
        return value.map { "\($0)" }
    }
    /// A row background view (stub).
    public func rowView(atRow row: Int, makeIfNecessary: Bool) -> NSTableRowView? { nil }

    /// Called when the user changes the row selection.
    public var onSelectionChange: ((NSTableView) -> Void)?

    /// Called when a row is activated (double-click / Enter); passes the row.
    public var onDoubleClick: ((Int) -> Void)?

    /// Creates an empty table.
    public required init(frame: NSRect) {
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createTableView(frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
        backend.setTableCellProvider(for: handle) { [weak self] row, columnIndex in
            guard let self, let dataSource = self.dataSource,
                  columnIndex < self.tableColumns.count else { return "" }
            let value = dataSource.tableView(self, objectValueFor: self.tableColumns[columnIndex], row: row)
            return value.map { String(describing: $0) } ?? ""
        }
        backend.setSelectionChangeAction(for: handle) { [weak self] row in
            guard let self else { return }
            self.selectedRow = row             // sync silently
            self.onSelectionChange?(self)
        }
        backend.setSortChangeAction(for: handle) { [weak self] columnIndex, ascending in
            guard let self, columnIndex < self.tableColumns.count else { return }
            let old = self.sortDescriptors
            let key = self.tableColumns[columnIndex].sortDescriptorPrototype?.key
            self.sortDescriptors = [NSSortDescriptor(key: key, ascending: ascending)]
            self.dataSource?.tableView(self, sortDescriptorsDidChange: old)
        }
        backend.setRowActivateAction(for: handle) { [weak self] row in
            guard let self else { return }
            self.selectedRow = row
            self.onDoubleClick?(row)
        }
    }

    /// Appends `column`.
    public func addTableColumn(_ column: NSTableColumn) {
        let index = tableColumns.count
        column.table = self
        column.columnIndex = index
        tableColumns.append(column)
        backend.addTableColumn(title: column.title, to: handle)
        if column.sortDescriptorPrototype != nil {
            backend.setColumnSortable(index, for: handle)
        }
    }

    /// Updates a column's live header title (used by `NSTableColumn.title`).
    func retitleColumn(_ index: Int, _ title: String) {
        guard index >= 0 else { return }
        backend.setTableColumnTitle(title, columnIndex: index, for: handle)
    }

    /// Makes a column's header clickable for sorting (used when a prototype is set).
    func makeColumnSortable(_ index: Int) {
        guard index >= 0 else { return }
        backend.setColumnSortable(index, for: handle)
    }

    /// Re-queries the data source and re-renders every cell.
    public func reloadData() {
        let rows = dataSource?.numberOfRows(in: self) ?? 0
        backend.setTableRowCount(rows, for: handle)
    }

    /// Programmatically selects `row`.
    public func selectRow(at row: Int) {
        selectedRow = row
        backend.setSelectedIndex(row, for: handle)
    }
}
