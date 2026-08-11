import WinChocolate

@MainActor
struct DrawnTableFixture {
    let scrollView: NSScrollView
    let tableView: NSTableView
    let headerView: NSView
}

@MainActor
func testDrawnTablePinnedHeaderStaysAndSorts() {
    let backend = InMemoryNativeControlBackend()
    let scrollView = NSScrollView(frame: NSMakeRect(0, 0, 300, 120))
    scrollView.hasVerticalScroller = true
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 120))
    let dataSource = ManyRowTableDataSource(count: 20)
    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    column.title = "Name"
    column.width = 280
    column.sortDescriptorPrototype = NSSortDescriptor(key: "name", ascending: true)
    tableView.addTableColumn(column)
    tableView.dataSource = dataSource
    let delegate = ViewBasedTableDelegate()
    tableView.delegate = delegate
    tableView.winUsesViewBasedCells = true
    scrollView.documentView = tableView

    _ = scrollView.realizeNativePeer(in: backend, parent: nil)

    guard let strip = scrollView.winHeaderStripView else {
        fatalError("Pinned header strip was not installed.")
    }
    expect(strip.frame == NSMakeRect(0, 0, 300, 24), "Header strip is not a full-width top band. Got \(strip.frame).")

    // Scroll the body down — the pinned strip stays fixed while the body moves.
    scrollView.contentView.scroll(to: NSMakePoint(0, 200))
    expect(strip.frame == NSMakeRect(0, 0, 300, 24), "Header strip moved when the body scrolled. Got \(strip.frame).")
    expect(tableView.frame.origin.y < 0, "Body did not scroll beneath the pinned header.")

    // Clicking the pinned header strip (press + release, no drag) applies the
    // sort and fires the action on mouse-up.
    var headerActions = 0
    tableView.onAction = { _ in headerActions += 1 }
    strip.mouseDown(with: NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(10, 6)))
    strip.mouseUp(with: NSEvent(type: .leftMouseUp, locationInWindow: NSMakePoint(10, 6)))
    expect(tableView.sortDescriptors.first?.key == "name", "Clicking the pinned header did not apply the sort descriptor.")
    expect(headerActions == 1, "Clicking the pinned header did not fire the table action.")
}

@MainActor
func testDrawnTableHeaderColumnResize() {
    let backend = InMemoryNativeControlBackend()
    let scrollView = NSScrollView(frame: NSMakeRect(0, 0, 320, 120))
    scrollView.hasVerticalScroller = true
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 320, 120))
    let dataSource = ManyRowTableDataSource(count: 6)
    let colA = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("a"))
    colA.title = "A"
    colA.width = 100
    let colB = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("b"))
    colB.title = "B"
    colB.width = 100
    tableView.addTableColumn(colA)
    tableView.addTableColumn(colB)
    tableView.dataSource = dataSource
    let delegate = ViewBasedTableDelegate()
    tableView.delegate = delegate
    tableView.winUsesViewBasedCells = true
    scrollView.documentView = tableView

    _ = scrollView.realizeNativePeer(in: backend, parent: nil)

    guard let strip = scrollView.winHeaderStripView else {
        fatalError("Pinned header strip was not installed.")
    }

    // Drag the boundary between column A and B (at x=100) 40pt to the right.
    strip.mouseDown(with: NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(100, 6)))
    strip.mouseDragged(with: NSEvent(type: .leftMouseDragged, locationInWindow: NSMakePoint(140, 6)))
    strip.mouseUp(with: NSEvent(type: .leftMouseUp, locationInWindow: NSMakePoint(140, 6)))

    expect(colA.width == 140, "Dragging the header boundary did not widen column A. Got \(colA.width).")
    expect(colB.width == 100, "Column B width should be unchanged. Got \(colB.width).")
}

@MainActor
func testDrawnTableHeaderColumnReorder() {
    func makeTable() -> DrawnTableFixture {
        let backend = InMemoryNativeControlBackend()
        let scrollView = NSScrollView(frame: NSMakeRect(0, 0, 320, 120))
        scrollView.hasVerticalScroller = true
        let tableView = NSTableView(frame: NSMakeRect(0, 0, 320, 120))
        let dataSource = ManyRowTableDataSource(count: 6)
        for id in ["a", "b", "c"] {
            let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            col.title = id.uppercased()
            col.width = 100
            tableView.addTableColumn(col)
        }
        tableView.dataSource = dataSource
        let delegate = ViewBasedTableDelegate()
        tableView.delegate = delegate
        tableView.winUsesViewBasedCells = true
        scrollView.documentView = tableView
        _ = scrollView.realizeNativePeer(in: backend, parent: nil)
        guard let strip = scrollView.winHeaderStripView else {
            fatalError("Pinned header strip was not installed.")
        }
        return DrawnTableFixture(scrollView: scrollView, tableView: tableView, headerView: strip)
    }

    // With reordering enabled, dragging column A's header past column B drops it
    // into the second slot: [A,B,C] -> [B,A,C].
    let fixture = makeTable()
    let tableView = fixture.tableView
    let strip = fixture.headerView
    tableView.allowsColumnReordering = true
    strip.mouseDown(with: NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(50, 6)))
    strip.mouseDragged(with: NSEvent(type: .leftMouseDragged, locationInWindow: NSMakePoint(180, 6)))
    strip.mouseUp(with: NSEvent(type: .leftMouseUp, locationInWindow: NSMakePoint(180, 6)))
    expect(tableView.tableColumns.map { $0.identifier.rawValue } == ["b", "a", "c"],
           "Column reorder drag did not move A after B. Got \(tableView.tableColumns.map { $0.identifier.rawValue }).")

    // With reordering disabled (the default), the same drag leaves order intact.
    let lockedFixture = makeTable()
    let lockedTable = lockedFixture.tableView
    let lockedStrip = lockedFixture.headerView
    lockedStrip.mouseDown(with: NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(50, 6)))
    lockedStrip.mouseDragged(with: NSEvent(type: .leftMouseDragged, locationInWindow: NSMakePoint(180, 6)))
    lockedStrip.mouseUp(with: NSEvent(type: .leftMouseUp, locationInWindow: NSMakePoint(180, 6)))
    expect(lockedTable.tableColumns.map { $0.identifier.rawValue } == ["a", "b", "c"],
           "Column reorder happened even though allowsColumnReordering is false. Got \(lockedTable.tableColumns.map { $0.identifier.rawValue }).")
}

final class VariableHeightTableDelegate: NSObject, NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        NSTextField(string: "r\(row)", frame: NSMakeRect(0, 0, 100, 20))
    }
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        row == 0 ? 48 : 24
    }
}

@MainActor
func testDrawnTableHonorsVariableRowHeights() {
    let backend = InMemoryNativeControlBackend()
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 400))
    let dataSource = ManyRowTableDataSource(count: 4)
    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    column.title = "Name"
    column.width = 280
    tableView.addTableColumn(column)
    tableView.dataSource = dataSource
    let delegate = VariableHeightTableDelegate()
    tableView.delegate = delegate
    tableView.winUsesViewBasedCells = true

    let handle = tableView.realizeNativePeer(in: backend, parent: nil)

    // The hosted cell views prove the geometry honors the variable heights.
    // Row 0 (48px) sits just below the 24px header (inset ~1px → y≈25); row 1
    // sits below the tall row 0 at 24 + 48 + 1 = 73 (not 49, which is what a
    // uniform 24px layout would give).
    let ys = tableView.subviews.map { $0.frame.origin.y }.sorted()
    expect(ys.count == 4, "Expected one hosted cell view per row. Got \(ys.count).")
    expect(abs(ys[0] - 25) < 2, "Row 0 cell view not just below the header. Got \(ys[0]).")
    expect(abs(ys[1] - 73) < 2, "Row 1 cell view not below the taller row 0 (expected ~73). Got \(ys[1]).")
    expect(abs(ys[2] - 97) < 2, "Row 2 cell view not at 97. Got \(ys[2]).")
    expect(abs(ys[3] - 121) < 2, "Row 3 cell view not at 121. Got \(ys[3]).")

    // The row-0 cell view is as tall as its 48px row (minus the 1px inset).
    let topView = tableView.subviews.min { $0.frame.origin.y < $1.frame.origin.y }
    expect((topView?.frame.size.height ?? 0) >= 44, "Row 0 cell view did not fill the tall row. Got \(topView?.frame.size.height ?? 0).")

    // Hit-testing honors the variable heights: a click at y=50 lands in the
    // tall row 0, while y=80 lands in row 1 (a uniform layout would misroute).
    backend.mouseDownActions[handle]?(NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(10, 50)))
    expect(tableView.selectedRow == 0, "Click in the tall row 0 did not select it. Got \(tableView.selectedRow).")
    backend.mouseDownActions[handle]?(NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(10, 80)))
    expect(tableView.selectedRow == 1, "Click at y=80 did not select row 1 under variable heights. Got \(tableView.selectedRow).")
}

final class EditableDrawnDataSource: NSObject, NSTableViewDataSource {
    var names = ["alpha", "bravo", "charlie"]
    var committed: [(row: Int, value: String)] = []
    func numberOfRows(in tableView: NSTableView) -> Int { names.count }
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        tableColumn?.identifier.rawValue == "name" ? names[row] : nil
    }
    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        let text = object.map { String(describing: $0) } ?? ""
        names[row] = text
        committed.append((row, text))
    }
}

final class EditableDrawnDelegate: NSObject, NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        tableColumn?.identifier.rawValue == "flag"
            ? NSButton(title: "•", frame: NSMakeRect(0, 0, 40, 20))
            : nil
    }
}

@MainActor
func testDrawnTableInPlaceEditCommitsToDataSource() {
    let backend = InMemoryNativeControlBackend()
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 200))
    let dataSource = EditableDrawnDataSource()
    let flag = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("flag"))
    flag.title = "Flag"
    flag.width = 60
    let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    nameColumn.title = "Name"
    nameColumn.width = 200
    nameColumn.isEditable = true
    tableView.addTableColumn(flag)
    tableView.addTableColumn(nameColumn)
    tableView.dataSource = dataSource
    let delegate = EditableDrawnDelegate()
    tableView.delegate = delegate
    tableView.winUsesViewBasedCells = true

    let handle = tableView.realizeNativePeer(in: backend, parent: nil)

    // Drawn mode: the "flag" column hosts buttons; the "name" column is drawn
    // text — so there is no text field in the table until an edit begins.
    expect(backend.records[handle]?.kind == "view", "Editable drawn table did not realize a custom-drawn peer.")
    expect(tableView.subviews.compactMap { $0 as? NSTextField }.isEmpty, "A text field existed before editing began.")

    // Double-click the drawn "name" cell of row 1 (x in col 1, y in row 1).
    backend.mouseDownActions[handle]?(NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(100, 24 + 24 + 6), clickCount: 2))

    // An editable overlay field appears over the cell, seeded with the value.
    let overlay = tableView.subviews.compactMap { $0 as? NSTextField }.first
    expect(overlay != nil, "Double-clicking an editable drawn cell did not open an edit overlay.")
    expect(overlay?.isEditable == true, "The edit overlay is not editable.")
    expect(overlay?.stringValue == "bravo", "The overlay was not seeded with the cell's value. Got \(overlay?.stringValue ?? "nil").")

    // Type a new value and commit by ending editing (focus loss).
    overlay?.stringValue = "bravo-edited"
    if let overlayHandle = overlay?.nativeHandle {
        backend.simulateFocusChange(gained: false, for: overlayHandle)
    }

    // The edit committed through the data source and the overlay tore down.
    expect(dataSource.committed.contains { $0.row == 1 && $0.value == "bravo-edited" },
           "The in-place edit did not commit to the data source. Committed: \(dataSource.committed).")
    expect(dataSource.names[1] == "bravo-edited", "The data source value was not updated.")
    expect(tableView.subviews.compactMap { $0 as? NSTextField }.isEmpty, "The edit overlay was not removed after committing.")

    // A non-editable column does not open an overlay.
    backend.mouseDownActions[handle]?(NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(20, 24 + 6), clickCount: 2))
    expect(tableView.subviews.compactMap { $0 as? NSTextField }.isEmpty, "A non-editable/hosted column opened an edit overlay.")

    // Programmatic editColumn opens the overlay on the drawn table too.
    tableView.editColumn(1, row: 2, with: nil, select: true)
    let progOverlay = tableView.subviews.compactMap { $0 as? NSTextField }.first
    expect(progOverlay?.stringValue == "charlie", "editColumn did not open a seeded overlay on row 2. Got \(progOverlay?.stringValue ?? "nil").")
    expect(tableView.selectedRow == 2, "editColumn did not select the edited row.")
}

@MainActor
func testDrawnTableReturnKeyBeginsEditingSelectedRow() {
    let backend = InMemoryNativeControlBackend()
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 200))
    let dataSource = EditableDrawnDataSource()
    let flag = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("flag"))
    flag.title = "Flag"
    flag.width = 60
    let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    nameColumn.title = "Name"
    nameColumn.width = 200
    nameColumn.isEditable = true
    tableView.addTableColumn(flag)
    tableView.addTableColumn(nameColumn)
    tableView.dataSource = dataSource
    let delegate = EditableDrawnDelegate()
    tableView.delegate = delegate
    tableView.winUsesViewBasedCells = true

    _ = tableView.realizeNativePeer(in: backend, parent: nil)

    // Select row 1, then press Return: editing begins on the first editable,
    // non-hosted column ("name"), seeded with that cell's value.
    tableView.selectRowIndexes([1], byExtendingSelection: false)
    tableView.keyDown(with: NSEvent(type: .keyDown, locationInWindow: NSZeroPoint, keyCode: 0x0d))

    let overlay = tableView.subviews.compactMap { $0 as? NSTextField }.first
    expect(overlay != nil, "Return did not begin editing the selected row.")
    expect(overlay?.stringValue == "bravo", "Return-edit overlay was not seeded with the cell value. Got \(overlay?.stringValue ?? "nil").")

    // A separate table with no selection: Return sends the action instead.
    let backend2 = InMemoryNativeControlBackend()
    let plainTable = NSTableView(frame: NSMakeRect(0, 0, 300, 200))
    let dataSource2 = EditableDrawnDataSource()
    let nameOnly = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    nameOnly.title = "Name"
    nameOnly.width = 200
    nameOnly.isEditable = true
    plainTable.addTableColumn(nameOnly)
    plainTable.dataSource = dataSource2
    plainTable.winUsesViewBasedCells = true
    _ = plainTable.realizeNativePeer(in: backend2, parent: nil)
    var actions = 0
    plainTable.onAction = { _ in actions += 1 }
    plainTable.keyDown(with: NSEvent(type: .keyDown, locationInWindow: NSZeroPoint, keyCode: 0x0d))
    expect(plainTable.subviews.compactMap { $0 as? NSTextField }.isEmpty, "Return opened an editor with no selection.")
    expect(actions == 1, "Return with no editable target did not fall back to the row action.")
}

final class RowViewTableDelegate: NSObject, NSTableViewDelegate {
    let base = NSColor(white: 0.9, alpha: 1)
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        NSTextField(string: "r\(row)", frame: NSMakeRect(0, 0, 100, 20))
    }
    func tableView(_ tableView: NSTableView, rowViewFor row: Int) -> NSTableRowView? {
        let rowView = NSTableRowView(frame: .zero)
        rowView.backgroundColor = base
        return rowView
    }
}

@MainActor
func testDrawnTableHostsRowViewsWithSelectionFill() {
    let backend = InMemoryNativeControlBackend()
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 200))
    let dataSource = ManyRowTableDataSource(count: 3)
    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    column.title = "Name"
    column.width = 280
    tableView.addTableColumn(column)
    tableView.dataSource = dataSource
    let delegate = RowViewTableDelegate()
    tableView.delegate = delegate
    tableView.winUsesViewBasedCells = true

    let handle = tableView.realizeNativePeer(in: backend, parent: nil)

    // One full-width row view is hosted per row, ordered top-to-bottom.
    let rowViews = tableView.subviews.compactMap { $0 as? NSTableRowView }
        .sorted { $0.frame.origin.y < $1.frame.origin.y }
    expect(rowViews.count == 3, "The table did not host one row view per row. Got \(rowViews.count).")
    expect(rowViews.allSatisfy { $0.frame.size.width == 300 }, "Row views are not full table width.")
    expect(rowViews[0].frame.origin.y == 24, "Row view 0 not placed below the header. Got \(rowViews[0].frame.origin.y).")

    // Row views layer behind the cell views (the cells host after them).
    let firstRowIndex = tableView.subviews.firstIndex { $0 === rowViews[0] } ?? -1
    let firstCellIndex = tableView.subviews.firstIndex { $0 is NSTextField } ?? -1
    expect(firstRowIndex >= 0 && firstCellIndex > firstRowIndex, "Row views do not layer behind the cell views.")

    // Unselected rows paint their base color natively.
    let firstRowHandle = requireValue(rowViews[0].nativeHandle, "First row should have a native handle.")
    expect(backend.records[firstRowHandle]?.backgroundColor == delegate.base,
           "Row view did not fill with its base color.")

    // Clicking row 1 flips its selection and swaps its native fill to the
    // selection color, leaving the others on their base color.
    backend.mouseDownActions[handle]?(NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(10, 24 + 24 + 6)))
    expect(rowViews[1].isSelected, "Clicking row 1 did not select its row view.")
    let secondRowHandle = requireValue(rowViews[1].nativeHandle, "Second row should have a native handle.")
    expect(backend.records[secondRowHandle]?.backgroundColor == NSColor.selectedTextBackgroundColor,
           "Selected row view did not swap to the selection fill.")
    expect(rowViews[0].isSelected == false, "Row 0 should not be selected.")
    expect(backend.records[firstRowHandle]?.backgroundColor == delegate.base,
           "Unselected row view lost its base fill.")

    // The click repaints the whole table tree (not just the surface), so the
    // borderless cell labels redraw over the new selection fill immediately
    // instead of showing stale pixels until a scroll.
    expect(backend.invalidatedTreeHandles.contains(handle),
           "Selecting a row did not invalidate the table's child tree (stale-until-scroll bug).")
}

@MainActor
func testTableViewAutoDetectsViewBasedModeFromDelegate() {
    let backend = InMemoryNativeControlBackend()

    // A delegate that vends a cell view auto-selects the framework-drawn peer —
    // WITHOUT any explicit `winUsesViewBasedCells` opt-in (AppKit semantics).
    let viewTable = NSTableView(frame: NSMakeRect(0, 0, 200, 120))
    let viewSource = ManyRowTableDataSource(count: 3)
    let viewCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    viewCol.width = 180
    viewTable.addTableColumn(viewCol)
    viewTable.dataSource = viewSource
    let viewDelegate = ViewBasedTableDelegate()
    viewTable.delegate = viewDelegate
    // winUsesViewBasedCells intentionally left false.
    let viewHandle = viewTable.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[viewHandle]?.kind == "view",
           "A view-vending delegate did not auto-select the drawn peer. Got \(backend.records[viewHandle]?.kind ?? "nil").")
    expect(viewTable.subviews.compactMap { $0 as? NSTextField }.count == 3,
           "Auto-detected drawn table did not host its cell views.")

    // A cell-based delegate (vends no view) keeps the native list path.
    let cellTable = NSTableView(frame: NSMakeRect(0, 0, 200, 120))
    let cellSource = RecordingTableDataSource()
    let cellCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    cellCol.width = 180
    cellTable.addTableColumn(cellCol)
    cellTable.dataSource = cellSource
    let cellDelegate = CellBasedSelectionDelegate()
    cellTable.delegate = cellDelegate
    let cellHandle = cellTable.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[cellHandle]?.kind != "view",
           "A cell-based table wrongly used the drawn peer. Got \(backend.records[cellHandle]?.kind ?? "nil").")
}

final class ReorderableTableDataSource: NSObject, NSTableViewDataSource {
    var items = ["alpha", "bravo", "charlie", "delta"]
    func numberOfRows(in tableView: NSTableView) -> Int { items.count }
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? { items[row] }
}

final class DropTargetTableDataSource: NSObject, NSTableViewDataSource {
    var items = ["alpha", "bravo"]
    func numberOfRows(in tableView: NSTableView) -> Int { items.count }
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? { items[row] }
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard let text = info.draggingPasteboard.string(forType: .string) else { return false }
        items.insert(text, at: max(0, min(row, items.count)))
        return true
    }
}

@MainActor
func testDrawnTableAcceptsExternalRowDrop() {
    let backend = InMemoryNativeControlBackend()
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 200, 200))
    let dataSource = DropTargetTableDataSource()
    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    column.width = 180
    tableView.addTableColumn(column)
    tableView.dataSource = dataSource
    tableView.winUsesViewBasedCells = true

    let handle = tableView.realizeNativePeer(in: backend, parent: nil)
    tableView.registerForDraggedTypes([.string])

    // Drop "charlie" at the very top → inserted as the new first row.
    let dropped = backend.simulateDrop(content: NativeDropContent(text: "charlie", filePaths: []),
                                       at: NSMakePoint(20, 2), for: handle)
    expect(dropped, "External drop was not accepted by the table.")
    expect(dataSource.items == ["charlie", "alpha", "bravo"],
           "Dropped text was not inserted at the drop row. Got \(dataSource.items).")

    // A table not registered for the dragged type refuses the drop.
    let backend2 = InMemoryNativeControlBackend()
    let plain = NSTableView(frame: NSMakeRect(0, 0, 200, 200))
    let ds2 = DropTargetTableDataSource()
    let col2 = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("n"))
    col2.width = 180
    plain.addTableColumn(col2)
    plain.dataSource = ds2
    plain.winUsesViewBasedCells = true
    let handle2 = plain.realizeNativePeer(in: backend2, parent: nil)
    let refused = backend2.simulateDrop(content: NativeDropContent(text: "x", filePaths: []),
                                        at: NSMakePoint(20, 2), for: handle2)
    expect(!refused, "A table not registered for drops accepted one.")
    expect(ds2.items == ["alpha", "bravo"], "A refused drop still mutated the model.")
}

final class PasteboardRowDataSource: NSObject, NSTableViewDataSource {
    let items = ["alpha", "bravo", "charlie", "delta"]
    func numberOfRows(in tableView: NSTableView) -> Int { items.count }
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? { items[row] }
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? { items[row] }
}

@MainActor
func testDrawnTableRowDragsOutViaPasteboardWriter() {
    let backend = InMemoryNativeControlBackend()
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 200, 300))
    let dataSource = PasteboardRowDataSource()
    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    column.width = 180
    tableView.addTableColumn(column)
    tableView.dataSource = dataSource
    let delegate = ViewBasedTableDelegate()
    tableView.delegate = delegate
    // No winRowReorderHandler → a row drag goes out as a system/OLE drag.

    let handle = tableView.realizeNativePeer(in: backend, parent: nil)
    // Press row 1 (arms the external drag) then move to start it.
    let header: CGFloat = 24
    backend.mouseDownActions[handle]?(NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(20, header + 1 * 24 + 6)))
    backend.mouseDraggedActions[handle]?(NSEvent(type: .leftMouseDragged, locationInWindow: NSMakePoint(60, header + 1 * 24 + 6)))

    expect(backend.performedDrags.count == 1,
           "Dragging a row with a pasteboard writer did not start a system drag. Got \(backend.performedDrags.count).")
    expect(backend.performedDrags.first?.content.text == "bravo",
           "The row drag carried the wrong pasteboard text. Got \(String(describing: backend.performedDrags.first?.content.text)).")

    // A table whose data source vends no writer does not start a drag.
    let backend2 = InMemoryNativeControlBackend()
    let plain = NSTableView(frame: NSMakeRect(0, 0, 200, 300))
    let plainSource = ReorderableTableDataSource()
    let col2 = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("n"))
    col2.width = 180
    plain.addTableColumn(col2)
    plain.dataSource = plainSource
    plain.delegate = delegate
    let handle2 = plain.realizeNativePeer(in: backend2, parent: nil)
    backend2.mouseDownActions[handle2]?(NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(20, header + 6)))
    backend2.mouseDraggedActions[handle2]?(NSEvent(type: .leftMouseDragged, locationInWindow: NSMakePoint(60, header + 6)))
    expect(backend2.performedDrags.isEmpty, "A row with no pasteboard writer should not start a system drag.")
}

@MainActor
func testDrawnTableRowReorderDragMovesRow() {
    let backend = InMemoryNativeControlBackend()
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 200, 300))
    let dataSource = ReorderableTableDataSource()
    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    column.width = 180
    tableView.addTableColumn(column)
    tableView.dataSource = dataSource
    let delegate = ViewBasedTableDelegate()
    tableView.delegate = delegate

    var reorderCalls: [(rows: IndexSet, to: Int)] = []
    tableView.winRowReorderHandler = { rows, to in
        reorderCalls.append((rows, to))
        let sorted = rows.sorted()
        let dest = to - sorted.filter { $0 < to }.count
        let moving = sorted.map { dataSource.items[$0] }
        for r in sorted.reversed() { dataSource.items.remove(at: r) }
        dataSource.items.insert(contentsOf: moving, at: dest)
    }

    let handle = tableView.realizeNativePeer(in: backend, parent: nil)
    // Header is 24pt (column has a default title); rows are 24pt each below it.
    // Press row 1 ("bravo"), drag past row 2, drop before row 3 (index 3).
    let header: CGFloat = 24
    backend.mouseDownActions[handle]?(NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(10, header + 1 * 24 + 6)))
    backend.mouseDraggedActions[handle]?(NSEvent(type: .leftMouseDragged, locationInWindow: NSMakePoint(10, header + 3 * 24 + 4)))
    backend.mouseUpActions[handle]?(NSEvent(type: .leftMouseUp, locationInWindow: NSMakePoint(10, header + 3 * 24 + 4)))

    expect(reorderCalls.count == 1, "Reorder handler was not called once. Got \(reorderCalls.count).")
    expect(reorderCalls.first?.rows == IndexSet(integer: 1) && reorderCalls.first?.to == 3,
           "Reorder handler received wrong indices. Got \(String(describing: reorderCalls.first)).")
    expect(dataSource.items == ["alpha", "charlie", "bravo", "delta"],
           "Row reorder did not move 'bravo' after 'charlie'. Got \(dataSource.items).")
}

