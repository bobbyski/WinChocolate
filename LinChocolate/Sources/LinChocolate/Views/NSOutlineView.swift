import Foundation

/// AppKit-shaped outline (tree table) data source: children per item, item
/// expandability, and per-cell values. `item == nil` means the root.
public protocol NSOutlineViewDataSource: AnyObject {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any?
}

/// AppKit-shaped tree table (GtkColumnView over a GtkTreeListModel). Column 0
/// carries the native expand arrows. The backend addresses items by index
/// path ("0.2"); this class resolves paths back to data-source items.
public final class NSOutlineView: NSView {

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
