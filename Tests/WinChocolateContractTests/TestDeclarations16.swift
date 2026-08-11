import WinChocolate

@MainActor
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

@MainActor
func testAlertReturnsFirstButtonInMemory() {
    NSApplication.shared.nativeBackend = InMemoryNativeControlBackend()
    let alert = NSAlert()
    alert.messageText = "Hello"
    alert.addButton(withTitle: "OK")

    let response = alert.runModal()

    expect(response == .alertFirstButtonReturn, "In-memory alert did not return first button.")
}

@MainActor
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

@MainActor
func testSavePanelMapsOptionsAndReturnsChosenURL() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    #if os(Windows)
    let directoryPath = "C:\\Projects"
    let chosenPath = directoryPath + "\\Report.txt"
    #else
    let directoryPath = "/Projects"
    let chosenPath = directoryPath + "/Report.txt"
    #endif
    let panel = NSSavePanel.savePanel()
    panel.title = "Save Document"
    panel.prompt = "Save"
    panel.nameFieldStringValue = "Report.txt"
    panel.allowedFileTypes = ["txt", "md"]
    panel.allowsOtherFileTypes = true
    panel.directoryURL = URL(fileURLWithPath: directoryPath)
    backend.scriptedFileDialogPaths = [[chosenPath]]

    let response = panel.runModal()

    expect(response == .OK, "Save panel did not return OK for a chosen path.")
    expect(panel.url?.path == chosenPath, "Save panel did not expose the chosen URL.")
    expect(backend.fileDialogRequests.count == 1, "Save panel did not run exactly one native dialog.")

    let options = backend.fileDialogRequests[0]
    expect(options.kind == .save, "Save panel did not request a save dialog.")
    expect(options.title == "Save Document", "Save panel did not forward its title.")
    expect(options.fileName == "Report.txt", "Save panel did not forward the name field value.")
    expect(options.fileTypes == ["txt", "md"], "Save panel did not forward allowed file types.")
    expect(options.allowsOtherFileTypes, "Save panel did not forward allowsOtherFileTypes.")
    expect(options.directoryPath == directoryPath, "Save panel did not forward the initial directory.")
    expect(!options.allowsMultipleSelection, "Save panel must not request multiple selection.")
}

@MainActor
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

@MainActor
func testOpenPanelSupportsMultipleSelectionAndDirectories() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    #if os(Windows)
    let firstPath = "C:\\A\\one.txt"
    let secondPath = "C:\\A\\two.txt"
    #else
    let firstPath = "/A/one.txt"
    let secondPath = "/A/two.txt"
    #endif
    let panel = NSOpenPanel.openPanel()
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = true
    panel.canChooseFiles = true
    backend.scriptedFileDialogPaths = [[firstPath, secondPath]]

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

@MainActor
func testOpenPanelBeginInvokesCompletionHandler() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    let panel = NSOpenPanel()
    #if os(Windows)
    backend.scriptedFileDialogPaths = [["C:\\A\\picked.txt"]]
    #else
    backend.scriptedFileDialogPaths = [["/A/picked.txt"]]
    #endif

    var receivedResponse: NSApplication.ModalResponse?
    panel.begin { response in
        receivedResponse = response
    }

    expect(receivedResponse == .OK, "Open panel begin did not deliver the modal response.")
    expect(panel.url?.lastPathComponent == "picked.txt", "Open panel begin did not populate url.")
}

final class DrawingTestView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.red.setFill()
        NSBezierPath(rect: NSMakeRect(1, 2, 10, 20)).fill()

        NSColor.blue.setStroke()
        let oval = NSBezierPath(ovalIn: NSMakeRect(0, 0, 40, 40))
        oval.lineWidth = 3
        oval.stroke()

        (NSMakeRect(5, 5, 2, 2)).fill()
    }
}

@MainActor
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

@MainActor
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
        (NSMakeRect(0, 0, 60, 60)).fill()
        NSGraphicsContext.restoreGraphicsState()

        (NSMakeRect(2, 2, 8, 8)).clip()
    }
}

@MainActor
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

@MainActor
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

@MainActor
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

final class SplitResizeRecorder: NSObject, NSSplitViewDelegate {
    var resizeCount = 0

    func splitViewDidResizeSubviews(_ notification: Notification) {
        resizeCount += 1
    }
}

@MainActor
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

@MainActor
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

