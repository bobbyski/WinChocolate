/// Data source for an AppKit-shaped outline view.
@MainActor
public protocol NSOutlineViewDataSource: NSObjectProtocol {
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

/// Delegate that can vend per-column cell views for an outline's items,
/// matching AppKit's `NSOutlineViewDelegate` view-based hook.
@MainActor
public protocol NSOutlineViewDelegate: NSObjectProtocol {
    /// Returns a view to host for a column and item, or `nil` for drawn text.
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView?

    /// Returns a custom row height for an item, or a non-positive value for
    /// the outline's default height.
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat

    /// Tells the delegate the outline's selection changed.
    func outlineViewSelectionDidChange(_ notification: NSNotification)
}

public extension NSOutlineViewDelegate {
    /// Default: no hosted view (the outline draws text for the cell).
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        nil
    }

    /// Default: the outline's standard row height.
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        -1
    }

    /// Default no-op so delegates only implement the callbacks they need.
    func outlineViewSelectionDidChange(_ notification: NSNotification) {}
}

/// A tree-shaped table view.
///
/// Built on the framework-drawn table: the visible tree is flattened into the
/// table backend, and the outline draws a real **disclosure triangle** and
/// per-level indentation on its first column (via the drawn-cell hooks), with
/// clicks on the triangle expanding/collapsing the item.
open class NSOutlineView: NSTableView {
    /// An outline reports `AXOutline` with `AXOutlineRow` rows.
    open override var winReportsAsOutline: Bool { true }

    private struct OutlineRow {
        var item: Any
        var level: Int
        var parent: Any?
    }

    /// Horizontal space reserved for the disclosure triangle on the first
    /// column, ahead of the cell text.
    private let disclosureWidth: CGFloat = 14

    // The adapter's members are nonisolated: the protocols are @MainActor
    // (inferring @MainActor on this class), but everything it touches on
    // the owner is nonisolated control state, and every call happens on the
    // Win32 UI thread.
    private final class OutlineTableAdapter: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        nonisolated(unsafe) weak var owner: NSOutlineView?

        nonisolated override init() {}

        nonisolated func numberOfRows(in tableView: NSTableView) -> Int {
            owner?.visibleRows.count ?? 0
        }

        nonisolated func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
            owner?.objectValue(for: tableColumn, row: row)
        }

        /// Bridges the drawn table's per-cell view request to the outline
        /// delegate's item-based hook.
        nonisolated func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            owner?.hostedView(for: tableColumn, row: row)
        }

        /// Bridges the drawn table's row-height request to the outline
        /// delegate's item-based hook.
        nonisolated func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            owner?.hostedRowHeight(row: row) ?? -1
        }

        /// Forwards table selection changes as outline selection changes.
        nonisolated func tableViewSelectionDidChange(_ notification: NSNotification) {
            guard let owner else {
                return
            }

            winMainActor {
                owner.outlineDelegate?.outlineViewSelectionDidChange(
                    NSNotification(name: "NSOutlineViewSelectionDidChangeNotification", object: owner)
                )
            }
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

    /// Object that can vend per-column cell views for items (view-based outline).
    open weak var outlineDelegate: NSOutlineViewDelegate? {
        didSet {
            reloadData()
        }
    }

    /// Bridges a drawn-cell view request (column, row) to the outline delegate's
    /// item-based hook. Returns `nil` — drawn text — when no delegate view.
    func hostedView(for tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let outlineDelegate, visibleRows.indices.contains(row) else {
            return nil
        }
        let item = visibleRows[row].item
        return winMainActor { outlineDelegate.outlineView(self, viewFor: tableColumn, item: item) }
    }

    /// Bridges a drawn-row height request to the outline delegate's
    /// item-based hook. Non-positive means the default height.
    func hostedRowHeight(row: Int) -> CGFloat {
        guard let outlineDelegate, visibleRows.indices.contains(row) else {
            return -1
        }
        let item = visibleRows[row].item
        return winMainActor { outlineDelegate.outlineView(self, heightOfRowByItem: item) }
    }

    /// The column showing the disclosure hierarchy. Stored for AppKit shape;
    /// the drawn outline always disclosure-decorates its first column.
    open var outlineTableColumn: NSTableColumn?

    /// Expands an item, optionally expanding its whole subtree.
    open func expandItem(_ item: Any?, expandChildren: Bool) {
        expandItem(item)
        guard expandChildren, let item, let outlineDataSource else {
            return
        }

        let count = winMainActor { outlineDataSource.outlineView(self, numberOfChildrenOfItem: item) }
        for index in 0..<count {
            let child = winMainActor { outlineDataSource.outlineView(self, child: index, ofItem: item) }
            if winMainActor({ outlineDataSource.outlineView(self, isItemExpandable: child) }) {
                expandItem(child, expandChildren: true)
            } else {
                expandItem(child)
            }
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
        // The adapter is also the table delegate: it bridges per-cell view
        // requests to the outline delegate's item-based hook.
        delegate = outlineAdapter
        // Outlines always use the framework-drawn table so they can draw
        // disclosure triangles and indentation themselves.
        winUsesViewBasedCells = true
    }

    /// Reloads the visible outline rows.
    open override func reloadData() {
        // Selection in an outline is by item, not by row index: after an
        // expand/collapse the rows shift, so capture the selected items' keys
        // against the current rows, then restore the selection to wherever those
        // items now sit. Items whose parent collapsed out of view are no longer
        // present and are dropped, so the selection never lands on a different
        // item than the one the user picked.
        let selectedKeys = Set(selectedRowIndexes.compactMap { row -> String? in
            visibleRows.indices.contains(row) ? key(for: visibleRows[row].item) : nil
        })

        rebuildVisibleRows()
        dataSource = outlineAdapter
        super.reloadData()

        guard !selectedKeys.isEmpty else {
            return
        }
        let restored = Set(visibleRows.indices.filter { selectedKeys.contains(key(for: visibleRows[$0].item)) })
        if restored.isEmpty {
            deselectAll(nil)
        } else {
            selectRowIndexes(restored, byExtendingSelection: false)
        }
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

        return winMainActor { outlineDataSource?.outlineView(self, isItemExpandable: item) ?? false }
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

    // MARK: Drag reordering

    /// Set to enable drag-to-reorder of outline rows. On a drop, the outline
    /// reports the dragged item, the proposed target parent, and the child index
    /// under that parent (AppKit's `acceptDrop` shape); the handler moves the
    /// item in the backing model and the outline reloads.
    ///
    /// The target parent is derived from the row just above the drop, so drops
    /// can **reparent** (cross-level), not just reorder siblings: dropping right
    /// below an expanded branch inserts as that branch's first child; otherwise
    /// the drop joins the parent of the row above it. A drop that would move an
    /// item into itself or its own subtree is rejected.
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

        // Derive the target parent from the row just above the drop position.
        // Dropping directly under an expanded branch reparents into it; anything
        // else joins the parent of the row above (the root when at the top).
        let targetParent: Any?
        if toIndex <= 0 {
            targetParent = nil
        } else {
            let above = visibleRows[min(toIndex, visibleRows.count) - 1]
            if isItemExpandable(above.item), isItemExpanded(above.item) {
                targetParent = above.item
            } else {
                targetParent = above.parent
            }
        }

        // Never move an item into itself or its own subtree.
        if let targetParent, isItem(targetParent, descendantOfOrEqualTo: moved.item) {
            return
        }

        // The proposed child index is the count of the target parent's visible
        // direct children that sit strictly above the drop position. (All direct
        // children — expanded or collapsed — appear in `visibleRows`, so this is
        // the true model child index.)
        let parentKey = targetParent.map { key(for: $0) }
        let siblingRows = visibleRows.indices.filter { idx in
            visibleRows[idx].parent.map { key(for: $0) } == parentKey
        }
        let targetChildIndex = siblingRows.filter { $0 < toIndex }.count
        handler(moved.item, targetParent, targetChildIndex)
        reloadData()
    }

    /// Whether `candidate` is `ancestor` itself or sits within its subtree, by
    /// walking the visible parent chain up from `candidate`.
    private func isItem(_ candidate: Any, descendantOfOrEqualTo ancestor: Any) -> Bool {
        let ancestorKey = key(for: ancestor)
        var current: Any? = candidate
        while let node = current {
            if key(for: node) == ancestorKey {
                return true
            }
            let nodeKey = key(for: node)
            current = visibleRows.first { key(for: $0.item) == nodeKey }?.parent
        }
        return false
    }

    private func rebuildVisibleRows() {
        visibleRows.removeAll()
        appendChildren(of: nil, level: 0)
    }

    private func appendChildren(of item: Any?, level: Int) {
        guard let outlineDataSource else {
            return
        }

        let count = winMainActor { outlineDataSource.outlineView(self, numberOfChildrenOfItem: item) }
        guard count > 0 else {
            return
        }

        for index in 0..<count {
            let child = winMainActor { outlineDataSource.outlineView(self, child: index, ofItem: item) }
            visibleRows.append(OutlineRow(item: child, level: level, parent: item))
            if winMainActor({ outlineDataSource.outlineView(self, isItemExpandable: child) }),
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
        let value = winMainActor { outlineDataSource?.outlineView(self, objectValueFor: tableColumn, byItem: outlineRow.item) }
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
        if winMainActor({ outlineDataSource?.outlineView(self, isItemExpandable: outlineRow.item) }) == true {
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
