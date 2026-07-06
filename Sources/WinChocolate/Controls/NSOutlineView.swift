/// Data source for an AppKit-shaped outline view.
public protocol NSOutlineViewDataSource: AnyObject {
    /// Returns the number of children below an item. `nil` means the root.
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int

    /// Returns the child at an index below an item. `nil` means the root.
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any

    /// Returns whether an item can expand.
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool

    /// Returns a display value for a column and item.
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any?
}

public extension NSOutlineViewDataSource {
    /// Default object value uses the item description.
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        item.map { String(describing: $0) }
    }
}

/// A tree-shaped table view.
///
/// Built on the framework-drawn table: the visible tree is flattened into the
/// table backend, and the outline draws a real **disclosure triangle** and
/// per-level indentation on its first column (via the drawn-cell hooks), with
/// clicks on the triangle expanding/collapsing the item.
open class NSOutlineView: NSTableView {
    private struct OutlineRow {
        var item: Any
        var level: Int
        var parent: Any?
    }

    /// Horizontal space reserved for the disclosure triangle on the first
    /// column, ahead of the cell text.
    private let disclosureWidth: CGFloat = 14

    private final class OutlineTableAdapter: NSTableViewDataSource {
        weak var owner: NSOutlineView?

        func numberOfRows(in tableView: NSTableView) -> Int {
            owner?.visibleRows.count ?? 0
        }

        func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
            owner?.objectValue(for: tableColumn, row: row)
        }
    }

    private let outlineAdapter = OutlineTableAdapter()
    private var visibleRows: [OutlineRow] = []
    private var expandedItemKeys: Set<String> = []

    /// Object that provides outline children and values.
    open weak var outlineDataSource: NSOutlineViewDataSource? {
        didSet {
            reloadData()
        }
    }

    /// Width used for each indentation level in the first column.
    open var indentationPerLevel: CGFloat = 16

    /// Whether indentation marker text is prefixed into the first column.
    open var showsDisclosureText: Bool = true

    /// Creates an outline view.
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        outlineAdapter.owner = self
        dataSource = outlineAdapter
        // Outlines always use the framework-drawn table so they can draw
        // disclosure triangles and indentation themselves.
        winUsesViewBasedCells = true
    }

    /// Reloads the visible outline rows.
    open override func reloadData() {
        rebuildVisibleRows()
        dataSource = outlineAdapter
        super.reloadData()
    }

    /// Expands an item.
    open func expandItem(_ item: Any?) {
        guard let item else {
            return
        }

        expandedItemKeys.insert(key(for: item))
        reloadData()
    }

    /// Collapses an item.
    open func collapseItem(_ item: Any?) {
        guard let item else {
            return
        }

        expandedItemKeys.remove(key(for: item))
        reloadData()
    }

    /// Expands a collapsed item, or collapses an expanded item.
    open func toggleItem(_ item: Any?) {
        guard let item,
              isItemExpandable(item) else {
            return
        }

        if isItemExpanded(item) {
            collapseItem(item)
        } else {
            expandItem(item)
        }
    }

    /// Returns whether an item is expanded.
    open func isItemExpanded(_ item: Any?) -> Bool {
        guard let item else {
            return false
        }

        return expandedItemKeys.contains(key(for: item))
    }

    /// Returns whether an item can expand.
    open func isItemExpandable(_ item: Any?) -> Bool {
        guard let item else {
            return false
        }

        return outlineDataSource?.outlineView(self, isItemExpandable: item) ?? false
    }

    /// Returns the visible item at a row.
    open func item(atRow row: Int) -> Any? {
        guard visibleRows.indices.contains(row) else {
            return nil
        }

        return visibleRows[row].item
    }

    /// Returns the visible row for an item, or `-1`.
    open func row(forItem item: Any?) -> Int {
        guard let item else {
            return -1
        }

        let itemKey = key(for: item)
        return visibleRows.firstIndex { key(for: $0.item) == itemKey } ?? -1
    }

    /// Returns the tree level for a visible row.
    open func level(forRow row: Int) -> Int {
        guard visibleRows.indices.contains(row) else {
            return -1
        }

        return visibleRows[row].level
    }

    /// Returns the tree level for an item.
    open func level(forItem item: Any?) -> Int {
        level(forRow: row(forItem: item))
    }

    // MARK: Drag reordering (sibling)

    /// Set to enable drag-to-reorder of outline rows among their siblings. On a
    /// drop, the outline reports the dragged item, its parent, and the proposed
    /// child index under that parent (AppKit's `acceptDrop` shape); the handler
    /// moves the item in the backing model and the outline reloads.
    ///
    /// This slice supports reordering within one parent (the common case). A
    /// drop whose nearest neighbours belong to a different parent is resolved to
    /// the dragged item's own parent, so cross-level moves are not performed.
    open var winOutlineReorderHandler: ((_ movedItem: Any, _ parent: Any?, _ childIndex: Int) -> Void)? {
        didSet { installOutlineReorderBridge() }
    }

    private func installOutlineReorderBridge() {
        guard winOutlineReorderHandler != nil else {
            winRowReorderHandler = nil
            return
        }
        winRowReorderHandler = { [weak self] fromRows, toIndex in
            self?.handleOutlineReorder(fromRows: fromRows, toIndex: toIndex)
        }
    }

    private func handleOutlineReorder(fromRows: IndexSet, toIndex: Int) {
        guard let fromRow = fromRows.first,
              visibleRows.indices.contains(fromRow),
              let handler = winOutlineReorderHandler else {
            return
        }
        let moved = visibleRows[fromRow]
        let parentKey = moved.parent.map { key(for: $0) }
        // Visible-row indices of the dragged item's siblings, in order — these
        // map one-to-one to child indices under the shared parent.
        let siblingRows = visibleRows.indices.filter { idx in
            visibleRows[idx].parent.map { key(for: $0) } == parentKey
        }
        // The proposed child index is the count of siblings that sit strictly
        // above the flattened drop position.
        let targetChildIndex = siblingRows.filter { $0 < toIndex }.count
        handler(moved.item, moved.parent, targetChildIndex)
        reloadData()
    }

    private func rebuildVisibleRows() {
        visibleRows.removeAll()
        appendChildren(of: nil, level: 0)
    }

    private func appendChildren(of item: Any?, level: Int) {
        guard let outlineDataSource else {
            return
        }

        let count = outlineDataSource.outlineView(self, numberOfChildrenOfItem: item)
        guard count > 0 else {
            return
        }

        for index in 0..<count {
            let child = outlineDataSource.outlineView(self, child: index, ofItem: item)
            visibleRows.append(OutlineRow(item: child, level: level, parent: item))
            if outlineDataSource.outlineView(self, isItemExpandable: child),
               expandedItemKeys.contains(key(for: child)) {
                appendChildren(of: child, level: level + 1)
            }
        }
    }

    private func objectValue(for tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard visibleRows.indices.contains(row) else {
            return nil
        }

        let outlineRow = visibleRows[row]
        let value = outlineDataSource?.outlineView(self, objectValueFor: tableColumn, byItem: outlineRow.item)
            ?? String(describing: outlineRow.item)

        // Indentation and the disclosure triangle are drawn (see the hooks
        // below), so the first column keeps plain text — unless a caller opts
        // back into legacy text markers via `showsDisclosureText` with the
        // drawn path disabled.
        guard showsDisclosureText, !winUsesViewBasedCells,
              tableColumns.first === tableColumn else {
            return value
        }

        let indent = String(repeating: "  ", count: outlineRow.level)
        let marker: String
        if outlineDataSource?.outlineView(self, isItemExpandable: outlineRow.item) == true {
            marker = isItemExpanded(outlineRow.item) ? "- " : "+ "
        } else {
            marker = "  "
        }

        return "\(indent)\(marker)\(value)"
    }

    private func key(for item: Any) -> String {
        String(describing: item)
    }

    // MARK: Drawn disclosure triangle + indentation

    /// The x of the disclosure triangle's left edge for a row's first column.
    private func disclosureX(forRow row: Int, cellRect: NSRect) -> CGFloat {
        cellRect.minX + 4 + CGFloat(visibleRows[row].level) * indentationPerLevel
    }

    /// First-column content is inset by the level's indentation plus the
    /// disclosure-triangle column.
    open override func winDrawnLeadingInset(forRow row: Int, column: Int) -> CGFloat {
        guard column == 0, visibleRows.indices.contains(row) else {
            return 0
        }
        return CGFloat(visibleRows[row].level) * indentationPerLevel + disclosureWidth
    }

    /// Draws the disclosure triangle for expandable items on the first column.
    open override func winDrawnDrawDecoration(forRow row: Int, column: Int, cellRect: NSRect) {
        guard column == 0, visibleRows.indices.contains(row),
              isItemExpandable(visibleRows[row].item) else {
            return
        }
        let x = disclosureX(forRow: row, cellRect: cellRect)
        let cy = cellRect.midY
        let path = NSBezierPath()
        if isItemExpanded(visibleRows[row].item) {
            // Pointing down (expanded).
            path.move(to: NSMakePoint(x, cy - 2))
            path.line(to: NSMakePoint(x + 8, cy - 2))
            path.line(to: NSMakePoint(x + 4, cy + 4))
        } else {
            // Pointing right (collapsed).
            path.move(to: NSMakePoint(x, cy - 4))
            path.line(to: NSMakePoint(x + 6, cy))
            path.line(to: NSMakePoint(x, cy + 4))
        }
        path.close()
        NSColor(white: 0.35, alpha: 1).setFill()
        path.fill()
    }

    /// A click on the disclosure triangle toggles the item instead of selecting.
    open override func winDrawnHandleDecorationClick(forRow row: Int, column: Int, at point: NSPoint) -> Bool {
        guard column == 0, visibleRows.indices.contains(row),
              isItemExpandable(visibleRows[row].item) else {
            return false
        }
        let cellRect = winCellRect(row: row, column: 0)
        let x = disclosureX(forRow: row, cellRect: cellRect)
        if point.x >= x - 3, point.x <= x + 12 {
            toggleItem(visibleRows[row].item)
            return true
        }
        return false
    }
}
