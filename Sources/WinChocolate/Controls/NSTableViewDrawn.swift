/// Framework-drawn (view-based) table rendering for `NSTableView`.
///
/// A native `SysListView32` can't host arbitrary per-cell views, so when the
/// delegate vends cell views the table realizes a plain custom-drawn peer: it
/// draws the header, grid, and selection itself, and hosts the delegate's cell
/// views as real child subviews positioned in a column/row grid. This is the
/// same custom-draw approach used for the level indicator and token chips,
/// scaled to a table. (First slice: no vertical scrolling yet — rows beyond
/// the frame are clipped; scrolling is a follow-up.)
/// The drawn table's per-presentation style tokens. The classic skin matches
/// the native `SysListView32` look (gray header slab, bold titles, visible
/// dividers); the modern skin matches themed Windows list views (flat header on
/// the body background, regular-weight titles, hairline rules). Everything the
/// drawn chrome paints routes through these tokens so the two presentations
/// stay complete alternatives rather than scattered branches.
struct WinDrawnTableStyle {
    let headerFill: NSColor
    let headerBaseline: NSColor
    let headerDivider: NSColor
    let headerTitleFont: NSFont
    let headerTitleColor: NSColor
    let sortArrowColor: NSColor
    let gridColor: NSColor
    let bodyFill: NSColor
    let alternatingRowFill: NSColor
    let cellTextColor: NSColor

    static var current: WinDrawnTableStyle {
        if NSApplication.shared.effectiveAppearance.winIsDark {
            return dark
        }
        return WinPresentation.selected == .modern ? modern : classic
    }

    static let classic = WinDrawnTableStyle(
        headerFill: NSColor(white: 0.93, alpha: 1),
        headerBaseline: NSColor(white: 0.75, alpha: 1),
        headerDivider: NSColor(white: 0.80, alpha: 1),
        headerTitleFont: NSFont.boldSystemFont(ofSize: 12),
        headerTitleColor: NSColor(white: 0.25, alpha: 1),
        sortArrowColor: NSColor(white: 0.4, alpha: 1),
        gridColor: NSColor(white: 0.85, alpha: 1),
        bodyFill: .white,
        alternatingRowFill: NSColor(white: 0.96, alpha: 1),
        cellTextColor: NSColor(white: 0.1, alpha: 1)
    )

    static let modern = WinDrawnTableStyle(
        headerFill: .white,
        headerBaseline: NSColor(white: 0.88, alpha: 1),
        headerDivider: NSColor(white: 0.92, alpha: 1),
        headerTitleFont: NSFont.systemFont(ofSize: 12),
        headerTitleColor: NSColor(white: 0.35, alpha: 1),
        sortArrowColor: NSColor(white: 0.45, alpha: 1),
        gridColor: NSColor(white: 0.92, alpha: 1),
        bodyFill: .white,
        alternatingRowFill: NSColor(white: 0.96, alpha: 1),
        cellTextColor: NSColor(white: 0.1, alpha: 1)
    )

    /// The dark skin (one skin serves both presentations; a dark *classic*
    /// look has no Windows precedent to imitate).
    static let dark = WinDrawnTableStyle(
        headerFill: NSColor(white: 0.16, alpha: 1),
        headerBaseline: NSColor(white: 0.30, alpha: 1),
        headerDivider: NSColor(white: 0.26, alpha: 1),
        headerTitleFont: NSFont.systemFont(ofSize: 12),
        headerTitleColor: NSColor(white: 0.80, alpha: 1),
        sortArrowColor: NSColor(white: 0.65, alpha: 1),
        gridColor: NSColor(white: 0.26, alpha: 1),
        bodyFill: NSColor(white: 0.14, alpha: 1),
        alternatingRowFill: NSColor(white: 0.17, alpha: 1),
        cellTextColor: NSColor(white: 0.88, alpha: 1)
    )
}

/// Commits the drawn table's in-place edit overlay when its field ends editing
/// (focus loss / Enter), then tears the overlay down.
public final class WinDrawnCellEditor: NSObject, NSTextFieldDelegate {
    weak var table: NSTableView?
    public func controlTextDidEndEditing(_ obj: Notification) {
        table?.winCommitDrawnEdit()
    }

    /// Intercepts the field editor's Tab/Backtab so editing commits and moves
    /// to the next/previous editable cell instead of letting Windows move focus
    /// off the field — AppKit's `control(_:textView:doCommandBy:)` contract.
    public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard let table else { return false }
        switch commandSelector {
        case "insertTab:":
            return table.winAdvanceDrawnEdit(reversed: false)
        case "insertBacktab:":
            return table.winAdvanceDrawnEdit(reversed: true)
        default:
            return false
        }
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
        table.winHeaderMouseDragged(toX: point.x)
    }

    public override func mouseUp(with event: NSEvent) {
        guard let table else {
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        table.winHeaderMouseUp(atX: point.x)
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

        // Background.
        style.bodyFill.setFill()
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
                style.alternatingRowFill.setFill()
                NSBezierPath(rect: rowRect).fill()
            }
            rowY += h
        }
        let rowsBottom = rowY

        // Grid lines.
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

        // Reorder drop-line indicator on top of everything.
        winDrawDropIndicator()
    }

    /// Returns `text` truncated with a trailing ellipsis so it fits within
    /// `width` when drawn with `attributes`, or `text` unchanged when it already
    /// fits. `width <= 0` yields the empty string.
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

        if extend, selectedRowIndexes.contains(row) {
            deselectRow(row)
        } else {
            selectRowIndexes([row], byExtendingSelection: extend)
        }
        winUpdateHostedRowSelection()
        winInvalidateTree()
        sendAction()

        // Arm a single-row reorder drag from this row (the explicit handler,
        // or AppKit's recipe: `.move` local mask + a data-source pasteboard
        // writer), or — when the table isn't reorderable but the data source
        // vends a writer — an external (system/OLE) drag out of the table.
        if winReorderDragEnabled(forRow: row) {
            winDraggingRow = row
            winDraggingRows = IndexSet(integer: row)
            winDropIndex = -1
            winPendingCollapseRow = -1
        } else if winMainActor { winEffectiveDataSource?.tableView(self, pasteboardWriterForRow: row) } != nil {
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
