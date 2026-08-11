import WinChocolate

struct OutlineReorderObservation {
    let item: String
    let parent: String?
    let childIndex: Int
}

@MainActor
func testTableViewDelegateViewHeightAndSortHooks() {
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 160))
    let dataSource = RecordingTableDataSource()
    let delegate = RecordingTableDelegate()
    let name = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    let firstSort = NSSortDescriptor(key: "name", ascending: true)
    let secondSort = NSSortDescriptor(key: "name", ascending: false)

    delegate.rowHeights[1] = 31
    tableView.addTableColumn(name)
    tableView.dataSource = dataSource
    tableView.delegate = delegate
    tableView.reloadData()

    let view = tableView.view(atColumn: 0, row: 1, makeIfNecessary: true)
    let missingView = tableView.view(atColumn: 0, row: 9, makeIfNecessary: true)
    tableView.sortDescriptors = [firstSort]
    tableView.sortDescriptors = [secondSort]

    expect(view === delegate.cellView, "Table delegate did not provide view-based cell view.")
    expect(missingView == nil, "Table view produced view for invalid row.")
    expect(delegate.requestedViewRows == [1], "Table delegate did not record requested row.")
    expect(tableView.heightOfRow(1) == 31, "Table delegate row height was not used.")
    expect(tableView.heightOfRow(0) == tableView.rowHeight, "Table delegate default row height was not used.")
    expect(delegate.oldSortDescriptorCount == 1, "Table delegate sort change did not receive old descriptors.")
    expect(tableView.sortDescriptors.first === secondSort, "Table sort descriptors were not stored.")
}

@MainActor
func testTableViewTabKeyMovesThroughKeyViewLoop() {
    let backend = InMemoryNativeControlBackend()
    let window = TabRecordingWindow(
        contentRect: NSMakeRect(0, 0, 300, 160),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 300, 160))
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 200, 100))
    let nextButton = NSButton(title: "Next", frame: NSMakeRect(0, 110, 80, 24))

    tableView.nextKeyView = nextButton
    nextButton.nextKeyView = tableView
    contentView.addSubview(tableView)
    contentView.addSubview(nextButton)
    window.contentView = contentView
    window.realizeNativePeer()
    _ = window.makeFirstResponder(tableView)

    tableView.keyDown(with: NSEvent(type: .keyDown, locationInWindow: NSZeroPoint, keyCode: 0x09))

    expect(window.nextSelectionCount == 1, "Table view Tab did not request next key view.")
    expect(window.firstResponder === nextButton, "Table view Tab did not move focus to next key view.")

    _ = window.makeFirstResponder(tableView)
    tableView.keyDown(with: NSEvent(type: .keyDown, locationInWindow: NSZeroPoint, keyCode: 0x09, modifierFlags: [.shift]))

    expect(window.previousSelectionCount == 1, "Table view Shift-Tab did not request previous key view.")
    expect(window.firstResponder === nextButton, "Table view Shift-Tab did not move focus to previous key view.")
}

@MainActor
func testSearchFieldTabKeyMovesThroughKeyViewLoop() {
    let backend = InMemoryNativeControlBackend()
    let window = TabRecordingWindow(
        contentRect: NSMakeRect(0, 0, 300, 160),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 300, 160))
    let previousButton = NSButton(title: "Previous", frame: NSMakeRect(0, 0, 80, 24))
    let searchField = NSSearchField(frame: NSMakeRect(0, 32, 160, 24))
    let nextButton = NSButton(title: "Next", frame: NSMakeRect(0, 64, 80, 24))

    previousButton.nextKeyView = searchField
    searchField.nextKeyView = nextButton
    contentView.addSubview(previousButton)
    contentView.addSubview(searchField)
    contentView.addSubview(nextButton)
    window.contentView = contentView
    window.realizeNativePeer()

    guard let searchHandle = searchField.nativeHandle else {
        fatalError("Search field did not realize.")
    }

    expect(window.makeFirstResponder(searchField), "Window did not accept search field as first responder.")

    backend.keyDownActions[searchHandle]?(
        NSEvent(type: .keyDown, locationInWindow: NSMakePoint(0, 0), keyCode: 0x09, characters: "\t")
    )

    expect(window.nextSelectionCount == 1, "Search field Tab did not request next key view.")
    expect(window.firstResponder === nextButton, "Search field Tab did not move focus to next key view.")

    expect(window.makeFirstResponder(searchField), "Window did not reaccept search field as first responder.")

    backend.keyDownActions[searchHandle]?(
        NSEvent(type: .keyDown, locationInWindow: NSMakePoint(0, 0), keyCode: 0x09, characters: "\t", modifierFlags: [.shift])
    )

    expect(window.previousSelectionCount == 1, "Search field Shift-Tab did not request previous key view.")
    expect(window.firstResponder === previousButton, "Search field Shift-Tab did not move focus to previous key view.")
}

@MainActor
func testTableViewKeyboardNavigationUpdatesSelection() {
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 160))
    let dataSource = RecordingTableDataSource()
    let delegate = RecordingTableDelegate()
    let name = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))

    tableView.addTableColumn(name)
    tableView.dataSource = dataSource
    tableView.delegate = delegate
    tableView.reloadData()

    tableView.keyDown(with: NSEvent(type: .keyDown, locationInWindow: NSZeroPoint, keyCode: 0x28))

    expect(tableView.selectedRow == 0, "Down arrow did not select the first row from empty selection.")
    expect(delegate.selectionChangeCount == 1, "Down arrow did not notify selection change.")

    tableView.keyDown(with: NSEvent(type: .keyDown, locationInWindow: NSZeroPoint, keyCode: 0x28))

    expect(tableView.selectedRow == 1, "Down arrow did not advance table selection.")

    tableView.keyDown(with: NSEvent(type: .keyDown, locationInWindow: NSZeroPoint, keyCode: 0x26))

    expect(tableView.selectedRow == 0, "Up arrow did not move table selection up.")

    tableView.keyDown(with: NSEvent(type: .keyDown, locationInWindow: NSZeroPoint, keyCode: 0x23))

    expect(tableView.selectedRow == 2, "End key did not move table selection to the last row.")

    tableView.keyDown(with: NSEvent(type: .keyDown, locationInWindow: NSZeroPoint, keyCode: 0x24))

    expect(tableView.selectedRow == 0, "Home key did not move table selection to the first row.")
}

@MainActor
func testTableViewKeyboardExtendedSelection() {
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 160))
    let dataSource = RecordingTableDataSource()
    let name = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))

    tableView.addTableColumn(name)
    tableView.dataSource = dataSource
    tableView.allowsMultipleSelection = true
    tableView.reloadData()
    tableView.selectRowIndexes([0], byExtendingSelection: false)
    tableView.keyDown(with: NSEvent(type: .keyDown, locationInWindow: NSZeroPoint, keyCode: 0x28, modifierFlags: [.shift]))

    expect(tableView.selectedRowIndexes == [0, 1], "Shift-Down did not extend table selection.")
}

@MainActor
func testTableViewColumnSelectionAndDoubleActionSurface() {
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 160))
    let dataSource = RecordingTableDataSource()
    let name = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    let note = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("note"))
    var doubleActionCount = 0

    tableView.addTableColumn(name)
    tableView.addTableColumn(note)
    tableView.dataSource = dataSource
    tableView.reloadData()
    tableView.selectColumnIndexes([0], byExtendingSelection: false)

    expect(tableView.numberOfSelectedColumns == 0, "Table selected columns before column selection was enabled.")

    tableView.allowsColumnSelection = true
    tableView.selectColumnIndexes([0], byExtendingSelection: false)
    tableView.selectColumnIndexes([1], byExtendingSelection: true)
    tableView.doubleAction = "doubleClick:"
    expect(tableView.doubleAction == "doubleClick:", "Table doubleAction selector was not stored.")
    // Real dispatch: the closure helper wires target/doubleAction to a
    // trampoline, replacing the stored selector (one doubleAction, as AppKit).
    tableView.onDoubleAction = { table in
        expect(table === tableView, "Table double-action sender was not table view.")
        doubleActionCount += 1
    }
    tableView.sendDoubleAction()
    tableView.deselectColumn(0)

    expect(tableView.isColumnSelected(1), "Table did not keep extended column selection.")
    expect(!tableView.isColumnSelected(0), "Table did not deselect column.")
    expect(tableView.numberOfSelectedColumns == 1, "Table selected column count was wrong.")
    expect(doubleActionCount == 1, "Table double action callback was not sent.")

    tableView.allowsColumnSelection = false

    expect(tableView.numberOfSelectedColumns == 0, "Disabling column selection did not clear selected columns.")
}

@MainActor
func testTableViewSortDescriptorPrototypeToggle() {
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 160))
    let dataSource = RecordingTableDataSource()
    let name = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    let note = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("note"))
    let nameSort = NSSortDescriptor(key: "name", ascending: true)
    let noteSort = NSSortDescriptor(key: "note", ascending: true)

    name.sortDescriptorPrototype = nameSort
    note.sortDescriptorPrototype = noteSort
    tableView.addTableColumn(name)
    tableView.addTableColumn(note)
    tableView.dataSource = dataSource
    tableView.reloadData()

    let firstSort = tableView.sortUsingDescriptorPrototype(forColumn: 0)
    let secondSort = tableView.sortUsingDescriptorPrototype(forColumn: 0)
    let thirdSort = tableView.sortUsingDescriptorPrototype(forColumn: 1)
    let missingSort = tableView.sortUsingDescriptorPrototype(forColumn: 9)

    expect(firstSort === nameSort, "Table did not apply the column sort descriptor prototype.")
    expect(tableView.sortDescriptors.first === thirdSort, "Table did not store the most recent sort descriptor.")
    expect(secondSort?.key == "name", "Table reversed descriptor lost its key.")
    expect(secondSort?.ascending == false, "Table did not toggle an already-active sort descriptor.")
    expect(thirdSort === noteSort, "Table did not switch to another column's sort descriptor prototype.")
    expect(missingSort == nil, "Table returned a sort descriptor for a missing column.")
}

@MainActor
func testOutlineViewFlattensExpandableItems() {
    let backend = InMemoryNativeControlBackend()
    let outlineView = NSOutlineView(frame: NSMakeRect(0, 0, 300, 160))
    let dataSource = RecordingOutlineDataSource()
    let name = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    let kind = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("kind"))

    name.title = "Name"
    kind.title = "Kind"
    outlineView.addTableColumn(name)
    outlineView.addTableColumn(kind)
    outlineView.outlineDataSource = dataSource
    outlineView.reloadData()

    expect(outlineView.numberOfRows == 2, "Outline view should start with root rows only.")
    expect(outlineView.item(atRow: 0) as? String == "Application", "Outline root item was wrong.")
    expect(outlineView.level(forRow: 0) == 0, "Outline root level was wrong.")
    expect(outlineView.row(forItem: "Controls") == 1, "Outline did not find root item row.")
    expect(outlineView.value(atColumn: 0, row: 0) == "Application", "Outline first-column value should be plain text (disclosure is drawn, not text).")
    expect(outlineView.value(atColumn: 1, row: 0) == "Group", "Outline did not load secondary column value.")
    expect(outlineView.isExpandable("Application"), "Outline did not report expandable group.")
    expect(!outlineView.isExpandable("NSApplication"), "Outline reported leaf as expandable.")

    outlineView.expandItem("Application")

    expect(outlineView.isItemExpanded("Application"), "Outline did not store expanded state.")
    expect(outlineView.numberOfRows == 4, "Outline did not add expanded children.")
    expect(outlineView.item(atRow: 1) as? String == "NSApplication", "Outline first child was wrong.")
    expect(outlineView.level(forItem: "NSApplication") == 1, "Outline child level was wrong.")
    expect(outlineView.value(atColumn: 0, row: 0) == "Application", "Expanded group value should be plain text.")
    expect(outlineView.value(atColumn: 0, row: 1) == "NSApplication", "Child value should be plain text (indentation is drawn).")
    // Indentation is expressed as a leading inset: a level-1 child is inset more
    // than its level-0 parent.
    expect(outlineView.winDrawnLeadingInset(forRow: 1, column: 0) > outlineView.winDrawnLeadingInset(forRow: 0, column: 0),
           "Outline child was not indented more than its parent.")

    outlineView.collapseItem("Application")

    expect(!outlineView.isItemExpanded("Application"), "Outline did not clear expanded state.")
    expect(outlineView.numberOfRows == 2, "Outline did not remove collapsed children.")

    outlineView.toggleItem("Controls")

    expect(outlineView.isItemExpanded("Controls"), "Outline toggle did not expand collapsed item.")
    expect(outlineView.numberOfRows == 4, "Outline toggle did not reveal child rows.")

    outlineView.toggleItem("NSButton")

    expect(outlineView.isItemExpanded("Controls"), "Outline toggle changed state for leaf item.")

    outlineView.toggleItem("Controls")

    expect(!outlineView.isItemExpanded("Controls"), "Outline toggle did not collapse expanded item.")

    // At this point the outline is collapsed again (2 root rows).
    let handle = outlineView.realizeNativePeer(in: backend, parent: nil)

    // The outline uses the framework-drawn table so it can draw disclosure
    // triangles and indentation itself.
    expect(backend.records[handle]?.kind == "view", "Outline view did not use the framework-drawn table.")

    // Clicking the disclosure triangle on the first root row expands it.
    // (Header is 24pt tall; the triangle sits at the left of row 0.)
    expect(outlineView.numberOfRows == 2, "Outline should be collapsed before the disclosure click.")
    backend.mouseDownActions[handle]?(NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(8, 24 + 8)))
    expect(outlineView.isItemExpanded("Application"), "Clicking the disclosure triangle did not expand the item.")
    expect(outlineView.numberOfRows == 4, "Disclosure-triangle expand did not reveal child rows.")
}

@MainActor
func testOutlineViewSelectionTracksItemAcrossExpandCollapse() {
    let outline = NSOutlineView(frame: NSMakeRect(0, 0, 300, 200))
    let source = RecordingOutlineDataSource()
    outline.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name")))
    outline.outlineDataSource = source
    outline.reloadData()
    outline.expandItem("Application")
    outline.expandItem("Controls")
    // Rows: Application(0), NSApplication(1), NSWindow(2), Controls(3), NSButton(4), NSMatrix(5)
    expect(outline.numberOfRows == 6, "Both groups should be expanded; got \(outline.numberOfRows) rows.")

    // Select the second child of the first group (NSWindow, row 2).
    outline.selectRowIndexes([2], byExtendingSelection: false)
    expect(outline.item(atRow: outline.selectedRow) as? String == "NSWindow", "Setup: NSWindow should be selected.")

    // Collapsing that group hides the selected item, so the selection clears —
    // it must NOT latch onto whatever item now happens to sit at row 2.
    outline.collapseItem("Application")
    expect(outline.selectedRowIndexes.isEmpty,
        "Collapsing the group holding the selection should clear it, not move it to a different item.")

    // Select a still-visible item, then expand a group above it: the selection
    // must follow the item to its new row so the selected item is unchanged.
    // Rows now: Application(0), Controls(1), NSButton(2), NSMatrix(3)
    outline.selectRowIndexes([2], byExtendingSelection: false)
    expect(outline.item(atRow: outline.selectedRow) as? String == "NSButton", "Setup: NSButton should be selected.")
    outline.expandItem("Application")
    // Rows: Application(0), NSApplication(1), NSWindow(2), Controls(3), NSButton(4), NSMatrix(5)
    expect(outline.item(atRow: outline.selectedRow) as? String == "NSButton",
        "Selection should follow NSButton to its new row after an earlier group expands.")
    expect(outline.selectedRow == 4, "NSButton should be at row 4 after expand; got \(outline.selectedRow).")
}

final class HostingOutlineDelegate: NSObject, NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard tableColumn?.identifier.rawValue == "name" else { return nil }
        return NSTextField(string: "cell-\(item)", frame: NSMakeRect(0, 0, 80, 18))
    }
}

@MainActor
func testOutlineViewHostsDelegateCellViews() {
    let backend = InMemoryNativeControlBackend()
    let outline = NSOutlineView(frame: NSMakeRect(0, 0, 240, 160))
    let name = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    name.title = "Name"
    name.width = 160
    let kind = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("kind"))
    kind.title = "Kind"
    kind.width = 60
    outline.addTableColumn(name)
    outline.addTableColumn(kind)
    let dataSource = RecordingOutlineDataSource()
    outline.outlineDataSource = dataSource
    let delegate = HostingOutlineDelegate()
    outline.outlineDelegate = delegate
    outline.reloadData()
    _ = outline.realizeNativePeer(in: backend, parent: nil)

    // Two root rows → the first column hosts a text field per row; the second
    // column (no delegate view) stays drawn text.
    let hosted = outline.subviews.compactMap { $0 as? NSTextField }
    expect(hosted.count == 2, "Outline did not host a delegate cell view per root row. Got \(hosted.count).")
    expect(hosted.contains { $0.stringValue == "cell-Application" },
           "Outline hosted view was not seeded from its item.")
    expect(hosted.contains { $0.stringValue == "cell-Controls" },
           "Outline hosted view for the second root row was missing.")
}

final class TreeOutlineDataSource: NSObject, NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        switch item.map({ String(describing: $0) }) {
        case .none: return 2        // Folder, Loose
        case "Folder": return 1     // Folder → A
        default: return 0
        }
    }
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        switch item.map({ String(describing: $0) }) {
        case .none: return ["Folder", "Loose"][index]
        case "Folder": return "A"
        default: return ""
        }
    }
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        String(describing: item) == "Folder"
    }
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        item.map { String(describing: $0) }
    }
}

@MainActor
func testOutlineViewCrossLevelDropTargetsParent() {
    let outline = NSOutlineView(frame: NSMakeRect(0, 0, 240, 160))
    let name = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    name.title = "Name"
    name.width = 220
    outline.addTableColumn(name)
    let source = TreeOutlineDataSource()
    outline.outlineDataSource = source
    outline.expandItem("Folder")  // visible: Folder(0), A(1, parent Folder), Loose(2)

    var received: OutlineReorderObservation?
    outline.winOutlineReorderHandler = { movedItem, parent, childIndex in
        received = OutlineReorderObservation(
            item: String(describing: movedItem),
            parent: parent.map { String(describing: $0) },
            childIndex: childIndex
        )
    }

    // Drop "Loose" (row 2) directly under the expanded "Folder" header (drop
    // index 1, before its child A) → reparents Loose into Folder at index 0.
    outline.winRowReorderHandler?(IndexSet(integer: 2), 1)
    expect(received?.item == "Loose" && received?.parent == "Folder" && received?.childIndex == 0,
           "Cross-level drop did not reparent into the expanded branch. Got \(String(describing: received)).")

    // Dropping "Folder" (row 0) into its own child A (drop index 2, just under A)
    // is rejected — you can't move an item into its own subtree.
    received = nil
    outline.winRowReorderHandler?(IndexSet(integer: 0), 2)
    expect(received == nil, "Dropping a branch into its own subtree was not rejected. Got \(String(describing: received)).")
}

@MainActor
func testOutlineViewSiblingReorderMovesItem() {
    let outline = NSOutlineView(frame: NSMakeRect(0, 0, 240, 160))
    let name = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    name.title = "Name"
    name.width = 220
    outline.addTableColumn(name)
    let source = MutableOutlineDataSource(["Alpha", "Bravo", "Charlie"])
    outline.outlineDataSource = source

    var received: OutlineReorderObservation?
    outline.winOutlineReorderHandler = { movedItem, parent, childIndex in
        received = OutlineReorderObservation(
            item: String(describing: movedItem),
            parent: parent.map { String(describing: $0) },
            childIndex: childIndex
        )
        // Standard AppKit move: adjust the insert index for the earlier removal.
        let movedName = String(describing: movedItem)
        guard let current = source.roots.firstIndex(of: movedName) else { return }
        source.roots.remove(at: current)
        let dest = childIndex > current ? childIndex - 1 : childIndex
        source.roots.insert(movedName, at: min(max(0, dest), source.roots.count))
    }

    // Setting the handler wires the drawn row-reorder bridge; invoke it as the
    // drop would: drag "Charlie" (row 2) to the top (flattened drop index 0).
    outline.winRowReorderHandler?(IndexSet(integer: 2), 0)

    expect(received?.item == "Charlie" && received?.parent == nil && received?.childIndex == 0,
           "Outline reorder reported the wrong drop. Got \(String(describing: received)).")
    expect(source.roots == ["Charlie", "Alpha", "Bravo"],
           "Outline sibling reorder did not move Charlie to the top. Got \(source.roots).")
    expect(outline.item(atRow: 0) as? String == "Charlie",
           "Outline did not reload with the new order after the reorder.")

    // Move it back down to the end (flattened drop index 3).
    outline.winRowReorderHandler?(IndexSet(integer: 0), 3)
    expect(source.roots == ["Alpha", "Bravo", "Charlie"],
           "Outline sibling reorder did not move Charlie to the end. Got \(source.roots).")
}

@MainActor
func testBrowserLoadsColumnsAndTracksSelection() {
    let backend = InMemoryNativeControlBackend()
    let browser = NSBrowser(frame: NSMakeRect(0, 0, 320, 120))
    let delegate = RecordingBrowserDelegate()
    var actionCount = 0

    browser.delegate = delegate
    browser.defaultColumnWidth = 150
    browser.onAction = { control in
        expect(control === browser, "Browser action sender was not browser.")
        actionCount += 1
    }

    expect(browser.items(inColumn: 0).map { String(describing: $0) } == ["Application", "Controls"], "Browser did not load root items.")
    expect(browser.numberOfVisibleColumns == 1, "Browser should start with one visible column.")

    browser.selectRow(0, inColumn: 0)

    expect(browser.selectedRow(inColumn: 0) == 0, "Browser did not store selected root row.")
    expect(browser.selectedItem(inColumn: 0) as? String == "Application", "Browser selected root item was wrong.")
    expect(browser.numberOfVisibleColumns == 2, "Browser did not add a child column for a branch.")
    expect(browser.items(inColumn: 1).map { String(describing: $0) } == ["NSApplication", "NSWindow"], "Browser child column items were wrong.")

    browser.selectRow(1, inColumn: 1)

    expect(browser.selectedItem(inColumn: 1) as? String == "NSWindow", "Browser selected leaf item was wrong.")
    expect(browser.numberOfVisibleColumns == 2, "Browser leaf selection should keep loaded columns through the leaf.")
    expect(actionCount == 2, "Browser action count was wrong.")

    let handle = browser.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "view", "Browser did not create a native host view.")
    expect(browser.subviews.compactMap { $0 as? NSScrollView }.count == 2, "Browser did not compose two visible scroll-view columns.")
}

@MainActor
func testBrowserPathRoundTrips() {
    let browser = NSBrowser(frame: NSMakeRect(0, 0, 320, 120))
    let delegate = RecordingBrowserDelegate()
    browser.delegate = delegate
    browser.loadColumnZero()

    // Set a path and read it back.
    expect(browser.setPath("/Application/NSWindow"), "setPath did not resolve a valid path.")
    expect(browser.path() == "/Application/NSWindow", "path() did not round-trip. Got \(browser.path()).")
    expect(browser.selectedColumn == 1, "selectedColumn was wrong after setPath. Got \(browser.selectedColumn).")
    expect(browser.selectedItem(inColumn: 0) as? String == "Application", "setPath did not select the first component.")
    expect(browser.selectedItem(inColumn: 1) as? String == "NSWindow", "setPath did not select the leaf component.")

    // Re-pathing to a different branch replaces the selection.
    expect(browser.setPath("/Controls/NSButton"), "setPath did not resolve the second path.")
    expect(browser.path() == "/Controls/NSButton", "path() did not follow the new selection. Got \(browser.path()).")

    // An unresolved path returns false.
    expect(!browser.setPath("/Application/DoesNotExist"), "setPath resolved a nonexistent leaf.")
}

@MainActor
func testBrowserColumnTitles() {
    let browser = NSBrowser(frame: NSMakeRect(0, 0, 320, 120))
    let delegate = RecordingBrowserDelegate()
    browser.delegate = delegate
    browser.loadColumnZero()

    // Column 0 has no default title; each later column is titled by the item
    // that produced it.
    expect(browser.title(ofColumn: 0) == "", "Column 0 should have no default title. Got \(browser.title(ofColumn: 0)).")
    browser.setPath("/Application/NSWindow")
    expect(browser.title(ofColumn: 1) == "Application", "Column 1 title should be the item selected in column 0. Got \(browser.title(ofColumn: 1)).")

    // A re-path retitles the second column.
    browser.setPath("/Controls/NSButton")
    expect(browser.title(ofColumn: 1) == "Controls", "Column 1 title did not follow the new selection. Got \(browser.title(ofColumn: 1)).")

    // A custom title overrides the default.
    browser.setTitle("Roots", ofColumn: 0)
    expect(browser.title(ofColumn: 0) == "Roots", "Custom column title was not applied.")

    // Titles are on by default and can be turned off.
    expect(browser.isTitled, "Browser should be titled by default.")
    browser.isTitled = false
    expect(browser.isTitled == false, "isTitled did not turn off.")
}

final class LeafBranchBrowserDelegate: NSObject, NSBrowserDelegate {
    // "Folder" is a branch (has a child); "File" is a leaf (no children).
    func browser(_ browser: NSBrowser, numberOfChildrenOfItem item: Any?) -> Int {
        switch item.map({ String(describing: $0) }) {
        case .none: return 2          // root: Folder, File
        case "Folder": return 1       // Folder → Document
        default: return 0             // File and Document are leaves
        }
    }
    func browser(_ browser: NSBrowser, child index: Int, ofItem item: Any?) -> Any {
        switch item.map({ String(describing: $0) }) {
        case .none: return ["Folder", "File"][index]
        case "Folder": return "Document"
        default: return ""
        }
    }
    func browser(_ browser: NSBrowser, isLeafItem item: Any?) -> Bool {
        switch item.map({ String(describing: $0) }) {
        case "Folder": return false
        default: return true
        }
    }
}

