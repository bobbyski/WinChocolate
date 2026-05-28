/// Data source for an AppKit-shaped table view.
public protocol NSTableViewDataSource: AnyObject {
    /// Returns the number of rows in the table.
    func numberOfRows(in tableView: NSTableView) -> Int

    /// Returns a display value for a column and row.
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any?
}

/// Delegate for table-view notifications.
public protocol NSTableViewDelegate: AnyObject {
    /// Called after the selected row changes.
    func tableViewSelectionDidChange(_ notification: NSNotification)
}

/// A row-and-column data view.
///
/// This first WinChocolate slice preserves AppKit's common data-source shape
/// and maps the classic backend to a native list box until a full ListView
/// implementation lands.
open class NSTableView: NSControl {
    /// Table columns in display order.
    public private(set) var tableColumns: [NSTableColumn] = []

    /// Object that provides row values.
    open weak var dataSource: NSTableViewDataSource?

    /// Object notified about selection changes.
    open weak var delegate: NSTableViewDelegate?

    /// Whether multiple rows may be selected.
    open var allowsMultipleSelection: Bool = false

    /// Whether alternating row backgrounds are requested.
    open var usesAlternatingRowBackgroundColors: Bool = false

    /// Whether the header should be visible.
    open var headerView: NSView?

    /// Swift-native selection callback.
    open var onSelectionChanged: ((NSTableView) -> Void)?

    /// Current selected row, or `-1` when nothing is selected.
    public private(set) var selectedRow: Int = -1

    /// Current selected row indexes.
    public private(set) var selectedRowIndexes: Set<Int> = []

    private var rowValues: [[String]] = []
    private var isUpdatingSelectionFromNative = false

    /// Number of columns.
    open var numberOfColumns: Int {
        tableColumns.count
    }

    /// Number of currently loaded rows.
    open var numberOfRows: Int {
        rowValues.count
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

    /// Returns a column with the given identifier, when present.
    open func tableColumn(withIdentifier identifier: NSUserInterfaceItemIdentifier) -> NSTableColumn? {
        tableColumns.first { $0.identifier == identifier }
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
            deselectAll(nil)
            return
        }

        let nextSelection = validIndexes.first ?? -1
        guard nextSelection == -1 || rowValues.indices.contains(nextSelection) else {
            return
        }

        selectedRowIndexes = allowsMultipleSelection && extend
            ? selectedRowIndexes.union(validIndexes)
            : [nextSelection]
        selectedRow = selectedRowIndexes.first ?? -1
        guard !isUpdatingSelectionFromNative, let nativeHandle else {
            return
        }

        realizedBackend?.setTableSelectedRow(selectedRow, for: nativeHandle)
    }

    /// Deselects all rows.
    open func deselectAll(_ sender: Any?) {
        selectedRow = -1
        selectedRowIndexes = []
        guard let nativeHandle else {
            return
        }

        realizedBackend?.setTableSelectedRow(-1, for: nativeHandle)
    }

    /// Returns the display value for a loaded row and column.
    open func value(atColumn columnIndex: Int, row rowIndex: Int) -> String? {
        guard rowValues.indices.contains(rowIndex),
              rowValues[rowIndex].indices.contains(columnIndex) else {
            return nil
        }

        return rowValues[rowIndex][columnIndex]
    }

    /// Reloads all rows from the data source.
    open func reloadData() {
        let count = dataSource?.numberOfRows(in: self) ?? 0
        var nextRows: [[String]] = []

        for row in 0..<count {
            let values = tableColumns.map { column -> String in
                guard let value = dataSource?.tableView(self, objectValueFor: column, row: row) else {
                    return ""
                }

                return String(describing: value)
            }
            nextRows.append(values)
        }

        rowValues = nextRows
        if selectedRow >= rowValues.count {
            selectedRow = rowValues.isEmpty ? -1 : rowValues.count - 1
        }
        selectedRowIndexes = selectedRow >= 0 ? [selectedRow] : []

        syncRowsToNative()
    }

    /// Creates the native table peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createTableView(columns: tableColumns.map(\.title), rows: rowValues, selectedRow: selectedRow, frame: frame, parent: parent)
    }

    /// Ensures native table state and selection dispatch are wired.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        reloadData()
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        backend.registerAction(for: handle) { [weak self, weak backend] in
            guard let self, let backend, let nativeHandle = self.nativeHandle else {
                return
            }

            self.updateSelectionFromNative(backend.tableSelectedRow(for: nativeHandle))
            _ = self.window?.makeFirstResponder(self)
            self.sendAction()
            self.onSelectionChanged?(self)
            self.delegate?.tableViewSelectionDidChange(NSNotification(name: "NSTableViewSelectionDidChangeNotification", object: self))
        }
        return handle
    }

    private func syncRowsToNative() {
        guard let nativeHandle else {
            return
        }

        realizedBackend?.setTableRows(rowValues, selectedRow: selectedRow, for: nativeHandle)
    }

    private func updateSelectionFromNative(_ row: Int) {
        isUpdatingSelectionFromNative = true
        selectedRow = rowValues.indices.contains(row) ? row : -1
        selectedRowIndexes = selectedRow >= 0 ? [selectedRow] : []
        isUpdatingSelectionFromNative = false
    }
}
