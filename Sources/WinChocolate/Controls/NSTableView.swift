/// Data source for an AppKit-shaped table view.
public protocol NSTableViewDataSource: AnyObject {
    /// Returns the number of rows in the table.
    func numberOfRows(in tableView: NSTableView) -> Int

    /// Returns a display value for a column and row.
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any?

    /// Updates the model after an editable value changes.
    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int)
}

/// Delegate for table-view notifications.
public protocol NSTableViewDelegate: AnyObject {
    /// Called after the selected row changes.
    func tableViewSelectionDidChange(_ notification: NSNotification)

    /// Returns a view for a row/column in view-based table configurations.
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?

    /// Returns a custom height for a row.
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat

    /// Called after table sort descriptors change.
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor])
}

public extension NSTableViewDataSource {
    /// Default no-op setter for read-only tables.
    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {}
}

public extension NSTableViewDelegate {
    /// Default table selection notification.
    func tableViewSelectionDidChange(_ notification: NSNotification) {}

    /// Default view-based table hook.
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
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
    open var allowsMultipleSelection: Bool = false

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

    /// Column autoresizing style.
    open var columnAutoresizingStyle: ColumnAutoresizingStyle = .uniformColumnAutoresizingStyle

    /// Current table sort descriptors.
    open var sortDescriptors: [NSSortDescriptor] = [] {
        didSet {
            delegate?.tableView(self, sortDescriptorsDidChange: oldValue)
        }
    }

    /// Whether the header should be visible.
    open var headerView: NSView?

    /// Swift-native selection callback.
    open var onSelectionChanged: ((NSTableView) -> Void)?

    /// Current selected row, or `-1` when nothing is selected.
    public private(set) var selectedRow: Int = -1

    /// Current selected column, or `-1` when nothing is selected.
    public private(set) var selectedColumn: Int = -1

    /// Current selected row indexes.
    public private(set) var selectedRowIndexes: Set<Int> = []

    private var rowValues: [[String]] = []
    private var isUpdatingSelectionFromNative = false

    /// Tables handle standard navigation keys as part of their component behavior.
    open override func keyDown(with event: NSEvent) {
        guard let keyCode = event.keyCode else {
            super.keyDown(with: event)
            return
        }

        switch keyCode {
        case 0x09:
            moveFocusWithTab(event)
        case 0x26:
            moveSelection(by: -1, extending: event.modifierFlags.contains(.shift))
        case 0x28:
            moveSelection(by: 1, extending: event.modifierFlags.contains(.shift))
        case 0x21:
            moveSelection(by: -10, extending: event.modifierFlags.contains(.shift))
        case 0x22:
            moveSelection(by: 10, extending: event.modifierFlags.contains(.shift))
        case 0x24:
            selectKeyboardRow(0, extending: event.modifierFlags.contains(.shift))
        case 0x23:
            selectKeyboardRow(max(0, numberOfRows - 1), extending: event.modifierFlags.contains(.shift))
        case 0x20, 0x0d:
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

        let nextSelection = validIndexes.min() ?? -1
        guard nextSelection == -1 || rowValues.indices.contains(nextSelection) else {
            return
        }

        let oldSelection = selectedRowIndexes
        selectedRowIndexes = allowsMultipleSelection && extend
            ? selectedRowIndexes.union(validIndexes)
            : [nextSelection]
        selectedRow = selectedRowIndexes.min() ?? -1
        selectedColumn = numberOfColumns > 0 ? 0 : -1
        if !isUpdatingSelectionFromNative, let nativeHandle {
            realizedBackend?.setTableSelectedRow(selectedRow, for: nativeHandle)
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
            realizedBackend?.setTableSelectedRow(-1, for: nativeHandle)
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
            realizedBackend?.setTableSelectedRow(selectedRow, for: nativeHandle)
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
            realizedBackend?.setTableSelectedRow(selectedRow, for: nativeHandle)
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

    /// Reloads part of the table. The first slice refreshes all rows.
    open func reloadData(forRowIndexes rowIndexes: Set<Int>, columnIndexes: Set<Int>) {
        reloadData()
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
        selectedColumn = selectedRow >= 0 && numberOfColumns > 0 ? max(selectedColumn, 0) : -1

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
            self.notifySelectionChanged()
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
        onSelectionChanged?(self)
        delegate?.tableViewSelectionDidChange(NSNotification(name: Self.selectionDidChangeNotification, object: self))
    }
}

/// AppKit-compatible table selection notification name.
public let NSTableViewSelectionDidChangeNotification = NSTableView.selectionDidChangeNotification
