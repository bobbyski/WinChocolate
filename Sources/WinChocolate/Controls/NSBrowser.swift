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

    /// Returns a custom title for a column, or `nil` to use the default.
    func browser(_ browser: NSBrowser, titleOfColumn column: Int) -> String?

    /// Returns a leading cell image for an item, or `nil` to use the built-in
    /// folder (branch) / document (leaf) glyph. Matches an `NSBrowserCell`
    /// carrying an image.
    func browser(_ browser: NSBrowser, imageForItem item: Any?) -> NSImage?
}

public extension NSBrowserDelegate {
    /// Default leaf behavior treats items with no children as leaves.
    func browser(_ browser: NSBrowser, isLeafItem item: Any?) -> Bool {
        browser.delegate?.browser(browser, numberOfChildrenOfItem: item) == 0
    }

    /// Default: no delegate-provided column title.
    func browser(_ browser: NSBrowser, titleOfColumn column: Int) -> String? {
        nil
    }

    /// Default: no per-cell image (the built-in folder/document glyph is used).
    func browser(_ browser: NSBrowser, imageForItem item: Any?) -> NSImage? {
        nil
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

    /// A browser column's list, drawn by the framework table so each row can
    /// paint an `NSBrowserCell`-style leading icon (a folder for branches, a
    /// document for leaves) plus a trailing branch chevron on non-leaf rows.
    private final class BrowserColumnTableView: NSTableView {
        weak var browser: NSBrowser?
        let columnIndex: Int

        /// Leading space reserved for the cell icon (matches `iconInset`).
        private let iconInset: CGFloat = 20

        init(browser: NSBrowser, columnIndex: Int, frame: NSRect) {
            self.browser = browser
            self.columnIndex = columnIndex
            super.init(frame: frame)
            // Always draw via the framework table so the icon + chevron can be
            // painted per row.
            winUsesViewBasedCells = true
        }

        /// Reserve leading space for the cell icon so the drawn title clears it.
        override func winDrawnLeadingInset(forRow row: Int, column: Int) -> CGFloat {
            browser?.showsCellIcons == true ? iconInset : 0
        }

        /// Reserve trailing space so a long title is clipped short of the branch
        /// chevron rather than drawing under it.
        override func winDrawnTrailingInset(forRow row: Int, column: Int) -> CGFloat {
            18
        }

        /// Draws the leading icon (folder/document) and the trailing branch
        /// chevron, matching AppKit's `NSBrowserCell` decoration.
        override func winDrawnDrawDecoration(forRow row: Int, column: Int, cellRect: NSRect) {
            guard let browser,
                  let item = browser.item(atRow: row, inColumn: columnIndex) else {
                return
            }
            let isLeaf = browser.delegate?.browser(browser, isLeafItem: item) ?? true
            if browser.showsCellIcons {
                let image = browser.delegate?.browser(browser, imageForItem: item)
                drawCellIcon(image: image, isLeaf: isLeaf, in: cellRect)
            }
            if !isLeaf {
                drawBranchChevron(in: cellRect)
            }
        }

        /// A right-pointing triangle at the trailing edge (branch mark).
        private func drawBranchChevron(in cellRect: NSRect) {
            let x = cellRect.maxX - 12
            let cy = cellRect.midY
            let path = NSBezierPath()
            path.move(to: NSMakePoint(x, cy - 4))
            path.line(to: NSMakePoint(x + 5, cy))
            path.line(to: NSMakePoint(x, cy + 4))
            path.close()
            NSColor(white: 0.45, alpha: 1).setFill()
            path.fill()
        }

        /// Draws the leading cell icon: a delegate-provided image when present,
        /// otherwise a simple, original folder (branch) or document (leaf) glyph
        /// drawn from rects/lines so it never collides with the chevron's
        /// triangle in fill-shape tests.
        private func drawCellIcon(image: NSImage?, isLeaf: Bool, in cellRect: NSRect) {
            let cy = cellRect.midY
            let left = cellRect.minX + 4
            if let image {
                image.draw(in: NSRect(x: left, y: cy - 7, width: 14, height: 14))
                return
            }
            if isLeaf {
                // Document: a page with two text lines.
                let page = NSRect(x: left + 1, y: cy - 6, width: 11, height: 13)
                NSColor.white.setFill()
                NSBezierPath(rect: page).fill()
                NSColor(white: 0.55, alpha: 1).setStroke()
                let border = NSBezierPath(rect: page)
                border.lineWidth = 1
                border.stroke()
                NSColor(white: 0.7, alpha: 1).setStroke()
                for dy in [3, 7] {
                    let line = NSBezierPath()
                    line.move(to: NSMakePoint(page.minX + 2, page.minY + CGFloat(dy)))
                    line.line(to: NSMakePoint(page.maxX - 2, page.minY + CGFloat(dy)))
                    line.stroke()
                }
            } else {
                // Folder: a body with a small tab on the top-left.
                let manila = NSColor(calibratedRed: 0.90, green: 0.78, blue: 0.44, alpha: 1)
                manila.setFill()
                NSBezierPath(rect: NSRect(x: left, y: cy + 3, width: 6, height: 2)).fill()
                NSBezierPath(rect: NSRect(x: left, y: cy - 5, width: 14, height: 9)).fill()
                NSColor(calibratedRed: 0.72, green: 0.60, blue: 0.28, alpha: 1).setStroke()
                let outline = NSBezierPath(rect: NSRect(x: left, y: cy - 5, width: 14, height: 9))
                outline.lineWidth = 1
                outline.stroke()
            }
        }
    }

    private final class BrowserColumn {
        let scrollView: NSScrollView
        let tableView: BrowserColumnTableView
        let dataSource: BrowserColumnDataSource
        let titleLabel: NSTextField

        init(browser: NSBrowser, column: Int, frame: NSRect) {
            scrollView = NSScrollView(frame: frame)
            tableView = BrowserColumnTableView(browser: browser, columnIndex: column,
                                               frame: NSRect(origin: NSZeroPoint, size: frame.size))
            dataSource = BrowserColumnDataSource(browser: browser, column: column)
            titleLabel = NSTextField(string: "", frame: .zero)
            titleLabel.isBordered = false
            titleLabel.alignment = .center
            titleLabel.font = NSFont.boldSystemFont(ofSize: 11)
            // The title strip follows the appearance so its text stays
            // legible (light band on light, header tone on dark).
            titleLabel.backgroundColor = NSApplication.shared.effectiveAppearance.winIsDark
                ? NSColor(white: 0.24, alpha: 1)
                : NSColor(white: 0.92, alpha: 1)
        }
    }

    private var columns: [BrowserColumn] = []
    private var columnItems: [[Any]] = []
    private var selectedRowsByColumn: [Int: Int] = [:]
    private var isUpdatingTableSelection = false
    private var customColumnTitles: [Int: String] = [:]

    /// Whether each column shows a title bar (default `true`).
    open var isTitled: Bool = true {
        didSet {
            tile()
        }
    }

    /// Whether browser cells draw a leading icon (folder for branches, document
    /// for leaves), matching Finder's `NSBrowserCell` look (default `true`).
    open var showsCellIcons: Bool = true {
        didSet {
            guard oldValue != showsCellIcons else { return }
            for column in columns {
                column.tableView.needsDisplay = true
            }
        }
    }

    /// The height of a column's title bar when `isTitled`.
    open var columnTitleHeight: CGFloat = 20

    /// Sets a custom title for a column (overrides the default).
    open func setTitle(_ title: String, ofColumn column: Int) {
        customColumnTitles[column] = title
        tile()
    }

    /// The title shown for a column: a custom title, else the delegate's, else
    /// the display name of the item that produced the column (empty for col 0).
    open func title(ofColumn column: Int) -> String {
        if let custom = customColumnTitles[column] {
            return custom
        }
        if let delegateTitle = delegate?.browser(self, titleOfColumn: column) {
            return delegateTitle
        }
        guard column > 0, let item = selectedItem(inColumn: column - 1) else {
            return column == 0 ? "" : ""
        }
        return displayString(for: item)
    }

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

    /// The separator used by `path()`/`setPath(_:)`.
    open var pathSeparator: String = "/"

    /// The rightmost column that currently has a selection, or `-1`.
    open var selectedColumn: Int {
        selectedRowsByColumn.keys.max() ?? -1
    }

    /// The display string for an item (delegate value, else its description).
    private func displayString(for item: Any?) -> String {
        if let value = delegate?.browser(self, objectValueForItem: item) {
            return String(describing: value)
        }
        return item.map { String(describing: $0) } ?? ""
    }

    /// The `pathSeparator`-joined path of selected items through the columns,
    /// e.g. `/Application/Controls/NSButton`.
    open func path() -> String {
        var components: [String] = []
        var column = 0
        while let item = selectedItem(inColumn: column) {
            components.append(displayString(for: item))
            column += 1
        }
        return pathSeparator + components.joined(separator: pathSeparator)
    }

    /// Selects columns to match a `pathSeparator`-separated path, returning
    /// whether the whole path resolved.
    @discardableResult
    open func setPath(_ path: String) -> Bool {
        let separator = Character(pathSeparator)
        let components = path.split(separator: separator).map(String.init)
        reloadColumn(0)
        var column = 0
        for component in components {
            guard columnItems.indices.contains(column),
                  let row = columnItems[column].firstIndex(where: { displayString(for: $0) == component }) else {
                return false
            }
            selectRow(row, inColumn: column)
            column += 1
        }
        return true
    }

    /// Creates a browser.
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        reloadColumn(0)
    }

    /// Creates a native host view for the composed columns.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createView(frame: frame, parent: parent)
    }

    /// Lays out visible columns (title bar above each column when titled).
    open func tile() {
        let visibleCount = max(1, columns.count)
        let width = max(1, min(columnWidth, frame.size.width / CGFloat(visibleCount)))
        let titleHeight = isTitled ? columnTitleHeight : 0
        for (index, column) in columns.enumerated() {
            let x = CGFloat(index) * width
            column.titleLabel.isHidden = !isTitled
            if isTitled {
                column.titleLabel.stringValue = title(ofColumn: index)
                column.titleLabel.frame = NSMakeRect(x, 0, width, titleHeight)
            }
            let scrollFrame = NSMakeRect(x, titleHeight, width, max(1, frame.size.height - titleHeight))
            column.scrollView.frame = scrollFrame
            column.tableView.frame = NSRect(origin: NSZeroPoint, size: scrollFrame.size)
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
            let removed = columns.removeLast()
            removed.scrollView.removeFromSuperview()
            removed.titleLabel.removeFromSuperview()
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
        addSubview(column.titleLabel)
        addSubview(column.scrollView)
    }

    private func trimColumns(after column: Int) {
        while columns.count > column + 1 {
            let removed = columns.removeLast()
            removed.scrollView.removeFromSuperview()
            removed.titleLabel.removeFromSuperview()
        }
        while columnItems.count > column + 1 {
            columnItems.removeLast()
        }
        selectedRowsByColumn = selectedRowsByColumn.filter { $0.key <= column }
        numberOfVisibleColumns = columns.count
        tile()
    }
}
