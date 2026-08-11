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
        guard let delegate = winEffectiveDelegate else {
            return false
        }
        return winMainActor { delegate.tableView(self, viewFor: tableColumns[0], row: 0) != nil
            || delegate.tableView(self, rowViewFor: 0) != nil }
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
        if let delegate = winEffectiveDelegate {
            let h = winMainActor { delegate.tableView(self, heightOfRow: row) }
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
        // Recycle the outgoing hosted views: move those with a reuse identifier
        // into the pool so a delegate that calls `makeView(withIdentifier:owner:)`
        // gets the same instance back instead of allocating a new one.
        winCellViewReusePool.removeAll()
        for view in winHostedCellViews {
            view.removeFromSuperview()
            if let key = view.identifier?.rawValue {
                winCellViewReusePool[key, default: []].append(view)
            }
        }
        winHostedCellViews.removeAll()
        winHostedCellKeys.removeAll()
        winHostedRowViews.removeAll()
        defer { winCellViewReusePool.removeAll() }

        let width = frame.size.width
        let columnCount = tableColumns.count
        for row in 0..<numberOfRows {
            // A delegate-vended row view sits full-width behind the cells and
            // paints the row background/selection. Add it first so cells layer
            // on top.
            if let rowView = winMainActor({ winEffectiveDelegate?.tableView(self, rowViewFor: row) }) {
                rowView.frame = NSRect(x: 0, y: winRowY(row), width: width, height: winRowHeightAt(row))
                rowView.isSelected = selectedRowIndexes.contains(row)
                addSubview(rowView)
                winHostedCellViews.append(rowView)
                winHostedRowViews[row] = rowView
            }
            for column in tableColumns.indices {
                guard let cellView = winMainActor({ winEffectiveDelegate?.tableView(self, viewFor: tableColumns[column], row: row) }) else {
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
        let style = WinDrawnTableStyle.current
        let rowsBottom = winDrawRowsAndBackground(width: width, style: style)
        winDrawGrid(width: width, rowsBottom: rowsBottom, style: style)

        // Header row — drawn in the body only when it is NOT pinned into a
        // separate strip (see `winDrawHeaderBar`).
        if !winHeaderIsPinned {
            winDrawHeaderBar(width: width)
        }

        // Per-cell decoration (e.g. outline disclosure triangles) and text for
        // cells the delegate does not vend a view for (drawn-text cells).
        winDrawCells(style: style)

        // Reorder drop-line indicator on top of everything.
        winDrawDropIndicator()
    }

    func winDrawRowsAndBackground(width: CGFloat, style: WinDrawnTableStyle) -> CGFloat {
        style.bodyFill.setFill()
        NSBezierPath(rect: bounds).fill()

        var rowY = winBodyTopInset
        for row in 0..<numberOfRows {
            let height = winRowHeightAt(row)
            let rowRect = NSRect(x: 0, y: rowY, width: width, height: height)
            if selectedRowIndexes.contains(row) {
                NSColor.selectedTextBackgroundColor.setFill()
                NSBezierPath(rect: rowRect).fill()
            } else if usesAlternatingRowBackgroundColors, row % 2 == 1 {
                style.alternatingRowFill.setFill()
                NSBezierPath(rect: rowRect).fill()
            }
            rowY += height
        }
        return rowY
    }

    func winDrawGrid(width: CGFloat, rowsBottom: CGFloat, style: WinDrawnTableStyle) {
        style.gridColor.setStroke()
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
    }

    func winDrawCells(style: WinDrawnTableStyle) {
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
                let trailing = winDrawnTrailingInset(forRow: row, column: column)
                let color: NSColor = selectedRowIndexes.contains(row)
                    ? .selectedTextColor : style.cellTextColor
                // Match the native control font (Segoe UI 9pt → 12px) and center
                // the text the way the header title is (optically centered).
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 9),
                    .foregroundColor: color,
                ]
                // Truncate with an ellipsis to the content width (column minus the
                // leading offset, trailing decoration space, and a small pad), and
                // clip as a hard safety net so nothing spills into the next column.
                let columnWidth = max(20, tableColumns[column].width)
                let contentWidth = max(0, columnWidth - 6 - inset - trailing - 2)
                let origin = NSMakePoint(winColumnX(column) + 6 + inset, textY + (h - 24) / 2 + 2)
                let clipRect = NSRect(x: winColumnX(column), y: textY,
                                      width: max(0, columnWidth - trailing), height: h)
                NSGraphicsContext.saveGraphicsState()
                (clipRect).clip()
                if let attributed = winAttributedValue(atColumn: column, row: row), attributed.length > 0 {
                    // A data-source `NSAttributedString`: draw with the value's
                    // own attributes (single dominant style at its start), unless
                    // the row is selected (then use the selection color).
                    var cellAttributes = attributed.attributes(at: 0, effectiveRange: nil)
                    if selectedRowIndexes.contains(row) {
                        cellAttributes[.foregroundColor] = NSColor.selectedTextColor
                    }
                    let shown = winTruncatedText(attributed.string, toWidth: contentWidth, attributes: cellAttributes)
                    shown.draw(at: origin, withAttributes: cellAttributes)
                } else {
                    let shown = winTruncatedText(text, toWidth: contentWidth, attributes: attributes)
                    shown.draw(at: origin, withAttributes: attributes)
                }
                NSGraphicsContext.restoreGraphicsState()
            }
            textY += h
        }

    }

    /// Returns `text` truncated with a trailing ellipsis so it fits within
    /// `width` when drawn with `attributes`, or `text` unchanged when it already
    /// fits. `width <= 0` yields the empty string.
}
