/// The column-header view of an `NSTableView`.
///
/// The framework-drawn table paints the header itself; this object provides the
/// AppKit header API surface — the column of the most recent header click
/// (`clickedColumn`) and the geometry helpers `columnAtPoint`/`headerRectOfColumn`
/// — so app code and subclasses can reason about the header.
open class NSTableHeaderView: NSView {
    /// The table this header belongs to.
    open weak var tableView: NSTableView?

    /// The index of the column whose header was most recently clicked, or `-1`.
    open var clickedColumn: Int = -1

    /// The column currently being resized, or `-1` (resize UI is a follow-up).
    open var resizedColumn: Int = -1

    /// The column currently being dragged, or `-1` (reorder UI is a follow-up).
    open var draggedColumn: Int = -1

    /// The height of the header row.
    open var headerHeight: CGFloat = 24

    /// Returns the column index at a point in header coordinates, or `-1`.
    open func column(at point: NSPoint) -> Int {
        guard let tableView else {
            return -1
        }
        var x: CGFloat = 0
        for (index, column) in tableView.tableColumns.enumerated() {
            let width = max(20, column.width)
            if point.x >= x, point.x < x + width {
                return index
            }
            x += width
        }
        return -1
    }

    /// Returns the header rectangle for a column in header coordinates.
    open func headerRect(ofColumn column: Int) -> NSRect {
        guard let tableView, tableView.tableColumns.indices.contains(column) else {
            return .zero
        }
        var x: CGFloat = 0
        for index in 0..<column {
            x += max(20, tableView.tableColumns[index].width)
        }
        return NSRect(x: x, y: 0, width: max(20, tableView.tableColumns[column].width), height: headerHeight)
    }
}
