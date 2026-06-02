/// Delegate/data source for an AppKit-shaped browser.
public protocol NSBrowserDelegate: AnyObject {
    /// Returns the number of children below an item. `nil` is the root column.
    func browser(_ browser: NSBrowser, numberOfChildrenOfItem item: Any?) -> Int

    /// Returns a child item below an item. `nil` is the root column.
    func browser(_ browser: NSBrowser, child index: Int, ofItem item: Any?) -> Any

    /// Returns whether an item is a leaf.
    func browser(_ browser: NSBrowser, isLeafItem item: Any?) -> Bool

    /// Returns the value shown for an item.
    func browser(_ browser: NSBrowser, objectValueForItem item: Any?) -> Any?
}

public extension NSBrowserDelegate {
    /// Default leaf behavior treats items with no children as leaves.
    func browser(_ browser: NSBrowser, isLeafItem item: Any?) -> Bool {
        browser.delegate?.browser(browser, numberOfChildrenOfItem: item) == 0
    }

    /// Default display value uses item description.
    func browser(_ browser: NSBrowser, objectValueForItem item: Any?) -> Any? {
        item.map { String(describing: $0) }
    }
}

/// A multi-column AppKit browser.
///
/// This first slice composes `NSTableView` columns inside scroll views. It keeps
/// the Mac-style item hierarchy API while the backend remains ordinary native
/// child controls.
open class NSBrowser: NSControl {
    private final class BrowserColumnDataSource: NSTableViewDataSource {
        weak var browser: NSBrowser?
        let column: Int

        init(browser: NSBrowser, column: Int) {
            self.browser = browser
            self.column = column
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            browser?.items(inColumn: column).count ?? 0
        }

        func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
            guard let browser,
                  let item = browser.item(atRow: row, inColumn: column) else {
                return nil
            }

            return browser.delegate?.browser(browser, objectValueForItem: item)
                ?? String(describing: item)
        }
    }

    private final class BrowserColumn {
        let scrollView: NSScrollView
        let tableView: NSTableView
        let dataSource: BrowserColumnDataSource

        init(browser: NSBrowser, column: Int, frame: NSRect) {
            scrollView = NSScrollView(frame: frame)
            tableView = NSTableView(frame: NSRect(origin: NSZeroPoint, size: frame.size))
            dataSource = BrowserColumnDataSource(browser: browser, column: column)
        }
    }

    private var columns: [BrowserColumn] = []
    private var columnItems: [[Any]] = []
    private var selectedRowsByColumn: [Int: Int] = [:]
    private var isUpdatingTableSelection = false

    /// Object that provides browser items.
    open weak var delegate: NSBrowserDelegate? {
        didSet {
            reloadColumn(0)
        }
    }

    /// Number of visible browser columns.
    open private(set) var numberOfVisibleColumns: Int = 1

    /// Width assigned to each visible column.
    open var columnWidth: CGFloat = 160 {
        didSet {
            tile()
        }
    }

    /// Whether leaf rows may be selected.
    open var allowsBranchSelection: Bool = true

    /// Whether branch rows may be selected.
    open var allowsEmptySelection: Bool = true

    /// Creates a browser.
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        reloadColumn(0)
    }

    /// Creates a native host view for the composed columns.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createView(frame: frame, parent: parent)
    }

    /// Lays out visible columns.
    open func tile() {
        let visibleCount = max(1, columns.count)
        let width = max(1, min(columnWidth, frame.size.width / CGFloat(visibleCount)))
        for (index, column) in columns.enumerated() {
            let columnFrame = NSMakeRect(CGFloat(index) * width, 0, width, frame.size.height)
            column.scrollView.frame = columnFrame
            column.tableView.frame = NSRect(origin: NSZeroPoint, size: columnFrame.size)
            column.scrollView.tile()
        }
    }

    /// Reloads all visible columns.
    open func loadColumnZero() {
        reloadColumn(0)
    }

    /// Reloads a column and drops columns to its right.
    open func reloadColumn(_ column: Int) {
        guard column >= 0 else {
            return
        }

        while columns.count > column {
            columns.removeLast().scrollView.removeFromSuperview()
        }
        while columnItems.count > column {
            columnItems.removeLast()
        }
        selectedRowsByColumn = selectedRowsByColumn.filter { $0.key < column }

        let parentItem = selectedItem(inColumn: column - 1)
        columnItems.append(children(of: parentItem))
        addColumn(at: column)
        numberOfVisibleColumns = columns.count
        tile()
    }

    /// Selects a row in a column.
    open func selectRow(_ row: Int, inColumn column: Int) {
        guard columnItems.indices.contains(column),
              columnItems[column].indices.contains(row) else {
            if allowsEmptySelection {
                selectedRowsByColumn.removeValue(forKey: column)
            }
            return
        }

        selectedRowsByColumn[column] = row
        if columns[column].tableView.selectedRow != row {
            isUpdatingTableSelection = true
            columns[column].tableView.selectRowIndexes([row], byExtendingSelection: false)
            isUpdatingTableSelection = false
        }
        let item = columnItems[column][row]
        if delegate?.browser(self, isLeafItem: item) == false {
            reloadColumn(column + 1)
        } else {
            trimColumns(after: column)
        }
        sendAction()
    }

    /// Returns the selected row for a column, or `-1`.
    open func selectedRow(inColumn column: Int) -> Int {
        selectedRowsByColumn[column] ?? -1
    }

    /// Returns the selected item in a column.
    open func selectedItem(inColumn column: Int) -> Any? {
        guard column >= 0,
              let row = selectedRowsByColumn[column],
              columnItems.indices.contains(column),
              columnItems[column].indices.contains(row) else {
            return nil
        }

        return columnItems[column][row]
    }

    /// Returns an item at a row and column.
    open func item(atRow row: Int, inColumn column: Int) -> Any? {
        guard columnItems.indices.contains(column),
              columnItems[column].indices.contains(row) else {
            return nil
        }

        return columnItems[column][row]
    }

    /// Returns loaded items in a column.
    open func items(inColumn column: Int) -> [Any] {
        guard columnItems.indices.contains(column) else {
            return []
        }

        return columnItems[column]
    }

    private func children(of item: Any?) -> [Any] {
        let count = delegate?.browser(self, numberOfChildrenOfItem: item) ?? 0
        guard count > 0 else {
            return []
        }

        return (0..<count).map { index in
            delegate?.browser(self, child: index, ofItem: item) ?? ""
        }
    }

    private func addColumn(at index: Int) {
        let frame = NSMakeRect(CGFloat(index) * columnWidth, 0, columnWidth, self.frame.size.height)
        let column = BrowserColumn(browser: self, column: index, frame: frame)
        let titleColumn = NSTableColumn(identifier: "browser")
        titleColumn.title = ""
        titleColumn.width = columnWidth
        column.tableView.headerView = nil
        column.tableView.addTableColumn(titleColumn)
        column.tableView.dataSource = column.dataSource
        column.tableView.allowsEmptySelection = allowsEmptySelection
        column.tableView.onSelectionChanged = { [weak self, weak column] table in
            guard let self,
                  let column,
                  !self.isUpdatingTableSelection,
                  table.selectedRow >= 0 else {
                return
            }

            self.selectRow(table.selectedRow, inColumn: column.dataSource.column)
        }
        column.tableView.reloadData()
        column.scrollView.hasVerticalScroller = true
        column.scrollView.hasHorizontalScroller = false
        column.scrollView.documentView = column.tableView
        columns.append(column)
        addSubview(column.scrollView)
    }

    private func trimColumns(after column: Int) {
        while columns.count > column + 1 {
            columns.removeLast().scrollView.removeFromSuperview()
        }
        while columnItems.count > column + 1 {
            columnItems.removeLast()
        }
        selectedRowsByColumn = selectedRowsByColumn.filter { $0.key <= column }
        numberOfVisibleColumns = columns.count
        tile()
    }
}
