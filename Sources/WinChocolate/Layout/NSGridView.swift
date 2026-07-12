import WinFoundation

/// A cell in an `NSGridView`, hosting one content view.
public final class NSGridCell {
    /// How a content view is positioned within its grid cell, matching AppKit's
    /// `NSGridCell.Placement`.
    public enum Placement: Int, Sendable {
        case inherited
        case none
        case leading
        case top
        case trailing
        case bottom
        case center
        case fill
    }

    /// The view shown in this cell (or `nil` for an empty cell). Setting it
    /// adds the view to the grid and detaches any previous content view.
    public var contentView: NSView? {
        didSet {
            guard oldValue !== contentView else { return }
            if oldValue?.superview === owner { oldValue?.removeFromSuperview() }
            if let contentView, let owner, contentView.superview !== owner {
                owner.addSubview(contentView)
            }
            owner?.winSetNeedsLayout()
        }
    }

    /// Cell-level horizontal placement; `.inherited` defers to the column/grid.
    public var xPlacement: Placement = .inherited {
        didSet { owner?.winSetNeedsLayout() }
    }

    /// Cell-level vertical placement; `.inherited` defers to the row/grid.
    public var yPlacement: Placement = .inherited {
        didSet { owner?.winSetNeedsLayout() }
    }

    weak var row: NSGridRow?
    weak var column: NSGridColumn?
    weak var owner: NSGridView?

    init(contentView: NSView?) {
        self.contentView = contentView
    }
}

/// A column in an `NSGridView`.
public final class NSGridColumn {
    /// An explicit width, or `NSGridView.sizedForContent` to size to the widest
    /// cell content in the column.
    public var width: CGFloat = NSGridView.sizedForContent {
        didSet { gridView?.winSetNeedsLayout() }
    }

    /// The column's default horizontal placement for its cells.
    public var xPlacement: NSGridCell.Placement = .inherited {
        didSet { gridView?.winSetNeedsLayout() }
    }

    /// Whether the column is hidden (excluded from layout).
    public var isHidden: Bool = false {
        didSet { gridView?.invalidateIntrinsicContentSize(); gridView?.winSetNeedsLayout() }
    }

    /// Extra space reserved inside the column, leading and trailing.
    public var leadingPadding: CGFloat = 0 { didSet { gridView?.winSetNeedsLayout() } }
    public var trailingPadding: CGFloat = 0 { didSet { gridView?.winSetNeedsLayout() } }

    weak var gridView: NSGridView?
    var index: Int = 0

    /// The number of cells in the column (the grid's row count).
    public var numberOfCells: Int { gridView?.numberOfRows ?? 0 }

    /// The cell at a row index.
    public func cell(at rowIndex: Int) -> NSGridCell {
        gridView!.cell(atColumnIndex: index, rowIndex: rowIndex)
    }
}

/// A row in an `NSGridView`.
public final class NSGridRow {
    /// How cell content baselines line up within the row.
    public enum Alignment: Int, Sendable {
        case inherited
        case none
        case firstBaseline
        case lastBaseline
    }

    /// An explicit height, or `NSGridView.sizedForContent` to size to the
    /// tallest cell content in the row.
    public var height: CGFloat = NSGridView.sizedForContent {
        didSet { gridView?.winSetNeedsLayout() }
    }

    /// The row's default vertical placement for its cells.
    public var yPlacement: NSGridCell.Placement = .inherited {
        didSet { gridView?.winSetNeedsLayout() }
    }

    /// The row's baseline alignment (stored for API fidelity; the layout uses
    /// the placement model).
    public var rowAlignment: Alignment = .inherited {
        didSet { gridView?.winSetNeedsLayout() }
    }

    /// Whether the row is hidden (excluded from layout).
    public var isHidden: Bool = false {
        didSet { gridView?.invalidateIntrinsicContentSize(); gridView?.winSetNeedsLayout() }
    }

    /// Extra space reserved inside the row, top and bottom.
    public var topPadding: CGFloat = 0 { didSet { gridView?.winSetNeedsLayout() } }
    public var bottomPadding: CGFloat = 0 { didSet { gridView?.winSetNeedsLayout() } }

    weak var gridView: NSGridView?
    var index: Int = 0

    /// The number of cells in the row (the grid's column count).
    public var numberOfCells: Int { gridView?.numberOfColumns ?? 0 }

    /// The cell at a column index.
    public func cell(at columnIndex: Int) -> NSGridCell {
        gridView!.cell(atColumnIndex: columnIndex, rowIndex: index)
    }
}

/// A view that lays out its content in a 2-D grid of rows and columns, matching
/// AppKit's `NSGridView` — the standard container for label-and-field forms.
///
/// Each column sizes to the widest cell content (or an explicit `width`), each
/// row to the tallest, and every cell positions its content view per the
/// resolved placement (cell → column/row → grid). The grid reports an
/// `intrinsicContentSize`, so it composes inside a constraint layout.
open class NSGridView: NSView {
    /// Sentinel for a column/row that should size to its content.
    public static let sizedForContent: CGFloat = .greatestFiniteMagnitude

    /// Grid-wide default horizontal placement.
    open var xPlacement: NSGridCell.Placement = .leading { didSet { relayout() } }

    /// Grid-wide default vertical placement.
    open var yPlacement: NSGridCell.Placement = .center { didSet { relayout() } }

    /// Grid-wide default row alignment (stored for API fidelity).
    /// The grid's default row alignment. `.firstBaseline`/`.lastBaseline`
    /// align a row's cell contents on their text baselines (via each view's
    /// `baselineOffsetFromBottom`), overriding row/grid y-placement; a cell's
    /// own explicit `yPlacement` still wins. WinChocolate defaults to `.none`
    /// (centered placement) — a documented divergence from AppKit's
    /// `.firstBaseline` default, pinned by existing consumers; set it
    /// explicitly for baseline rows.
    open var rowAlignment: NSGridRow.Alignment = .none { didSet { relayout() } }

    /// Space between adjacent rows.
    open var rowSpacing: CGFloat = 8 { didSet { relayout() } }

    /// Space between adjacent columns.
    open var columnSpacing: CGFloat = 8 { didSet { relayout() } }

    private var columns: [NSGridColumn] = []
    private var rows: [NSGridRow] = []

    /// A rectangular block of merged cells: the top-left cell's content spans
    /// the whole block; the other cells are covered (empty).
    private struct MergedRegion {
        var columns: Range<Int>
        var rows: Range<Int>
        var headRow: Int { rows.lowerBound }
        var headColumn: Int { columns.lowerBound }
        func covers(row: Int, column: Int) -> Bool { rows.contains(row) && columns.contains(column) }
    }
    private var mergedRegions: [MergedRegion] = []
    /// Cells indexed `[rowIndex][columnIndex]`.
    private var cells: [[NSGridCell]] = []

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    /// Creates a grid from a row-major array of views (AppKit's
    /// `NSGridView(views:)`); short rows are padded with empty cells.
    public convenience init(views rowViews: [[NSView]]) {
        self.init(frame: .zero)
        rowViews.forEach { _ = addRow(with: $0) }
    }

    // MARK: - Structure

    open var numberOfRows: Int { rows.count }
    open var numberOfColumns: Int { columns.count }

    open func row(at index: Int) -> NSGridRow { rows[index] }
    open func column(at index: Int) -> NSGridColumn { columns[index] }

    /// The cell at a column/row index.
    open func cell(atColumnIndex columnIndex: Int, rowIndex: Int) -> NSGridCell {
        cells[rowIndex][columnIndex]
    }

    /// Appends a row of views (adding columns if the row is wider than the grid).
    @discardableResult
    open func addRow(with views: [NSView]) -> NSGridRow {
        insertRow(at: rows.count, with: views)
    }

    /// Inserts a row of views at an index.
    @discardableResult
    open func insertRow(at index: Int, with views: [NSView]) -> NSGridRow {
        ensureColumnCount(views.count)
        let row = NSGridRow()
        row.gridView = self
        let clamped = min(max(index, 0), rows.count)
        rows.insert(row, at: clamped)

        var rowCells: [NSGridCell] = []
        for column in 0..<columns.count {
            let view = column < views.count ? views[column] : nil
            let cell = NSGridCell(contentView: view)
            cell.owner = self
            cell.row = row
            cell.column = columns[column]
            rowCells.append(cell)
            if let view, view.superview !== self {
                addSubview(view)
            }
        }
        cells.insert(rowCells, at: clamped)
        reindex()
        relayout()
        return row
    }

    /// Appends a column of views (adding rows if the column is taller).
    @discardableResult
    open func addColumn(with views: [NSView]) -> NSGridColumn {
        insertColumn(at: columns.count, with: views)
    }

    /// Inserts a column of views at an index.
    @discardableResult
    open func insertColumn(at index: Int, with views: [NSView]) -> NSGridColumn {
        ensureRowCount(views.count)
        let column = NSGridColumn()
        column.gridView = self
        let clamped = min(max(index, 0), columns.count)
        columns.insert(column, at: clamped)

        for row in 0..<rows.count {
            let view = row < views.count ? views[row] : nil
            let cell = NSGridCell(contentView: view)
            cell.owner = self
            cell.row = rows[row]
            cell.column = column
            cells[row].insert(cell, at: clamped)
            if let view, view.superview !== self {
                addSubview(view)
            }
        }
        reindex()
        relayout()
        return column
    }

    /// Removes the row at an index (its content views detach from the grid).
    open func removeRow(at index: Int) {
        guard rows.indices.contains(index) else { return }
        cells[index].forEach { $0.contentView?.removeFromSuperview() }
        rows.remove(at: index)
        cells.remove(at: index)
        reindex()
        relayout()
    }

    /// Removes the column at an index (its content views detach from the grid).
    open func removeColumn(at index: Int) {
        guard columns.indices.contains(index) else { return }
        for row in cells.indices {
            cells[row][index].contentView?.removeFromSuperview()
            cells[row].remove(at: index)
        }
        columns.remove(at: index)
        reindex()
        relayout()
    }

    // MARK: - Merging

    /// Merges a rectangular block of cells into one: the top-left cell's content
    /// view spans the whole block and the other cells are emptied, matching
    /// AppKit's `mergeCells(inHorizontalRange:verticalRange:)`. Common uses are a
    /// header spanning every column, or a wide field spanning two columns.
    open func mergeCells(inHorizontalRange columnRange: NSRange, verticalRange rowRange: NSRange) {
        let cols = columnRange.location..<columnRange.upperBound
        let rowsRange = rowRange.location..<rowRange.upperBound
        guard cols.lowerBound >= 0, rowsRange.lowerBound >= 0,
              cols.upperBound <= columns.count, rowsRange.upperBound <= rows.count,
              cols.count >= 1, rowsRange.count >= 1, cols.count * rowsRange.count > 1 else {
            return
        }
        // Drop any existing region that overlaps the new block.
        mergedRegions.removeAll { $0.columns.overlaps(cols) && $0.rows.overlaps(rowsRange) }
        // Keep the head cell's content; empty every other cell in the block.
        for r in rowsRange {
            for c in cols where !(r == rowsRange.lowerBound && c == cols.lowerBound) {
                cells[r][c].contentView = nil
            }
        }
        mergedRegions.append(MergedRegion(columns: cols, rows: rowsRange))
        relayout()
    }

    /// Removes the merge covering a cell, if any (its neighbours become
    /// independent cells again).
    open func unmergeCells(atColumnIndex columnIndex: Int, rowIndex: Int) {
        mergedRegions.removeAll { $0.covers(row: rowIndex, column: columnIndex) }
        relayout()
    }

    /// The merged region covering a cell, if any.
    private func mergedRegion(row: Int, column: Int) -> MergedRegion? {
        mergedRegions.first { $0.covers(row: row, column: column) }
    }

    private func ensureColumnCount(_ count: Int) {
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

    private func ensureRowCount(_ count: Int) {
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

    private func reindex() {
        for (i, row) in rows.enumerated() { row.index = i }
        for (j, column) in columns.enumerated() { column.index = j }
    }

    private func relayout() {
        invalidateIntrinsicContentSize()
        winSetNeedsLayout()
    }

    // MARK: - Sizing + layout

    /// A cell's content size for measuring: its intrinsic size per axis where it
    /// has one, else its current frame size (0 for an empty cell).
    private func contentSize(_ cell: NSGridCell) -> NSSize {
        guard let view = cell.contentView else { return .zero }
        let intrinsic = view.intrinsicContentSize
        let width = intrinsic.width == NSView.noIntrinsicMetric ? view.frame.size.width : intrinsic.width
        let height = intrinsic.height == NSView.noIntrinsicMetric ? view.frame.size.height : intrinsic.height
        return NSSize(width: width, height: height)
    }

    private var visibleColumns: [Int] { columns.indices.filter { !columns[$0].isHidden } }
    private var visibleRows: [Int] { rows.indices.filter { !rows[$0].isHidden } }

    /// Column widths, indexed by column index (hidden columns get 0). Cells in a
    /// merged region are excluded — a spanning cell doesn't dictate any single
    /// column's width; it just fills whatever the spanned columns become.
    private func columnWidths() -> [CGFloat] {
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
    private func rowHeights() -> [CGFloat] {
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

    open override var intrinsicContentSize: NSSize {
        let widths = columnWidths()
        let heights = rowHeights()
        let visCols = visibleColumns.count
        let visRows = visibleRows.count
        guard visCols > 0, visRows > 0 else { return .zero }
        let totalWidth = visibleColumns.reduce(0) { $0 + widths[$1] } + columnSpacing * CGFloat(visCols - 1)
        let totalHeight = visibleRows.reduce(0) { $0 + heights[$1] } + rowSpacing * CGFloat(visRows - 1)
        return NSSize(width: totalWidth, height: totalHeight)
    }

    open override func layout() {
        var widths = columnWidths()
        var heights = rowHeights()

        // An over-sized grid distributes its extra space equally to the
        // content-sized tracks (explicit-width/height tracks keep their size),
        // so a grid pinned larger than its fitting size fills the frame —
        // matching AppKit's constraint-driven stretching. The fitting
        // (intrinsic) size is unaffected.
        let fittingWidth = visibleColumns.reduce(0) { $0 + widths[$1] }
            + columnSpacing * CGFloat(max(visibleColumns.count - 1, 0))
        let extraWidth = bounds.size.width - fittingWidth
        if extraWidth > 0 {
            let stretchable = visibleColumns.filter { columns[$0].width == NSGridView.sizedForContent }
            if !stretchable.isEmpty {
                let share = extraWidth / CGFloat(stretchable.count)
                for c in stretchable { widths[c] += share }
            }
        }
        let fittingHeight = visibleRows.reduce(0) { $0 + heights[$1] }
            + rowSpacing * CGFloat(max(visibleRows.count - 1, 0))
        let extraHeight = bounds.size.height - fittingHeight
        if extraHeight > 0 {
            let stretchable = visibleRows.filter { rows[$0].height == NSGridView.sizedForContent }
            if !stretchable.isEmpty {
                let share = extraHeight / CGFloat(stretchable.count)
                for r in stretchable { heights[r] += share }
            }
        }

        // Column x-origins (left to right, skipping hidden columns).
        var columnX = [CGFloat](repeating: 0, count: columns.count)
        var x: CGFloat = 0
        for c in visibleColumns {
            columnX[c] = x
            x += widths[c] + columnSpacing
        }
        // Row y-origins (top to bottom, flipped coordinates).
        var rowY = [CGFloat](repeating: 0, count: rows.count)
        var y: CGFloat = 0
        for r in visibleRows {
            rowY[r] = y
            y += heights[r] + rowSpacing
        }

        for r in visibleRows {
            // Baseline row alignment (row overrides grid; `.inherited` falls
            // through): the row's cell contents hang from a common baseline
            // computed from each view's `baselineOffsetFromBottom`. A cell's
            // own explicit `yPlacement` still wins.
            let effectiveAlignment = rows[r].rowAlignment == .inherited ? rowAlignment : rows[r].rowAlignment
            let alignsBaselines = effectiveAlignment == .firstBaseline || effectiveAlignment == .lastBaseline
            var rowBaseline: CGFloat = 0
            if alignsBaselines {
                for c in visibleColumns where mergedRegion(row: r, column: c) == nil {
                    guard let content = cells[r][c].contentView else { continue }
                    let size = contentSize(cell: content)
                    rowBaseline = max(rowBaseline, size.height - content.baselineOffsetFromBottom)
                }
            }
            for c in visibleColumns {
                // A merged region is laid out once, at its head cell; other
                // covered cells are skipped.
                if let region = mergedRegion(row: r, column: c) {
                    guard r == region.headRow, c == region.headColumn else { continue }
                    let cell = cells[r][c]
                    guard let content = cell.contentView else { continue }
                    let firstCol = region.columns.lowerBound
                    let lastCol = region.columns.upperBound - 1
                    let firstRow = region.rows.lowerBound
                    let lastRow = region.rows.upperBound - 1
                    let left = columnX[firstCol] + columns[firstCol].leadingPadding
                    let right = columnX[lastCol] + widths[lastCol] - columns[lastCol].trailingPadding
                    let top = rowY[firstRow] + rows[firstRow].topPadding
                    let bottom = rowY[lastRow] + heights[lastRow] - rows[lastRow].bottomPadding
                    let spanRect = NSRect(x: left, y: top, width: max(right - left, 0), height: max(bottom - top, 0))
                    content.frame = placeContent(content, in: spanRect,
                                                 x: resolvedX(cell), y: resolvedY(cell))
                    continue
                }
                let cell = cells[r][c]
                guard let content = cell.contentView else { continue }
                let cellRect = NSRect(x: columnX[c] + columns[c].leadingPadding,
                                      y: rowY[r] + rows[r].topPadding,
                                      width: max(widths[c] - columns[c].leadingPadding - columns[c].trailingPadding, 0),
                                      height: max(heights[r] - rows[r].topPadding - rows[r].bottomPadding, 0))
                var frame = placeContent(content, in: cellRect,
                                         x: resolvedX(cell), y: resolvedY(cell))
                if alignsBaselines, cell.yPlacement == .inherited {
                    frame.origin.y = cellRect.origin.y + rowBaseline
                        - (frame.size.height - content.baselineOffsetFromBottom)
                }
                content.frame = frame
            }
        }
    }

    private func resolvedX(_ cell: NSGridCell) -> NSGridCell.Placement {
        for value in [cell.xPlacement, cell.column?.xPlacement ?? .inherited, xPlacement] where value != .inherited {
            return value
        }
        return .leading
    }

    private func resolvedY(_ cell: NSGridCell) -> NSGridCell.Placement {
        for value in [cell.yPlacement, cell.row?.yPlacement ?? .inherited, yPlacement] where value != .inherited {
            return value
        }
        return .center
    }

    private func placeContent(_ view: NSView, in cell: NSRect, x: NSGridCell.Placement, y: NSGridCell.Placement) -> NSRect {
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

    private func contentSize(cell view: NSView) -> NSSize {
        let intrinsic = view.intrinsicContentSize
        let width = intrinsic.width == NSView.noIntrinsicMetric ? view.frame.size.width : intrinsic.width
        let height = intrinsic.height == NSView.noIntrinsicMetric ? view.frame.size.height : intrinsic.height
        return NSSize(width: width, height: height)
    }
}
