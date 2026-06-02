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
/// This first slice keeps AppKit's outline data-source shape and flattens the
/// visible tree into the existing table backend. It does not yet draw disclosure
/// triangles; indentation is represented in the first column text.
open class NSOutlineView: NSTableView {
    private struct OutlineRow {
        var item: Any
        var level: Int
    }

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
            visibleRows.append(OutlineRow(item: child, level: level))
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

        guard showsDisclosureText,
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
}
