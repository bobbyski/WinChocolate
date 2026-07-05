/// Framework-drawn (view-based) table rendering for `NSTableView`.
///
/// A native `SysListView32` can't host arbitrary per-cell views, so when the
/// delegate vends cell views the table realizes a plain custom-drawn peer: it
/// draws the header, grid, and selection itself, and hosts the delegate's cell
/// views as real child subviews positioned in a column/row grid. This is the
/// same custom-draw approach used for the level indicator and token chips,
/// scaled to a table. (First slice: no vertical scrolling yet — rows beyond
/// the frame are clipped; scrolling is a follow-up.)
/// Commits the drawn table's in-place edit overlay when its field ends editing
/// (focus loss / Enter), then tears the overlay down.
public final class WinDrawnCellEditor: NSTextFieldDelegate {
    weak var table: NSTableView?
    public func controlTextDidEndEditing(_ obj: NSNotification) {
        table?.winCommitDrawnEdit()
    }
}

/// The non-scrolling header strip for a framework-drawn table hosted in a
/// scroll view. It draws the table's column header and routes header clicks to
/// sorting, staying pinned while the body scrolls beneath it.
public final class WinDrawnHeaderStrip: NSView {
    weak var table: NSTableView?

    public override func draw(_ dirtyRect: NSRect) {
        table?.winDrawHeaderBar(width: frame.size.width)
    }

    public override func mouseDown(with event: NSEvent) {
        guard let table else {
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        table.winHeaderMouseDown(atX: point.x)
    }

    public override func mouseDragged(with event: NSEvent) {
        guard let table else {
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        table.winHeaderResizeDrag(toX: point.x)
    }

    public override func mouseUp(with event: NSEvent) {
        table?.winHeaderResizeEnd()
    }
}

extension NSTableView {
    /// Whether the table should draw itself and host view-based cells.
    ///
    /// Matches AppKit's rule: a table is *view-based* — and so uses the
    /// framework-drawn peer that can host per-cell/row views — when its delegate
    /// vends a cell view for the first cell or a full-width row view for the
    /// first row. `winUsesViewBasedCells` forces it on for callers that want a
    /// drawn (all-text) table without vending any view.
    var winShouldUseDrawnCells: Bool {
        guard numberOfRows > 0, !tableColumns.isEmpty else {
            return false
        }
        // An explicit opt-in forces the drawn peer even with no delegate (e.g.
        // an all-text drawn table, or an outline view that draws its own tree).
        if winUsesViewBasedCells {
            return true
        }
        guard let delegate else {
            return false
        }
        return delegate.tableView(self, viewFor: tableColumns[0], row: 0) != nil
            || delegate.tableView(self, rowViewFor: 0) != nil
    }

    /// Whether the drawn table hides its header (all columns untitled).
    var winHeaderHidden: Bool {
        tableColumns.allSatisfy { $0.title.isEmpty }
    }

    /// The header row height (0 when the header is hidden).
    var winHeaderHeight: CGFloat {
        winHeaderHidden ? 0 : winDrawnHeaderHeight
    }

    /// Whether the drawn table's header is pinned in a non-scrolling strip above
    /// the scrolling body (true when it's a scroll-view document view with a
    /// visible header). When pinned, the body excludes the header and the strip
    /// draws it.
    var winHeaderIsPinned: Bool {
        winIsDrawn && !winHeaderHidden && enclosingScrollView != nil
    }

    /// The header space reserved *within the scrolling body*: 0 when the header
    /// is pinned (drawn in the strip), else the header height.
    var winBodyTopInset: CGFloat {
        winHeaderIsPinned ? 0 : winHeaderHeight
    }

    /// The x origin of a drawn column, from cumulative column widths.
    func winColumnX(_ column: Int) -> CGFloat {
        tableColumns.prefix(column).reduce(0) { $0 + max(20, $1.width) }
    }

    /// The height of a single row, honoring the delegate's `heightOfRow`.
    ///
    /// `heightOfRow` has a protocol-default that returns `rowHeight`, so a value
    /// equal to `rowHeight` is indistinguishable from "delegate didn't override"
    /// — in that case we keep the drawn baseline (`winDrawnRowHeight`). A value
    /// that differs is a genuine per-row customization and is honored.
    func winRowHeight(_ row: Int) -> CGFloat {
        if let delegate {
            let h = delegate.tableView(self, heightOfRow: row)
            if h > 0, h != rowHeight {
                return max(16, h)
            }
        }
        return winDrawnRowHeight
    }

    /// The cached height of a row (from the last rebuild), or a fresh query
    /// when the cache is stale/empty — so drawing and hit-testing agree.
    func winRowHeightAt(_ row: Int) -> CGFloat {
        guard row >= 0 else { return winDrawnRowHeight }
        if row < winRowHeights.count {
            return winRowHeights[row]
        }
        return winRowHeight(row)
    }

    /// The y origin of a row: header height plus the sum of the heights of all
    /// rows above it (variable-height aware).
    func winRowY(_ row: Int) -> CGFloat {
        var y = winBodyTopInset
        for r in 0..<max(0, row) {
            y += winRowHeightAt(r)
        }
        return y
    }

    /// Recomputes the per-row height cache from the delegate.
    func winRebuildRowHeights() {
        winRowHeights = (0..<numberOfRows).map { winRowHeight($0) }
    }

    /// The cell rectangle for a row and column in the drawn table.
    func winCellRect(row: Int, column: Int) -> NSRect {
        NSRect(
            x: winColumnX(column),
            y: winRowY(row),
            width: column < tableColumns.count ? max(20, tableColumns[column].width) : 0,
            height: winRowHeightAt(row)
        )
    }

    /// The row at a y-coordinate in the drawn table, or `-1` above the rows.
    func winRowAtY(_ y: CGFloat) -> Int {
        guard y >= winBodyTopInset else {
            return -1
        }
        var cursor = winBodyTopInset
        for row in 0..<numberOfRows {
            cursor += winRowHeightAt(row)
            if y < cursor {
                return row
            }
        }
        return -1
    }

    /// The full content height of the drawn table (header + all rows).
    var winContentHeight: CGFloat {
        var h = winBodyTopInset
        for row in 0..<numberOfRows {
            h += winRowHeightAt(row)
        }
        return h
    }

    /// When the drawn table is a scroll view's document view, grows it to its
    /// full content height so the scroll view clips and scrolls the extra rows.
    /// (Standalone drawn tables keep their given frame and clip.)
    func winSizeToContentIfScrolled() {
        guard winIsDrawn, let scrollView = enclosingScrollView else {
            return
        }
        // Install/refresh the pinned header strip first — it insets the content
        // clip, which changes the viewport size the document sizes against.
        winSetupPinnedHeader()
        let width = max(scrollView.contentView.bounds.size.width, tableColumns.reduce(0) { $0 + max(20, $1.width) })
        let height = max(scrollView.contentView.bounds.size.height, winContentHeight)
        if frame.size.width != width || frame.size.height != height {
            frame = NSRect(x: frame.origin.x, y: frame.origin.y, width: width, height: height)
        }
        // Re-sync the scroll view's native scrollbars with the new document size.
        scrollView.tile()
    }

    /// Rebuilds the hosted cell views for the drawn table.
    func winRebuildHostedViews() {
        guard winIsDrawn else {
            return
        }
        winRebuildRowHeights()
        winSizeToContentIfScrolled()
        for view in winHostedCellViews {
            view.removeFromSuperview()
        }
        winHostedCellViews.removeAll()
        winHostedCellKeys.removeAll()
        winHostedRowViews.removeAll()

        let width = frame.size.width
        let columnCount = tableColumns.count
        for row in 0..<numberOfRows {
            // A delegate-vended row view sits full-width behind the cells and
            // paints the row background/selection. Add it first so cells layer
            // on top.
            if let rowView = delegate?.tableView(self, rowViewFor: row) {
                rowView.frame = NSRect(x: 0, y: winRowY(row), width: width, height: winRowHeightAt(row))
                rowView.isSelected = selectedRowIndexes.contains(row)
                addSubview(rowView)
                winHostedCellViews.append(rowView)
                winHostedRowViews[row] = rowView
            }
            for column in tableColumns.indices {
                guard let cellView = delegate?.tableView(self, viewFor: tableColumns[column], row: row) else {
                    continue
                }
                // Inset the cell view slightly so grid lines/selection show,
                // plus any leading inset (outline indentation/disclosure).
                var frame = winCellRect(row: row, column: column)
                frame = frame.insetBy(dx: 1, dy: 1)
                let lead = winDrawnLeadingInset(forRow: row, column: column)
                if lead > 0 {
                    frame.origin.x += lead
                    frame.size.width = max(0, frame.size.width - lead)
                }
                cellView.frame = frame
                addSubview(cellView)
                winHostedCellViews.append(cellView)
                winHostedCellKeys.insert(row * columnCount + column)
            }
        }
    }

    /// Repaints the drawn table and all of its hosted child views, so
    /// transparent cell labels repaint over a changed selection band or row-view
    /// fill (a plain `needsDisplay` only repaints the table surface, leaving the
    /// borderless children showing stale pixels until a scroll forces a redraw).
    func winInvalidateTree() {
        needsDisplay = true
        if let nativeHandle {
            realizedBackend?.invalidateControlTree(nativeHandle)
        }
    }

    /// Syncs hosted row views' selection state with the table's selection.
    func winUpdateHostedRowSelection() {
        for (row, rowView) in winHostedRowViews {
            rowView.isSelected = selectedRowIndexes.contains(row)
        }
    }

    /// Whether a cell hosts a delegate-vended view (vs. drawn text).
    func winCellIsHosted(row: Int, column: Int) -> Bool {
        winHostedCellKeys.contains(row * tableColumns.count + column)
    }

    /// Draws the drawn table's header, alternating rows, selection, and grid.
    func winDrawTable(_ dirtyRect: NSRect) {
        let width = frame.size.width

        // Background.
        NSColor.white.setFill()
        NSBezierPath(rect: bounds).fill()

        // Alternating row backgrounds and selection highlight.
        var rowY = winBodyTopInset
        for row in 0..<numberOfRows {
            let h = winRowHeightAt(row)
            let rowRect = NSRect(x: 0, y: rowY, width: width, height: h)
            if selectedRowIndexes.contains(row) {
                NSColor.selectedTextBackgroundColor.setFill()
                NSBezierPath(rect: rowRect).fill()
            } else if usesAlternatingRowBackgroundColors, row % 2 == 1 {
                NSColor(white: 0.96, alpha: 1).setFill()
                NSBezierPath(rect: rowRect).fill()
            }
            rowY += h
        }
        let rowsBottom = rowY

        // Grid lines.
        NSColor(white: 0.85, alpha: 1).setStroke()
        if gridStyleMask.contains(.solidHorizontalGridLineMask) {
            var y = winBodyTopInset
            for row in 0...numberOfRows {
                let line = NSBezierPath()
                line.move(to: NSMakePoint(0, y))
                line.line(to: NSMakePoint(width, y))
                line.stroke()
                if row < numberOfRows {
                    y += winRowHeightAt(row)
                }
            }
        }
        if gridStyleMask.contains(.solidVerticalGridLineMask) {
            for column in tableColumns.indices {
                let x = winColumnX(column)
                let line = NSBezierPath()
                line.move(to: NSMakePoint(x, winBodyTopInset))
                line.line(to: NSMakePoint(x, rowsBottom))
                line.stroke()
            }
        }

        // Header row — drawn in the body only when it is NOT pinned into a
        // separate strip (see `winDrawHeaderBar`).
        if !winHeaderIsPinned {
            winDrawHeaderBar(width: width)
        }

        // Per-cell decoration (e.g. outline disclosure triangles) and text for
        // cells the delegate does not vend a view for (drawn-text cells).
        var textY = winBodyTopInset
        for row in 0..<numberOfRows {
            let h = winRowHeightAt(row)
            for column in tableColumns.indices {
                let cellRect = NSRect(x: winColumnX(column), y: textY,
                                      width: column < tableColumns.count ? max(20, tableColumns[column].width) : 0,
                                      height: h)
                winDrawnDrawDecoration(forRow: row, column: column, cellRect: cellRect)
                guard !winCellIsHosted(row: row, column: column) else {
                    continue
                }
                if row == winDrawnEditRow, column == winDrawnEditColumn {
                    continue
                }
                let text = value(atColumn: column, row: row) ?? ""
                guard !text.isEmpty else {
                    continue
                }
                let inset = winDrawnLeadingInset(forRow: row, column: column)
                let color: NSColor = selectedRowIndexes.contains(row)
                    ? .selectedTextColor : NSColor(white: 0.1, alpha: 1)
                // Match the native control font (Segoe UI 9pt → 12px) and center
                // the text the way the header title is (optically centered).
                text.draw(at: NSMakePoint(winColumnX(column) + 6 + inset, textY + (h - 24) / 2 + 2), withAttributes: [
                    .font: NSFont.systemFont(ofSize: 9),
                    .foregroundColor: color,
                ])
            }
            textY += h
        }

        // Reorder drop-line indicator on top of everything.
        winDrawDropIndicator()
    }

    /// Draws the column header (background, base line, titles, sort arrows) at
    /// the top of `width`, `winDrawnHeaderHeight` tall. Used both in-body (when
    /// the header is not pinned) and by the pinned header strip.
    func winDrawHeaderBar(width: CGFloat) {
        guard !winHeaderHidden else {
            return
        }
        let headerRect = NSRect(x: 0, y: 0, width: width, height: winDrawnHeaderHeight)
        NSColor(white: 0.93, alpha: 1).setFill()
        NSBezierPath(rect: headerRect).fill()
        // Bottom base line.
        NSColor(white: 0.75, alpha: 1).setStroke()
        let base = NSBezierPath()
        base.move(to: NSMakePoint(0, winDrawnHeaderHeight))
        base.line(to: NSMakePoint(width, winDrawnHeaderHeight))
        base.stroke()

        // Column dividers between header cells (matching the body grid).
        NSColor(white: 0.80, alpha: 1).setStroke()
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
                .font: NSFont.boldSystemFont(ofSize: 12),
                .foregroundColor: NSColor(white: 0.25, alpha: 1),
            ])
            if let sort = sortDescriptors.first,
               sort.key == tableColumns[column].sortDescriptorPrototype?.key {
                let arrowX = winColumnX(column) + max(20, tableColumns[column].width) - 14
                (sort.ascending ? "▲" : "▼").draw(at: NSMakePoint(arrowX, titleY + 3), withAttributes: [
                    .font: NSFont.systemFont(ofSize: 8),
                    .foregroundColor: NSColor(white: 0.4, alpha: 1),
                ])
            }
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

    /// Header mouse-down: begin a column resize if near a column boundary,
    /// otherwise sort by (and act on) the clicked column.
    func winHeaderMouseDown(atX x: CGFloat) {
        if let column = winColumnBoundary(atX: x) {
            winResizingColumn = column
            winResizeStartX = x
            winResizeStartWidth = max(20, tableColumns[column].width)
            return
        }
        winHeaderStripClicked(atX: x)
    }

    /// Updates the resized column's width as the header drag moves.
    func winHeaderResizeDrag(toX x: CGFloat) {
        guard winResizingColumn >= 0, tableColumns.indices.contains(winResizingColumn) else {
            return
        }
        tableColumns[winResizingColumn].width = max(24, winResizeStartWidth + (x - winResizeStartX))
        winRebuildHostedViews()
        // Repaint *synchronously* — a plain invalidate is starved by the rapid
        // drag, so the drawn grid and the header strip's divider would only
        // catch up on release. Redraw the whole enclosing scroll view (body clip
        // + pinned header strip) so both track the cursor live.
        if let scrollHandle = enclosingScrollView?.nativeHandle {
            realizedBackend?.redrawControlImmediately(scrollHandle)
        } else if let nativeHandle {
            realizedBackend?.redrawControlImmediately(nativeHandle)
        }
    }

    /// Ends an interactive column resize.
    func winHeaderResizeEnd() {
        winResizingColumn = -1
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

    /// Handles a click in the drawn table: selects the hit row, or sorts on a
    /// header click.
    func winDrawnMouseDown(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        _ = window?.makeFirstResponder(self)

        // Header click → record the clicked column, apply its sort, and send
        // the table action (parity with the native header path). When the header
        // is pinned into a strip, the strip handles clicks instead.
        if !winHeaderHidden, !winHeaderIsPinned, point.y < winDrawnHeaderHeight {
            let column = winColumnAtX(point.x)
            if column >= 0 {
                headerView?.clickedColumn = column
                if sortUsingDescriptorPrototype(forColumn: column) != nil {
                    needsDisplay = true
                }
                sendAction()
            }
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
        if extend, selectedRowIndexes.contains(row) {
            deselectRow(row)
        } else {
            selectRowIndexes([row], byExtendingSelection: extend)
        }
        winUpdateHostedRowSelection()
        winInvalidateTree()
        sendAction()

        // Arm a potential reorder drag from this row.
        if winRowReorderHandler != nil {
            winDraggingRow = row
            winDropIndex = -1
        }

        // Double-click a drawn (non-hosted) cell in an editable column → edit.
        if event.clickCount >= 2 {
            let column = winColumnAtX(point.x)
            if column >= 0 {
                winBeginDrawnEdit(row: row, column: column)
            }
        }
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

    /// Updates the drop-insertion indicator as a reorder drag moves.
    func winDrawnMouseDragged(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let index = winDropInsertionIndex(atY: point.y)
        if index != winDropIndex {
            winDropIndex = index
            winInvalidateTree()
        }
    }

    /// Commits a reorder drag: calls the handler with (fromRow, toIndex).
    func winDrawnMouseUp(_ event: NSEvent) {
        defer {
            winDraggingRow = -1
            winDropIndex = -1
            winInvalidateTree()
        }
        guard let handler = winRowReorderHandler,
              winDraggingRow >= 0, winDropIndex >= 0 else {
            return
        }
        // A drop just above or just below the source row is a no-op.
        if winDropIndex == winDraggingRow || winDropIndex == winDraggingRow + 1 {
            return
        }
        handler(winDraggingRow, winDropIndex)
        reloadData()
    }

    /// Draws the reorder drop-line indicator, if a drag is active.
    func winDrawDropIndicator() {
        guard winDraggingRow >= 0, winDropIndex >= 0 else {
            return
        }
        var y = winHeaderHeight
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
    private func winColumnAtX(_ x: CGFloat) -> Int {
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
