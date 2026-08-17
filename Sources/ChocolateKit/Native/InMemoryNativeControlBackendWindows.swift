// Readers and test hooks for tables, focus and drawing.
//
// The writers, registrars and modal entry points that used to live here moved
// to the class body in `InMemoryNativeControlBackendState.swift` so a backend
// can override them — see the note there. What stays is the half no backend
// replaces: derived getters and the `simulate*` hooks tests drive.
extension InMemoryNativeControlBackend {
    /// Returns the recorded date-picker value.
    public func datePickerDate(for handle: NativeHandle) -> Date? {
        records[handle]?.datePickerDate
    }

    /// Reads the recorded selected rows.
    public func tableSelectedRows(for handle: NativeHandle) -> [Int] {
        tableSelectedRowSets[handle] ?? (tableSelectedRow(for: handle) >= 0 ? [tableSelectedRow(for: handle)] : [])
    }

    /// Test hook: commits an in-place edit as if the user typed it.
    public func simulateTableEdit(row: Int, column: Int, text: String, for handle: NativeHandle) {
        tableEditActionsByHandle[handle]?(row, column, text)
    }

    /// Test hook: double-clicks a row as if the user did, updating the clicked row.
    public func simulateTableDoubleClick(row: Int, for handle: NativeHandle) {
        records[handle]?.tableClickedRow = row
        tableDoubleClickActionsByHandle[handle]?()
    }

    /// Test hook: sets the native selection and fires the table action.
    public func simulateTableSelection(rows: [Int], for handle: NativeHandle) {
        tableSelectedRowSets[handle] = rows.sorted()
        records[handle]?.tableSelectedRow = rows.min() ?? -1
        records[handle]?.tableClickedRow = rows.min() ?? -1
        records[handle]?.tableClickedColumn = -1
        actions[handle]?()
    }

    /// Test hook: fires a header click on a column (no row) and the action.
    public func simulateTableColumnClick(column: Int, for handle: NativeHandle) {
        records[handle]?.tableClickedColumn = column
        records[handle]?.tableClickedRow = -1
        actions[handle]?()
    }

    /// Reads recorded table selection.
    public func tableSelectedRow(for handle: NativeHandle) -> Int {
        records[handle]?.tableSelectedRow ?? -1
    }

    /// Reads recorded table clicked row.
    public func tableClickedRow(for handle: NativeHandle) -> Int {
        records[handle]?.tableClickedRow ?? -1
    }

    /// Reads recorded table clicked column.
    public func tableClickedColumn(for handle: NativeHandle) -> Int {
        records[handle]?.tableClickedColumn ?? -1
    }

    /// Simulates a native focus change for tests.
    public func simulateFocusChange(gained: Bool, for handle: NativeHandle) {
        focusChangeActions[handle]?(gained)
    }

    /// Simulates the cursor leaving a control for tests.
    public func simulateMouseLeft(for handle: NativeHandle) {
        mouseLeftActions[handle]?()
    }

    /// Runs a handle's registered draw action and returns the recorded commands.
    @discardableResult
    public func performDraw(for handle: NativeHandle, in rect: NSRect) -> RecordingDrawingContext {
        let context = RecordingDrawingContext()
        drawActions[handle]?(context, rect)
        return context
    }
}
