extension NSTableView {

    func winTruncatedText(_ text: String, toWidth width: CGFloat, attributes: [NSAttributedString.Key: Any]) -> String {
        guard width > 0 else {
            return ""
        }
        if text.isEmpty || text.size(withAttributes: attributes).width <= width {
            return text
        }
        let ellipsis = "…"
        var truncated = text
        while !truncated.isEmpty {
            truncated.removeLast()
            let candidate = truncated + ellipsis
            if candidate.size(withAttributes: attributes).width <= width {
                return candidate
            }
        }
        return ellipsis
    }

    /// Draws the column header (background, base line, titles, sort arrows) at
    /// the top of `width`, `winDrawnHeaderHeight` tall. Used both in-body (when
    /// the header is not pinned) and by the pinned header strip.
    func winDrawHeaderBar(width: CGFloat) {
        guard !winHeaderHidden else {
            return
        }
        let style = WinDrawnTableStyle.current
        let headerRect = NSRect(x: 0, y: 0, width: width, height: winDrawnHeaderHeight)
        style.headerFill.setFill()
        NSBezierPath(rect: headerRect).fill()
        // Bottom base line.
        style.headerBaseline.setStroke()
        let base = NSBezierPath()
        base.move(to: NSMakePoint(0, winDrawnHeaderHeight))
        base.line(to: NSMakePoint(width, winDrawnHeaderHeight))
        base.stroke()

        // Column dividers between header cells (matching the body grid).
        style.headerDivider.setStroke()
        for column in tableColumns.indices where column > 0 {
            let x = winColumnX(column)
            let divider = NSBezierPath()
            divider.move(to: NSMakePoint(x, 3))
            divider.line(to: NSMakePoint(x, winDrawnHeaderHeight - 3))
            divider.stroke()
        }

        // Title text. `TextOutW` (TA_TOP) anchors the cell top at this y, and the
        // font's internal leading sits above the glyphs, so the visible text
        // reads lower than the geometric center — bias the y upward to match the
        // natively-centered row cells.
        let titleY: CGFloat = 0
        for column in tableColumns.indices {
            let title = tableColumns[column].title
            title.draw(at: NSMakePoint(winColumnX(column) + 6, titleY), withAttributes: [
                .font: style.headerTitleFont,
                .foregroundColor: style.headerTitleColor,
            ])
            if let sort = sortDescriptors.first,
               sort.key == tableColumns[column].sortDescriptorPrototype?.key {
                let arrowX = winColumnX(column) + max(20, tableColumns[column].width) - 14
                (sort.ascending ? "▲" : "▼").draw(at: NSMakePoint(arrowX, titleY + 3), withAttributes: [
                    .font: NSFont.systemFont(ofSize: 8),
                    .foregroundColor: style.sortArrowColor,
                ])
            }
        }

        // Reorder drop indicator: a heavy insertion bar at the target boundary.
        if winHeaderDropIndex >= 0 {
            let x = winColumnX(min(winHeaderDropIndex, tableColumns.count))
            NSColor(calibratedRed: 0.15, green: 0.45, blue: 0.85, alpha: 1).setStroke()
            let marker = NSBezierPath()
            marker.lineWidth = 2
            marker.move(to: NSMakePoint(x, 1))
            marker.line(to: NSMakePoint(x, winDrawnHeaderHeight - 1))
            marker.stroke()
        }
    }

    /// Installs (or removes) the pinned header strip on the enclosing scroll
    /// view, matching the current pinned state.
    func winSetupPinnedHeader() {
        guard let scrollView = enclosingScrollView else {
            return
        }
        if winHeaderIsPinned {
            let strip: WinDrawnHeaderStrip
            if let existing = winPinnedHeaderStrip {
                strip = existing
            } else {
                strip = WinDrawnHeaderStrip(frame: .zero)
                strip.table = self
                winPinnedHeaderStrip = strip
            }
            if scrollView.winHeaderStripView !== strip {
                scrollView.winSetHeaderStrip(strip, height: winDrawnHeaderHeight)
            }
        } else if winPinnedHeaderStrip != nil {
            scrollView.winSetHeaderStrip(nil, height: 0)
            winPinnedHeaderStrip = nil
        }
    }

    /// The column whose right edge is within `tolerance` points of `x`, or nil —
    /// used to start an interactive column resize from the header.
    func winColumnBoundary(atX x: CGFloat, tolerance: CGFloat = 4) -> Int? {
        var edge: CGFloat = 0
        for column in tableColumns.indices {
            edge += max(20, tableColumns[column].width)
            if abs(x - edge) <= tolerance {
                return column
            }
        }
        return nil
    }

    /// The column insertion index (0...count) a reorder drop at `x` targets.
    func winColumnDropIndex(atX x: CGFloat) -> Int {
        var edge: CGFloat = 0
        for column in tableColumns.indices {
            let width = max(20, tableColumns[column].width)
            if x < edge + width / 2 {
                return column
            }
            edge += width
        }
        return tableColumns.count
    }

    /// Header mouse-down: begin a column resize near a boundary; otherwise record
    /// a potential column-reorder drag / header click (resolved on mouse-up).
    func winHeaderMouseDown(atX x: CGFloat) {
        if let column = winColumnBoundary(atX: x) {
            winResizingColumn = column
            winResizeStartX = x
            winResizeStartWidth = max(20, tableColumns[column].width)
            return
        }
        winHeaderDragColumn = winColumnAtX(x)
        winHeaderDragStartX = x
        winHeaderDropIndex = -1
    }

    /// Header mouse-drag: resize the column, or (when `allowsColumnReordering`)
    /// track a column-reorder drop target past a small threshold.
    func winHeaderMouseDragged(toX x: CGFloat) {
        if winResizingColumn >= 0, tableColumns.indices.contains(winResizingColumn) {
            tableColumns[winResizingColumn].width = max(24, winResizeStartWidth + (x - winResizeStartX))
            winRebuildHostedViews()
            winRedrawHeaderAndBodyNow()
            return
        }
        if allowsColumnReordering, winHeaderDragColumn >= 0, abs(x - winHeaderDragStartX) > 6 {
            winHeaderDropIndex = winColumnDropIndex(atX: x)
            winRedrawHeaderAndBodyNow()
        }
    }

    /// Header mouse-up: finish a resize, commit a column reorder, or (if neither
    /// dragged) sort by the pressed column.
    func winHeaderMouseUp(atX x: CGFloat) {
        defer {
            winResizingColumn = -1
            winHeaderDragColumn = -1
            winHeaderDropIndex = -1
        }
        if winResizingColumn >= 0 {
            return
        }
        if winHeaderDropIndex >= 0, winHeaderDragColumn >= 0 {
            // A reorder drag occurred. `winHeaderDropIndex` is an *insertion point*
            // (0...count) in the current column order; `moveColumn` wants the
            // final index after the dragged column is removed, so shift down when
            // the drop is to the right of the source. Dropping just before or
            // after the column itself is a no-op.
            if winHeaderDropIndex != winHeaderDragColumn, winHeaderDropIndex != winHeaderDragColumn + 1 {
                let finalIndex = winHeaderDropIndex > winHeaderDragColumn
                    ? winHeaderDropIndex - 1 : winHeaderDropIndex
                moveColumn(winHeaderDragColumn, toColumn: finalIndex)
                winRebuildHostedViews()
                winRedrawHeaderAndBodyNow()
            }
            return
        }
        // No drag: treat as a header click → sort.
        if winHeaderDragColumn >= 0 {
            winHeaderStripClicked(atX: winHeaderDragStartX)
        }
    }

    /// Repaints the body surface and the header strip synchronously so a live
    /// header drag (resize/reorder) tracks the cursor rather than snapping on up.
    func winRedrawHeaderAndBodyNow() {
        if let scrollHandle = enclosingScrollView?.nativeHandle {
            realizedBackend?.redrawControlImmediately(scrollHandle)
        } else if let nativeHandle {
            realizedBackend?.redrawControlImmediately(nativeHandle)
        }
    }

    /// Handles a click in the pinned header strip: sort by the hit column and
    /// send the table action.
    func winHeaderStripClicked(atX x: CGFloat) {
        let column = winColumnAtX(x)
        guard column >= 0 else {
            return
        }
        headerView?.clickedColumn = column
        if sortUsingDescriptorPrototype(forColumn: column) != nil {
            needsDisplay = true
        }
        winPinnedHeaderStrip?.needsDisplay = true
        sendAction()
    }

    /// The first editable, non-hosted (drawn-text) column of a row, or `nil` —
    /// the target for keyboard-driven (Return) edit-begin.
    func winFirstEditableDrawnColumn(forRow row: Int) -> Int? {
        tableColumns.indices.first { column in
            tableColumns[column].isEditable && !winCellIsHosted(row: row, column: column)
        }
    }

    /// AppKit's Return-to-edit: begins editing the first editable drawn cell of
    /// the selected row. Returns whether an edit actually started (so the caller
    /// can fall back to sending the table action).
    @discardableResult
    func winBeginEditSelectedRow() -> Bool {
        guard winIsDrawn, selectedRow >= 0,
              winDrawnEditField == nil,
              let column = winFirstEditableDrawnColumn(forRow: selectedRow) else {
            return false
        }
        winBeginDrawnEdit(row: selectedRow, column: column)
        return true
    }

    /// Begins an in-place edit of a drawn (non-hosted) cell in an editable
    /// column: floats an editable text field over the cell, seeded with the
    /// current value, and focuses it. Committing writes back via the data source.
    func winBeginDrawnEdit(row: Int, column: Int) {
        guard winIsDrawn,
              tableColumns.indices.contains(column),
              tableColumns[column].isEditable,
              !winCellIsHosted(row: row, column: column),
              row >= 0, row < numberOfRows else {
            return
        }
        winCancelDrawnEdit()

        let rect = winCellRect(row: row, column: column).insetBy(dx: 1, dy: 1)
        let field = NSTextField(string: value(atColumn: column, row: row) ?? "", frame: rect)
        field.isEditable = true
        field.isBordered = true
        field.drawsBackground = true
        field.delegate = winCellEditor
        addSubview(field)
        winDrawnEditField = field
        winDrawnEditRow = row
        winDrawnEditColumn = column
        needsDisplay = true
        _ = window?.makeFirstResponder(field)
    }

    /// Commits the live drawn-cell edit to the data source and tears down the
    /// overlay. Reentrancy-safe: clears the field reference before committing.
    func winCommitDrawnEdit() {
        guard let field = winDrawnEditField else {
            return
        }
        let row = winDrawnEditRow
        let column = winDrawnEditColumn
        let text = field.stringValue
        winDrawnEditField = nil
        winDrawnEditRow = -1
        winDrawnEditColumn = -1
        field.removeFromSuperview()
        if tableColumns.indices.contains(column), row >= 0, row < numberOfRows {
            setObjectValue(text, for: tableColumns[column], row: row)
        }
        needsDisplay = true
    }

    /// Removes the drawn-cell edit overlay without committing.
    func winCancelDrawnEdit() {
        guard let field = winDrawnEditField else {
            return
        }
        winDrawnEditField = nil
        winDrawnEditRow = -1
        winDrawnEditColumn = -1
        field.removeFromSuperview()
    }

    /// The next editable, non-hosted drawn cell after `(row, column)`, scanning
    /// forward (or backward when `reversed`) across columns and then wrapping to
    /// the next/previous row. Returns `nil` when there is no further editable
    /// cell — matching AppKit, where Tab past the last field ends editing.
    func winNextEditableDrawnCell(afterRow row: Int, column: Int, reversed: Bool) -> (row: Int, column: Int)? {
        guard numberOfRows > 0, !tableColumns.isEmpty else { return nil }
        let columnCount = tableColumns.count
        var r = row
        var c = column
        // Bound the walk so a table with no other editable cell terminates.
        for _ in 0..<(numberOfRows * columnCount) {
            if reversed {
                c -= 1
                if c < 0 { c = columnCount - 1; r -= 1 }
            } else {
                c += 1
                if c >= columnCount { c = 0; r += 1 }
            }
            guard r >= 0, r < numberOfRows else { return nil }
            if tableColumns[c].isEditable, !winCellIsHosted(row: r, column: c) {
                return (r, c)
            }
        }
        return nil
    }

    /// Tab/Backtab inside the drawn cell editor: commits the current edit and
    /// begins editing the next (or previous) editable cell, selecting its row.
    /// Returns whether editing advanced; `false` means there was nowhere to go
    /// (the caller lets editing end, as AppKit does).
}
