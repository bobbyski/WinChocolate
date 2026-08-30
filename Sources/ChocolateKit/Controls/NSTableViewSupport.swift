extension NSTableView {

    /// Clamps a proposed column width to the column's `minWidth`/`maxWidth`
    /// (`maxWidth <= 0` means unbounded).
    internal func winClampedColumnWidth(_ width: CGFloat, for column: NSTableColumn) -> CGFloat {
        var w = max(width, column.minWidth)
        if column.maxWidth > 0 {
            w = min(w, column.maxWidth)
        }
        return w
    }


    /// Reflows the drawn table after column widths change (a no-op for the
    /// native-list peer, whose column widths are fixed at creation — the same
    /// boundary as interactive resize).
    internal func winApplyColumnWidths() {
        if winIsDrawn {
            winRebuildHostedViews()
            needsDisplay = true
        }
    }


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


    internal func moveFocusWithTab(_ event: NSEvent) {
        if event.modifierFlags.contains(.shift) {
            window?.selectPreviousKeyView(nil)
        } else {
            window?.selectNextKeyView(nil)
        }
    }


    /// Selects rows by a plain `Set`, the shared implementation behind AppKit's
    /// `selectRowIndexes(_:byExtendingSelection:)`.
    ///
    /// Deliberately *not* an overload of the AppKit name: Apple declares only
    /// the `IndexSet` form, and once real Foundation is underneath — where
    /// `IndexSet` is `ExpressibleByArrayLiteral`, as Apple's is — a second
    /// overload taking `Set<Int>` makes every `selectRowIndexes([row], …)`
    /// call site ambiguous.
    func selectRows(_ indexes: Set<Int>, byExtendingSelection extend: Bool) {
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


    /// Reloads only the given cells from the data source, updating each in
    /// place natively instead of rebuilding the whole table.
    internal func reloadDataForRows(_ rowIndexes: Set<Int>, columns columnIndexes: Set<Int>) {
        let columns = columnIndexes.isEmpty ? Set(tableColumns.indices) : columnIndexes
        for row in rowIndexes where rowValues.indices.contains(row) {
            for column in columns where tableColumns.indices.contains(column) {
                let value = winMainActor { winEffectiveDataSource?.tableView(self, objectValueFor: tableColumns[column], row: row) }
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


    internal func commitEdit(row: Int, column: Int, text: String) {
        guard rowValues.indices.contains(row) else {
            return
        }
        setObjectValue(text, for: tableColumn(at: column), row: row)
    }


    internal func handleHeaderClick(column: Int) {
        headerView?.clickedColumn = column
        guard let sort = sortUsingDescriptorPrototype(forColumn: column) else {
            return
        }
        if let nativeHandle {
            realizedBackend?.setTableSortIndicator(column: column, ascending: sort.ascending, for: nativeHandle)
        }
    }


    internal func syncRowsToNative() {
        guard let nativeHandle else {
            return
        }

        realizedBackend?.setTableRows(rowValues, selectedRow: selectedRow, for: nativeHandle)
    }


    internal func updateSelectionFromNative(rows: [Int]) {
        isUpdatingSelectionFromNative = true
        let valid = Set(rows.filter { rowValues.indices.contains($0) })
        selectedRowIndexes = valid
        selectedRow = valid.min() ?? -1
        selectedColumn = selectedRow >= 0 && numberOfColumns > 0 ? 0 : -1
        isUpdatingSelectionFromNative = false
    }


    internal func moveSelection(by offset: Int, extending: Bool) {
        guard numberOfRows > 0 else {
            return
        }

        let base = selectedRow >= 0 ? selectedRow : (offset < 0 ? numberOfRows : -1)
        selectKeyboardRow(base + offset, extending: extending)
    }


    internal func selectKeyboardRow(_ row: Int, extending: Bool) {
        guard numberOfRows > 0 else {
            return
        }

        let clampedRow = max(0, min(row, numberOfRows - 1))
        selectRowIndexes([clampedRow], byExtendingSelection: extending)
        scrollRowToVisible(clampedRow)
    }


    internal func notifySelectionChanged() {
        if winIsDrawn {
            needsDisplay = true
        }
        winInternalSelectionChanged?(self)
        winMainActor { winEffectiveDelegate?.tableViewSelectionDidChange(Notification(name: Notification.Name(Self.selectionDidChangeNotification), object: self)) }
    }

    func winSizeToFit() {
        if winAutoresizeColumns() {
            winApplyColumnWidths()
        }
    }

    /// Grows or shrinks the columns to fill the table's width, without
    /// rebuilding anything.
    ///
    /// **Split out from `winSizeToFit` so the layout pass can call it.** A cell
    /// view is sized to its *column*, not to the table, so a single-column
    /// table whose column is still the default 100pt draws 100pt-wide cells
    /// inside a 283pt table — every label in them overflows, and in a sidebar
    /// each row's text lands on the row below. The columns therefore have to
    /// be resized *before* the rows are built, and `winSizeToFit` cannot be
    /// used for that: it ends by rebuilding, which is what would be calling it.
    ///
    /// - Returns: whether any column's width actually changed.
    @discardableResult
    func winAutoresizeColumns() -> Bool {
        guard !tableColumns.isEmpty else { return false }
        switch columnAutoresizingStyle {
        case .noColumnAutoresizing:
            return false
        case .lastColumnOnlyAutoresizingStyle:
            sizeLastColumnToFit()
            return true
        case .uniformColumnAutoresizingStyle:
            let spacing = intercellSpacing.width * CGFloat(max(0, tableColumns.count - 1))
            let current = tableColumns.reduce(0) { $0 + $1.width }
            let delta = frame.size.width - spacing - current
            guard abs(delta) > 0.5 else {
                return false
            }
            let share = delta / CGFloat(tableColumns.count)
            for index in tableColumns.indices {
                tableColumns[index].width = winClampedColumnWidth(tableColumns[index].width + share, for: tableColumns[index])
            }
            return true
        }
    }

    func winKeyDown(with event: NSEvent) {
        if event.keyCode == TableKeyCode.return {
            if !winBeginEditSelectedRow() {
                sendAction()
            }
            return
        }
        switch event.keyCode {
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
        case TableKeyCode.space:
            sendAction()
        default:
            super.keyDown(with: event)
        }
    }

    func winSelectAll(_ sender: Any?) {
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

    func winScrollRowToVisible(_ row: Int) {
        guard row >= 0, row < numberOfRows else {
            return
        }

        // A native list peer scrolls itself (LVM_ENSUREVISIBLE); the clip-view
        // nudge below is the drawn table's mechanism.
        if !winIsDrawn, let nativeHandle {
            realizedBackend?.scrollTableRowToVisible(row, for: nativeHandle)
            return
        }

        guard let scrollView = enclosingScrollView else {
            return
        }

        let clip = scrollView.contentView
        let rowTop = winIsDrawn ? winRowY(row) : CGFloat(row) * rowHeight
        let rowHeightValue = winIsDrawn ? winRowHeightAt(row) : rowHeight
        let visible = clip.documentVisibleRect

        var origin = visible.origin
        if rowTop < visible.origin.y {
            origin.y = rowTop
        } else if rowTop + rowHeightValue > visible.origin.y + visible.size.height {
            origin.y = rowTop + rowHeightValue - visible.size.height
        } else {
            return
        }

        clip.scroll(to: origin)
        scrollView.reflectScrolledClipView(clip)
    }

    func winAccessibilityChildren() -> [Any]? {
        // The data-driven row/cell tree is the table's accessibility surface:
        // it carries every cell's text whether the table draws its own cells
        // or hosts cell views, so assistive technology and the contract tests
        // see the same structure. An explicit app override still wins.
        if let explicit = winExplicitAccessibilityChildren { return explicit }
        guard numberOfRows > 0 else { return nil }
        var rows: [NSAccessibilityProtocol] = []
        for row in 0..<numberOfRows {
            let rowElement = NSAccessibilityElement()
            rowElement.setAccessibilityRole(.row)
            rowElement.setAccessibilitySubrole(winReportsAsOutline ? .outlineRow : .tableRow)
            rowElement.accessibilityFrameInParentSpace = winAccessibilityRowFrame(row)
            rowElement.winAccessibilityParent = self
            var cells: [NSAccessibilityProtocol] = []
            for column in 0..<max(1, tableColumns.count) {
                let cell = NSAccessibilityElement()
                cell.setAccessibilityRole(.cell)
                cell.setAccessibilityValue(value(atColumn: column, row: row) ?? "")
                if tableColumns.indices.contains(column) {
                    cell.setAccessibilityLabel(tableColumns[column].title)
                }
                cell.accessibilityFrameInParentSpace = winAccessibilityRowFrame(row)
                cells.append(cell)
            }
            rowElement.setAccessibilityChildren(cells)
            rows.append(rowElement)
        }
        return rows
    }

    func winReloadData(forRowIndexes rowIndexes: IndexSet, columnIndexes: IndexSet) {
        reloadDataForRows(Set(rowIndexes), columns: Set(columnIndexes))
    }

    func winRealizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
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
        backend.registerTableDoubleClickAction(for: handle) { [weak self] in
            self?.sendDoubleAction()
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

    func winEditColumn(_ column: Int, row: Int, with event: NSEvent?, select: Bool) {
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

    func winDeselectAll(_ sender: Any?) {
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

    func winReloadAllData() {
        let count = winMainActor { winEffectiveDataSource?.numberOfRows(in: self) } ?? 0
        let (nextRows, nextRaw) = winLoadedRows(count: count)

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

    private func winLoadedRows(count: Int) -> ([[String]], [[Any?]]) {
        var nextRows: [[String]] = []
        var nextRaw: [[Any?]] = []
        for row in 0..<count {
            var strings: [String] = []
            var raws: [Any?] = []
            for column in tableColumns {
                let value = winMainActor { winEffectiveDataSource?.tableView(self, objectValueFor: column, row: row) }
                raws.append(value)
                strings.append(winDisplayString(from: value))
            }
            nextRows.append(strings)
            nextRaw.append(raws)
        }
        return (nextRows, nextRaw)
    }
}
