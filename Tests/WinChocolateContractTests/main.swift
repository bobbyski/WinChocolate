import WinChocolate

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fatalError(message)
    }
}

func clearApplicationWindows() {
    for window in NSApplication.shared.windows {
        NSApplication.shared.removeWindowsItem(window)
    }
}

func testWindowRealizationCreatesNativeHierarchy() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(10, 20, 320, 240),
        styleMask: [.titled, .closable, .resizable],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    window.title = "Chocolate"

    let contentView = NSView(frame: NSMakeRect(0, 0, 320, 240))
    let button = NSButton(title: "OK", frame: NSMakeRect(20, 20, 80, 30))
    contentView.addSubview(button)
    window.contentView = contentView

    let windowHandle = window.realizeNativePeer()

    expect(backend.records[windowHandle]?.kind == "window", "Window native record was not created.")
    expect(backend.records[windowHandle]?.text == "Chocolate", "Window title was not recorded.")
    expect(contentView.nativeHandle != nil, "Content view was not realized.")
    expect(button.nativeHandle != nil, "Button was not realized.")
    expect(backend.records[button.nativeHandle!]?.kind == "button", "Button native record was not created.")
    expect(backend.records[button.nativeHandle!]?.parent == contentView.nativeHandle, "Button parent was not content view.")
}

func testViewHierarchyMaintainsSuperviewOwnership() {
    let firstParent = NSView(frame: NSMakeRect(0, 0, 100, 100))
    let secondParent = NSView(frame: NSMakeRect(0, 0, 100, 100))
    let child = NSView(frame: NSMakeRect(0, 0, 20, 20))

    firstParent.addSubview(child)
    secondParent.addSubview(child)

    expect(firstParent.subviews.isEmpty, "Child remained in old parent.")
    expect(secondParent.subviews.count == 1, "Child was not added to new parent.")
    expect(child.superview === secondParent, "Child superview was not updated.")
}

func testViewInsertionReplacementTagsAndDescendants() {
    let parent = NSView(frame: NSMakeRect(0, 0, 200, 200))
    let first = NSView(frame: NSMakeRect(0, 0, 20, 20))
    let second = NSView(frame: NSMakeRect(0, 0, 20, 20))
    let belowSecond = NSView(frame: NSMakeRect(0, 0, 20, 20))
    let aboveFirst = NSView(frame: NSMakeRect(0, 0, 20, 20))
    let replacement = NSView(frame: NSMakeRect(0, 0, 20, 20))

    first.tag = 11
    replacement.tag = 22

    parent.addSubview(first)
    parent.addSubview(second)
    parent.addSubview(belowSecond, positioned: .below, relativeTo: second)
    parent.addSubview(aboveFirst, positioned: .above, relativeTo: first)

    expect(parent.subviews.count == 4, "Positioned subviews were not added.")
    expect(parent.subviews[0] === first, "First subview moved unexpectedly.")
    expect(parent.subviews[1] === aboveFirst, "Subview was not inserted above the reference view.")
    expect(parent.subviews[2] === belowSecond, "Subview was not inserted below the reference view.")
    expect(parent.subviews[3] === second, "Second subview moved unexpectedly.")
    expect(aboveFirst.isDescendant(of: parent), "Subview did not report descendant relationship.")
    expect(!parent.isDescendant(of: aboveFirst), "Ancestor reported descendant relationship.")
    expect(parent.viewWithTag(11) === first, "viewWithTag did not find existing tagged view.")

    parent.replaceSubview(first, with: replacement)

    expect(parent.subviews[0] === replacement, "Replacement did not preserve subview position.")
    expect(first.superview == nil, "Replaced view still had a superview.")
    expect(replacement.superview === parent, "Replacement superview was not updated.")
    expect(parent.viewWithTag(22) === replacement, "viewWithTag did not find replacement view.")
}

func testViewCompatibilityMetadataStoresValues() {
    let view = NSView(frame: NSMakeRect(0, 0, 100, 100))

    view.autoresizingMask = [.width, .height]
    view.autoresizesSubviews = false
    view.wantsLayer = true
    view.toolTip = "Hello"

    expect(view.autoresizingMask.contains(.width), "Autoresizing width mask was not stored.")
    expect(view.autoresizingMask.contains(.height), "Autoresizing height mask was not stored.")
    expect(!view.autoresizesSubviews, "autoresizesSubviews was not stored.")
    expect(view.wantsLayer, "wantsLayer was not stored.")
    expect(view.toolTip == "Hello", "toolTip was not stored.")
}

func testGeometryConvenienceFunctions() {
    let rect = NSMakeRect(10, 20, 100, 50)

    expect(NSZeroPoint == NSMakePoint(0, 0), "NSZeroPoint was not zero.")
    expect(NSZeroSize == NSMakeSize(0, 0), "NSZeroSize was not zero.")
    expect(NSZeroRect == NSMakeRect(0, 0, 0, 0), "NSZeroRect was not zero.")
    expect(NSMinX(rect) == 10, "NSMinX returned the wrong value.")
    expect(NSMidX(rect) == 60, "NSMidX returned the wrong value.")
    expect(NSMaxX(rect) == 110, "NSMaxX returned the wrong value.")
    expect(NSMinY(rect) == 20, "NSMinY returned the wrong value.")
    expect(NSMidY(rect) == 45, "NSMidY returned the wrong value.")
    expect(NSMaxY(rect) == 70, "NSMaxY returned the wrong value.")
    expect(NSWidth(rect) == 100, "NSWidth returned the wrong value.")
    expect(NSHeight(rect) == 50, "NSHeight returned the wrong value.")
    expect(NSPointInRect(NSMakePoint(10, 20), rect), "NSPointInRect rejected the minimum edge.")
    expect(!NSPointInRect(NSMakePoint(110, 70), rect), "NSPointInRect included the maximum edge.")
    expect(NSOffsetRect(rect, 3, 4) == NSMakeRect(13, 24, 100, 50), "NSOffsetRect returned the wrong rect.")
    expect(NSInsetRect(rect, 5, 6) == NSMakeRect(15, 26, 90, 38), "NSInsetRect returned the wrong rect.")
    expect(NSEqualRects(rect, NSMakeRect(10, 20, 100, 50)), "NSEqualRects rejected equal rects.")
}

func testViewCoordinateConversionAndHitTesting() {
    let root = NSView(frame: NSMakeRect(0, 0, 300, 300))
    let parent = NSView(frame: NSMakeRect(20, 30, 200, 200))
    let child = NSView(frame: NSMakeRect(5, 7, 40, 50))
    let hiddenChild = NSView(frame: NSMakeRect(6, 8, 10, 10))

    root.addSubview(parent)
    parent.addSubview(child)
    child.addSubview(hiddenChild)
    hiddenChild.isHidden = true

    expect(child.convert(NSMakePoint(1, 2), to: root) == NSMakePoint(26, 39), "Point conversion to ancestor failed.")
    expect(root.convert(NSMakePoint(26, 39), to: child) == NSMakePoint(1, 2), "Point conversion from ancestor failed.")
    expect(parent.convert(NSMakeRect(1, 2, 10, 11), from: child) == NSMakeRect(6, 9, 10, 11), "Rect conversion from child failed.")
    expect(root.hitTest(NSMakePoint(26, 39)) === child, "Hit testing did not return deepest visible child.")
    expect(root.hitTest(NSMakePoint(31, 46)) === child, "Hit testing returned hidden child.")
    expect(root.hitTest(NSMakePoint(250, 250)) === root, "Hit testing did not return root for empty visible area.")
    expect(root.hitTest(NSMakePoint(400, 400)) == nil, "Hit testing accepted a point outside bounds.")
}

func testScrollViewHostsDocumentView() {
    let scrollView = NSScrollView(frame: NSMakeRect(0, 0, 200, 120))
    let documentView = NSView(frame: NSMakeRect(0, 0, 180, 240))

    scrollView.hasVerticalScroller = true
    scrollView.documentView = documentView

    expect(scrollView.subviews.count == 1, "Scroll view did not add document view as subview.")
    expect(scrollView.subviews.first === documentView, "Scroll view subview was not the document view.")
    expect(documentView.superview === scrollView, "Document view superview was not the scroll view.")
}

func testScrollViewUsesNativePeerAndRealizesDocumentView() {
    let backend = InMemoryNativeControlBackend()
    let scrollView = NSScrollView(frame: NSMakeRect(0, 0, 200, 120))
    let documentView = NSView(frame: NSMakeRect(0, 0, 180, 240))

    scrollView.hasVerticalScroller = true
    scrollView.documentView = documentView

    let handle = scrollView.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "scrollView", "Scroll view did not request native scroll peer.")
    expect(documentView.nativeHandle != nil, "Scroll view did not realize document view.")
    expect(backend.records[documentView.nativeHandle!]?.parent == handle, "Document view native parent was not scroll view.")
}

final class RecordingResponder: NSResponder {
    var mouseDownCount = 0
    var keyDownCount = 0

    override func mouseDown(with event: NSEvent) {
        mouseDownCount += 1
    }

    override func keyDown(with event: NSEvent) {
        keyDownCount += 1
    }
}

final class RefusingResponder: NSResponder {
    override var acceptsFirstResponder: Bool {
        true
    }

    override func resignFirstResponder() -> Bool {
        false
    }
}

final class RecordingView: NSView {
    var mouseDownCount = 0
    var mouseUpCount = 0
    var mouseMovedCount = 0
    var keyDownCount = 0
    var keyUpCount = 0
    var lastEvent: NSEvent?

    override func mouseDown(with event: NSEvent) {
        mouseDownCount += 1
        lastEvent = event
    }

    override func mouseUp(with event: NSEvent) {
        mouseUpCount += 1
        lastEvent = event
    }

    override func mouseMoved(with event: NSEvent) {
        mouseMovedCount += 1
        lastEvent = event
    }

    override func keyDown(with event: NSEvent) {
        keyDownCount += 1
        lastEvent = event
    }

    override func keyUp(with event: NSEvent) {
        keyUpCount += 1
        lastEvent = event
    }
}

final class RecordingTableDataSource: NSTableViewDataSource {
    var rows: [[String]] = [
        ["Ada", "Compiler"],
        ["Grace", "Navy"],
        ["Katherine", "Orbit"]
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
        case "note":
            return rows[row][1]
        default:
            return nil
        }
    }

    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        guard rows.indices.contains(row) else {
            return
        }

        switch tableColumn?.identifier.rawValue {
        case "name":
            rows[row][0] = object.map { String(describing: $0) } ?? ""
        case "note":
            rows[row][1] = object.map { String(describing: $0) } ?? ""
        default:
            break
        }
    }
}

final class RecordingTableDelegate: NSTableViewDelegate {
    var selectionChangeCount = 0
    var lastObject: AnyObject?
    var requestedViewRows: [Int] = []
    var oldSortDescriptorCount = -1
    var rowHeights: [Int: CGFloat] = [:]
    var cellView = NSTableCellView(frame: NSMakeRect(0, 0, 100, 24))

    func tableViewSelectionDidChange(_ notification: NSNotification) {
        selectionChangeCount += 1
        lastObject = notification.object
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        requestedViewRows.append(row)
        return cellView
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        rowHeights[row] ?? tableView.rowHeight
    }

    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        oldSortDescriptorCount = oldDescriptors.count
    }
}

final class TabRecordingWindow: NSWindow {
    var nextSelectionCount = 0
    var previousSelectionCount = 0

    override func selectNextKeyView(_ sender: Any?) {
        nextSelectionCount += 1
        super.selectNextKeyView(sender)
    }

    override func selectPreviousKeyView(_ sender: Any?) {
        previousSelectionCount += 1
        super.selectPreviousKeyView(sender)
    }
}

func testCellStoresStringAndObjectValues() {
    let cell = NSTextFieldCell(textCell: "Header")

    expect(cell.stringValue == "Header", "Text cell did not store initial string.")

    cell.objectValue = 42

    expect(cell.stringValue == "42", "Text cell did not stringify object value.")

    cell.stringValue = "Updated"

    expect(cell.objectValue as? String == "Updated", "Text cell stringValue did not update objectValue.")
}

func testSortDescriptorStoresKeyDirectionAndReverse() {
    let descriptor = NSSortDescriptor(key: "name", ascending: true, selector: "compare:")
    let reversed = descriptor.reversedSortDescriptor

    expect(descriptor.key == "name", "Sort descriptor key was not stored.")
    expect(descriptor.ascending, "Sort descriptor ascending flag was not stored.")
    expect(descriptor.selector == "compare:", "Sort descriptor selector was not stored.")
    expect(reversed.key == "name", "Reversed sort descriptor did not preserve key.")
    expect(!reversed.ascending, "Reversed sort descriptor did not flip direction.")
    expect(reversed.selector == "compare:", "Reversed sort descriptor did not preserve selector.")
}

func testTableCellAndRowViewsStoreState() {
    let cellView = NSTableCellView(frame: NSMakeRect(0, 0, 120, 24))
    let textField = NSTextField.label(withString: "Cell")
    let rowView = NSTableRowView(frame: NSMakeRect(0, 0, 120, 24))

    cellView.objectValue = "Value"
    cellView.textField = textField
    rowView.isSelected = true
    rowView.isEmphasized = false
    rowView.selectionHighlightStyle = .sourceList
    rowView.shouldDrawSeparator = false

    expect(cellView.objectValue as? String == "Value", "Table cell view objectValue was not stored.")
    expect(cellView.textField === textField, "Table cell view textField was not stored.")
    expect(textField.superview === cellView, "Table cell view did not host textField.")
    expect(rowView.isSelected, "Table row view selected state was not stored.")
    expect(!rowView.isEmphasized, "Table row view emphasized state was not stored.")
    expect(rowView.selectionHighlightStyle == .sourceList, "Table row view highlight style was not stored.")
    expect(!rowView.shouldDrawSeparator, "Table row view separator state was not stored.")
}

func testTableColumnStoresAppKitIdentifierShape() {
    let column = NSTableColumn(identifier: "name")
    let dataCell = NSTextFieldCell(textCell: "Data")
    let sortDescriptor = NSSortDescriptor(key: "name", ascending: true)

    column.title = "Name"
    column.width = 160
    column.minWidth = 40
    column.maxWidth = 400
    column.isEditable = true
    column.resizingMask = [.userResizingMask]
    column.setDataCell(dataCell)
    column.sortDescriptorPrototype = sortDescriptor

    expect(column.identifier == NSUserInterfaceItemIdentifier("name"), "Table column identifier was not stored.")
    expect(column.title == "Name", "Table column title was not stored.")
    expect(column.headerCell.stringValue == "Name", "Table column title did not update header cell.")
    expect(column.width == 160, "Table column width was not stored.")
    expect(column.minWidth == 40, "Table column min width was not stored.")
    expect(column.maxWidth == 400, "Table column max width was not stored.")
    expect(column.isEditable, "Table column editability was not stored.")
    expect(column.resizingMask == [.userResizingMask], "Table column resizing mask was not stored.")
    expect(column.dataCell === dataCell, "Table column data cell was not stored.")
    expect(column.sortDescriptorPrototype === sortDescriptor, "Table column sort descriptor prototype was not stored.")
}

func testTableViewReloadsRowsFromDataSource() {
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 160))
    let dataSource = RecordingTableDataSource()
    let name = NSTableColumn(identifier: "name")
    let note = NSTableColumn(identifier: "note")

    name.title = "Name"
    note.title = "Note"
    tableView.addTableColumn(name)
    tableView.addTableColumn(note)
    tableView.dataSource = dataSource
    tableView.reloadData()

    expect(tableView.numberOfColumns == 2, "Table view column count was wrong.")
    expect(tableView.numberOfRows == 3, "Table view row count was wrong.")
    expect(tableView.tableColumn(withIdentifier: "note") === note, "Table column identifier lookup failed.")
    expect(tableView.tableColumn(at: 0) === name, "Table column index lookup failed.")
    expect(tableView.column(withIdentifier: "note") == 1, "Table column index lookup by identifier failed.")
    expect(tableView.value(atColumn: 0, row: 1) == "Grace", "Table view did not load first column value.")
    expect(tableView.value(atColumn: 1, row: 2) == "Orbit", "Table view did not load second column value.")
    expect(tableView.value(for: note, row: 0) == "Compiler", "Table view did not load value for table column.")
}

func testTableViewColumnMovementAndRemoval() {
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 160))
    let first = NSTableColumn(identifier: "first")
    let second = NSTableColumn(identifier: "second")
    let third = NSTableColumn(identifier: "third")

    tableView.addTableColumn(first)
    tableView.addTableColumn(second)
    tableView.addTableColumn(third)
    tableView.moveColumn(0, toColumn: 2)

    expect(tableView.tableColumn(at: 0) === second, "moveColumn did not shift second column into first position.")
    expect(tableView.tableColumn(at: 2) === first, "moveColumn did not move first column to requested position.")

    tableView.removeTableColumn(second)

    expect(tableView.numberOfColumns == 2, "removeTableColumn did not remove a column.")
    expect(tableView.column(withIdentifier: "second") == -1, "Removed table column was still found.")
}

func testTableViewSelectionOptionsAndHelpers() {
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 160))
    let dataSource = RecordingTableDataSource()
    let name = NSTableColumn(identifier: "name")

    tableView.addTableColumn(name)
    tableView.dataSource = dataSource
    tableView.reloadData()

    tableView.allowsEmptySelection = false
    tableView.selectRowIndexes([1], byExtendingSelection: false)
    tableView.deselectAll(nil)

    expect(tableView.selectedRow == 1, "Table view allowed empty selection when disabled.")

    tableView.allowsEmptySelection = true
    tableView.deselectAll(nil)

    expect(tableView.selectedRow == -1, "Table view did not clear selection.")

    tableView.allowsMultipleSelection = true
    tableView.selectRowIndexes([0], byExtendingSelection: false)
    tableView.selectRowIndexes([2], byExtendingSelection: true)

    expect(tableView.isRowSelected(0), "Table view did not keep extended row selection.")
    expect(tableView.isRowSelected(2), "Table view did not add extended row selection.")
    expect(tableView.numberOfSelectedRows == 2, "Table view selected row count was wrong.")

    tableView.deselectRow(0)

    expect(!tableView.isRowSelected(0), "Table view did not deselect a row.")
    expect(tableView.selectedRow == 2, "Table view selected row was not updated after deselect.")

    tableView.selectAll(nil)

    expect(tableView.numberOfSelectedRows == 3, "Table view selectAll did not select all rows.")
}

func testTableViewStoresDisplayOptionsAndSetObjectValue() {
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 160))
    let dataSource = RecordingTableDataSource()
    let note = NSTableColumn(identifier: "note")

    tableView.addTableColumn(note)
    tableView.dataSource = dataSource
    tableView.rowHeight = 24
    tableView.intercellSpacing = NSMakeSize(4, 5)
    tableView.gridStyleMask = [.solidHorizontalGridLineMask, .solidVerticalGridLineMask]
    tableView.selectionHighlightStyle = .sourceList
    tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
    tableView.allowsColumnReordering = true
    tableView.allowsColumnResizing = false
    tableView.reloadData()
    tableView.setObjectValue("Updated", for: note, row: 1)

    expect(tableView.rowHeight == 24, "Table rowHeight was not stored.")
    expect(tableView.intercellSpacing == NSMakeSize(4, 5), "Table intercellSpacing was not stored.")
    expect(tableView.gridStyleMask.contains(.solidHorizontalGridLineMask), "Table horizontal grid style was not stored.")
    expect(tableView.gridStyleMask.contains(.solidVerticalGridLineMask), "Table vertical grid style was not stored.")
    expect(tableView.selectionHighlightStyle == .sourceList, "Table selection highlight style was not stored.")
    expect(tableView.columnAutoresizingStyle == .lastColumnOnlyAutoresizingStyle, "Table autoresizing style was not stored.")
    expect(tableView.allowsColumnReordering, "Table column reordering flag was not stored.")
    expect(!tableView.allowsColumnResizing, "Table column resizing flag was not stored.")
    expect(tableView.value(atColumn: 0, row: 1) == "Updated", "Table setObjectValue did not update through data source.")
}

func testTableViewDelegateViewHeightAndSortHooks() {
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 160))
    let dataSource = RecordingTableDataSource()
    let delegate = RecordingTableDelegate()
    let name = NSTableColumn(identifier: "name")
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
    tableView.previousKeyView = nextButton
    nextButton.nextKeyView = tableView
    nextButton.previousKeyView = tableView
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

func testTableViewKeyboardNavigationUpdatesSelection() {
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 160))
    let dataSource = RecordingTableDataSource()
    let delegate = RecordingTableDelegate()
    let name = NSTableColumn(identifier: "name")

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

func testTableViewKeyboardExtendedSelection() {
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 160))
    let dataSource = RecordingTableDataSource()
    let name = NSTableColumn(identifier: "name")

    tableView.addTableColumn(name)
    tableView.dataSource = dataSource
    tableView.allowsMultipleSelection = true
    tableView.reloadData()
    tableView.selectRowIndexes([0], byExtendingSelection: false)
    tableView.keyDown(with: NSEvent(type: .keyDown, locationInWindow: NSZeroPoint, keyCode: 0x28, modifierFlags: [.shift]))

    expect(tableView.selectedRowIndexes == [0, 1], "Shift-Down did not extend table selection.")
}

func testTableViewColumnSelectionAndDoubleActionSurface() {
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 160))
    let dataSource = RecordingTableDataSource()
    let name = NSTableColumn(identifier: "name")
    let note = NSTableColumn(identifier: "note")
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
    tableView.onDoubleAction = { table in
        expect(table === tableView, "Table double-action sender was not table view.")
        doubleActionCount += 1
    }
    tableView.sendDoubleAction()
    tableView.deselectColumn(0)

    expect(tableView.isColumnSelected(1), "Table did not keep extended column selection.")
    expect(!tableView.isColumnSelected(0), "Table did not deselect column.")
    expect(tableView.numberOfSelectedColumns == 1, "Table selected column count was wrong.")
    expect(tableView.doubleAction == "doubleClick:", "Table doubleAction selector was not stored.")
    expect(doubleActionCount == 1, "Table double action callback was not sent.")

    tableView.allowsColumnSelection = false

    expect(tableView.numberOfSelectedColumns == 0, "Disabling column selection did not clear selected columns.")
}

func testTableViewSortDescriptorPrototypeToggle() {
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 160))
    let dataSource = RecordingTableDataSource()
    let name = NSTableColumn(identifier: "name")
    let note = NSTableColumn(identifier: "note")
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

func testSliderStoresRangeValueAndSyncsNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let slider = NSSlider(value: 25, minValue: 0, maxValue: 100, target: nil, action: "sliderChanged:")
    slider.frame = NSMakeRect(0, 0, 240, 24)

    expect(slider.minValue == 0, "Slider minValue was not stored.")
    expect(slider.maxValue == 100, "Slider maxValue was not stored.")
    expect(slider.doubleValue == 25, "Slider doubleValue was not stored.")
    expect(slider.intValue == 25, "Slider intValue did not follow doubleValue.")
    expect(slider.action == "sliderChanged:", "Slider action selector was not stored.")

    let handle = slider.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "slider", "Slider did not request a native slider peer.")
    expect(backend.records[handle]?.sliderMinValue == 0, "Slider minValue was not synced to native backend.")
    expect(backend.records[handle]?.sliderMaxValue == 100, "Slider maxValue was not synced to native backend.")
    expect(backend.records[handle]?.sliderValue == 25, "Slider value was not synced to native backend.")

    slider.doubleValue = 140
    expect(slider.doubleValue == 100, "Slider did not clamp value to maxValue.")
    expect(backend.records[handle]?.sliderValue == 100, "Slider clamped value was not synced to native backend.")

    slider.minValue = 20
    slider.maxValue = 80
    slider.intValue = 10
    expect(slider.doubleValue == 20, "Slider did not clamp intValue to minValue.")
    expect(backend.records[handle]?.sliderMinValue == 20, "Slider updated minValue was not synced to native backend.")
    expect(backend.records[handle]?.sliderMaxValue == 80, "Slider updated maxValue was not synced to native backend.")
}

func testSliderNativeActionUpdatesValue() {
    let backend = InMemoryNativeControlBackend()
    let slider = NSSlider(value: 1, minValue: 0, maxValue: 10, target: nil, action: nil)
    var actionCount = 0
    slider.onAction = { control in
        guard let slider = control as? NSSlider else {
            expect(false, "Slider action sender was not slider.")
            return
        }

        actionCount += 1
        expect(slider.doubleValue == 7, "Slider action did not read native value.")
    }

    let handle = slider.realizeNativePeer(in: backend, parent: nil)
    backend.setSliderValue(7, for: handle)
    backend.actions[handle]?()

    expect(actionCount == 1, "Slider native action was not dispatched.")
}

func testProgressIndicatorStoresRangeValueAndSyncsNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let progress = NSProgressIndicator(frame: NSMakeRect(0, 0, 240, 16))
    progress.minValue = 0
    progress.maxValue = 100
    progress.doubleValue = 30

    expect(progress.doubleValue == 30, "Progress indicator doubleValue was not stored.")
    expect(progress.minValue == 0, "Progress indicator minValue was not stored.")
    expect(progress.maxValue == 100, "Progress indicator maxValue was not stored.")

    let handle = progress.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "progressIndicator", "Progress indicator did not request native peer.")
    expect(backend.records[handle]?.progressMinValue == 0, "Progress indicator minValue was not synced.")
    expect(backend.records[handle]?.progressMaxValue == 100, "Progress indicator maxValue was not synced.")
    expect(backend.records[handle]?.progressValue == 30, "Progress indicator value was not synced.")

    progress.increment(by: 90)
    expect(progress.doubleValue == 100, "Progress indicator did not clamp increment to maxValue.")
    expect(backend.records[handle]?.progressValue == 100, "Progress indicator clamped value was not synced.")

    progress.startAnimation(nil)
    expect(progress.isAnimating, "Progress indicator did not store animation state.")
    progress.stopAnimation(nil)
    expect(!progress.isAnimating, "Progress indicator did not stop animation state.")
}

func testStepperStoresRangeIncrementAndSyncsNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let stepper = NSStepper(frame: NSMakeRect(0, 0, 24, 48))
    stepper.minValue = 0
    stepper.maxValue = 10
    stepper.increment = 2
    stepper.doubleValue = 4

    expect(stepper.doubleValue == 4, "Stepper doubleValue was not stored.")
    expect(stepper.intValue == 4, "Stepper intValue did not reflect doubleValue.")
    expect(stepper.minValue == 0, "Stepper minValue was not stored.")
    expect(stepper.maxValue == 10, "Stepper maxValue was not stored.")
    expect(stepper.increment == 2, "Stepper increment was not stored.")

    let handle = stepper.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "stepper", "Stepper did not request native peer.")
    expect(backend.records[handle]?.stepperMinValue == 0, "Stepper minValue was not synced.")
    expect(backend.records[handle]?.stepperMaxValue == 10, "Stepper maxValue was not synced.")
    expect(backend.records[handle]?.stepperIncrement == 2, "Stepper increment was not synced.")
    expect(backend.records[handle]?.stepperValue == 4, "Stepper value was not synced.")

    stepper.doubleValue = 20
    expect(stepper.doubleValue == 10, "Stepper did not clamp value to maxValue.")
    expect(backend.records[handle]?.stepperValue == 10, "Stepper clamped value was not synced.")

    stepper.valueWraps = true
    stepper.stepUp(nil)
    expect(stepper.doubleValue == 0, "Stepper did not wrap upward to minValue.")
    stepper.stepDown(nil)
    expect(stepper.doubleValue == 10, "Stepper did not wrap downward to maxValue.")
}

func testStepperNativeActionUpdatesValue() {
    let backend = InMemoryNativeControlBackend()
    let stepper = NSStepper(frame: NSMakeRect(0, 0, 24, 48))
    stepper.minValue = 0
    stepper.maxValue = 10
    stepper.doubleValue = 1
    var actionCount = 0
    stepper.onAction = { control in
        guard let stepper = control as? NSStepper else {
            expect(false, "Stepper action sender was not stepper.")
            return
        }

        actionCount += 1
        expect(stepper.doubleValue == 7, "Stepper action did not read native value.")
    }

    let handle = stepper.realizeNativePeer(in: backend, parent: nil)
    backend.setStepperValue(7, for: handle)
    backend.actions[handle]?()

    expect(actionCount == 1, "Stepper native action was not dispatched.")
}

func testTableViewNativePeerReceivesColumnsRowsAndSelection() {
    let backend = InMemoryNativeControlBackend()
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 160))
    let dataSource = RecordingTableDataSource()
    let name = NSTableColumn(identifier: "name")
    let note = NSTableColumn(identifier: "note")

    name.title = "Name"
    note.title = "Note"
    tableView.addTableColumn(name)
    tableView.addTableColumn(note)
    tableView.dataSource = dataSource
    tableView.reloadData()
    tableView.selectRowIndexes([1], byExtendingSelection: false)

    let handle = tableView.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "tableView", "Table view did not request native table peer.")
    expect(backend.records[handle]?.tableColumns == ["Name", "Note"], "Table columns were not synced to backend.")
    expect(backend.records[handle]?.tableRows == [["Ada", "Compiler"], ["Grace", "Navy"], ["Katherine", "Orbit"]], "Table rows were not synced to backend.")
    expect(backend.records[handle]?.tableSelectedRow == 1, "Table selection was not synced to backend.")
    expect(tableView.selectedRowIndexes == [1], "Table selectedRowIndexes was not updated.")
}

func testTableViewNativeSelectionNotifiesDelegateAndAction() {
    let backend = InMemoryNativeControlBackend()
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 160))
    let dataSource = RecordingTableDataSource()
    let delegate = RecordingTableDelegate()
    let name = NSTableColumn(identifier: "name")
    var actionCount = 0
    var callbackCount = 0

    tableView.addTableColumn(name)
    tableView.dataSource = dataSource
    tableView.delegate = delegate
    tableView.onAction = { control in
        expect(control === tableView, "Table action sender was not table view.")
        actionCount += 1
    }
    tableView.onSelectionChanged = { table in
        expect(table === tableView, "Table selection callback sender was not table view.")
        callbackCount += 1
    }
    tableView.reloadData()

    let handle = tableView.realizeNativePeer(in: backend, parent: nil)
    backend.setTableSelectedRow(2, for: handle)
    backend.actions[handle]?()

    expect(tableView.selectedRow == 2, "Table view did not read native selection.")
    expect(actionCount == 1, "Table view did not send action after selection.")
    expect(callbackCount == 1, "Table view did not invoke selection callback.")
    expect(delegate.selectionChangeCount == 1, "Table view delegate was not notified.")
    expect(delegate.lastObject === tableView, "Table view delegate notification object was wrong.")
}

func testTableViewActionCanReadSelectedRowValue() {
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 160))
    let dataSource = RecordingTableDataSource()
    let name = NSTableColumn(identifier: "name")
    var actionRow = -1
    var actionValue: String?

    tableView.addTableColumn(name)
    tableView.dataSource = dataSource
    tableView.reloadData()
    tableView.selectRowIndexes([1], byExtendingSelection: false)
    tableView.onAction = { control in
        guard let table = control as? NSTableView else {
            return
        }

        actionRow = table.selectedRow
        actionValue = table.value(atColumn: 0, row: actionRow)
    }
    tableView.keyDown(with: NSEvent(type: .keyDown, locationInWindow: NSZeroPoint, keyCode: 0x20))

    expect(actionRow == 1, "Table action could not read selected row.")
    expect(actionValue == "Grace", "Table action could not read selected row value.")
}

func testTableViewClickedRowAndColumnFollowSelection() {
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 160))
    let dataSource = RecordingTableDataSource()
    let name = NSTableColumn(identifier: "name")
    let note = NSTableColumn(identifier: "note")

    tableView.addTableColumn(name)
    tableView.addTableColumn(note)
    tableView.dataSource = dataSource
    tableView.reloadData()

    expect(tableView.clickedRow == -1, "Table clickedRow should default to -1.")
    expect(tableView.clickedColumn == -1, "Table clickedColumn should default to -1.")

    tableView.selectRowIndexes([2], byExtendingSelection: false)

    expect(tableView.clickedRow == 2, "Table clickedRow did not follow selected row.")
    expect(tableView.clickedColumn == 0, "Table clickedColumn did not follow selected column.")
}

func testSubviewResponderChainTargetsSuperview() {
    let parent = NSView(frame: NSMakeRect(0, 0, 100, 100))
    let child = NSView(frame: NSMakeRect(0, 0, 20, 20))

    parent.addSubview(child)

    expect(child.nextResponder === parent, "Subview next responder was not its superview.")

    child.removeFromSuperview()

    expect(child.nextResponder == nil, "Subview next responder was not cleared on removal.")
}

func testResponderForwardsUnhandledEvents() {
    let child = NSResponder()
    let parent = RecordingResponder()
    let mouseEvent = NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(4, 5))
    let keyEvent = NSEvent(type: .keyDown, locationInWindow: NSMakePoint(0, 0))

    child.nextResponder = parent
    child.mouseDown(with: mouseEvent)
    child.keyDown(with: keyEvent)

    expect(parent.mouseDownCount == 1, "Mouse event did not forward to next responder.")
    expect(parent.keyDownCount == 1, "Key event did not forward to next responder.")
}

func testWindowIsContentViewNextResponder() {
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 100, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: InMemoryNativeControlBackend()
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 100, 100))

    window.contentView = contentView

    expect(contentView.nextResponder === window, "Window was not content view's next responder.")
}

func testWindowMakeFirstResponderFocusesNativeView() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 100, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 100, 100))

    window.contentView = contentView
    window.realizeNativePeer()

    expect(window.makeFirstResponder(contentView), "Window did not accept content view as first responder.")
    expect(window.firstResponder === contentView, "Window first responder was not updated.")
    expect(backend.focusedHandle == contentView.nativeHandle, "Backend did not receive native focus request.")
}

func testWindowMakeFirstResponderHonorsResignFailure() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 100, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let refusing = RefusingResponder()
    let next = NSView(frame: NSMakeRect(0, 0, 10, 10))

    expect(window.makeFirstResponder(refusing), "Window did not accept initial responder.")
    expect(!window.makeFirstResponder(next), "Window ignored first responder resign failure.")
    expect(window.firstResponder === refusing, "Window first responder changed after resign failure.")
}

func testApplicationTracksWindowListAndKeyMainWindow() {
    clearApplicationWindows()

    let first = NSWindow(
        contentRect: NSMakeRect(0, 0, 100, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: InMemoryNativeControlBackend()
    )
    let second = NSWindow(
        contentRect: NSMakeRect(0, 0, 100, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: InMemoryNativeControlBackend()
    )

    first.realizeNativePeer()
    second.realizeNativePeer()
    second.makeKeyAndOrderFront(nil)

    expect(NSApp === NSApplication.shared, "NSApp did not alias NSApplication.shared.")
    expect(NSApplication.shared.windows.contains { $0 === first }, "Application did not track first window.")
    expect(NSApplication.shared.windows.contains { $0 === second }, "Application did not track second window.")
    expect(NSApplication.shared.keyWindow === second, "Application key window was not updated.")
    expect(NSApplication.shared.mainWindow === second, "Application main window was not updated.")
    expect(second.isKeyWindow, "Window did not report key window state.")
    expect(second.isMainWindow, "Window did not report main window state.")

    second.close()

    expect(NSApplication.shared.keyWindow == nil, "Closing key window did not clear application key window.")
    expect(NSApplication.shared.mainWindow == nil, "Closing main window did not clear application main window.")
    expect(!NSApplication.shared.windows.contains { $0 === second }, "Closing window did not remove it from application windows.")

    clearApplicationWindows()
}

func testWindowSelectNextAndPreviousKeyView() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 100, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 100, 100))
    let first = NSButton(title: "First", frame: NSMakeRect(0, 0, 40, 20))
    let second = NSButton(title: "Second", frame: NSMakeRect(0, 24, 40, 20))

    first.nextKeyView = second
    second.previousKeyView = first
    contentView.addSubview(first)
    contentView.addSubview(second)
    window.contentView = contentView
    window.realizeNativePeer()

    expect(window.makeFirstResponder(first), "Window did not accept first key view.")

    window.selectNextKeyView(nil)

    expect(window.firstResponder === second, "Window did not select next key view.")
    expect(backend.focusedHandle == second.nativeHandle, "Backend focus did not move to next key view.")

    window.selectPreviousKeyView(nil)

    expect(window.firstResponder === first, "Window did not select previous key view.")
    expect(backend.focusedHandle == first.nativeHandle, "Backend focus did not move to previous key view.")
}

func testWindowSelectNextKeyViewSkipsDisabledExplicitTarget() {
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 100, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: InMemoryNativeControlBackend()
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 100, 100))
    let first = NSButton(title: "First", frame: NSMakeRect(0, 0, 40, 20))
    let disabled = NSButton(title: "Disabled", frame: NSMakeRect(0, 24, 60, 20))
    let fallback = NSButton(title: "Fallback", frame: NSMakeRect(0, 48, 60, 20))

    disabled.isEnabled = false
    first.nextKeyView = disabled
    disabled.nextKeyView = fallback
    contentView.addSubview(first)
    contentView.addSubview(disabled)
    contentView.addSubview(fallback)
    window.contentView = contentView
    window.realizeNativePeer()

    expect(window.makeFirstResponder(first), "Window did not accept first key view.")

    window.selectNextKeyView(nil)

    expect(window.firstResponder === fallback, "Window did not skip disabled key view target.")
}

func testNativeMouseDownDispatchesToView() {
    let backend = InMemoryNativeControlBackend()
    let view = RecordingView(frame: NSMakeRect(0, 0, 100, 100))
    let handle = view.realizeNativePeer(in: backend, parent: nil)
    let event = NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(12, 34))

    backend.mouseDownActions[handle]?(event)

    expect(view.mouseDownCount == 1, "Native mouse-down action did not reach view.")
    expect(view.lastEvent == event, "Native mouse-down event was not forwarded intact.")
}

func testNativeMouseDownOnControlMakesControlFirstResponder() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 200, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 200, 100))
    let button = NSButton(title: "Click", frame: NSMakeRect(20, 20, 80, 24))

    contentView.addSubview(button)
    window.contentView = contentView
    window.realizeNativePeer()

    guard let handle = button.nativeHandle else {
        fatalError("Button did not realize.")
    }

    backend.mouseDownActions[handle]?(NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(2, 3)))

    expect(window.firstResponder === button, "Native mouse-down on control did not make it first responder.")
    expect(backend.focusedHandle == handle, "Native mouse-down on control did not request native focus.")
}

func testNativeMouseUpDispatchesToView() {
    let backend = InMemoryNativeControlBackend()
    let view = RecordingView(frame: NSMakeRect(0, 0, 100, 100))
    let handle = view.realizeNativePeer(in: backend, parent: nil)
    let event = NSEvent(type: .leftMouseUp, locationInWindow: NSMakePoint(56, 78))

    backend.mouseUpActions[handle]?(event)

    expect(view.mouseUpCount == 1, "Native mouse-up action did not reach view.")
    expect(view.lastEvent == event, "Native mouse-up event was not forwarded intact.")
}

func testNativeMouseMovedDispatchesToView() {
    let backend = InMemoryNativeControlBackend()
    let view = RecordingView(frame: NSMakeRect(0, 0, 100, 100))
    let handle = view.realizeNativePeer(in: backend, parent: nil)
    let event = NSEvent(type: .mouseMoved, locationInWindow: NSMakePoint(7, 9), modifierFlags: [.shift])

    backend.mouseMovedActions[handle]?(event)

    expect(view.mouseMovedCount == 1, "Native mouse-moved action did not reach view.")
    expect(view.lastEvent == event, "Native mouse-moved event was not forwarded intact.")
}

func testNativeKeyDownDispatchesToView() {
    let backend = InMemoryNativeControlBackend()
    let view = RecordingView(frame: NSMakeRect(0, 0, 100, 100))
    let handle = view.realizeNativePeer(in: backend, parent: nil)
    let event = NSEvent(type: .keyDown, locationInWindow: NSMakePoint(0, 0), keyCode: 65, characters: "A", modifierFlags: [.shift])

    backend.keyDownActions[handle]?(event)

    expect(view.keyDownCount == 1, "Native key-down action did not reach view.")
    expect(view.lastEvent == event, "Native key-down event was not forwarded intact.")
}

func testNativeKeyUpDispatchesToView() {
    let backend = InMemoryNativeControlBackend()
    let view = RecordingView(frame: NSMakeRect(0, 0, 100, 100))
    let handle = view.realizeNativePeer(in: backend, parent: nil)
    let event = NSEvent(type: .keyUp, locationInWindow: NSMakePoint(0, 0), keyCode: 65, characters: "a")

    backend.keyUpActions[handle]?(event)

    expect(view.keyUpCount == 1, "Native key-up action did not reach view.")
    expect(view.lastEvent == event, "Native key-up event was not forwarded intact.")
}

func testControlClosureActionIsInvoked() {
    let button = NSButton(title: "Run", frame: NSMakeRect(0, 0, 80, 24))
    var actionCount = 0

    button.onAction = { control in
        expect(control === button, "Action control was not the sender.")
        actionCount += 1
    }

    button.sendAction()

    expect(actionCount == 1, "Action closure was not invoked once.")
}

func testButtonPerformClickHonorsEnabledState() {
    let button = NSButton(title: "Run", frame: NSMakeRect(0, 0, 80, 24))
    var actionCount = 0

    button.onAction = { _ in
        actionCount += 1
    }

    button.performClick(nil)
    button.isEnabled = false
    button.performClick(nil)

    expect(actionCount == 1, "Disabled button still sent its action.")
}

func testControlCompatibilityMetadataStoresValues() {
    let control = NSControl(frame: NSMakeRect(0, 0, 80, 24))

    control.objectValue = "Value"
    control.isContinuous = true

    expect(control.objectValue as? String == "Value", "Control objectValue was not stored.")
    expect(control.isContinuous, "Control continuous flag was not stored.")
}

func testSwitchButtonTogglesStateOnPerformClick() {
    let checkbox = NSButton(title: "Check", frame: NSMakeRect(0, 0, 120, 24))
    checkbox.setButtonType(.switchButton)

    checkbox.performClick(nil)
    expect(checkbox.state == .on, "Switch button did not toggle on.")

    checkbox.performClick(nil)
    expect(checkbox.state == .off, "Switch button did not toggle off.")
}

func testButtonMixedStateAndCompatibilityProperties() {
    let checkbox = NSButton(title: "Check", frame: NSMakeRect(0, 0, 120, 24))

    checkbox.setButtonType(.switchButton)
    checkbox.allowsMixedState = true
    checkbox.keyEquivalent = "\r"
    checkbox.isBordered = false

    checkbox.setNextState()
    expect(checkbox.state == .on, "Mixed-state button did not move from off to on.")
    checkbox.setNextState()
    expect(checkbox.state == .mixed, "Mixed-state button did not move from on to mixed.")
    checkbox.setNextState()
    expect(checkbox.state == .off, "Mixed-state button did not move from mixed to off.")
    expect(checkbox.keyEquivalent == "\r", "Button key equivalent was not stored.")
    expect(!checkbox.isBordered, "Button bordered flag was not stored.")
}

func testRadioButtonClearsSiblingRadioButtons() {
    let parent = NSView(frame: NSMakeRect(0, 0, 300, 100))
    let first = NSButton(title: "First", frame: NSMakeRect(0, 0, 80, 24))
    let second = NSButton(title: "Second", frame: NSMakeRect(90, 0, 80, 24))
    first.setButtonType(.radioButton)
    second.setButtonType(.radioButton)
    parent.addSubview(first)
    parent.addSubview(second)

    first.performClick(nil)
    second.performClick(nil)

    expect(first.state == .off, "First radio button was not cleared.")
    expect(second.state == .on, "Second radio button was not selected.")
}

func testRealizedViewStatePropagatesToBackend() {
    let backend = InMemoryNativeControlBackend()
    let view = NSView(frame: NSMakeRect(0, 0, 100, 100))
    let handle = view.realizeNativePeer(in: backend, parent: nil)

    view.frame = NSMakeRect(10, 20, 120, 140)
    view.isHidden = true

    expect(backend.records[handle]?.frame == NSMakeRect(10, 20, 120, 140), "Frame update did not reach backend.")
    expect(backend.records[handle]?.isHidden == true, "Hidden state did not reach backend.")
}

func testWindowTitleAndFramePropagateToBackend() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 100, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let handle = window.realizeNativePeer()

    window.title = "Updated"
    window.setFrame(NSMakeRect(10, 20, 300, 200), display: true)

    expect(backend.records[handle]?.text == "Updated", "Window title update did not reach backend.")
    expect(backend.records[handle]?.frame == NSMakeRect(10, 20, 300, 200), "Window frame update did not reach backend.")
}

func testWindowContentSizeAndCenterUpdateFrame() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(10, 20, 100, 80),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 100, 80))
    window.contentView = contentView
    let handle = window.realizeNativePeer()

    window.setContentSize(NSMakeSize(240, 160))

    expect(window.frame == NSMakeRect(10, 20, 240, 160), "setContentSize did not update window frame.")
    expect(contentView.frame == NSMakeRect(0, 0, 240, 160), "setContentSize did not update content view frame.")
    expect(window.contentLayoutRect == NSMakeRect(0, 0, 240, 160), "contentLayoutRect did not reflect content size.")
    expect(backend.records[handle]?.frame == NSMakeRect(10, 20, 240, 160), "setContentSize did not reach backend.")

    window.center()

    expect(window.frame == NSMakeRect(392, 304, 240, 160), "center did not use the expected default screen frame.")
    expect(backend.records[handle]?.frame == NSMakeRect(392, 304, 240, 160), "center did not reach backend.")
}

func testEditableTextFieldUsesEditableNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let textField = NSTextField(string: "Seed", frame: NSMakeRect(0, 0, 120, 24))
    textField.isEditable = true

    let handle = textField.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "editableTextField", "Editable text field did not request editable native peer.")
}

func testSecureTextFieldUsesSecureNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let secureField = NSSecureTextField(string: "Secret", frame: NSMakeRect(0, 0, 160, 24))

    expect(secureField.isEditable, "Secure text field should be editable by default.")
    expect(secureField.isSelectable, "Secure text field should be selectable by default.")

    let handle = secureField.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "secureTextField", "Secure text field did not request secure native peer.")
    expect(backend.records[handle]?.text == "Secret", "Secure text field initial string was not sent to backend.")

    secureField.stringValue = "Changed"
    expect(backend.records[handle]?.text == "Changed", "Secure text field changes did not sync to backend.")
}

func testTextViewUsesMultilineNativePeerAndStoresText() {
    let backend = InMemoryNativeControlBackend()
    let textView = NSTextView(frame: NSMakeRect(0, 0, 220, 80))
    textView.string = "Line one"
    textView.insertText("\nLine two")

    let handle = textView.realizeNativePeer(in: backend, parent: nil)

    expect(textView.string == "Line one\nLine two", "Text view did not store multiline text.")
    expect(textView.isEditable, "Text view should default to editable.")
    expect(textView.isSelectable, "Text view should default to selectable.")
    expect(backend.records[handle]?.kind == "editableTextView", "Text view did not request editable native peer.")
    expect(backend.records[handle]?.text == "Line one\nLine two", "Text view text was not synced to backend.")

    textView.setString("Reset")
    expect(backend.records[handle]?.text == "Reset", "Text view setString did not update backend.")
}

func testTextFieldFactoryConstructorsAndCompatibilityProperties() {
    let label = NSTextField.label(withString: "Label")
    let wrappingLabel = NSTextField.wrappingLabel(withString: "Wrapped")
    let textField = NSTextField.textField(withString: "Edit")
    let secureField = NSSecureTextField.secureTextField(withString: "Password")

    textField.placeholderString = "Placeholder"

    expect(label.stringValue == "Label", "Label factory did not set string.")
    expect(!label.isEditable, "Label factory created editable field.")
    expect(!label.isSelectable, "Label factory created selectable field.")
    expect(!label.isBordered, "Label factory created bordered field.")
    expect(!label.drawsBackground, "Label factory enabled background drawing.")
    expect(wrappingLabel.stringValue == "Wrapped", "Wrapping label factory did not set string.")
    expect(textField.stringValue == "Edit", "Text field factory did not set string.")
    expect(textField.isEditable, "Text field factory did not create editable field.")
    expect(textField.isSelectable, "Text field factory did not create selectable field.")
    expect(textField.isBordered, "Text field factory did not create bordered field.")
    expect(textField.drawsBackground, "Text field factory did not enable background drawing.")
    expect(textField.placeholderString == "Placeholder", "Placeholder string was not stored.")
    expect(secureField.stringValue == "Password", "Secure text field factory did not store string.")
    expect(secureField.isEditable, "Secure text field factory did not create editable field.")
    expect(secureField.isSelectable, "Secure text field factory did not create selectable field.")
    expect(secureField.isBordered, "Secure text field factory did not create bordered field.")
    expect(secureField.drawsBackground, "Secure text field factory did not draw background.")
}

func testSwitchButtonUsesCheckboxNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let checkbox = NSButton(title: "Check", frame: NSMakeRect(0, 0, 120, 24))
    checkbox.setButtonType(.switchButton)
    checkbox.state = .on

    let handle = checkbox.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "checkbox", "Switch button did not request checkbox native peer.")
    expect(backend.records[handle]?.buttonState == .on, "Switch button state was not synced to backend.")
}

func testRadioButtonUsesRadioNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let radioButton = NSButton(title: "Radio", frame: NSMakeRect(0, 0, 120, 24))
    radioButton.setButtonType(.radioButton)
    radioButton.state = .on

    let handle = radioButton.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "radioButton", "Radio button did not request radio native peer.")
    expect(backend.records[handle]?.buttonState == .on, "Radio button state was not synced to backend.")
}

func testPopUpButtonUsesNativePeerAndSelection() {
    let backend = InMemoryNativeControlBackend()
    let popUpButton = NSPopUpButton(frame: NSMakeRect(0, 0, 140, 80), pullsDown: false)
    popUpButton.addItems(withTitles: ["Info", "Warning", "Critical"])
    popUpButton.selectItem(withTitle: "Warning")

    let handle = popUpButton.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "popUpButton", "Pop-up button did not request native peer.")
    expect(backend.records[handle]?.popUpItems == ["Info", "Warning", "Critical"], "Pop-up button items were not synced.")
    expect(backend.records[handle]?.popUpSelectedIndex == 1, "Pop-up button selection was not synced.")
    expect(popUpButton.titleOfSelectedItem == "Warning", "Pop-up button selected title was not reported.")
}

func testPopUpButtonNativeActionUpdatesSelection() {
    let backend = InMemoryNativeControlBackend()
    let popUpButton = NSPopUpButton(frame: NSMakeRect(0, 0, 140, 80), pullsDown: false)
    popUpButton.addItems(withTitles: ["Info", "Warning", "Critical"])
    let handle = popUpButton.realizeNativePeer(in: backend, parent: nil)
    var actionCount = 0

    popUpButton.onAction = { control in
        expect(control === popUpButton, "Pop-up action sender was not the control.")
        actionCount += 1
    }

    backend.setPopUpButtonSelectedIndex(2, for: handle)
    backend.actions[handle]?()

    expect(popUpButton.indexOfSelectedItem == 2, "Pop-up button did not read native selection.")
    expect(popUpButton.titleOfSelectedItem == "Critical", "Pop-up button selected title did not update.")
    expect(actionCount == 1, "Pop-up button action was not sent.")
}

func testPopUpButtonItemLookupAndRemoval() {
    let popUpButton = NSPopUpButton(frame: NSMakeRect(0, 0, 140, 80), pullsDown: false)

    popUpButton.addItems(withTitles: ["Info", "Warning", "Critical"])
    popUpButton.selectItem(withTitle: "Critical")

    expect(popUpButton.itemTitles == ["Info", "Warning", "Critical"], "Pop-up itemTitles did not match.")
    expect(popUpButton.lastItem == "Critical", "Pop-up lastItem was wrong.")
    expect(popUpButton.indexOfItem(withTitle: "Warning") == 1, "Pop-up index lookup failed.")
    expect(popUpButton.indexOfItem(withTitle: "Missing") == -1, "Pop-up missing index should be -1.")

    popUpButton.removeItem(withTitle: "Warning")

    expect(popUpButton.itemTitles == ["Info", "Critical"], "Pop-up title removal failed.")
    expect(popUpButton.indexOfSelectedItem == 1, "Pop-up selected index was not adjusted after title removal.")

    popUpButton.removeItem(at: 1)

    expect(popUpButton.itemTitles == ["Info"], "Pop-up index removal failed.")
    expect(popUpButton.indexOfSelectedItem == 0, "Pop-up selected index was not clamped after removal.")

    popUpButton.removeItem(at: 0)

    expect(popUpButton.itemTitles.isEmpty, "Pop-up final removal failed.")
    expect(popUpButton.indexOfSelectedItem == -1, "Pop-up selected index was not cleared.")
}

func testComboBoxStoresItemsTextAndUsesNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let comboBox = NSComboBox(frame: NSMakeRect(0, 0, 180, 28))
    comboBox.addItems(withObjectValues: ["Cocoa", "AppKit"])
    comboBox.stringValue = "WinChocolate"

    let handle = comboBox.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "comboBox", "Combo box did not request native peer.")
    expect(backend.records[handle]?.comboBoxItems == ["Cocoa", "AppKit"], "Combo box items were not synced.")
    expect(backend.records[handle]?.text == "WinChocolate", "Combo box text was not synced.")
    expect(comboBox.numberOfItems == 2, "Combo box numberOfItems was wrong.")
    expect(comboBox.indexOfItem(withObjectValue: "AppKit") == 1, "Combo box item lookup failed.")

    comboBox.selectItem(at: 0)
    expect(comboBox.stringValue == "Cocoa", "Combo box selection did not update stringValue.")
}

func testComboBoxNativeTextChangeAndActionUpdateState() {
    let backend = InMemoryNativeControlBackend()
    let comboBox = NSComboBox(frame: NSMakeRect(0, 0, 180, 28))
    var textChangeCount = 0
    var actionCount = 0

    comboBox.onComboBoxTextChanged = { combo in
        textChangeCount += 1
        expect(combo.stringValue == "Typed", "Combo box text change did not update stringValue.")
    }
    comboBox.onAction = { control in
        actionCount += 1
        expect((control as? NSComboBox)?.stringValue == "Selected", "Combo box action did not read backend text.")
    }

    let handle = comboBox.realizeNativePeer(in: backend, parent: nil)
    backend.textChangeActions[handle]?("Typed")
    backend.setText("Selected", for: handle)
    backend.actions[handle]?()

    expect(textChangeCount == 1, "Combo box text-change callback did not fire.")
    expect(actionCount == 1, "Combo box action callback did not fire.")
}

func testImageViewStoresImageAndUsesNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let imageView = NSImageView(frame: NSMakeRect(0, 0, 64, 64))
    imageView.image = NSImage(named: "Icon")

    let handle = imageView.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "imageView", "Image view did not request native peer.")
    expect(backend.records[handle]?.text == "Icon", "Image view did not sync image description.")
    expect(!imageView.acceptsFirstResponder, "Image view should not accept first responder by default.")

    imageView.image = NSImage(named: "Updated")
    expect(backend.records[handle]?.text == "Updated", "Image view image changes did not sync.")
}

func testTabViewStoresItemsSelectionAndUsesNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let tabView = NSTabView(frame: NSMakeRect(0, 0, 220, 80))
    let first = NSTabViewItem(identifier: "first")
    let second = NSTabViewItem(identifier: "second")
    first.label = "First"
    second.label = "Second"

    tabView.addTabViewItem(first)
    tabView.addTabViewItem(second)

    let handle = tabView.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "tabView", "Tab view did not request native peer.")
    expect(backend.records[handle]?.tabViewItems == ["First", "Second"], "Tab view labels were not synced.")
    expect(tabView.selectedTabViewItem === first, "Tab view did not select first item by default.")

    tabView.selectTabViewItem(second)
    expect(tabView.selectedTabViewItem === second, "Tab view did not update selected item.")
    expect(backend.records[handle]?.tabViewSelectedIndex == 1, "Tab view selection was not synced.")
}

func testTabViewNativeSelectionDispatchesAction() {
    let backend = InMemoryNativeControlBackend()
    let tabView = NSTabView(frame: NSMakeRect(0, 0, 220, 80))
    let first = NSTabViewItem(identifier: "first")
    let second = NSTabViewItem(identifier: "second")
    first.label = "First"
    second.label = "Second"
    tabView.addTabViewItem(first)
    tabView.addTabViewItem(second)
    var selectionCount = 0

    tabView.onSelectionChanged = { tabs in
        selectionCount += 1
        expect(tabs.selectedTabViewItem === second, "Native tab selection did not update selected item.")
    }

    let handle = tabView.realizeNativePeer(in: backend, parent: nil)
    backend.setTabViewSelectedIndex(1, for: handle)
    backend.actions[handle]?()

    expect(selectionCount == 1, "Native tab selection callback did not fire.")
}

func testNativeButtonActionMakesButtonFirstResponder() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 200, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 200, 100))
    let button = NSButton(title: "Click", frame: NSMakeRect(20, 20, 80, 24))
    var actionCount = 0

    button.onAction = { _ in
        actionCount += 1
    }
    contentView.addSubview(button)
    window.contentView = contentView
    window.realizeNativePeer()

    guard let handle = button.nativeHandle else {
        fatalError("Button did not realize.")
    }

    backend.actions[handle]?()

    expect(window.firstResponder === button, "Native button action did not make button first responder.")
    expect(backend.focusedHandle == handle, "Native button action did not request native focus.")
    expect(actionCount == 1, "Native button action did not send action.")
}

func testNativePopUpActionMakesPopUpFirstResponder() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 200, 120),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 200, 120))
    let popUpButton = NSPopUpButton(frame: NSMakeRect(20, 20, 140, 80), pullsDown: false)

    popUpButton.addItems(withTitles: ["Info", "Warning"])
    contentView.addSubview(popUpButton)
    window.contentView = contentView
    window.realizeNativePeer()

    guard let handle = popUpButton.nativeHandle else {
        fatalError("Pop-up button did not realize.")
    }

    backend.actions[handle]?()

    expect(window.firstResponder === popUpButton, "Native pop-up action did not make pop-up first responder.")
    expect(backend.focusedHandle == handle, "Native pop-up action did not request native focus.")
}

func testNativeTextChangeMakesEditableTextFieldFirstResponder() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 200, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 200, 100))
    let textField = NSTextField(string: "", frame: NSMakeRect(20, 20, 140, 24))

    textField.isEditable = true
    contentView.addSubview(textField)
    window.contentView = contentView
    window.realizeNativePeer()

    guard let handle = textField.nativeHandle else {
        fatalError("Text field did not realize.")
    }

    backend.textChangeActions[handle]?("Typed")

    expect(window.firstResponder === textField, "Native text change did not make text field first responder.")
    expect(backend.focusedHandle == handle, "Native text change did not request native focus.")
    expect(textField.stringValue == "Typed", "Native text change did not update string value.")
}

func testNativeTextChangeMakesSecureTextFieldFirstResponder() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 200, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 200, 100))
    let secureField = NSSecureTextField(string: "", frame: NSMakeRect(20, 20, 140, 24))

    contentView.addSubview(secureField)
    window.contentView = contentView
    window.realizeNativePeer()

    guard let handle = secureField.nativeHandle else {
        fatalError("Secure text field did not realize.")
    }

    backend.textChangeActions[handle]?("Typed")

    expect(window.firstResponder === secureField, "Native secure text change did not make secure field first responder.")
    expect(backend.focusedHandle == handle, "Native secure text change did not request native focus.")
    expect(secureField.stringValue == "Typed", "Native secure text change did not update string value.")
}

func testNativeTextChangeMakesTextViewFirstResponder() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 240, 140),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 240, 140))
    let textView = NSTextView(frame: NSMakeRect(20, 20, 160, 80))

    contentView.addSubview(textView)
    window.contentView = contentView
    window.realizeNativePeer()

    guard let handle = textView.nativeHandle else {
        fatalError("Text view did not realize.")
    }

    var callbackText = ""
    textView.onTextChanged = { view in
        callbackText = view.string
    }
    backend.textChangeActions[handle]?("Typed\nMore")

    expect(window.firstResponder === textView, "Native text view change did not make text view first responder.")
    expect(backend.focusedHandle == handle, "Native text view change did not request native focus.")
    expect(textView.string == "Typed\nMore", "Native text view change did not update string.")
    expect(callbackText == "Typed\nMore", "Native text view change did not invoke callback.")
}

func testBoxUsesNativePeerAndSyncsTitle() {
    let backend = InMemoryNativeControlBackend()
    let box = NSBox(title: "Group", frame: NSMakeRect(0, 0, 200, 120))

    let handle = box.realizeNativePeer(in: backend, parent: nil)
    box.title = "Updated Group"

    expect(backend.records[handle]?.kind == "box", "Box did not request native peer.")
    expect(backend.records[handle]?.text == "Updated Group", "Box title was not synced to backend.")
}

func testColorValuesClampComponents() {
    let color = NSColor(calibratedRed: 2, green: -1, blue: 0.25, alpha: 3)

    expect(color.redComponent == 1, "Color red component did not clamp high.")
    expect(color.greenComponent == 0, "Color green component did not clamp low.")
    expect(color.blueComponent == 0.25, "Color blue component changed unexpectedly.")
    expect(color.alphaComponent == 1, "Color alpha component did not clamp high.")
}

func testViewAndTextFieldColorsSyncToBackend() {
    let backend = InMemoryNativeControlBackend()
    let view = NSView(frame: NSMakeRect(0, 0, 100, 100))
    let textField = NSTextField(string: "Color", frame: NSMakeRect(0, 0, 80, 24))
    view.backgroundColor = .white
    textField.textColor = .blue
    textField.backgroundColor = NSColor(calibratedRed: 0.9, green: 0.95, blue: 1, alpha: 1)
    view.addSubview(textField)

    let viewHandle = view.realizeNativePeer(in: backend, parent: nil)
    guard let textHandle = textField.nativeHandle else {
        fatalError("Text field did not realize.")
    }

    expect(backend.records[viewHandle]?.backgroundColor == .white, "View background color was not synced.")
    expect(backend.records[textHandle]?.textColor == .blue, "Text field text color was not synced.")
    expect(backend.records[textHandle]?.backgroundColor == NSColor(calibratedRed: 0.9, green: 0.95, blue: 1, alpha: 1), "Text field background color was not synced.")
}

func testFontValuesClampSizeAndSyncToBackend() {
    let backend = InMemoryNativeControlBackend()
    let textField = NSTextField(string: "Font", frame: NSMakeRect(0, 0, 120, 24))
    let tinyFont = NSFont(name: "Segoe UI", size: -4)
    let boldFont = NSFont.boldSystemFont(ofSize: 16)

    textField.font = boldFont
    let handle = textField.realizeNativePeer(in: backend, parent: nil)

    expect(tinyFont.pointSize == 1, "Font point size did not clamp low.")
    expect(boldFont.fontName == "Segoe UI", "Bold system font did not use system face.")
    expect(boldFont.weight == .bold, "Bold system font did not use bold weight.")
    expect(backend.records[handle]?.font == boldFont, "Text field font was not synced.")
}


func testRemovingRealizedSubviewDestroysNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let parent = NSView(frame: NSMakeRect(0, 0, 100, 100))
    let child = NSView(frame: NSMakeRect(0, 0, 20, 20))
    parent.addSubview(child)
    parent.realizeNativePeer(in: backend, parent: nil)

    guard let childHandle = child.nativeHandle else {
        fatalError("Child did not realize.")
    }

    child.removeFromSuperview()

    expect(child.nativeHandle == nil, "Child native handle was not cleared.")
    expect(backend.records[childHandle] == nil, "Child native record was not destroyed.")
}

func testMainMenuQuitItemTerminatesApplication() {
    let backend = InMemoryNativeControlBackend()
    let app = NSApplication(nativeBackend: backend)
    let menuBar = NSMenu()
    let appMenuItem = NSMenuItem(title: "WinChocolate", action: nil, keyEquivalent: "")
    let appMenu = NSMenu(title: "WinChocolate")
    let quitItem = NSMenuItem(title: "Quit WinChocolate", action: "terminate:", keyEquivalent: "q")

    quitItem.target = app
    appMenu.addItem(quitItem)
    appMenuItem.submenu = appMenu
    menuBar.addItem(appMenuItem)
    app.mainMenu = menuBar

    expect(backend.installedMainMenu === menuBar, "Main menu was not installed in the backend.")
    expect(quitItem.performAction(), "Quit menu item did not perform.")
    expect(backend.didTerminateApplication, "Quit menu item did not terminate the application.")
}

func testMenuItemInsertionLookupAndRemoval() {
    let menu = NSMenu(title: "File")
    let open = menu.addItem(withTitle: "Open", action: nil, keyEquivalent: "o")
    let save = NSMenuItem(title: "Save", action: nil, keyEquivalent: "s")
    let close = menu.insertItem(withTitle: "Close", action: nil, keyEquivalent: "w", at: 1)

    menu.insertItem(save, at: 99)

    expect(menu.numberOfItems == 3, "Menu item count was wrong.")
    expect(menu.item(at: 0) === open, "Menu item lookup by index failed.")
    expect(menu.item(at: 1) === close, "Menu insertItem(withTitle:) inserted at wrong index.")
    expect(menu.item(at: 2) === save, "Menu insertItem clamping failed.")
    expect(menu.item(withTitle: "Save") === save, "Menu lookup by title failed.")
    expect(menu.index(of: close) == 1, "Menu index(of:) failed.")
    expect(menu.indexOfItem(withTitle: "Missing") == -1, "Menu missing title index should be -1.")
    expect(save.menu === menu, "Inserted item did not receive parent menu.")

    menu.removeItem(at: 1)

    expect(close.menu == nil, "Removed item retained parent menu.")
    expect(menu.numberOfItems == 2, "removeItem(at:) did not remove one item.")

    menu.removeItem(open)

    expect(open.menu == nil, "removeItem did not clear parent menu.")
    expect(menu.numberOfItems == 1, "removeItem did not remove matching item.")

    menu.removeAllItems()

    expect(save.menu == nil, "removeAllItems did not clear parent menu.")
    expect(menu.numberOfItems == 0, "removeAllItems did not clear menu.")
}

func testMenuItemStateAndSeparatorContracts() {
    let separator = NSMenuItem.separator()
    let item = NSMenuItem(title: "Toggle", action: nil, keyEquivalent: "t")

    item.isEnabled = false
    item.isHidden = true
    item.state = .on
    item.keyEquivalentModifierMask = [.command, .shift]

    expect(separator.isSeparatorItem, "Separator item was not recognized.")
    expect(!item.performAction(), "Disabled menu item performed action.")
    expect(item.isHidden, "Menu item hidden state was not stored.")
    expect(item.state == .on, "Menu item state was not stored.")
    expect(item.keyEquivalentModifierMask.contains(.command), "Menu item command modifier was not stored.")
    expect(item.keyEquivalentModifierMask.contains(.shift), "Menu item shift modifier was not stored.")
}

func testAlertReturnsFirstButtonInMemory() {
    NSApplication.shared.nativeBackend = InMemoryNativeControlBackend()
    let alert = NSAlert()
    alert.messageText = "Hello"
    alert.addButton(withTitle: "OK")

    let response = alert.runModal()

    expect(response == .alertFirstButtonReturn, "In-memory alert did not return first button.")
}

func testAlertRestoresKeyWindowAndFirstResponder() {
    clearApplicationWindows()

    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 200, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 200, 100))
    let button = NSButton(title: "Alert", frame: NSMakeRect(20, 20, 80, 24))
    let alert = NSAlert()

    contentView.addSubview(button)
    window.contentView = contentView
    window.makeKeyAndOrderFront(nil)
    _ = window.makeFirstResponder(button)

    let response = alert.runModal()

    expect(response == .alertFirstButtonReturn, "Alert did not return expected response.")
    expect(NSApplication.shared.keyWindow === window, "Alert did not restore key window.")
    expect(NSApplication.shared.mainWindow === window, "Alert did not restore main window.")
    expect(window.firstResponder === button, "Alert did not restore first responder.")
    expect(backend.focusedHandle == button.nativeHandle, "Alert did not restore native focus.")

    clearApplicationWindows()
}

testWindowRealizationCreatesNativeHierarchy()
testViewHierarchyMaintainsSuperviewOwnership()
testViewInsertionReplacementTagsAndDescendants()
testViewCompatibilityMetadataStoresValues()
testGeometryConvenienceFunctions()
testViewCoordinateConversionAndHitTesting()
testScrollViewHostsDocumentView()
testScrollViewUsesNativePeerAndRealizesDocumentView()
testCellStoresStringAndObjectValues()
testSortDescriptorStoresKeyDirectionAndReverse()
testTableCellAndRowViewsStoreState()
testTableColumnStoresAppKitIdentifierShape()
testTableViewReloadsRowsFromDataSource()
testTableViewColumnMovementAndRemoval()
testTableViewSelectionOptionsAndHelpers()
testTableViewStoresDisplayOptionsAndSetObjectValue()
testTableViewDelegateViewHeightAndSortHooks()
testTableViewTabKeyMovesThroughKeyViewLoop()
testTableViewKeyboardNavigationUpdatesSelection()
testTableViewKeyboardExtendedSelection()
testTableViewColumnSelectionAndDoubleActionSurface()
testTableViewSortDescriptorPrototypeToggle()
testSliderStoresRangeValueAndSyncsNativePeer()
testSliderNativeActionUpdatesValue()
testProgressIndicatorStoresRangeValueAndSyncsNativePeer()
testStepperStoresRangeIncrementAndSyncsNativePeer()
testStepperNativeActionUpdatesValue()
testTableViewNativePeerReceivesColumnsRowsAndSelection()
testTableViewNativeSelectionNotifiesDelegateAndAction()
testTableViewActionCanReadSelectedRowValue()
testTableViewClickedRowAndColumnFollowSelection()
testSubviewResponderChainTargetsSuperview()
testResponderForwardsUnhandledEvents()
testWindowIsContentViewNextResponder()
testWindowMakeFirstResponderFocusesNativeView()
testWindowMakeFirstResponderHonorsResignFailure()
testApplicationTracksWindowListAndKeyMainWindow()
testWindowSelectNextAndPreviousKeyView()
testWindowSelectNextKeyViewSkipsDisabledExplicitTarget()
testNativeMouseDownDispatchesToView()
testNativeMouseDownOnControlMakesControlFirstResponder()
testNativeMouseUpDispatchesToView()
testNativeMouseMovedDispatchesToView()
testNativeKeyDownDispatchesToView()
testNativeKeyUpDispatchesToView()
testControlClosureActionIsInvoked()
testButtonPerformClickHonorsEnabledState()
testControlCompatibilityMetadataStoresValues()
testSwitchButtonTogglesStateOnPerformClick()
testButtonMixedStateAndCompatibilityProperties()
testRadioButtonClearsSiblingRadioButtons()
testRealizedViewStatePropagatesToBackend()
testWindowTitleAndFramePropagateToBackend()
testWindowContentSizeAndCenterUpdateFrame()
testEditableTextFieldUsesEditableNativePeer()
testSecureTextFieldUsesSecureNativePeer()
testTextViewUsesMultilineNativePeerAndStoresText()
testTextFieldFactoryConstructorsAndCompatibilityProperties()
testSwitchButtonUsesCheckboxNativePeer()
testRadioButtonUsesRadioNativePeer()
testPopUpButtonUsesNativePeerAndSelection()
testPopUpButtonNativeActionUpdatesSelection()
testPopUpButtonItemLookupAndRemoval()
testComboBoxStoresItemsTextAndUsesNativePeer()
testComboBoxNativeTextChangeAndActionUpdateState()
testImageViewStoresImageAndUsesNativePeer()
testTabViewStoresItemsSelectionAndUsesNativePeer()
testTabViewNativeSelectionDispatchesAction()
testNativeButtonActionMakesButtonFirstResponder()
testNativePopUpActionMakesPopUpFirstResponder()
testNativeTextChangeMakesEditableTextFieldFirstResponder()
testNativeTextChangeMakesSecureTextFieldFirstResponder()
testNativeTextChangeMakesTextViewFirstResponder()
testBoxUsesNativePeerAndSyncsTitle()
testColorValuesClampComponents()
testViewAndTextFieldColorsSyncToBackend()
testFontValuesClampSizeAndSyncToBackend()
testRemovingRealizedSubviewDestroysNativePeer()
testMainMenuQuitItemTerminatesApplication()
testMenuItemInsertionLookupAndRemoval()
testMenuItemStateAndSeparatorContracts()
testAlertReturnsFirstButtonInMemory()
testAlertRestoresKeyWindowAndFirstResponder()

print("WinChocolate contract tests passed.")
