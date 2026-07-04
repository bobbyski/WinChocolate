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

final class RecordingToolbarDelegate: NSToolbarDelegate {
    var allowedIdentifiers: [NSToolbarItem.Identifier] = ["open", "save", "customize"]
    var defaultIdentifiers: [NSToolbarItem.Identifier] = ["open", "save"]
    var requestedIdentifiers: [NSToolbarItem.Identifier] = []
    var insertionFlags: [Bool] = []

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        allowedIdentifiers
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        defaultIdentifiers
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        requestedIdentifiers.append(itemIdentifier)
        insertionFlags.append(flag)

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = itemIdentifier.rawValue == "customize" ? "Customize" : "Save"
        item.paletteLabel = item.label
        return item
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
    expect(backend.records[windowHandle]?.isHidden == true, "Realized window should stay hidden until ordered front.")
    expect(contentView.nativeHandle != nil, "Content view was not realized.")
    expect(button.nativeHandle != nil, "Button was not realized.")
    expect(backend.records[button.nativeHandle!]?.kind == "button", "Button native record was not created.")
    expect(backend.records[button.nativeHandle!]?.parent == contentView.nativeHandle, "Button parent was not content view.")

    window.makeKeyAndOrderFront(nil)

    expect(backend.records[windowHandle]?.isHidden == false, "makeKeyAndOrderFront did not show the realized window.")

    clearApplicationWindows()
}

func testWindowTitleVisibilityBlanksCaption() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 200, 120),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    window.title = "Inspector"
    let handle = window.realizeNativePeer()
    expect(backend.records[handle]?.text == "Inspector", "Visible title was not pushed to the native window.")

    // Hiding the title blanks the caption text but keeps the window.
    window.titleVisibility = .hidden
    expect(backend.records[handle]?.text == "", "Hidden titleVisibility did not blank the caption.")

    // A title set while hidden stays blank, then reappears when shown.
    window.title = "Renamed"
    expect(backend.records[handle]?.text == "", "Title change while hidden should not reveal the caption.")
    window.titleVisibility = .visible
    expect(backend.records[handle]?.text == "Renamed", "Restoring visibility did not show the current title.")

    clearApplicationWindows()
}

func testWindowStandardButtonsAndStyleFlags() {
    let backend = InMemoryNativeControlBackend()
    let titled = NSWindow(
        contentRect: NSMakeRect(0, 0, 200, 120),
        styleMask: [.titled, .closable, .fullSizeContentView],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )

    // fullSizeContentView is a recognized style option.
    expect(titled.styleMask.contains(.fullSizeContentView), "fullSizeContentView flag was not stored in the style mask.")

    // Titled windows vend proxy buttons; the same instance is returned each time.
    let close = titled.standardWindowButton(.closeButton)
    expect(close != nil, "Titled window did not vend a close-button proxy.")
    close?.isHidden = true
    expect(titled.standardWindowButton(.closeButton)?.isHidden == true, "Standard button proxy did not persist its state.")

    // titlebarAppearsTransparent round-trips.
    titled.titlebarAppearsTransparent = true
    expect(titled.titlebarAppearsTransparent, "titlebarAppearsTransparent did not store.")

    // Borderless windows vend no standard buttons.
    let borderless = NSWindow(
        contentRect: NSMakeRect(0, 0, 100, 60),
        styleMask: [],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    expect(borderless.standardWindowButton(.closeButton) == nil, "Borderless window should not vend standard buttons.")

    clearApplicationWindows()
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

func testViewTooltipSyncsToNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let view = NSView(frame: NSMakeRect(0, 0, 100, 100))
    view.toolTip = "Before"

    let handle = view.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.toolTip == "Before", "Initial tooltip was not sent to native peer.")

    view.toolTip = "After"

    expect(backend.records[handle]?.toolTip == "After", "Updated tooltip was not sent to native peer.")

    view.toolTip = nil

    expect(backend.records[handle]?.toolTip == nil, "Cleared tooltip was not sent to native peer.")
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

    expect(scrollView.subviews.count == 1, "Scroll view should own one clip view child.")
    expect(scrollView.subviews.first === scrollView.contentView, "Scroll view subview was not the clip view.")
    expect(scrollView.contentView.documentView === documentView, "Clip view did not host the document view.")
    expect(documentView.superview === scrollView.contentView, "Document view superview was not the clip view.")
    expect(!scrollView.contentView.acceptsFirstResponder, "Clip view should skip key-view traversal.")
}

func testScrollViewUsesNativePeerAndRealizesDocumentView() {
    let backend = InMemoryNativeControlBackend()
    let scrollView = NSScrollView(frame: NSMakeRect(0, 0, 200, 120))
    let documentView = NSView(frame: NSMakeRect(0, 0, 300, 240))

    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = true
    scrollView.documentView = documentView

    let handle = scrollView.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "scrollView", "Scroll view did not request native scroll peer.")
    expect(scrollView.contentView.nativeHandle != nil, "Scroll view did not realize clip view.")
    expect(documentView.nativeHandle != nil, "Scroll view did not realize document view.")
    expect(backend.records[scrollView.contentView.nativeHandle!]?.parent == handle, "Clip view native parent was not scroll view.")
    expect(backend.records[documentView.nativeHandle!]?.parent == scrollView.contentView.nativeHandle, "Document view native parent was not clip view.")
    expect(backend.records[handle]?.scrollViewContentSize == NSMakeSize(300, 240), "Scroll view did not sync document size.")
    expect(backend.records[handle]?.scrollViewViewportSize == NSMakeSize(200, 120), "Scroll view did not sync viewport size.")
}

func testScrollViewNativeScrollbarActionUpdatesClipOrigin() {
    let backend = InMemoryNativeControlBackend()
    let scrollView = NSScrollView(frame: NSMakeRect(0, 0, 200, 120))
    let documentView = NSView(frame: NSMakeRect(0, 0, 300, 240))

    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = true
    scrollView.documentView = documentView

    let handle = scrollView.realizeNativePeer(in: backend, parent: nil)
    backend.setScrollViewContentOffset(NSMakePoint(40, 70), for: handle)
    backend.actions[handle]?()

    expect(scrollView.contentView.boundsOrigin == NSMakePoint(40, 70), "Native scroll-view action did not update clip-view origin.")
    expect(documentView.frame.origin == NSMakePoint(-40, -70), "Native scroll-view action did not move the document view.")
}

func testClipViewScrollsDocumentView() {
    let clipView = NSClipView(frame: NSMakeRect(0, 0, 100, 80))
    let documentView = NSView(frame: NSMakeRect(0, 0, 180, 160))
    clipView.documentView = documentView

    clipView.scroll(to: NSMakePoint(40, 50))

    expect(clipView.boundsOrigin == NSMakePoint(40, 50), "Clip view did not store scroll origin.")
    expect(clipView.documentVisibleRect == NSMakeRect(40, 50, 100, 80), "Clip view visible rect was not document-space bounds.")
    expect(documentView.frame.origin == NSMakePoint(-40, -50), "Clip view did not offset document frame.")

    clipView.scroll(to: NSMakePoint(400, 400))
    expect(clipView.boundsOrigin == NSMakePoint(80, 80), "Clip view did not constrain scroll origin to document extent.")
}

final class RecordingResponder: NSResponder {
    var mouseDownCount = 0
    var mouseDraggedCount = 0
    var keyDownCount = 0

    override func mouseDown(with event: NSEvent) {
        mouseDownCount += 1
    }

    override func mouseDragged(with event: NSEvent) {
        mouseDraggedCount += 1
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
    var mouseDraggedCount = 0
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

    override func mouseDragged(with event: NSEvent) {
        mouseDraggedCount += 1
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

final class RecordingOutlineDataSource: NSOutlineViewDataSource {
    let roots = ["Application", "Controls"]
    let children: [String: [String]] = [
        "Application": ["NSApplication", "NSWindow"],
        "Controls": ["NSButton", "NSMatrix"]
    ]

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
        children[String(describing: item)] != nil
    }

    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        guard let item else {
            return nil
        }

        let value = String(describing: item)
        if tableColumn?.identifier.rawValue == "kind" {
            return children[value] == nil ? "Leaf" : "Group"
        }

        return value
    }
}

final class RecordingBrowserDelegate: NSBrowserDelegate {
    let roots = ["Application", "Controls"]
    let children: [String: [String]] = [
        "Application": ["NSApplication", "NSWindow"],
        "Controls": ["NSButton", "NSMatrix"]
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
}

final class RecordingCollectionDataSource: NSCollectionViewDataSource {
    let values = [
        ["NSButton", "NSTextField", "NSTableView"],
        ["NSBrowser", "NSOutlineView"]
    ]

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        values.count
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        values[section].count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = NSCollectionViewItem()
        let title = values[indexPath.section][indexPath.item]
        item.representedObject = title
        item.view = NSButton(title: title, frame: NSMakeRect(0, 0, 112, 34))
        return item
    }
}

final class RecordingCollectionDelegate: NSCollectionViewDelegate {
    var selected: Set<IndexPath> = []
    var deselected: Set<IndexPath> = []

    func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
        selected.formUnion(indexPaths)
    }

    func collectionView(_ collectionView: NSCollectionView, didDeselectItemsAt indexPaths: Set<IndexPath>) {
        deselected.formUnion(indexPaths)
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
    searchField.previousKeyView = previousButton
    searchField.nextKeyView = nextButton
    nextButton.previousKeyView = searchField
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

func testOutlineViewFlattensExpandableItems() {
    let backend = InMemoryNativeControlBackend()
    let outlineView = NSOutlineView(frame: NSMakeRect(0, 0, 300, 160))
    let dataSource = RecordingOutlineDataSource()
    let name = NSTableColumn(identifier: "name")
    let kind = NSTableColumn(identifier: "kind")

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
    expect(outlineView.value(atColumn: 0, row: 0) == "+ Application", "Outline did not mark collapsed group.")
    expect(outlineView.value(atColumn: 1, row: 0) == "Group", "Outline did not load secondary column value.")
    expect(outlineView.isItemExpandable("Application"), "Outline did not report expandable group.")
    expect(!outlineView.isItemExpandable("NSApplication"), "Outline reported leaf as expandable.")

    outlineView.expandItem("Application")

    expect(outlineView.isItemExpanded("Application"), "Outline did not store expanded state.")
    expect(outlineView.numberOfRows == 4, "Outline did not add expanded children.")
    expect(outlineView.item(atRow: 1) as? String == "NSApplication", "Outline first child was wrong.")
    expect(outlineView.level(forItem: "NSApplication") == 1, "Outline child level was wrong.")
    expect(outlineView.value(atColumn: 0, row: 0) == "- Application", "Outline did not mark expanded group.")
    expect(outlineView.value(atColumn: 0, row: 1) == "    NSApplication", "Outline child indentation text was wrong.")

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

    let handle = outlineView.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "tableView", "Outline view did not use the table backend.")
    expect(backend.records[handle]?.tableRows.count == 2, "Outline native rows were not synced.")
}

func testBrowserLoadsColumnsAndTracksSelection() {
    let backend = InMemoryNativeControlBackend()
    let browser = NSBrowser(frame: NSMakeRect(0, 0, 320, 120))
    let delegate = RecordingBrowserDelegate()
    var actionCount = 0

    browser.delegate = delegate
    browser.columnWidth = 150
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
    expect(browser.subviews.count == 2, "Browser did not compose visible scroll-view columns.")
}

func testIndexPathStoresCollectionComponents() {
    let indexPath = IndexPath(item: 3, section: 2)
    let appended = IndexPath(indexes: [1, 4]).appending(9)

    expect(indexPath.section == 2, "IndexPath section component was wrong.")
    expect(indexPath.item == 3, "IndexPath item component was wrong.")
    expect(indexPath.count == 2, "IndexPath count was wrong.")
    expect(indexPath[0] == 2 && indexPath[1] == 3, "IndexPath subscript returned wrong components.")
    expect(appended.count == 3 && appended[2] == 9, "IndexPath appending did not add a component.")
}

func testCollectionViewReloadsItemsAndTracksSelection() {
    let backend = InMemoryNativeControlBackend()
    let collectionView = NSCollectionView(frame: NSMakeRect(0, 0, 260, 96))
    let dataSource = RecordingCollectionDataSource()
    let delegate = RecordingCollectionDelegate()
    var actionCount = 0

    collectionView.dataSource = dataSource
    collectionView.delegate = delegate
    collectionView.itemSize = NSMakeSize(112, 28)
    collectionView.minimumInteritemSpacing = 8
    collectionView.minimumLineSpacing = 6
    collectionView.onAction = { control in
        expect(control === collectionView, "Collection view action sender was not collection view.")
        actionCount += 1
    }

    collectionView.reloadData()

    let first = IndexPath(item: 0, section: 0)
    let secondSection = IndexPath(item: 1, section: 1)
    expect(collectionView.subviews.count == 5, "Collection view did not compose item views.")
    expect(collectionView.item(at: first)?.representedObject as? String == "NSButton", "Collection item lookup returned wrong represented object.")
    expect(collectionView.indexPath(for: collectionView.item(at: secondSection)!) == secondSection, "Collection reverse item lookup failed.")

    let handle = collectionView.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "view", "Collection view did not create a native host view.")
    expect(collectionView.subviews.allSatisfy { $0.nativeHandle != nil }, "Collection item views were not realized.")

    collectionView.selectItems(at: [secondSection])

    expect(collectionView.selectionIndexPaths == [secondSection], "Collection view did not store selection.")
    expect(collectionView.item(at: secondSection)?.isSelected == true, "Collection item did not mark selected state.")
    expect(delegate.selected.contains(secondSection), "Collection delegate did not receive selection.")
    expect(actionCount == 1, "Collection view action was not sent for selection.")

    collectionView.deselectItems(at: [secondSection])

    expect(collectionView.selectionIndexPaths.isEmpty, "Collection view did not deselect item.")
    expect(delegate.deselected.contains(secondSection), "Collection delegate did not receive deselection.")
}

func testCollectionViewButtonItemClickSelectsItem() {
    let collectionView = NSCollectionView(frame: NSMakeRect(0, 0, 260, 96))
    let dataSource = RecordingCollectionDataSource()
    let target = IndexPath(item: 2, section: 0)
    var actionCount = 0

    collectionView.dataSource = dataSource
    collectionView.onAction = { _ in
        actionCount += 1
    }
    collectionView.reloadData()

    guard let button = collectionView.item(at: target)?.view as? NSButton else {
        fatalError("Collection data source did not create a button item.")
    }

    button.performClick(nil)

    expect(collectionView.selectionIndexPaths == [target], "Collection button item click did not select its index path.")
    expect(actionCount == 1, "Collection button item click did not send collection action.")
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

func testLevelIndicatorStoresRangeValueAndUsesProgressPeer() {
    let backend = InMemoryNativeControlBackend()
    let level = NSLevelIndicator(frame: NSMakeRect(0, 0, 160, 18))
    level.minValue = 0
    level.maxValue = 10
    level.warningValue = 7
    level.criticalValue = 9
    level.doubleValue = 6

    expect(level.doubleValue == 6, "Level indicator doubleValue was not stored.")
    expect(level.intValue == 6, "Level indicator intValue did not reflect doubleValue.")
    expect(level.warningValue == 7, "Level indicator warningValue was not stored.")
    expect(level.criticalValue == 9, "Level indicator criticalValue was not stored.")

    let handle = level.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "progressIndicator", "Level indicator did not request progress-style native peer.")
    expect(backend.records[handle]?.progressMinValue == 0, "Level indicator minValue was not synced.")
    expect(backend.records[handle]?.progressMaxValue == 10, "Level indicator maxValue was not synced.")
    expect(backend.records[handle]?.progressValue == 6, "Level indicator value was not synced.")

    level.doubleValue = 20
    expect(level.doubleValue == 10, "Level indicator did not clamp to maxValue.")
    expect(backend.records[handle]?.progressValue == 10, "Level indicator clamped value was not synced.")
    expect(!level.acceptsFirstResponder, "Level indicator should skip key-view traversal.")
}

func testScrollerStoresValueAndSyncsNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let scroller = NSScroller(frame: NSMakeRect(0, 0, 20, 120))
    scroller.doubleValue = 0.4
    scroller.knobProportion = 0.25

    expect(scroller.doubleValue == 0.4, "Scroller doubleValue was not stored.")
    expect(scroller.knobProportion == 0.25, "Scroller knobProportion was not stored.")
    expect(scroller.isVertical, "Scroller orientation did not infer vertical frame.")
    expect(!scroller.acceptsFirstResponder, "Scroller should skip key-view traversal.")

    let handle = scroller.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "scroller", "Scroller did not request native scroller peer.")
    expect(backend.records[handle]?.sliderValue == 0.4, "Scroller value was not synced.")
    expect(backend.records[handle]?.scrollerKnobProportion == 0.25, "Scroller knob proportion was not synced.")
    expect(backend.records[handle]?.scrollerIsVertical == true, "Scroller orientation was not synced.")

    scroller.setFloatValue(1.5, knobProportion: -1)
    expect(scroller.doubleValue == 1, "Scroller did not clamp doubleValue.")
    expect(scroller.knobProportion == 0, "Scroller did not clamp knobProportion.")
    expect(backend.records[handle]?.sliderValue == 1, "Scroller clamped value was not synced.")
}

func testScrollerNativeActionUpdatesValue() {
    let backend = InMemoryNativeControlBackend()
    let scroller = NSScroller(frame: NSMakeRect(0, 0, 120, 18))
    var actionCount = 0
    scroller.onAction = { control in
        guard let scroller = control as? NSScroller else {
            expect(false, "Scroller action sender was not scroller.")
            return
        }

        actionCount += 1
        expect(scroller.doubleValue == 0.75, "Scroller action did not read native value.")
        expect(scroller.hitPart == .knob, "Scroller did not report the knob hit part.")
    }

    let handle = scroller.realizeNativePeer(in: backend, parent: nil)
    backend.simulateScrollerPart(.knob, value: 0.75, for: handle)

    expect(actionCount == 1, "Scroller native action was not dispatched.")
}

func testScrollerHitPartReflectsGesture() {
    let backend = InMemoryNativeControlBackend()
    let scroller = NSScroller(frame: NSMakeRect(0, 0, 120, 18))
    let handle = scroller.realizeNativePeer(in: backend, parent: nil)

    // Each backend part maps to the matching AppKit hit part.
    let cases: [(NativeScrollerPart, NSScroller.Part)] = [
        (.decrementLine, .decrementLine),
        (.incrementLine, .incrementLine),
        (.decrementPage, .decrementPage),
        (.incrementPage, .incrementPage),
        (.knob, .knob),
    ]
    for (native, expected) in cases {
        backend.simulateScrollerPart(native, for: handle)
        expect(scroller.hitPart == expected, "Scroller hit part did not follow the \(native) gesture.")
    }
}

func testDatePickerStoresDateRangeAndSyncsNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let initialDate = Date(timeIntervalSince1970: 1_780_272_000)
    let minDate = Date(timeIntervalSince1970: 1_735_689_600)
    let maxDate = Date(timeIntervalSince1970: 1_893_456_000)
    let picker = NSDatePicker(date: initialDate, frame: NSMakeRect(0, 0, 180, 28))
    var actionCount = 0

    picker.minDate = minDate
    picker.maxDate = maxDate
    picker.onAction = { control in
        expect(control === picker, "Date picker action sender was not picker.")
        actionCount += 1
    }

    expect(picker.dateValue == initialDate, "Date picker dateValue was not stored.")
    expect(picker.minDate == minDate, "Date picker minDate was not stored.")
    expect(picker.maxDate == maxDate, "Date picker maxDate was not stored.")
    expect(picker.stringValue == "6/1/2026", "Date picker stringValue did not format the date in US style.")
    expect(picker.acceptsFirstResponder, "Date picker should accept first responder.")

    let handle = picker.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "datePicker", "Date picker did not request native date picker peer.")
    expect(backend.records[handle]?.datePickerDate == initialDate, "Date picker did not sync initial date.")
    expect(backend.records[handle]?.datePickerMinDate == minDate, "Date picker did not sync min date.")
    expect(backend.records[handle]?.datePickerMaxDate == maxDate, "Date picker did not sync max date.")

    let nextDate = Date(timeIntervalSince1970: 1_783_036_800)
    picker.dateValue = nextDate
    expect(backend.records[handle]?.datePickerDate == nextDate, "Date picker date changes did not sync.")

    backend.actions[handle]?()
    expect(actionCount == 1, "Date picker native action did not fire.")
}

func testSegmentedControlStoresSegmentsAndComposesButtons() {
    let backend = InMemoryNativeControlBackend()
    let segmented = NSSegmentedControl(labels: ["One", "Two"], frame: NSMakeRect(0, 0, 160, 28))
    segmented.setLabel("First", forSegment: 0)
    segmented.setWidth(90, forSegment: 0)
    segmented.setEnabled(false, forSegment: 1)
    segmented.selectedSegment = 0

    expect(segmented.segmentCount == 2, "Segmented control segment count was not stored.")
    expect(segmented.label(forSegment: 0) == "First", "Segmented control label was not stored.")
    expect(segmented.width(forSegment: 0) == 90, "Segmented control width was not stored.")
    expect(!segmented.isEnabled(forSegment: 1), "Segmented control segment enabled state was not stored.")
    expect(segmented.isSelected(forSegment: 0), "Segmented control selected segment was not stored.")

    let handle = segmented.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "view", "Segmented control did not request a native container view.")
    expect(segmented.subviews.count == 2, "Segmented control did not compose segment buttons.")
    guard segmented.subviews.count == 2,
          let first = segmented.subviews[0] as? NSButton,
          let second = segmented.subviews[1] as? NSButton,
          let firstHandle = first.nativeHandle,
          let secondHandle = second.nativeHandle else {
        expect(false, "Segmented control segment buttons were not realized.")
        return
    }

    expect(backend.records[firstHandle]?.kind == "button", "First segment was not backed by a button.")
    expect(backend.records[firstHandle]?.text == "First", "First segment label was not synced.")
    expect(backend.records[firstHandle]?.frame.size.width == 90, "First segment width was not synced.")
    expect(backend.records[secondHandle]?.isEnabled == false, "Second segment enabled state was not synced.")
}

func testSegmentedControlPerSegmentImageAndTag() {
    let segmented = NSSegmentedControl(labels: ["Grid", "List"], frame: NSMakeRect(0, 0, 160, 28))

    // Per-segment tags round-trip and follow the selection.
    segmented.setTag(11, forSegment: 0)
    segmented.setTag(22, forSegment: 1)
    expect(segmented.tag(forSegment: 0) == 11, "Segment tag was not stored.")
    expect(segmented.tag(forSegment: 1) == 22, "Second segment tag was not stored.")
    segmented.selectedSegment = 1
    expect(segmented.selectedSegmentTag() == 22, "selectedSegmentTag did not follow the selection.")

    // Per-segment images round-trip and reach the composed button.
    let icon = NSImage(named: "grid.symbol")
    segmented.setImage(icon, forSegment: 0)
    expect(segmented.image(forSegment: 0) === icon, "Segment image was not stored.")
    expect(segmented.image(forSegment: 1) == nil, "Unset segment image should be nil.")
    guard segmented.subviews.indices.contains(0), let firstButton = segmented.subviews[0] as? NSButton else {
        expect(false, "Segment button was not composed.")
        return
    }
    expect(firstButton.image === icon, "Segment image did not reach the composed button.")
    // A labeled segment with an image shows the image beside the label.
    expect(firstButton.imagePosition == .imageLeft, "Labeled segment with image should place the image left.")
}

func testSegmentedControlActionSelectsSegment() {
    let segmented = NSSegmentedControl(labels: ["One", "Two"], frame: NSMakeRect(0, 0, 160, 28))
    var actionCount = 0
    segmented.onAction = { control in
        guard let segmented = control as? NSSegmentedControl else {
            expect(false, "Segmented action sender was not segmented control.")
            return
        }

        actionCount += 1
        expect(segmented.selectedSegment == 1, "Segmented control did not select clicked segment.")
    }

    guard segmented.subviews.count == 2,
          let second = segmented.subviews[1] as? NSButton else {
        expect(false, "Segmented control did not create segment buttons before realization.")
        return
    }

    second.performClick(nil)
    expect(actionCount == 1, "Segmented control action was not dispatched.")
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

func testSearchFieldTracksRecentSearchesAndNativeChanges() {
    let backend = InMemoryNativeControlBackend()
    let searchField = NSSearchField(frame: NSMakeRect(0, 0, 180, 28))
    var actionCount = 0
    searchField.onAction = { control in
        actionCount += 1
        expect(control is NSSearchField, "Search field action sender was not search field.")
    }

    let handle = searchField.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[handle]?.kind == "editableTextField", "Search field did not use editable native peer.")

    backend.textChangeActions[handle]?("cocoa")

    expect(searchField.stringValue == "cocoa", "Search field native edit did not update stringValue.")
    expect(searchField.recentSearches == ["cocoa"], "Search field did not remember immediate search.")
    expect(actionCount == 1, "Search field did not send immediate search action.")

    searchField.cancelSearch(nil)
    expect(searchField.stringValue.isEmpty, "Search field cancel did not clear text.")
    expect(actionCount == 2, "Search field cancel did not send action.")
}

func testColorWellStoresColorAndSendsAction() {
    let backend = InMemoryNativeControlBackend()
    // A well click presents the shared color panel, which must land on the
    // in-memory backend rather than a real native window.
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    let colorWell = NSColorWell(frame: NSMakeRect(0, 0, 40, 24))
    colorWell.color = .red
    var actionCount = 0
    colorWell.onAction = { control in
        actionCount += 1
        expect((control as? NSColorWell)?.color == .blue, "Color well action did not expose color.")
    }

    let handle = colorWell.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "imageView", "Color well did not request a bordered swatch peer.")
    expect(backend.records[handle]?.backgroundColor == .red, "Color well color was not synced to background.")

    colorWell.color = .blue
    expect(backend.records[handle]?.backgroundColor == .blue, "Color well updated color was not synced.")

    backend.mouseDownActions[handle]?(NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(2, 2)))

    expect(colorWell.isActive, "Color well did not activate on click.")
    expect(actionCount == 1, "Color well did not send action on click.")
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

    backend.scrollTableRowToVisible(2, for: handle)
    expect(backend.records[handle]?.tableVisibleRow == 2, "Table visible-row request was not recorded.")
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

func testSplitViewArrangesSubviewsAndDividerPosition() {
    let splitView = NSSplitView(frame: NSMakeRect(0, 0, 300, 100))
    let first = NSView(frame: NSZeroRect)
    let second = NSView(frame: NSZeroRect)

    splitView.addSubview(first)
    splitView.addSubview(second)

    expect(!splitView.acceptsFirstResponder, "Split view should not accept first responder by default.")
    expect(first.frame == NSMakeRect(0, 0, 146, 100), "Vertical split did not size first pane evenly.")
    expect(second.frame == NSMakeRect(154, 0, 146, 100), "Vertical split did not size second pane evenly.")

    splitView.setPosition(120, ofDividerAt: 0)

    expect(first.frame == NSMakeRect(0, 0, 120, 100), "Split divider did not resize first pane.")
    expect(second.frame == NSMakeRect(128, 0, 172, 100), "Split divider did not resize second pane.")

    splitView.isVertical = false

    expect(first.frame == NSMakeRect(0, 0, 300, 46), "Horizontal split did not size first pane evenly.")
    expect(second.frame == NSMakeRect(0, 54, 300, 46), "Horizontal split did not size second pane evenly.")
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
    let dragEvent = NSEvent(type: .leftMouseDragged, locationInWindow: NSMakePoint(8, 9))
    let keyEvent = NSEvent(type: .keyDown, locationInWindow: NSMakePoint(0, 0))

    child.nextResponder = parent
    child.mouseDown(with: mouseEvent)
    child.mouseDragged(with: dragEvent)
    child.keyDown(with: keyEvent)

    expect(parent.mouseDownCount == 1, "Mouse event did not forward to next responder.")
    expect(parent.mouseDraggedCount == 1, "Mouse-dragged event did not forward to next responder.")
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

func testWindowSelectNextKeyViewSkipsHiddenContainerChildren() {
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 140, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: InMemoryNativeControlBackend()
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 140, 100))
    let first = NSButton(title: "First", frame: NSMakeRect(0, 0, 40, 20))
    let hiddenContainer = NSView(frame: NSMakeRect(0, 24, 80, 48))
    let hiddenChild = NSButton(title: "Hidden", frame: NSMakeRect(0, 0, 60, 20))
    let fallback = NSButton(title: "Fallback", frame: NSMakeRect(0, 76, 60, 20))

    hiddenContainer.isHidden = true
    first.nextKeyView = hiddenChild
    hiddenChild.nextKeyView = fallback
    hiddenContainer.addSubview(hiddenChild)
    contentView.addSubview(first)
    contentView.addSubview(hiddenContainer)
    contentView.addSubview(fallback)
    window.contentView = contentView
    window.realizeNativePeer()

    expect(window.makeFirstResponder(first), "Window did not accept first key view.")

    window.selectNextKeyView(nil)

    expect(window.firstResponder === fallback, "Window did not skip hidden key view container children.")
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

func testNativeMouseDraggedDispatchesToView() {
    let backend = InMemoryNativeControlBackend()
    let view = RecordingView(frame: NSMakeRect(0, 0, 100, 100))
    let handle = view.realizeNativePeer(in: backend, parent: nil)
    let event = NSEvent(type: .leftMouseDragged, locationInWindow: NSMakePoint(11, 13), modifierFlags: [.option])

    backend.mouseDraggedActions[handle]?(event)

    expect(view.mouseDraggedCount == 1, "Native mouse-dragged action did not reach view.")
    expect(view.lastEvent == event, "Native mouse-dragged event was not forwarded intact.")
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

    expect(backend.records[handle]?.usesMainMenu == true, "Normal windows should request the application main menu.")
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

func testNativeWindowResizeUpdatesContentAndAutoresizesSubviews() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(10, 20, 200, 120),
        styleMask: [.titled, .resizable],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 200, 120))
    let stretchView = NSView(frame: NSMakeRect(10, 10, 80, 30))
    let trailingView = NSView(frame: NSMakeRect(150, 80, 30, 20))
    stretchView.autoresizingMask = [.width]
    trailingView.autoresizingMask = [.minXMargin, .minYMargin]
    contentView.addSubview(stretchView)
    contentView.addSubview(trailingView)
    window.contentView = contentView
    let handle = window.realizeNativePeer()

    guard let resizeAction = backend.windowResizeActions[handle] else {
        fatalError("Window did not register native resize action.")
    }

    resizeAction(NSMakeSize(260, 180))

    expect(window.frame.size == NSMakeSize(260, 180), "Native resize did not update window frame size.")
    expect(contentView.frame == NSMakeRect(0, 0, 260, 180), "Native resize did not update content view frame.")
    expect(backend.records[contentView.nativeHandle!]?.frame == contentView.frame, "Native resize did not sync content view frame to backend.")
    expect(stretchView.frame == NSMakeRect(10, 10, 140, 30), "Autoresizing width mask did not stretch subview.")
    expect(trailingView.frame == NSMakeRect(210, 140, 30, 20), "Autoresizing margins did not move trailing subview.")
}

func testPanelStoresPanelStateAndOrdersFront() {
    clearApplicationWindows()

    let backend = InMemoryNativeControlBackend()
    let panel = NSPanel(
        contentRect: NSMakeRect(20, 30, 240, 120),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )

    panel.title = "Inspector"
    panel.isFloatingPanel = true
    panel.hidesOnDeactivate = true
    panel.becomesKeyOnlyIfNeeded = true
    panel.worksWhenModal = true
    panel.orderFrontRegardless()

    guard let handle = panel.nativeHandle else {
        fatalError("Panel did not realize native peer.")
    }

    expect(panel.isFloatingPanel, "Panel floating flag was not stored.")
    expect(panel.hidesOnDeactivate, "Panel deactivate-hiding flag was not stored.")
    expect(panel.becomesKeyOnlyIfNeeded, "Panel key-only-if-needed flag was not stored.")
    expect(panel.worksWhenModal, "Panel modal interaction flag was not stored.")
    expect(backend.records[handle]?.kind == "window", "Panel did not use the window backend peer.")
    expect(backend.records[handle]?.text == "Inspector", "Panel title was not synced.")
    expect(backend.records[handle]?.usesMainMenu == false, "Panel should not request the application main menu.")
    expect(NSApplication.shared.windows.contains { $0 === panel }, "Panel was not tracked in application windows.")
    expect(NSApplication.shared.keyWindow !== panel, "orderFrontRegardless should not force key window in this slice.")

    guard let closeAction = backend.windowCloseActions[handle] else {
        fatalError("Panel did not register native close cleanup.")
    }

    closeAction()

    expect(panel.nativeHandle == nil, "Native panel close did not clear panel handle.")
    expect(!NSApplication.shared.windows.contains { $0 === panel }, "Native panel close did not remove panel from application windows.")
    expect(!backend.didTerminateApplication, "Native panel close should not terminate the application.")

    panel.orderFrontRegardless()

    expect(panel.nativeHandle != nil, "Panel did not reopen after native close.")

    clearApplicationWindows()
}

func testPopoverShowsClosesAndReopensFromAnchorView() {
    clearApplicationWindows()

    let previousBackend = NSApplication.shared.nativeBackend
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        clearApplicationWindows()
    }

    let window = NSWindow(
        contentRect: NSMakeRect(100, 120, 400, 300),
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 400, 300))
    let anchor = NSButton(title: "Anchor", frame: NSMakeRect(24, 32, 80, 30))
    contentView.addSubview(anchor)
    window.contentView = contentView
    window.makeKeyAndOrderFront(nil)

    let popoverContent = NSView(frame: NSMakeRect(0, 0, 160, 90))
    let popover = NSPopover()
    popover.animates = false
    popover.behavior = .transient
    popover.contentSize = NSMakeSize(160, 90)
    popover.contentViewController = NSViewController(view: popoverContent)
    popover.show(relativeTo: NSMakeRect(4, 6, 20, 18), of: anchor, preferredEdge: .maxY)

    guard let panel = NSApplication.shared.windows.compactMap({ $0 as? NSPanel }).last,
          let panelHandle = panel.nativeHandle else {
        fatalError("Popover did not create a panel host.")
    }

    expect(popover.isShown, "Popover did not report shown state.")
    expect(panel.contentView === popoverContent, "Popover did not install controller view as panel content.")
    expect(panel.styleMask == .borderless, "Popover host should use a borderless panel style.")
    expect(backend.records[panelHandle]?.usesMainMenu == false, "Popover host should not request the application main menu.")
    expect(backend.records[panelHandle]?.frame == NSMakeRect(128, 184, 160, 90), "Popover did not position relative to anchor view.")

    popover.performClose(nil)

    expect(!popover.isShown, "Popover did not report closed state.")
    expect(panel.nativeHandle == nil, "Popover close did not close the host panel.")
    expect(!NSApplication.shared.windows.contains { $0 === panel }, "Popover close did not remove the host panel from application windows.")

    popover.show(relativeTo: NSMakeRect(4, 6, 20, 18), of: anchor, preferredEdge: .maxX)

    expect(popover.isShown, "Popover did not report shown state after reopening.")
    expect(panel.nativeHandle != nil, "Popover host panel did not reopen.")
}

func testPopoverAnimatesFadesHost() {
    clearApplicationWindows()

    let previousBackend = NSApplication.shared.nativeBackend
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        clearApplicationWindows()
    }

    let window = NSWindow(
        contentRect: NSMakeRect(100, 120, 400, 300),
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 400, 300))
    let anchor = NSButton(title: "Anchor", frame: NSMakeRect(24, 32, 80, 30))
    contentView.addSubview(anchor)
    window.contentView = contentView
    window.makeKeyAndOrderFront(nil)

    let popover = NSPopover()
    popover.animates = true
    popover.behavior = .applicationDefined
    popover.contentSize = NSMakeSize(160, 90)
    popover.contentViewController = NSViewController(view: NSView(frame: NSMakeRect(0, 0, 160, 90)))
    popover.show(relativeTo: NSMakeRect(4, 6, 20, 18), of: anchor, preferredEdge: .maxY)

    guard let panel = NSApplication.shared.windows.compactMap({ $0 as? NSPanel }).last,
          let panelHandle = panel.nativeHandle else {
        fatalError("Popover did not create a panel host.")
    }

    // An animated show fades the host in rather than a plain show.
    expect(backend.fadedWindows[panelHandle] == true, "Animated popover did not fade its host in.")
    expect(backend.records[panelHandle]?.isHidden == false, "Faded-in popover host should be visible.")

    popover.performClose(nil)

    // An animated close fades the host out before it is destroyed.
    expect(backend.fadedWindows[panelHandle] == false, "Animated popover did not fade its host out on close.")
}

func testToolbarStoresItemsAndAttachesToWindow() {
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 320, 200),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: InMemoryNativeControlBackend()
    )
    let toolbar = NSToolbar(identifier: "main")
    let openItem = NSToolbarItem(itemIdentifier: "open")
    let flexibleItem = NSToolbarItem(itemIdentifier: .flexibleSpace)
    let saveItem = NSToolbarItem(itemIdentifier: "save")

    openItem.label = "Open"
    openItem.paletteLabel = "Open File"
    openItem.toolTip = "Open a document"
    toolbar.addItem(openItem)
    toolbar.addItem(saveItem)
    toolbar.insertItem(flexibleItem, at: 1)
    toolbar.displayMode = .iconAndLabel
    toolbar.sizeMode = .small
    toolbar.allowsUserCustomization = true

    window.toolbar = toolbar

    expect(window.toolbar === toolbar, "Window did not store toolbar.")
    expect(toolbar.window === window, "Toolbar did not attach back to window.")
    expect(toolbar.items.map(\.itemIdentifier) == ["open", .flexibleSpace, "save"], "Toolbar item ordering was not preserved.")
    expect(toolbar.item(withIdentifier: "open") === openItem, "Toolbar did not find item by identifier.")
    expect(openItem.toolbar === toolbar, "Toolbar item did not retain toolbar back-reference.")
    expect(openItem.label == "Open", "Toolbar item label was not stored.")
    expect(openItem.paletteLabel == "Open File", "Toolbar item palette label was not stored.")
    expect(openItem.toolTip == "Open a document", "Toolbar item tooltip was not stored.")
    expect(toolbar.displayMode == .iconAndLabel, "Toolbar display mode was not stored.")
    expect(toolbar.sizeMode == .small, "Toolbar size mode was not stored.")
    expect(toolbar.allowsUserCustomization, "Toolbar customization flag was not stored.")

    let removed = toolbar.removeItem(at: 1)

    expect(removed === flexibleItem, "Toolbar did not remove the expected item.")
    expect(flexibleItem.toolbar == nil, "Removed toolbar item still referenced its toolbar.")
    expect(toolbar.items.map(\.itemIdentifier) == ["open", "save"], "Toolbar removal did not update ordering.")

    let replacement = NSToolbar(identifier: "secondary")
    window.toolbar = replacement

    expect(toolbar.window == nil, "Replacing window toolbar did not detach old toolbar.")
    expect(replacement.window === window, "Replacing window toolbar did not attach new toolbar.")
}

func testToolbarVisibilityAndItemActions() {
    let toolbar = NSToolbar(identifier: "actions")
    let item = NSToolbarItem(itemIdentifier: "click")
    let button = NSButton(title: "Click", frame: NSMakeRect(0, 0, 80, 28))
    var visibilityStates: [Bool] = []
    var toolbarActionCount = 0
    var buttonActionCount = 0

    toolbar.visibilityDidChange = { isVisible in
        visibilityStates.append(isVisible)
    }
    item.onAction = { _ in
        toolbarActionCount += 1
    }
    button.onAction = { _ in
        buttonActionCount += 1
    }

    item.view = button
    item.isEnabled = false
    item.performAction()

    expect(!button.isEnabled, "Toolbar item enabled state did not sync to its control view.")
    expect(buttonActionCount == 0, "Disabled toolbar item should not activate its control view.")
    expect(toolbarActionCount == 0, "Disabled toolbar item should not invoke closure action.")

    item.isEnabled = true
    item.performAction()

    expect(button.isEnabled, "Toolbar item did not re-enable its control view.")
    expect(buttonActionCount == 1, "Toolbar item did not activate its custom control view.")
    expect(toolbarActionCount == 0, "Toolbar item with a control view should prefer the control action.")

    item.view = nil
    item.performAction()

    expect(toolbarActionCount == 1, "Toolbar item did not invoke its closure action.")

    toolbar.isVisible = false
    toolbar.isVisible = true

    expect(visibilityStates == [false, true], "Toolbar visibility change callback did not receive expected states.")
}

func testToolbarCustomizationDelegateAndDefaultItems() {
    let toolbar = NSToolbar(identifier: "customizable")
    let delegate = RecordingToolbarDelegate()
    let openItem = NSToolbarItem(itemIdentifier: "open")

    openItem.label = "Open"
    toolbar.delegate = delegate
    toolbar.addItem(openItem)

    toolbar.setVisibleItemIdentifiers(["open", "customize"])

    expect(toolbar.items.map(\.itemIdentifier) == ["open", "customize"], "Toolbar did not apply visible customization identifiers.")
    expect(toolbar.item(withIdentifier: "customize")?.label == "Customize", "Toolbar did not retain delegate-created customization item.")
    expect(delegate.requestedIdentifiers == ["customize"], "Toolbar did not ask delegate for missing customization item.")
    expect(delegate.insertionFlags == [true], "Toolbar did not pass insertion flag when creating visible item.")
    expect(openItem.toolbar === toolbar, "Existing toolbar item lost its toolbar back-reference.")

    toolbar.resetVisibleItemsToDefault()

    expect(toolbar.items.map(\.itemIdentifier) == ["open", "save"], "Toolbar did not restore delegate default item identifiers.")
    expect(toolbar.item(withIdentifier: "save")?.label == "Save", "Toolbar did not create default item through delegate.")
    expect(toolbar.item(withIdentifier: "customize")?.label == "Customize", "Toolbar item store did not preserve hidden customization item.")
}

func testToolbarCustomizationAllowsDuplicateStructuralItems() {
    let toolbar = NSToolbar(identifier: "customizable")

    toolbar.setVisibleItemIdentifiers([.separator, .separator, .flexibleSpace, .flexibleSpace])

    expect(toolbar.items.map(\.itemIdentifier) == [.separator, .separator, .flexibleSpace, .flexibleSpace], "Toolbar did not keep duplicate structural customization items.")
    expect(toolbar.items[0] !== toolbar.items[1], "Duplicate separators should be distinct toolbar item instances.")
    expect(toolbar.items[2] !== toolbar.items[3], "Duplicate flexible spaces should be distinct toolbar item instances.")
}

func testToolbarCustomizationPaletteShowsToolbarDropTargetAtTop() {
    clearApplicationWindows()

    let toolbar = NSToolbar(identifier: "customizable")
    let delegate = RecordingToolbarDelegate()
    let openItem = NSToolbarItem(itemIdentifier: "open")
    let saveItem = NSToolbarItem(itemIdentifier: "save")

    openItem.label = "Open"
    saveItem.label = "Save"
    toolbar.delegate = delegate
    toolbar.allowsUserCustomization = true
    toolbar.addItem(openItem)
    toolbar.addItem(saveItem)

    toolbar.runCustomizationPalette(nil)

    guard let panel = NSApplication.shared.windows.compactMap({ $0 as? NSPanel }).last,
          let contentView = panel.contentView else {
        expect(false, "Toolbar customization palette did not create a panel.")
        return
    }

    let strip = contentView.subviews.first { $0.tag == 1_103 }
    let toolbarTiles = (strip?.subviews ?? [])
        .filter { $0.toolTip == "Drag to reorder or drag out to remove." && $0.frame.origin.y == 8 }

    expect(panel.styleMask.contains(.resizable), "Toolbar customization palette should be resizable.")
    expect(contentView.tag == 1_100, "Toolbar customization palette did not mark the content as the toolbar drop surface.")
    expect(strip?.frame.origin.y == 0, "Toolbar customization strip was not docked at the top.")
    expect(toolbarTiles.count == 2, "Toolbar customization top row did not mirror visible toolbar item count.")
    expect(toolbar.items.map(\.label) == ["Open", "Save"], "Toolbar customization top row did not mirror visible toolbar items.")
    expect(toolbarTiles.allSatisfy { $0.frame.origin.y < 42 }, "Toolbar customization top row was not docked at the top.")
    expect(!contentView.subviews.compactMap { ($0 as? NSTextField)?.stringValue }.contains("Mock toolbar drop target:"), "Toolbar customization palette still labels the drop target as a mock toolbar.")

    let paletteWidth = contentView.subviews.first { $0.tag == 1_101 }?.frame.size.width ?? 0
    expect(paletteWidth > 0, "Toolbar customization palette container was not tagged for lookup.")
    panel.setContentSize(NSMakeSize(900, 560))
    let resizedPaletteWidth = contentView.subviews.first { $0.tag == 1_101 }?.frame.size.width ?? 0
    expect(resizedPaletteWidth > paletteWidth, "Toolbar customization palette contents did not autoresize horizontally.")

    clearApplicationWindows()
}

func testToolbarCustomizationMovesExistingItemToEnd() {
    clearApplicationWindows()

    let toolbar = NSToolbar(identifier: "customizable")
    let openItem = NSToolbarItem(itemIdentifier: "open")
    let saveItem = NSToolbarItem(itemIdentifier: "save")
    let printItem = NSToolbarItem(itemIdentifier: "print")

    openItem.label = "Open"
    saveItem.label = "Save"
    printItem.label = "Print"
    toolbar.allowsUserCustomization = true
    toolbar.addItem(openItem)
    toolbar.addItem(saveItem)
    toolbar.addItem(printItem)

    toolbar.runCustomizationPalette(nil)

    guard let panel = NSApplication.shared.windows.compactMap({ $0 as? NSPanel }).last,
          let contentView = panel.contentView else {
        expect(false, "Toolbar customization palette did not create a panel.")
        return
    }

    let strip = contentView.subviews.first { $0.tag == 1_103 }
    let toolbarTiles = (strip?.subviews ?? [])
        .filter { $0.toolTip == "Drag to reorder or drag out to remove." && $0.frame.origin.y == 8 }
        .sorted { $0.frame.origin.x < $1.frame.origin.x }

    guard let openTile = toolbarTiles.first else {
        expect(false, "Toolbar customization top row did not create toolbar item tiles.")
        return
    }

    let start = openTile.convert(NSMakePoint(openTile.bounds.size.width / 2, openTile.bounds.size.height / 2), to: nil)
    // Drop just inside the trailing edge of the toolbar strip; the content view
    // is resized to the native client area, so the width cannot be hard-coded.
    let end = contentView.convert(NSMakePoint(contentView.frame.size.width - 10, 20), to: nil)

    openTile.mouseDown(with: NSEvent(type: .leftMouseDown, locationInWindow: start))
    openTile.mouseDragged(with: NSEvent(type: .leftMouseDragged, locationInWindow: end))
    openTile.mouseUp(with: NSEvent(type: .leftMouseUp, locationInWindow: end))

    expect(toolbar.items.map(\.itemIdentifier) == ["save", "print", "open"], "Dragging an existing toolbar item to the far end did not move it to the end.")

    clearApplicationWindows()
}

func testToolbarViewComposesItemsAndDispatchesActions() {
    let backend = InMemoryNativeControlBackend()
    let toolbar = NSToolbar(identifier: "native")
    let openItem = NSToolbarItem(itemIdentifier: "open")
    let separator = NSToolbarItem(itemIdentifier: .separator)
    let flexibleSpace = NSToolbarItem(itemIdentifier: .flexibleSpace)
    let saveItem = NSToolbarItem(itemIdentifier: "save")
    let toolbarView = NSToolbarView(frame: NSMakeRect(0, 0, 280, 36))
    var firedIdentifiers: [String] = []

    openItem.label = "Open"
    openItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: "Open")
    saveItem.label = "Save"
    saveItem.isEnabled = false
    openItem.onAction = { item in
        firedIdentifiers.append(item.itemIdentifier.rawValue)
    }
    saveItem.onAction = { item in
        firedIdentifiers.append(item.itemIdentifier.rawValue)
    }
    toolbar.addItem(openItem)
    toolbar.addItem(separator)
    toolbar.addItem(flexibleSpace)
    toolbar.addItem(saveItem)
    toolbarView.toolbar = toolbar

    let handle = toolbarView.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "view", "Toolbar view did not request a composed native host view.")
    expect(backend.records[handle]?.toolbarItems.isEmpty == true, "Composed toolbar host should not install native toolbar item descriptors.")

    expect(toolbarView.subviews.count == 5, "Composed toolbar did not create one top-level view per toolbar item plus the chrome hairline.")
    expect(toolbarView.subviews[0].subviews.isEmpty, "Composed toolbar open item should be one self-contained view.")
    expect(toolbarView.subviews[0].backgroundColor == nil, "Composed toolbar item should let the toolbar background show through.")
    if let openHandle = toolbarView.subviews[0].nativeHandle {
        expect(backend.records[openHandle]?.drawsBackground == false, "Composed toolbar item should request a clear native background.")
    }
    expect(toolbarView.subviews[1] is NSToolbarSeparatorView, "Composed toolbar separator did not render as a simple separator view.")
    if let separatorHandle = toolbarView.subviews[1].nativeHandle {
        expect(backend.records[separatorHandle]?.drawsBackground == false, "Composed toolbar separator should request a clear native background.")
    }
    if let flexibleSpaceHandle = toolbarView.subviews[2].nativeHandle {
        expect(backend.records[flexibleSpaceHandle]?.drawsBackground == false, "Composed toolbar space should request a clear native background.")
    }
    expect(toolbarView.subviews[3].subviews.isEmpty, "Composed toolbar save item should be one self-contained view.")
    expect(toolbarView.subviews[3].backgroundColor == nil, "Composed toolbar item should not draw its own background.")
    if let saveHandle = toolbarView.subviews[3].nativeHandle {
        expect(backend.records[saveHandle]?.drawsBackground == false, "Composed toolbar item should keep its native background clear.")
    }

    let realizedItemTexts = backend.records.values.compactMap(\.text)
    expect(
        realizedItemTexts.contains("__WinChocolateToolbarItem\tOpen\tfolder\t1\t1\tbelow"),
        "Composed toolbar did not render the open item label and image."
    )
    expect(
        realizedItemTexts.contains("__WinChocolateToolbarItem\tSave\tsave\t1\t1\tbelow"),
        "Composed toolbar did not render the save item label and image."
    )

    let firstPoint = toolbarView.subviews[0].convert(NSMakePoint(4, 4), to: nil)
    let lastPoint = toolbarView.subviews[3].convert(NSMakePoint(4, 4), to: nil)
    toolbarView.subviews[0].mouseDown(with: NSEvent(type: .leftMouseDown, locationInWindow: firstPoint))
    toolbarView.subviews[0].mouseUp(with: NSEvent(type: .leftMouseUp, locationInWindow: firstPoint))
    toolbarView.subviews[3].mouseDown(with: NSEvent(type: .leftMouseDown, locationInWindow: lastPoint))
    toolbarView.subviews[3].mouseUp(with: NSEvent(type: .leftMouseUp, locationInWindow: lastPoint))

    expect(firedIdentifiers == ["open"], "Composed toolbar dispatch did not honor enabled item actions.")

    saveItem.isEnabled = true
    toolbarView.reloadItems()

    let enabledPoint = toolbarView.subviews[3].convert(NSMakePoint(4, 4), to: nil)
    toolbarView.subviews[3].mouseDown(with: NSEvent(type: .leftMouseDown, locationInWindow: enabledPoint))
    toolbarView.subviews[3].mouseUp(with: NSEvent(type: .leftMouseUp, locationInWindow: enabledPoint))
    expect(firedIdentifiers == ["open", "save"], "Toolbar reload did not update enabled state.")

    toolbar.displayMode = .iconOnly

    let iconOnlyTexts = backend.records.values.compactMap(\.text)
    expect(
        iconOnlyTexts.contains("__WinChocolateToolbarItem\tOpen\tfolder\t1\t0\tbelow"),
        "Toolbar icon-only mode did not preserve the item image."
    )

    toolbar.displayMode = .labelOnly

    let labelOnlyTexts = backend.records.values.compactMap(\.text)
    expect(
        labelOnlyTexts.contains("__WinChocolateToolbarItem\tOpen\tfolder\t0\t1\tbelow"),
        "Toolbar label-only mode should preserve item labels."
    )
}

func testToolbarViewHostsCustomItemView() {
    let backend = InMemoryNativeControlBackend()
    let toolbar = NSToolbar(identifier: "customView")
    let selector = NSPopUpButton(frame: NSMakeRect(0, 0, 140, 28), pullsDown: false)
    let item = NSToolbarItem(itemIdentifier: "selector")
    let toolbarView = NSToolbarView(frame: NSMakeRect(0, 0, 300, 40))

    selector.addItems(withTitles: ["One", "Two"])
    item.label = "Selector"
    item.view = selector
    item.minSize = NSMakeSize(140, 28)
    item.maxSize = NSMakeSize(140, 28)
    toolbar.addItem(item)
    toolbarView.toolbar = toolbar

    let handle = toolbarView.realizeNativePeer(in: backend, parent: nil)

    expect(selector.superview === toolbarView, "Toolbar custom item view was not hosted by toolbar view.")
    expect(selector.nativeHandle != nil, "Toolbar custom item view did not realize a native peer.")
    expect(selector.frame == NSMakeRect(8, 6, 140, 28), "Toolbar custom item view was not positioned in the toolbar strip.")
    expect(selector.backgroundColor == nil, "Toolbar custom item view should let the toolbar background show through.")
    if let selectorHandle = selector.nativeHandle {
        expect(backend.records[selectorHandle]?.drawsBackground == false, "Toolbar custom control should request a clear native background.")
    }
    expect(backend.records[handle]?.kind == "view", "Toolbar custom item view should be hosted by a composed native view.")
    expect(backend.records[handle]?.toolbarItems.isEmpty == true, "Composed toolbar custom item should not reserve native toolbar separator space.")
}

func testToolbarItemCreatesCompositeImageLabelView() {
    let backend = InMemoryNativeControlBackend()
    let item = NSToolbarItem(itemIdentifier: "open")
    item.label = "Open"
    item.image = NSImage(named: "folder")

    let view = item.winCompositeView(showItem: true, showLabel: true, toolbarHeight: 40)
    let handle = view.realizeNativePeer(in: backend, parent: nil)

    expect(view.backgroundColor == nil, "Toolbar composite view should have a transparent background.")
    expect(view.subviews.isEmpty, "Toolbar composite view should render as one self-contained native view.")
    expect(view.frame.size.height <= 40, "Toolbar composite view did not fit within the toolbar height.")
    expect(
        backend.records[handle]?.text == "__WinChocolateToolbarItem\tOpen\tfolder\t1\t1\tbelow",
        "Toolbar composite view did not carry the label and image key."
    )
    expect(backend.records[handle]?.drawsBackground == false, "Toolbar composite view should request a clear native background.")

    let separator = NSToolbarItem(itemIdentifier: .separator)
    let separatorView = separator.winCompositeView(showItem: true, showLabel: false, toolbarHeight: 40)
    let separatorHandle = separatorView.realizeNativePeer(in: backend, parent: nil)

    expect(separatorView is NSToolbarSeparatorView, "Toolbar separator composite should be a simple separator view.")
    expect(separatorView.backgroundColor != nil, "Toolbar separator view should draw its own bar color.")
    expect(backend.records[separatorHandle]?.text.contains("separator") == true, "Toolbar separator view did not carry a separator image key.")
    expect(backend.records[separatorHandle]?.drawsBackground == false, "Toolbar separator view should request a clear native background.")
}

func testWindowToolbarCreatesDockedComposedHostAndReservesContent() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(20, 30, 320, 220),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 320, 220))
    let toolbar = NSToolbar(identifier: "windowToolbar")
    let item = NSToolbarItem(itemIdentifier: "open")

    item.label = "Open"
    toolbar.addItem(item)
    window.toolbar = toolbar
    window.contentView = contentView

    let windowHandle = window.realizeNativePeer()
    let toolbarRecords = backend.records.filter { $0.value.kind == "view" && $0.value.parent == windowHandle && $0.value.frame == NSMakeRect(0, 0, 320, 40) }

    expect(toolbarRecords.count == 1, "Window toolbar did not create exactly one composed toolbar host view.")
    guard let toolbarRecord = toolbarRecords.first else {
        return
    }

    expect(toolbarRecord.value.toolbarItems.isEmpty, "Composed toolbar host should not pass item descriptors to a native toolbar peer.")
    expect(
        backend.records.contains { $0.value.text.hasPrefix("__WinChocolateToolbarItem\tOpen") },
        "Window toolbar did not compose a label for the toolbar item."
    )
    expect(window.contentLayoutRect == NSMakeRect(0, 40, 320, 180), "Window toolbar did not reserve layout space.")
    expect(contentView.frame == NSMakeRect(0, 40, 320, 180), "Content view did not move below the toolbar strip.")

    item.label = "Open File"

    expect(
        backend.records.contains { $0.value.text.hasPrefix("__WinChocolateToolbarItem\tOpen File") },
        "Toolbar item label changes did not refresh the window-owned toolbar."
    )
}

func testWindowToolbarHeightFollowsDisplayMode() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(20, 30, 320, 220),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 320, 220))
    let toolbar = NSToolbar(identifier: "windowToolbarHeight")
    let item = NSToolbarItem(itemIdentifier: "open")

    item.label = "Open"
    item.image = NSImage(systemSymbolName: "folder", accessibilityDescription: "Open")
    toolbar.addItem(item)
    window.toolbar = toolbar
    window.contentView = contentView

    _ = window.realizeNativePeer()

    expect(window.toolbarHeight == 40, "Default toolbar height should fit icon and label display.")
    expect(contentView.frame == NSMakeRect(0, 40, 320, 180), "Default toolbar height did not reserve icon-and-label space.")

    toolbar.displayMode = .iconOnly

    expect(window.toolbarHeight == 30, "Icon-only toolbar mode should reduce toolbar height.")
    expect(contentView.frame == NSMakeRect(0, 30, 320, 190), "Icon-only toolbar mode did not reduce reserved content space.")

    toolbar.displayMode = .labelOnly

    expect(window.toolbarHeight == 26, "Label-only toolbar mode should reduce toolbar height.")
    expect(contentView.frame == NSMakeRect(0, 26, 320, 194), "Label-only toolbar mode did not reduce reserved content space.")

    toolbar.displayMode = .iconAndLabel
    toolbar.sizeMode = .small

    expect(window.toolbarHeight == 34, "Small icon-and-label toolbar mode should use compact toolbar height.")
    expect(contentView.frame == NSMakeRect(0, 34, 320, 186), "Small toolbar mode did not update reserved content space.")
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

    // Bezel and line-mode properties round-trip for AppKit source compatibility.
    expect(!textField.isBezeled, "isBezeled should default off.")
    expect(textField.bezelStyle == .squareBezel, "bezelStyle should default to square.")
    expect(textField.usesSingleLineMode, "usesSingleLineMode should default on.")
    expect(textField.maximumNumberOfLines == 1, "maximumNumberOfLines should default to 1.")

    textField.isBezeled = true
    textField.bezelStyle = .roundedBezel
    textField.usesSingleLineMode = false
    textField.maximumNumberOfLines = 0
    expect(textField.isBezeled, "isBezeled did not store.")
    expect(textField.bezelStyle == .roundedBezel, "bezelStyle did not store rounded.")
    expect(!textField.usesSingleLineMode, "usesSingleLineMode did not clear.")
    expect(textField.maximumNumberOfLines == 0, "maximumNumberOfLines did not store unlimited.")
}

func testFormComposesTextFieldsAndStoresCells() {
    let backend = InMemoryNativeControlBackend()
    let form = NSForm(frame: NSMakeRect(0, 0, 260, 90))
    form.titleWidth = 80

    let name = form.addEntry("Name:")
    let status = form.insertEntry("Status:", at: 1)
    form.setStringValue("WinChocolate", at: 0)
    form.setStringValue("Native", at: 1)

    expect(form.numberOfRows == 2, "Form row count was not stored.")
    expect(form.cell(at: 0) === name, "Form did not return first cell.")
    expect(form.cell(at: 1) === status, "Form did not return inserted cell.")
    expect(form.index(of: status) == 1, "Form did not find cell index.")
    expect(form.textField(at: 0)?.stringValue == "WinChocolate", "Form did not sync first text field value.")
    expect(form.textField(at: 1)?.stringValue == "Native", "Form did not sync second text field value.")
    expect(form.textField(at: 0)?.frame == NSMakeRect(88, 0, 172, 28), "Form did not lay out first text field.")
    expect(!form.acceptsFirstResponder, "Form container should not accept first responder.")

    let handle = form.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[handle]?.kind == "view", "Form did not request a native container view.")
    guard form.subviews.count == 4,
          let firstLabelHandle = form.subviews[0].nativeHandle,
          let firstFieldHandle = form.subviews[1].nativeHandle else {
        expect(false, "Form subviews were not realized.")
        return
    }

    expect(backend.records[firstLabelHandle]?.kind == "textField", "Form label did not use label text field peer.")
    expect(backend.records[firstFieldHandle]?.kind == "editableTextField", "Form entry did not use editable text field peer.")

    backend.textChangeActions[firstFieldHandle]?("Updated")
    expect(name.stringValue == "Updated", "Form cell did not track native text changes.")

    form.removeEntry(at: 0)
    expect(form.numberOfRows == 1, "Form did not remove entry.")
    expect(form.cell(at: 0) === status, "Form did not preserve remaining cell after removal.")
}

func testMatrixComposesButtonsAndTracksSelection() {
    let backend = InMemoryNativeControlBackend()
    let matrix = NSMatrix(
        frame: NSMakeRect(0, 0, 240, 80),
        mode: .radioModeMatrix,
        prototype: NSButtonCell(title: "Choice"),
        numberOfRows: 2,
        numberOfColumns: 2
    )
    var actionCount = 0

    matrix.cellSize = NSMakeSize(100, 28)
    matrix.intercellSpacing = NSMakeSize(8, 6)
    matrix.onAction = { control in
        expect(control === matrix, "Matrix action sender was not matrix.")
        actionCount += 1
    }

    expect(matrix.numberOfRows == 2, "Matrix row count was not stored.")
    expect(matrix.numberOfColumns == 2, "Matrix column count was not stored.")
    expect(matrix.cell(atRow: 0, column: 0)?.stringValue == "Choice 1,1", "Matrix did not create prototype-based cells.")
    expect(matrix.button(atRow: 0, column: 0)?.frame == NSMakeRect(0, 0, 100, 28), "Matrix did not lay out first button.")
    expect(matrix.button(atRow: 1, column: 1)?.frame == NSMakeRect(108, 34, 100, 28), "Matrix did not lay out last button.")
    expect(!matrix.acceptsFirstResponder, "Matrix container should not accept first responder.")

    matrix.selectCell(atRow: 1, column: 0)

    expect(matrix.selectedRow == 1, "Matrix selected row was not stored.")
    expect(matrix.selectedColumn == 0, "Matrix selected column was not stored.")
    expect(matrix.selectedCell()?.stringValue == "Choice 2,1", "Matrix selected cell was not returned.")
    expect(matrix.button(atRow: 1, column: 0)?.state == .on, "Matrix did not sync button state for selected cell.")

    let replacement = NSButtonCell(title: "Custom")
    matrix.putCell(replacement, atRow: 0, column: 1)

    expect(matrix.cell(atRow: 0, column: 1) === replacement, "Matrix did not store replacement cell.")
    expect(matrix.button(atRow: 0, column: 1)?.title == "Custom", "Matrix did not sync replacement title.")

    let handle = matrix.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "view", "Matrix did not request a native container view.")
    guard let customHandle = matrix.button(atRow: 0, column: 1)?.nativeHandle else {
        expect(false, "Matrix button was not realized.")
        return
    }

    expect(backend.records[customHandle]?.kind == "radioButton", "Radio-mode matrix did not realize radio button peers.")

    matrix.button(atRow: 0, column: 1)?.performClick(nil)

    expect(matrix.selectedRow == 0, "Matrix button click did not update selected row.")
    expect(matrix.selectedColumn == 1, "Matrix button click did not update selected column.")
    expect(actionCount == 1, "Matrix button click did not dispatch matrix action.")

    matrix.deselectSelectedCell()

    expect(matrix.selectedRow == -1, "Matrix deselect did not clear selected row.")
    expect(matrix.selectedCell() == nil, "Matrix deselect did not clear selected cell.")
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
    expect(backend.records[handle]?.text == "", "Combo box native text change should not echo text back to the native peer.")
    backend.setText("Selected", for: handle)
    backend.actions[handle]?()

    expect(textChangeCount == 1, "Combo box text-change callback did not fire.")
    expect(actionCount == 1, "Combo box action callback did not fire.")
}

func testTokenFieldStoresTokensAndTokenizesNativeText() {
    let backend = InMemoryNativeControlBackend()
    let tokenField = NSTokenField(tokens: ["Cocoa", "AppKit"], frame: NSMakeRect(0, 0, 220, 28))
    var changedTokens: [String] = []

    tokenField.onTextChanged = { field in
        changedTokens = (field as? NSTokenField)?.tokens ?? []
    }

    let handle = tokenField.realizeNativePeer(in: backend, parent: nil)
    backend.textChangeActions[handle]?("NSWindow, NSView, NSButton")

    expect(backend.records[handle]?.kind == "editableTextField", "Token field did not use editable text-field peer.")
    expect(tokenField.tokens == ["NSWindow", "NSView", "NSButton"], "Token field did not tokenize edited text.")
    expect((tokenField.objectValue as? [String]) == tokenField.tokens, "Token field objectValue did not mirror tokens.")
    expect(changedTokens == tokenField.tokens, "Token field text-change callback did not observe tokens.")

    tokenField.tokenizingCharacter = ";"
    tokenField.stringValue = "One; Two"
    tokenField.setTokens(["Cocoa", "WinChocolate"])

    expect(tokenField.tokens == ["Cocoa", "WinChocolate"], "Token field setTokens did not replace tokens.")
    expect(tokenField.stringValue == "Cocoa; WinChocolate", "Token field setTokens did not honor tokenizing character.")
}

func testPathControlStoresURLAndPathComponentCells() {
    let backend = InMemoryNativeControlBackend()
    let pathControl = NSPathControl(
        url: URL(fileURLWithPath: "C:\\AIResearch\\WinChocolate"),
        frame: NSMakeRect(0, 0, 260, 28)
    )

    let handle = pathControl.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "textField", "Path control did not use text-field peer.")
    expect(pathControl.stringValue.contains("WinChocolate"), "Path control did not display URL path.")
    expect(pathControl.pathComponentCells.contains { $0.title == "WinChocolate" }, "Path control did not build component cells.")

    pathControl.setURL(URL(fileURLWithPath: "C:\\AIResearch\\WinChocolate\\Code"))

    expect(pathControl.stringValue.hasSuffix("Code"), "Path control setURL did not update visible path.")
    expect(pathControl.pathComponentCells.contains { $0.title == "Code" }, "Path control setURL did not refresh component cells.")
}

func testPathControlComponentURLsAndSelection() {
    let pathControl = NSPathControl(
        url: URL(fileURLWithPath: "C:\\AIResearch\\WinChocolate\\Code"),
        frame: NSMakeRect(0, 0, 260, 28)
    )

    // Every component cell carries a cumulative URL ending in its own title.
    expect(!pathControl.pathComponentCells.isEmpty, "Path control produced no component cells.")
    for cell in pathControl.pathComponentCells {
        guard let cellURL = cell.url else {
            expect(false, "Component cell \(cell.title) had no cumulative URL.")
            continue
        }
        expect(cellURL.lastPathComponent == cell.title, "Component cell URL did not end with its own title.")
    }

    // Selecting a component records it, exposes its URL, and fires the action.
    var actionFired = false
    pathControl.onAction = { _ in actionFired = true }
    guard let last = pathControl.pathComponentCells.last else {
        expect(false, "Path control had no last component.")
        return
    }
    let selected = pathControl.selectComponentCell(at: pathControl.pathComponentCells.count - 1)
    expect(selected, "selectComponentCell did not accept a valid index.")
    expect(actionFired, "Selecting a component did not fire the control action.")
    expect(pathControl.clickedPathComponentCell === last, "Clicked component cell was not recorded.")
    expect(pathControl.clickedPathComponentURL == last.url, "Clicked component URL did not match the cell.")

    // An out-of-range selection is rejected.
    expect(!pathControl.selectComponentCell(at: 99), "selectComponentCell should reject an out-of-range index.")

    // Changing the URL clears the recorded click.
    pathControl.setURL(URL(fileURLWithPath: "C:\\AIResearch"))
    expect(pathControl.clickedPathComponentCell == nil, "Rebuilding components did not clear the clicked cell.")
}

func testWinFoundationCompatibilitySurface() {
    let url = URL(fileURLWithPath: "C:\\AIResearch\\WinChocolate\\")
    expect(url.path == "C:\\AIResearch\\WinChocolate\\", "WinFoundation URL did not preserve directory-style trailing separator.")
    expect(url.isFileURL, "WinFoundation URL(fileURLWithPath:) should create a file URL.")
    expect(url.absoluteString == "file:///C:/AIResearch/WinChocolate/", "WinFoundation URL absoluteString did not create a file URL string.")
    expect(url.relativeString == url.absoluteString, "WinFoundation URL relativeString should match absoluteString without base URL support.")
    expect(url.lastPathComponent == "WinChocolate", "WinFoundation URL lastPathComponent failed.")
    expect(url.appendingPathComponent("Code").path.hasSuffix("WinChocolate\\Code"), "WinFoundation URL appendingPathComponent failed.")
    expect(url.appendingPathComponent("Code", isDirectory: true).hasDirectoryPath, "WinFoundation URL directory appending failed.")
    expect(url.appendingPathComponent("README").appendingPathExtension("md").lastPathComponent == "README.md", "WinFoundation URL appendingPathExtension failed.")
    expect(url.appendingPathComponent("README.md").pathExtension == "md", "WinFoundation URL pathExtension failed.")
    expect(url.appendingPathComponent("README.md").deletingPathExtension().lastPathComponent == "README", "WinFoundation URL deletingPathExtension failed.")
    expect(url.appendingPathComponent("Code").deletingLastPathComponent().lastPathComponent == "WinChocolate", "WinFoundation URL deletingLastPathComponent failed.")

    let parsedFileURL = URL(string: "file:///C:/AIResearch/WinChocolate/Code")
    expect(parsedFileURL?.isFileURL == true, "WinFoundation URL(string:) did not parse file URL.")
    expect(parsedFileURL?.lastPathComponent == "Code", "WinFoundation parsed file URL lastPathComponent failed.")

    let webURL = URL(string: "https://example.com/index.html")
    expect(webURL?.isFileURL == false, "WinFoundation URL(string:) should preserve non-file URLs.")
    expect(webURL?.scheme == "https", "WinFoundation URL scheme failed.")
    expect(webURL?.host == "example.com", "WinFoundation URL host failed.")
    expect(webURL?.path == "/index.html", "WinFoundation URL path failed for web URL.")
    expect(webURL?.absoluteString == "https://example.com/index.html", "WinFoundation non-file URL absoluteString failed.")

    let queriedURL = URL(string: "https://example.com/search docs/index.html?q=hello world&sort=up#top item")
    expect(queriedURL?.scheme == "https", "WinFoundation queried URL scheme failed.")
    expect(queriedURL?.host == "example.com", "WinFoundation queried URL host failed.")
    expect(queriedURL?.path == "/search docs/index.html", "WinFoundation queried URL path failed.")
    expect(queriedURL?.query == "q=hello world&sort=up", "WinFoundation queried URL query failed.")
    expect(queriedURL?.fragment == "top item", "WinFoundation queried URL fragment failed.")
    expect(queriedURL?.percentEncodedPath == "/search%20docs/index.html", "WinFoundation queried URL percentEncodedPath failed.")
    expect(queriedURL?.percentEncodedQuery == "q=hello%20world&sort=up", "WinFoundation queried URL percentEncodedQuery failed.")
    expect(queriedURL?.percentEncodedFragment == "top%20item", "WinFoundation queried URL percentEncodedFragment failed.")
    expect(queriedURL?.absoluteString == "https://example.com/search%20docs/index.html?q=hello%20world&sort=up#top%20item", "WinFoundation queried URL absoluteString failed.")

    let spacedFileURL = URL(fileURLWithPath: "C:\\AIResearch\\Win Chocolate\\hello world.txt")
    expect(spacedFileURL.absoluteString == "file:///C:/AIResearch/Win%20Chocolate/hello%20world.txt", "WinFoundation URL did not percent-encode file URL spaces.")
    expect(spacedFileURL.percentEncodedPath == "C:/AIResearch/Win%20Chocolate/hello%20world.txt", "WinFoundation URL percentEncodedPath failed.")

    let decodedFileURL = URL(string: "file:///C:/AIResearch/Win%20Chocolate/hello%20world.txt")
    expect(decodedFileURL?.path == "C:\\AIResearch\\Win Chocolate\\hello world.txt", "WinFoundation URL did not decode percent-encoded file URL path.")

    let baseURL = URL(string: "https://example.com/docs/")
    let relativeURL = URL(string: "guide/index.html", relativeTo: baseURL)
    expect(relativeURL?.baseURL?.absoluteString == "https://example.com/docs/", "WinFoundation relative URL did not preserve base URL.")
    expect(relativeURL?.relativePath == "guide/index.html", "WinFoundation relative URL did not preserve relative path.")
    expect(relativeURL?.relativeString == "guide/index.html", "WinFoundation relative URL did not preserve relativeString.")
    expect(relativeURL?.absoluteString == "https://example.com/docs/guide/index.html", "WinFoundation relative URL did not resolve absoluteString with base URL.")
    expect(relativeURL?.absoluteURL.absoluteString == "https://example.com/docs/guide/index.html", "WinFoundation relative URL absoluteURL failed.")

    let queriedRelativeURL = URL(string: "guide/search results.html?q=hello world#section 1", relativeTo: baseURL)
    expect(queriedRelativeURL?.absoluteString == "https://example.com/docs/guide/search%20results.html?q=hello%20world#section%201", "WinFoundation queried relative URL absoluteString failed.")
    expect(queriedRelativeURL?.absoluteURL.query == "q=hello world", "WinFoundation queried relative URL query failed.")
    expect(queriedRelativeURL?.absoluteURL.fragment == "section 1", "WinFoundation queried relative URL fragment failed.")

    let weirdPath = URL(fileURLWithPath: "C:\\AIResearch\\.\\WinChocolate\\Code\\..\\Docs\\")
    expect(weirdPath.standardizedFileURL.path == "C:\\AIResearch\\WinChocolate\\Docs\\", "WinFoundation URL standardizedFileURL did not collapse dot components.")

    let uncURL = URL(fileURLWithPath: "\\\\Server\\Share\\WinChocolate")
    expect(uncURL.absoluteString == "file://Server/Share/WinChocolate", "WinFoundation URL did not format UNC file URL correctly.")
    expect(uncURL.pathComponents == ["Server", "Share", "WinChocolate"], "WinFoundation URL UNC pathComponents failed.")

    let parsedUNCURL = URL(string: "file://Server/Share/WinChocolate")
    expect(parsedUNCURL?.path == "\\\\Server\\Share\\WinChocolate", "WinFoundation URL did not parse UNC file URL correctly.")

    let driveRoot = URL(fileURLWithPath: "C:\\")
    expect(driveRoot.deletingLastPathComponent().path == "C:\\", "WinFoundation URL should preserve Windows drive root when deleting last component.")

    let data = Data([1, 2, 3])
    expect(data.count == 3, "WinFoundation Data count failed.")
    expect(Array(data) == [1, 2, 3], "WinFoundation Data iteration failed.")

    var mutableData = Data(repeating: 7, count: 3)
    expect(Array(mutableData) == [7, 7, 7], "WinFoundation Data repeating initializer failed.")
    mutableData[1] = 9
    expect(mutableData[1] == 9, "WinFoundation Data mutable subscript failed.")
    mutableData.append(10)
    mutableData.append(contentsOf: [11, 12])
    mutableData.append(Data([13, 14]))
    expect(Array(mutableData) == [7, 9, 7, 10, 11, 12, 13, 14], "WinFoundation Data append failed.")
    mutableData.replaceSubrange(1..<3, with: [21, 22, 23])
    expect(Array(mutableData) == [7, 21, 22, 23, 10, 11, 12, 13, 14], "WinFoundation Data replaceSubrange failed.")
    expect(Array(mutableData.subdata(in: 1..<4)) == [21, 22, 23], "WinFoundation Data subdata failed.")
    let unsafeSum = mutableData.withUnsafeBytes { rawBuffer in
        rawBuffer.reduce(0) { partial, byte in partial + Int(byte) }
    }
    expect(unsafeSum == Array(mutableData).reduce(0) { $0 + Int($1) }, "WinFoundation Data withUnsafeBytes failed.")
    mutableData.withUnsafeMutableBytes { rawBuffer in
        rawBuffer[0] = 99
    }
    expect(mutableData.first == 99, "WinFoundation Data withUnsafeMutableBytes failed.")
    mutableData.removeAll(keepingCapacity: true)
    expect(mutableData.isEmpty, "WinFoundation Data removeAll failed.")

    let packageDataURL = URL(fileURLWithPath: "C:\\AIResearch\\WinChocolate\\Code\\WinChocolate\\Package.swift")
    let packageData = try? Data(contentsOf: packageDataURL)
    expect(packageData?.count ?? 0 > 0, "WinFoundation Data(contentsOf:) failed to read a package file.")
    expect(String(decoding: packageData ?? Data(), as: UTF8.self).contains("WinChocolate"), "WinFoundation Data(contentsOf:) did not preserve file bytes.")

    let writeDataURL = URL(fileURLWithPath: "C:\\AIResearch\\WinChocolate\\Code\\WinChocolate\\.build\\winfoundation-data-write.txt")
    let writtenData = Data([87, 105, 110, 67, 104, 111, 99, 111, 108, 97, 116, 101])
    do {
        try writtenData.write(to: writeDataURL)
        let roundTripData = try Data(contentsOf: writeDataURL)
        expect(roundTripData == writtenData, "WinFoundation Data write/read round trip failed.")
    } catch {
        fatalError("WinFoundation Data file I/O threw unexpectedly: \(error)")
    }

    var indexes = IndexSet(integer: 2)
    indexes.insert(1)
    indexes.insert(3)
    indexes.remove(2)
    expect(Array(indexes) == [1, 3], "WinFoundation IndexSet ordering or mutation failed.")
    expect(indexes.first == 1, "WinFoundation IndexSet first failed.")
    expect(indexes.last == 3, "WinFoundation IndexSet last failed.")

    var rangeIndexes = IndexSet(integersIn: 4..<7)
    rangeIndexes.insert(integersIn: 8...9)
    rangeIndexes.remove(integersIn: 5..<6)
    expect(Array(rangeIndexes) == [4, 6, 8, 9], "WinFoundation IndexSet range mutation failed.")
    expect(rangeIndexes.contains(integersIn: 8...9), "WinFoundation IndexSet closed range contains failed.")
    expect(!rangeIndexes.contains(integersIn: 4...6), "WinFoundation IndexSet range contains should require all indexes.")
    expect(rangeIndexes.intersects(integersIn: 5...6), "WinFoundation IndexSet range intersects failed.")
    expect(rangeIndexes.integerGreaterThan(6) == 8, "WinFoundation IndexSet integerGreaterThan failed.")
    expect(rangeIndexes.integerGreaterThanOrEqualTo(6) == 6, "WinFoundation IndexSet integerGreaterThanOrEqualTo failed.")
    expect(rangeIndexes.integerLessThan(8) == 6, "WinFoundation IndexSet integerLessThan failed.")
    expect(rangeIndexes.integerLessThanOrEqualTo(8) == 8, "WinFoundation IndexSet integerLessThanOrEqualTo failed.")

    let unionIndexes = indexes.union(rangeIndexes)
    expect(Array(unionIndexes) == [1, 3, 4, 6, 8, 9], "WinFoundation IndexSet union failed.")
    expect(Array(unionIndexes.intersection(IndexSet(integersIn: 3...8))) == [3, 4, 6, 8], "WinFoundation IndexSet intersection failed.")
    expect(Array(unionIndexes.subtracting(IndexSet(integersIn: 4...8))) == [1, 3, 9], "WinFoundation IndexSet subtracting failed.")

    let early = Date(timeIntervalSinceReferenceDate: 1)
    let later = Date(timeIntervalSinceReferenceDate: 2)
    expect(early < later, "WinFoundation Date comparison failed.")
    expect(Date(timeIntervalSince1970: 978_307_201).timeIntervalSinceReferenceDate == 1, "WinFoundation Date Unix epoch initializer failed.")
    expect(early.timeIntervalSince1970 == 978_307_201, "WinFoundation Date timeIntervalSince1970 failed.")
    expect(later.timeIntervalSince(early) == 1, "WinFoundation Date timeIntervalSince failed.")
    expect(early.addingTimeInterval(10).timeIntervalSinceReferenceDate == 11, "WinFoundation Date addingTimeInterval failed.")
    expect(early.distance(to: later) == 1, "WinFoundation Date distance(to:) failed.")
    expect(early.advanced(by: 4).timeIntervalSinceReferenceDate == 5, "WinFoundation Date advanced(by:) failed.")

    let now = Date()
    expect(now.timeIntervalSince1970 > 1_700_000_000, "WinFoundation Date() did not use a real current clock.")
    let future = Date(timeIntervalSinceNow: 5)
    expect(future.timeIntervalSince(now) > 0, "WinFoundation Date(timeIntervalSinceNow:) failed.")
    expect(Date.now.timeIntervalSince1970 > 1_700_000_000, "WinFoundation Date.now did not use a real current clock.")

    let knownUUID = UUID(uuidString: "00112233-4455-6677-8899-AABBCCDDEEFF")
    expect(knownUUID?.uuidString == "00112233-4455-6677-8899-AABBCCDDEEFF", "WinFoundation UUID uuidString failed.")
    expect(UUID(uuidString: "00112233445566778899aabbccddeeff")?.uuidString == "00112233-4455-6677-8899-AABBCCDDEEFF", "WinFoundation UUID compact/lowercase parser failed.")
    expect(UUID(uuidString: "not-a-uuid") == nil, "WinFoundation UUID should reject invalid strings.")
    let tupleUUID = UUID(uuid: (
        0x00, 0x11, 0x22, 0x33,
        0x44, 0x55, 0x66, 0x77,
        0x88, 0x99, 0xAA, 0xBB,
        0xCC, 0xDD, 0xEE, 0xFF
    ))
    expect(tupleUUID == knownUUID, "WinFoundation UUID raw tuple initializer failed.")
    expect(tupleUUID.description == tupleUUID.uuidString, "WinFoundation UUID description failed.")
    expect(UUID().uuidString != UUID().uuidString, "WinFoundation UUID() should create distinct values.")

    let interval: TimeInterval = 2.5
    expect(Date(timeInterval: interval, since: early).timeIntervalSinceReferenceDate == 3.5, "WinFoundation TimeInterval alias failed.")

    guard let packageBundle = Bundle(path: "C:\\AIResearch\\WinChocolate\\Code\\WinChocolate") else {
        fatalError("WinFoundation Bundle(path:) failed.")
    }
    expect(packageBundle.bundleURL.isFileURL, "WinFoundation Bundle bundleURL should be a file URL.")
    expect(packageBundle.bundlePath.hasSuffix("Code\\WinChocolate"), "WinFoundation Bundle bundlePath failed.")
    expect(packageBundle.path(forResource: "Package", ofType: "swift")?.hasSuffix("Package.swift") == true, "WinFoundation Bundle resource path lookup failed.")
    expect(packageBundle.url(forResource: "Package", withExtension: "swift")?.lastPathComponent == "Package.swift", "WinFoundation Bundle resource URL lookup failed.")
    expect(packageBundle.path(forResource: "Missing", ofType: "swift") == nil, "WinFoundation Bundle should return nil for missing resources.")
    expect(Bundle(path: ".")?.path(forResource: "WinChocolateArtwork", ofType: "bmp", inDirectory: "Demo\\DemoApplication\\Resources") != nil, "WinFoundation Bundle should find demo resources from the package working directory.")
    expect(Bundle(path: ".")?.path(forResource: "WinChocolateArtworkDemo", ofType: "bmp", inDirectory: "Demo\\DemoApplication\\Resources") != nil, "WinFoundation Bundle should find resized demo resources from the package working directory.")
    expect(Bundle(url: packageBundle.bundleURL)?.bundlePath == packageBundle.bundlePath, "WinFoundation Bundle(url:) failed.")
    expect(Bundle.main.bundleURL.isFileURL, "WinFoundation Bundle.main should expose a file URL.")
    expect(Bundle.main.executableURL?.pathExtension == "exe", "WinFoundation Bundle.main executableURL failed.")

    let center = NotificationCenter()
    let notificationName = Notification.Name("WinFoundationNotification")
    let sender = NSButton(title: "Sender", frame: NSMakeRect(0, 0, 80, 24))
    var deliveredNames: [String] = []
    var deliveredUserInfoValue = ""
    let token = center.addObserver(forName: notificationName, object: sender, queue: nil) { notification in
        deliveredNames.append(notification.name.rawValue)
        deliveredUserInfoValue = notification.userInfo?["value"] as? String ?? ""
    }
    center.post(name: notificationName, object: NSButton(title: "Other", frame: NSMakeRect(0, 0, 80, 24)))
    expect(deliveredNames.isEmpty, "WinFoundation NotificationCenter should filter nonmatching objects.")
    center.post(name: notificationName, object: sender, userInfo: ["value": "delivered"])
    expect(deliveredNames == ["WinFoundationNotification"], "WinFoundation NotificationCenter did not deliver matching notification.")
    expect(deliveredUserInfoValue == "delivered", "WinFoundation NotificationCenter did not preserve userInfo.")
    center.removeObserver(token)
    center.post(name: notificationName, object: sender)
    expect(deliveredNames.count == 1, "WinFoundation NotificationCenter removeObserver failed.")

    var wildcardCount = 0
    let wildcardToken = center.addObserver(forName: nil, object: nil, queue: OperationQueue.main) { _ in
        wildcardCount += 1
    }
    center.post(Notification(name: "WildcardOne"))
    center.post(name: "WildcardTwo")
    expect(wildcardCount == 2, "WinFoundation NotificationCenter wildcard observer failed.")
    center.removeObserver(wildcardToken)
}

func testImageViewStoresImageAndUsesNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let imageView = NSImageView(frame: NSMakeRect(0, 0, 64, 64))
    let packageURL = URL(fileURLWithPath: "C:\\AIResearch\\WinChocolate\\Code\\WinChocolate\\Package.swift")
    let urlImage = NSImage(contentsOf: packageURL)
    let dataImage = NSImage(data: Data([1, 2, 3, 4]))
    let symbolImage = NSImage(systemSymbolName: "folder", accessibilityDescription: "Open folder")

    expect(urlImage?.filePath == packageURL.path, "NSImage(contentsOf:) did not preserve file URL path.")
    expect((urlImage?.data?.count ?? 0) > 0, "NSImage(contentsOf:) did not load file data.")
    expect(dataImage?.data == Data([1, 2, 3, 4]), "NSImage(data:) did not preserve image data.")
    expect(NSImage(data: Data()) == nil, "NSImage(data:) should reject empty data.")
    expect(symbolImage?.name == "folder", "NSImage(systemSymbolName:) did not preserve the symbol name.")
    expect(symbolImage?.accessibilityDescription == "Open folder", "NSImage(systemSymbolName:) did not preserve accessibility description.")

    imageView.image = NSImage(contentsOfFile: "Resources/Icon.bmp")
    imageView.imageScaling = .scaleNone
    imageView.imageAlignment = .alignTopLeft
    imageView.imageFrameStyle = .grayBezel

    let handle = imageView.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "imageView", "Image view did not request native peer.")
    expect(backend.records[handle]?.imagePath == "Resources/Icon.bmp", "Image view did not sync image path.")
    expect(backend.records[handle]?.text == "Resources/Icon.bmp\nno scale, top left", "Image view did not sync image description.")
    expect(!imageView.acceptsFirstResponder, "Image view should not accept first responder by default.")
    expect(imageView.imageFrameStyle == .grayBezel, "Image view frame style was not stored.")

    imageView.image = NSImage(contentsOfFile: "Resources/Updated.bmp")
    expect(backend.records[handle]?.imagePath == "Resources/Updated.bmp", "Image view image path changes did not sync.")
    expect(backend.records[handle]?.text == "Resources/Updated.bmp\nno scale, top left", "Image view image changes did not sync.")

    imageView.imageScaling = .scaleProportionallyUpOrDown
    imageView.imageAlignment = .alignBottomRight
    expect(backend.records[handle]?.text == "Resources/Updated.bmp\nscale fit, bottom right", "Image view scaling/alignment changes did not sync.")
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

func testVisualEffectViewStoresMaterialAndUsesFallbackBackground() {
    let backend = InMemoryNativeControlBackend()
    let effectView = NSVisualEffectView(frame: NSMakeRect(0, 0, 180, 80))

    effectView.material = .sidebar
    effectView.blendingMode = .withinWindow
    effectView.state = .active

    let handle = effectView.realizeNativePeer(in: backend, parent: nil)

    expect(effectView.material == .sidebar, "Visual effect material was not stored.")
    expect(effectView.blendingMode == .withinWindow, "Visual effect blending mode was not stored.")
    expect(effectView.state == .active, "Visual effect state was not stored.")
    expect(!effectView.acceptsFirstResponder, "Visual effect view should skip key-view traversal.")
    expect(backend.records[handle]?.kind == "view", "Visual effect view did not use a view peer.")
    expect(backend.records[handle]?.backgroundColor == effectView.backgroundColor, "Visual effect fallback background was not synced.")

    effectView.material = .hudWindow
    expect(backend.records[handle]?.backgroundColor == effectView.backgroundColor, "Visual effect material change did not update fallback background.")
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
    NSApplication.shared.nativeBackend = InMemoryNativeControlBackend()
}

func testSavePanelMapsOptionsAndReturnsChosenURL() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    let panel = NSSavePanel.savePanel()
    panel.title = "Save Document"
    panel.prompt = "Save"
    panel.nameFieldStringValue = "Report.txt"
    panel.allowedFileTypes = ["txt", "md"]
    panel.allowsOtherFileTypes = true
    panel.directoryURL = URL(fileURLWithPath: "C:\\Projects")
    backend.scriptedFileDialogPaths = [["C:\\Projects\\Report.txt"]]

    let response = panel.runModal()

    expect(response == .OK, "Save panel did not return OK for a chosen path.")
    expect(panel.url?.path == "C:\\Projects\\Report.txt", "Save panel did not expose the chosen URL.")
    expect(backend.fileDialogRequests.count == 1, "Save panel did not run exactly one native dialog.")

    let options = backend.fileDialogRequests[0]
    expect(options.kind == .save, "Save panel did not request a save dialog.")
    expect(options.title == "Save Document", "Save panel did not forward its title.")
    expect(options.fileName == "Report.txt", "Save panel did not forward the name field value.")
    expect(options.fileTypes == ["txt", "md"], "Save panel did not forward allowed file types.")
    expect(options.allowsOtherFileTypes, "Save panel did not forward allowsOtherFileTypes.")
    expect(options.directoryPath == "C:\\Projects", "Save panel did not forward the initial directory.")
    expect(!options.allowsMultipleSelection, "Save panel must not request multiple selection.")
}

func testSavePanelCancelReturnsCancelAndClearsURL() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    let panel = NSSavePanel()
    backend.scriptedFileDialogPaths = [nil]

    let response = panel.runModal()

    expect(response == .cancel, "Cancelled save panel did not return cancel.")
    expect(panel.url == nil, "Cancelled save panel should not expose a URL.")
}

func testOpenPanelSupportsMultipleSelectionAndDirectories() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    let panel = NSOpenPanel.openPanel()
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = true
    panel.canChooseFiles = true
    backend.scriptedFileDialogPaths = [["C:\\A\\one.txt", "C:\\A\\two.txt"]]

    let response = panel.runModal()

    expect(response == .OK, "Open panel did not return OK for chosen paths.")
    expect(panel.urls.count == 2, "Open panel did not expose all chosen URLs.")
    expect(panel.urls.first?.lastPathComponent == "one.txt", "Open panel did not order chosen URLs.")
    expect(panel.url == panel.urls.first, "Open panel url should be the first chosen URL.")

    let options = backend.fileDialogRequests[0]
    expect(options.kind == .open, "Open panel did not request an open dialog.")
    expect(options.allowsMultipleSelection, "Open panel did not forward multiple selection.")
    expect(options.canChooseDirectories, "Open panel did not forward directory choosing.")
    expect(options.canChooseFiles, "Open panel did not forward file choosing.")
}

func testOpenPanelBeginInvokesCompletionHandler() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    let panel = NSOpenPanel()
    backend.scriptedFileDialogPaths = [["C:\\A\\picked.txt"]]

    var receivedResponse: NSApplication.ModalResponse?
    panel.begin { response in
        receivedResponse = response
    }

    expect(receivedResponse == .OK, "Open panel begin did not deliver the modal response.")
    expect(panel.url?.lastPathComponent == "picked.txt", "Open panel begin did not populate url.")
}

// The suite runs inside build scripts on a real desktop. Windows and panels
// created without an explicit backend capture the application default, which
// on Windows is the live Win32 backend — every ordered-front test window would
// flash on screen. Route the default through the in-memory backend first.
NSApplication.shared.nativeBackend = InMemoryNativeControlBackend()

final class DrawingTestView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.red.setFill()
        NSBezierPath(rect: NSMakeRect(1, 2, 10, 20)).fill()

        NSColor.blue.setStroke()
        let oval = NSBezierPath(ovalIn: NSMakeRect(0, 0, 40, 40))
        oval.lineWidth = 3
        oval.stroke()

        NSRectFill(NSMakeRect(5, 5, 2, 2))
    }
}

func testViewDrawDispatchesPathsToBackendContext() {
    let backend = InMemoryNativeControlBackend()
    let view = DrawingTestView(frame: NSMakeRect(0, 0, 60, 60))
    let handle = view.realizeNativePeer(in: backend, parent: nil)

    view.needsDisplay = true
    expect(backend.invalidatedHandles.contains(handle), "needsDisplay did not invalidate the native peer.")

    let recording = backend.performDraw(for: handle, in: NSMakeRect(0, 0, 60, 60))

    expect(recording.fills.count == 2, "Draw pass did not record both fill commands.")
    expect(recording.strokes.count == 1, "Draw pass did not record the stroke command.")
    expect(recording.fills.first?.color == .red, "Fill did not use the color set through NSColor.setFill.")
    expect(recording.fills.first?.segments.count == 5, "Rectangle path did not build move/line/line/line/close segments.")
    expect(recording.strokes.first?.color == .blue, "Stroke did not use the color set through NSColor.setStroke.")
    expect(recording.strokes.first?.lineWidth == 3, "Stroke did not carry the path line width.")

    let ovalSegments = recording.strokes.first?.segments ?? []
    let curveCount = ovalSegments.filter { segment in
        if case .curve = segment {
            return true
        }
        return false
    }.count
    expect(curveCount == 4, "Oval path did not approximate the circle with four Bezier curves.")
    expect(view.needsDisplay == false, "Draw pass did not clear needsDisplay.")
    expect(NSGraphicsContext.current == nil, "Draw pass did not restore the previous graphics context.")
}

final class TextAndImageDrawingTestView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        "Hello Chocolate".draw(
            at: NSMakePoint(4, 6),
            withAttributes: [
                .font: NSFont.boldSystemFont(ofSize: 15),
                .foregroundColor: NSColor.red
            ]
        )
        "Plain".draw(at: NSMakePoint(1, 2), withAttributes: nil)
        NSImage(contentsOfFile: "C:\\Art\\brand.png")?.draw(in: NSMakeRect(10, 20, 30, 40))
    }
}

func testViewDrawDispatchesTextAndImagesToBackendContext() {
    let backend = InMemoryNativeControlBackend()
    let view = TextAndImageDrawingTestView(frame: NSMakeRect(0, 0, 80, 80))
    let handle = view.realizeNativePeer(in: backend, parent: nil)

    let recording = backend.performDraw(for: handle, in: NSMakeRect(0, 0, 80, 80))

    expect(recording.texts.count == 2, "Draw pass did not record both text commands.")
    expect(recording.texts.first?.text == "Hello Chocolate", "Text draw did not carry the string content.")
    expect(recording.texts.first?.point == NSMakePoint(4, 6), "Text draw did not carry the origin point.")
    expect(recording.texts.first?.color == .red, "Text draw did not resolve the foreground color attribute.")
    expect(recording.texts.first?.fontName == "Segoe UI", "Text draw did not resolve the font name attribute.")
    expect(recording.texts.first?.fontSize == 15, "Text draw did not resolve the font size attribute.")
    expect(recording.texts.first?.bold == true, "Bold font attribute did not mark the text bold.")
    expect(recording.texts.last?.color == .black, "Attribute-free text did not default to black.")
    expect(recording.texts.last?.fontName == "Segoe UI", "Attribute-free text did not default to Segoe UI.")
    expect(recording.texts.last?.fontSize == 12, "Attribute-free text did not default to 12 points.")
    expect(recording.texts.last?.bold == false, "Attribute-free text did not default to regular weight.")

    expect(recording.images.count == 1, "Draw pass did not record the image command.")
    expect(recording.images.first?.path == "C:\\Art\\brand.png", "Image draw did not carry the file path.")
    expect(recording.images.first?.rect == NSMakeRect(10, 20, 30, 40), "Image draw did not carry the destination rect.")
}

final class GradientAndClipTestView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSGradient(starting: .red, ending: .blue)?.draw(in: NSMakeRect(0, 0, 100, 50), angle: 0)

        NSGradient(colorsAndLocations: (.white, 0), (.black, 0.25), (.red, 1))?
            .draw(in: NSMakeRect(0, 0, 100, 50), angle: 90)

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(ovalIn: NSMakeRect(10, 10, 40, 40)).addClip()
        NSColor.green.setFill()
        NSRectFill(NSMakeRect(0, 0, 60, 60))
        NSGraphicsContext.restoreGraphicsState()

        NSRectClip(NSMakeRect(2, 2, 8, 8))
    }
}

func testGradientAndClipCommandsReachBackendContext() {
    let backend = InMemoryNativeControlBackend()
    let view = GradientAndClipTestView(frame: NSMakeRect(0, 0, 120, 60))
    let handle = view.realizeNativePeer(in: backend, parent: nil)

    let recording = backend.performDraw(for: handle, in: NSMakeRect(0, 0, 120, 60))

    expect(recording.gradients.count == 2, "Draw pass did not record both gradient commands.")
    let horizontal = recording.gradients.first
    expect(horizontal?.stops.count == 2, "Two-color gradient did not carry two stops.")
    expect(horizontal?.stops.first?.color == .red, "Gradient did not carry the starting color.")
    expect(horizontal?.stops.last?.location == 1, "Evenly spaced gradient did not end at location 1.")
    expect(horizontal?.rect == NSMakeRect(0, 0, 100, 50), "Gradient did not carry the target rect.")
    expect(horizontal?.angle == 0, "Horizontal gradient did not carry angle 0.")

    let vertical = recording.gradients.last
    expect(vertical?.stops.count == 3, "Located gradient did not carry three stops.")
    expect(vertical?.stops[1].location == 0.25, "Located gradient did not keep the middle stop location.")
    expect(vertical?.angle == 90, "Vertical gradient did not carry angle 90.")

    expect(recording.clips.count == 2, "Draw pass did not record both clip commands.")
    let ovalClipCurves = recording.clips.first?.segments.filter { segment in
        if case .curve = segment {
            return true
        }
        return false
    }.count
    expect(ovalClipCurves == 4, "Oval clip did not carry four curve segments.")
    expect(recording.stateOperations == [.save, .restore], "Graphics state save/restore did not reach the backend in order.")
    expect(recording.fills.count == 1, "Clipped fill did not record.")
    expect(recording.fills.first?.color == .green, "Clipped fill did not carry its color.")
}

func testUndoManagerRegistersUndoAndRedo() {
    final class Counter {
        var value = 0
    }

    let manager = NSUndoManager()
    let counter = Counter()

    func setValue(_ newValue: Int) {
        let oldValue = counter.value
        counter.value = newValue
        manager.registerUndo(withTarget: counter) { _ in
            setValue(oldValue)
        }
        manager.setActionName("Set Value")
    }

    setValue(1)
    setValue(2)
    expect(manager.canUndo, "Registrations did not populate the undo stack.")
    expect(!manager.canRedo, "Nothing was undone, so redo should be empty.")
    expect(manager.undoMenuItemTitle == "Undo Set Value", "Action name did not flow into the undo menu title.")

    manager.undo()
    expect(counter.value == 1, "Undo did not run the most recent action.")
    expect(manager.canRedo, "Undo did not move the inverse onto the redo stack.")
    expect(manager.redoMenuItemTitle == "Redo Set Value", "Undo did not carry the action name to redo.")

    manager.undo()
    expect(counter.value == 0, "Second undo did not run the older action.")
    expect(!manager.canUndo, "Undo stack should be empty after undoing everything.")

    manager.redo()
    manager.redo()
    expect(counter.value == 2, "Redo did not replay both actions in order.")
    expect(!manager.canRedo && manager.canUndo, "Redo did not rebuild the undo stack.")

    manager.undo()
    setValue(5)
    expect(!manager.canRedo, "A fresh registration should clear the redo stack.")

    manager.removeAllActions()
    expect(!manager.canUndo && !manager.canRedo, "removeAllActions did not clear both stacks.")

    let limited = NSUndoManager()
    limited.levelsOfUndo = 1
    limited.registerUndo(withTarget: counter) { _ in }
    limited.registerUndo(withTarget: counter) { _ in }
    limited.undo()
    expect(!limited.canUndo, "levelsOfUndo did not cap the undo stack.")
}

func testTextViewUndoRestoresPreviousText() {
    let backend = InMemoryNativeControlBackend()
    let textView = NSTextView(frame: NSMakeRect(0, 0, 200, 80))
    textView.string = "one"
    textView.allowsUndo = true
    let handle = textView.realizeNativePeer(in: backend, parent: nil)

    backend.textChangeActions[handle]?("one two")
    expect(textView.string == "one two", "Native change did not update the string.")
    let manager = textView.undoManager
    expect(manager?.canUndo == true, "Text change did not register an undo action.")

    manager?.undo()
    expect(textView.string == "one", "Undo did not restore the previous text.")
    expect(manager?.canRedo == true, "Undo did not produce a redo action.")

    manager?.redo()
    expect(textView.string == "one two", "Redo did not reapply the edit.")
    expect(manager?.canUndo == true, "Redo did not rebuild the undo action.")

    manager?.undo()
    expect(textView.string == "one", "Undo after redo did not restore the previous text again.")

    // Consecutive single-unit edits coalesce into one typing-burst action.
    backend.textChangeActions[handle]?("one!")
    backend.textChangeActions[handle]?("one!?")
    backend.textChangeActions[handle]?("one!?#")
    manager?.undo()
    expect(textView.string == "one", "Typing-burst undo did not revert the whole burst.")

    // Whitespace closes a word group, so words peel back one undo at a time.
    backend.textChangeActions[handle]?("one ")
    backend.textChangeActions[handle]?("one t")
    backend.textChangeActions[handle]?("one tw")
    backend.textChangeActions[handle]?("one two")
    manager?.undo()
    expect(textView.string == "one ", "Undo did not peel back just the last word.")
    manager?.undo()
    expect(textView.string == "one", "Undo did not peel back the whitespace group.")

    // Deletions coalesce separately from insertions.
    backend.textChangeActions[handle]?("one1")
    backend.textChangeActions[handle]?("one12")
    backend.textChangeActions[handle]?("one1")
    backend.textChangeActions[handle]?("one")
    manager?.undo()
    expect(textView.string == "one12", "Undo did not revert the deletion run as one action.")
    manager?.undo()
    expect(textView.string == "one", "Undo did not revert the insertion run separately.")

    let plain = NSTextView(frame: NSMakeRect(0, 0, 200, 80))
    let plainHandle = plain.realizeNativePeer(in: backend, parent: nil)
    backend.textChangeActions[plainHandle]?("edited")
    expect(plain.undoManager?.canUndo == false, "allowsUndo == false should not register undo actions.")
}

final class SplitResizeRecorder: NSSplitViewDelegate {
    var resizeCount = 0

    func splitViewDidResizeSubviews(_ notification: NSNotification) {
        resizeCount += 1
    }
}

func testSplitViewDividerDragResizesPanes() {
    let backend = InMemoryNativeControlBackend()
    let split = NSSplitView(frame: NSMakeRect(0, 0, 208, 100))
    let left = NSView(frame: NSMakeRect(0, 0, 10, 10))
    let right = NSView(frame: NSMakeRect(0, 0, 10, 10))
    split.addSubview(left)
    split.addSubview(right)
    _ = split.realizeNativePeer(in: backend, parent: nil)

    // Thick dividers are 8 wide: panes 0..100 and 108..208, divider between.
    expect(left.frame.size.width == 100, "adjustSubviews did not split panes evenly.")
    expect(right.frame.origin.x == 108, "adjustSubviews did not offset the second pane past the divider.")

    let recorder = SplitResizeRecorder()
    split.delegate = recorder

    split.mouseDown(with: NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(104, 50)))
    split.mouseDragged(with: NSEvent(type: .leftMouseDragged, locationInWindow: NSMakePoint(60, 50)))
    split.mouseUp(with: NSEvent(type: .leftMouseUp, locationInWindow: NSMakePoint(60, 50)))

    expect(left.frame.size.width == 56, "Dragging the divider did not resize the first pane.")
    expect(right.frame.origin.x == 64, "Dragging the divider did not move the second pane.")
    expect(right.frame.origin.x + right.frame.size.width == 208, "The second pane's far edge should not move during a drag.")
    expect(recorder.resizeCount == 1, "The delegate did not hear about the divider drag.")

    // Over-dragging clamps so no pane goes negative.
    split.mouseDown(with: NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(60, 50)))
    split.mouseDragged(with: NSEvent(type: .leftMouseDragged, locationInWindow: NSMakePoint(-40, 50)))
    split.mouseUp(with: NSEvent(type: .leftMouseUp, locationInWindow: NSMakePoint(-40, 50)))
    expect(left.frame.size.width == 0, "Over-dragging left did not clamp the first pane at zero width.")
    expect(right.frame.origin.x == 8, "Over-dragging left did not park the divider at the leading edge.")

    // A press outside any divider does not start a drag.
    split.mouseDown(with: NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(150, 50)))
    split.mouseDragged(with: NSEvent(type: .leftMouseDragged, locationInWindow: NSMakePoint(30, 50)))
    split.mouseUp(with: NSEvent(type: .leftMouseUp, locationInWindow: NSMakePoint(30, 50)))
    expect(left.frame.size.width == 0 && right.frame.origin.x == 8, "A drag starting outside the divider should not move it.")
}

final class CursorRectTestView: NSView {
    override func resetCursorRects() {
        addCursorRect(NSMakeRect(10, 10, 50, 20), cursor: .iBeam)
        addCursorRect(NSMakeRect(0, 40, 30, 30), cursor: .pointingHand)
    }
}

func testCursorRectsFlowToBackendRegions() {
    let backend = InMemoryNativeControlBackend()
    let view = CursorRectTestView(frame: NSMakeRect(0, 0, 100, 100))
    let handle = view.realizeNativePeer(in: backend, parent: nil)

    let regions = backend.cursorRegions[handle] ?? []
    expect(regions.count == 2, "resetCursorRects did not push both cursor regions at realize time.")
    expect(regions.first == NativeCursorRegion(rect: NSMakeRect(10, 10, 50, 20), cursorName: "iBeam"), "The first cursor region did not carry its rect and cursor name.")
    expect(regions.last?.cursorName == "pointingHand", "The second cursor region did not carry its cursor name.")

    // Split views publish divider gaps as resize regions and keep them
    // aligned as the divider moves.
    let split = NSSplitView(frame: NSMakeRect(0, 0, 208, 100))
    split.addSubview(NSView(frame: NSMakeRect(0, 0, 10, 10)))
    split.addSubview(NSView(frame: NSMakeRect(0, 0, 10, 10)))
    let splitHandle = split.realizeNativePeer(in: backend, parent: nil)

    var splitRegions = backend.cursorRegions[splitHandle] ?? []
    expect(splitRegions == [NativeCursorRegion(rect: NSMakeRect(100, 0, 8, 100), cursorName: "resizeLeftRight")], "The split view did not publish its divider gap as a resize cursor region.")

    split.setPosition(60, ofDividerAt: 0)
    splitRegions = backend.cursorRegions[splitHandle] ?? []
    expect(splitRegions.first?.rect == NSMakeRect(60, 0, 8, 100), "Moving the divider did not update its cursor region.")
}

final class AutosaveTestDocument: NSDocument {
    var text = "seed"

    override class var autosavesInPlace: Bool {
        true
    }

    override func data(ofType typeName: String) throws -> Data {
        Data(Array(text.utf8))
    }

    override func read(from data: Data, ofType typeName: String) throws {
        text = String(decoding: data, as: UTF8.self)
    }
}

func testDocumentWindowCloseAsksToSaveAndAutosaves() {
    clearApplicationWindows()
    defer {
        clearApplicationWindows()
    }

    let application = NSApplication.shared
    let backend = InMemoryNativeControlBackend()
    let previousBackend = application.nativeBackend
    application.nativeBackend = backend
    defer {
        application.nativeBackend = previousBackend
    }

    let document = AutosaveTestDocument()
    NSDocumentController.shared.addDocument(document)
    let window = NSWindow(
        contentRect: NSMakeRect(40, 40, 300, 200),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let handle = window.realizeNativePeer()
    document.addWindowController(NSWindowController(window: window))
    document.updateChangeCount(.changeDone)

    // Cancel vetoes the title-bar close.
    backend.nextModalResponseCode = NSApplication.ModalResponse.alertSecondButtonReturn.rawValue
    expect(!backend.requestWindowClose(handle), "Cancel did not veto the close.")
    expect(window.nativeHandle != nil, "A vetoed close should leave the window realized.")
    expect(NSDocumentController.shared.documents.contains { $0 === document }, "A vetoed close should keep the document open.")

    // Autosave writes edited documents that have a file, via the timer.
    let autosaveURL = FileManager.default.temporaryDirectory.appendingPathComponent("WinChocolateAutosaveTest.txt")
    try? FileManager.default.removeItem(at: autosaveURL)
    defer {
        try? FileManager.default.removeItem(at: autosaveURL)
    }
    document.fileURL = autosaveURL
    document.text = "autosaved contents"
    let timerIdentifier = backend.scheduledTimers.last?.identifier ?? 0
    expect(backend.scheduledTimers.last?.intervalMilliseconds == 30_000, "The autosave timer was not scheduled by addDocument.")
    backend.fireTimer(timerIdentifier)
    expect(!document.isDocumentEdited, "Autosave did not clear the edited state.")
    let saved = (try? Data(contentsOf: autosaveURL)).map { String(decoding: $0, as: UTF8.self) }
    expect(saved == "autosaved contents", "Autosave did not write the document file.")

    // Don't Save closes without writing and releases the document.
    document.updateChangeCount(.changeDone)
    backend.nextModalResponseCode = NSApplication.ModalResponse.alertThirdButtonReturn.rawValue
    expect(backend.requestWindowClose(handle), "Don't Save did not allow the close.")
    expect(document.windowControllers.isEmpty, "Closing the window did not detach its controller.")
    expect(!NSDocumentController.shared.documents.contains { $0 === document }, "Closing the last window did not close the document.")
}

func testFileManagerCoversDocumentAppNeeds() {
    let manager = FileManager.default
    let root = manager.temporaryDirectory.appendingPathComponent("WinChocolateFMTest")
    try? manager.removeItem(at: root)
    defer {
        try? manager.removeItem(at: root)
    }

    // Nested creation, existence, and directory reporting.
    let nested = root.appendingPathComponent("a").appendingPathComponent("b")
    do {
        try manager.createDirectory(at: nested, withIntermediateDirectories: true)
    } catch {
        expect(false, "createDirectory with intermediates threw: \(error)")
    }
    var isDirectory = ObjCBool(false)
    expect(manager.fileExists(atPath: nested.path, isDirectory: &isDirectory), "The nested directory does not exist after creation.")
    expect(isDirectory.boolValue, "The nested directory was not reported as a directory.")
    expect(!manager.fileExists(atPath: root.appendingPathComponent("missing").path), "A missing path should not exist.")

    // File round trip plus isDirectory == false for plain files.
    let fileURL = nested.appendingPathComponent("note.txt")
    do {
        try Data(Array("hello files".utf8)).write(to: fileURL)
    } catch {
        expect(false, "Writing the test file threw: \(error)")
    }
    expect(manager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory), "The written file does not exist.")
    expect(!isDirectory.boolValue, "A plain file was reported as a directory.")

    // Listing sees the file, sorted.
    do {
        let names = try manager.contentsOfDirectory(atPath: nested.path)
        expect(names == ["note.txt"], "Directory listing did not return the file: \(names)")
        let urls = try manager.contentsOfDirectory(at: nested, includingPropertiesForKeys: nil)
        expect(urls.first?.lastPathComponent == "note.txt", "URL listing did not return the file URL.")
    } catch {
        expect(false, "contentsOfDirectory threw: \(error)")
    }

    // Copy requires a fresh destination and copies contents.
    let copyURL = nested.appendingPathComponent("copy.txt")
    do {
        try manager.copyItem(at: fileURL, to: copyURL)
        let copied = try Data(contentsOf: copyURL)
        expect(String(decoding: copied, as: UTF8.self) == "hello files", "The copied file's contents did not round trip.")
    } catch {
        expect(false, "copyItem threw: \(error)")
    }
    do {
        try manager.copyItem(at: fileURL, to: copyURL)
        expect(false, "Copying over an existing destination should throw.")
    } catch {
    }

    // Move renames and removes the source.
    let movedURL = nested.appendingPathComponent("moved.txt")
    do {
        try manager.moveItem(at: copyURL, to: movedURL)
    } catch {
        expect(false, "moveItem threw: \(error)")
    }
    expect(!manager.fileExists(atPath: copyURL.path), "The moved file still exists at its source.")
    expect(manager.fileExists(atPath: movedURL.path), "The moved file does not exist at its destination.")

    // Directory copy is recursive.
    let treeCopy = root.appendingPathComponent("tree")
    do {
        try manager.copyItem(at: root.appendingPathComponent("a"), to: treeCopy)
        expect(manager.fileExists(atPath: treeCopy.appendingPathComponent("b").appendingPathComponent("note.txt").path), "Recursive copy did not carry nested files.")
    } catch {
        expect(false, "Recursive copyItem threw: \(error)")
    }

    // Recursive removal takes the whole tree.
    do {
        try manager.removeItem(at: root)
    } catch {
        expect(false, "Recursive removeItem threw: \(error)")
    }
    expect(!manager.fileExists(atPath: root.path), "The removed tree still exists.")

    // Known folders resolve to real locations.
    let documents = manager.urls(for: .documentDirectory, in: .userDomainMask)
    expect(documents.count == 1, "The Documents folder did not resolve.")
    expect(manager.fileExists(atPath: documents[0].path), "The resolved Documents folder does not exist.")
}

func testScrollToVisibleMovesTheClipView() {
    let backend = InMemoryNativeControlBackend()
    let scrollView = NSScrollView(frame: NSMakeRect(0, 0, 100, 100))
    let document = NSView(frame: NSMakeRect(0, 0, 100, 500))
    scrollView.documentView = document
    let child = NSView(frame: NSMakeRect(0, 300, 100, 40))
    document.addSubview(child)
    _ = scrollView.realizeNativePeer(in: backend, parent: nil)

    expect(child.enclosingScrollView === scrollView, "enclosingScrollView did not find the ancestor scroll view.")
    expect(scrollView.contentView.boundsOrigin == NSZeroPoint, "The clip view should start at the origin.")

    // A rect below the viewport scrolls just enough to reveal its bottom.
    let didScroll = child.scrollToVisible(child.bounds)
    expect(didScroll, "scrollToVisible did not report scrolling for an off-screen rect.")
    expect(scrollView.contentView.boundsOrigin.y == 240, "scrollToVisible did not align the rect's bottom to the viewport bottom.")

    // Scrolling to an already-visible rect does nothing.
    let didScrollAgain = child.scrollToVisible(child.bounds)
    expect(!didScrollAgain, "scrollToVisible should not scroll when the rect is already visible.")

    // A view outside any scroll view reports no scrolling.
    let orphan = NSView(frame: NSMakeRect(0, 0, 10, 10))
    expect(orphan.enclosingScrollView == nil, "A detached view should have no enclosing scroll view.")
    expect(!orphan.scrollToVisible(orphan.bounds), "scrollToVisible without a scroll view should report false.")
}

func testTimerSchedulesFiresAndInvalidates() {
    let application = NSApplication.shared
    let backend = InMemoryNativeControlBackend()
    let previousBackend = application.nativeBackend
    application.nativeBackend = backend
    defer {
        application.nativeBackend = previousBackend
    }

    var repeatingFires = 0
    let repeating = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
        repeatingFires += 1
    }
    let repeatingIdentifier = backend.scheduledTimers.last?.identifier ?? 0
    expect(backend.scheduledTimers.last?.intervalMilliseconds == 250, "The timer interval did not convert to milliseconds.")
    expect(repeating.timeInterval == 0.25, "The timer did not keep its interval.")

    backend.fireTimer(repeatingIdentifier)
    backend.fireTimer(repeatingIdentifier)
    expect(repeatingFires == 2, "A repeating timer did not fire on each tick.")
    expect(repeating.isValid, "A repeating timer should stay valid after firing.")

    repeating.invalidate()
    expect(!repeating.isValid, "invalidate did not mark the timer invalid.")
    expect(backend.canceledTimerIdentifiers.contains(repeatingIdentifier), "invalidate did not cancel the native timer.")
    backend.fireTimer(repeatingIdentifier)
    expect(repeatingFires == 2, "A canceled timer's action should not fire.")

    var oneShotFires = 0
    let oneShot = Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { _ in
        oneShotFires += 1
    }
    let oneShotIdentifier = backend.scheduledTimers.last?.identifier ?? 0
    backend.fireTimer(oneShotIdentifier)
    expect(oneShotFires == 1, "A one-shot timer did not fire.")
    expect(!oneShot.isValid, "A one-shot timer should invalidate after firing.")
    expect(backend.canceledTimerIdentifiers.contains(oneShotIdentifier), "A one-shot timer did not cancel its native timer after firing.")
}

func testTextViewFindAndReplace() {
    let backend = InMemoryNativeControlBackend()
    let textView = NSTextView(frame: NSMakeRect(0, 0, 300, 100))
    textView.string = "alpha beta alpha BETA alpha"
    _ = textView.realizeNativePeer(in: backend, parent: nil)

    let previousSearch = NSTextFinder.winSharedSearchString
    let previousReplacement = NSTextFinder.winSharedReplacementString
    defer {
        NSTextFinder.winSharedSearchString = previousSearch
        NSTextFinder.winSharedReplacementString = previousReplacement
    }

    // Forward find is case-insensitive and wraps.
    NSTextFinder.winSharedSearchString = "beta"
    textView.setSelectedRange(NSMakeRange(0, 0))
    textView.performTextFinderAction(.nextMatch)
    expect(textView.selectedRange == NSMakeRange(6, 4), "nextMatch did not select the first match.")
    textView.performTextFinderAction(.nextMatch)
    expect(textView.selectedRange == NSMakeRange(17, 4), "nextMatch did not find the uppercase match case-insensitively.")
    textView.performTextFinderAction(.nextMatch)
    expect(textView.selectedRange == NSMakeRange(6, 4), "nextMatch did not wrap around to the first match.")

    // Backward find wraps the other way.
    textView.performTextFinderAction(.previousMatch)
    expect(textView.selectedRange == NSMakeRange(17, 4), "previousMatch did not wrap to the last match.")

    // The selection becomes the search string through the menu tag path.
    textView.setSelectedRange(NSMakeRange(0, 5))
    let useSelectionItem = NSMenuItem(title: "Use Selection for Find", action: nil, keyEquivalent: "")
    useSelectionItem.tag = NSTextFinder.Action.setSearchString.rawValue
    textView.performTextFinderAction(useSelectionItem)
    expect(NSTextFinder.winSharedSearchString == "alpha", "setSearchString did not adopt the selection.")

    // Replace only rewrites a selection that matches the search string.
    NSTextFinder.winSharedReplacementString = "omega"
    textView.setSelectedRange(NSMakeRange(6, 4))
    textView.performTextFinderAction(.replace)
    expect(textView.string == "alpha beta alpha BETA alpha", "Replace should not rewrite a selection that does not match.")

    textView.setSelectedRange(NSMakeRange(0, 5))
    textView.performTextFinderAction(.replace)
    expect(textView.string == "omega beta alpha BETA alpha", "Replace did not rewrite the matching selection.")

    // Replace-all rewrites every remaining case-insensitive match.
    textView.performTextFinderAction(.replaceAll)
    expect(textView.string == "omega beta omega BETA omega", "replaceAll did not rewrite every match.")
}

final class KeyEquivalentTestView: NSView {
    var consumesEquivalents = false
    var seenEquivalents = 0

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        seenEquivalents += 1
        return consumesEquivalents
    }
}

func testViewChainSeesKeyEquivalentsBeforeMenu() {
    clearApplicationWindows()
    defer {
        clearApplicationWindows()
    }

    let application = NSApplication.shared
    let backend = InMemoryNativeControlBackend()
    let previousBackend = application.nativeBackend
    application.nativeBackend = backend
    let previousMenu = application.mainMenu
    defer {
        application.nativeBackend = previousBackend
        application.mainMenu = previousMenu
    }

    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 400, 300),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let content = NSView(frame: NSMakeRect(0, 0, 400, 300))
    let keyView = KeyEquivalentTestView(frame: NSMakeRect(0, 0, 100, 100))
    content.addSubview(keyView)
    window.contentView = content
    window.makeKey()

    var menuFired = false
    let menu = NSMenu()
    let submenuItem = NSMenuItem(title: "Test", action: nil, keyEquivalent: "")
    let submenu = NSMenu(title: "Test")
    let item = NSMenuItem(title: "Do Thing", action: nil, keyEquivalent: "k")
    item.onAction = { _ in
        menuFired = true
    }
    submenu.addItem(item)
    submenuItem.submenu = submenu
    menu.addItem(submenuItem)
    application.mainMenu = menu

    let event = NSEvent(type: .keyDown, locationInWindow: NSMakePoint(0, 0), keyCode: 0x4b, characters: "k", modifierFlags: [.control])

    // The view declines, so the menu equivalent fires.
    expect(backend.keyEquivalentHandler?(event) == true, "The menu key equivalent did not fire when no view consumed it.")
    expect(keyView.seenEquivalents == 1, "The view chain was not consulted before the menu.")
    expect(menuFired, "The menu action did not run after the view declined.")

    // The view consumes, so the menu never sees the event.
    menuFired = false
    keyView.consumesEquivalents = true
    expect(backend.keyEquivalentHandler?(event) == true, "A view-consumed key equivalent should report handled.")
    expect(!menuFired, "The menu should not fire when a view consumed the equivalent.")
}

final class NoteTestDocument: NSDocument {
    var text = "seed"
    var madeControllers = 0

    override func data(ofType typeName: String) throws -> Data {
        Data(Array(text.utf8))
    }

    override func read(from data: Data, ofType typeName: String) throws {
        text = String(decoding: data, as: UTF8.self)
    }

    override func makeWindowControllers() {
        madeControllers += 1
        let window = NSWindow(
            contentRect: NSMakeRect(40, 40, 300, 200),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        addWindowController(NSWindowController(window: window))
    }
}

func testDocumentWindowControllersSyncTitles() {
    clearApplicationWindows()
    defer {
        clearApplicationWindows()
    }

    let document = NoteTestDocument()
    document.makeWindowControllers()
    expect(document.windowControllers.count == 1, "makeWindowControllers did not attach a controller.")

    let controller = document.windowControllers[0]
    expect(controller.document === document, "addWindowController did not point the controller at the document.")
    expect(controller.isWindowLoaded, "The controller should report its window as loaded.")
    expect(controller.window?.title == "Untitled", "Attaching did not sync the untitled display name.")

    document.updateChangeCount(.changeDone)
    expect(controller.window?.title == "*Untitled", "An edited document did not gain the asterisk title.")

    document.updateChangeCount(.changeCleared)
    expect(controller.window?.title == "Untitled", "Clearing changes did not drop the asterisk title.")

    let second = NSWindowController(window: nil)
    document.addWindowController(second)
    document.addWindowController(second)
    expect(document.windowControllers.count == 2, "Re-adding a controller should not duplicate it.")

    document.removeWindowController(second)
    expect(document.windowControllers.count == 1, "removeWindowController did not detach the controller.")
    expect(second.document == nil, "Detaching did not clear the controller's document.")

    document.close()
    expect(document.windowControllers.isEmpty, "close did not release the window controllers.")
}

func testDocumentControllerNewDocumentMakesAndShowsWindows() {
    clearApplicationWindows()
    defer {
        clearApplicationWindows()
    }

    let shared = NSDocumentController.shared
    let previousClass = shared.winDocumentClass
    defer {
        shared.winDocumentClass = previousClass
    }
    shared.winDocumentClass = NoteTestDocument.self

    let document = shared.newDocument(nil)
    expect(shared.documents.contains { $0 === document }, "newDocument did not register the document.")
    expect(shared.currentDocument === document, "newDocument did not become the current document.")
    expect((document as? NoteTestDocument)?.madeControllers == 1, "newDocument did not make window controllers.")
    expect(document.windowControllers.first?.window != nil, "The new document's controller has no window.")

    document.close()
    expect(!shared.documents.contains { $0 === document }, "close did not remove the document from the controller.")
}

func testAttributedStringStoresStringAndAttributes() {
    let plain = NSAttributedString(string: "Plain")
    expect(plain.string == "Plain", "Attributed string did not store its characters.")
    expect(plain.attributes.isEmpty, "Attribute-free attributed string did not report empty attributes.")

    let styled = NSAttributedString(
        string: "Styled",
        attributes: [
            .font: NSFont.boldSystemFont(ofSize: 13),
            .foregroundColor: NSColor.blue
        ]
    )
    expect(styled.string == "Styled", "Attributed string with attributes did not store its characters.")
    expect((styled.attributes[.font] as? NSFont)?.pointSize == 13, "Attributed string did not round-trip the font attribute.")
    expect((styled.attributes[.font] as? NSFont)?.weight == .bold, "Attributed string did not round-trip the font weight.")
    expect(styled.attributes[.foregroundColor] as? NSColor == .blue, "Attributed string did not round-trip the color attribute.")

    let nilAttributes = NSAttributedString(string: "None", attributes: nil)
    expect(nilAttributes.attributes.isEmpty, "Nil attribute dictionary did not normalize to empty attributes.")

    let estimate = "Styled".size(withAttributes: [.font: NSFont.systemFont(ofSize: 10)])
    expect(abs(estimate.width - 33) < 0.001, "String size estimate did not scale width by character count and size.")
    expect(abs(estimate.height - 13.5) < 0.001, "String size estimate did not scale height by font size.")
}

final class EventRecordingView: NSView {
    var rightDownCount = 0
    var rightUpCount = 0
    var lastClickCount = 0
    var lastScrollDeltaY: CGFloat = 0

    override func mouseDown(with event: NSEvent) {
        lastClickCount = event.clickCount
    }

    override func rightMouseDown(with event: NSEvent) {
        rightDownCount += 1
    }

    override func rightMouseUp(with event: NSEvent) {
        rightUpCount += 1
    }

    override func scrollWheel(with event: NSEvent) {
        lastScrollDeltaY = event.scrollingDeltaY
    }
}

func testRightMouseScrollAndClickCountReachTheView() {
    let backend = InMemoryNativeControlBackend()
    let view = EventRecordingView(frame: NSMakeRect(0, 0, 50, 50))
    let handle = view.realizeNativePeer(in: backend, parent: nil)

    backend.rightMouseDownActions[handle]?(NSEvent(type: .rightMouseDown, locationInWindow: NSMakePoint(5, 5)))
    backend.rightMouseUpActions[handle]?(NSEvent(type: .rightMouseUp, locationInWindow: NSMakePoint(5, 5)))
    backend.mouseDownActions[handle]?(NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(5, 5), clickCount: 2))
    backend.scrollWheelActions[handle]?(NSEvent(type: .scrollWheel, locationInWindow: NSMakePoint(5, 5), scrollingDeltaY: -2))

    expect(view.rightDownCount == 1, "Right mouse-down did not reach the view responder.")
    expect(view.rightUpCount == 1, "Right mouse-up did not reach the view responder.")
    expect(view.lastClickCount == 2, "Double-click count did not reach mouseDown.")
    expect(view.lastScrollDeltaY == -2, "Scroll wheel delta did not reach scrollWheel.")
}

func testAlertCustomButtonsRunComposedModalPanel() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        clearApplicationWindows()
    }

    let alert = NSAlert()
    alert.messageText = "Save changes?"
    alert.informativeText = "Your changes will be lost otherwise."
    alert.addButton(withTitle: "Save")
    alert.addButton(withTitle: "Don't Save")
    alert.addButton(withTitle: "Cancel")
    alert.showsSuppressionButton = true
    alert.suppressionButton?.state = .on
    backend.nextModalResponseCode = NSApplication.ModalResponse.alertSecondButtonReturn.rawValue

    let response = alert.runModal()

    expect(response == .alertSecondButtonReturn, "Composed alert did not return the scripted button response.")
    expect(backend.modalSessions.count == 1, "Composed alert did not run exactly one modal session.")
    expect(alert.suppressionButton?.state == .on, "Alert suppression button state was not preserved.")
}

func testRunModalReturnsScriptedStopCode() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 200, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    backend.nextModalResponseCode = NSApplication.ModalResponse.OK.rawValue

    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        clearApplicationWindows()
    }

    let response = NSApplication.shared.runModal(for: window)
    NSApplication.shared.stopModal(withCode: .cancel)

    expect(response == .OK, "runModal did not return the backend stop code.")
    expect(backend.modalSessions.first == window.nativeHandle, "runModal did not run a session for the window.")
    expect(backend.modalStopCodes == [NSApplication.ModalResponse.cancel.rawValue], "stopModal did not forward its code to the backend.")
}

final class OtherMouseRecordingView: NSView {
    var otherDownCount = 0
    var otherUpCount = 0

    override func otherMouseDown(with event: NSEvent) {
        otherDownCount += 1
    }

    override func otherMouseUp(with event: NSEvent) {
        otherUpCount += 1
    }
}

func testOtherMouseButtonsReachTheView() {
    let backend = InMemoryNativeControlBackend()
    let view = OtherMouseRecordingView(frame: NSMakeRect(0, 0, 50, 50))
    let handle = view.realizeNativePeer(in: backend, parent: nil)

    backend.otherMouseDownActions[handle]?(NSEvent(type: .otherMouseDown, locationInWindow: NSMakePoint(5, 5)))
    backend.otherMouseUpActions[handle]?(NSEvent(type: .otherMouseUp, locationInWindow: NSMakePoint(5, 5)))

    expect(view.otherDownCount == 1, "Other mouse-down did not reach the view responder.")
    expect(view.otherUpCount == 1, "Other mouse-up did not reach the view responder.")

    // Unhandled other-mouse events forward along the responder chain.
    let container = OtherMouseRecordingView(frame: NSMakeRect(0, 0, 100, 100))
    let child = NSView(frame: NSMakeRect(0, 0, 50, 50))
    container.addSubview(child)
    child.otherMouseDown(with: NSEvent(type: .otherMouseDown, locationInWindow: NSMakePoint(5, 5)))
    expect(container.otherDownCount == 1, "Other mouse-down did not forward to the next responder.")
}

func testMenuPerformKeyEquivalentMatchesControlAsCommand() {
    let menu = NSMenu(title: "Main")
    let fileItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
    let fileMenu = NSMenu(title: "File")
    var savedCount = 0
    let saveItem = NSMenuItem(title: "Save", action: nil, keyEquivalent: "s")
    saveItem.onAction = { _ in
        savedCount += 1
    }
    fileMenu.addItem(saveItem)
    fileItem.submenu = fileMenu
    menu.addItem(fileItem)

    let controlS = NSEvent(type: .keyDown, locationInWindow: NSZeroPoint, keyCode: 0x53, characters: "s", modifierFlags: [.control])
    expect(menu.performKeyEquivalent(with: controlS), "Control-modified key did not match a .command key equivalent.")
    expect(savedCount == 1, "Matched key equivalent did not perform the item action.")

    let commandS = NSEvent(type: .keyDown, locationInWindow: NSZeroPoint, keyCode: 0x53, characters: "s", modifierFlags: [.command])
    expect(menu.performKeyEquivalent(with: commandS), "Command-modified key did not match a .command key equivalent.")

    let controlD = NSEvent(type: .keyDown, locationInWindow: NSZeroPoint, keyCode: 0x44, characters: "d", modifierFlags: [.control])
    expect(!menu.performKeyEquivalent(with: controlD), "Non-matching character should not perform a key equivalent.")

    let bareS = NSEvent(type: .keyDown, locationInWindow: NSZeroPoint, keyCode: 0x53, characters: "s", modifierFlags: [])
    expect(!menu.performKeyEquivalent(with: bareS), "Unmodified key should not match a .command key equivalent.")
    expect(savedCount == 2, "Key equivalent fired for a non-matching event.")

    // Installing a main menu registers the backend key-equivalent handler.
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.mainMenu = nil
        NSApplication.shared.nativeBackend = previousBackend
    }

    NSApplication.shared.mainMenu = menu
    expect(backend.keyEquivalentHandler?(controlS) == true, "Application main menu did not route backend key equivalents.")
    expect(savedCount == 3, "Backend key-equivalent handler did not perform the menu action.")
}

func testMenuPopUpPerformsScriptedContextSelection() {
    let backend = InMemoryNativeControlBackend()
    let view = NSView(frame: NSMakeRect(0, 0, 100, 100))
    _ = view.realizeNativePeer(in: backend, parent: nil)

    var chosenTitle = ""
    let menu = NSMenu(title: "Context")
    for title in ["Star", "Wave", "Card"] {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.onAction = { _ in
            chosenTitle = title
        }
        menu.addItem(item)
    }

    backend.nextContextMenuSelection = 1
    expect(menu.popUp(positioning: nil, at: NSMakePoint(10, 10), in: view), "Scripted context selection did not report success.")
    expect(chosenTitle == "Wave", "Context menu did not perform the scripted item's action.")
    expect(backend.poppedContextMenus.count == 1, "Context menu pop was not recorded.")
    expect(backend.poppedContextMenus.first === menu, "Recorded context menu was not the popped menu.")

    backend.nextContextMenuSelection = -1
    expect(!menu.popUp(positioning: nil, at: NSMakePoint(10, 10), in: view), "Cancelled context menu should report no selection.")
    expect(backend.poppedContextMenus.count == 2, "Cancelled context menu pop was not recorded.")
}

func testCursorSetPushPopSyncToBackend() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSCursor.arrow.set()
        NSApplication.shared.nativeBackend = previousBackend
    }

    NSCursor.iBeam.set()
    expect(backend.cursorNames.last == "iBeam", "Cursor set did not reach the backend.")
    expect(NSCursor.current === NSCursor.iBeam, "Cursor set did not update the current cursor.")

    NSCursor.crosshair.push()
    expect(backend.cursorNames.last == "crosshair", "Cursor push did not reach the backend.")
    expect(NSCursor.current === NSCursor.crosshair, "Cursor push did not update the current cursor.")

    NSCursor.pop()
    expect(backend.cursorNames.last == "iBeam", "Cursor pop did not restore the previous cursor.")
    expect(NSCursor.current === NSCursor.iBeam, "Cursor pop did not update the current cursor.")
}

func testProgressIndicatorIndeterminateSyncsToBackend() {
    let backend = InMemoryNativeControlBackend()
    let indicator = NSProgressIndicator(frame: NSMakeRect(0, 0, 120, 18))
    let handle = indicator.realizeNativePeer(in: backend, parent: nil)

    expect(backend.progressIndeterminateStates[handle]?.isIndeterminate == false, "Determinate indicator should realize as determinate.")

    indicator.isIndeterminate = true
    indicator.startAnimation(nil)
    expect(backend.progressIndeterminateStates[handle]?.isIndeterminate == true, "isIndeterminate did not sync to the backend.")
    expect(backend.progressIndeterminateStates[handle]?.animating == true, "startAnimation did not sync to the backend.")

    indicator.stopAnimation(nil)
    expect(backend.progressIndeterminateStates[handle]?.animating == false, "stopAnimation did not sync to the backend.")

    indicator.isIndeterminate = false
    indicator.style = .spinning
    expect(backend.progressIndeterminateStates[handle]?.isIndeterminate == true, "Spinning style should render indeterminately on the classic backend.")
}

final class RecordingTextViewDelegate: NSTextViewDelegate {
    var changeCount = 0
    var lastNotificationName = ""
    var lastObject: AnyObject?

    func textDidChange(_ notification: NSNotification) {
        changeCount += 1
        lastNotificationName = notification.name
        lastObject = notification.object
    }
}

func testTextViewSelectionInsertionAndDelegate() {
    let backend = InMemoryNativeControlBackend()
    let textView = NSTextView(frame: NSMakeRect(0, 0, 240, 100))
    let delegate = RecordingTextViewDelegate()
    textView.delegate = delegate
    textView.string = "Hello Chocolate"
    let handle = textView.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.text == "Hello Chocolate", "Text view did not push its string to the native peer.")

    textView.selectedRange = NSMakeRange(6, 9)
    expect(backend.records[handle]?.textSelectionLocation == 6, "setSelectedRange did not record the selection location.")
    expect(backend.records[handle]?.textSelectionLength == 9, "setSelectedRange did not record the selection length.")
    expect(textView.selectedRange == NSMakeRange(6, 9), "selectedRange did not read the native selection back.")

    textView.selectedRange = NSMakeRange(4, 999)
    expect(textView.selectedRange == NSMakeRange(4, 11), "Native selection did not clamp an oversized length.")

    textView.insertText("World", replacementRange: NSMakeRange(6, 9))
    expect(backend.records[handle]?.text == "Hello World", "insertText did not replace the range in the native text.")
    expect(textView.string == "Hello World", "insertText did not update the local string.")
    expect(textView.selectedRange == NSMakeRange(11, 0), "insertText did not collapse the selection to the inserted end.")

    textView.insertText("!", replacementRange: NSMakeRange(NSNotFound, 0))
    expect(textView.string == "Hello World!", "NSNotFound replacement range did not insert at the current selection.")
    expect(backend.records[handle]?.text == "Hello World!", "NSNotFound replacement did not reach the native text.")

    textView.scrollRangeToVisible(NSMakeRange(0, 5))
    expect(backend.records[handle]?.textSelectionLocation == 0, "scrollRangeToVisible did not move the native selection.")
    expect(backend.records[handle]?.textSelectionLength == 5, "scrollRangeToVisible did not carry the range length.")

    textView.font = NSFont.systemFont(ofSize: 15)
    expect(backend.records[handle]?.font?.pointSize == 15, "Text view font did not sync to the native peer.")

    expect(backend.records[handle]?.isTextEditable == true, "Editable text view should realize as editable.")
    textView.isEditable = false
    expect(backend.records[handle]?.isTextEditable == false, "isEditable did not sync the native read-only style.")

    backend.textChangeActions[handle]?("Typed text")
    expect(textView.string == "Typed text", "Native text change did not update the string.")
    expect(delegate.changeCount == 1, "Native text change did not notify the delegate.")
    expect(delegate.lastNotificationName == NSTextView.textDidChangeNotification, "textDidChange did not carry the AppKit notification name.")
    expect(delegate.lastObject === textView, "textDidChange did not carry the text view as the notification object.")

    // A selection made before realization applies when the peer appears.
    let deferred = NSTextView(frame: NSMakeRect(0, 0, 100, 40))
    deferred.string = "abcdef"
    deferred.selectedRange = NSMakeRange(2, 3)
    let deferredHandle = deferred.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[deferredHandle]?.textSelectionLocation == 2, "Stored selection location did not apply on realization.")
    expect(backend.records[deferredHandle]?.textSelectionLength == 3, "Stored selection length did not apply on realization.")
}

final class TextContractDocument: NSDocument {
    var content = ""

    override func data(ofType typeName: String) throws -> Data {
        Data(Array(content.utf8))
    }

    override func read(from data: Data, ofType typeName: String) throws {
        content = String(decoding: data, as: UTF8.self)
    }
}

func testDocumentChangeCountAndOverridableDefaults() {
    let document = NSDocument()

    expect(document.displayName == "Untitled", "Unsaved document did not report the Untitled display name.")
    expect(!document.isDocumentEdited, "New document should not report edits.")

    document.updateChangeCount(.changeDone)
    expect(document.isDocumentEdited, "changeDone did not mark the document edited.")

    document.updateChangeCount(.changeCleared)
    expect(!document.isDocumentEdited, "changeCleared did not clear the edited state.")

    var thrownError: Error?
    do {
        _ = try document.data(ofType: "txt")
    } catch {
        thrownError = error
    }
    expect(thrownError as? NSDocumentError == .unimplemented, "Base data(ofType:) did not throw the unimplemented error.")

    document.fileURL = URL(fileURLWithPath: "C:\\Docs\\Report.txt")
    expect(document.displayName == "Report.txt", "Saved document did not use the file name as display name.")
}

func testDocumentSavePanelFlowWritesAndReadsBack() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    let savePath = "C:\\Users\\bobby\\AppData\\Local\\Temp\\winchoc-doc-test.txt"
    let document = TextContractDocument()
    document.content = "Chocolate document"
    document.updateChangeCount(.changeDone)
    backend.scriptedFileDialogPaths = [[savePath]]

    document.save(nil)

    expect(backend.fileDialogRequests.count == 1, "Saving a URL-less document did not run one save panel.")
    expect(backend.fileDialogRequests.first?.kind == .save, "Saving did not request a save dialog.")
    expect(backend.fileDialogRequests.first?.fileName == "Untitled", "Save panel did not seed the name field with the display name.")
    expect(document.fileURL?.path == savePath, "Save did not adopt the chosen destination URL.")
    expect(document.lastError == nil, "Save reported an unexpected error.")
    expect(!document.isDocumentEdited, "Save did not clear the change count.")

    let reader = TextContractDocument()
    var readError: Error?
    do {
        try reader.read(from: URL(fileURLWithPath: savePath), ofType: "txt")
    } catch {
        readError = error
    }
    expect(readError == nil, "Reading the saved document back failed.")
    expect(reader.content == "Chocolate document", "Round-tripped document content did not match.")
    expect(reader.fileURL?.path == savePath, "read(from:ofType:) did not record the file URL.")
    expect(reader.fileType == "txt", "read(from:ofType:) did not record the file type.")

    // A document with a destination saves without presenting a panel.
    document.content = "Chocolate document v2"
    document.updateChangeCount(.changeDone)
    document.save(nil)
    expect(backend.fileDialogRequests.count == 1, "Saving a titled document should not run another panel.")
    expect(!document.isDocumentEdited, "Second save did not clear the change count.")

    let secondReader = TextContractDocument()
    try? secondReader.read(from: URL(fileURLWithPath: savePath), ofType: "txt")
    expect(secondReader.content == "Chocolate document v2", "In-place save did not rewrite the file.")

    // saveAs always asks for a destination.
    backend.scriptedFileDialogPaths = [[savePath]]
    document.saveAs(nil)
    expect(backend.fileDialogRequests.count == 2, "saveAs did not force a save panel.")
}

func testDocumentControllerTracksDocumentsRecentsAndOpen() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    let controller = NSDocumentController()
    let first = NSDocument()
    let second = NSDocument()

    controller.addDocument(first)
    controller.addDocument(second)
    expect(controller.documents.count == 2, "Controller did not track added documents.")
    expect(controller.currentDocument === second, "Controller did not make the newest document current.")

    controller.removeDocument(second)
    expect(controller.documents.count == 1, "Controller did not remove a document.")
    expect(controller.currentDocument === first, "Controller did not fall back to the remaining document.")

    for index in 1...12 {
        controller.noteNewRecentDocumentURL(URL(fileURLWithPath: "C:\\Docs\\file-\(index).txt"))
    }
    expect(controller.recentDocumentURLs.count == 10, "Recent documents list did not cap at ten entries.")
    expect(controller.recentDocumentURLs.first?.lastPathComponent == "file-12.txt", "Recent documents were not most-recent first.")

    controller.noteNewRecentDocumentURL(URL(fileURLWithPath: "C:\\Docs\\file-7.txt"))
    expect(controller.recentDocumentURLs.count == 10, "Re-noting a recent URL should not grow the list.")
    expect(controller.recentDocumentURLs.first?.lastPathComponent == "file-7.txt", "Re-noted URL did not move to the front.")
    expect(controller.recentDocumentURLs.filter { $0.lastPathComponent == "file-7.txt" }.count == 1, "Recent documents did not dedupe.")

    // openDocument reads each chosen URL into the configured document class.
    let openPath = "C:\\Users\\bobby\\AppData\\Local\\Temp\\winchoc-doc-test.txt"
    let seed = TextContractDocument()
    seed.content = "Opened content"
    var seedError: Error?
    do {
        try seed.write(to: URL(fileURLWithPath: openPath), ofType: "txt")
    } catch {
        seedError = error
    }
    expect(seedError == nil, "Seeding the open-document file failed.")

    controller.winDocumentClass = TextContractDocument.self
    backend.scriptedFileDialogPaths = [[openPath]]
    controller.openDocument(nil)

    expect(backend.fileDialogRequests.first?.kind == .open, "openDocument did not run an open dialog.")
    expect(controller.documents.count == 2, "openDocument did not add the opened document.")
    let opened = controller.currentDocument as? TextContractDocument
    expect(opened?.content == "Opened content", "openDocument did not read the chosen file.")
    expect(opened?.fileURL?.path == openPath, "openDocument did not record the opened file URL.")
    expect(controller.recentDocumentURLs.first?.path == openPath, "openDocument did not note the recent document URL.")

    // Closing a document removes it from the shared controller.
    let shared = NSDocumentController.shared
    let closing = NSDocument()
    shared.addDocument(closing)
    closing.close()
    expect(!shared.documents.contains { $0 === closing }, "close() did not remove the document from the shared controller.")
}

final class ColorChangeRecordingView: NSView {
    var receivedColors: [NSColor] = []

    override var acceptsFirstResponder: Bool {
        true
    }

    override func changeColor(_ sender: Any?) {
        if let panel = sender as? NSColorPanel {
            receivedColors.append(panel.color)
        }
    }
}

final class FontChangeRecordingView: NSView {
    var receivedFonts: [NSFont] = []

    override var acceptsFirstResponder: Bool {
        true
    }

    override func changeFont(_ sender: Any?) {
        receivedFonts.append(NSFontManager.shared.convert(NSFont.systemFont(ofSize: 13)))
    }
}

final class RecordingTextFieldDelegate: NSTextFieldDelegate {
    var began = 0
    var changed = 0
    var ended = 0
    var lastChangedText: String?

    func controlTextDidBeginEditing(_ obj: NSNotification) {
        began += 1
    }

    func controlTextDidChange(_ obj: NSNotification) {
        changed += 1
        lastChangedText = (obj.object as? NSTextField)?.stringValue
    }

    func controlTextDidEndEditing(_ obj: NSNotification) {
        ended += 1
    }
}

func testTextFieldFormatterDisplaysAndParses() {
    let backend = InMemoryNativeControlBackend()
    let field = NSTextField(string: "", frame: NSMakeRect(0, 0, 120, 24))
    field.isEditable = true

    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    field.formatter = formatter
    field.objectValue = NSNumber(value: 1234.5)

    // Setting objectValue renders it through the formatter for display.
    expect(field.stringValue == "$1,234.50", "Formatter did not format objectValue for display.")

    let handle = field.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[handle]?.text == "$1,234.50", "Field did not realize with formatted text.")

    // The user edits the text, then focus leaves the field (commit point).
    field.stringValue = "$99.5"
    backend.simulateFocusChange(gained: false, for: handle)

    // Editing end parses the text into objectValue and re-displays it canonically.
    expect((field.objectValue as? NSNumber)?.doubleValue == 99.5, "Formatter did not parse edited text into objectValue.")
    expect(field.stringValue == "$99.50", "Field did not re-display the canonical formatted value.")

    // Unparseable input reverts to the last valid value on commit.
    field.stringValue = "garbage"
    backend.simulateFocusChange(gained: false, for: handle)
    expect(field.stringValue == "$99.50", "Field did not revert unparseable input to the last valid value.")
}

func testNSNumberBoxing() {
    // Integers round-trip exactly and read as other widths.
    let three = NSNumber(value: 3)
    expect(three.intValue == 3, "NSNumber int value wrong.")
    expect(three.doubleValue == 3.0, "NSNumber double from int wrong.")
    expect(three.int64Value == 3, "NSNumber int64 wrong.")
    expect(three.stringValue == "3", "NSNumber integer stringValue should have no decimal point.")
    expect(three.boolValue, "NSNumber non-zero boolValue should be true.")

    // Doubles keep their fractional value.
    let pi = NSNumber(value: 3.5)
    expect(pi.doubleValue == 3.5, "NSNumber double value wrong.")
    expect(pi.intValue == 3, "NSNumber int from double should truncate.")
    expect(pi.stringValue == "3.5", "NSNumber fractional stringValue wrong.")

    // Booleans box and read back.
    let flag = NSNumber(value: true)
    expect(flag.boolValue, "NSNumber bool value wrong.")
    expect(flag.intValue == 1, "NSNumber bool int value wrong.")

    // Equality and hashing compare by numeric value.
    expect(NSNumber(value: 2) == NSNumber(value: 2.0), "NSNumber equality should compare numeric value.")
    expect(NSNumber(value: 1).compare(NSNumber(value: 2)) == .orderedAscending, "NSNumber compare wrong.")
    var seen = Set<NSNumber>()
    seen.insert(NSNumber(value: 5))
    expect(seen.contains(NSNumber(value: 5.0)), "NSNumber hashing should match equal values.")
}

func testNumberFormatterStylesAndParsing() {
    // Plain style: no grouping, no fraction.
    let plain = NumberFormatter()
    plain.numberStyle = .none
    expect(plain.string(from: NSNumber(value: 1234)) == "1234", "Plain style should not group.")

    // Decimal style groups and keeps up to three fraction digits (US locale).
    let decimal = NumberFormatter()
    decimal.numberStyle = .decimal
    expect(decimal.string(from: NSNumber(value: 1234.5)) == "1,234.5", "Decimal style did not group/format.")
    expect(decimal.string(from: NSNumber(value: -1234)) == "-1,234", "Decimal negative did not format.")

    // Currency style: symbol, grouping, two fraction digits, sign in front.
    let currency = NumberFormatter()
    currency.numberStyle = .currency
    expect(currency.string(from: NSNumber(value: 1234.5)) == "$1,234.50", "Currency style did not format.")
    expect(currency.string(from: NSNumber(value: -12.5)) == "-$12.50", "Currency negative did not format.")

    // Percent style multiplies by 100 and appends the symbol.
    let percent = NumberFormatter()
    percent.numberStyle = .percent
    expect(percent.string(from: NSNumber(value: 0.25)) == "25%", "Percent style did not format.")

    // Parsing strips grouping, currency, and percent decoration.
    expect(currency.number(from: "$1,234.50")?.doubleValue == 1234.5, "Currency parse failed.")
    expect(decimal.number(from: "1,234.5")?.doubleValue == 1234.5, "Decimal parse failed.")
    expect(percent.number(from: "25%")?.doubleValue == 0.25, "Percent parse failed.")
    expect(decimal.number(from: "nonsense") == nil, "Non-numeric parse should be nil.")

    // The base Formatter API formats supported Swift values.
    expect(decimal.string(for: 1234.5) == "1,234.5", "string(for: Double) failed.")
    expect(decimal.string(for: 1000) == "1,000", "string(for: Int) failed.")
    expect(decimal.string(for: "x") == nil, "string(for: unsupported) should be nil.")
}

func testLocaleSystemPatterns() {
    // The current locale is read from the system and exposes usable patterns.
    let locale = Locale.current
    expect(!locale.identifier.isEmpty, "Current locale identifier was empty.")
    expect(!locale.shortDatePattern.isEmpty, "Locale short-date pattern was empty.")
    expect(!locale.timePattern.isEmpty, "Locale time pattern was empty.")

    // A constructed identifier is stored and bridges to the Windows form.
    let constructed = Locale(identifier: "en_US")
    expect(constructed.identifier == "en_US", "Locale did not store its identifier.")

    // A style-based DateFormatter uses the locale for output.
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    let date = Date(timeIntervalSince1970: 1_780_272_000) // 2026-06-01 UTC
    expect(formatter.string(from: date) == "6/1/2026", "Short style did not produce the US short date.")
}

func testDateFormatterPatternsAndRoundTrip() {
    let formatter = DateFormatter()

    // Round-trip a date+time through parse and format.
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    guard let date = formatter.date(from: "2026-06-01 12:34:56") else {
        expect(false, "date(from:) failed to parse a valid date.")
        return
    }
    expect(formatter.string(from: date) == "2026-06-01 12:34:56", "Round-trip date+time mismatch.")

    // Month names.
    formatter.dateFormat = "MMMM d, yyyy"
    expect(formatter.string(from: date) == "June 1, 2026", "Long month name was wrong.")
    formatter.dateFormat = "MMM d"
    expect(formatter.string(from: date) == "Jun 1", "Short month name was wrong.")

    // 12-hour clock with meridiem, both directions.
    formatter.dateFormat = "h:mm a"
    expect(formatter.string(from: date) == "12:34 PM", "12-hour PM format was wrong.")
    guard let morning = formatter.date(from: "9:05 AM") else {
        expect(false, "12-hour parse failed.")
        return
    }
    formatter.dateFormat = "HH:mm"
    expect(formatter.string(from: morning) == "09:05", "AM parse/format was wrong.")

    // The Unix epoch is a Thursday.
    formatter.dateFormat = "yyyy-MM-dd"
    guard let epoch = formatter.date(from: "1970-01-01") else {
        expect(false, "Epoch parse failed.")
        return
    }
    expect(epoch.timeIntervalSince1970 == 0, "Epoch parse was not zero.")
    formatter.dateFormat = "EEEE"
    expect(formatter.string(from: epoch) == "Thursday", "Epoch weekday was wrong.")

    // Style presets drive output when dateFormat is empty.
    let styled = DateFormatter()
    styled.dateStyle = .medium
    styled.timeStyle = .short
    expect(styled.string(from: date) == "Jun 1, 2026 12:34 PM", "Style preset format was wrong.")

    // Quoted literals pass through.
    formatter.dateFormat = "yyyy 'at' HH:mm"
    expect(formatter.string(from: date) == "2026 at 12:34", "Quoted literal was not handled.")

    // A non-matching string parses to nil.
    formatter.dateFormat = "yyyy-MM-dd"
    expect(formatter.date(from: "not a date") == nil, "Bad input should parse to nil.")
}

func testWindowMovableByBackgroundAndPanelKeyAndColorWell() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    // isMovableByWindowBackground marks the content view as a window-drag area.
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 400, 300),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let content = NSView(frame: NSMakeRect(0, 0, 400, 300))
    window.contentView = content
    window.isMovableByWindowBackground = true
    _ = window.realizeNativePeer()

    guard let contentHandle = content.nativeHandle else {
        expect(false, "Content view did not realize.")
        return
    }
    expect(backend.windowDragViewHandles.contains(contentHandle), "Movable-by-background did not mark the content view.")
    window.isMovableByWindowBackground = false
    expect(!backend.windowDragViewHandles.contains(contentHandle), "Clearing movable-by-background did not unmark the view.")

    // A becomesKeyOnlyIfNeeded panel becomes key only with an editable view.
    let barePanel = NSPanel(
        contentRect: NSMakeRect(0, 0, 200, 120),
        styleMask: [.titled, .utilityWindow],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    barePanel.becomesKeyOnlyIfNeeded = true
    let bareContent = NSView(frame: NSMakeRect(0, 0, 200, 120))
    bareContent.addSubview(NSButton(title: "Close", frame: NSMakeRect(10, 10, 80, 28)))
    barePanel.contentView = bareContent
    expect(!barePanel.canBecomeKey, "A button-only key-only panel should not become key.")

    let editPanel = NSPanel(
        contentRect: NSMakeRect(0, 0, 200, 120),
        styleMask: [.titled, .utilityWindow],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    editPanel.becomesKeyOnlyIfNeeded = true
    let editContent = NSView(frame: NSMakeRect(0, 0, 200, 120))
    let editField = NSTextField(string: "", frame: NSMakeRect(10, 10, 160, 24))
    editField.isEditable = true
    editContent.addSubview(editField)
    editPanel.contentView = editContent
    expect(editPanel.canBecomeKey, "A panel hosting an editable field should be able to become key.")

    // Without the flag, panels always can become key.
    editPanel.becomesKeyOnlyIfNeeded = false
    expect(barePanel.canBecomeKey == false, "barePanel still keyed off its own flag.")

    // NSColorWell style and border are configurable.
    let well = NSColorWell(frame: NSMakeRect(0, 0, 44, 24))
    expect(well.colorWellStyle == .default && well.isBordered, "Color well defaults were wrong.")
    well.colorWellStyle = .minimal
    well.isBordered = false
    expect(well.colorWellStyle == .minimal && !well.isBordered, "Color well style/border did not update.")
}

func testDatePickerElementFormats() {
    let backend = InMemoryNativeControlBackend()

    // Date-only defers to the native control's locale short date (nil format).
    let dateOnly = NSDatePicker(frame: NSMakeRect(0, 0, 160, 24))
    let dateHandle = dateOnly.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[dateHandle]?.datePickerFormat == nil, "Date-only picker should use the native locale default.")

    // Time-only uses the locale time pattern.
    let timeOnly = NSDatePicker(frame: NSMakeRect(0, 0, 160, 24))
    timeOnly.datePickerElements = [.hourMinuteSecond]
    let timeHandle = timeOnly.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[timeHandle]?.datePickerFormat == Locale.current.timePattern, "Time picker did not use the locale time pattern.")

    // Both elements combine the locale date and time patterns.
    let both = NSDatePicker(frame: NSMakeRect(0, 0, 200, 24))
    both.datePickerElements = [.yearMonthDay, .hourMinuteSecond]
    let bothHandle = both.realizeNativePeer(in: backend, parent: nil)
    let expectedBoth = "\(Locale.current.shortDatePattern) \(Locale.current.timePattern)"
    expect(backend.records[bothHandle]?.datePickerFormat == expectedBoth, "Date-time picker format was wrong.")

    // Changing elements after realization re-applies the format.
    both.datePickerElements = [.hourMinuteSecond]
    expect(backend.records[bothHandle]?.datePickerFormat == Locale.current.timePattern, "Element change did not re-apply the format.")

    // stringValue formats through the locale (US short date on a US machine).
    let stringPicker = NSDatePicker(date: Date(timeIntervalSince1970: 1_780_272_000), frame: NSMakeRect(0, 0, 200, 24))
    expect(stringPicker.stringValue == "6/1/2026", "Date-only stringValue was not the US short date.")
}

func testButtonImageAndAlternateTitle() {
    let backend = InMemoryNativeControlBackend()

    // A toggle button swaps to its alternate title in the on state.
    let toggle = NSButton(title: "Play", frame: NSMakeRect(0, 0, 100, 28))
    toggle.setButtonType(.switchButton)
    toggle.alternateTitle = "Pause"
    let toggleHandle = toggle.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[toggleHandle]?.text == "Play", "Off-state button did not show the base title.")

    toggle.state = .on
    expect(backend.records[toggleHandle]?.text == "Pause", "On-state button did not swap to the alternate title.")
    toggle.state = .off
    expect(backend.records[toggleHandle]?.text == "Play", "Returning off did not restore the base title.")

    // An image reaches the backend by file path.
    let button = NSButton(title: "Icon", frame: NSMakeRect(0, 0, 80, 28))
    button.image = NSImage(contentsOfFile: "C:/icons/star.png")
    button.imagePosition = .imageLeft
    let handle = button.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[handle]?.buttonImagePath == "C:/icons/star.png", "Button image path did not reach the backend.")

    // Clearing the image removes it.
    button.image = nil
    expect(backend.records[handle]?.buttonImagePath == nil, "Clearing the button image did not reach the backend.")
}

func testTextFieldDelegateEditingCallbacks() {
    let backend = InMemoryNativeControlBackend()
    let field = NSTextField(string: "", frame: NSMakeRect(0, 0, 160, 24))
    field.isEditable = true
    let delegate = RecordingTextFieldDelegate()
    field.delegate = delegate
    let handle = field.realizeNativePeer(in: backend, parent: nil)

    // Focus in → begin editing; native text change → change; focus out → end.
    backend.simulateFocusChange(gained: true, for: handle)
    expect(delegate.began == 1, "controlTextDidBeginEditing did not fire on focus.")

    backend.textChangeActions[handle]?("Choc")
    expect(delegate.changed == 1, "controlTextDidChange did not fire on a native edit.")
    expect(delegate.lastChangedText == "Choc", "Change notification carried the wrong text.")
    expect(field.stringValue == "Choc", "Text field did not adopt the edited text.")

    backend.simulateFocusChange(gained: false, for: handle)
    expect(delegate.ended == 1, "controlTextDidEndEditing did not fire on focus loss.")

    // A non-editable label does not register focus editing callbacks.
    let label = NSTextField(string: "Label", frame: NSMakeRect(0, 0, 80, 20))
    let labelDelegate = RecordingTextFieldDelegate()
    label.delegate = labelDelegate
    let labelHandle = label.realizeNativePeer(in: backend, parent: nil)
    expect(backend.focusChangeActions[labelHandle] == nil, "A label registered an editing focus watch.")
}

func testPopUpButtonTagsAndPullsDown() {
    let popUp = NSPopUpButton(frame: NSMakeRect(0, 0, 120, 24), pullsDown: true)
    expect(popUp.pullsDown, "pullsDown flag was not retained from the initializer.")

    popUp.addItems(withTitles: ["Red", "Green", "Blue"])
    popUp.setTag(10, forItemAt: 0)
    popUp.setTag(20, forItemAt: 1)
    popUp.setTag(30, forItemAt: 2)

    expect(popUp.tag(atIndex: 1) == 20, "Item tag did not read back.")
    expect(popUp.indexOfItem(withTag: 30) == 2, "indexOfItem(withTag:) was wrong.")
    expect(popUp.indexOfItem(withTag: 99) == -1, "Missing tag did not return -1.")

    expect(popUp.selectItem(withTag: 20), "selectItem(withTag:) did not find the tag.")
    expect(popUp.indexOfSelectedItem == 1, "selectItem(withTag:) selected the wrong item.")
    expect(popUp.selectedTag() == 20, "selectedTag() did not match the selection.")
    expect(!popUp.selectItem(withTag: 99), "selectItem(withTag:) accepted a missing tag.")

    // Removing an item keeps titles and tags aligned.
    popUp.removeItem(at: 0)
    expect(popUp.tag(atIndex: 0) == 20, "Tags did not stay aligned with titles after removal.")
    expect(popUp.indexOfItem(withTag: 10) == -1, "Removed item's tag lingered.")
}

func testAlertHelpAndIconConfiguration() {
    let alert = NSAlert()
    alert.messageText = "Delete the file?"
    alert.showsHelp = true
    alert.helpAnchor = "trash-help"
    expect(alert.showsHelp, "showsHelp was not stored.")
    expect(alert.helpAnchor == "trash-help", "helpAnchor was not stored.")

    // A delegate that handles help suppresses the fallback closure.
    final class HelpDelegate: NSAlertDelegate {
        var asked = 0
        func alertShowHelp(_ alert: NSAlert) -> Bool {
            asked += 1
            return true
        }
    }
    let delegate = HelpDelegate()
    alert.delegate = delegate
    expect(alert.delegate?.alertShowHelp(alert) == true, "Alert delegate help routing failed.")
    expect(delegate.asked == 1, "Help delegate was not consulted.")

    // The default delegate implementation reports help unhandled.
    final class PlainDelegate: NSAlertDelegate {}
    expect(PlainDelegate().alertShowHelp(alert) == false, "Default alertShowHelp should be false.")

    // A custom icon is retained for the composed panel.
    alert.icon = NSImage(named: "custom")
    expect(alert.icon != nil, "Custom alert icon was not stored.")
}

func testCommonControlDepthWiresToBackend() {
    let backend = InMemoryNativeControlBackend()

    // Text field: placeholder + alignment reach the peer.
    let field = NSTextField(string: "", frame: NSMakeRect(0, 0, 120, 24))
    field.isEditable = true
    field.placeholderString = "Search"
    field.alignment = .center
    let fieldHandle = field.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[fieldHandle]?.placeholder == "Search", "Placeholder did not reach the backend.")
    expect(backend.records[fieldHandle]?.textAlignment == .center, "Alignment did not reach the backend.")
    field.alignment = .right
    expect(backend.records[fieldHandle]?.textAlignment == .right, "Alignment change did not sync.")

    // Slider: tick marks + vertical + tick snapping.
    let slider = NSSlider(frame: NSMakeRect(0, 0, 120, 24))
    slider.minValue = 0
    slider.maxValue = 10
    slider.numberOfTickMarks = 11
    slider.isVertical = true
    let sliderHandle = slider.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[sliderHandle]?.sliderTickMarkCount == 11, "Tick-mark count did not reach the backend.")
    expect(backend.records[sliderHandle]?.sliderIsVertical == true, "Vertical orientation did not reach the backend.")
    expect(slider.closestTickMarkValue(toValue: 4.4) == 4, "Tick snapping picked the wrong value.")

    // Combo box: visible items + forward completion.
    let combo = NSComboBox(frame: NSMakeRect(0, 0, 140, 24))
    combo.addItems(withObjectValues: ["Apple", "Apricot", "Banana"])
    combo.numberOfVisibleItems = 8
    combo.completes = true
    let comboHandle = combo.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[comboHandle]?.comboBoxVisibleItems == 8, "Visible-item count did not reach the backend.")
    expect(combo.completedString(forPrefix: "ap") == "Apple", "Completion did not find the first prefix match.")
    expect(combo.completedString(forPrefix: "ban") == "Banana", "Completion missed a later item.")
    expect(combo.completedString(forPrefix: "z") == nil, "Completion matched a non-prefix.")

    // Button: key equivalent fires the action.
    let button = NSButton(title: "OK", frame: NSMakeRect(0, 0, 80, 28))
    button.keyEquivalent = "\r"
    var clicks = 0
    button.onAction = { _ in clicks += 1 }
    _ = button.realizeNativePeer(in: backend, parent: nil)
    let returnEvent = NSEvent(type: .keyDown, locationInWindow: NSMakePoint(0, 0), keyCode: 0x0d, characters: "\r", modifierFlags: [])
    expect(button.performKeyEquivalent(with: returnEvent), "Return key equivalent was not recognized.")
    expect(clicks == 1, "Key equivalent did not fire the action.")
    let otherEvent = NSEvent(type: .keyDown, locationInWindow: NSMakePoint(0, 0), keyCode: 0x41, characters: "a", modifierFlags: [])
    expect(!button.performKeyEquivalent(with: otherEvent), "Unrelated key wrongly matched the equivalent.")

    // Level indicator: warning/critical recolor the bar.
    let level = NSLevelIndicator(frame: NSMakeRect(0, 0, 120, 20))
    level.minValue = 0
    level.maxValue = 100
    level.warningValue = 60
    level.criticalValue = 85
    let levelHandle = level.realizeNativePeer(in: backend, parent: nil)
    level.doubleValue = 40
    expect(backend.records[levelHandle]?.progressBarColor == nil, "Below-threshold bar was colored.")
    level.doubleValue = 70
    expect(backend.records[levelHandle]?.progressBarColor != nil, "Warning threshold did not color the bar.")
    level.doubleValue = 95
    expect(backend.records[levelHandle]?.progressBarColor == .red, "Critical threshold did not turn the bar red.")
}

func testSegmentedControlKeyboardSelection() {
    let segmented = NSSegmentedControl(labels: ["One", "Two", "Three"], frame: NSMakeRect(0, 0, 180, 24))
    segmented.trackingMode = .selectOne
    segmented.selectedSegment = 0
    var actions = 0
    segmented.onAction = { _ in actions += 1 }

    let right = NSEvent(type: .keyDown, locationInWindow: NSMakePoint(0, 0), keyCode: 0x27, characters: nil, modifierFlags: [])
    segmented.keyDown(with: right)
    expect(segmented.selectedSegment == 1, "Right arrow did not advance the segment.")
    segmented.keyDown(with: right)
    expect(segmented.selectedSegment == 2, "Right arrow did not keep advancing.")
    segmented.keyDown(with: right)
    expect(segmented.selectedSegment == 2, "Right arrow moved past the last segment.")

    let left = NSEvent(type: .keyDown, locationInWindow: NSMakePoint(0, 0), keyCode: 0x25, characters: nil, modifierFlags: [])
    segmented.keyDown(with: left)
    expect(segmented.selectedSegment == 1, "Left arrow did not move back.")
    expect(actions == 3, "Keyboard selection did not send actions.")

    // A disabled segment is skipped.
    segmented.setEnabled(false, forSegment: 0)
    segmented.keyDown(with: left)
    expect(segmented.selectedSegment == 1, "Left arrow did not skip the disabled first segment.")
}

func testWindowSizeLimitsAndPopoverDismiss() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    // Window content size limits reach the backend.
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 400, 300),
        styleMask: [.titled, .resizable],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    window.contentMinSize = NSMakeSize(320, 240)
    window.contentMaxSize = NSMakeSize(800, 600)
    let windowHandle = window.realizeNativePeer()
    expect(backend.records[windowHandle]?.minContentSize == NSMakeSize(320, 240), "Min content size did not reach the backend.")
    expect(backend.records[windowHandle]?.maxContentSize == NSMakeSize(800, 600), "Max content size did not reach the backend.")

    // Transient popover registers an outside-click dismiss and closes on it.
    let anchor = NSView(frame: NSMakeRect(10, 10, 40, 20))
    window.contentView = NSView(frame: NSMakeRect(0, 0, 400, 300))
    window.contentView?.addSubview(anchor)
    window.makeKeyAndOrderFront(nil)

    let controller = NSViewController()
    controller.view = NSView(frame: NSMakeRect(0, 0, 200, 120))
    let popover = NSPopover()
    popover.behavior = .transient
    popover.contentViewController = controller
    popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .maxY)

    expect(popover.isShown, "Popover did not show.")
    expect(backend.outsideClickDismissHandle != nil, "Transient popover did not register an outside-click watch.")

    backend.simulateOutsideClick()
    expect(!popover.isShown, "Outside click did not dismiss the transient popover.")
    expect(backend.outsideClickDismissHandle == nil, "Dismiss watch was not torn down after closing.")
}

func testFontTraitsWeightsAndDescriptor() {
    // Italic and the extended weight scale round-trip through NSFont.
    let base = NSFont(name: "Georgia", size: 14)
    expect(!base.italic && base.weight == .regular, "Default font carried unexpected traits.")
    expect(base.withItalic(true).italic, "withItalic did not set the italic trait.")
    expect(base.withWeight(.semibold).weight == .semibold, "withWeight did not change the weight.")
    expect(base.withWeight(.semibold).isBold, "Semibold did not report as bold.")
    expect(!base.withWeight(.light).isBold, "Light incorrectly reported as bold.")
    expect(NSFont.Weight.closest(toLogFontWeight: 620) == .semibold, "Closest weight mapping was wrong.")
    expect(NSFont.Weight.allCases.count == 9, "Weight scale is not the standard nine steps.")

    // Descriptor captures and reconstructs symbolic traits.
    let descriptor = NSFont(name: "Consolas", size: 12, weight: .bold, italic: true).fontDescriptor
    expect(descriptor.symbolicTraits.contains(.bold), "Descriptor dropped the bold trait.")
    expect(descriptor.symbolicTraits.contains(.italic), "Descriptor dropped the italic trait.")
    let rebuilt = NSFont(descriptor: descriptor, size: 0)
    expect(rebuilt.fontName == "Consolas" && rebuilt.pointSize == 12, "Descriptor lost family or size.")
    expect(rebuilt.isBold && rebuilt.italic, "Descriptor did not rebuild the traits.")
    let plainDescriptor = NSFontDescriptor(name: "Arial", size: 10)
    let withItalic = plainDescriptor.withSymbolicTraits(.italic)
    expect(withItalic.symbolicTraits.contains(.italic), "withSymbolicTraits did not add the trait.")

    // NSFontManager trait conversion toggles bold and italic.
    let manager = NSFontManager.shared
    let bolded = manager.convert(base, toHaveTrait: .bold)
    expect(bolded.weight == .bold, "toHaveTrait: .bold did not bold the font.")
    let italicized = manager.convert(bolded, toHaveTrait: .italic)
    expect(italicized.italic && italicized.weight == .bold, "toHaveTrait: .italic dropped the existing bold.")
    let unbolded = manager.convert(italicized, toHaveTrait: .unbold)
    expect(unbolded.weight == .regular && unbolded.italic, ".unbold did not clear bold while keeping italic.")
    expect(manager.traits(of: italicized) == [.bold, .italic], "traits(of:) did not report both traits.")

    // Italic reaches the native rich-text peer as a character format.
    let backend = InMemoryNativeControlBackend()
    let textView = NSTextView(frame: NSMakeRect(0, 0, 200, 80))
    textView.isRichText = true
    textView.string = "styled"
    let handle = textView.realizeNativePeer(in: backend, parent: nil)
    textView.setFont(NSFont(name: "Georgia", size: 13, weight: .bold, italic: true), range: NSMakeRange(0, 6))
    let format = backend.records[handle]?.textRangeFormats.last
    expect(format?.font?.italic == true, "Italic font did not reach the native formatting.")
    expect(format?.font?.weight == .bold, "Bold-italic font lost its weight.")
}

func testMutableAttributedStringRunsAndEnumeration() {
    let text = NSMutableAttributedString(string: "Hello World")
    expect(text.length == 11, "Length did not count UTF-16 units.")
    expect(text.string == "Hello World", "String contents were lost.")

    // Attributes apply per range and report effective ranges.
    let boldFont = NSFont.boldSystemFont(ofSize: 14)
    text.addAttribute(.font, value: boldFont, range: NSMakeRange(0, 5))
    text.addAttribute(.foregroundColor, value: NSColor.red, range: NSMakeRange(6, 5))
    text.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSMakeRange(0, 11))

    var effective = NSRange(location: 0, length: 0)
    withUnsafeMutablePointer(to: &effective) { pointer in
        expect((text.attribute(.font, at: 2, effectiveRange: pointer) as? NSFont) == boldFont, "Font attribute did not read back.")
    }
    expect(effective == NSMakeRange(0, 5), "Effective range did not match the font run.")
    expect(text.attribute(.font, at: 8, effectiveRange: nil) == nil, "Font leaked past its range.")
    expect((text.attribute(.underlineStyle, at: 8, effectiveRange: nil) as? Int) == 1, "Underline did not cover the whole string.")

    // Enumeration walks the distinct runs in order.
    var enumeratedRanges: [NSRange] = []
    text.enumerateAttributes(in: NSMakeRange(0, text.length)) { _, range, _ in
        enumeratedRanges.append(range)
    }
    expect(enumeratedRanges == [NSMakeRange(0, 5), NSMakeRange(5, 1), NSMakeRange(6, 5)], "Enumeration did not yield the attribute runs.")

    // setAttributes replaces; removeAttribute deletes one key.
    text.setAttributes([.foregroundColor: NSColor.blue], range: NSMakeRange(0, 5))
    expect(text.attribute(.font, at: 2, effectiveRange: nil) == nil, "setAttributes kept a replaced attribute.")
    text.removeAttribute(.foregroundColor, range: NSMakeRange(0, 5))
    expect(text.attribute(.foregroundColor, at: 2, effectiveRange: nil) == nil, "removeAttribute left the attribute behind.")

    // Replacement text inherits the attributes at the replaced location.
    let styled = NSMutableAttributedString(string: "abc", attributes: [.foregroundColor: NSColor.green])
    styled.replaceCharacters(in: NSMakeRange(1, 1), with: "XY")
    expect(styled.string == "aXYc", "replaceCharacters mangled the text.")
    expect((styled.attribute(.foregroundColor, at: 1, effectiveRange: nil) as? NSColor) == .green, "Replacement did not inherit attributes.")

    // Append, insert, and delete keep runs consistent.
    styled.append(NSAttributedString(string: "!", attributes: [.foregroundColor: NSColor.red]))
    expect(styled.string == "aXYc!", "append lost text.")
    expect((styled.attribute(.foregroundColor, at: 4, effectiveRange: nil) as? NSColor) == .red, "append lost its attributes.")
    styled.insert(NSAttributedString(string: ">>"), at: 0)
    expect(styled.string == ">>aXYc!", "insert lost text.")
    styled.deleteCharacters(in: NSMakeRange(0, 2))
    expect(styled.string == "aXYc!", "deleteCharacters removed the wrong range.")

    // attributedSubstring carries the overlapping runs.
    let substring = styled.attributedSubstring(from: NSMakeRange(3, 2))
    expect(substring.string == "c!", "attributedSubstring took the wrong text.")
    expect((substring.attribute(.foregroundColor, at: 1, effectiveRange: nil) as? NSColor) == .red, "attributedSubstring dropped run attributes.")
}

func testTextStorageAppliesRunsToTextView() {
    let backend = InMemoryNativeControlBackend()
    let textView = NSTextView(frame: NSMakeRect(0, 0, 300, 100))
    textView.isRichText = true
    textView.string = "plain"
    let handle = textView.realizeNativePeer(in: backend, parent: nil)

    guard let storage = textView.textStorage else {
        expect(false, "Text view did not vend a text storage.")
        return
    }
    expect(storage.string == "plain", "Text storage was not seeded with the view's text.")

    // A batched edit applies once: new text plus its attribute runs.
    storage.beginEditing()
    storage.replaceCharacters(in: NSMakeRange(0, storage.length), with: "Styled note")
    storage.addAttribute(.font, value: NSFont(name: "Georgia", size: 16, weight: .bold), range: NSMakeRange(0, 6))
    storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSMakeRange(7, 4))
    storage.endEditing()

    expect(textView.string == "Styled note", "Storage edits did not update the view text.")
    let formats = backend.records[handle]?.textRangeFormats ?? []
    expect(formats.contains { $0.font?.fontName == "Georgia" && $0.location == 0 && $0.length == 6 }, "Font run did not reach the native peer.")
    expect(formats.contains { $0.underline == true && $0.location == 7 && $0.length == 4 }, "Underline run did not reach the native peer.")

    // Native edits sync the storage's plain text.
    backend.textChangeActions[handle]?("typed text")
    expect(storage.string == "typed text", "Native editing did not sync the text storage.")
}

func testRTFWriterEmitsTablesRunsAndEscapes() {
    let text = NSMutableAttributedString(string: "Bold red — ok")
    text.addAttribute(.font, value: NSFont(name: "Georgia", size: 14, weight: .bold), range: NSMakeRange(0, 4))
    text.addAttribute(.foregroundColor, value: NSColor.red, range: NSMakeRange(5, 3))
    text.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSMakeRange(11, 2))

    guard let data = text.rtf(from: NSMakeRange(0, text.length)) else {
        expect(false, "RTF writer returned nil.")
        return
    }
    let rtf = String(decoding: Array(data), as: UTF8.self)

    expect(rtf.hasPrefix("{\\rtf1\\ansi\\deff0"), "RTF header is missing.")
    expect(rtf.contains("Georgia;"), "Font table is missing the run font.")
    expect(rtf.contains("\\red255\\green0\\blue0;"), "Color table is missing the run color.")
    expect(rtf.contains("\\b Bold"), "Bold run controls are missing.")
    expect(rtf.contains("\\cf1 red"), "Color run controls are missing.")
    expect(rtf.contains("\\strike ok"), "Strikethrough run controls are missing.")
    expect(rtf.contains("\\u8212?"), "Non-ASCII characters were not escaped.")
    expect(rtf.hasSuffix("}"), "RTF is not closed.")

    // A rich text view copy stages RTF alongside the plain string.
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    let textView = NSTextView(frame: NSMakeRect(0, 0, 200, 80))
    textView.isRichText = true
    _ = textView.realizeNativePeer(in: backend, parent: nil)
    textView.textStorage?.replaceCharacters(in: NSMakeRange(0, 0), with: "Rich copy")
    textView.textStorage?.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 13), range: NSMakeRange(0, 4))
    textView.selectedRange = NSMakeRange(0, 9)
    textView.copy(nil)

    expect(NSPasteboard.general.string(forType: .string) == "Rich copy", "Rich copy did not stage the plain string.")
    expect(NSPasteboard.general.data(forType: .rtf) != nil, "Rich copy did not stage RTF data.")
}

func testPasteboardAndTextViewClipboardActions() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    // The general pasteboard reads and writes the backend clipboard.
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    expect(pasteboard.string(forType: .string) == nil, "Cleared pasteboard still returned a string.")
    expect(pasteboard.types == nil, "Cleared pasteboard still reported types.")

    let countBeforeWrite = pasteboard.changeCount
    expect(pasteboard.setString("Chocolate", forType: .string), "Writing a string was rejected.")
    expect(pasteboard.string(forType: .string) == "Chocolate", "Written string did not read back.")
    expect(pasteboard.types == [.string], "String type was not reported after writing.")
    expect(pasteboard.changeCount > countBeforeWrite, "Writing did not advance the change count.")
    expect(!pasteboard.setString("x", forType: NSPasteboard.PasteboardType(rawValue: "public.png")), "An unsupported type was accepted.")

    // declareTypes clears, matching the old AppKit contract.
    pasteboard.declareTypes([.string], owner: nil)
    expect(pasteboard.string(forType: .string) == nil, "declareTypes did not clear the pasteboard.")

    // One logical copy can stage several representations together.
    pasteboard.clearContents()
    let rtfBytes = Data(Array("{\\rtf1 Hi}".utf8))
    let pngBytes = Data([0x89, 0x50, 0x4e, 0x47])
    expect(pasteboard.setString("Hi", forType: .string), "Staged string write was rejected.")
    expect(pasteboard.setData(rtfBytes, forType: .rtf), "RTF data write was rejected.")
    expect(pasteboard.setData(pngBytes, forType: .png), "PNG data write was rejected.")
    expect(pasteboard.string(forType: .string) == "Hi", "Staged string was lost by later data writes.")
    expect(pasteboard.data(forType: .rtf) == rtfBytes, "RTF data did not read back.")
    expect(pasteboard.data(forType: .png) == pngBytes, "PNG data did not read back.")
    expect(pasteboard.types == [.string, .rtf, .png], "Combined representations were not all reported.")
    expect(pasteboard.data(forType: .string) == nil, "data(forType:) accepted the plain-text type.")

    // Clearing drops every staged representation.
    pasteboard.clearContents()
    expect(pasteboard.data(forType: .rtf) == nil, "clearContents left RTF data behind.")
    expect(pasteboard.types == nil, "clearContents left types behind.")

    // Text view copy/cut/paste run over the general pasteboard.
    let textView = NSTextView(frame: NSMakeRect(0, 0, 300, 100))
    textView.string = "Hello World"
    _ = textView.realizeNativePeer(in: backend, parent: nil)

    textView.selectedRange = NSMakeRange(0, 5)
    textView.copy(nil)
    expect(pasteboard.string(forType: .string) == "Hello", "Copy did not place the selection on the pasteboard.")
    expect(textView.string == "Hello World", "Copy changed the text.")

    textView.selectedRange = NSMakeRange(6, 5)
    textView.cut(nil)
    expect(pasteboard.string(forType: .string) == "World", "Cut did not place the selection on the pasteboard.")
    expect(textView.string == "Hello ", "Cut did not delete the selection.")

    textView.selectedRange = NSMakeRange(0, 0)
    textView.paste(nil)
    expect(textView.string == "WorldHello ", "Paste did not insert at the selection.")

    // Paste replaces a non-empty selection.
    textView.selectedRange = NSMakeRange(0, 5)
    textView.paste(nil)
    expect(textView.string == "WorldHello ", "Paste over a selection did not replace it.")

    // selectAll covers the whole text; read-only views refuse cut/paste.
    textView.selectAll(nil)
    expect(textView.selectedRange == NSMakeRange(0, textView.string.utf16.count), "selectAll did not select the whole text.")
    textView.isEditable = false
    textView.cut(nil)
    expect(textView.string == "WorldHello ", "Cut modified a read-only text view.")
}

func testRichTextViewAppliesRangeFormatting() {
    let backend = InMemoryNativeControlBackend()
    let manager = NSFontManager.shared
    defer {
        manager.selectedFont = nil
    }

    let textView = NSTextView(frame: NSMakeRect(0, 0, 300, 120))
    textView.isRichText = true
    textView.string = "Rich text attributes"
    let handle = textView.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.isRichText == true, "Rich text view did not request a rich-edit peer.")

    // Per-range font and color formatting reach the backend.
    let rangeFont = NSFont(name: "Georgia", size: 18, weight: .bold)
    textView.setFont(rangeFont, range: NSMakeRange(0, 4))
    textView.setTextColor(.red, range: NSMakeRange(5, 4))

    let formats = backend.records[handle]?.textRangeFormats ?? []
    expect(formats.count == 2, "Range formatting did not reach the backend.")
    expect(formats.first?.font == rangeFont, "Range font was not recorded.")
    expect(formats.first?.location == 0 && formats.first?.length == 4, "Font range was not recorded.")
    expect(formats.last?.color == .red, "Range color was not recorded.")
    expect(formats.last?.location == 5 && formats.last?.length == 4, "Color range was not recorded.")

    // changeFont converts the selection when one exists.
    manager.selectedFont = NSFont(name: "Consolas", size: 12)
    textView.selectedRange = NSMakeRange(0, 9)
    textView.changeFont(nil)
    let selectionFormat = backend.records[handle]?.textRangeFormats.last
    expect(selectionFormat?.font?.fontName == "Consolas", "changeFont did not format the selected range.")
    expect(selectionFormat?.location == 0 && selectionFormat?.length == 9, "changeFont did not use the selection range.")
    expect(textView.font == nil, "Selection-scoped changeFont overwrote the whole-view font.")

    // Plain text views still convert the whole view's font.
    let plain = NSTextView(frame: NSMakeRect(0, 0, 100, 50))
    _ = plain.realizeNativePeer(in: backend, parent: nil)
    plain.changeFont(nil)
    expect(plain.font?.fontName == "Consolas", "Plain-text changeFont did not convert the view font.")
    expect(backend.records[handle]?.textRangeFormats.count == 3, "Plain-text changeFont leaked range formatting.")
}

func testScrollViewWheelScrollingMovesContent() {
    let backend = InMemoryNativeControlBackend()
    let scrollView = NSScrollView(frame: NSMakeRect(0, 0, 200, 100))
    scrollView.hasVerticalScroller = true
    scrollView.hasHorizontalScroller = true
    scrollView.documentView = NSView(frame: NSMakeRect(0, 0, 600, 400))
    let handle = scrollView.realizeNativePeer(in: backend, parent: nil)

    // One wheel notch down scrolls three lines of the default line scroll.
    scrollView.scrollWheel(with: NSEvent(type: .scrollWheel, locationInWindow: NSMakePoint(10, 10), scrollingDeltaY: -1))
    expect(scrollView.contentView.boundsOrigin.y == 48, "Wheel notch did not scroll three default lines.")
    expect(backend.records[handle]?.scrollViewContentOffset.y == 48, "Wheel scroll did not sync the native scrollbar offset.")

    // Scrolling above the top clamps at zero.
    scrollView.scrollWheel(with: NSEvent(type: .scrollWheel, locationInWindow: NSMakePoint(10, 10), scrollingDeltaY: 5))
    expect(scrollView.contentView.boundsOrigin.y == 0, "Wheel scroll did not clamp at the document top.")

    // Shift converts a vertical wheel into horizontal scrolling.
    scrollView.scrollWheel(with: NSEvent(type: .scrollWheel, locationInWindow: NSMakePoint(10, 10), modifierFlags: [.shift], scrollingDeltaY: -1))
    expect(scrollView.contentView.boundsOrigin.x == 48, "Shift-wheel did not scroll horizontally.")
    expect(scrollView.contentView.boundsOrigin.y == 0, "Shift-wheel still scrolled vertically.")

    // Horizontal wheel deltas scroll horizontally on their own.
    scrollView.scrollWheel(with: NSEvent(type: .scrollWheel, locationInWindow: NSMakePoint(10, 10), scrollingDeltaX: -1))
    expect(scrollView.contentView.boundsOrigin.x == 96, "Horizontal wheel delta did not scroll horizontally.")

    // Line scroll distances are adjustable.
    scrollView.lineScroll = 8
    scrollView.scrollWheel(with: NSEvent(type: .scrollWheel, locationInWindow: NSMakePoint(10, 10), scrollingDeltaY: -1))
    expect(scrollView.contentView.boundsOrigin.y == 24, "Adjusted line scroll was not honored.")

    // A large scroll clamps at the document end.
    scrollView.scrollWheel(with: NSEvent(type: .scrollWheel, locationInWindow: NSMakePoint(10, 10), scrollingDeltaY: -100))
    expect(scrollView.contentView.boundsOrigin.y == 300, "Wheel scroll did not clamp at the document bottom.")
}

func testScrollViewMagnificationScalesGeometryAndDrawing() {
    let backend = InMemoryNativeControlBackend()
    let scrollView = NSScrollView(frame: NSMakeRect(0, 0, 200, 100))
    scrollView.hasVerticalScroller = true
    let document = NSView(frame: NSMakeRect(0, 0, 400, 300))
    scrollView.documentView = document
    let handle = scrollView.realizeNativePeer(in: backend, parent: nil)
    guard let documentHandle = document.nativeHandle else {
        expect(false, "Document view did not realize a native peer.")
        return
    }

    scrollView.setMagnification(2, centeredAt: NSMakePoint(0, 0))

    expect(scrollView.magnification == 2, "setMagnification did not update the magnification.")
    expect(backend.records[documentHandle]?.contentScale == 2, "Magnification did not reach the document view's content scale.")
    expect(backend.records[documentHandle]?.frame.size == NSMakeSize(800, 600), "Magnification did not scale the document's native frame.")
    expect(backend.records[handle]?.scrollViewContentSize == NSMakeSize(800, 600), "Scrollbar content size did not scale with magnification.")
    expect(scrollView.contentView.documentVisibleRect.size == NSMakeSize(100, 50), "Visible document range did not shrink under magnification.")

    // Scrolling clamps to the magnified extent and syncs scaled pixels.
    scrollView.scroll(NSMakePoint(1_000, 1_000))
    expect(scrollView.contentView.boundsOrigin == NSMakePoint(300, 250), "Magnified scroll did not clamp to the reduced document range.")
    expect(backend.records[handle]?.scrollViewContentOffset == NSMakePoint(600, 500), "Native offset did not scale with magnification.")

    // Wheel distances stay constant on screen: one notch is 48 screen
    // points, which is 24 document units at 2x.
    scrollView.scroll(NSMakePoint(0, 0))
    scrollView.scrollWheel(with: NSEvent(type: .scrollWheel, locationInWindow: NSMakePoint(10, 10), scrollingDeltaY: -1))
    expect(scrollView.contentView.boundsOrigin.y == 24, "Wheel scroll distance did not adjust for magnification.")

    // The magnification range clamps, and 1x removes the content scale.
    scrollView.setMagnification(100, centeredAt: NSMakePoint(0, 0))
    expect(scrollView.magnification == scrollView.maxMagnification, "Magnification did not clamp to maxMagnification.")
    scrollView.setMagnification(1, centeredAt: NSMakePoint(0, 0))
    expect(backend.records[documentHandle]?.contentScale == 1, "Returning to 1x did not clear the content scale.")
    expect(backend.records[documentHandle]?.frame.size == NSMakeSize(400, 300), "Returning to 1x did not restore the native frame.")

    // magnify(toFit:) picks the scale that fits the rectangle.
    scrollView.magnify(toFit: NSMakeRect(0, 0, 100, 50))
    expect(scrollView.magnification == 2, "magnify(toFit:) did not compute the fitting magnification.")
}

func testFloatingPanelStateReachesBackend() {
    let backend = InMemoryNativeControlBackend()
    let panel = NSPanel(
        contentRect: NSMakeRect(100, 100, 200, 150),
        styleMask: [.titled, .closable, .utilityWindow],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    panel.isFloatingPanel = true
    panel.hidesOnDeactivate = true
    panel.orderFrontRegardless()

    guard let handle = panel.nativeHandle else {
        expect(false, "Panel did not realize a native window.")
        return
    }

    expect(backend.records[handle]?.kind == "window", "Panel did not use a window peer.")
    expect(backend.records[handle]?.windowLevel == NSWindow.Level.floating.rawValue, "Floating panel level was not applied at realization.")
    expect(backend.records[handle]?.hidesOnDeactivate == true, "hidesOnDeactivate was not applied at realization.")
    expect(backend.records[handle]?.isHidden == false, "orderFrontRegardless did not show the panel.")

    // Level changes after realization flow through immediately.
    panel.isFloatingPanel = false
    expect(backend.records[handle]?.windowLevel == NSWindow.Level.normal.rawValue, "Clearing isFloatingPanel did not return the level to normal.")
    panel.level = .floating
    expect(backend.records[handle]?.windowLevel == NSWindow.Level.floating.rawValue, "Setting level directly did not reach the backend.")

    // orderOut hides without destroying; orderFront shows the same peer again.
    panel.orderOut(nil)
    expect(backend.records[handle]?.isHidden == true, "orderOut did not hide the panel.")
    expect(panel.nativeHandle != nil, "orderOut destroyed the panel peer.")
    panel.orderFront(nil)
    expect(backend.records[handle]?.isHidden == false, "orderFront did not reshow the hidden panel.")

    // Panels never become the application's main window.
    panel.makeMain()
    expect(NSApplication.shared.mainWindow !== panel, "A panel became the application's main window.")
}

func testColorPanelFloatsAndAppliesColorsLive() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    // A document window whose first responder listens for changeColor.
    let documentWindow = NSWindow(
        contentRect: NSMakeRect(50, 50, 400, 300),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let recorder = ColorChangeRecordingView(frame: NSMakeRect(0, 0, 400, 300))
    documentWindow.contentView = recorder
    documentWindow.makeKeyAndOrderFront(nil)
    documentWindow.makeFirstResponder(recorder)

    let panel = NSColorPanel(nativeBackend: backend)
    panel.color = .red
    var changedColors: [NSColor] = []
    panel.winColorDidChange = { changedColors.append($0) }

    panel.makeKeyAndOrderFront(nil)
    guard let handle = panel.nativeHandle else {
        expect(false, "Color panel did not realize a native window.")
        return
    }

    expect(backend.records[handle]?.windowLevel == NSWindow.Level.floating.rawValue, "Color panel is not a floating window.")
    expect(backend.records[handle]?.hidesOnDeactivate == true, "Color panel does not hide on deactivate.")
    expect(backend.records[handle]?.isHidden == false, "Presented color panel is hidden.")
    expect(NSApplication.shared.mainWindow === documentWindow, "The color panel displaced the main window.")

    // Dragging a component slider recomposes the color and applies it live.
    // Programmatic color sets also dispatch, so start observing here.
    recorder.receivedColors.removeAll()
    let sliderHandles = backend.records.filter { $0.value.kind == "slider" }.keys.sorted { $0.rawValue < $1.rawValue }
    expect(sliderHandles.count == 3, "Color panel did not realize three component sliders.")
    if sliderHandles.count == 3 {
        backend.setSliderValue(255, for: sliderHandles[2])
        backend.actions[sliderHandles[2]]?()
    }

    let magenta = NSColor(calibratedRed: 1, green: 0, blue: 1, alpha: 1)
    expect(panel.color == magenta, "Slider change did not recompose the panel color.")
    expect(changedColors == [magenta], "Slider change did not fire the change closure.")
    expect(recorder.receivedColors == [magenta], "changeColor did not reach the document window's first responder.")

    // A title-bar close hides the shared-style panel instead of destroying it.
    let closed = backend.requestWindowClose(handle)
    expect(!closed, "Title-bar close destroyed the color panel instead of hiding it.")
    expect(backend.records[handle]?.isHidden == true, "Close request did not hide the color panel.")
    expect(panel.nativeHandle != nil, "Close request destroyed the color panel peer.")
    expect(NSApplication.shared.keyWindow === documentWindow, "Hiding the key panel did not return key status to the document window.")

    panel.makeKeyAndOrderFront(nil)
    expect(backend.records[handle]?.isHidden == false, "Re-presenting did not show the hidden color panel.")

    // The shared panel feeds the active color well live and lets go on deactivate.
    let colorWell = NSColorWell(frame: NSMakeRect(0, 0, 32, 24))
    colorWell.color = .green
    colorWell.activate(true)
    expect(NSColorPanel.shared.color == .green, "Activating a color well did not seed the shared panel color.")
    NSColorPanel.shared.color = .white
    expect(colorWell.color == .white, "Shared panel color did not flow into the active color well.")
    colorWell.deactivate()
    NSColorPanel.shared.color = .black
    expect(colorWell.color == .white, "Deactivated color well still received panel colors.")
}

func testFontPanelLiveApplyThroughFontManager() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    let manager = NSFontManager.shared
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        manager.winFontDidChange = nil
        manager.target = nil
    }

    // A document window whose first responder converts changeFont sends.
    let documentWindow = NSWindow(
        contentRect: NSMakeRect(50, 50, 400, 300),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let recorder = FontChangeRecordingView(frame: NSMakeRect(0, 0, 400, 300))
    documentWindow.contentView = recorder
    documentWindow.makeKeyAndOrderFront(nil)
    documentWindow.makeFirstResponder(recorder)

    let seedFont = NSFont(name: "Georgia", size: 14)
    manager.selectedFont = seedFont
    var changedFonts: [NSFont] = []
    manager.winFontDidChange = { changedFonts.append($0) }

    let panel = NSFontPanel(nativeBackend: backend)
    panel.setPanelFont(seedFont, isMultiple: false)
    expect(panel.winSelectedFont == seedFont, "setPanelFont did not seed the panel selection.")

    panel.makeKeyAndOrderFront(nil)
    guard let handle = panel.nativeHandle else {
        expect(false, "Font panel did not realize a native window.")
        return
    }

    expect(backend.records[handle]?.windowLevel == NSWindow.Level.floating.rawValue, "Font panel is not a floating window.")
    expect(backend.records[handle]?.hidesOnDeactivate == true, "Font panel does not hide on deactivate.")

    // The family list shows the installed families from the backend.
    let families = backend.fontFamilyNames()
    guard let tableHandle = backend.records.first(where: { $0.value.kind == "tableView" })?.key else {
        expect(false, "Font panel did not realize a family table.")
        return
    }
    expect(backend.records[tableHandle]?.tableRows.count == families.count, "Family table does not list the installed families.")

    // Selecting a family applies the font live through the manager.
    guard let consolasRow = families.firstIndex(of: "Consolas") else {
        expect(false, "Deterministic family list is missing Consolas.")
        return
    }
    backend.setTableSelectedRow(consolasRow, for: tableHandle)
    backend.actions[tableHandle]?()

    expect(manager.selectedFont?.fontName == "Consolas", "Family selection did not update the manager's selected font.")
    expect(panel.winSelectedFont?.fontName == "Consolas", "Family selection did not update the panel selection.")
    expect(changedFonts.count == 1, "Family selection did not fire the manager change closure.")
    expect(recorder.receivedFonts.count == 1, "changeFont did not reach the document window's first responder.")
    expect(recorder.receivedFonts.first?.fontName == "Consolas", "convert(_:) did not return the live panel selection.")

    // Editing the size combo re-applies with the new point size.
    let comboHandle = backend.records.first { $0.value.kind == "comboBox" }?.key
    expect(comboHandle != nil, "Font panel did not realize a size combo box.")
    if let comboHandle {
        backend.textChangeActions[comboHandle]?("24")
        expect(manager.selectedFont?.pointSize == 24, "Size change did not update the selected font size.")
        expect(recorder.receivedFonts.count == 2, "Size change did not send changeFont again.")
    }

    // NSTextView applies panel fonts to its whole plain-text contents.
    let textView = NSTextView(frame: NSMakeRect(0, 0, 200, 100))
    textView.changeFont(manager)
    expect(textView.font == manager.selectedFont, "NSTextView.changeFont did not adopt the panel selection.")

    // A title-bar close hides the shared-style panel instead of destroying it.
    let closed = backend.requestWindowClose(handle)
    expect(!closed, "Title-bar close destroyed the font panel instead of hiding it.")
    expect(backend.records[handle]?.isHidden == true, "Close request did not hide the font panel.")
}

final class RealizationRecordingView: NSView {
    var didRealize = false

    override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        didRealize = true
        return super.realizeNativePeer(in: backend, parent: parent)
    }
}

func testAlertAccessoryViewJoinsComposedPanel() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        clearApplicationWindows()
    }

    let alert = NSAlert()
    alert.messageText = "Accessory host"
    alert.addButton(withTitle: "OK")
    let accessory = RealizationRecordingView(frame: NSMakeRect(0, 0, 200, 30))
    alert.accessoryView = accessory
    backend.nextModalResponseCode = NSApplication.ModalResponse.alertFirstButtonReturn.rawValue

    let response = alert.runModal()

    expect(response == .alertFirstButtonReturn, "Accessory alert did not return the scripted button response.")
    expect(backend.modalSessions.count == 1, "Accessory alert did not run exactly one modal session.")
    // The panel and its content view deallocate when runModal returns, so the
    // weak superview link cannot be asserted here; realization proves the
    // accessory joined the composed panel hierarchy.
    expect(accessory.didRealize, "Accessory view was never realized into the composed panel.")
    expect(accessory.frame.origin.x == 80, "Accessory view was not indented to the alert text column.")
}

final class RecordingMenuValidator: NSMenuItemValidation {
    var allowed = false
    var validatedTitles: [String] = []

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        validatedTitles.append(menuItem.title)
        return allowed
    }
}

func testSavePanelSheetPassesAnchorFrame() {
    clearApplicationWindows()

    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        clearApplicationWindows()
    }

    let parent = NSWindow(
        contentRect: NSMakeRect(120, 80, 700, 500),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let panel = NSSavePanel.savePanel()
    backend.scriptedFileDialogPaths = [["C:\\Temp\\anchored.txt"]]

    var received: NSApplication.ModalResponse?
    panel.beginSheetModal(for: parent) { response in
        received = response
    }

    expect(received == .OK, "Sheet save panel did not deliver the response.")
    expect(backend.fileDialogRequests.last?.anchorFrame == parent.frame, "Sheet presentation did not pass the parent frame as the dialog anchor.")

    backend.scriptedFileDialogPaths = [["C:\\Temp\\plain.txt"]]
    _ = panel.runModal()
    expect(backend.fileDialogRequests.last?.anchorFrame == nil, "Plain runModal should not anchor the dialog.")
}
func testMenuUpdateRunsValidationAndAutoenables() {
    let menu = NSMenu(title: "Edit")
    let validator = RecordingMenuValidator()

    let validated = NSMenuItem(title: "Paste", action: nil, keyEquivalent: "")
    validated.target = validator
    validated.isEnabled = true
    menu.addItem(validated)

    let actionless = NSMenuItem(title: "Broken", action: nil, keyEquivalent: "")
    menu.addItem(actionless)

    let wired = NSMenuItem(title: "Copy", action: nil, keyEquivalent: "")
    wired.onAction = { _ in }
    menu.addItem(wired)

    menu.update()

    expect(validator.validatedTitles == ["Paste"], "Menu update did not consult the item's validation target.")
    expect(validated.isEnabled == false, "Menu update did not apply the validator's refusal.")
    expect(actionless.isEnabled == false, "Autoenable did not disable an item with no action.")
    expect(wired.isEnabled == true, "Autoenable disabled an item with an action.")

    validator.allowed = true
    menu.update()
    expect(validated.isEnabled == true, "Menu update did not re-enable after validation allowed it.")

    menu.autoenablesItems = false
    validated.isEnabled = false
    menu.update()
    expect(validated.isEnabled == false, "Manual enablement was overridden with autoenablesItems off.")
}

func testStringSizeUsesBackendTextMetrics() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    let size = "Hello".size(withAttributes: [.font: NSFont.boldSystemFont(ofSize: 20)])
    expect(size.width == 5 * 20 * 0.55, "String measurement did not route through the backend metrics.")
    expect(size.height == 20 * 1.35, "String measurement height did not route through the backend metrics.")
}

func testWindowSheetPositionsRunsModalAndEndsWithCode() {
    clearApplicationWindows()

    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        clearApplicationWindows()
    }

    let parent = NSWindow(
        contentRect: NSMakeRect(100, 100, 600, 400),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let sheet = NSWindow(
        contentRect: NSMakeRect(0, 0, 300, 150),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )

    backend.nextModalResponseCode = NSApplication.ModalResponse.OK.rawValue
    var received: NSApplication.ModalResponse?
    parent.beginSheet(sheet) { response in
        received = response
    }

    expect(received == .OK, "Sheet completion handler did not receive the modal response.")
    expect(sheet.frame.origin.x == 250, "Sheet was not centered on the parent window.")
    expect(sheet.frame.origin.y == 156, "Sheet was not positioned under the parent title area.")
    expect(backend.modalSessions.contains(sheet.nativeHandle ?? NativeHandle(rawValue: 0)), "Sheet did not run a modal session.")

    parent.endSheet(sheet, returnCode: .cancel)
    expect(backend.modalStopCodes.last == NSApplication.ModalResponse.cancel.rawValue, "endSheet did not forward its return code.")
    expect(sheet.nativeHandle == nil, "endSheet did not close the sheet window.")
}

func testAlertBeginSheetModalDeliversResponse() {
    clearApplicationWindows()

    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        clearApplicationWindows()
    }

    let parent = NSWindow(
        contentRect: NSMakeRect(50, 50, 500, 300),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let alert = NSAlert()
    alert.messageText = "Sheet?"
    alert.addButton(withTitle: "Yes")
    alert.addButton(withTitle: "No")
    backend.nextModalResponseCode = NSApplication.ModalResponse.alertSecondButtonReturn.rawValue

    var received: NSApplication.ModalResponse?
    alert.beginSheetModal(for: parent) { response in
        received = response
    }

    expect(received == .alertSecondButtonReturn, "Alert sheet did not deliver the scripted response.")
    expect(backend.modalSessions.count == 1, "Alert sheet did not run a modal session.")
}

testWindowRealizationCreatesNativeHierarchy()
testWindowTitleVisibilityBlanksCaption()
testWindowStandardButtonsAndStyleFlags()
testViewHierarchyMaintainsSuperviewOwnership()
testViewInsertionReplacementTagsAndDescendants()
testViewCompatibilityMetadataStoresValues()
testViewTooltipSyncsToNativePeer()
testGeometryConvenienceFunctions()
testViewCoordinateConversionAndHitTesting()
testScrollViewHostsDocumentView()
testScrollViewUsesNativePeerAndRealizesDocumentView()
testScrollViewNativeScrollbarActionUpdatesClipOrigin()
testClipViewScrollsDocumentView()
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
testSearchFieldTabKeyMovesThroughKeyViewLoop()
testTableViewKeyboardNavigationUpdatesSelection()
testTableViewKeyboardExtendedSelection()
testTableViewColumnSelectionAndDoubleActionSurface()
testTableViewSortDescriptorPrototypeToggle()
testOutlineViewFlattensExpandableItems()
testBrowserLoadsColumnsAndTracksSelection()
testIndexPathStoresCollectionComponents()
testCollectionViewReloadsItemsAndTracksSelection()
testCollectionViewButtonItemClickSelectsItem()
testSliderStoresRangeValueAndSyncsNativePeer()
testSliderNativeActionUpdatesValue()
testProgressIndicatorStoresRangeValueAndSyncsNativePeer()
testLevelIndicatorStoresRangeValueAndUsesProgressPeer()
testScrollerStoresValueAndSyncsNativePeer()
testScrollerNativeActionUpdatesValue()
testScrollerHitPartReflectsGesture()
testDatePickerStoresDateRangeAndSyncsNativePeer()
testSegmentedControlStoresSegmentsAndComposesButtons()
testSegmentedControlPerSegmentImageAndTag()
testSegmentedControlActionSelectsSegment()
testStepperStoresRangeIncrementAndSyncsNativePeer()
testStepperNativeActionUpdatesValue()
testSearchFieldTracksRecentSearchesAndNativeChanges()
testColorWellStoresColorAndSendsAction()
testTableViewNativePeerReceivesColumnsRowsAndSelection()
testTableViewNativeSelectionNotifiesDelegateAndAction()
testTableViewActionCanReadSelectedRowValue()
testTableViewClickedRowAndColumnFollowSelection()
testSplitViewArrangesSubviewsAndDividerPosition()
testSubviewResponderChainTargetsSuperview()
testResponderForwardsUnhandledEvents()
testWindowIsContentViewNextResponder()
testWindowMakeFirstResponderFocusesNativeView()
testWindowMakeFirstResponderHonorsResignFailure()
testApplicationTracksWindowListAndKeyMainWindow()
testWindowSelectNextAndPreviousKeyView()
testWindowSelectNextKeyViewSkipsDisabledExplicitTarget()
testWindowSelectNextKeyViewSkipsHiddenContainerChildren()
testNativeMouseDownDispatchesToView()
testNativeMouseDownOnControlMakesControlFirstResponder()
testNativeMouseUpDispatchesToView()
testNativeMouseMovedDispatchesToView()
testNativeMouseDraggedDispatchesToView()
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
testNativeWindowResizeUpdatesContentAndAutoresizesSubviews()
testPanelStoresPanelStateAndOrdersFront()
testPopoverShowsClosesAndReopensFromAnchorView()
testPopoverAnimatesFadesHost()
testToolbarStoresItemsAndAttachesToWindow()
testToolbarVisibilityAndItemActions()
testToolbarCustomizationDelegateAndDefaultItems()
testToolbarCustomizationAllowsDuplicateStructuralItems()
testToolbarCustomizationPaletteShowsToolbarDropTargetAtTop()
testToolbarCustomizationMovesExistingItemToEnd()
testToolbarViewComposesItemsAndDispatchesActions()
testToolbarViewHostsCustomItemView()
testToolbarItemCreatesCompositeImageLabelView()
testWindowToolbarCreatesDockedComposedHostAndReservesContent()
testEditableTextFieldUsesEditableNativePeer()
testSecureTextFieldUsesSecureNativePeer()
testTextViewUsesMultilineNativePeerAndStoresText()
testTextFieldFactoryConstructorsAndCompatibilityProperties()
testFormComposesTextFieldsAndStoresCells()
testMatrixComposesButtonsAndTracksSelection()
testSwitchButtonUsesCheckboxNativePeer()
testRadioButtonUsesRadioNativePeer()
testPopUpButtonUsesNativePeerAndSelection()
testPopUpButtonNativeActionUpdatesSelection()
testPopUpButtonItemLookupAndRemoval()
testComboBoxStoresItemsTextAndUsesNativePeer()
testComboBoxNativeTextChangeAndActionUpdateState()
testTokenFieldStoresTokensAndTokenizesNativeText()
testPathControlStoresURLAndPathComponentCells()
testPathControlComponentURLsAndSelection()
testWinFoundationCompatibilitySurface()
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
testVisualEffectViewStoresMaterialAndUsesFallbackBackground()
testFontValuesClampSizeAndSyncToBackend()
testRemovingRealizedSubviewDestroysNativePeer()
testMainMenuQuitItemTerminatesApplication()
testMenuItemInsertionLookupAndRemoval()
testMenuItemStateAndSeparatorContracts()
testAlertReturnsFirstButtonInMemory()
testAlertRestoresKeyWindowAndFirstResponder()
testSavePanelMapsOptionsAndReturnsChosenURL()
testSavePanelCancelReturnsCancelAndClearsURL()
testOpenPanelSupportsMultipleSelectionAndDirectories()
testOpenPanelBeginInvokesCompletionHandler()
testViewDrawDispatchesPathsToBackendContext()
testViewDrawDispatchesTextAndImagesToBackendContext()
testGradientAndClipCommandsReachBackendContext()
testUndoManagerRegistersUndoAndRedo()
testTextViewUndoRestoresPreviousText()
testDocumentWindowControllersSyncTitles()
testDocumentControllerNewDocumentMakesAndShowsWindows()
testSplitViewDividerDragResizesPanes()
testCursorRectsFlowToBackendRegions()
testViewChainSeesKeyEquivalentsBeforeMenu()
testTextViewFindAndReplace()
testScrollToVisibleMovesTheClipView()
testTimerSchedulesFiresAndInvalidates()
testFileManagerCoversDocumentAppNeeds()
testDocumentWindowCloseAsksToSaveAndAutosaves()
testAttributedStringStoresStringAndAttributes()
testRightMouseScrollAndClickCountReachTheView()
testAlertCustomButtonsRunComposedModalPanel()
testRunModalReturnsScriptedStopCode()
testProgressIndicatorIndeterminateSyncsToBackend()
testMenuUpdateRunsValidationAndAutoenables()
testStringSizeUsesBackendTextMetrics()
testWindowSheetPositionsRunsModalAndEndsWithCode()
testAlertBeginSheetModalDeliversResponse()
testSavePanelSheetPassesAnchorFrame()
testOtherMouseButtonsReachTheView()
testMenuPerformKeyEquivalentMatchesControlAsCommand()
testMenuPopUpPerformsScriptedContextSelection()
testCursorSetPushPopSyncToBackend()
testTextViewSelectionInsertionAndDelegate()
testDocumentChangeCountAndOverridableDefaults()
testDocumentSavePanelFlowWritesAndReadsBack()
testDocumentControllerTracksDocumentsRecentsAndOpen()
testNSNumberBoxing()
testNumberFormatterStylesAndParsing()
testTextFieldFormatterDisplaysAndParses()
testLocaleSystemPatterns()
testDateFormatterPatternsAndRoundTrip()
testWindowMovableByBackgroundAndPanelKeyAndColorWell()
testDatePickerElementFormats()
testButtonImageAndAlternateTitle()
testTextFieldDelegateEditingCallbacks()
testPopUpButtonTagsAndPullsDown()
testAlertHelpAndIconConfiguration()
testCommonControlDepthWiresToBackend()
testSegmentedControlKeyboardSelection()
testWindowSizeLimitsAndPopoverDismiss()
testFontTraitsWeightsAndDescriptor()
testMutableAttributedStringRunsAndEnumeration()
testTextStorageAppliesRunsToTextView()
testRTFWriterEmitsTablesRunsAndEscapes()
testPasteboardAndTextViewClipboardActions()
testRichTextViewAppliesRangeFormatting()
testScrollViewWheelScrollingMovesContent()
testScrollViewMagnificationScalesGeometryAndDrawing()
testFloatingPanelStateReachesBackend()
testColorPanelFloatsAndAppliesColorsLive()
testFontPanelLiveApplyThroughFontManager()
testAlertAccessoryViewJoinsComposedPanel()

print("WinChocolate contract tests passed.")
