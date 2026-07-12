import Foundation

/// AppKit-shaped column browser delegate (item-based, like `NSOutlineView`).
public protocol NSBrowserDelegate: AnyObject {
    func browser(_ browser: NSBrowser, numberOfChildrenOfItem item: Any?) -> Int
    func browser(_ browser: NSBrowser, child index: Int, ofItem item: Any?) -> Any
    func browser(_ browser: NSBrowser, isLeafItem item: Any?) -> Bool
}

/// AppKit-shaped `NSBrowser`: Miller-column navigation. No single GTK peer — a
/// composed control: a fixed row of single-column `NSTableView`s. Selecting a
/// row in column *c* populates column *c+1* with that item's children. Built
/// entirely from existing controls, so it needs no backend surface of its own.
public final class NSBrowser: NSView {

    /// The maximum number of visible columns.
    public var maxVisibleColumns = 3

    /// The width of each column (set before `loadColumnZero()`).
    public var columnWidth: Double = 150

    public weak var delegate: NSBrowserDelegate? {
        didSet { if !columns.isEmpty { reloadAll() } }
    }

    /// Fired when the selection (and thus `path()`) changes.
    public var onAction: ((NSBrowser) -> Void)?

    private var columns: [NSTableView] = []
    private var columnSources: [BrowserColumnSource] = []
    /// The selected row per column (−1 = nothing selected in that column).
    private var selectionPath: [Int] = []

    /// Builds the columns (idempotent) and shows the root in column zero.
    public func loadColumnZero() {
        setupColumnsIfNeeded()
        selectionPath = Array(repeating: -1, count: columns.count)
        reloadAll()
    }

    /// Sets a column's header title (deeper columns otherwise auto-title with
    /// their selected parent item).
    public func setTitle(_ title: String, ofColumn column: Int) {
        guard column < columns.count, let col = columns[column].tableColumns.first else { return }
        col.title = title
    }

    /// The selected path as "/A/B/C" of item descriptions.
    public func path() -> String {
        var components: [String] = []
        var parent: Any? = nil
        for column in 0..<columns.count {
            let selected = selectionPath[column]
            guard selected >= 0, let delegate else { break }
            let item = delegate.browser(self, child: selected, ofItem: parent)
            components.append(String(describing: item))
            parent = item
        }
        return "/" + components.joined(separator: "/")
    }

    /// Selects `row` in `column` (as if the user clicked it): reveals that
    /// item's children in the next column and updates `path()`.
    public func selectRow(_ row: Int, inColumn column: Int) {
        guard column < columns.count else { return }
        columns[column].selectRow(at: row)
        columnSelectionChanged(column, row: row)
    }

    /// The selected row in `column` (−1 if none).
    public func selectedRow(inColumn column: Int) -> Int {
        column < selectionPath.count ? selectionPath[column] : -1
    }

    // MARK: Column data (queried by each column's data source)

    /// The number of rows shown in `column` (its parent item's child count).
    public func numberOfRows(inColumn column: Int) -> Int {
        guard let delegate else { return 0 }
        let parent = resolvedParent(forColumn: column)
        guard parent.valid else { return 0 }
        return delegate.browser(self, numberOfChildrenOfItem: parent.item)
    }

    func item(atRow row: Int, inColumn column: Int) -> Any? {
        guard let delegate else { return nil }
        let parent = resolvedParent(forColumn: column)
        guard parent.valid else { return nil }
        return delegate.browser(self, child: row, ofItem: parent.item)
    }

    // MARK: Internals

    private func setupColumnsIfNeeded() {
        guard columns.isEmpty else { return }
        // Initialize before creating tables: assigning a table's dataSource
        // triggers reloadData → resolvedParent, which reads selectionPath.
        selectionPath = Array(repeating: -1, count: maxVisibleColumns)
        for column in 0..<maxVisibleColumns {
            let table = NSTableView(frame: NSMakeRect(Double(column) * columnWidth, 0, columnWidth, frame.height))
            let col = NSTableColumn(identifier: "browser\(column)")
            col.title = ""
            table.addTableColumn(col)
            let source = BrowserColumnSource(browser: self, column: column)
            table.dataSource = source
            table.onSelectionChange = { [weak self] tv in
                self?.columnSelectionChanged(column, row: tv.selectedRow)
            }
            addSubview(table)
            columns.append(table)
            columnSources.append(source)
        }
        selectionPath = Array(repeating: -1, count: maxVisibleColumns)
    }

    private func columnSelectionChanged(_ column: Int, row: Int) {
        guard column < selectionPath.count else { return }
        selectionPath[column] = row
        for deeper in (column + 1)..<selectionPath.count { selectionPath[deeper] = -1 }
        // Auto-title and repopulate the next column with the selected item.
        if column + 1 < columns.count {
            let name = item(atRow: row, inColumn: column).map { String(describing: $0) } ?? ""
            columns[column + 1].tableColumns.first?.title = name
        }
        for deeper in (column + 1)..<columns.count { columns[deeper].reloadData() }
        onAction?(self)
    }

    private func reloadAll() {
        for table in columns { table.reloadData() }
    }

    /// The parent item whose children column `column` displays. `valid` is
    /// false if the path to that column isn't fully selected (empty column).
    private func resolvedParent(forColumn column: Int) -> (valid: Bool, item: Any?) {
        if column == 0 { return (true, nil) }
        var item: Any? = nil
        for level in 0..<column {
            guard level < selectionPath.count else { return (false, nil) }
            let selected = selectionPath[level]
            guard selected >= 0, let delegate else { return (false, nil) }
            item = delegate.browser(self, child: selected, ofItem: item)
        }
        return (true, item)
    }
}

/// One browser column's data source — forwards to the browser by column index.
final class BrowserColumnSource: NSTableViewDataSource {
    weak var browser: NSBrowser?
    let column: Int
    init(browser: NSBrowser, column: Int) {
        self.browser = browser
        self.column = column
    }
    func numberOfRows(in tableView: NSTableView) -> Int {
        browser?.numberOfRows(inColumn: column) ?? 0
    }
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        browser?.item(atRow: row, inColumn: column)
    }
}
