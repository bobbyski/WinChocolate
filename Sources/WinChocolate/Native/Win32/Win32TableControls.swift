#if os(Windows)
extension Win32NativeControlBackend {
    /// Creates a native table-view child.
    public func createTableView(columns: [String], rows: [[String]], selectedRow: Int, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        createTableView(columns: columns, columnWidths: [], rows: rows, selectedRow: selectedRow, frame: frame, parent: parent)
    }

    /// Creates a native table-view child with explicit column widths.
    public func createTableView(columns: [String], columnWidths: [CGFloat], rows: [[String]], selectedRow: Int, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        initializeListViewControls()
        let handle = createChildWindow(
            className: "SysListView32",
            text: "",
            frame: frame,
            parent: parent,
            commandIdentifier: nextCommandID(),
            style: wsChild | wsVisible | wsTabStop | wsBorder | wsVScroll | lvsReport | lvsSingleSel | lvsShowSelAlways
        )
        subclassControlForTabKey(handle)
        tableColumnTitles[handle.rawValue] = columns
        tableClickedRows[handle.rawValue] = -1
        tableClickedColumns[handle.rawValue] = -1
        installTableColumns(columns, widths: columnWidths, for: handle)
        if let hwnd = hwnd(from: handle) {
            _ = winSendMessageW(hwnd, lvmSetExtendedListViewStyle, 0, LPARAM(lvsExFullRowSelect | lvsExGridLines))
            if let headerHwnd = HWND(bitPattern: winSendMessageW(hwnd, lvmGetHeader, 0, 0)) {
                tableHeaderOwners[UInt(bitPattern: headerHwnd)] = handle
            }
            // `DarkMode_Explorer` (applied at creation) themes the selection
            // and scrollbar; the row background/text need explicit colors.
            applyDarkListViewColorsIfNeeded(hwnd)
        }
        setTableRows(rows, selectedRow: selectedRow, for: handle)
        return handle
    }

    /// Replaces native table rows.
    public func setTableRows(_ rows: [[String]], selectedRow: Int, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winSendMessageW(hwnd, lvmDeleteAllItems, 0, 0)
        for (rowIndex, row) in rows.enumerated() {
            let firstValue = row.first ?? ""
            withWideString(firstValue) { title in
                var item = LVITEMW()
                item.mask = lvifText
                item.iItem = Int32(rowIndex)
                item.iSubItem = 0
                item.pszText = UnsafeMutablePointer(mutating: title)
                withUnsafePointer(to: item) { itemPointer in
                    _ = winSendMessageW(hwnd, lvmInsertItemW, 0, Int(bitPattern: itemPointer))
                }
            }

            if row.count > 1 {
                for columnIndex in 1..<row.count {
                    setTableCellText(row[columnIndex], row: rowIndex, column: columnIndex, hwnd: hwnd)
                }
            }
        }
        setTableSelectedRow(selectedRow, for: handle)
    }

    /// Updates native table selection.
    public func setTableSelectedRow(_ selectedRow: Int, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        tableClickedColumns[handle.rawValue] = -1
        tableClickedRows[handle.rawValue] = -1
        let selectedState = lvisSelected | lvisFocused
        var clearItem = LVITEMW()
        clearItem.stateMask = selectedState
        clearItem.state = 0
        withUnsafePointer(to: clearItem) { itemPointer in
            _ = winSendMessageW(hwnd, lvmSetItemState, WPARAM.max, Int(bitPattern: itemPointer))
        }

        guard selectedRow >= 0 else {
            return
        }

        var item = LVITEMW()
        item.stateMask = selectedState
        item.state = selectedState
        withUnsafePointer(to: item) { itemPointer in
            _ = winSendMessageW(hwnd, lvmSetItemState, WPARAM(selectedRow), Int(bitPattern: itemPointer))
        }
    }

    /// Updates a single cell's text in place without rebuilding the list.
    public func setTableCellText(_ text: String, row: Int, column: Int, for handle: NativeHandle) {
        guard row >= 0, column >= 0, let hwnd = hwnd(from: handle) else {
            return
        }
        setTableCellText(text, row: row, column: column, hwnd: hwnd)
    }

    /// Enables or disables native multiple-row selection by toggling
    /// `LVS_SINGLESEL` on the list-view style.
    public func setTableAllowsMultipleSelection(_ allows: Bool, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }
        var style = winGetWindowLongPtrW(hwnd, gwlStyle)
        if allows {
            style &= ~LONG_PTR(lvsSingleSel)
        } else {
            style |= LONG_PTR(lvsSingleSel)
        }
        _ = winSetWindowLongPtrW(hwnd, gwlStyle, style)
    }

    /// Replaces the native selection with the given rows (first row focused).
    public func setTableSelectedRows(_ rows: Set<Int>, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }
        tableClickedColumns[handle.rawValue] = -1
        tableClickedRows[handle.rawValue] = -1

        let selectedState = lvisSelected | lvisFocused
        var clearItem = LVITEMW()
        clearItem.stateMask = selectedState
        clearItem.state = 0
        withUnsafePointer(to: clearItem) { itemPointer in
            _ = winSendMessageW(hwnd, lvmSetItemState, WPARAM.max, Int(bitPattern: itemPointer))
        }

        for (order, row) in rows.sorted().enumerated() where row >= 0 {
            var item = LVITEMW()
            item.stateMask = selectedState
            // Only the first row takes focus; the rest are selected.
            item.state = order == 0 ? selectedState : lvisSelected
            withUnsafePointer(to: item) { itemPointer in
                _ = winSendMessageW(hwnd, lvmSetItemState, WPARAM(row), Int(bitPattern: itemPointer))
            }
        }
    }

    /// Reads every selected row, in ascending order.
    public func tableSelectedRows(for handle: NativeHandle) -> [Int] {
        guard let hwnd = hwnd(from: handle) else {
            return []
        }
        var rows: [Int] = []
        var start = WPARAM.max
        while true {
            let next = Int(winSendMessageW(hwnd, lvmGetNextItem, start, LPARAM(lvniSelected)))
            if next < 0 {
                break
            }
            rows.append(next)
            start = WPARAM(next)
        }
        return rows.sorted()
    }

    /// Enables or disables in-place first-column label editing.
    public func setTableEditable(_ editable: Bool, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }
        var style = winGetWindowLongPtrW(hwnd, gwlStyle)
        if editable {
            style |= LONG_PTR(lvsEditLabels)
            tableEditableHandles.insert(handle.rawValue)
        } else {
            style &= ~LONG_PTR(lvsEditLabels)
            tableEditableHandles.remove(handle.rawValue)
        }
        _ = winSetWindowLongPtrW(hwnd, gwlStyle, style)
    }

    /// Begins editing a cell's label (the native list-view edits the first
    /// column only, so the column argument selects the row to edit).
    public func editTableCell(row: Int, column: Int, for handle: NativeHandle) {
        guard row >= 0, let hwnd = hwnd(from: handle) else {
            return
        }
        _ = winSetFocus(hwnd)
        _ = winSendMessageW(hwnd, lvmEditLabelW, WPARAM(row), 0)
    }

    /// Draws (or clears) the ascending/descending sort arrow on a column header.
    public func setTableSortIndicator(column: Int, ascending: Bool, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle),
              let headerHwnd = HWND(bitPattern: winSendMessageW(hwnd, lvmGetHeader, 0, 0)) else {
            return
        }
        let columnCount = tableColumnTitles[handle.rawValue]?.count ?? 0
        for index in 0..<columnCount {
            var item = HDITEMW()
            item.mask = hdiFormat
            withUnsafeMutablePointer(to: &item) { itemPointer in
                _ = winSendMessageW(headerHwnd, hdmGetItemW, WPARAM(index), Int(bitPattern: itemPointer))
            }
            item.fmt &= ~(hdfSortUp | hdfSortDown)
            if index == column {
                item.fmt |= ascending ? hdfSortUp : hdfSortDown
            }
            withUnsafeMutablePointer(to: &item) { itemPointer in
                _ = winSendMessageW(headerHwnd, hdmSetItemW, WPARAM(index), Int(bitPattern: itemPointer))
            }
        }
    }

    /// Registers the in-place-edit commit callback.
    public func registerTableEditAction(for handle: NativeHandle, action: @escaping (Int, Int, String) -> Void) {
        tableEditActions[handle.rawValue] = action
    }

    /// Scrolls a native table row into view.
    public func scrollTableRowToVisible(_ row: Int, for handle: NativeHandle) {
        guard row >= 0,
              let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winSendMessageW(hwnd, lvmEnsureVisible, WPARAM(row), 0)
    }

    /// Reads native table selection.
    public func tableSelectedRow(for handle: NativeHandle) -> Int {
        guard let hwnd = hwnd(from: handle) else {
            return -1
        }

        return Int(winSendMessageW(hwnd, lvmGetNextItem, WPARAM.max, LPARAM(lvniSelected)))
    }

    /// Reads the most recent native table row activation.
    public func tableClickedRow(for handle: NativeHandle) -> Int {
        tableClickedRows[handle.rawValue] ?? -1
    }

    /// Reads the most recent native table column activation.
    public func tableClickedColumn(for handle: NativeHandle) -> Int {
        tableClickedColumns[handle.rawValue] ?? -1
    }

    private func installTableColumns(_ columns: [String], widths: [CGFloat], for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        let fallbackWidth = max(80, Int32(frameWidth(for: handle) / CGFloat(max(columns.count, 1))))
        for (index, titleText) in columns.enumerated() {
            withWideString(titleText.isEmpty ? "Column \(index + 1)" : titleText) { title in
                var column = LVCOLUMNW()
                column.mask = lvcfText | lvcfWidth | lvcfSubItem
                let requestedWidth = widths.indices.contains(index) ? Int32(widths[index]) : fallbackWidth
                column.cx = max(24, requestedWidth)
                column.pszText = UnsafeMutablePointer(mutating: title)
                column.iSubItem = Int32(index)
                withUnsafePointer(to: column) { columnPointer in
                    _ = winSendMessageW(hwnd, lvmInsertColumnW, WPARAM(index), Int(bitPattern: columnPointer))
                }
            }
        }
    }

    private func setTableCellText(_ text: String, row: Int, column: Int, hwnd: HWND?) {
        withWideString(text) { title in
            var item = LVITEMW()
            item.iItem = Int32(row)
            item.iSubItem = Int32(column)
            item.pszText = UnsafeMutablePointer(mutating: title)
            withUnsafePointer(to: item) { itemPointer in
                _ = winSendMessageW(hwnd, lvmSetItemTextW, WPARAM(row), Int(bitPattern: itemPointer))
            }
        }
    }
}
#endif
