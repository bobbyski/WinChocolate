import Foundation

/// AppKit-shaped outline (tree table) data source: children per item, item
/// expandability, and per-cell values. `item == nil` means the root.
public protocol NSOutlineViewDataSource: AnyObject {
    /// The number of children of `item` (nil = root).
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int
    /// The `index`-th child of `item` (nil = root).
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any
    /// Whether `item` can be expanded.
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool
    /// The value for `tableColumn` in the row representing `item`.
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any?
}

/// AppKit-shaped tree table (GtkColumnView over a GtkTreeListModel). Column 0
/// carries the native expand arrows. The backend addresses items by index
/// path ("0.2"); this class resolves paths back to data-source items.
open class NSOutlineView: NSControl {

    /// The outline delegate; selection changes post
    /// `outlineViewSelectionDidChange(_:)`, as on Apple.
    public weak var delegate: NSOutlineViewDelegate?

    /// The drag operations offered as a drag source (stored, as on the table).
    public func setDraggingSourceOperationMask(_ mask: NSDragOperation, forLocal isLocal: Bool) {
        draggingSourceMask = mask
    }

    var draggingSourceMask: NSDragOperation = []

    /// The columns, in display order.
    public private(set) var tableColumns: [NSTableColumn] = []

    /// Supplies the tree and cell values. Assigning reloads.
    public weak var dataSource: NSOutlineViewDataSource? {
        didSet { reloadData() }
    }

    /// The selected visible row (−1 when nothing is selected).
    public private(set) var selectedRow: Int = -1

    /// Called when the user changes the row selection.
    public var onSelectionChange: ((NSOutlineView) -> Void)?

    /// Creates an empty outline view.
    public required init(frame: NSRect) {
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createOutlineView(frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
        backend.setOutlineProviders(
            for: handle,
            childCount: { [weak self] path in
                guard let self, let dataSource = self.dataSource,
                      let item = self.item(atPath: path) else { return 0 }
                guard dataSource.outlineView(self, isItemExpandable: item) else { return 0 }
                return dataSource.outlineView(self, numberOfChildrenOfItem: item)
            },
            cellText: { [weak self] path, columnIndex in
                guard let self, let dataSource = self.dataSource,
                      columnIndex < self.tableColumns.count,
                      let item = self.item(atPath: path) else { return "" }
                let value = dataSource.outlineView(
                    self, objectValueFor: self.tableColumns[columnIndex], byItem: item)
                return value.map { String(describing: $0) } ?? ""
            }
        )
        backend.setSelectionChangeAction(for: handle) { [weak self] row in
            guard let self else { return }
            self.selectedRow = row             // sync silently
            self.onSelectionChange?(self)
            self.delegate?.outlineViewSelectionDidChange(Notification(name: Notification.Name("NSOutlineViewSelectionDidChangeNotification"), object: self))
            self.sendAction()
        }
    }

    /// Appends `column` (the first column shows the expand arrows).
    public func addTableColumn(_ column: NSTableColumn) {
        tableColumns.append(column)
        backend.addOutlineColumn(title: column.title, to: handle)
    }

    /// Re-queries the data source and re-renders.
    public func reloadData() {
        let roots = dataSource?.outlineView(self, numberOfChildrenOfItem: nil) ?? 0
        backend.setOutlineRootCount(roots, for: handle)
    }

    /// The item shown at visible row `row` (AppKit's `item(atRow:)`).
    public func item(atRow row: Int) -> Any? {
        guard let path = backend.outlineItemPath(atRow: row, for: handle) else { return nil }
        return item(atPath: path)
    }

    /// The visible row showing `item`, or −1 if it isn't visible (AppKit's
    /// `row(forItem:)`). Items compare by their string form (the demo's items
    /// are strings, matching AppKit's identity-by-value use here).
    public func row(forItem item: Any?) -> Int {
        guard let item else { return -1 }
        let key = String(describing: item)
        let count = backend.outlineVisibleRowCount(for: handle)
        for row in 0..<count where self.item(atRow: row).map({ String(describing: $0) }) == key {
            return row
        }
        return -1
    }

    /// Whether `item` can be expanded (defers to the data source).
    public func isExpandable(_ item: Any) -> Bool {
        dataSource?.outlineView(self, isItemExpandable: item) ?? false
    }

    /// Whether `item`'s row is currently expanded (AppKit's `isItemExpanded`).
    public func isItemExpanded(_ item: Any) -> Bool {
        let row = row(forItem: item)
        return row >= 0 && backend.outlineIsRowExpanded(atRow: row, for: handle)
    }

    /// Expands `item`'s row (AppKit's `expandItem(_:)`).
    public func expandItem(_ item: Any?) {
        let row = row(forItem: item)
        if row >= 0 { backend.setOutlineRowExpanded(true, atRow: row, for: handle) }
    }

    /// Collapses `item`'s row (AppKit's `collapseItem(_:)`).
    public func collapseItem(_ item: Any?) {
        let row = row(forItem: item)
        if row >= 0 { backend.setOutlineRowExpanded(false, atRow: row, for: handle) }
    }

    /// The indentation level of `item` (0 = root), AppKit's `level(forItem:)`.
    public func level(forItem item: Any?) -> Int {
        let row = row(forItem: item)
        return row >= 0 ? max(0, backend.outlineRowDepth(atRow: row, for: handle) - 1) : 0
    }

    /// Selects the given rows (single-selection: the first index).
    public func selectRowIndexes(_ indexes: IndexSet, byExtendingSelection extend: Bool) {
        if let first = indexes.first {
            selectedRow = first
            backend.selectOutlineRow(first, for: handle)
        }
    }

    /// Resolves an index path ("0.2") to a data-source item.
    private func item(atPath path: String) -> Any? {
        guard let dataSource else { return nil }
        var item: Any? = nil
        for part in path.split(separator: ".") {
            guard let index = Int(part),
                  index < dataSource.outlineView(self, numberOfChildrenOfItem: item) else { return nil }
            item = dataSource.outlineView(self, child: index, ofItem: item)
        }
        return item
    }
}


/// AppKit's outline delegate (the slice the demo drives).
public protocol NSOutlineViewDelegate: AnyObject {
    /// Posted after the user changes the row selection.
    func outlineViewSelectionDidChange(_ notification: Notification)
}

public extension NSOutlineViewDelegate {
    /// Default: no-op.
    func outlineViewSelectionDidChange(_ notification: Notification) {}
}
