import WinChocolate

@MainActor
func testTrackingAreasDeliverEnterAndExit() {
    let backend = InMemoryNativeControlBackend()
    let view = HoverRecordingView(frame: NSMakeRect(0, 0, 100, 100))
    let area = NSTrackingArea(rect: NSMakeRect(10, 10, 40, 40), options: [.mouseEnteredAndExited, .activeAlways], owner: view, userInfo: ["zone": "badge"])
    view.addTrackingArea(area)
    expect(view.trackingAreas.count == 1, "addTrackingArea did not retain the area.")
    expect(area.userInfo?["zone"] as? String == "badge", "Tracking area lost its userInfo.")

    let handle = view.realizeNativePeer(in: backend, parent: nil)

    // Move inside the area: one enter, no exit.
    backend.mouseMovedActions[handle]?(NSEvent(type: .mouseMoved, locationInWindow: NSMakePoint(20, 20)))
    expect(view.enteredCount == 1 && view.exitedCount == 0, "Entering the area did not send exactly one mouseEntered.")

    // Move within the area: no repeated enter.
    backend.mouseMovedActions[handle]?(NSEvent(type: .mouseMoved, locationInWindow: NSMakePoint(30, 30)))
    expect(view.enteredCount == 1, "Moving inside the area re-sent mouseEntered.")

    // Move out of the area (still inside the view): one exit.
    backend.mouseMovedActions[handle]?(NSEvent(type: .mouseMoved, locationInWindow: NSMakePoint(80, 80)))
    expect(view.exitedCount == 1, "Leaving the area did not send mouseExited.")

    // Re-enter, then leave the view entirely (native mouse-leave): exit fires.
    backend.mouseMovedActions[handle]?(NSEvent(type: .mouseMoved, locationInWindow: NSMakePoint(20, 20)))
    expect(view.enteredCount == 2, "Re-entering the area did not send mouseEntered again.")
    backend.simulateMouseLeft(for: handle)
    expect(view.exitedCount == 2, "The native mouse-leave did not exit the hovered area.")

    // removeTrackingArea stops deliveries.
    view.removeTrackingArea(area)
    backend.mouseMovedActions[handle]?(NSEvent(type: .mouseMoved, locationInWindow: NSMakePoint(20, 20)))
    expect(view.enteredCount == 2, "A removed tracking area still delivered events.")

    // inVisibleRect tracks the whole bounds regardless of the area rect.
    let wholeView = HoverRecordingView(frame: NSMakeRect(0, 0, 50, 50))
    wholeView.addTrackingArea(NSTrackingArea(rect: NSZeroRect, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: nil))
    let wholeHandle = wholeView.realizeNativePeer(in: backend, parent: nil)
    backend.mouseMovedActions[wholeHandle]?(NSEvent(type: .mouseMoved, locationInWindow: NSMakePoint(45, 45)))
    expect(wholeView.enteredCount == 1, "inVisibleRect did not track the view bounds (owner fallback to the view).")
}

final class WindowStateRecordingDelegate: NSObject, NSWindowDelegate {
    var resized = 0
    var moved = 0
    var miniaturized = 0
    var deminiaturized = 0

    func windowDidResize(_ notification: Notification) { resized += 1 }
    func windowDidMove(_ notification: Notification) { moved += 1 }
    func windowDidMiniaturize(_ notification: Notification) { miniaturized += 1 }
    func windowDidDeminiaturize(_ notification: Notification) { deminiaturized += 1 }
}

@MainActor
func testScreensAndWindowStateDepth() {
    let backend = InMemoryNativeControlBackend()
    backend.testScreens = [
        NativeScreenDescription(
            frame: NSMakeRect(0, 0, 1920, 1080),
            visibleFrame: NSMakeRect(0, 0, 1920, 1040)
        ),
        NativeScreenDescription(
            frame: NSMakeRect(1920, 0, 1280, 1024),
            visibleFrame: NSMakeRect(1920, 0, 1280, 984)
        ),
    ]
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        clearApplicationWindows()
    }

    // NSScreen reflects the backend's monitors, primary first.
    expect(NSScreen.screens.count == 2, "NSScreen.screens did not list both displays.")
    expect(NSScreen.main?.frame == NSMakeRect(0, 0, 1920, 1080), "NSScreen.main is not the primary display.")
    expect(NSScreen.main?.visibleFrame == NSMakeRect(0, 0, 1920, 1040), "visibleFrame did not exclude the work-area inset.")

    testWindowStateDepth(backend: backend)
}

@MainActor
func testWindowStateDepth(backend: InMemoryNativeControlBackend) {
    let window = NSWindow(
        contentRect: NSMakeRect(2000, 100, 400, 300),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let delegate = WindowStateRecordingDelegate()
    window.delegate = delegate
    window.makeKeyAndOrderFront(nil)
    guard let handle = window.nativeHandle else {
        expect(false, "Window did not realize a native handle.")
        return
    }

    // The window reports the second display (most overlap).
    expect(window.screen?.frame == NSMakeRect(1920, 0, 1280, 1024), "window.screen did not pick the display with the most overlap.")

    // center() uses the primary work area.
    window.center()
    expect(window.frame.origin.x == (1920 - 400) / 2, "center() did not center horizontally in the work area.")
    expect(window.frame.origin.y == (1040 - 300) / 2, "center() did not center vertically in the work area.")

    // Minimize / restore round-trips with delegate callbacks.
    expect(window.isVisible, "A shown window should report visible.")
    window.miniaturize(nil)
    expect(window.isMiniaturized && !window.isVisible, "miniaturize did not minimize the native window.")
    expect(delegate.miniaturized == 1, "windowDidMiniaturize did not fire.")
    window.deminiaturize(nil)
    expect(!window.isMiniaturized, "deminiaturize did not restore the native window.")
    expect(delegate.deminiaturized == 1, "windowDidDeminiaturize did not fire.")

    // Zoom toggles; orderBack reaches the backend.
    window.zoom(nil)
    expect(window.isZoomed, "zoom did not maximize the window.")
    window.zoom(nil)
    expect(!window.isZoomed, "A second zoom did not restore the window.")
    window.orderBack(nil)
    expect(backend.windowsOrderedBack.contains(handle), "orderBack did not reach the backend.")

    // A native move updates the frame origin and notifies the delegate.
    backend.simulateWindowMove(to: NSMakePoint(64, 48), for: handle)
    expect(window.frame.origin == NSMakePoint(64, 48), "A native move did not update the window frame origin.")
    expect(delegate.moved == 1, "windowDidMove did not fire.")

    // A native resize notifies the delegate (existing relayout path).
    backend.windowResizeActions[handle]?(NSSize(width: 500, height: 400))
    expect(delegate.resized == 1, "windowDidResize did not fire.")
    expect(window.frame.size == NSSize(width: 500, height: 400), "A native resize did not update the frame size.")
}

final class DropRecordingView: NSView {
    var enteredOperations: [NSDragOperation] = []
    var exitedCount = 0
    var droppedTexts: [String] = []
    var droppedURLs: [URL] = []

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let operation: NSDragOperation = sender.draggingPasteboard.types?.isEmpty == false ? .copy : []
        enteredOperations.append(operation)
        return operation
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        exitedCount += 1
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let text = sender.draggingPasteboard.string(forType: .string) {
            droppedTexts.append(text)
        }
        if let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
            droppedURLs.append(contentsOf: urls)
        }
        return !droppedTexts.isEmpty || !droppedURLs.isEmpty
    }
}

final class TextDragSource: NSDraggingSource {
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }
}

@MainActor
func testDragAndDropDestinationAndSource() {
    let backend = InMemoryNativeControlBackend()

    // Destination: registering realizes a backend drop target.
    let view = DropRecordingView(frame: NSMakeRect(0, 0, 200, 100))
    view.registerForDraggedTypes([.string, .fileURL])
    let handle = view.realizeNativePeer(in: backend, parent: nil)
    expect(backend.dropHandlers[handle] != nil, "registerForDraggedTypes did not install a backend drop target.")

    // A file drag enters, is accepted, and drops file URLs.
    let files = NativeDropContent(text: nil, filePaths: ["C:\\Drop\\one.txt", "C:\\Drop\\two.txt"])
    expect(backend.simulateDragEnter(content: files, at: NSMakePoint(10, 10), for: handle), "The view did not accept a matching file drag.")
    expect(view.enteredOperations.last == .copy, "draggingEntered did not report a copy operation.")
    expect(backend.simulateDrop(content: files, at: NSMakePoint(20, 20), for: handle), "The drop was not performed.")
    expect(view.droppedURLs.count == 2 && view.droppedURLs.first?.isFileURL == true, "performDragOperation did not read the dropped file URLs.")

    // A text drag delivers through the drag pasteboard.
    let text = NativeDropContent(text: "Dragged words", filePaths: [])
    expect(backend.simulateDragEnter(content: text, at: NSMakePoint(5, 5), for: handle), "The view did not accept a matching text drag.")
    backend.simulateDragExit(for: handle)
    expect(view.exitedCount == 1, "draggingExited did not fire.")
    expect(backend.simulateDrop(content: text, at: NSMakePoint(5, 5), for: handle), "The text drop was not performed.")
    expect(view.droppedTexts == ["Dragged words"], "performDragOperation did not read the dropped text.")

    // Content that matches none of the registered types is refused.
    let strange = NativeDropContent(text: nil, filePaths: [])
    expect(!backend.simulateDragEnter(content: strange, at: NSZeroPoint, for: handle), "A drag with no matching content was accepted.")

    // Unregistering removes the backend target.
    view.unregisterDraggedTypes()
    expect(backend.dropHandlers[handle] == nil && backend.unregisteredDropTargets.contains(handle), "unregisterDraggedTypes did not remove the drop target.")

    // Source: beginDraggingSession routes the writers into a native drag.
    backend.nextDragResult = true
    let items = [
        NSDraggingItem(pasteboardWriter: "Outbound text"),
        NSDraggingItem(pasteboardWriter: URL(fileURLWithPath: "C:\\Send\\file.png")),
    ]
    let session = view.beginDraggingSession(with: items, event: NSEvent(type: .leftMouseDragged, locationInWindow: NSZeroPoint), source: TextDragSource())
    expect(session.winDropped, "The dragging session did not report the scripted drop.")
    expect(backend.performedDrags.count == 1, "beginDraggingSession did not start exactly one native drag.")
    expect(backend.performedDrags.first?.content.text == "Outbound text", "The outbound drag lost its text writer.")
    expect(backend.performedDrags.first?.content.filePaths.first?.hasSuffix("file.png") == true, "The outbound drag lost its file writer.")
}

final class PrintableTestView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.setFill()
        NSBezierPath(rect: NSMakeRect(0, 0, 100, 20)).fill()
        "Printed line".draw(at: NSMakePoint(4, 2), withAttributes: [.font: NSFont.systemFont(ofSize: 12)])
    }
}

@MainActor
func testPrintOperationRendersViewDrawing() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    // Print info carries paper geometry; the imageable bounds inset by margins.
    let info = NSPrintInfo()
    info.paperSize = NSSize(width: 612, height: 792)
    info.leftMargin = 36
    info.rightMargin = 36
    info.topMargin = 40
    info.bottomMargin = 40
    expect(info.imageablePageBounds == NSMakeRect(36, 40, 540, 712), "imageablePageBounds did not inset the paper by the margins.")

    let view = PrintableTestView(frame: NSMakeRect(0, 0, 300, 200))
    _ = view.realizeNativePeer(in: backend, parent: nil)

    let operation = NSPrintOperation.printOperation(with: view, printInfo: info)
    operation.jobTitle = "Test Job"
    expect(operation.run(), "The print operation did not report success.")

    expect(backend.printJobs.count == 1, "The backend did not record exactly one print job.")
    expect(backend.printJobs.first?.jobName == "Test Job", "The print job lost its document name.")
    expect(backend.printJobs.first?.contentSize == NSSize(width: 300, height: 200), "The print job did not use the view size.")
    expect(backend.printJobs.first?.recording.fills.count == 1, "The view's fill did not render into the print context.")
    expect(backend.printJobs.first?.recording.texts.first?.text == "Printed line", "The view's text did not render into the print context.")

    // A canceled dialog reports false and records nothing.
    backend.nextPrintResult = false
    expect(!operation.run(), "A canceled print dialog should report false.")
    expect(backend.printJobs.count == 1, "A canceled print dialog should not record a job.")
}

@MainActor
func testTableViewMultipleSelectionEditingAndSorting() {
    let backend = InMemoryNativeControlBackend()
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 160))
    let dataSource = RecordingTableDataSource()
    let name = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    name.title = "Name"
    name.isEditable = true
    name.sortDescriptorPrototype = NSSortDescriptor(key: "name", ascending: true)
    let note = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("note"))
    note.title = "Note"
    tableView.addTableColumn(name)
    tableView.addTableColumn(note)
    tableView.dataSource = dataSource
    tableView.allowsMultipleSelection = true

    let handle = tableView.realizeNativePeer(in: backend, parent: nil)

    // Multiple selection reaches the backend and round-trips as a set.
    expect(backend.tableAllowsMultipleSelection[handle] == true, "allowsMultipleSelection did not reach the backend.")
    tableView.selectRowIndexes([0, 2], byExtendingSelection: false)
    expect(tableView.selectedRowIndexes == [0, 2], "selectRowIndexes did not store the multiple selection.")
    expect(Set(backend.tableSelectedRowSets[handle] ?? []) == [0, 2], "Multiple selection did not sync to the backend.")

    // A native multi-row selection updates the framework's set.
    backend.simulateTableSelection(rows: [1, 2], for: handle)
    expect(tableView.selectedRowIndexes == [1, 2], "Native multiple selection did not update the framework set.")
    expect(tableView.numberOfSelectedRows == 2, "numberOfSelectedRows is wrong after a native multi-select.")

    // First-column editing is enabled; a committed edit writes through the data source.
    expect(backend.tableEditableHandles.contains(handle), "An editable first column did not enable native editing.")
    backend.simulateTableEdit(row: 1, column: 0, text: "Grace Hopper", for: handle)
    expect(dataSource.rows[1][0] == "Grace Hopper", "In-place edit did not write through the data source.")
    expect(tableView.value(atColumn: 0, row: 1) == "Grace Hopper", "The edited value did not reload.")

    // A partial reload refreshes only the requested cell.
    dataSource.rows[2][1] = "NASA"
    tableView.reloadData(forRowIndexes: [2], columnIndexes: [1])
    expect(tableView.value(atColumn: 1, row: 2) == "NASA", "Partial reload did not refresh the requested cell.")
    expect(tableView.value(atColumn: 0, row: 2) == "Katherine", "Partial reload should not have touched other cells.")

    // A header click on a sortable column applies the ascending sort + indicator.
    backend.simulateTableColumnClick(column: 0, for: handle)
    expect(tableView.sortDescriptors.first?.key == "name" && tableView.sortDescriptors.first?.ascending == true, "Header click did not apply the ascending sort descriptor.")
    expect(backend.tableSortIndicators[handle]?.column == 0 && backend.tableSortIndicators[handle]?.ascending == true, "Header click did not set the ascending sort indicator.")

    // A second header click toggles the sort (and indicator) to descending.
    backend.simulateTableColumnClick(column: 0, for: handle)
    expect(tableView.sortDescriptors.first?.ascending == false, "A second header click did not toggle to descending.")
    expect(backend.tableSortIndicators[handle]?.ascending == false, "The sort indicator did not flip to descending.")

    // A header click also FIRES the table action so apps that re-sort their
    // model on the action (reading `sortDescriptors`) actually run.
    var headerActionCount = 0
    var descriptorAtAction: NSSortDescriptor?
    tableView.onAction = { table in
        guard let table = table as? NSTableView, table.clickedRow < 0, table.clickedColumn >= 0 else {
            return
        }
        headerActionCount += 1
        descriptorAtAction = table.sortDescriptors.first
    }
    backend.simulateTableColumnClick(column: 0, for: handle)
    expect(headerActionCount == 1, "Header click did not fire the table action. Got \(headerActionCount).")
    expect(descriptorAtAction?.key == "name", "The action saw the wrong (or no) applied sort descriptor.")
}

final class ViewBasedTableDelegate: NSObject, NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        NSTextField(string: "\(tableColumn?.identifier.rawValue ?? "?")-\(row)", frame: NSMakeRect(0, 0, 100, 20))
    }
}

@MainActor
func testViewBasedTableHostsCellViews() {
    let backend = InMemoryNativeControlBackend()
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 200))
    let dataSource = RecordingTableDataSource()
    let name = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    name.title = "Name"
    name.width = 120
    let note = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("note"))
    note.title = "Note"
    note.width = 120
    tableView.addTableColumn(name)
    tableView.addTableColumn(note)
    tableView.dataSource = dataSource
    tableView.allowsMultipleSelection = true
    tableView.winUsesViewBasedCells = true
    let delegate = ViewBasedTableDelegate()
    tableView.delegate = delegate

    let handle = tableView.realizeNativePeer(in: backend, parent: nil)

    // A view-based table realizes a custom-drawn peer (not the native list),
    // and hosts one cell view per (row, column) — 3 rows x 2 columns.
    expect(backend.records[handle]?.kind == "view", "View-based table did not realize a custom-drawn peer.")
    expect(tableView.subviews.count == 6, "View-based table did not host a cell view per cell. Got \(tableView.subviews.count).")

    // Cell views are laid out below the header, in the column grid.
    let topLeftCell = tableView.subviews.min { $0.frame.origin.y < $1.frame.origin.y || ($0.frame.origin.y == $1.frame.origin.y && $0.frame.origin.x < $1.frame.origin.x) }
    expect((topLeftCell?.frame.origin.y ?? 0) >= 24, "The first cell view is not below the header row.")
    let secondColumnCells = tableView.subviews.filter { $0.frame.origin.x >= 120 }
    expect(secondColumnCells.count == 3, "The second column did not host a cell view per row.")

    // Clicking a row hit-tests and selects it.
    backend.mouseDownActions[handle]?(NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(10, 24 + 12)))
    expect(tableView.selectedRow == 0, "Clicking the first data row did not select it.")

    // Reloading rebuilds the hosted views (no leak / duplication).
    tableView.reloadData()
    expect(tableView.subviews.count == 6, "Reload did not rebuild exactly one cell view per cell.")
}

final class ManyRowTableDataSource: NSObject, NSTableViewDataSource {
    let count: Int
    init(count: Int) { self.count = count }
    func numberOfRows(in tableView: NSTableView) -> Int { count }
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? { "row \(row)" }
}

@MainActor
func testDrawnTableClipsCellTextToColumns() {
    let backend = InMemoryNativeControlBackend()
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 200, 200))
    let dataSource = ManyRowTableDataSource(count: 2)
    let colA = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("a"))
    colA.title = "A"
    colA.width = 80
    let colB = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("b"))
    colB.title = "B"
    colB.width = 80
    tableView.addTableColumn(colA)
    tableView.addTableColumn(colB)
    tableView.dataSource = dataSource
    tableView.winUsesViewBasedCells = true  // all-text drawn cells (no hosted views)

    let handle = tableView.realizeNativePeer(in: backend, parent: nil)
    let recording = backend.performDraw(for: handle, in: tableView.bounds)

    // Each of the 2×2 drawn-text cells clips its text to the cell rect, so a long
    // value can't spill into the next column. A rect clip is 5 path segments.
    let cellClips = recording.clips.filter { $0.segments.count == 5 }
    expect(cellClips.count == 4, "Drawn table did not clip each text cell to its column. Got \(cellClips.count).")

    // The default trailing inset is zero (only decorated columns reserve space).
    expect(tableView.winDrawnTrailingInset(forRow: 0, column: 0) == 0, "Default trailing inset should be zero.")
}

final class LongTextTableDataSource: NSObject, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int { 1 }
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        "ThisIsAVeryLongCellValueThatMustTruncate"
    }
}

@MainActor
func testDrawnTableTruncatesLongCellTextWithEllipsis() {
    // Use the in-memory backend for text measurement so truncation is
    // deterministic (width = characters × pointSize × 0.55).
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = InMemoryNativeControlBackend()
    defer { NSApplication.shared.nativeBackend = previousBackend }

    let backend = InMemoryNativeControlBackend()
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 80, 100))
    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    column.title = ""  // untitled → no header, so the first drawn text is the cell
    column.width = 40  // narrow: the 40-char value cannot fit
    tableView.addTableColumn(column)
    let dataSource = LongTextTableDataSource()
    tableView.dataSource = dataSource
    tableView.winUsesViewBasedCells = true

    let handle = tableView.realizeNativePeer(in: backend, parent: nil)
    let recording = backend.performDraw(for: handle, in: tableView.bounds)

    guard let drawn = recording.texts.first?.text else {
        fatalError("Drawn table recorded no cell text.")
    }
    expect(drawn.hasSuffix("…"), "Long cell text was not truncated with an ellipsis. Got \(drawn).")
    expect(drawn.count < 40, "Truncated text was not shorter than the 40-char original. Got \(drawn).")
}

final class RecyclingCellDelegate: NSObject, NSTableViewDelegate {
    static let cellID = NSUserInterfaceItemIdentifier("recycle-cell")
    private(set) var madeFresh = 0
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let reused = tableView.makeView(withIdentifier: Self.cellID, owner: nil) as? NSTextField {
            reused.stringValue = "r\(row)"
            return reused
        }
        madeFresh += 1
        let field = NSTextField(string: "r\(row)", frame: NSMakeRect(0, 0, 100, 20))
        field.identifier = Self.cellID
        return field
    }
}

@MainActor
func testDrawnTableRecyclesCellViewsViaMakeView() {
    let backend = InMemoryNativeControlBackend()
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 200, 200))
    let dataSource = ManyRowTableDataSource(count: 3)
    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    column.width = 180
    tableView.addTableColumn(column)
    tableView.dataSource = dataSource
    let delegate = RecyclingCellDelegate()
    tableView.delegate = delegate

    _ = tableView.realizeNativePeer(in: backend, parent: nil)

    // First build hosts 3 cell views. (Fresh count may include one extra from
    // the view-based auto-detection probe, which isn't hosted — so assert on the
    // hosted set and the reload delta, not the absolute fresh count.)
    let firstViews = Set(tableView.subviews.compactMap { $0 as? NSTextField }.map { ObjectIdentifier($0) })
    expect(firstViews.count == 3, "First build did not host 3 cell views. Got \(firstViews.count).")
    let freshAfterFirst = delegate.madeFresh

    // Reload: the outgoing views are pooled and handed back through makeView, so
    // no fresh views are allocated and the same instances are re-hosted.
    tableView.reloadData()
    let secondViews = Set(tableView.subviews.compactMap { $0 as? NSTextField }.map { ObjectIdentifier($0) })
    expect(secondViews == firstViews, "Cell views were not recycled across reloadData.")
    expect(delegate.madeFresh == freshAfterFirst,
           "reloadData allocated fresh cell views instead of recycling. \(freshAfterFirst) → \(delegate.madeFresh).")
}

final class AttributedCellTableDataSource: NSObject, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int { 1 }
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        NSAttributedString(string: "Alert", attributes: [.foregroundColor: NSColor.red])
    }
}

@MainActor
func testDrawnTableRendersAttributedCellValue() {
    let backend = InMemoryNativeControlBackend()
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 120, 100))
    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("c"))
    column.title = ""  // no header, so the first drawn text is the cell
    column.width = 100
    tableView.addTableColumn(column)
    let dataSource = AttributedCellTableDataSource()
    tableView.dataSource = dataSource
    tableView.winUsesViewBasedCells = true

    let handle = tableView.realizeNativePeer(in: backend, parent: nil)
    let recording = backend.performDraw(for: handle, in: tableView.bounds)

    // The cell renders the attributed value's text with its own color, and its
    // plain string flows through the model too.
    let cell = recording.texts.first { $0.text == "Alert" }
    expect(cell != nil, "Attributed cell value was not drawn. Got \(recording.texts.map { $0.text }).")
    expect(cell?.color == .red, "Attributed cell was not drawn with its own color. Got \(String(describing: cell?.color)).")
    expect(tableView.value(atColumn: 0, row: 0) == "Alert", "Attributed value's plain string was not cached.")
}

@MainActor
func testTableColumnAutoresizing() {
    let backend = InMemoryNativeControlBackend()
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 100))
    let colA = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("a"))
    colA.title = "A"
    colA.width = 80
    let colB = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("b"))
    colB.title = "B"
    colB.width = 80
    tableView.addTableColumn(colA)
    tableView.addTableColumn(colB)
    let dataSource = ManyRowTableDataSource(count: 3)
    tableView.dataSource = dataSource
    tableView.winUsesViewBasedCells = true
    _ = tableView.realizeNativePeer(in: backend, parent: nil)

    // sizeLastColumnToFit: the last column fills the remaining width
    // (300 − 3pt intercell spacing − colA 80 = 217); others unchanged.
    tableView.sizeLastColumnToFit()
    expect(colA.width == 80, "sizeLastColumnToFit changed a non-last column. Got \(colA.width).")
    expect(colB.width == 217, "sizeLastColumnToFit did not fill the last column. Got \(colB.width).")

    // Uniform sizeToFit shares the deficit equally: available 297, current 160,
    // delta 137 → +68.5 each.
    colA.width = 80
    colB.width = 80
    tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
    tableView.sizeToFit()
    expect(colA.width == 148.5 && colB.width == 148.5,
           "Uniform sizeToFit did not share the width equally. Got \(colA.width), \(colB.width).")

    // With autoresizing off, sizeToFit is a no-op.
    colA.width = 50
    colB.width = 50
    tableView.columnAutoresizingStyle = .noColumnAutoresizing
    tableView.sizeToFit()
    expect(colA.width == 50 && colB.width == 50, "sizeToFit resized columns with autoresizing off.")
}

@MainActor
func testDrawnTableScrollsAsScrollViewDocument() {
    let backend = InMemoryNativeControlBackend()
    let scrollView = NSScrollView(frame: NSMakeRect(0, 0, 300, 120))
    scrollView.hasVerticalScroller = true
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 120))
    let dataSource = ManyRowTableDataSource(count: 20)
    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    column.title = "Name"
    column.width = 280
    tableView.addTableColumn(column)
    tableView.dataSource = dataSource
    let scrollDelegate = ViewBasedTableDelegate()
    tableView.delegate = scrollDelegate
    tableView.winUsesViewBasedCells = true
    scrollView.documentView = tableView

    _ = scrollView.realizeNativePeer(in: backend, parent: nil)

    // The titled header is pinned into a non-scrolling strip on the scroll view;
    // the document (body) therefore excludes the header and grows to just the
    // rows (20 x 24 = 480), which the scroll view scrolls. It hosts a cell view
    // per row.
    expect(tableView.subviews.count == 20, "Drawn table did not host a cell view per row. Got \(tableView.subviews.count).")
    expect(scrollView.winHeaderStripView != nil, "The scroll view did not get a pinned header strip.")
    expect(tableView.frame.size.height == 480, "Body (header-excluded) content height wrong. Got \(tableView.frame.size.height).")
    // The content clip is inset below the pinned 24pt header strip.
    expect(scrollView.contentView.frame.origin.y == 24, "The content clip was not inset below the header strip. Got \(scrollView.contentView.frame.origin.y).")

    // Scrolling repositions the document view up (negative origin), bringing
    // lower rows into the viewport.
    scrollView.contentView.scroll(to: NSMakePoint(0, 200))
    expect(tableView.frame.origin.y <= -150, "Scrolling did not move the drawn document view up. Got \(tableView.frame.origin.y).")
}

