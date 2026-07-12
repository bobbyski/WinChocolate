import Foundation

/// One column of an `NSTableView`: an identifier plus a header title.
public final class NSTableColumn {

    /// Stable identifier used by data sources to tell columns apart.
    public let identifier: String

    /// The header title.
    public var title: String

    public init(identifier: String) {
        self.identifier = identifier
        self.title = identifier
    }
}

/// AppKit-shaped table data source: row count plus per-cell values.
public protocol NSTableViewDataSource: AnyObject {
    func numberOfRows(in tableView: NSTableView) -> Int
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any?
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

    /// Called when the user changes the row selection.
    public var onSelectionChange: ((NSTableView) -> Void)?

    /// Creates an empty table.
    public override init(frame: NSRect) {
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
    }

    /// Appends `column`.
    public func addTableColumn(_ column: NSTableColumn) {
        tableColumns.append(column)
        backend.addTableColumn(title: column.title, to: handle)
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
