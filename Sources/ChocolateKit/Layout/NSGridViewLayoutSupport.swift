extension NSGridView {
    struct GridLayoutMetrics {
        var widths: [CGFloat]
        var heights: [CGFloat]
        let columnOrigins: [CGFloat]
        let rowOrigins: [CGFloat]
    }

    func winLayoutGrid() {
        var widths = columnWidths()
        var heights = rowHeights()
        stretchColumnWidths(&widths)
        stretchRowHeights(&heights)
        let metrics = GridLayoutMetrics(
            widths: widths,
            heights: heights,
            columnOrigins: gridOrigins(count: columns.count, visibleIndices: visibleColumns, sizes: widths, spacing: columnSpacing),
            rowOrigins: gridOrigins(count: rows.count, visibleIndices: visibleRows, sizes: heights, spacing: rowSpacing)
        )
        for rowIndex in visibleRows {
            layoutGridRow(rowIndex, metrics: metrics)
        }
    }

    func stretchColumnWidths(_ widths: inout [CGFloat]) {
        let fittingWidth = visibleColumns.reduce(0) { $0 + widths[$1] }
            + columnSpacing * CGFloat(max(visibleColumns.count - 1, 0))
        let extraWidth = bounds.size.width - fittingWidth
        guard extraWidth > 0 else { return }
        let stretchable = visibleColumns.filter { columns[$0].width == NSGridView.sizedForContent }
        guard !stretchable.isEmpty else { return }
        let share = extraWidth / CGFloat(stretchable.count)
        for columnIndex in stretchable {
            widths[columnIndex] += share
        }
    }

    func stretchRowHeights(_ heights: inout [CGFloat]) {
        let fittingHeight = visibleRows.reduce(0) { $0 + heights[$1] }
            + rowSpacing * CGFloat(max(visibleRows.count - 1, 0))
        let extraHeight = bounds.size.height - fittingHeight
        guard extraHeight > 0 else { return }
        let stretchable = visibleRows.filter { rows[$0].height == NSGridView.sizedForContent }
        guard !stretchable.isEmpty else { return }
        let share = extraHeight / CGFloat(stretchable.count)
        for rowIndex in stretchable {
            heights[rowIndex] += share
        }
    }

    func gridOrigins(count: Int, visibleIndices: [Int], sizes: [CGFloat], spacing: CGFloat) -> [CGFloat] {
        var origins = [CGFloat](repeating: 0, count: count)
        var position: CGFloat = 0
        for index in visibleIndices {
            origins[index] = position
            position += sizes[index] + spacing
        }
        return origins
    }

    func layoutGridRow(_ rowIndex: Int, metrics: GridLayoutMetrics) {
        let alignment = rows[rowIndex].rowAlignment == .inherited ? rowAlignment : rows[rowIndex].rowAlignment
        let alignsBaselines = alignment == .firstBaseline || alignment == .lastBaseline
        let baseline = alignsBaselines ? gridBaseline(forRow: rowIndex) : 0
        for columnIndex in visibleColumns {
            layoutGridCell(
                row: rowIndex,
                column: columnIndex,
                metrics: metrics,
                baseline: baseline,
                alignsBaselines: alignsBaselines
            )
        }
    }

    func gridBaseline(forRow rowIndex: Int) -> CGFloat {
        var baseline: CGFloat = 0
        for columnIndex in visibleColumns where mergedRegion(row: rowIndex, column: columnIndex) == nil {
            guard let content = cells[rowIndex][columnIndex].contentView else { continue }
            let size = contentSize(cell: content)
            baseline = max(baseline, size.height - content.baselineOffsetFromBottom)
        }
        return baseline
    }

    func layoutGridCell(
        row rowIndex: Int,
        column columnIndex: Int,
        metrics: GridLayoutMetrics,
        baseline: CGFloat,
        alignsBaselines: Bool
    ) {
        if let region = mergedRegion(row: rowIndex, column: columnIndex) {
            layoutMergedCell(region, row: rowIndex, column: columnIndex, metrics: metrics)
            return
        }
        layoutRegularCell(
            row: rowIndex,
            column: columnIndex,
            metrics: metrics,
            baseline: baseline,
            alignsBaselines: alignsBaselines
        )
    }

    func layoutMergedCell(_ region: MergedRegion, row: Int, column: Int, metrics: GridLayoutMetrics) {
        guard row == region.headRow, column == region.headColumn,
              let content = cells[row][column].contentView else { return }
        let firstColumn = region.columns.lowerBound
        let lastColumn = region.columns.upperBound - 1
        let firstRow = region.rows.lowerBound
        let lastRow = region.rows.upperBound - 1
        let left = metrics.columnOrigins[firstColumn] + columns[firstColumn].leadingPadding
        let right = metrics.columnOrigins[lastColumn] + metrics.widths[lastColumn] - columns[lastColumn].trailingPadding
        let top = metrics.rowOrigins[firstRow] + rows[firstRow].topPadding
        let bottom = metrics.rowOrigins[lastRow] + metrics.heights[lastRow] - rows[lastRow].bottomPadding
        let span = NSRect(x: left, y: top, width: max(right - left, 0), height: max(bottom - top, 0))
        let cell = cells[row][column]
        content.frame = placeContent(content, in: span, x: resolvedX(cell), y: resolvedY(cell))
    }

    func layoutRegularCell(
        row: Int,
        column: Int,
        metrics: GridLayoutMetrics,
        baseline: CGFloat,
        alignsBaselines: Bool
    ) {
        let cell = cells[row][column]
        guard let content = cell.contentView else { return }
        let cellRect = NSRect(
            x: metrics.columnOrigins[column] + columns[column].leadingPadding,
            y: metrics.rowOrigins[row] + rows[row].topPadding,
            width: max(metrics.widths[column] - columns[column].leadingPadding - columns[column].trailingPadding, 0),
            height: max(metrics.heights[row] - rows[row].topPadding - rows[row].bottomPadding, 0)
        )
        var frame = placeContent(content, in: cellRect, x: resolvedX(cell), y: resolvedY(cell))
        if alignsBaselines, cell.yPlacement == .inherited {
            frame.origin.y = cellRect.origin.y + baseline - (frame.size.height - content.baselineOffsetFromBottom)
        }
        content.frame = frame
    }

    func mergedRegion(row: Int, column: Int) -> MergedRegion? {
        mergedRegions.first { $0.covers(row: row, column: column) }
    }

    func ensureColumnCount(_ count: Int) {
        while columns.count < count {
            let column = NSGridColumn()
            column.gridView = self
            columns.append(column)
            for row in cells.indices {
                let cell = NSGridCell(contentView: nil)
                cell.owner = self
                cell.row = rows[row]
                cell.column = column
                cells[row].append(cell)
            }
        }
    }

    func ensureRowCount(_ count: Int) {
        while rows.count < count {
            let row = NSGridRow()
            row.gridView = self
            rows.append(row)
            var rowCells: [NSGridCell] = []
            for column in columns {
                let cell = NSGridCell(contentView: nil)
                cell.owner = self
                cell.row = row
                cell.column = column
                rowCells.append(cell)
            }
            cells.append(rowCells)
        }
    }

    func reindex() {
        for (i, row) in rows.enumerated() { row.index = i }
        for (j, column) in columns.enumerated() { column.index = j }
    }

    func relayout() {
        invalidateIntrinsicContentSize()
        winSetNeedsLayout()
    }

    // MARK: - Sizing + layout

    /// A cell's content size for measuring: its intrinsic size per axis where it
    /// has one, else its current frame size (0 for an empty cell).
    func contentSize(_ cell: NSGridCell) -> NSSize {
        guard let view = cell.contentView else { return .zero }
        let intrinsic = view.intrinsicContentSize
        let width = intrinsic.width == NSView.noIntrinsicMetric ? view.frame.size.width : intrinsic.width
        let height = intrinsic.height == NSView.noIntrinsicMetric ? view.frame.size.height : intrinsic.height
        return NSSize(width: width, height: height)
    }

    var visibleColumns: [Int] { columns.indices.filter { !columns[$0].isHidden } }
    var visibleRows: [Int] { rows.indices.filter { !rows[$0].isHidden } }

    /// Column widths, indexed by column index (hidden columns get 0). Cells in a
    /// merged region are excluded — a spanning cell doesn't dictate any single
    /// column's width; it just fills whatever the spanned columns become.
    func columnWidths() -> [CGFloat] {
        columns.indices.map { c in
            guard !columns[c].isHidden else { return 0 }
            if columns[c].width != NSGridView.sizedForContent {
                return columns[c].width
            }
            // A cell that spans more than one column can't size a single column
            // (its width belongs to the whole span), so it's excluded here; a
            // cell merged only vertically still contributes its width.
            let content = visibleRows.compactMap { r -> CGFloat? in
                if let region = mergedRegion(row: r, column: c), region.columns.count > 1 { return nil }
                return contentSize(cells[r][c]).width
            }.max() ?? 0
            return content + columns[c].leadingPadding + columns[c].trailingPadding
        }
    }

    /// Row heights, indexed by row index (hidden rows get 0). Merged cells are
    /// excluded (see `columnWidths`).
    func rowHeights() -> [CGFloat] {
        rows.indices.map { r in
            guard !rows[r].isHidden else { return 0 }
            if rows[r].height != NSGridView.sizedForContent {
                return rows[r].height
            }
            // Excluded only when the cell spans more than one row (its height
            // belongs to the whole vertical span); a horizontally-merged header
            // still sizes the row it heads.
            let content = visibleColumns.compactMap { c -> CGFloat? in
                if let region = mergedRegion(row: r, column: c), region.rows.count > 1 { return nil }
                return contentSize(cells[r][c]).height
            }.max() ?? 0
            return content + rows[r].topPadding + rows[r].bottomPadding
        }
    }

    func resolvedX(_ cell: NSGridCell) -> NSGridCell.Placement {
        for value in [cell.xPlacement, cell.column?.xPlacement ?? .inherited, xPlacement] where value != .inherited {
            return value
        }
        return .leading
    }

    func resolvedY(_ cell: NSGridCell) -> NSGridCell.Placement {
        for value in [cell.yPlacement, cell.row?.yPlacement ?? .inherited, yPlacement] where value != .inherited {
            return value
        }
        return .center
    }

    func placeContent(_ view: NSView, in cell: NSRect, x: NSGridCell.Placement, y: NSGridCell.Placement) -> NSRect {
        let size = contentSize(cell: view)
        var frame = NSRect(origin: cell.origin, size: size)

        switch x {
        case .fill:
            frame.origin.x = cell.origin.x
            frame.size.width = cell.size.width
        case .trailing:
            frame.origin.x = cell.origin.x + cell.size.width - size.width
        case .center:
            frame.origin.x = cell.origin.x + (cell.size.width - size.width) / 2
        default: // .leading, .none, .top, .bottom, .inherited
            frame.origin.x = cell.origin.x
        }

        switch y {
        case .fill:
            frame.origin.y = cell.origin.y
            frame.size.height = cell.size.height
        case .bottom:
            frame.origin.y = cell.origin.y + cell.size.height - size.height
        case .center:
            frame.origin.y = cell.origin.y + (cell.size.height - size.height) / 2
        default: // .top, .leading, .none, .trailing, .inherited
            frame.origin.y = cell.origin.y
        }
        return frame
    }

    func contentSize(cell view: NSView) -> NSSize {
        let intrinsic = view.intrinsicContentSize
        let width = intrinsic.width == NSView.noIntrinsicMetric ? view.frame.size.width : intrinsic.width
        let height = intrinsic.height == NSView.noIntrinsicMetric ? view.frame.size.height : intrinsic.height
        return NSSize(width: width, height: height)
    }
}
