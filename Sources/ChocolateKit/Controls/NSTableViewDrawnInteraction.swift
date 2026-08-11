extension NSTableView {

    @discardableResult
    public func winAdvanceDrawnEdit(reversed: Bool) -> Bool {
        guard winDrawnEditField != nil else { return false }
        let fromRow = winDrawnEditRow
        let fromColumn = winDrawnEditColumn
        guard let next = winNextEditableDrawnCell(afterRow: fromRow, column: fromColumn, reversed: reversed) else {
            return false
        }
        winCommitDrawnEdit()
        selectRowIndexes(IndexSet(integer: next.row), byExtendingSelection: false)
        winBeginDrawnEdit(row: next.row, column: next.column)
        return true
    }

    /// Handles a click in the drawn table: selects the hit row, or sorts on a
    /// header click.
    func winDrawnMouseDown(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        _ = window?.makeFirstResponder(self)

        if winHandleHeaderMouseDown(at: point) {
            return
        }

        let row = winRowAtY(point.y)
        guard row >= 0 else {
            return
        }

        // A click on an in-cell decoration (e.g. an outline disclosure triangle)
        // is consumed before selection.
        let hitColumn = winColumnAtX(point.x)
        if hitColumn >= 0, winDrawnHandleDecorationClick(forRow: row, column: hitColumn, at: point) {
            return
        }

        let extend = allowsMultipleSelection && (event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.command))

        // Pressing an already-selected row of a multi-selection (no modifier)
        // must not collapse the selection yet — that would prevent dragging all
        // of them. Defer the collapse to mouse-up (only if no drag happens) and
        // arm a multi-row drag now. (AppKit's mouse-down-and-drag behavior.)
        if !extend, winReorderDragEnabled(forRow: row), selectedRowIndexes.contains(row), selectedRowIndexes.count > 1 {
            winDraggingRow = row
            winDraggingRows = IndexSet(selectedRowIndexes)
            winDropIndex = -1
            winPendingCollapseRow = row
            return
        }

        winApplyMouseSelection(row: row, extending: extend)

        // Arm a single-row reorder drag from this row (the explicit handler,
        // or AppKit's recipe: `.move` local mask + a data-source pasteboard
        // writer), or — when the table isn't reorderable but the data source
        // vends a writer — an external (system/OLE) drag out of the table.
        if winReorderDragEnabled(forRow: row) {
            winDraggingRow = row
            winDraggingRows = IndexSet(integer: row)
            winDropIndex = -1
            winPendingCollapseRow = -1
        } else if winMainActor({ winEffectiveDataSource?.tableView(self, pasteboardWriterForRow: row) }) != nil {
            winExternalDragRow = row
        }

        // Double-click sends the table's double-action (AppKit parity), then a
        // drawn (non-hosted) cell in an editable column begins editing.
        if event.clickCount >= 2 {
            sendDoubleAction()
            let column = winColumnAtX(point.x)
            if column >= 0 {
                winBeginDrawnEdit(row: row, column: column)
            }
        }
    }

    func winHandleHeaderMouseDown(at point: NSPoint) -> Bool {
        guard !winHeaderHidden, !winHeaderIsPinned, point.y < winDrawnHeaderHeight else {
            return false
        }
        let column = winColumnAtX(point.x)
        if column >= 0 {
            headerView?.clickedColumn = column
            if sortUsingDescriptorPrototype(forColumn: column) != nil {
                needsDisplay = true
            }
            sendAction()
        }
        return true
    }

    func winApplyMouseSelection(row: Int, extending: Bool) {
        if extending, selectedRowIndexes.contains(row) {
            deselectRow(row)
        } else {
            selectRowIndexes([row], byExtendingSelection: extending)
        }
        winUpdateHostedRowSelection()
        winInvalidateTree()
        sendAction()
    }

    /// The insertion index (0...numberOfRows) a drop at `y` targets.
    func winDropInsertionIndex(atY y: CGFloat) -> Int {
        guard y >= winBodyTopInset else {
            return 0
        }
        var cursor = winBodyTopInset
        for row in 0..<numberOfRows {
            let h = winRowHeightAt(row)
            if y < cursor + h / 2 {
                return row
            }
            cursor += h
        }
        return numberOfRows
    }

    /// Updates the drop-insertion indicator as a reorder drag moves, or begins
    /// an external drag when one is armed.
    func winDrawnMouseDragged(_ event: NSEvent) {
        if winExternalDragRow >= 0 {
            winStartExternalRowDrag(event)
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        let index = winDropInsertionIndex(atY: point.y)
        if index != winDropIndex {
            winDropIndex = index
            winInvalidateTree()
        }
    }

    /// Begins a system/OLE drag carrying the armed row's pasteboard writer. The
    /// classic backend runs the drag loop synchronously, so this returns once
    /// the drop (or cancel) completes.
    func winStartExternalRowDrag(_ event: NSEvent) {
        let row = winExternalDragRow
        winExternalDragRow = -1
        guard row >= 0, row < numberOfRows,
              let writer = winMainActor({ winEffectiveDataSource?.tableView(self, pasteboardWriterForRow: row) }) else {
            return
        }
        let item = NSDraggingItem(pasteboardWriter: writer)
        item.draggingFrame = winCellRect(row: row, column: 0)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    /// Commits a reorder drag: calls the handler with (fromRows, toIndex). If no
    /// drag occurred but a selection collapse was deferred, applies it now.
    func winDrawnMouseUp(_ event: NSEvent) {
        defer {
            winDraggingRow = -1
            winDraggingRows = IndexSet()
            winDropIndex = -1
            winPendingCollapseRow = -1
            winExternalDragRow = -1
            winInvalidateTree()
        }
        // No drag happened (mouse never moved to set a drop index).
        if winDropIndex < 0 {
            if winPendingCollapseRow >= 0 {
                selectRowIndexes([winPendingCollapseRow], byExtendingSelection: false)
                winUpdateHostedRowSelection()
                sendAction()
            }
            return
        }
        guard winDraggingRow >= 0, !winDraggingRows.isEmpty else {
            return
        }
        // A single-row drop just above or below its own row is a no-op.
        if winDraggingRows.count == 1, winDropIndex == winDraggingRow || winDropIndex == winDraggingRow + 1 {
            return
        }
        if let handler = winRowReorderHandler {
            handler(winDraggingRows, winDropIndex)
            reloadData()
            return
        }
        // AppKit's reorder pathway: the drop arrives at the data source's
        // `tableView(_:acceptDrop:row:dropOperation:)` with `.above`, the
        // dragged row indexes riding the pasteboard as a comma-separated
        // string (the local-drag payload convention).
        guard let dataSource = winEffectiveDataSource else {
            return
        }
        let rowList = winDraggingRows.map(String.init).joined(separator: ",")
        let info = WinDraggingInfo(
            content: NativeDropContent(text: rowList, filePaths: []),
            location: NSMakePoint(0, 0)
        )
        let accepted = winMainActor {
            dataSource.tableView(self, acceptDrop: info, row: winDropIndex, dropOperation: .above)
        }
        if accepted {
            reloadData()
        }
    }

    /// Draws the reorder drop-line indicator, if a drag is active.
    func winDrawDropIndicator() {
        guard winDraggingRow >= 0, winDropIndex >= 0 else {
            return
        }
        // Rows start at `winBodyTopInset` — 0 when the header is pinned in its
        // own strip. Measuring from `winHeaderHeight` drew the line one header
        // height low (a top drop showed between rows 1 and 2 while correctly
        // inserting before row 1).
        var y = winBodyTopInset
        for row in 0..<winDropIndex where row < numberOfRows {
            y += winRowHeightAt(row)
        }
        let width = frame.size.width
        let accent = NSColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1)
        // A bold insertion bar with a round cap on the left, like AppKit's.
        accent.setStroke()
        let line = NSBezierPath()
        line.lineWidth = 3
        line.move(to: NSMakePoint(4, y))
        line.line(to: NSMakePoint(width, y))
        line.stroke()
        accent.setFill()
        NSBezierPath(ovalIn: NSRect(x: 0, y: y - 4, width: 8, height: 8)).fill()
    }

    /// The column at an x-coordinate, or `-1`.
    func winColumnAtX(_ x: CGFloat) -> Int {
        for column in tableColumns.indices {
            let start = winColumnX(column)
            let end = start + max(20, tableColumns[column].width)
            if x >= start, x < end {
                return column
            }
        }
        return -1
    }
}
