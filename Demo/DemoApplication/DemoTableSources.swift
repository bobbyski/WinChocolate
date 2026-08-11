// Part of the shared demo, split out of main.swift by topic.
//
// Only DECLARATIONS live here. main.swift is Swift's top-level-code file:
// its statements run in written order, and moving one here would turn it
// into a lazily-initialized global that never runs. Declarations have no
// such ordering, so they move freely.

#if canImport(LinChocolate)
import LinChocolate
#elseif canImport(WinChocolate)
import WinChocolate
#else
import AppKit
#endif

/// Data source for the showcase's framework-drawn (view-based) table (5.5).
final class DemoViewTableDataSource: NSObject, NSTableViewDataSource {
    var tasks = [
        "Review the pull request", "Ship the nightly build", "Write the release notes",
        "Triage the bug backlog", "Update the changelog", "Refresh the screenshots",
        "Tag the release", "Post the announcement", "Close the milestone", "Archive the branch",
    ]
    var done = Array(repeating: false, count: 10)
    var notes = [
        "high", "nightly", "draft", "backlog", "minor",
        "1.0", "signed", "blog", "v5", "cleanup",
    ]

    func numberOfRows(in tableView: NSTableView) -> Int {
        tasks.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        tableColumn?.identifier.rawValue == "note" ? notes[row] : tasks[row]
    }

    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        guard tableColumn?.identifier.rawValue == "note" else {
            return
        }
        notes[row] = object.map { String(describing: $0) } ?? ""
    }

    // MARK: Row reorder — AppKit's drag-and-drop data-source recipe
    // (a `.move` local mask + a pasteboard writer per row + acceptDrop).

    /// Reported after a reorder so the page can update its status line.
    var onReorder: (@MainActor (_ movedCount: Int, _ destination: Int) -> Void)?

    /// Apple declares this returning `NSPasteboardWriting?`, and the type matters: this is
    /// an `@objc` protocol with *optional* methods, so a signature that does not match the
    /// requirement is never exposed to Objective-C and AppKit simply never calls it —
    /// `responds(to: "tableView:pasteboardWriterForRow:")` is **false**. Declared
    /// `-> Any?` (as the chocolate frameworks' own protocol has it) the drag silently
    /// carried no data and every row snapped back, with no error anywhere.
    /// `NSString` is the writer here because Swift's `String` does not itself conform.
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        "\(row)" as NSString
    }

    /// Required by AppKit for a drop to be accepted at all: without a validate that
    /// returns a real operation, `acceptDrop` is never reached and the row snaps back.
    ///
    /// Reordering only ever means "between rows" (`.above`). AppKit proposes `.on`
    /// whenever the pointer is over a row's *body* — which is nearly the whole table — so
    /// rejecting `.on` outright left only the hairline gap between rows as a valid target
    /// and the row snapped back almost everywhere. Retarget `.on` to the nearest gap with
    /// `setDropRow(_:dropOperation:)` instead: that is the standard reorder recipe, and it
    /// makes the whole table a drop target while still only ever inserting between rows.
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int,
                   proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if dropOperation == .on {
            tableView.setDropRow(row, dropOperation: .above)
        }

        return .move
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row toIndex: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard dropOperation == .above else {
            return false
        }

        // One pasteboard *item* per dragged row — that is what a writer-per-row produces.
        // This used to read `draggingPasteboard.string(forType:)` and split it on commas,
        // which is a single-string format: on AppKit that call returns only the *first*
        // item, so a multi-row drag silently moved just one row.
        let sortedRows = (info.draggingPasteboard.pasteboardItems ?? [])
            .compactMap { Int($0.string(forType: .string) ?? "") }
            .sorted()
        guard !sortedRows.isEmpty, sortedRows.allSatisfy({ tasks.indices.contains($0) }) else {
            return false
        }

        // Move one or many rows (parallel model arrays) to the drop index.
        let dest = toIndex - sortedRows.filter { $0 < toIndex }.count
        let movedTasks = sortedRows.map { tasks[$0] }
        let movedNotes = sortedRows.map { notes[$0] }
        let movedDone = sortedRows.map { done[$0] }
        for row in sortedRows.reversed() {
            tasks.remove(at: row)
            notes.remove(at: row)
            done.remove(at: row)
        }
        tasks.insert(contentsOf: movedTasks, at: dest)
        notes.insert(contentsOf: movedNotes, at: dest)
        done.insert(contentsOf: movedDone, at: dest)

        // The model moved; the view has no idea. A table does NOT reload itself after a
        // drop — the data source owns the model, so it has to say when it changed. Without
        // this the drop succeeds (this returns true, the model is correct) and the rows
        // keep rendering in the old order, which looks *exactly* like the drag snapping
        // back. Re-select the moved rows so the result is visible, as a reorder should.
        tableView.reloadData()
        tableView.selectRowIndexes(IndexSet(dest..<(dest + sortedRows.count)), byExtendingSelection: false)

        let handler = onReorder
        MainActor.assumeIsolated {
            handler?(sortedRows.count, dest)
        }
        return true
    }
}

/// Delegate that vends a real control per cell so the drawn table hosts them
/// inside its cells — something a native list view can't do.
final class DemoViewTableDelegate: NSObject, NSTableViewDelegate {
    let source: DemoViewTableDataSource
    var onEvent: (@MainActor (String) -> Void)?

    init(source: DemoViewTableDataSource) {
        self.source = source
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableColumn?.identifier.rawValue == "task" {
            let field = NSTextField(string: source.tasks[row], frame: NSMakeRect(0, 0, 200, 22))
            field.isBordered = false
            field.drawsBackground = false
            return field
        }
        // The "note" column is editable: double-click a note to edit it.
        //
        // This used to `return nil` and rely on the table painting the column itself as
        // drawn text. AppKit has no such per-column fallback — a table is view-based or
        // cell-based, and this one is view-based because the delegate vends views at all,
        // so a nil view means an *empty cell*, with nothing to double-click. The column
        // has to vend an editable field like any other view-based column.
        if tableColumn?.identifier.rawValue == "note" {
            let field = NSTextField(string: source.notes[row], frame: NSMakeRect(0, 0, 160, 22))
            field.isBordered = false
            field.drawsBackground = false
            field.isEditable = true
            field.onAction = { [weak self] control in
                guard let self, let edited = control as? NSTextField else {
                    return
                }
                self.source.notes[row] = edited.stringValue
                let handler = onEvent
                let message = "Note \(row) → \(edited.stringValue)"
                MainActor.assumeIsolated {
                    handler?(message)
                }
            }
            return field
        }
        let button = NSButton(title: source.done[row] ? "Done ✓" : "Mark done", frame: NSMakeRect(0, 0, 110, 22))
        button.onAction = { [weak self, weak tableView] _ in
            guard let self else {
                return
            }
            self.source.done[row].toggle()
            let handler = onEvent
            let message = "Row \(row) → \(self.source.done[row] ? "done" : "not done")"
            MainActor.assumeIsolated {
                handler?(message)
            }
            tableView?.reloadData()
        }
        return button
    }

    /// Completed rows render taller — a live demo of the drawn table honoring
    /// per-row heights (toggle "Mark done" and watch the row grow).
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        source.done[row] ? 44 : 24
    }
}

/// A small pipeline-status list showcasing `NSTableRowView` hosting: each row
/// gets a full-width colored row view behind hosted label cells.
final class DemoStatusRowDataSource: NSObject, NSTableViewDataSource {
    let items: [(stage: String, status: String)] = [
        ("Build", "passing"), ("Unit tests", "passing"), ("Lint", "warning"),
        ("Deploy", "failed"), ("Docs", "passing"), ("Package", "passing"),
    ]
    func numberOfRows(in tableView: NSTableView) -> Int { items.count }
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        tableColumn?.identifier.rawValue == "stage" ? items[row].stage : items[row].status
    }
}

final class DemoStatusRowDelegate: NSObject, NSTableViewDelegate {
    let source: DemoStatusRowDataSource
    init(source: DemoStatusRowDataSource) { self.source = source }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        // Hosted (transparent) labels sit above the colored row view.
        let text = tableColumn?.identifier.rawValue == "stage" ? source.items[row].stage : source.items[row].status
        let field = NSTextField(string: text, frame: NSMakeRect(0, 0, 120, 20))
        field.isBordered = false
        field.drawsBackground = false
        return field
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = NSTableRowView(frame: .zero)
        switch source.items[row].status {
        case "passing": rowView.backgroundColor = NSColor(red: 0.85, green: 0.95, blue: 0.85, alpha: 1)
        case "warning": rowView.backgroundColor = NSColor(red: 1.0, green: 0.97, blue: 0.80, alpha: 1)
        case "failed": rowView.backgroundColor = NSColor(red: 1.0, green: 0.87, blue: 0.87, alpha: 1)
        default: rowView.backgroundColor = .white
        }
        return rowView
    }
}

final class DemoTableDataSource: NSObject, NSTableViewDataSource {
    var rows: [[String]] = [
        ["NSApplication", "Running"],
        ["NSWindow", "Key/Main"],
        ["NSButton", "Actions"],
        ["NSTextField", "Editing"],
        ["NSForm", "Composed rows"],
        ["NSMatrix", "Legacy grid"],
        ["NSSecureTextField", "Password"],
        ["NSSearchField", "Immediate search"],
        ["NSComboBox", "Editable list"],
        ["NSLevelIndicator", "Value meter"],
        ["NSDatePicker", "Date/time"],
        ["NSColorWell", "Color swatch"],
        ["NSSegmentedControl", "Composed segments"],
        ["NSTabView", "Native tabs"],
        ["NSImageView", "Bitmap artwork"],
        ["NSBrowser", "Column browser"],
        ["NSOutlineView", "Tree table"],
        ["NSTableView", "First slice"],
        ["NSTableColumn", "Identifiers"],
        ["NSTableCellView", "View based"],
        ["NSTableRowView", "Selection state"],
        ["NSScrollView", "Document view"],
        ["NSResponder", "Key loop"],
        ["NSEvent", "Keyboard/mouse"],
        ["NSMenu", "Quit command"],
        ["NSAlert", "Modal"],
        ["NSColor", "Native paint"],
        ["NSFont", "Native font"]
    ]

    func numberOfRows(in tableView: NSTableView) -> Int {
        rows.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard rows.indices.contains(row) else {
            return nil
        }

        switch tableColumn?.identifier.rawValue {
        case "name":
            return rows[row][0]
        case "status":
            return rows[row][1]
        default:
            return nil
        }
    }

    func sort(using descriptor: NSSortDescriptor) {
        guard let key = descriptor.key else {
            return
        }

        let columnIndex: Int
        switch key {
        case "name":
            columnIndex = 0
        case "status":
            columnIndex = 1
        default:
            return
        }

        rows.sort { left, right in
            let leftValue = left.indices.contains(columnIndex) ? left[columnIndex] : ""
            let rightValue = right.indices.contains(columnIndex) ? right[columnIndex] : ""
            if descriptor.ascending {
                return leftValue < rightValue
            }

            return leftValue > rightValue
        }
    }
}

final class DemoOutlineDataSource: NSObject, NSOutlineViewDataSource {
    var roots = ["Application", "Controls", "Tables"]
    var children: [String: [String]] = [
        "Application": ["NSApplication", "NSWindow", "NSMenu"],
        "Controls": ["NSButton", "NSTextField", "NSMatrix"],
        "Tables": ["NSTableView", "NSOutlineView", "NSTableColumn"]
    ]

    /// Moves `item` to `childIndex` under `parent` (nil = the root list),
    /// supporting **reparenting** — the item is pulled out of wherever it
    /// currently lives (root or any branch) and inserted under the target,
    /// adjusting the index when it moved down within the same list.
    func moveItem(_ item: String, under parent: Any?, to childIndex: Int) {
        let targetKey = parent.map { String(describing: $0) }
        var adjust = 0
        if let idx = roots.firstIndex(of: item) {
            if targetKey == nil, idx < childIndex { adjust = 1 }
            roots.remove(at: idx)
        }
        for key in children.keys {
            if let idx = children[key]?.firstIndex(of: item) {
                if targetKey == key, idx < childIndex { adjust = 1 }
                children[key]?.remove(at: idx)
            }
        }
        let dest = max(0, childIndex - adjust)
        if let targetKey {
            var list = children[targetKey] ?? []
            list.insert(item, at: min(dest, list.count))
            children[targetKey] = list
        } else {
            roots.insert(item, at: min(dest, roots.count))
        }
    }

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard let item else {
            return roots.count
        }

        return children[String(describing: item)]?.count ?? 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let item {
            return children[String(describing: item)]?[index] ?? ""
        }

        return roots[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        !(children[String(describing: item)] ?? []).isEmpty
    }

    // MARK: Sibling/reparenting reorder — AppKit's drag-and-drop recipe
    // (a `.move` local mask + a pasteboard writer per item + acceptDrop).

    /// Reported after a reorder so the page can update its status line.
    var onReorder: (@MainActor (_ movedItem: String, _ childIndex: Int) -> Void)?

    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        String(describing: item) as NSString
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item parent: Any?, childIndex index: Int) -> Bool {
        guard let moved = info.draggingPasteboard.string(forType: .string) else {
            return false
        }
        moveItem(moved, under: parent, to: index)
        let handler = onReorder
        MainActor.assumeIsolated {
            handler?(moved, index)
        }
        return true
    }

    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        guard let item else {
            return nil
        }

        let value = String(describing: item)
        if tableColumn?.identifier.rawValue == "outlineStatus" {
            return children[value] == nil ? "Leaf" : "Group"
        }

        return value
    }
}

final class DemoBrowserDataSource: NSObject, NSBrowserDelegate {
    let roots = ["Application", "Controls", "Tables"]
    let children: [String: [String]] = [
        "Application": ["NSApplication", "NSWindow", "NSMenu", "NSAlert"],
        "Controls": ["NSButton", "NSTextField", "NSComboBox", "NSBrowser"],
        "Tables": ["NSTableView", "NSOutlineView", "NSTableColumn", "NSScrollView"]
    ]

    func browser(_ browser: NSBrowser, numberOfChildrenOfItem item: Any?) -> Int {
        guard let item else {
            return roots.count
        }

        return children[String(describing: item)]?.count ?? 0
    }

    func browser(_ browser: NSBrowser, child index: Int, ofItem item: Any?) -> Any {
        if let item {
            return children[String(describing: item)]?[index] ?? ""
        }

        return roots[index]
    }

    func browser(_ browser: NSBrowser, isLeafItem item: Any?) -> Bool {
        guard let item else {
            return false
        }

        return children[String(describing: item)] == nil
    }

    /// The item-based browser interface requires all four of
    /// `numberOfChildrenOfItem`, `child:ofItem:`, `isLeafItem:` and
    /// `objectValueForItem:`. AppKit probes for them with `respondsToSelector:`
    /// and silently falls back to the old matrix-based interface — raising
    /// "Illegal NSBrowser delegate" — if any one is absent. A Swift
    /// protocol-extension default does not satisfy that probe, so this must be
    /// implemented here rather than defaulted by the framework.
    func browser(_ browser: NSBrowser, objectValueForItem item: Any?) -> Any? {
        item.map { String(describing: $0) }
    }
}
