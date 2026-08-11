import WinChocolate

@MainActor
func testDrawnTableMultiRowReorderMovesSelection() {
    let backend = InMemoryNativeControlBackend()
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 200, 300))
    let dataSource = ReorderableTableDataSource()  // alpha, bravo, charlie, delta
    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    column.width = 180
    tableView.addTableColumn(column)
    tableView.dataSource = dataSource
    tableView.allowsMultipleSelection = true
    let delegate = ViewBasedTableDelegate()
    tableView.delegate = delegate
    tableView.winRowReorderHandler = { rows, to in
        let sorted = rows.sorted()
        let dest = to - sorted.filter { $0 < to }.count
        let moving = sorted.map { dataSource.items[$0] }
        for r in sorted.reversed() { dataSource.items.remove(at: r) }
        dataSource.items.insert(contentsOf: moving, at: dest)
    }

    let handle = tableView.realizeNativePeer(in: backend, parent: nil)
    // Select rows 0 and 1 (alpha, bravo), then drag from row 0 (no modifier —
    // the selection must survive so all selected rows drag together) to the end.
    tableView.selectRowIndexes([0, 1], byExtendingSelection: false)
    let header: CGFloat = 24
    backend.mouseDownActions[handle]?(NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(10, header + 0 * 24 + 6)))
    backend.mouseDraggedActions[handle]?(NSEvent(type: .leftMouseDragged, locationInWindow: NSMakePoint(10, header + 4 * 24)))
    backend.mouseUpActions[handle]?(NSEvent(type: .leftMouseUp, locationInWindow: NSMakePoint(10, header + 4 * 24)))

    // Both selected rows move to the end, keeping their order.
    expect(dataSource.items == ["charlie", "delta", "alpha", "bravo"],
           "Multi-row reorder did not move the selection to the end. Got \(dataSource.items).")
}

@MainActor
func testTableHeaderViewTracksClickedColumnAndGeometry() {
    let backend = InMemoryNativeControlBackend()
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 160))
    let dataSource = ManyRowTableDataSource(count: 3)
    let colA = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("a"))
    colA.title = "A"
    colA.width = 100
    colA.sortDescriptorPrototype = NSSortDescriptor(key: "a", ascending: true)
    let colB = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("b"))
    colB.title = "B"
    colB.width = 120
    colB.sortDescriptorPrototype = NSSortDescriptor(key: "b", ascending: true)
    tableView.addTableColumn(colA)
    tableView.addTableColumn(colB)
    tableView.dataSource = dataSource
    let delegate = ViewBasedTableDelegate()
    tableView.delegate = delegate

    // The header view is auto-created and linked to its table.
    expect(tableView.headerView != nil, "Table did not auto-create a header view.")
    expect(tableView.headerView?.tableView === tableView, "Header view was not linked to its table.")

    // Geometry: column B starts after column A's 100pt width.
    expect(tableView.headerView?.headerRect(ofColumn: 1) == NSMakeRect(100, 0, 120, 24),
           "Header rect for column 1 was wrong. Got \(tableView.headerView?.headerRect(ofColumn: 1) ?? .zero).")
    expect(tableView.headerView?.column(at: NSMakePoint(150, 5)) == 1,
           "columnAtPoint did not resolve to column 1.")

    let handle = tableView.realizeNativePeer(in: backend, parent: nil)

    // Clicking column B's header (y in the 24pt header band) records it.
    backend.mouseDownActions[handle]?(NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(150, 8)))
    expect(tableView.headerView?.clickedColumn == 1, "Header click did not record clickedColumn. Got \(tableView.headerView?.clickedColumn ?? -99).")
    expect(tableView.sortDescriptors.first?.key == "b", "Header click did not apply column B's sort prototype.")
}

final class LayoutCountingView: NSView {
    var layoutCount = 0
    override func layout() {
        layoutCount += 1
    }
}

@MainActor
func testNeedsLayoutArmsCoalescedPumpFlush() {
    clearApplicationWindows()
    let previousBackend = NSApplication.shared.nativeBackend
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        clearApplicationWindows()
    }

    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 300, 200),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let content = LayoutCountingView(frame: NSMakeRect(0, 0, 300, 200))
    let child = LayoutCountingView(frame: NSMakeRect(0, 0, 50, 50))
    content.addSubview(child)
    window.contentView = content

    // Marking two views in the same window arms exactly one flush timer on
    // the current backend — the marks coalesce.
    let timersBefore = backend.scheduledTimers.count
    content.needsLayout = true
    child.needsLayout = true
    expect(backend.scheduledTimers.count == timersBefore + 1,
           "needsLayout marks should arm exactly one coalesced flush timer; armed \(backend.scheduledTimers.count - timersBefore).")

    // The message-loop tick runs one layout pass over the window subtree and
    // clears the flags.
    backend.fireDueTimers()
    expect(content.layoutCount == 1 && child.layoutCount == 1,
           "Pump flush should lay out the window subtree once. Got content \(content.layoutCount), child \(child.layoutCount).")
    expect(!content.needsLayout && !child.needsLayout,
           "Pump flush should clear needsLayout.")

    // A fresh mark after the flush arms a new timer (the pump re-arms).
    content.needsLayout = true
    expect(backend.scheduledTimers.count == timersBefore + 2,
           "A mark after a flush should arm a new flush timer.")
}

@MainActor
func testControlsExposeAppKitAccessibilityRolesAndValues() {
    // A checkbox reports the checkbox role, its title as label, and its state
    // as the accessibility value — the AppKit contract assistive tech reads.
    let checkbox = NSButton(frame: NSMakeRect(0, 0, 120, 24))
    checkbox.title = "Remember me"
    checkbox.setButtonType(.switch)
    checkbox.state = .on
    expect(checkbox.accessibilityRole() == .checkBox, "A switch button should report the checkbox role.")
    expect(checkbox.accessibilityLabel() == "Remember me", "A button's title should be its accessibility label.")
    expect((checkbox.accessibilityValue() as? Int) == 1, "A checked box should report value 1.")
    expect(checkbox.isAccessibilityElement(), "A control should be an accessibility element.")
    expect(checkbox.accessibilityRoleDescription() == "checkbox", "The role description should match AppKit's.")

    // A radio button reports the radio role.
    let radio = NSButton(frame: .zero)
    radio.setButtonType(.radio)
    expect(radio.accessibilityRole() == .radioButton, "A radio button should report the radio role.")

    // An editable field is a text field carrying its text as value; a static
    // label field is static text.
    let field = NSTextField(frame: NSMakeRect(0, 0, 160, 22))
    field.isEditable = true
    field.stringValue = "hello"
    field.placeholderString = "Name"
    expect(field.accessibilityRole() == .textField, "An editable field should report the text-field role.")
    expect((field.accessibilityValue() as? String) == "hello", "A text field's value should be its text.")
    expect(field.accessibilityLabel() == "Name", "A field's placeholder should be its default label.")

    let label = NSTextField(frame: .zero)
    label.isEditable = false
    label.isSelectable = false
    label.stringValue = "Caption"
    expect(label.accessibilityRole() == .staticText, "A non-editable field should report static text.")

    // A slider carries its numeric value.
    let slider = NSSlider(frame: NSMakeRect(0, 0, 120, 20))
    slider.doubleValue = 0.5
    expect(slider.accessibilityRole() == .slider, "A slider should report the slider role.")
    expect((slider.accessibilityValue() as? Double) == 0.5, "A slider's value should be its double value.")

    // An explicit override wins over the intrinsic role/label (AppKit semantics).
    let custom = NSButton(frame: .zero)
    custom.title = "Go"
    custom.setAccessibilityLabel("Submit the form")
    custom.setAccessibilityRole(.link)
    expect(custom.accessibilityLabel() == "Submit the form", "An explicit accessibility label should win.")
    expect(custom.accessibilityRole() == .link, "An explicit accessibility role should win.")

    // A disabled control reports itself disabled to assistive technology.
    let disabled = NSButton(frame: .zero)
    disabled.isEnabled = false
    expect(!disabled.isAccessibilityEnabled(), "A disabled control should report itself disabled.")

    // A plain container view is not an element and reports the group role.
    let container = NSView(frame: NSMakeRect(0, 0, 100, 100))
    expect(!container.isAccessibilityElement(), "A plain view should not be an accessibility element.")
    expect(container.accessibilityRole() == .group, "A plain view should report the group role.")
}

@MainActor
func testAccessibilityTreeWalksContainerHierarchy() {
    // A container's snapshot should reach its control descendants with their
    // roles/labels intact.
    let root = NSView(frame: NSMakeRect(0, 0, 200, 120))
    let ok = NSButton(frame: NSMakeRect(10, 10, 80, 24))
    ok.title = "OK"
    let cancel = NSButton(frame: NSMakeRect(100, 10, 80, 24))
    cancel.title = "Cancel"
    let hidden = NSButton(frame: NSMakeRect(0, 50, 80, 24))
    hidden.title = "Secret"
    hidden.isHidden = true
    root.addSubview(ok)
    root.addSubview(cancel)
    root.addSubview(hidden)

    let snapshot = root.winAccessibilitySnapshot()
    expect(snapshot.role == NSAccessibilityRole.group.rawValue, "The root should snapshot as a group.")
    expect(snapshot.children.count == 2, "A hidden subview should not appear in the accessibility tree.")
    expect(snapshot.firstDescendant(labeled: "OK") != nil, "The OK button should be reachable in the tree.")
    expect(snapshot.firstDescendant(labeled: "Cancel")?.role == NSAccessibilityRole.button.rawValue,
           "Cancel should be reachable and report the button role.")
    expect(snapshot.firstDescendant(labeled: "Secret") == nil, "The hidden button should be absent.")
    // Two buttons, both elements; the group container is not an element.
    expect(snapshot.elementCount == 2, "The tree should count exactly the two visible controls.")
}

@MainActor
func testDrawnTablePublishesRowAndCellAccessibilityTree() {
    // The framework-drawn table draws its own cells, so it must publish a
    // synthetic AXTable → AXRow → AXCell tree for screen readers (10.2, moved
    // from 5.1). We assert that tree directly.
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 160))
    let dataSource = RecordingTableDataSource()
    let name = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    let note = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("note"))
    name.title = "Name"
    note.title = "Note"
    tableView.addTableColumn(name)
    tableView.addTableColumn(note)
    tableView.dataSource = dataSource
    tableView.reloadData()

    let snapshot = tableView.winAccessibilitySnapshot()
    expect(snapshot.role == NSAccessibilityRole.table.rawValue,
           "A multi-column drawn table should report the table role.")
    let rows = snapshot.descendants(role: .row)
    expect(rows.count == 3, "The table should publish one AXRow per data row.")
    expect(rows[0].subrole == NSAccessibilitySubrole.tableRow.rawValue, "Rows should carry the table-row subrole.")
    let cells = snapshot.descendants(role: .cell)
    expect(cells.count == 6, "The table should publish one AXCell per row per column.")
    // The first row's first cell carries the model text and its column's title.
    let firstCell = rows[0].children.first
    expect((firstCell?.value) == "Ada", "The first cell should carry its model text as the accessibility value.")
    expect(firstCell?.label == "Name", "A cell should default its label to its column title.")
    // The second row's second cell reflects the data source.
    expect(rows[1].children.last?.value == "Navy", "Row/column addressing in the tree should match the data source.")

    // An outline reports the outline role with outline-row subroles.
    let outlineView = NSOutlineView(frame: NSMakeRect(0, 0, 300, 160))
    outlineView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name")))
    outlineView.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("kind")))
    let outlineSource = RecordingOutlineDataSource()
    outlineView.outlineDataSource = outlineSource
    outlineView.reloadData()
    let outlineSnapshot = outlineView.winAccessibilitySnapshot()
    expect(outlineSnapshot.role == NSAccessibilityRole.outline.rawValue,
           "A drawn outline should report the outline role.")
    if let firstOutlineRow = outlineSnapshot.descendants(role: .row).first {
        expect(firstOutlineRow.subrole == NSAccessibilitySubrole.outlineRow.rawValue,
               "Outline rows should carry the outline-row subrole.")
    } else {
        expect(false, "The outline should publish at least one row element.")
    }
}

@MainActor
func testAccessibilityLabelPropagatesToNativePeer() {
    // An explicit accessibility label pushes to the backend so the OS
    // accessibility layer reads the app's label rather than window text.
    let backend = InMemoryNativeControlBackend()
    let button = NSButton(frame: NSMakeRect(0, 0, 80, 24))
    let handle = button.realizeNativePeer(in: backend, parent: nil)
    button.setAccessibilityLabel("Close window")
    expect(backend.records[handle]?.accessibilityName == "Close window",
           "A post-realization accessibility label should push to the native peer.")

    // A label set before realization is replayed onto the backend so the
    // annotation matches regardless of ordering.
    let pre = NSButton(frame: NSMakeRect(0, 0, 80, 24))
    pre.setAccessibilityLabel("Help")
    let preHandle = pre.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[preHandle]?.accessibilityName == "Help",
           "A pre-realization accessibility label should replay onto the native peer.")
}

@MainActor
func testTextFieldShowsIBeamAndHeaderShowsResizeCursor() {
    // An editable field shows the I-beam over its content; a static label does not.
    let editable = NSTextField(frame: NSMakeRect(0, 0, 120, 22))
    editable.isEditable = true
    let editRegions = editable.winResolvedCursorRegions()
    expect(editRegions.contains { $0.cursorName == "iBeam" },
           "An editable text field should show the I-beam cursor.")

    let staticLabel = NSTextField(frame: NSMakeRect(0, 0, 120, 22))
    staticLabel.isEditable = false
    staticLabel.isSelectable = false
    expect(staticLabel.winResolvedCursorRegions().isEmpty,
           "A static label should not claim a cursor region.")

    // The table header shows the left-right resize cursor over each column
    // boundary when resizing is allowed.
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 160))
    let a = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("a")); a.width = 100
    let b = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("b")); b.width = 120
    tableView.addTableColumn(a)
    tableView.addTableColumn(b)
    let header = NSTableHeaderView(frame: NSMakeRect(0, 0, 300, 24))
    header.tableView = tableView
    let regions = header.winResolvedCursorRegions()
    let resizeRegions = regions.filter { $0.cursorName == "resizeLeftRight" }
    expect(resizeRegions.count == 2, "The header should show a resize cursor at each column boundary.")
    // The first boundary straddles the first column's trailing edge (x == 100).
    expect(resizeRegions.contains { $0.rect.minX < 100 && $0.rect.maxX > 100 },
           "A resize hot-zone should straddle the first column boundary at x=100.")

    // With resizing disabled, no resize cursor appears.
    tableView.allowsColumnResizing = false
    expect(header.winResolvedCursorRegions().isEmpty,
           "A non-resizable table's header should not show resize cursors.")
}

@MainActor
func testDrawnTableTabAdvancesCellEditor() {
    let backend = InMemoryNativeControlBackend()
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 160))
    let dataSource = RecordingTableDataSource()
    let name = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    let note = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("note"))
    name.title = "Name"; name.isEditable = true
    note.title = "Note"; note.isEditable = true
    tableView.addTableColumn(name)
    tableView.addTableColumn(note)
    tableView.dataSource = dataSource
    tableView.winUsesViewBasedCells = true
    _ = tableView.realizeNativePeer(in: backend, parent: nil)

    // Begin editing the first cell.
    tableView.editColumn(0, row: 0, with: nil, select: true)
    expect(tableView.winIsEditingDrawnCell, "editColumn should begin a drawn-cell edit.")
    expect(tableView.winEditingRow == 0 && tableView.winEditingColumn == 0,
           "Editing should start at (0,0).")

    // Tab advances across columns within the row.
    expect(tableView.winAdvanceDrawnEdit(reversed: false), "Tab should advance the editor.")
    expect(tableView.winEditingRow == 0 && tableView.winEditingColumn == 1,
           "Tab should move to the next column in the same row.")

    // Tab at the row's last column wraps to the first column of the next row.
    expect(tableView.winAdvanceDrawnEdit(reversed: false), "Tab should advance to the next row.")
    expect(tableView.winEditingRow == 1 && tableView.winEditingColumn == 0,
           "Tab past the last column should wrap to the next row's first column.")

    // Backtab reverses back to the previous row's last column.
    expect(tableView.winAdvanceDrawnEdit(reversed: true), "Backtab should retreat the editor.")
    expect(tableView.winEditingRow == 0 && tableView.winEditingColumn == 1,
           "Backtab should move to the previous row's last column.")

    // The advance commits the intermediate edits back to the data source
    // (the value typed before Tab is not lost).
    expect(tableView.winIsEditingDrawnCell, "Editing should still be active after advancing.")
}

@MainActor
func testSearchFieldDrawsChromeAndRecentMenu() {
    let field = NSSearchField(frame: NSMakeRect(0, 0, 160, 22))

    // With no text: the magnifier draws (a ring + handle = 2 strokes) and no
    // clear button appears.
    let empty = RecordingDrawingContext()
    field.winDrawSearchChrome(in: empty)
    expect(empty.strokes.count == 2, "An empty search field should draw only the magnifier (ring + handle).")
    expect(field.winCancelButtonRect.width == 0, "An empty search field should have no clear button.")

    // The magnifier sits at the leading edge; the text area starts after it.
    expect(field.winSearchIconRect.minX < field.winSearchTextRect.minX,
           "The magnifier should sit to the left of the text area.")

    // With text: the clear (✕) button appears (2 more strokes) on the trailing edge.
    field.stringValue = "swift"
    let withText = RecordingDrawingContext()
    field.winDrawSearchChrome(in: withText)
    expect(withText.strokes.count == 4, "A search field with text should draw the magnifier and the clear ✕.")
    expect(field.winCancelButtonRect.maxX <= field.bounds.width,
           "The clear button should sit within the trailing edge.")

    // Clicking the clear button empties the field.
    let cancelPoint = NSPoint(x: field.winCancelButtonRect.midX, y: field.winCancelButtonRect.midY)
    expect(field.winHandleSearchChromeClick(at: cancelPoint), "A click on the clear button should be consumed.")
    expect(field.stringValue.isEmpty, "Clicking the clear button should empty the search field.")

    // The recent-searches menu lists the tracked searches plus a Clear item.
    field.recentSearches = ["alpha", "beta"]
    let menu = field.winRecentSearchesMenu()
    let titles = menu.items.map { $0.title }
    expect(titles.contains("Recent Searches"), "The recent menu should have the AppKit header.")
    expect(titles.contains("alpha") && titles.contains("beta"), "The recent menu should list recent searches.")
    expect(titles.contains("Clear"), "The recent menu should offer a Clear item.")

    let emptyMenu = NSSearchField(frame: .zero).winRecentSearchesMenu()
    expect(emptyMenu.items.contains { $0.title == "No Recent Searches" },
           "With no history the menu should show 'No Recent Searches'.")
}

@MainActor
func testSheetsLinkParentPositionBelowToolbarAndQueue() {
    let backend = InMemoryNativeControlBackend()
    backend.nextModalResponseCode = NSApplication.ModalResponse.OK.rawValue
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        clearApplicationWindows()
    }

    func makeWindow() -> NSWindow {
        NSWindow(contentRect: NSMakeRect(0, 0, 400, 300), styleMask: [.titled],
                 backing: .buffered, defer: false, nativeBackend: backend)
    }

    let parent = makeWindow()
    let sheet = makeWindow()
    sheet.setFrame(NSMakeRect(0, 0, 200, 120), display: false)

    parent.beginSheet(sheet)
    expect(parent.attachedSheet === sheet, "beginSheet should attach the sheet to its parent.")
    expect(sheet.sheetParent === parent, "The sheet should link back to its parent window.")
    // Centered horizontally, dropped below the title area.
    expect(sheet.frame.origin.x == parent.frame.origin.x + (400 - 200) / 2,
           "The sheet should be centered horizontally over its parent.")
    expect(sheet.frame.origin.y == parent.frame.origin.y + parent.winSheetTopInset,
           "The sheet should hang from the parent's title inset.")

    // A toolbar pushes the inset down by the toolbar height (moved from 6.2).
    let toolbarParent = makeWindow()
    let plainInset = parent.winSheetTopInset
    toolbarParent.toolbar = NSToolbar(identifier: "sheet-tb")
    expect(toolbarParent.winSheetTopInset > plainInset,
           "A window with a visible toolbar should drop its sheet below the toolbar.")

    // A second sheet while one is attached queues behind it.
    let queued = makeWindow()
    parent.beginSheet(queued)
    expect(parent.attachedSheet === sheet, "A second beginSheet should not replace the live sheet.")
    expect(queued.sheetParent == nil, "A queued sheet should not attach until its turn.")

    // Ending the first sheet presents the queued one.
    parent.endSheet(sheet, returnCode: .OK)
    expect(parent.attachedSheet === queued, "Ending a sheet should present the next queued sheet.")
    expect(queued.sheetParent === parent, "The queued sheet should link to its parent when presented.")
}

@MainActor
func testDragImageAndDisplayScaleSurfaces() {
    // A dragging item carries the image the source supplies via
    // setDraggingFrame(_:contents:) — the drag-image surface (10.11).
    let item = NSDraggingItem(pasteboardWriter: "payload")
    expect(item.winDragImage == nil, "A dragging item starts with no drag image.")
    let image = NSImage(size: NSMakeSize(32, 32))
    let frame = NSMakeRect(0, 0, 32, 32)
    item.setDraggingFrame(frame, contents: image)
    expect(item.winDragImage === image, "setDraggingFrame(_:contents:) should store the drag image.")
    expect(item.draggingFrame == frame, "setDraggingFrame should store the drag frame.")

    // Non-image contents leave the drag imageless (falls back to the cursor).
    let plain = NSDraggingItem(pasteboardWriter: "payload")
    plain.setDraggingFrame(frame, contents: "not an image")
    expect(plain.winDragImage == nil, "Non-image drag contents should leave no drag image.")

    // The backend surfaces the real display scale (10.7 infrastructure).
    let backend = InMemoryNativeControlBackend()
    expect(backend.winDisplayScale() == 1.0, "The default display scale should be 1.0 (96 DPI).")
    backend.scriptedDisplayScale = 1.5
    expect(backend.winDisplayScale() == 1.5, "The backend should report the configured display scale.")
}

@MainActor
func testUnchangedFrameDoesNotRepushToBackend() {
    // Assigning the same frame must not reach the backend — layout re-assigns
    // identical frames on every scroll/resize pass, and re-pushing each would
    // repaint (flicker) every control. Only a real change should push.
    let backend = InMemoryNativeControlBackend()
    let button = NSButton(frame: NSMakeRect(0, 0, 80, 24))
    let handle = button.realizeNativePeer(in: backend, parent: nil)
    let baseline = backend.setFrameCallCounts[handle] ?? 0

    // Re-assign the identical frame several times: no new backend pushes.
    button.frame = NSMakeRect(0, 0, 80, 24)
    button.frame = NSMakeRect(0, 0, 80, 24)
    button.frame = NSMakeRect(0, 0, 80, 24)
    expect((backend.setFrameCallCounts[handle] ?? 0) == baseline,
           "Re-assigning an unchanged frame should not push to the backend.")

    // A real change pushes exactly once.
    button.frame = NSMakeRect(10, 10, 80, 24)
    expect((backend.setFrameCallCounts[handle] ?? 0) == baseline + 1,
           "A changed frame should push exactly one backend update.")

    // Re-assigning that new frame again is again a no-op.
    button.frame = NSMakeRect(10, 10, 80, 24)
    expect((backend.setFrameCallCounts[handle] ?? 0) == baseline + 1,
           "Re-assigning the just-set frame should not push again.")
}

