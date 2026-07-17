nonisolated(unsafe) private var tableAllowsColumnSelection: [ObjectIdentifier: Bool] = [:]
nonisolated(unsafe) private var tableSelectedColumnIndexes: [ObjectIdentifier: Set<Int>] = [:]
nonisolated(unsafe) private var tableDoubleActions: [ObjectIdentifier: Selector] = [:]

public extension NSTableView {
    /// Most recent row activated by mouse or keyboard, or `-1`.
    var clickedRow: Int {
        if let nativeHandle,
           let backend = realizedBackend {
            let nativeRow = backend.tableClickedRow(for: nativeHandle)
            if nativeRow >= 0 {
                return nativeRow
            }
            if backend.tableClickedColumn(for: nativeHandle) >= 0 {
                return -1
            }
        }

        return selectedRow
    }

    /// Most recent column activated by mouse or keyboard, or `-1`.
    var clickedColumn: Int {
        if let nativeHandle,
           let nativeColumn = realizedBackend?.tableClickedColumn(for: nativeHandle),
           nativeColumn >= 0 {
            return nativeColumn
        }

        return selectedColumn
    }

    /// Whether columns can be selected.
    var allowsColumnSelection: Bool {
        get {
            tableAllowsColumnSelection[ObjectIdentifier(self)] ?? false
        }
        set {
            tableAllowsColumnSelection[ObjectIdentifier(self)] = newValue
            if !newValue {
                tableSelectedColumnIndexes[ObjectIdentifier(self)] = []
            }
        }
    }

    /// Current selected column indexes.
    var selectedColumnIndexes: Set<Int> {
        tableSelectedColumnIndexes[ObjectIdentifier(self)] ?? []
    }

    /// Number of selected columns.
    var numberOfSelectedColumns: Int {
        selectedColumnIndexes.count
    }

    /// Selector intended to be sent for a double-click action.
    var doubleAction: Selector? {
        get {
            tableDoubleActions[ObjectIdentifier(self)]
        }
        set {
            tableDoubleActions[ObjectIdentifier(self)] = newValue
        }
    }

    /// Selects columns when column selection is enabled.
    func selectColumnIndexes(_ indexes: Set<Int>, byExtendingSelection extend: Bool) {
        guard allowsColumnSelection else {
            return
        }

        let validIndexes = indexes.filter { $0 >= 0 && $0 < numberOfColumns }
        guard !validIndexes.isEmpty else {
            return
        }

        let identifier = ObjectIdentifier(self)
        let oldSelection = tableSelectedColumnIndexes[identifier] ?? []
        tableSelectedColumnIndexes[identifier] = extend
            ? oldSelection.union(validIndexes)
            : validIndexes
    }

    /// Deselects a specific column.
    func deselectColumn(_ column: Int) {
        let identifier = ObjectIdentifier(self)
        var selection = tableSelectedColumnIndexes[identifier] ?? []
        selection.remove(column)
        tableSelectedColumnIndexes[identifier] = selection
    }

    /// Returns whether a column is selected.
    func isColumnSelected(_ column: Int) -> Bool {
        selectedColumnIndexes.contains(column)
    }

    /// Applies the column's sort descriptor prototype, toggling it when already active.
    @discardableResult
    func sortUsingDescriptorPrototype(forColumn column: Int) -> NSSortDescriptor? {
        guard let tableColumn = tableColumn(at: column),
              let prototype = tableColumn.sortDescriptorPrototype else {
            return nil
        }

        let nextDescriptor: NSSortDescriptor
        if let current = sortDescriptors.first,
           current.key == prototype.key,
           current.ascending == prototype.ascending {
            nextDescriptor = prototype.reversedSortDescriptor
        } else {
            nextDescriptor = prototype
        }

        sortDescriptors = [nextDescriptor]
        return nextDescriptor
    }

    /// Sends the table's double-click action, dispatching the `doubleAction`
    /// selector to `target` (or down the responder chain), as AppKit does.
    func sendDoubleAction() {
        guard isEnabled else {
            return
        }

        _ = sendAction(doubleAction, to: target)
    }
}
