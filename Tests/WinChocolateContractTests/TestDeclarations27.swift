import WinChocolate

// Phase 1 of Docs/NSDOCUMENT_PLAN.md — the Foundation pieces the document
// architecture stands on.
//
// These tests assert the CONTRACT, never our implementation of it. That
// distinction is load-bearing here: on Linux and macOS `FileWrapper` is real
// Foundation's, and on Windows and in the browser it is the core's own
// (Sources/ChocolateKit/Runtime/FileWrapper.swift, gated to the two platforms
// whose Foundation lacks the type). The same test text runs against both, which
// is the only way to know the two agree — so nothing below may assert a
// disambiguated file name's exact spelling, or the bytes of a serialized
// representation, because those are unspecified and genuinely differ.

/// A scratch directory that cleans up after itself.
private func withTemporaryDirectory(_ body: (URL) throws -> Void) {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("chocolate-filewrapper-tests")
    try? FileManager.default.removeItem(at: root)
    do {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try body(root)
    } catch {
        expect(false, "Temporary directory work threw: \(error)")
    }
    try? FileManager.default.removeItem(at: root)
}

func testFileWrapperRoundTripsARegularFile() {
    withTemporaryDirectory { root in
        let payload = Data("Chocolate note".utf8)
        let wrapper = FileWrapper(regularFileWithContents: payload)
        wrapper.preferredFilename = "note.txt"

        expect(wrapper.isRegularFile, "A regular-file wrapper did not report isRegularFile.")
        expect(!wrapper.isDirectory, "A regular-file wrapper reported isDirectory.")
        expect(!wrapper.isSymbolicLink, "A regular-file wrapper reported isSymbolicLink.")
        expect(wrapper.regularFileContents == payload, "A regular-file wrapper lost its bytes.")
        expect(wrapper.fileWrappers == nil, "A regular-file wrapper offered children.")

        let destination = root.appendingPathComponent("note.txt")
        do {
            try wrapper.write(to: destination, options: .atomic, originalContentsURL: nil)
        } catch {
            expect(false, "Writing a regular-file wrapper threw: \(error)")
            return
        }

        expect(FileManager.default.fileExists(atPath: destination.path),
               "Writing a regular-file wrapper produced no file.")
        expect((try? Data(contentsOf: destination)) == payload,
               "A written wrapper's bytes did not match what went in.")
        expect(wrapper.matchesContents(of: destination),
               "matchesContents(of:) denied a file it had just written.")

        // Reading it back must reproduce the wrapper.
        guard let reread = try? FileWrapper(url: destination, options: .immediate) else {
            expect(false, "Reading a written wrapper back threw.")
            return
        }
        expect(reread.isRegularFile, "A wrapper read from a file was not a regular file.")
        expect(reread.regularFileContents == payload, "A wrapper read back lost its bytes.")
        expect(reread.filename == "note.txt", "A wrapper read back did not record its filename.")
    }
}

func testFileWrapperRoundTripsADirectoryTree() {
    withTemporaryDirectory { root in
        // The shape a document package actually takes: a folder holding files
        // and a nested folder.
        let images = FileWrapper(directoryWithFileWrappers: [
            "cover.png": FileWrapper(regularFileWithContents: Data([0x89, 0x50, 0x4E, 0x47]))
        ])
        images.preferredFilename = "Images"

        let bundle = FileWrapper(directoryWithFileWrappers: [
            "text.rtf": FileWrapper(regularFileWithContents: Data("body".utf8)),
            "meta.json": FileWrapper(regularFileWithContents: Data("{}".utf8)),
            "Images": images
        ])
        bundle.preferredFilename = "Note.notebundle"

        expect(bundle.isDirectory, "A directory wrapper did not report isDirectory.")
        expect(bundle.fileWrappers?.count == 3, "A directory wrapper lost children.")
        expect(bundle.regularFileContents == nil, "A directory wrapper offered file contents.")

        let destination = root.appendingPathComponent("Note.notebundle")
        do {
            try bundle.write(to: destination, options: [.atomic, .withNameUpdating],
                             originalContentsURL: nil)
        } catch {
            expect(false, "Writing a directory wrapper threw: \(error)")
            return
        }

        let manager = FileManager.default
        expect(manager.fileExists(atPath: destination.appendingPathComponent("text.rtf").path),
               "A written package is missing text.rtf.")
        expect(manager.fileExists(atPath: destination.appendingPathComponent("meta.json").path),
               "A written package is missing meta.json.")
        expect(manager.fileExists(atPath: destination.appendingPathComponent("Images/cover.png").path),
               "A written package is missing its nested Images/cover.png.")

        guard let reread = try? FileWrapper(url: destination, options: .immediate) else {
            expect(false, "Reading a written package back threw.")
            return
        }
        expect(reread.isDirectory, "A package read back was not a directory.")
        expect(reread.fileWrappers?.count == 3, "A package read back has the wrong child count.")
        expect(reread.fileWrappers?["Images"]?.isDirectory == true,
               "A package read back lost its nested directory.")
        expect(reread.fileWrappers?["Images"]?.fileWrappers?["cover.png"]?.regularFileContents
               == Data([0x89, 0x50, 0x4E, 0x47]),
               "A nested file's bytes did not survive the round trip.")
        expect(reread.fileWrappers?["text.rtf"]?.regularFileContents == Data("body".utf8),
               "A package child's bytes did not survive the round trip.")
    }
}

func testFileWrapperNamesChildrenWithoutCollisions() {
    let directory = FileWrapper(directoryWithFileWrappers: [:])

    let first = directory.addRegularFile(withContents: Data("one".utf8), preferredFilename: "page.txt")
    let second = directory.addRegularFile(withContents: Data("two".utf8), preferredFilename: "page.txt")
    let third = directory.addRegularFile(withContents: Data("three".utf8), preferredFilename: "page.txt")

    // The exact disambiguated spelling is unspecified — Foundation's and ours
    // differ — so the contract is that the keys are distinct, that each one
    // retrieves the child it named, and that the bytes did not get mixed up.
    expect(first == "page.txt", "The first child did not get its preferred name.")
    expect(Set([first, second, third]).count == 3,
           "Three children with one preferred name did not get three distinct keys.")
    expect(directory.fileWrappers?.count == 3, "A directory dropped a colliding child.")
    expect(directory.fileWrappers?[first]?.regularFileContents == Data("one".utf8),
           "The first child's bytes are under the wrong key.")
    expect(directory.fileWrappers?[second]?.regularFileContents == Data("two".utf8),
           "The second child's bytes are under the wrong key.")
    expect(directory.fileWrappers?[third]?.regularFileContents == Data("three".utf8),
           "The third child's bytes are under the wrong key.")

    guard let child = directory.fileWrappers?[second] else {
        expect(false, "A colliding child could not be fetched back.")
        return
    }
    expect(directory.keyForChildFileWrapper(child) == second,
           "keyForChildFileWrapper(_:) disagreed with the key addFileWrapper returned.")

    directory.removeFileWrapper(child)
    expect(directory.fileWrappers?.count == 2, "removeFileWrapper(_:) did not remove the child.")
    expect(directory.keyForChildFileWrapper(child) == nil,
           "A removed child still reports a key.")
}

func testFileWrapperSerializationRoundTrips() {
    let bundle = FileWrapper(directoryWithFileWrappers: [
        "text.rtf": FileWrapper(regularFileWithContents: Data("body".utf8)),
        "Images": FileWrapper(directoryWithFileWrappers: [
            "cover.png": FileWrapper(regularFileWithContents: Data([1, 2, 3]))
        ])
    ])
    bundle.preferredFilename = "Note.notebundle"

    // The BYTES are deliberately not asserted: Apple's representation is a
    // private archive format and the core's is its own. What both guarantee —
    // and what callers rely on — is that a representation reconstitutes the
    // tree it came from.
    guard let bytes = bundle.serializedRepresentation else {
        expect(false, "A directory wrapper produced no serialized representation.")
        return
    }
    guard let restored = FileWrapper(serializedRepresentation: bytes) else {
        expect(false, "A serialized representation would not deserialize.")
        return
    }

    expect(restored.isDirectory, "A deserialized package was not a directory.")
    expect(restored.fileWrappers?.count == 2, "A deserialized package has the wrong child count.")
    expect(restored.fileWrappers?["text.rtf"]?.regularFileContents == Data("body".utf8),
           "A deserialized child lost its bytes.")
    expect(restored.fileWrappers?["Images"]?.fileWrappers?["cover.png"]?.regularFileContents
           == Data([1, 2, 3]),
           "A deserialized nested child lost its bytes.")
}

func testDocumentReadFailuresReportCocoaErrors() {
    // Measured against real AppKit (Docs/NSDOCUMENT_PLAN.md § Ground Truth):
    // opening a file that is not there reports NSCocoaErrorDomain code 260.
    // Applications branch on exactly this, so the port has to match it rather
    // than inventing an error of its own — which is what it used to do.
    let document = TextContractDocument()
    let missing = FileManager.default.temporaryDirectory
        .appendingPathComponent("chocolate-no-such-document.txt")
    try? FileManager.default.removeItem(at: missing)

    var thrown: Error?
    do {
        try document.read(from: missing, ofType: "txt")
    } catch {
        thrown = error
    }

    guard let error = thrown as? NSError else {
        expect(false, "Reading a missing document did not throw an NSError.")
        return
    }
    expect(error.domain == "NSCocoaErrorDomain",
           "A missing-file read reported domain \(error.domain), not NSCocoaErrorDomain.")
    expect(error.code == 260,
           "A missing-file read reported code \(error.code), not Apple's 260.")
    expect(error.localizedDescription.contains("chocolate-no-such-document.txt"),
           "A missing-file error did not name the file it concerned.")
    expect(document.fileURL == nil,
           "A failed read still adopted the file URL.")
}

// MARK: - Phase 2: responder-chain routing
//
// The milestone these guard: a menu item with NO target and the action
// `saveDocument:` saves the front document. That is how every document-based
// AppKit app's File menu is wired, ActiveUI's included, so if this is broken
// the menu items look perfectly correct and do nothing at all.

/// A document that records what it was asked to do, without touching disk.
///
/// The `@unchecked Sendable` is restated because `NSDocument` carries it and
/// Swift requires a subclass to say so again.
final class ChainProbeDocument: NSDocument, @unchecked Sendable {
    nonisolated(unsafe) var saveCalls = 0
    nonisolated(unsafe) var saveAsCalls = 0

    override func save(_ sender: Any?) {
        saveCalls += 1
    }

    override func saveAs(_ sender: Any?) {
        saveAsCalls += 1
    }
}

@MainActor
func testNilTargetSaveReachesTheDocumentThroughTheChain() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 320, 200),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false
    )
    let controller = NSWindowController(window: window)
    let document = ChainProbeDocument()
    document.addWindowController(controller)
    window.makeKeyAndOrderFront(nil)

    // The link measured on real AppKit: a window's next responder is its
    // window controller.
    expect(window.windowController === controller,
           "Creating a controller with a window did not link the window back to it.")
    expect(window.nextResponder === controller,
           "A window's nextResponder is not its window controller.")

    // And the hinge: the controller offers its document to the chain. The
    // selector is Apple's OBJECTIVE-C name — the Swift method is save(_:).
    let saveSelector = Selector("saveDocument:")
    expect(document.responds(to: saveSelector),
           "A document does not respond to Apple's saveDocument: selector.")
    expect(controller.supplementalTarget(forAction: saveSelector, sender: nil) as? NSDocument === document,
           "A window controller did not offer its document as a supplemental target.")

    // Now the whole point: no target at all, and the document still saves.
    let delivered = NSApplication.shared.sendAction(saveSelector, to: nil, from: nil)
    expect(delivered, "A nil-target saveDocument: was not delivered to anything.")
    expect(document.saveCalls == 1,
           "A nil-target saveDocument: did not reach the document (saveCalls == \(document.saveCalls)).")

    expect(NSApplication.shared.target(forAction: saveSelector) as? NSDocument === document,
           "target(forAction:) disagrees with where sendAction actually delivered.")

    _ = NSApplication.shared.sendAction(Selector("saveDocumentAs:"), to: nil, from: nil)
    expect(document.saveAsCalls == 1, "A nil-target saveDocumentAs: did not reach the document.")

    document.removeWindowController(controller)
    window.close()
}

@MainActor
func testNilTargetDocumentActionsReachTheDocumentController() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    // `shared` here is whichever controller this suite created first, which is
    // AppKit's own rule for the shared controller.
    let controller = NSDocumentController.shared
    let before = controller.documents.count

    let delivered = NSApplication.shared.sendAction(Selector("newDocument:"), to: nil, from: nil)
    expect(delivered, "A nil-target newDocument: was not delivered to anything.")
    expect(controller.documents.count == before + 1,
           "A nil-target newDocument: did not reach the shared document controller.")

    expect(NSApplication.shared.target(forAction: Selector("newDocument:")) as? NSDocumentController === controller,
           "target(forAction:) did not resolve newDocument: to the document controller.")

    // Tidy up so later tests see the list they expect.
    if let made = controller.documents.last {
        controller.removeDocument(made)
    }
}

@MainActor
func testMenuValidationAsksTheChainForNilTargetItems() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
    }

    let menu = NSMenu(title: "File")
    let saveItem = NSMenuItem(title: "Save", action: Selector("saveDocument:"), keyEquivalent: "s")
    let nonsenseItem = NSMenuItem(title: "Nonsense", action: Selector("noSuchAction:"), keyEquivalent: "")
    menu.addItem(saveItem)
    menu.addItem(nonsenseItem)

    // With no document anywhere, neither item has a handler.
    menu.update()
    expect(!nonsenseItem.isEnabled,
           "An item whose action nothing handles was left enabled.")

    // Put a document on screen; now Save has somewhere to go.
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 320, 200),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false
    )
    let controller = NSWindowController(window: window)
    let document = ChainProbeDocument()
    document.addWindowController(controller)
    window.makeKeyAndOrderFront(nil)

    menu.update()
    expect(saveItem.isEnabled,
           "Save stayed disabled even though the chain reaches a document.")

    document.removeWindowController(controller)
    window.close()
}

// MARK: - Phases 3–5: the document surface itself

/// A document whose bytes are its text, for exercising the read/write ladder.
final class LadderDocument: NSDocument, @unchecked Sendable {
    nonisolated(unsafe) var text = ""

    override class var readableTypes: [String] { ["txt"] }
    override class var writableTypes: [String] { ["txt"] }

    override func data(ofType typeName: String) throws -> Data {
        Data(text.utf8)
    }

    override func read(from data: Data, ofType typeName: String) throws {
        text = String(decoding: data, as: UTF8.self)
    }
}

func testChangeCountUndoingBackToCleanLeavesDocumentUnedited() {
    let document = LadderDocument()
    expect(!document.isDocumentEdited, "A new document should not be edited.")

    // The behaviour a boolean flag could never produce, and the reason AppKit
    // keeps an integer: three edits undone three times is CLEAN, so quitting
    // asks nothing about a file that is byte-for-byte unchanged.
    document.updateChangeCount(.changeDone)
    document.updateChangeCount(.changeDone)
    document.updateChangeCount(.changeDone)
    expect(document.isDocumentEdited, "Three changes did not mark the document edited.")

    document.updateChangeCount(.changeUndone)
    expect(document.isDocumentEdited, "Undoing one of three changes should leave it edited.")
    document.updateChangeCount(.changeUndone)
    document.updateChangeCount(.changeUndone)
    expect(!document.isDocumentEdited,
           "Undoing every change must leave the document clean, not merely 'edited'.")

    document.updateChangeCount(.changeRedone)
    expect(document.isDocumentEdited, "Redoing a change did not mark the document edited again.")

    document.updateChangeCount(.changeCleared)
    expect(!document.isDocumentEdited, "changeCleared did not clear the edited state.")
}

func testChangeCountTokenKeepsEditsMadeDuringASave() {
    let document = LadderDocument()
    document.updateChangeCount(.changeDone)

    // A save captures the count it is about to write…
    let token = document.changeCountToken(for: .saveOperation)
    // …and the user types again before the write finishes.
    document.updateChangeCount(.changeDone)
    document.updateChangeCount(withToken: token, for: .saveOperation)

    expect(document.isDocumentEdited,
           "An edit made during a save was lost: the document claims to be clean when it is not.")

    document.updateChangeCount(withToken: document.changeCountToken(for: .saveOperation),
                              for: .saveOperation)
    expect(!document.isDocumentEdited, "Saving the remaining edit did not clean the document.")
}

func testDocumentEnumRawValuesMatchApple() {
    // Measured from the macOS 26.4 SDK. Two of these are counter-intuitive and
    // were wrong in this framework's first draft: changeRedone is 5 rather than
    // sitting beside changeUndone, and autosaveElsewhere (3) comes BEFORE
    // autosaveInPlace (4).
    expect(NSDocument.ChangeType.changeDone.rawValue == 0, "changeDone must be 0.")
    expect(NSDocument.ChangeType.changeUndone.rawValue == 1, "changeUndone must be 1.")
    expect(NSDocument.ChangeType.changeCleared.rawValue == 2, "changeCleared must be 2.")
    expect(NSDocument.ChangeType.changeReadOtherContents.rawValue == 3, "changeReadOtherContents must be 3.")
    expect(NSDocument.ChangeType.changeAutosaved.rawValue == 4, "changeAutosaved must be 4.")
    expect(NSDocument.ChangeType.changeRedone.rawValue == 5, "changeRedone must be 5, not 3.")
    expect(NSDocument.ChangeType.changeDiscardable.rawValue == 256, "changeDiscardable must be 256.")

    expect(NSDocument.SaveOperationType.saveOperation.rawValue == 0, "saveOperation must be 0.")
    expect(NSDocument.SaveOperationType.saveAsOperation.rawValue == 1, "saveAsOperation must be 1.")
    expect(NSDocument.SaveOperationType.saveToOperation.rawValue == 2, "saveToOperation must be 2.")
    expect(NSDocument.SaveOperationType.autosaveElsewhereOperation.rawValue == 3,
           "autosaveElsewhereOperation must be 3 — it comes BEFORE autosaveInPlace.")
    expect(NSDocument.SaveOperationType.autosaveInPlaceOperation.rawValue == 4,
           "autosaveInPlaceOperation must be 4.")
    expect(NSDocument.SaveOperationType.autosaveAsOperation.rawValue == 5, "autosaveAsOperation must be 5.")
}

func testDocumentUndoManagerDefaultsMatchApple() {
    let document = LadderDocument()
    // Measured: hasUndoManager is true and undoManager is non-nil by default.
    expect(document.hasUndoManager, "hasUndoManager must default to true.")
    expect(document.undoManager != nil, "undoManager must be non-nil by default.")

    let manager = document.undoManager
    expect(document.undoManager === manager, "undoManager must not be rebuilt on each access.")

    document.undoManager = nil
    expect(!document.hasUndoManager, "Setting undoManager to nil did not clear hasUndoManager.")
    expect(document.undoManager == nil, "undoManager should stay nil once turned off.")
}

func testDocumentReadWriteLadderUsesFileWrapperRung() {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("chocolate-ladder-tests")
    try? FileManager.default.removeItem(at: root)
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let destination = root.appendingPathComponent("note.txt")
    let document = LadderDocument()
    document.text = "ladder"

    // write(to:ofType:) goes through fileWrapper(ofType:) → data(ofType:),
    // so a subclass overriding only the Data rung still writes correctly.
    do {
        try document.write(to: destination, ofType: "txt")
    } catch {
        expect(false, "Writing through the ladder threw: \(error)")
        return
    }
    expect((try? Data(contentsOf: destination)) == Data("ladder".utf8),
           "The ladder did not write the document's bytes.")

    // And reading comes back down the same three rungs.
    let reader = LadderDocument()
    do {
        try reader.read(from: destination, ofType: "txt")
    } catch {
        expect(false, "Reading through the ladder threw: \(error)")
        return
    }
    expect(reader.text == "ladder", "The ladder did not read the document's bytes.")
    expect(reader.fileURL == destination, "Reading did not record the file URL.")
    expect(reader.fileModificationDate != nil, "Reading did not record a modification date.")
}

func testWriteSafelyKeepsThePreviousFileWhenWritingFails() {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("chocolate-safewrite-tests")
    try? FileManager.default.removeItem(at: root)
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let destination = root.appendingPathComponent("note.txt")
    let good = LadderDocument()
    good.text = "original"
    try? good.write(to: destination, ofType: "txt")

    // A document that cannot produce bytes fails mid-save. The contract users
    // depend on is that the file already on disk survives it.
    let failing = FailingWriteDocument()
    failing.fileURL = destination
    var threw = false
    do {
        try failing.writeSafely(to: destination, ofType: "txt", for: .saveOperation)
    } catch {
        threw = true
    }

    expect(threw, "A failing write did not report an error.")
    expect((try? Data(contentsOf: destination)) == Data("original".utf8),
           "A failed save destroyed the previous version of the file.")
}

/// A document whose write always fails, for testing safe writing.
final class FailingWriteDocument: NSDocument, @unchecked Sendable {
    override func data(ofType typeName: String) throws -> Data {
        throw CocoaFileErrorProbe.failure
    }
}

/// A stand-in error for a document that cannot produce bytes.
enum CocoaFileErrorProbe: Error {
    case failure
}

@MainActor
func testUntitledDocumentsAreNumberedLikeAppKit() {
    let controller = LadderDocumentController()
    var made: [NSDocument] = []
    defer {
        for document in made {
            controller.removeDocument(document)
        }
    }

    // Measured: Untitled, Untitled 2, Untitled 3 — the first has no number.
    for _ in 0..<3 {
        guard let document = try? controller.makeUntitledDocument(ofType: "txt") else {
            expect(false, "makeUntitledDocument threw.")
            return
        }
        controller.addDocument(document)
        made.append(document)
    }

    expect(made[0].displayName == "Untitled", "The first untitled document must be 'Untitled'.")
    expect(made[1].displayName == "Untitled 2", "The second untitled document must be 'Untitled 2'.")
    expect(made[2].displayName == "Untitled 3", "The third untitled document must be 'Untitled 3'.")
    expect(made[0].defaultDraftName() == "Untitled",
           "defaultDraftName() is 'Untitled' for every draft, number included separately.")

    // Closing the middle one frees its number for reuse rather than marching on.
    controller.removeDocument(made[1])
    guard let replacement = try? controller.makeUntitledDocument(ofType: "txt") else {
        expect(false, "makeUntitledDocument threw.")
        return
    }
    controller.addDocument(replacement)
    made.append(replacement)
    expect(replacement.displayName == "Untitled 2",
           "A freed untitled number should be reused, not skipped.")
}

/// Supplies `LadderDocument` through AppKit's real `documentClass(forType:)`.
final class LadderDocumentController: NSDocumentController {
    override func documentClass(forType typeName: String) -> AnyClass? {
        LadderDocument.self
    }
    override var defaultType: String? { "txt" }
}

@MainActor
func testOpeningAnAlreadyOpenFileBringsItForwardInsteadOfDuplicating() {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("chocolate-reopen-tests")
    try? FileManager.default.removeItem(at: root)
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let url = root.appendingPathComponent("note.txt")
    try? Data("on disk".utf8).write(to: url)

    let controller = LadderDocumentController()
    var first: NSDocument?
    controller.openDocument(withContentsOf: url, display: false) { document, alreadyOpen, error in
        first = document
        expect(error == nil, "Opening a document reported an error.")
        expect(!alreadyOpen, "A freshly opened document should not report as already open.")
    }
    expect((first as? LadderDocument)?.text == "on disk", "Opening did not read the file.")

    // Two windows onto one file, each with its own unsaved changes, is a
    // data-loss bug — so a second open must find the first document.
    var second: NSDocument?
    controller.openDocument(withContentsOf: url, display: false) { document, alreadyOpen, _ in
        second = document
        expect(alreadyOpen, "Re-opening the same file did not report it as already open.")
    }
    expect(second === first, "Re-opening the same file created a second document for it.")
    expect(controller.documents.count == 1, "Re-opening the same file added a duplicate document.")
    expect(controller.recentDocumentURLs.first == url, "Opening did not note the recent document.")

    first?.close()
}

@MainActor
func testDocumentValidationDisablesActionsThatCannotWork() {
    let document = LadderDocument()

    let save = NSMenuItem(title: "Save", action: Selector("saveDocument:"), keyEquivalent: "s")
    let revert = NSMenuItem(title: "Revert", action: Selector("revertDocumentToSaved:"), keyEquivalent: "")
    let printItem = NSMenuItem(title: "Print", action: Selector("printDocument:"), keyEquivalent: "p")

    // Never saved: Save is available (it becomes Save As), Revert is not —
    // there is nothing to revert to.
    expect(document.validateUserInterfaceItem(save),
           "Save must stay available for a document that has never been saved.")
    expect(!document.validateUserInterfaceItem(revert),
           "Revert must be disabled with no file to revert to.")

    // The base class has no print operation, so Print stays disabled rather
    // than printing a blank page.
    expect(!document.validateUserInterfaceItem(printItem),
           "Print must be disabled when the document has no print operation.")

    document.fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("x.txt")
    expect(!document.validateUserInterfaceItem(save),
           "Save must be disabled for a saved document with no changes.")
    expect(!document.validateUserInterfaceItem(revert),
           "Revert must be disabled for a document with no changes.")

    document.updateChangeCount(.changeDone)
    expect(document.validateUserInterfaceItem(save), "Save must be enabled for a dirty document.")
    expect(document.validateUserInterfaceItem(revert), "Revert must be enabled for a dirty saved document.")
}

@MainActor
func testWindowControllerLoadsItsWindowLazilyLikeAppKit() {
    // MEASURED CONTRACT: with a windowNibName, isWindowLoaded is false until
    // `window` is first read; that read runs windowWillLoad → loadWindow →
    // windowDidLoad exactly once, and later reads do not reload.
    // The single-argument form, which makes the controller its own owner.
    // Apple types the two-argument form's `owner` as a non-optional `Any`, so
    // there is no nil to pass — a divergence this framework had until the demo
    // caught it.
    let controller = LazyLoadingController(windowNibName: NSNib.Name("NoSuchNib"))
    expect(!controller.isWindowLoaded, "A controller with a nib name must not load its window eagerly.")
    expect(controller.loadWindowCalls == 0, "loadWindow() ran before the window was asked for.")

    let window = controller.window
    expect(window != nil, "Reading `window` did not produce one.")
    expect(controller.isWindowLoaded, "The window did not report as loaded after the first read.")
    expect(controller.loadWindowCalls == 1, "loadWindow() must run exactly once.")
    expect(controller.willLoadCalls == 1, "windowWillLoad() must run exactly once.")
    expect(controller.didLoadCalls == 1, "windowDidLoad() must run exactly once.")

    _ = controller.window
    expect(controller.loadWindowCalls == 1, "Reading `window` again reloaded it.")

    // A controller handed a window up front is loaded from the start.
    let direct = NSWindowController(window: NSWindow(
        contentRect: NSMakeRect(0, 0, 10, 10),
        styleMask: [.titled], backing: .buffered, defer: false))
    expect(direct.isWindowLoaded, "init(window:) must report the window as loaded.")
    expect(direct.windowNibName == nil, "init(window:) must leave windowNibName nil.")
}

/// A controller that builds its window in code, to isolate load timing.
final class LazyLoadingController: NSWindowController {
    nonisolated(unsafe) var loadWindowCalls = 0
    nonisolated(unsafe) var willLoadCalls = 0
    nonisolated(unsafe) var didLoadCalls = 0

    override func loadWindow() {
        loadWindowCalls += 1
        window = NSWindow(contentRect: NSMakeRect(0, 0, 100, 100),
                          styleMask: [.titled], backing: .buffered, defer: false)
    }

    override func windowWillLoad() {
        willLoadCalls += 1
    }

    override func windowDidLoad() {
        didLoadCalls += 1
    }
}

/// A delegate that records and can veto termination.
final class TerminateProbeDelegate: NSObject, NSApplicationDelegate {
    nonisolated(unsafe) var asked = 0
    nonisolated(unsafe) var willTerminateCalls = 0
    nonisolated(unsafe) var reply = NSApplication.TerminateReply.terminateNow

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        asked += 1
        return reply
    }

    func applicationWillTerminate(_ notification: Notification) {
        willTerminateCalls += 1
    }
}

@MainActor
func testQuitReviewsUnsavedDocumentsBeforeAskingTheDelegate() {
    let backend = InMemoryNativeControlBackend()
    let application = NSApplication.shared
    let previousBackend = application.nativeBackend
    let previousDelegate = application.delegate
    application.nativeBackend = backend
    let probe = TerminateProbeDelegate()
    application.delegate = probe
    defer {
        application.nativeBackend = previousBackend
        application.delegate = previousDelegate
    }

    let controller = NSDocumentController.shared
    let document = LadderDocument()
    controller.addDocument(document)
    document.updateChangeCount(.changeDone)
    defer {
        document.updateChangeCount(.changeCleared)
        controller.removeDocument(document)
    }

    // ORDER MATTERS, and it is Apple's: unsaved documents are reviewed FIRST.
    // Cancelling the save prompt stops the quit before the delegate is ever
    // asked — reviewing afterwards would mean Cancel could not stop a quit
    // that was already under way.
    backend.nextModalResponseCode = NSApplication.ModalResponse.alertSecondButtonReturn.rawValue
    application.terminate(nil)
    expect(probe.asked == 0,
           "Cancelling the save prompt must stop the quit before the delegate is consulted.")
    expect(probe.willTerminateCalls == 0, "A cancelled quit still told the delegate it was terminating.")
    expect(!backend.didTerminateApplication, "A cancelled quit still terminated the application.")

    // Don't Save lets the review through, and then the delegate gets its say.
    backend.nextModalResponseCode = NSApplication.ModalResponse.alertThirdButtonReturn.rawValue
    probe.reply = .terminateCancel
    application.terminate(nil)
    expect(probe.asked == 1, "The delegate was not asked once the documents were reviewed.")
    expect(!backend.didTerminateApplication, "applicationShouldTerminate returning .terminateCancel did not stop the quit.")

    // .terminateLater defers until the delegate answers.
    backend.nextModalResponseCode = NSApplication.ModalResponse.alertThirdButtonReturn.rawValue
    probe.reply = .terminateLater
    document.updateChangeCount(.changeDone)
    application.terminate(nil)
    expect(!backend.didTerminateApplication, ".terminateLater terminated immediately instead of deferring.")

    application.reply(toApplicationShouldTerminate: true)
    expect(backend.didTerminateApplication, "reply(toApplicationShouldTerminate: true) did not complete the quit.")
    expect(probe.willTerminateCalls == 1, "Completing a deferred quit did not tell the delegate.")
}

func testTerminateReplyRawValuesMatchApple() {
    expect(NSApplication.TerminateReply.terminateCancel.rawValue == 0, "terminateCancel must be 0.")
    expect(NSApplication.TerminateReply.terminateNow.rawValue == 1, "terminateNow must be 1.")
    expect(NSApplication.TerminateReply.terminateLater.rawValue == 2, "terminateLater must be 2.")
}

// MARK: - Phase 6: the same document API over a very different filesystem

/// A filesystem made of a dictionary — what a browser tab actually has.
final class MemoryFileStore: ChocolateFileStore {
    nonisolated(unsafe) var files: [String: [UInt8]] = [:]
    nonisolated(unsafe) var writeCount = 0

    func fileExists(atPath path: String) -> Bool { files[path] != nil }
    func contents(atPath path: String) -> [UInt8]? { files[path] }
    func write(_ bytes: [UInt8], toPath path: String) {
        files[path] = bytes
        writeCount += 1
    }
    func removeFile(atPath path: String) { files.removeValue(forKey: path) }
    var allPaths: [String] { files.keys.sorted() }
}

@MainActor
func testDocumentsRoundTripThroughASubstituteFilesystem() {
    // The golden rule in one test: the SAME NSDocument code that saves to disk
    // on Windows, Linux and macOS has to work in a browser tab, which has no
    // filesystem at all. The seam is what makes that true — a backend installs
    // a substitute store and nothing in NSDocument changes.
    let store = MemoryFileStore()
    let previous = ChocolateFileAccess.substitute
    ChocolateFileAccess.substitute = store
    defer { ChocolateFileAccess.substitute = previous }

    expect(ChocolateFileAccess.usesSubstitute,
           "Installing a store did not switch file access onto it.")

    let url = URL(fileURLWithPath: "/Untitled.txt")
    let document = LadderDocument()
    document.text = "written in a browser"

    do {
        try document.writeSafely(to: url, ofType: "txt", for: .saveOperation)
    } catch {
        expect(false, "Saving into a substitute filesystem threw: \(error)")
        return
    }

    expect(store.fileExists(atPath: "/Untitled.txt"),
           "A document saved into the substitute store left no file.")
    expect(store.contents(atPath: "/Untitled.txt").map { String(decoding: $0, as: UTF8.self) }
           == "written in a browser",
           "A document's bytes did not reach the substitute store intact.")

    // And it reads back — which is what a reload in a browser tab depends on.
    let reader = LadderDocument()
    do {
        try reader.read(from: url, ofType: "txt")
    } catch {
        expect(false, "Reading back from a substitute filesystem threw: \(error)")
        return
    }
    expect(reader.text == "written in a browser",
           "A document read back from the substitute store lost its contents.")
    expect(reader.fileURL == url, "Reading back did not record the file URL.")

    // Overwriting must not go through atomic staging: there is no half-written
    // state to protect against, and a staging file would litter the store.
    document.text = "second version"
    try? document.writeSafely(to: url, ofType: "txt", for: .saveOperation)
    expect(store.allPaths == ["/Untitled.txt"],
           "Saving over a file in a substitute store left staging files behind: \(store.allPaths)")
    expect(store.contents(atPath: "/Untitled.txt").map { String(decoding: $0, as: UTF8.self) }
           == "second version",
           "Overwriting in the substitute store did not replace the contents.")

    // A missing file still reports Apple's error, whatever is underneath.
    var thrown: Error?
    do {
        try LadderDocument().read(from: URL(fileURLWithPath: "/nope.txt"), ofType: "txt")
    } catch {
        thrown = error
    }
    expect((thrown as? NSError)?.code == 260,
           "A missing file in the substitute store did not report Apple's code 260.")
}

@MainActor
func testWindowDocumentChromeReachesTheBackend() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 200, 120),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let handle = window.realizeNativePeer()

    // The API is Apple's — a flag, not a decorated title — and each backend
    // renders it its own way: an asterisk on Win32/GTK/WASM, a close-button dot
    // on macOS. What the framework guarantees is that the flag arrives.
    window.title = "Report.txt"
    window.isDocumentEdited = true
    expect(backend.documentEditedWindows[handle] == true,
           "isDocumentEdited did not reach the backend.")
    expect(window.title == "Report.txt",
           "Marking a document edited must not rewrite the window's title.")

    window.representedURL = URL(fileURLWithPath: "/docs/Report.txt")
    expect(backend.representedPaths[handle] == "/docs/Report.txt",
           "representedURL did not reach the backend.")
    expect(window.representedFilename == "/docs/Report.txt",
           "representedFilename must reflect representedURL.")

    window.isDocumentEdited = false
    expect(backend.documentEditedWindows[handle] == false,
           "Clearing isDocumentEdited did not reach the backend.")

    window.close()
}
