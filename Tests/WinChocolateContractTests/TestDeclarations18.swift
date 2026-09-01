import WinChocolate

@MainActor
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

@MainActor
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

@MainActor
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

@MainActor
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

@MainActor
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

final class RecordingTextViewDelegate: NSObject, NSTextViewDelegate {
    var changeCount = 0
    var lastNotificationName = ""
    var lastObject: Any?

    func textDidChange(_ notification: Notification) {
        changeCount += 1
        lastNotificationName = notification.name.rawValue
        lastObject = notification.object
    }
}

@MainActor
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
    expect((delegate.lastObject as AnyObject) === textView, "textDidChange did not carry the text view as the notification object.")

    // A selection made before realization applies when the peer appears.
    let deferred = NSTextView(frame: NSMakeRect(0, 0, 100, 40))
    deferred.string = "abcdef"
    deferred.selectedRange = NSMakeRange(2, 3)
    let deferredHandle = deferred.realizeNativePeer(in: backend, parent: nil)
    expect(backend.records[deferredHandle]?.textSelectionLocation == 2, "Stored selection location did not apply on realization.")
    expect(backend.records[deferredHandle]?.textSelectionLength == 3, "Stored selection length did not apply on realization.")
}

/// Supplies `TextContractDocument` through AppKit's real `documentClass(forType:)`.
final class TextContractDocumentController: NSDocumentController {
    override func documentClass(forType typeName: String) -> AnyClass? {
        TextContractDocument.self
    }
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

@MainActor
func testDocumentChangeCountAndOverridableDefaults() {
    let document = NSDocument()

    expect(document.displayName == "Untitled", "Unsaved document did not report the Untitled display name.")
    expect(!document.isDocumentEdited, "New document should not report edits.")

    document.updateChangeCount(.changeDone)
    expect(document.isDocumentEdited, "changeDone did not mark the document edited.")

    document.updateChangeCount(.changeCleared)
    expect(!document.isDocumentEdited, "changeCleared did not clear the edited state.")

    // `NSDocument().data(ofType:)` is deliberately NOT exercised here. On real
    // AppKit it raises `NSInternalInconsistencyException` ("dataOfType:error: is
    // a subclass responsibility but has not been overridden") and kills the
    // process — measured in Docs/NSDOCUMENT_PLAN.md § Ground Truth — so the port
    // traps to match. A test cannot catch either one, and asserting that it
    // *throws* was the old, invented behaviour this suite used to lock in.

    #if os(Windows)
    document.fileURL = URL(fileURLWithPath: "C:\\Docs\\Report.txt")
    #else
    document.fileURL = URL(fileURLWithPath: "/Docs/Report.txt")
    #endif
    expect(document.displayName == "Report.txt", "Saved document did not use the file name as display name.")
}

@MainActor
func testDocumentSavePanelFlowWritesAndReadsBack() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    let savePath = FileManager.default.temporaryDirectory
        .appendingPathComponent("winchoc-doc-test.txt").path
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

@MainActor
func testDocumentControllerTracksDocumentsRecentsAndOpen() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    // A controller that supplies the suite's document class through AppKit's
    // real hook, `documentClass(forType:)`.
    let controller = TextContractDocumentController()
    let first = NSDocument()
    let second = NSDocument()

    controller.addDocument(first)
    controller.addDocument(second)
    expect(controller.documents.count == 2, "Controller did not track added documents.")
    expect(controller.currentDocument === second, "Controller did not make the newest document current.")

    controller.removeDocument(second)
    expect(controller.documents.count == 1, "Controller did not remove a document.")
    expect(controller.currentDocument === first, "Controller did not fall back to the remaining document.")

    #if os(Windows)
    let documentsPath = "C:\\Docs"
    let pathSeparator = "\\"
    #else
    let documentsPath = "/Docs"
    let pathSeparator = "/"
    #endif
    for index in 1...12 {
        controller.noteNewRecentDocumentURL(URL(fileURLWithPath: "\(documentsPath)\(pathSeparator)file-\(index).txt"))
    }
    expect(controller.recentDocumentURLs.count == 10, "Recent documents list did not cap at ten entries.")
    expect(controller.recentDocumentURLs.first?.lastPathComponent == "file-12.txt", "Recent documents were not most-recent first.")

    controller.noteNewRecentDocumentURL(URL(fileURLWithPath: "\(documentsPath)\(pathSeparator)file-7.txt"))
    expect(controller.recentDocumentURLs.count == 10, "Re-noting a recent URL should not grow the list.")
    expect(controller.recentDocumentURLs.first?.lastPathComponent == "file-7.txt", "Re-noted URL did not move to the front.")
    expect(controller.recentDocumentURLs.filter { $0.lastPathComponent == "file-7.txt" }.count == 1, "Recent documents did not dedupe.")

    testDocumentControllerOpenAndClose(controller, backend: backend)
}

@MainActor
func testDocumentControllerOpenAndClose(_ controller: NSDocumentController, backend: InMemoryNativeControlBackend) {
    // openDocument reads each chosen URL into the configured document class.
    let openPath = FileManager.default.temporaryDirectory
        .appendingPathComponent("winchoc-doc-test.txt").path
    let seed = TextContractDocument()
    seed.content = "Opened content"
    var seedError: Error?
    do {
        try seed.write(to: URL(fileURLWithPath: openPath), ofType: "txt")
    } catch {
        seedError = error
    }
    expect(seedError == nil, "Seeding the open-document file failed.")

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

final class ColorChangeRecordingView: NSView, NSColorChanging {
    var receivedColors: [NSColor] = []

    override var acceptsFirstResponder: Bool {
        true
    }

    func changeColor(_ sender: NSColorPanel?) {
        if let panel = sender {
            receivedColors.append(panel.color)
        }
    }
}

final class FontChangeRecordingView: NSView, NSFontChanging {
    var receivedFonts: [NSFont] = []

    override var acceptsFirstResponder: Bool {
        true
    }

    func changeFont(_ sender: NSFontManager?) {
        receivedFonts.append((sender ?? NSFontManager.shared).convert(NSFont.systemFont(ofSize: 13)))
    }
}

final class RecordingTextFieldDelegate: NSObject, NSTextFieldDelegate {
    var began = 0
    var changed = 0
    var ended = 0
    var lastChangedText: String?

    func controlTextDidBeginEditing(_ obj: Notification) {
        began += 1
    }

    func controlTextDidChange(_ obj: Notification) {
        changed += 1
        lastChangedText = (obj.object as? NSTextField)?.stringValue
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        ended += 1
    }
}

@MainActor
func testTextFieldFormatterDisplaysAndParses() {
    let backend = InMemoryNativeControlBackend()
    let field = NSTextField(string: "", frame: NSMakeRect(0, 0, 120, 24))
    field.isEditable = true

    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    #if !os(Windows)
    formatter.locale = Locale(identifier: "en_US")
    #endif
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

@MainActor
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

@MainActor
func testNumberFormatterStylesAndParsing() {
    #if os(Windows)
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
    #endif
}

@MainActor
func testLocaleSystemPatterns() {
    #if os(Windows)
    // The current locale is read from the system and exposes usable patterns.
    let locale = Locale.current
    expect(!locale.identifier.isEmpty, "Current locale identifier was empty.")
    expect(!locale.shortDatePattern.isEmpty, "Locale short-date pattern was empty.")
    expect(!locale.timePattern.isEmpty, "Locale time pattern was empty.")

    // A constructed identifier is stored and bridges to the Windows form.
    let constructed = Locale(identifier: "en_US")
    expect(constructed.identifier == "en_US", "Locale did not store its identifier.")

    // A style-based DateFormatter uses the locale for output. The zone is
    // pinned: a Date is an instant, and the formatter now renders it as a wall
    // clock, so leaving the zone implicit would make this assertion depend on
    // where the machine running it happens to be.
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeZone = TimeZone(secondsFromGMT: 0)!
    let date = Date(timeIntervalSince1970: 1_780_272_000) // 2026-06-01 00:00 UTC
    expect(formatter.string(from: date) == "6/1/2026", "Short style did not produce the US short date.")

    // The same instant west of Greenwich is still the previous day — which is
    // the whole point: AppKit shows 5/31/2026 for this date on an Eastern Mac,
    // and the picker's field has to agree.
    let eastern = DateFormatter()
    eastern.dateStyle = .short
    eastern.timeZone = TimeZone(secondsFromGMT: -4 * 3_600)!
    expect(eastern.string(from: date) == "5/31/2026", "A UTC-4 zone did not roll the date back a day.")

    // The default zone is the system's, as Foundation's is.
    let byDefault = DateFormatter()
    expect(byDefault.timeZone.identifier == TimeZone.current.identifier,
           "DateFormatter did not default to the current zone.")
    #endif
}

