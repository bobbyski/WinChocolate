import WinChocolate

@MainActor
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

@MainActor
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

    let fileURL = testFileManagerFileRoundTrip(manager: manager, nested: nested)
    testFileManagerCopyMoveAndRemove(manager: manager, root: root, nested: nested, fileURL: fileURL)
    testFileManagerKnownFolders(manager: manager)
}

@MainActor
func testFileManagerFileRoundTrip(manager: FileManager, nested: URL) -> URL {
    // File round trip plus isDirectory == false for plain files.
    let fileURL = nested.appendingPathComponent("note.txt")
    do {
        try Data(Array("hello files".utf8)).write(to: fileURL)
    } catch {
        expect(false, "Writing the test file threw: \(error)")
    }
    var isDirectory = ObjCBool(false)
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
    return fileURL
}

@MainActor
func testFileManagerCopyMoveAndRemove(manager: FileManager, root: URL, nested: URL, fileURL: URL) {
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
}

@MainActor
func testFileManagerKnownFolders(manager: FileManager) {
    // Known folders resolve to real locations.
    let documents = manager.urls(for: .documentDirectory, in: .userDomainMask)
    expect(documents.count == 1, "The Documents folder did not resolve.")
    #if os(Windows)
    expect(manager.fileExists(atPath: documents[0].path), "The resolved Documents folder does not exist.")
    #else
    expect(!documents[0].path.isEmpty, "The resolved Documents folder path is empty.")
    #endif
}

@MainActor
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

@MainActor
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

@MainActor
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

@MainActor
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

@MainActor
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

@MainActor
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

@MainActor
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

@MainActor
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

@MainActor
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

@MainActor
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

