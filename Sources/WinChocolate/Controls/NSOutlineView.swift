/// Data source for an AppKit-shaped outline view.
///
/// Refines `NSTableViewDataSource` so an outline source can be assigned to
/// AppKit's real `outlineView.dataSource` property (Apple retypes the
/// inherited property covariantly via the ObjC runtime; Swift-only code gets
/// the same assignment shape through this refinement, with defaults below so
/// outline sources never implement the flat-table API — the outline's
/// internal adapter supplies it).
@MainActor
public protocol NSOutlineViewDataSource: NSTableViewDataSource {
    /// Returns the number of children below an item. `nil` means the root.
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int

    /// Returns the child at an index below an item. `nil` means the root.
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any

    /// Returns whether an item can expand.
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool

    /// Returns a display value for a column and item.
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any?

    /// Returns the object supplying an item's pasteboard representation for a
    /// drag, or `nil` if the item is not draggable — AppKit's
    /// `outlineView(_:pasteboardWriterForItem:)`. A non-`nil` writer (plus a
    /// `.move` local mask via `setDraggingSourceOperationMask(_:forLocal:)`)
    /// enables drag-to-reorder.
    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> Any?

    /// Accepts a drop targeting a parent item at a child index, returning
    /// whether it was consumed — AppKit's exact
    /// `outlineView(_:acceptDrop:item:childIndex:)`. Reorder drops report the
    /// proposed parent (`nil` = root) and the model child index; read the
    /// dragged item's representation from `info.draggingPasteboard`.
    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool
}

public extension NSOutlineViewDataSource {
    /// Outline sources never implement the flat-table row count — the
    /// outline's internal adapter supplies it from the flattened tree.
    func numberOfRows(in tableView: NSTableView) -> Int {
        0
    }

    /// Default object value uses the item description.
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        item.map { String(describing: $0) }
    }

    /// Default: items are not draggable.
    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> Any? {
        nil
    }

    /// Default: the outline refuses drops.
    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
        false
    }
}

/// Delegate that can vend per-column cell views for an outline's items,
/// matching AppKit's `NSOutlineViewDelegate` view-based hook.
///
/// Refines `NSTableViewDelegate` so an outline delegate can be assigned to
/// AppKit's real `outlineView.delegate` property (see the data-source note);
/// the table-level callbacks all have defaults, so pure-AppKit outline
/// delegates conform unchanged.
@MainActor
public protocol NSOutlineViewDelegate: NSTableViewDelegate {
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

        /// Bridges a row-level reorder drop to the outline data source's
        /// item-based `outlineView(_:acceptDrop:item:childIndex:)`.
        nonisolated func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
            guard let owner else {
                return false
            }
            let rowList = info.draggingPasteboard.string(forType: .string) ?? ""
            let fromRows = IndexSet(rowList.split(separator: ",").compactMap { Int($0) })
            return winMainActor {
                owner.winAcceptOutlineReorderDrop(fromRows: fromRows, toIndex: row, info: info)
            }
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

    /// Object that provides outline children and values. Not API (18.12):
    /// applications assign AppKit's real `dataSource` property, which routes
    /// here; `package` for framework internals and the suite.
    package weak var outlineDataSource: NSOutlineViewDataSource? {
        didSet {
            reloadData()
        }
    }

    /// Object that can vend per-column cell views for items. Not API
    /// (18.12): applications assign AppKit's real `delegate` property.
    package weak var outlineDelegate: NSOutlineViewDelegate? {
        didSet {
            reloadData()
        }
    }

    /// AppKit's real property shape: an outline's `dataSource` is its
    /// outline data source (Apple retypes the inherited property; here the
    /// outline protocol refines the table one so the same assignment
    /// compiles). The flattening adapter is interposed internally through
    /// `winEffectiveDataSource`, never through this property.
    open override var dataSource: NSTableViewDataSource? {
        get { outlineDataSource }
        set { outlineDataSource = newValue as? NSOutlineViewDataSource }
    }

    /// AppKit's real property shape for the outline delegate (see
    /// `dataSource`).
    open override var delegate: NSTableViewDelegate? {
        get { outlineDelegate }
        set { outlineDelegate = newValue as? NSOutlineViewDelegate }
    }

    /// The table machinery reads the flattening adapter, whatever the app
    /// assigned to `dataSource`/`delegate`.
    override var winEffectiveDataSource: NSTableViewDataSource? { outlineAdapter }
    override var winEffectiveDelegate: NSTableViewDelegate? { outlineAdapter }

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
        // The adapter (also the table delegate) bridges the drawn table's
        // flat row requests to the outline's item hooks; it is interposed
        // through winEffectiveDataSource/Delegate, leaving the public
        // `dataSource`/`delegate` with AppKit's outline semantics.
        outlineAdapter.owner = self
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

    /// Expands a collapsed item, or collapses an expanded item. Not API
    /// (18.7): Apple has only expandItem(_:)/collapseItem(_:) — package for
    /// the disclosure-click machinery and the suite.
    package func toggleItem(_ item: Any?) {
        guard let item,
              isExpandable(item) else {
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
    open func isExpandable(_ item: Any?) -> Bool {
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
    /// Framework-internal reorder hook. Not API (18.8): applications use
    /// AppKit's recipe — `setDraggingSourceOperationMask(.move, forLocal:
    /// true)`, `outlineView(_:pasteboardWriterForItem:)`, and
    /// `outlineView(_:acceptDrop:item:childIndex:)`.
    package var winOutlineReorderHandler: ((_ movedItem: Any, _ parent: Any?, _ childIndex: Int) -> Void)? {
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

    /// Maps a row-level reorder drop to the outline's item terms: the moved
    /// item, its proposed parent (`nil` = root), and the model child index.
    /// Returns `nil` for invalid drops (out of range, into own subtree).
    private func winMapReorderDrop(fromRows: IndexSet, toIndex: Int) -> (moved: Any, parent: Any?, childIndex: Int)? {
        guard let fromRow = fromRows.first,
              visibleRows.indices.contains(fromRow) else {
            return nil
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
            if isExpandable(above.item), isItemExpanded(above.item) {
                targetParent = above.item
            } else {
                targetParent = above.parent
            }
        }

        // Never move an item into itself or its own subtree.
        if let targetParent, isItem(targetParent, descendantOfOrEqualTo: moved.item) {
            return nil
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
        return (moved.item, targetParent, targetChildIndex)
    }

    private func handleOutlineReorder(fromRows: IndexSet, toIndex: Int) {
        guard let handler = winOutlineReorderHandler,
              let target = winMapReorderDrop(fromRows: fromRows, toIndex: toIndex) else {
            return
        }
        handler(target.moved, target.parent, target.childIndex)
        reloadData()
    }

    /// Accepts a row-level reorder drop through AppKit's outline data-source
    /// pathway: maps the drop to item terms and forwards to
    /// `outlineView(_:acceptDrop:item:childIndex:)`.
    package func winAcceptOutlineReorderDrop(fromRows: IndexSet, toIndex: Int, info: NSDraggingInfo) -> Bool {
        guard let outlineDataSource,
              let target = winMapReorderDrop(fromRows: fromRows, toIndex: toIndex) else {
            return false
        }
        // The pasteboard handed to the data source carries the app's OWN
        // representation of the dragged item (its `pasteboardWriterForItem`
        // output), exactly what an AppKit acceptDrop expects to read back.
        let writer = winMainActor { outlineDataSource.outlineView(self, pasteboardWriterForItem: target.moved) }
        let itemText = (writer as? String) ?? String(describing: target.moved)
        let itemInfo = WinDraggingInfo(
            content: NativeDropContent(text: itemText, filePaths: []),
            location: info.draggingLocation
        )
        let accepted = winMainActor { outlineDataSource.outlineView(self, acceptDrop: itemInfo, item: target.parent, childIndex: target.childIndex) }
        if accepted {
            reloadData()
        }
        return accepted
    }

    /// Reorder drags also arm via AppKit's outline recipe: a `.move` local
    /// mask plus a data-source `pasteboardWriterForItem` for the dragged row.
    package override func winReorderDragEnabled(forRow row: Int) -> Bool {
        if super.winReorderDragEnabled(forRow: row) {
            return true
        }
        guard winLocalDragOperationMask.contains(.move),
              visibleRows.indices.contains(row),
              let outlineDataSource else {
            return false
        }
        return winMainActor { outlineDataSource.outlineView(self, pasteboardWriterForItem: visibleRows[row].item) } != nil
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
              isExpandable(visibleRows[row].item) else {
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
              isExpandable(visibleRows[row].item) else {
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
