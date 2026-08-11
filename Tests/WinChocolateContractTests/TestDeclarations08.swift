import WinChocolate

@MainActor
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

@MainActor
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

@MainActor
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

@MainActor
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

    expect(backend.records[handle]?.kind == "view", "Color well did not request a mouse-routing swatch peer.")
    expect(backend.records[handle]?.backgroundColor == .red, "Color well color was not synced to background.")

    colorWell.color = .blue
    expect(backend.records[handle]?.backgroundColor == .blue, "Color well updated color was not synced.")

    backend.mouseDownActions[handle]?(NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(2, 2)))

    expect(colorWell.isActive, "Color well did not activate on click.")
    expect(actionCount == 1, "Color well did not send action on click.")
}

@MainActor
func testColorWellPanelPickFiresActionAndTintsTemplate() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    let templateImage = NSImage(contentsOfFile: "C:/art/glyph.png")
    templateImage?.isTemplate = true
    let imageView = NSImageView(frame: NSMakeRect(0, 0, 44, 36))
    imageView.image = templateImage
    let imageHandle = imageView.realizeNativePeer(in: backend, parent: nil)

    let well = NSColorWell(frame: NSMakeRect(0, 0, 44, 36))
    well.color = .systemBlue
    var actionColors: [NSColor] = []
    well.onAction = { control in
        guard let well = control as? NSColorWell else {
            return
        }
        actionColors.append(well.color)
        imageView.contentTintColor = well.color
    }
    let wellHandle = well.realizeNativePeer(in: backend, parent: nil)

    // Click: presents the panel and activates the well. (Activation seeds the
    // panel with the well's color, which counts as the first "change".)
    backend.mouseDownActions[wellHandle]?(NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(2, 2)))
    expect(well.isActive, "Clicking the well did not activate it.")
    expect(NSColorPanel.shared.color == .systemBlue, "Activation did not seed the panel with the well's color.")

    // A panel pick (what the panel's sliders/swatches set) must flow back:
    // well.color updates AND the action fires with the new color.
    let picked = NSColor(calibratedRed: 0.2, green: 0.7, blue: 0.3, alpha: 1)
    NSColorPanel.shared.color = picked
    expect(well.color == picked, "Panel pick did not update the active well's color.")
    expect(actionColors.last == picked, "Panel pick did not fire the well's action with the picked color.")
    expect(backend.records[imageHandle]?.imageTint == picked, "contentTintColor did not re-tint the template image natively.")

    well.deactivate()
}

@MainActor
func testDrawnTableScrollRowToVisibleMovesClipView() {
    let backend = InMemoryNativeControlBackend()
    let scrollView = NSScrollView(frame: NSMakeRect(0, 0, 200, 100))
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 200, 100))
    tableView.winUsesViewBasedCells = true
    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    column.width = 180
    tableView.addTableColumn(column)
    let dataSource = ScrollRowsDataSource()
    tableView.dataSource = dataSource
    scrollView.documentView = tableView
    _ = scrollView.realizeNativePeer(in: backend, parent: nil)
    tableView.reloadData()

    // Row 30 sits far below the 100pt viewport; scrolling must move the clip.
    tableView.scrollRowToVisible(30)
    expect(scrollView.contentView.documentVisibleRect.origin.y > 0,
           "scrollRowToVisible left the drawn table at the top.")

    // Scrolling to an already-visible row must not move the viewport (the
    // implementation nudges only as far as needed, so a repeat is a no-op).
    let afterFirst = scrollView.contentView.documentVisibleRect.origin
    tableView.scrollRowToVisible(30)
    expect(scrollView.contentView.documentVisibleRect.origin == afterFirst,
           "scrollRowToVisible moved the viewport for an already-visible row.")

    // Scrolling back to the first row returns to the top.
    tableView.scrollRowToVisible(0)
    expect(scrollView.contentView.documentVisibleRect.origin.y == 0,
           "scrollRowToVisible did not scroll back up to the first row.")
}

final class ScrollRowsDataSource: NSObject, NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int { 40 }
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? { "row \(row)" }
}

@MainActor
func testColorWellExpandedSwatchPalette() {
    clearApplicationWindows()
    let previousBackend = NSApplication.shared.nativeBackend
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        clearApplicationWindows()
    }

    let window = NSWindow(contentRect: NSMakeRect(0, 0, 300, 200), styleMask: [.titled], backing: .buffered, defer: false)
    let content = NSView(frame: NSMakeRect(0, 0, 300, 200))
    let well = NSColorWell(frame: NSMakeRect(20, 20, 40, 24))
    well.colorWellStyle = .expanded
    well.color = .white
    content.addSubview(well)
    window.contentView = content
    window.makeKeyAndOrderFront(nil)

    var actionCount = 0
    well.onAction = { _ in actionCount += 1 }

    // The expanded style drops down a swatch palette instead of the panel.
    well.winShowSwatchPalette()
    expect(well.winSwatchPopover?.isShown == true, "Expanded well did not show its swatch palette.")

    // Picking a swatch sets the color, fires the action, and closes the palette.
    well.winSimulateSwatchPick(at: 3) // red, in swatchColors order
    expect(well.color == .red, "Swatch pick did not set the well color.")
    expect(actionCount == 1, "Swatch pick did not fire the well action.")
    expect(well.winSwatchPopover?.isShown == false, "Swatch pick did not close the palette.")
}

@MainActor
func testTableViewNativePeerReceivesColumnsRowsAndSelection() {
    let backend = InMemoryNativeControlBackend()
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

@MainActor
func testTableViewNativeSelectionNotifiesDelegateAndAction() {
    let backend = InMemoryNativeControlBackend()
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 160))
    let dataSource = RecordingTableDataSource()
    // Cell-based delegate (vends no view) so the table uses the native list
    // path this test exercises — auto-detection only picks the drawn peer when
    // a delegate vends views.
    let delegate = CellBasedSelectionDelegate()
    let name = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    var actionCount = 0

    tableView.addTableColumn(name)
    tableView.dataSource = dataSource
    // One real delegate observes the selection (a table has a single
    // delegate — the closure convenience is gone from the framework, and
    // selection changes arrive through tableViewSelectionDidChange).
    tableView.delegate = delegate
    tableView.onAction = { control in
        expect(control === tableView, "Table action sender was not table view.")
        actionCount += 1
    }
    tableView.reloadData()

    let handle = tableView.realizeNativePeer(in: backend, parent: nil)
    backend.setTableSelectedRow(2, for: handle)
    backend.actions[handle]?()

    expect(tableView.selectedRow == 2, "Table view did not read native selection.")
    expect(actionCount == 1, "Table view did not send action after selection.")
    expect(delegate.selectionChangeCount == 1, "Table view delegate was not notified.")
    expect((delegate.lastObject as AnyObject) === tableView, "Table view delegate notification object was wrong.")
}

@MainActor
func testTableViewActionCanReadSelectedRowValue() {
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 160))
    let dataSource = RecordingTableDataSource()
    let name = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
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

@MainActor
func testTableViewClickedRowAndColumnFollowSelection() {
    let tableView = NSTableView(frame: NSMakeRect(0, 0, 300, 160))
    let dataSource = RecordingTableDataSource()
    let name = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    let note = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("note"))

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

@MainActor
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

@MainActor
func testSplitViewResizeKeepsPaneProportions() {
    // AppKit's `adjustSubviews` scales the panes it finds; it does not re-divide
    // them evenly. A divider the app positioned must survive a resize instead of
    // snapping back to the middle.
    let splitView = NSSplitView(frame: NSMakeRect(0, 0, 240, 100))
    let first = NSView(frame: NSZeroRect)
    let second = NSView(frame: NSZeroRect)
    splitView.addSubview(first)
    splitView.addSubview(second)
    splitView.setPosition(70, ofDividerAt: 0)
    expect(first.frame.size.width == 70, "Split divider did not take the requested position.")

    let thickness = splitView.dividerThickness
    let oldAvailable = 240 - thickness
    splitView.frame = NSMakeRect(0, 0, 360, 100)

    let expectedFirst = 70 * (360 - thickness) / oldAvailable
    expect(abs(first.frame.size.width - expectedFirst) < 0.5,
           "Resize should scale the first pane proportionally (expected ~\(expectedFirst), got \(first.frame.size.width)).")
    expect(first.frame.size.width < 150,
           "Resize must not snap the divider back to the middle (got \(first.frame.size.width)).")
    expect(abs((first.frame.size.width + thickness + second.frame.size.width) - 360) < 0.5,
           "Panes plus divider should fill the resized split view.")
    expect(abs(second.frame.origin.x - (first.frame.size.width + thickness)) < 0.5,
           "Second pane should start just past the divider.")
}

@MainActor
func testSubviewResponderChainTargetsSuperview() {
    let parent = NSView(frame: NSMakeRect(0, 0, 100, 100))
    let child = NSView(frame: NSMakeRect(0, 0, 20, 20))

    parent.addSubview(child)

    expect(child.nextResponder === parent, "Subview next responder was not its superview.")

    child.removeFromSuperview()

    expect(child.nextResponder == nil, "Subview next responder was not cleared on removal.")
}

@MainActor
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

@MainActor
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

@MainActor
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

@MainActor
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

@MainActor
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

@MainActor
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

