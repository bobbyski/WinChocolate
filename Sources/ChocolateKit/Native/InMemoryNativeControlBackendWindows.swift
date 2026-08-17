extension InMemoryNativeControlBackend {
    /// Returns the recorded date-picker value.
    public func datePickerDate(for handle: NativeHandle) -> Date? {
        records[handle]?.datePickerDate
    }

    /// Records a date-picker display format.
    public func setDatePickerFormat(_ format: String?, for handle: NativeHandle) {
        records[handle]?.datePickerFormat = format
    }

    /// Records a button image file path.
    public func setButtonImage(imagePath: String?, for handle: NativeHandle) {
        records[handle]?.buttonImagePath = imagePath
    }

    /// Replaces recorded table rows.
    public func setTableRows(_ rows: [[String]], selectedRow: Int, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.tableRows = rows
        record.tableSelectedRow = selectedRow
        records[handle] = record
    }

    /// Updates a single recorded table cell.
    public func setTableCellText(_ text: String, row: Int, column: Int, for handle: NativeHandle) {
        guard var record = records[handle],
              record.tableRows.indices.contains(row),
              record.tableRows[row].indices.contains(column) else {
            return
        }
        record.tableRows[row][column] = text
        records[handle] = record
    }

    /// Updates recorded table selection.
    public func setTableSelectedRow(_ selectedRow: Int, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.tableSelectedRow = selectedRow
        record.tableClickedColumn = -1
        records[handle] = record
        tableSelectedRowSets[handle] = selectedRow >= 0 ? [selectedRow] : []
    }

    /// Recorded per-handle table state for multiple selection, editing, sorting.
    /// The `tableAllowsMultipleSelection` value.
    /// The `tableEditableHandles` value.
    /// The `tableSortIndicators` value.

    /// Records native multiple-selection enablement.
    public func setTableAllowsMultipleSelection(_ allows: Bool, for handle: NativeHandle) {
        tableAllowsMultipleSelection[handle] = allows
    }

    /// Records a multiple-row selection.
    public func setTableSelectedRows(_ rows: Set<Int>, for handle: NativeHandle) {
        tableSelectedRowSets[handle] = rows.sorted()
        records[handle]?.tableSelectedRow = rows.min() ?? -1
        records[handle]?.tableClickedColumn = -1
    }

    /// Reads the recorded selected rows.
    public func tableSelectedRows(for handle: NativeHandle) -> [Int] {
        tableSelectedRowSets[handle] ?? (tableSelectedRow(for: handle) >= 0 ? [tableSelectedRow(for: handle)] : [])
    }

    /// Records table editability.
    public func setTableEditable(_ editable: Bool, for handle: NativeHandle) {
        if editable {
            tableEditableHandles.insert(handle)
        } else {
            tableEditableHandles.remove(handle)
        }
    }

    /// No-op edit trigger for the in-memory backend (see `simulateTableEdit`).
    public func editTableCell(row: Int, column: Int, for handle: NativeHandle) {}

    /// Records a sort indicator (column < 0 clears it).
    public func setTableSortIndicator(column: Int, ascending: Bool, for handle: NativeHandle) {
        if column < 0 {
            tableSortIndicators.removeValue(forKey: handle)
        } else {
            tableSortIndicators[handle] = (column, ascending)
        }
    }

    /// Records the in-place-edit commit callback.
    public func registerTableEditAction(for handle: NativeHandle, action: @escaping (Int, Int, String) -> Void) {
        tableEditActionsByHandle[handle] = action
    }

    /// Test hook: commits an in-place edit as if the user typed it.
    public func simulateTableEdit(row: Int, column: Int, text: String, for handle: NativeHandle) {
        tableEditActionsByHandle[handle]?(row, column, text)
    }

    /// Records the row double-click callback.
    public func registerTableDoubleClickAction(for handle: NativeHandle, action: @escaping () -> Void) {
        tableDoubleClickActionsByHandle[handle] = action
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

    /// Records a table row visibility request.
    public func scrollTableRowToVisible(_ row: Int, for handle: NativeHandle) {
        guard var record = records[handle] else {
            return
        }

        record.tableVisibleRow = row
        records[handle] = record
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

    /// Records a text change action.
    public func registerTextChangeAction(for handle: NativeHandle, action: @escaping (String) -> Void) {
        textChangeActions[handle] = action
    }

    /// Records a focus-change action.
    public func registerFocusChangeAction(for handle: NativeHandle, action: @escaping (Bool) -> Void) {
        focusChangeActions[handle] = action
    }

    /// Simulates a native focus change for tests.
    public func simulateFocusChange(gained: Bool, for handle: NativeHandle) {
        focusChangeActions[handle]?(gained)
    }

    /// Records a mouse-down action.
    public func registerMouseDownAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        mouseDownActions[handle] = action
    }

    /// Records a mouse-up action.
    public func registerMouseUpAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        mouseUpActions[handle] = action
    }

    /// Records a mouse-moved action.
    public func registerMouseMovedAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        mouseMovedActions[handle] = action
    }

    /// Records a mouse-left action.
    public func registerMouseLeftAction(for handle: NativeHandle, action: @escaping () -> Void) {
        mouseLeftActions[handle] = action
    }

    /// Simulates the cursor leaving a control for tests.
    public func simulateMouseLeft(for handle: NativeHandle) {
        mouseLeftActions[handle]?()
    }

    /// Records a mouse-dragged action.
    public func registerMouseDraggedAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        mouseDraggedActions[handle] = action
    }

    /// Records a right mouse-down action.
    public func registerRightMouseDownAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        rightMouseDownActions[handle] = action
    }

    /// Records a right mouse-up action.
    public func registerRightMouseUpAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        rightMouseUpActions[handle] = action
    }

    /// Records a tertiary mouse-down action.
    public func registerOtherMouseDownAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        otherMouseDownActions[handle] = action
    }

    /// Records a tertiary mouse-up action.
    public func registerOtherMouseUpAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        otherMouseUpActions[handle] = action
    }

    /// Records a scroll-wheel action.
    public func registerScrollWheelAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        scrollWheelActions[handle] = action
    }

    /// Records a draw action.
    public func registerDrawAction(for handle: NativeHandle, action: @escaping (NativeDrawingContext, NSRect) -> Void) {
        drawActions[handle] = action
    }

    /// Records a repaint request.
    public func invalidateControl(_ handle: NativeHandle) {
        invalidatedHandles.append(handle)
    }

    /// Records a repaint request for a control and its descendants.
    public func invalidateControlTree(_ handle: NativeHandle) {
        invalidatedHandles.append(handle)
        invalidatedTreeHandles.append(handle)
    }

    /// Records a synchronous repaint request.
    public func redrawControlImmediately(_ handle: NativeHandle) {
        invalidatedHandles.append(handle)
        invalidatedTreeHandles.append(handle)
    }

    /// Runs a handle's registered draw action and returns the recorded commands.
    @discardableResult
    public func performDraw(for handle: NativeHandle, in rect: NSRect) -> RecordingDrawingContext {
        let context = RecordingDrawingContext()
        drawActions[handle]?(context, rect)
        return context
    }

    /// Records a key-down action.
    public func registerKeyDownAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        keyDownActions[handle] = action
    }

    /// Records a key-up action.
    public func registerKeyUpAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        keyUpActions[handle] = action
    }

    /// Returns the default alert response without displaying UI.
    public func runAlert(_ alert: NSAlert) -> NSApplication.ModalResponse {
        .alertFirstButtonReturn
    }

    /// Records the request and returns the next scripted dialog result.
    public func runFileDialog(_ options: NativeFileDialogOptions) -> [String]? {
        fileDialogRequests.append(options)
        guard !scriptedFileDialogPaths.isEmpty else {
            return nil
        }

        return scriptedFileDialogPaths.removeFirst()
    }

    /// Records the request and returns the scripted color chooser result.
    public func runColorChooser(initialColor: NSColor) -> NSColor? {
        colorChooserRequests.append(initialColor)
        return nextColorChooserResult
    }

    /// Records the request and returns the scripted font chooser result.
    public func runFontChooser(initialFont: NSFont?) -> NSFont? {
        fontChooserRequests.append(initialFont)
        return nextFontChooserResult
    }

    /// Records the modal session and returns the scripted stop code.
    public func runModal(for handle: NativeHandle) -> Int {
        modalSessions.append(handle)
        return nextModalResponseCode
    }

    /// Records a modal stop request.
}
