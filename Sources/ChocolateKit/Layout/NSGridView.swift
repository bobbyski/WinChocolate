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
    /// The `trailingPadding` value.
    public var trailingPadding: CGFloat = 0 { didSet { gridView?.winSetNeedsLayout() } }

    weak var gridView: NSGridView?
    var index: Int = 0

    /// The number of cells in the column (the grid's row count).
    public var numberOfCells: Int { gridView?.numberOfRows ?? 0 }

    /// The cell at a row index.
    public func cell(at rowIndex: Int) -> NSGridCell {
        guard let gridView else {
            preconditionFailure("Detached NSGridColumn has no cells.")
        }
        return gridView.cell(atColumnIndex: index, rowIndex: rowIndex)
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
    /// The `bottomPadding` value.
    public var bottomPadding: CGFloat = 0 { didSet { gridView?.winSetNeedsLayout() } }

    weak var gridView: NSGridView?
    var index: Int = 0

    /// The number of cells in the row (the grid's column count).
    public var numberOfCells: Int { gridView?.numberOfColumns ?? 0 }

    /// The cell at a column index.
    public func cell(at columnIndex: Int) -> NSGridCell {
        guard let gridView else {
            preconditionFailure("Detached NSGridRow has no cells.")
        }
        return gridView.cell(atColumnIndex: columnIndex, rowIndex: index)
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

    var columns: [NSGridColumn] = []
    var rows: [NSGridRow] = []

    /// A rectangular block of merged cells: the top-left cell's content spans
    /// the whole block; the other cells are covered (empty).
    struct MergedRegion {
        var columns: Range<Int>
        var rows: Range<Int>
        var headRow: Int { rows.lowerBound }
        var headColumn: Int { columns.lowerBound }
        func covers(row: Int, column: Int) -> Bool { rows.contains(row) && columns.contains(column) }
    }
    var mergedRegions: [MergedRegion] = []
    /// Cells indexed `[rowIndex][columnIndex]`.
    var cells: [[NSGridCell]] = []

    /// Creates an empty grid view with the supplied frame.
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    /// Creates a grid from a row-major array of views (AppKit's
    /// `NSGridView(views:)`); short rows are padded with empty cells.
    public convenience init(views rowViews: [[NSView]]) {
        self.init(frame: .zero)
        rowViews.forEach { _ = addRow(with: $0) }
    }

    // MARK: - Structure

    /// The `numberOfRows` value.
    open var numberOfRows: Int { rows.count }
    /// The `numberOfColumns` value.
    open var numberOfColumns: Int { columns.count }

    /// Performs the `row` operation.
    open func row(at index: Int) -> NSGridRow { rows[index] }
    /// Performs the `column` operation.
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
    /// The size required by the grid's rows, columns, spacing, and padding.
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

    /// Arranges grid cells using the current row and column metrics.
    open override func layout() {
        winLayoutGrid()
    }

}
