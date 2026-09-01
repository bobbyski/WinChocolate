// The base class's "you must override this" behaviour.
//
// Measured, not guessed (Docs/NSDOCUMENT_PLAN.md § Ground Truth): calling
// `NSDocument().data(ofType:)` on real AppKit does NOT throw. It raises
// `NSInternalInconsistencyException` — "dataOfType:error: is a subclass
// responsibility but has not been overridden." — and the process dies.
//
// There is no Objective-C runtime here to raise through, so the faithful
// analogue of an unhandled exception is a trap carrying Apple's own message.
// This replaces the former `NSDocumentError.unimplemented`, which was invented
// surface: it made a programmer error look like a recoverable failure, and it
// existed on the false premise that `NSError` was unavailable (it is not — see
// Dialogs/NSAlert.swift and WinFoundation/NSError.swift).

/// Traps with AppKit's wording for an un-overridden required method.
///
/// - Parameter method: The Objective-C selector AppKit names in its message,
///   such as `"dataOfType:error:"`.
internal func nsDocumentSubclassResponsibility(_ method: String) -> Never {
    fatalError("\(method) is a subclass responsibility but has not been overridden.")
}

/// An abstract model object that owns, reads, and writes one document's data.
///
/// `NSDocument` is the model half of AppKit's document architecture. It knows
/// what a document *is* — its bytes, its file, whether it has unsaved changes —
/// and nothing about how it is displayed; that belongs to the window
/// controllers it makes.
///
/// ```
///   NSDocumentController          the registry: open documents, recents,
///          │                      New and Open
///          │ owns
///          ▼
///      NSDocument                 THIS TYPE: bytes, file identity, dirty state
///          │
///          │ makeWindowControllers()
///          ▼
///   NSWindowController…           one per window, each showing this document
///          │
///          └─ supplementalTarget ──▶ back to the document, which is how a
///                                    menu's saveDocument: reaches it
/// ```
///
/// **Subclassing.** The minimum is `data(ofType:)` and `read(from:ofType:)`,
/// plus `makeWindowControllers()` to put something on screen. Everything else
/// has a working default.
///
/// **Why this file is long.** Nearly every member below is `open`, because
/// nearly every member of Apple's is. Swift will not let an `open` method be
/// declared in an extension — a subclass cannot override it there — so a type
/// whose whole purpose is to be subclassed has to declare its overridable
/// surface in one class body. Splitting it across files was tried and reverted:
/// it produced 208 "cannot be overridden" warnings and would have made
/// `data(ofType:)` impossible to override, which is the one thing every
/// document subclass must do. The sections below are marked instead, and the
/// genuinely separable pieces — the enums, the selector table, the panel types —
/// do live in their own files. Logged in NEEDS_HUMAN.md.
open class NSDocument: NSObject, @unchecked Sendable {

    // MARK: - File identity

    /// The document's on-disk location, when saved or opened.
    open var fileURL: URL? {
        didSet {
            guard fileURL != oldValue else {
                return
            }
            synchronizeWindowTitles()
        }
    }

    /// The document's type name, when known.
    open var fileType: String?

    /// When the document's file was last modified, as far as this document knows.
    open var fileModificationDate: Date?

    /// The most recent save or write failure.
    ///
    /// Not AppKit surface. Menu-driven `save(_:)`/`saveAs(_:)` cannot throw, and
    /// AppKit presents such failures in an alert; this additionally records the
    /// last one so a test — or an app that would rather handle it quietly — can
    /// see what went wrong. `presentError(_:)` is the AppKit-shaped path.
    public internal(set) var lastError: Error?

    // MARK: - Internal storage

    /// Backing store for an explicitly assigned display name.
    private var assignedDisplayName: String?

    /// The number distinguishing this untitled document from its siblings.
    ///
    /// 1 means "Untitled"; 2 and up append the number, which is what AppKit
    /// does — measured as `Untitled`, `Untitled 2`, `Untitled 3`. Assigned by
    /// `NSDocumentController.addDocument(_:)`, the only object that can see the
    /// other untitled documents.
    internal var untitledNumber = 1

    /// Backing store, so `undoManager` can hand one out lazily.
    private var storedUndoManager: NSUndoManager?

    /// How many un-cleared changes the document is carrying.
    internal var changeCount = 0

    /// The change count as of the last autosave.
    internal var changeCountAtLastAutosave = 0

    /// Backing store for `autosavedContentsFileURL`.
    internal var winAutosavedContentsFileURL: URL?

    /// The periodic autosave timer, when one is running.
    internal var winAutosaveTimer: Timer?

    /// The controller this document is registered with.
    ///
    /// AppKit's `close()` removes a document from the *shared* controller and
    /// nothing else, because it assumes a process has exactly one. That holds
    /// for applications and not for a test suite, where a document registered
    /// with a second controller could never be removed from it and the list
    /// grew forever. Remembering the registrar closes that hole and is
    /// indistinguishable from Apple's behaviour whenever there is only one
    /// controller — which is every real app.
    internal weak var owningController: NSDocumentController?

    /// Backing store for `printInfo`.
    private var storedPrintInfo: NSPrintInfo?

    // MARK: - Display name

    /// The name shown in window titles and save panels.
    ///
    /// Assigning nil restores the derived name — the file's name for a saved
    /// document, or the numbered draft name for an untitled one. That
    /// null-resettable behaviour is why AppKit types this `String!`.
    open var displayName: String! {
        get {
            if let assignedDisplayName {
                return assignedDisplayName
            }
            if let fileURL {
                return fileURL.lastPathComponent
            }
            let draft = defaultDraftName()
            return untitledNumber > 1 ? "\(draft) \(untitledNumber)" : draft
        }
        set {
            assignedDisplayName = newValue
            synchronizeWindowTitles()
        }
    }

    /// The base name given to a document that has never been saved.
    ///
    /// AppKit returns "Untitled" for every draft and appends the number
    /// separately — measured: `defaultDraftName()` is "Untitled" even for the
    /// document whose `displayName` is "Untitled 3".
    open func defaultDraftName() -> String {
        "Untitled"
    }

    // MARK: - Undo

    /// Whether this document keeps an undo manager.
    ///
    /// True by default, as AppKit's is (measured).
    open var hasUndoManager = true

    /// The document's undo manager, created on first use.
    ///
    /// Non-nil by default, matching AppKit. Setting nil turns undo off.
    open var undoManager: NSUndoManager? {
        get {
            guard hasUndoManager else {
                return nil
            }
            if storedUndoManager == nil {
                storedUndoManager = NSUndoManager()
            }
            return storedUndoManager
        }
        set {
            storedUndoManager = newValue
            hasUndoManager = newValue != nil
        }
    }

    // MARK: - Edited state

    /// Whether the document has unsaved changes.
    open var isDocumentEdited: Bool {
        changeCount != 0
    }

    /// Whether there are changes that have not been autosaved.
    open var hasUnautosavedChanges: Bool {
        changeCount != changeCountAtLastAutosave
    }

    /// Whether the document is open only for viewing, not editing.
    open internal(set) var isInViewingMode = false

    /// Whether the document's file is locked against writing.
    open internal(set) var isLocked = false

    /// Whether this document has never been saved anywhere the user chose.
    open var isDraft = false

    /// Records a change to the document's edited state.
    ///
    /// The count is an integer rather than a flag, exactly as AppKit's is, and
    /// that is the point: undoing back past every edit leaves the document
    /// **clean**, because the decrements cancel the increments. A boolean could
    /// never do that, and users notice — it is the difference between "undo
    /// everything, quit, no prompt" and a save prompt for an unchanged file.
    open func updateChangeCount(_ change: ChangeType) {
        switch change {
        case .changeDone, .changeRedone:
            changeCount += 1
        case .changeUndone:
            changeCount -= 1
        case .changeCleared:
            changeCount = 0
            changeCountAtLastAutosave = 0
        case .changeAutosaved:
            changeCountAtLastAutosave = changeCount
        case .changeReadOtherContents:
            // Re-reading from elsewhere makes memory and disk disagree.
            changeCount += 1
        case .changeDiscardable:
            // A modifier on another change rather than a change in itself.
            break
        }
        synchronizeWindowTitles()
    }

    /// Captures the document's change count before a save begins.
    ///
    /// The point is the edit that lands *while* the write is in flight.
    /// Clearing the count outright at the end of a save would throw that edit
    /// away and leave the document looking clean when it is not.
    open func changeCountToken(for saveOperation: SaveOperationType) -> Any {
        changeCount
    }

    /// Clears the changes a save captured, leaving any that arrived since.
    open func updateChangeCount(withToken changeCountToken: Any,
                                for saveOperation: SaveOperationType) {
        guard let captured = changeCountToken as? Int else {
            return
        }

        switch saveOperation {
        case .saveOperation, .saveAsOperation:
            // Subtract what the save wrote rather than zeroing, so an edit made
            // during the write survives it.
            changeCount -= captured
            changeCountAtLastAutosave = changeCount
        case .autosaveInPlaceOperation, .autosaveElsewhereOperation, .autosaveAsOperation:
            changeCountAtLastAutosave = captured
        case .saveToOperation:
            // A copy written elsewhere is not this document being saved.
            break
        }
        synchronizeWindowTitles()
    }

    // MARK: - Types

    /// The type identifiers this document class can open.
    open class var readableTypes: [String] { [] }

    /// The type identifiers this document class can save.
    open class var writableTypes: [String] { [] }

    /// The types this document can be saved as for a particular operation.
    open func writableTypes(for saveOperation: SaveOperationType) -> [String] {
        Self.writableTypes
    }

    /// Whether the document reads and writes this type itself.
    open class func isNativeType(_ type: String) -> Bool {
        readableTypes.contains(type)
    }

    /// Whether documents of this type can be read concurrently.
    ///
    /// False, as Apple's is. The framework is single-threaded by design.
    open class func canConcurrentlyReadDocuments(ofType typeName: String) -> Bool {
        false
    }

    /// The extension the save panel should append for a type.
    ///
    /// Nil by default. Apple answers "txt" for `public.plain-text` because it
    /// consults the UTType database; there is none here, so a document that
    /// knows its own extensions answers from them and everything else says it
    /// does not know rather than guessing.
    open func fileNameExtension(forType typeName: String,
                                saveOperation: SaveOperationType) -> String? {
        nil
    }

    // MARK: - Lifecycle

    /// Creates an empty document.
    ///
    /// `required` so `NSDocumentController` can instantiate its configured
    /// document class from a metatype.
    public required override init() {
        super.init()
    }

    /// Creates an empty document of a type.
    public convenience init(type typeName: String) throws {
        self.init()
        fileType = typeName
    }

    /// Creates a document by reading a file.
    public convenience init(contentsOf url: URL, ofType typeName: String) throws {
        self.init()
        try read(from: url, ofType: typeName)
        fileType = typeName
    }

    /// Creates a document that reads from one URL but belongs to another.
    ///
    /// The shape reopening uses: contents come from an autosaved copy while the
    /// document's identity stays the file the user knows about.
    public convenience init(for urlOrNil: URL?, withContentsOf contentsURL: URL,
                            ofType typeName: String) throws {
        self.init()
        try read(from: contentsURL, ofType: typeName)
        fileURL = urlOrNil
        fileType = typeName
    }

    // MARK: - Window controllers

    /// The window controllers presenting this document.
    open private(set) var windowControllers: [NSWindowController] = []

    /// The window a document-modal sheet should hang from.
    open var windowForSheet: NSWindow? {
        windowControllers.first { $0.window != nil }?.window
    }

    /// Creates this document's window controllers. Subclasses override.
    open func makeWindowControllers() {
    }

    /// The nib holding this document's window, when it uses one.
    open var windowNibName: NSNib.Name? {
        nil
    }

    /// Called before a window controller loads its nib.
    open func windowControllerWillLoadNib(_ windowController: NSWindowController) {
    }

    /// Called after a window controller loads its nib.
    open func windowControllerDidLoadNib(_ windowController: NSWindowController) {
    }

    /// Attaches a window controller to this document.
    open func addWindowController(_ windowController: NSWindowController) {
        guard !windowControllers.contains(where: { $0 === windowController }) else {
            return
        }
        windowControllers.append(windowController)
        windowController.document = self
    }

    /// Detaches a window controller from this document.
    open func removeWindowController(_ windowController: NSWindowController) {
        windowControllers.removeAll { $0 === windowController }
        if windowController.document === self {
            windowController.document = nil
        }
    }

    /// Shows all of the document's windows.
    open func showWindows() {
        for controller in windowControllers {
            controller.showWindow(nil)
        }
    }

    /// Pushes the document's name and edited state into every window.
    internal func synchronizeWindowTitles() {
        for controller in windowControllers {
            controller.synchronizeWindowTitleWithDocumentName()
            controller.setDocumentEdited(isDocumentEdited)
        }
    }

    // MARK: - Reading
    //
    // AppKit gives a document three rungs to override, and which one a subclass
    // picks is the whole design decision:
    //
    //     read(from: Data, ofType:)         a document that is one blob of bytes
    //     read(from: FileWrapper, ofType:)  a document that is a folder of files
    //     read(from: URL, ofType:)          a document that wants the file itself
    //
    // Each default is written in terms of the rung below it, so a subclass
    // overrides exactly one and the other two keep working.

    /// Loads document contents from a file URL and records the file identity.
    ///
    /// Default behaviour: reads the item into a `FileWrapper` and hands it to
    /// `read(from:ofType:)`.
    ///
    /// - Throws: An `NSError` in `NSCocoaErrorDomain`, with the same domain and
    ///   code AppKit reports, because applications branch on them and show them
    ///   to people through `NSAlert(error:)`.
    open func read(from url: URL, ofType typeName: String) throws {
        guard ChocolateFileAccess.fileExists(atPath: url.path) else {
            throw CocoaFileError.error(CocoaFileError.readNoSuchFile, url: url,
                                       reason: "The file doesn’t exist.")
        }

        let wrapper: FileWrapper
        do {
            wrapper = try FileWrapper(url: url, options: .immediate)
        } catch let error as NSError where error.domain == CocoaFileError.domain {
            throw error
        } catch {
            throw CocoaFileError.error(CocoaFileError.readNoPermission, url: url,
                                       reason: "The file couldn’t be read.")
        }

        // A subclass that cannot make sense of the contents throws its own
        // error; it is deliberately not rewritten here, because only the
        // subclass knows whether the trouble was the format, the encoding, or
        // something else entirely.
        try read(from: wrapper, ofType: typeName)

        fileURL = url
        fileType = typeName
        fileModificationDate = Date()
    }

    /// Loads document contents from a file wrapper.
    ///
    /// Default behaviour: a regular file's bytes go to `read(from:ofType:)`;
    /// anything else is a document package, which the base class cannot
    /// interpret, so a subclass that saves as a package overrides this rung.
    open func read(from fileWrapper: FileWrapper, ofType typeName: String) throws {
        guard let contents = fileWrapper.regularFileContents else {
            throw CocoaFileError.error(
                CocoaFileError.readCorruptFile,
                url: URL(fileURLWithPath: fileWrapper.filename ?? "document"),
                reason: "This document is a package, and its class does not read packages. "
                        + "Override read(from:ofType:) taking a FileWrapper.")
        }
        try read(from: contents, ofType: typeName)
    }

    /// Loads document contents from data. Subclasses must override.
    ///
    /// The bottom rung, and the one most documents override. Traps rather than
    /// throwing, as AppKit raises.
    open func read(from data: Data, ofType typeName: String) throws {
        nsDocumentSubclassResponsibility("readFromData:ofType:error:")
    }

    /// Re-reads the document from a file, discarding unsaved changes.
    open func revert(toContentsOf url: URL, ofType typeName: String) throws {
        try read(from: url, ofType: typeName)
        updateChangeCount(.changeCleared)
    }

    /// Whether the document holds its file's entire contents in memory.
    ///
    /// True here and true on Apple by default (measured).
    open var isEntireFileLoaded: Bool {
        true
    }

    // MARK: - Writing

    /// Returns the document's data for writing. Subclasses must override.
    open func data(ofType typeName: String) throws -> Data {
        nsDocumentSubclassResponsibility("dataOfType:error:")
    }

    /// Returns the document's contents as a file wrapper.
    ///
    /// Default behaviour: wraps `data(ofType:)`. A document that saves as a
    /// package overrides this instead and never implements `data(ofType:)`.
    open func fileWrapper(ofType typeName: String) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try data(ofType: typeName))
    }

    /// Writes the document to a file URL.
    open func write(to url: URL, ofType typeName: String) throws {
        try write(to: url, ofType: typeName, for: .saveOperation, originalContentsURL: nil)
    }

    /// Writes the document, told which kind of save this is.
    ///
    /// The `saveOperation` matters to subclasses: a `saveToOperation` is a copy
    /// going somewhere else and must not disturb the document's own state.
    open func write(to url: URL,
                    ofType typeName: String,
                    for saveOperation: SaveOperationType,
                    originalContentsURL absoluteOriginalContentsURL: URL?) throws {
        let wrapper = try fileWrapper(ofType: typeName)
        do {
            try wrapper.write(to: url, options: [],
                              originalContentsURL: absoluteOriginalContentsURL)
        } catch let error as NSError where error.domain == CocoaFileError.domain {
            throw error
        } catch {
            throw CocoaFileError.error(CocoaFileError.writeNoPermission, url: url,
                                       reason: "The file couldn’t be written.")
        }
    }

    /// Writes the document so that a failure cannot destroy the previous version.
    ///
    /// The contract users actually depend on: if the disk fills up or the
    /// process dies mid-write, the file that was already there must still be
    /// there. Writes beside the destination and moves the finished result into
    /// place, keeping a backup first when `keepBackupFile` asks for one.
    open func writeSafely(to url: URL,
                          ofType typeName: String,
                          for saveOperation: SaveOperationType) throws {
        let manager = FileManager.default

        guard ChocolateFileAccess.fileExists(atPath: url.path) else {
            // Nothing to lose: write straight to the destination.
            try write(to: url, ofType: typeName, for: saveOperation, originalContentsURL: nil)
            return
        }

        // The staging dance below is a filesystem protection; a substitute
        // store has no half-written state to guard against.
        if ChocolateFileAccess.usesSubstitute {
            try write(to: url, ofType: typeName, for: saveOperation, originalContentsURL: url)
            return
        }

        if keepBackupFile, let backup = backupFileURL {
            try? manager.removeItem(at: backup)
            try? manager.copyItem(at: url, to: backup)
        }

        // A sibling rather than the temp directory, so the final move stays on
        // one volume — a cross-device move is a copy that can fail half way,
        // which is the very thing this method exists to prevent.
        let staging = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.lastPathComponent).saving")
        try? manager.removeItem(at: staging)

        do {
            try write(to: staging, ofType: typeName, for: saveOperation, originalContentsURL: url)
        } catch {
            try? manager.removeItem(at: staging)
            throw error
        }

        do {
            try manager.removeItem(at: url)
            try manager.moveItem(at: staging, to: url)
        } catch {
            try? manager.removeItem(at: staging)
            throw CocoaFileError.error(CocoaFileError.writeUnknown, url: url,
                                       reason: "The saved file couldn’t be moved into place.")
        }
    }

    /// Whether saving keeps the previous version alongside the new one.
    ///
    /// False, as Apple's is (measured).
    open var keepBackupFile: Bool {
        false
    }

    /// Where `keepBackupFile` puts the previous version.
    open var backupFileURL: URL? {
        guard let fileURL else {
            return nil
        }
        return fileURL.deletingLastPathComponent()
            .appendingPathComponent("\(fileURL.lastPathComponent)~")
    }

    /// File attributes to apply to a file this document writes.
    open func fileAttributesToWrite(to url: URL,
                                    ofType typeName: String,
                                    for saveOperation: SaveOperationType,
                                    originalContentsURL absoluteOriginalContentsURL: URL?) throws -> [String: Any] {
        [:]
    }

    /// Whether this document can be written off the main thread.
    ///
    /// False: the framework is single-threaded by design.
    open func canAsynchronouslyWrite(to url: URL,
                                     ofType typeName: String,
                                     for saveOperation: SaveOperationType) -> Bool {
        false
    }

    // MARK: - Saving
    //
    // The Swift names look mismatched with the selectors and are not. Apple's
    // Swift name for `saveDocument:` is `save(_:)` — the importer renamed it in
    // Swift 3, and `#selector(NSDocument.save(_:))` really does print
    // "saveDocument:" (measured). The selector names live in the dispatch table
    // in NSDocumentValidation.swift.

    /// Saves the document, asking for a destination when it has none.
    open func save(_ sender: Any?) {
        guard fileURL != nil else {
            // Never saved: this is really a Save As.
            runModalSavePanel(for: .saveOperation)
            return
        }
        performSave(to: fileURL, ofType: fileType, for: .saveOperation)
    }

    /// Saves to a destination chosen in a panel, which becomes the document's.
    open func saveAs(_ sender: Any?) {
        runModalSavePanel(for: .saveAsOperation)
    }

    /// Writes a copy elsewhere, leaving the document pointing at its own file.
    ///
    /// The difference from Save As is why both exist: this one is "give me a
    /// copy over there" and must not change what the window is editing.
    open func saveTo(_ sender: Any?) {
        runModalSavePanel(for: .saveToOperation)
    }

    /// Discards unsaved changes and re-reads the document from its file.
    ///
    /// Asks first, as AppKit does — this throws away the user's work.
    open func revertToSaved(_ sender: Any?) {
        guard let fileURL else {
            return
        }

        if isDocumentEdited {
            let alert = NSAlert()
            alert.messageText = "Do you want to revert to the most recently saved version of "
                + "“\(displayName ?? "this document")”?"
            alert.informativeText = "Your current changes will be lost."
            alert.addButton(withTitle: "Revert")
            alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else {
                return
            }
        }

        do {
            try revert(toContentsOf: fileURL, ofType: fileType ?? fileURL.pathExtension)
            lastError = nil
        } catch {
            lastError = error
            presentError(error)
        }
    }

    /// Saves to a URL and reports the outcome to a completion handler.
    ///
    /// The write is synchronous — the framework is single-threaded by design —
    /// so the handler is called before this returns, with nil for success.
    open func save(to url: URL,
                   ofType typeName: String,
                   for saveOperation: SaveOperationType,
                   completionHandler: (Error?) -> Void) {
        let token = changeCountToken(for: saveOperation)
        do {
            try writeSafely(to: url, ofType: typeName, for: saveOperation)
        } catch {
            lastError = error
            completionHandler(error)
            return
        }
        adoptSaveResult(url: url, typeName: typeName, operation: saveOperation, token: token)
        completionHandler(nil)
    }

    /// Saves and reports the outcome by sending a selector to a delegate.
    open func save(withDelegate delegate: Any?,
                   didSave didSaveSelector: Selector?,
                   contextInfo: UnsafeMutableRawPointer?) {
        let wasEdited = isDocumentEdited
        save(nil)
        let succeeded = wasEdited ? !isDocumentEdited : lastError == nil
        notify(delegate, didSaveSelector, succeeded: succeeded, contextInfo: contextInfo)
    }

    /// Runs a save panel and saves to whatever it returns.
    open func runModalSavePanel(for saveOperation: SaveOperationType,
                                delegate: Any? = nil,
                                didSave didSaveSelector: Selector? = nil,
                                contextInfo: UnsafeMutableRawPointer? = nil) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = displayName ?? defaultDraftName()

        let typeName = fileType ?? writableTypes(for: saveOperation).first ?? ""
        if let suggested = fileNameExtension(forType: typeName, saveOperation: saveOperation) {
            panel.allowedFileTypes = [suggested]
        }
        if let directory = fileURL?.deletingLastPathComponent() {
            panel.directoryURL = directory
        }

        guard prepareSavePanel(panel) else {
            notify(delegate, didSaveSelector, succeeded: false, contextInfo: contextInfo)
            return
        }

        guard panel.runModal() == .OK, let url = panel.url else {
            // A cancelled panel is not a failure, and must not raise an alert.
            notify(delegate, didSaveSelector, succeeded: false, contextInfo: contextInfo)
            return
        }

        fileNameExtensionWasHiddenInLastRunSavePanel = panel.isExtensionHidden
        fileTypeFromLastRunSavePanel = typeName.isEmpty ? nil : typeName

        performSave(to: url, ofType: typeName.isEmpty ? url.pathExtension : typeName,
                    for: saveOperation)
        notify(delegate, didSaveSelector, succeeded: lastError == nil, contextInfo: contextInfo)
    }

    /// Lets a subclass configure the save panel before it runs.
    ///
    /// Return false to abandon the save entirely.
    open func prepareSavePanel(_ savePanel: NSSavePanel) -> Bool {
        true
    }

    /// Whether the save panel offers a file-format chooser.
    open var savePanelShowsFileFormatsControl: Bool {
        writableTypes(for: .saveAsOperation).count > 1
    }

    /// Whether the save panel should show the document's accessory view.
    ///
    /// Deprecated on Apple in favour of `savePanelShowsFileFormatsControl`, and
    /// kept for the same reason Apple keeps it: ported code calls it.
    open var shouldRunSavePanelWithAccessoryView: Bool {
        savePanelShowsFileFormatsControl
    }

    /// Whether the last save panel hid the file's extension.
    open internal(set) var fileNameExtensionWasHiddenInLastRunSavePanel = false

    /// The type chosen in the last save panel, when it offered a choice.
    open internal(set) var fileTypeFromLastRunSavePanel: String?

    // MARK: - Autosaving
    //
    // This framework used to autosave every 30 seconds for any class returning
    // true from `autosavesInPlace`. That number was invented. Apple's
    // `NSDocumentController.autosavingDelay` defaults to 0.0 — measured — which
    // means AppKit does no periodic autosaving unless an application asks. An
    // app that never set a delay was getting disk writes it never requested.

    /// Whether documents of this class save automatically over their own file.
    ///
    /// False by default, as Apple's is (measured).
    open class var autosavesInPlace: Bool { false }

    /// Whether this class autosaves documents the user has not yet named.
    open class var autosavesDrafts: Bool { false }

    /// Whether this class keeps previous versions of a document.
    ///
    /// False, and a documented boundary: no platform here has a version store.
    open class var preservesVersions: Bool { false }

    /// Whether this class stores documents in a cloud container.
    ///
    /// False, and a documented boundary: iCloud has no analogue here.
    open class var usesUbiquitousStorage: Bool { false }

    /// Where the autosaved copy of this document lives, when there is one.
    open var autosavedContentsFileURL: URL? {
        get { winAutosavedContentsFileURL }
        set { winAutosavedContentsFileURL = newValue }
    }

    /// The type an autosave writes; the document's own type by default.
    open var autosavingFileType: String? {
        fileType
    }

    /// Whether an autosave in progress may be abandoned silently.
    ///
    /// True while the document has a file to fall back on: nothing is lost by
    /// giving up when the last explicit save is still on disk.
    open var autosavingIsImplicitlyCancellable: Bool {
        fileURL != nil
    }

    /// Checks whether autosaving over the document's file is safe right now.
    ///
    /// - Throws: An `NSError` when the file has gone missing or is locked, so
    ///   the caller can stop rather than write into a hole.
    open func checkAutosavingSafety() throws {
        guard let fileURL else {
            return
        }

        if isLocked {
            throw CocoaFileError.error(CocoaFileError.writeNoPermission, url: fileURL,
                                       reason: "The document is locked.")
        }

        // A missing file is only a problem when we KNOW it used to be there —
        // which `fileModificationDate` is exactly the record of, since it is
        // set by a successful read or write. Without that record the document
        // merely has a destination it has not written yet, and autosaving in
        // place is supposed to create it. Treating every missing file as unsafe
        // silently disabled autosave for exactly the documents that most need
        // it: the ones whose first save has not happened.
        if fileModificationDate != nil,
           !ChocolateFileAccess.fileExists(atPath: fileURL.path) {
            throw CocoaFileError.error(CocoaFileError.readNoSuchFile, url: fileURL,
                                       reason: "The document’s file is no longer there.")
        }
    }

    /// Autosaves, reporting the outcome to a completion handler.
    ///
    /// A document with nowhere safe to write is skipped rather than prompting:
    /// autosaving must never put a panel in front of somebody who did not ask
    /// to save.
    open func autosave(withImplicitCancellability implicitlyCancellable: Bool,
                       completionHandler: (Error?) -> Void) {
        guard hasUnautosavedChanges, let destination = autosaveDestination() else {
            completionHandler(nil)
            return
        }

        do {
            try checkAutosavingSafety()
        } catch {
            completionHandler(error)
            return
        }

        let operation: SaveOperationType = destination == fileURL
            ? .autosaveInPlaceOperation
            : .autosaveElsewhereOperation
        let token = changeCountToken(for: operation)

        do {
            try writeSafely(to: destination,
                            ofType: autosavingFileType ?? destination.pathExtension,
                            for: operation)
        } catch {
            lastError = error
            completionHandler(error)
            return
        }

        if operation == .autosaveElsewhereOperation {
            autosavedContentsFileURL = destination
        }
        updateChangeCount(withToken: token, for: operation)
        completionHandler(nil)
    }

    /// Autosaves and reports the outcome by sending a selector to a delegate.
    open func autosaveDocument(withDelegate delegate: Any?,
                               didAutosave didAutosaveSelector: Selector?,
                               contextInfo: UnsafeMutableRawPointer?) {
        autosave(withImplicitCancellability: autosavingIsImplicitlyCancellable) { error in
            notify(delegate, didAutosaveSelector, succeeded: error == nil,
                   contextInfo: contextInfo)
        }
    }

    /// Asks for an autosave to happen periodically.
    ///
    /// Honours `NSDocumentController.autosavingDelay`; a delay of zero — the
    /// default — means no periodic autosaving, exactly as on Apple.
    open func scheduleAutosaving() {
        let delay = NSDocumentController.shared.autosavingDelay
        guard delay > 0 else {
            cancelAutosaving()
            return
        }
        guard winAutosaveTimer == nil else {
            return
        }

        winAutosaveTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: true) { [weak self] _ in
            guard let self else {
                return
            }
            MainActor.assumeIsolated {
                self.autosave(withImplicitCancellability: self.autosavingIsImplicitlyCancellable) { _ in }
            }
        }
    }

    /// Stops any scheduled autosaving. Called when the document closes.
    internal func cancelAutosaving() {
        winAutosaveTimer?.invalidate()
        winAutosaveTimer = nil
    }

    /// Where an autosave should write.
    ///
    /// In place over the document's own file when the class opted in;
    /// otherwise a scratch copy for a draft, but only if the class opted into
    /// autosaving drafts. Nil means "do not autosave this document".
    private func autosaveDestination() -> URL? {
        if let fileURL, type(of: self).autosavesInPlace {
            return fileURL
        }
        guard fileURL == nil, type(of: self).autosavesDrafts else {
            return nil
        }
        if let existing = autosavedContentsFileURL {
            return existing
        }
        let name = (displayName ?? defaultDraftName()).replacingOccurrences(of: "/", with: "-")
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("ChocolateAutosave-\(name)")
    }

    // MARK: - Closing
    //
    // The save-changes prompt lives here, not in `NSWindowController`, which is
    // where this framework used to keep it. That is not tidying: a document can
    // have several windows, and closing one of them must not ask about unsaved
    // changes — only closing the last one should, and only the document knows
    // how many it has.

    /// Asks whether the document may close, prompting about unsaved changes.
    ///
    /// The prompt is Apple's three-way one: Save, Cancel, Don't Save.
    open func canClose(withDelegate delegate: Any,
                       shouldClose shouldCloseSelector: Selector?,
                       contextInfo: UnsafeMutableRawPointer?) {
        guard isDocumentEdited else {
            notify(delegate, shouldCloseSelector, succeeded: true, contextInfo: contextInfo)
            return
        }

        let alert = NSAlert()
        alert.messageText = "Do you want to save the changes made to the document "
            + "“\(displayName ?? defaultDraftName())”?"
        alert.informativeText = "Your changes will be lost if you don’t save them."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Don’t Save")

        switch runCloseAlert(alert) {
        case .alertFirstButtonReturn:
            // Save. The close is only allowed if the save actually worked — a
            // cancelled save panel or a failed write must not take the
            // document's changes down with the window.
            save(nil)
            notify(delegate, shouldCloseSelector,
                   succeeded: !isDocumentEdited, contextInfo: contextInfo)
        case .alertThirdButtonReturn:
            // Don't Save: discard and close.
            notify(delegate, shouldCloseSelector, succeeded: true, contextInfo: contextInfo)
        default:
            // Cancel, and anything unrecognised. Refusing to close is the
            // answer that cannot lose the user's work.
            notify(delegate, shouldCloseSelector, succeeded: false, contextInfo: contextInfo)
        }
    }

    /// Asks whether one of the document's window controllers may close.
    ///
    /// Only the **last** window prompts. Closing one of several windows onto
    /// the same document throws nothing away, so asking would be noise.
    open func shouldCloseWindowController(_ windowController: NSWindowController,
                                          delegate: Any?,
                                          shouldClose shouldCloseSelector: Selector?,
                                          contextInfo: UnsafeMutableRawPointer?) {
        let isLastWindow = windowControllers.count <= 1 || windowController.shouldCloseDocument
        guard isLastWindow else {
            notify(delegate, shouldCloseSelector, succeeded: true, contextInfo: contextInfo)
            return
        }
        canClose(withDelegate: delegate ?? self,
                 shouldClose: shouldCloseSelector, contextInfo: contextInfo)
    }

    /// Closes the document, its windows, and its controller registration.
    ///
    /// Unconditional: asking is `canClose`'s job, and by the time this runs the
    /// decision has been made.
    open func close() {
        cancelAutosaving()

        // Copied before iterating: closing a window calls back into
        // `removeWindowController(_:)`, which mutates the array being walked.
        let controllers = windowControllers
        windowControllers.removeAll()
        for controller in controllers {
            controller.document = nil
            controller.close()
        }

        if let autosaved = autosavedContentsFileURL {
            try? FileManager.default.removeItem(at: autosaved)
            autosavedContentsFileURL = nil
        }

        (owningController ?? NSDocumentController.shared).removeDocument(self)
    }

    // MARK: - Error presentation

    /// Presents an error to the user and reports whether it was recovered from.
    ///
    /// Runs the error through `willPresentError(_:)` first, so a subclass can
    /// substitute a better one. A cancellation is swallowed rather than shown:
    /// the user already knows they cancelled.
    @discardableResult
    open func presentError(_ error: Error) -> Bool {
        let refined = willPresentError(error)

        if let nsError = refined as? NSError,
           nsError.domain == CocoaFileError.domain,
           nsError.code == CocoaFileError.userCancelled {
            willNotPresentError(refined)
            return false
        }

        let alert = NSAlert(error: refined)
        if let window = windowForSheet {
            alert.beginSheetModal(for: window) { _ in }
            return false
        }
        _ = alert.runModal()
        return false
    }

    /// Presents an error as a sheet on a window, reporting to a delegate.
    open func presentError(_ error: Error,
                           modalFor window: NSWindow,
                           delegate: Any?,
                           didPresent didPresentSelector: Selector?,
                           contextInfo: UnsafeMutableRawPointer?) {
        let alert = NSAlert(error: willPresentError(error))
        alert.beginSheetModal(for: window) { _ in }
        notify(delegate, didPresentSelector, succeeded: false, contextInfo: contextInfo)
    }

    /// Lets a subclass replace an error on its way to the user.
    open func willPresentError(_ error: Error) -> Error {
        error
    }

    /// Called for an error that is deliberately not being shown.
    ///
    /// The hook that makes swallowing an error honest rather than silent.
    open func willNotPresentError(_ error: Error) {
    }

    // MARK: - Printing

    /// The paper settings this document prints with.
    ///
    /// Starts fresh per document, so changing one document's page setup does
    /// not change every other one's.
    open var printInfo: NSPrintInfo {
        get {
            if let storedPrintInfo {
                return storedPrintInfo
            }
            let fresh = NSPrintInfo()
            storedPrintInfo = fresh
            return fresh
        }
        set { storedPrintInfo = newValue }
    }

    /// Prints the document.
    ///
    /// Objective-C name `printDocument:` — the one action in this family whose
    /// Swift name is not shortened.
    open func printDocument(_ sender: Any?) {
        print(withSettings: [:], showPrintPanel: true,
              delegate: nil, didPrint: nil, contextInfo: nil)
    }

    /// Prints with explicit settings, reporting the outcome to a delegate.
    open func print(withSettings printSettings: [String: Any],
                    showPrintPanel: Bool,
                    delegate: Any?,
                    didPrint didPrintSelector: Selector?,
                    contextInfo: UnsafeMutableRawPointer?) {
        let operation: NSPrintOperation?
        do {
            operation = try printOperation(withSettings: printSettings)
        } catch {
            lastError = error
            presentError(error)
            notify(delegate, didPrintSelector, succeeded: false, contextInfo: contextInfo)
            return
        }

        guard let operation else {
            notify(delegate, didPrintSelector, succeeded: false, contextInfo: contextInfo)
            return
        }

        operation.showsPrintPanel = showPrintPanel
        let succeeded = operation.run()
        notify(delegate, didPrintSelector, succeeded: succeeded, contextInfo: contextInfo)
    }

    /// Returns the print operation for this document. Subclasses override.
    ///
    /// Nil by default, which disables the Print menu item through
    /// `validateUserInterfaceItem(_:)` — a Print item that prints a blank page
    /// is worse than a disabled one.
    open func printOperation(withSettings printSettings: [String: Any]) throws -> NSPrintOperation? {
        nil
    }

    /// Runs a print operation modally, reporting to a delegate.
    open func runModalPrintOperation(_ printOperation: NSPrintOperation,
                                     delegate: Any?,
                                     didRun didRunSelector: Selector?,
                                     contextInfo: UnsafeMutableRawPointer?) {
        let succeeded = printOperation.run()
        notify(delegate, didRunSelector, succeeded: succeeded, contextInfo: contextInfo)
    }

    /// Shows the page-setup panel.
    ///
    /// Objective-C name `runPageLayout:`.
    open func runPageLayout(_ sender: Any?) {
        runModalPageLayout(with: printInfo, delegate: nil, didRun: nil, contextInfo: nil)
    }

    /// Runs the page-layout panel over some settings.
    open func runModalPageLayout(with printInfo: NSPrintInfo,
                                 delegate: Any?,
                                 didRun didRunSelector: Selector?,
                                 contextInfo: UnsafeMutableRawPointer?) {
        let layout = NSPageLayout()
        guard preparePageLayout(layout) else {
            notify(delegate, didRunSelector, succeeded: false, contextInfo: contextInfo)
            return
        }

        let accepted = layout.runModal(with: printInfo) == .OK
        if accepted, shouldChangePrintInfo(printInfo) {
            self.printInfo = printInfo
            updateChangeCount(.changeDone)
        }
        notify(delegate, didRunSelector, succeeded: accepted, contextInfo: contextInfo)
    }

    /// Lets a subclass configure the page-layout panel before it runs.
    open func preparePageLayout(_ pageLayout: NSPageLayout) -> Bool {
        true
    }

    /// Whether accepting new page settings should be treated as an edit.
    ///
    /// True, as AppKit's is: page setup is part of the document.
    open func shouldChangePrintInfo(_ newPrintInfo: NSPrintInfo) -> Bool {
        true
    }

    // MARK: - Moving, renaming, duplicating, locking
    //
    // Documented boundary: on a Mac these are Finder-integrated. None of that
    // exists here, so each is the plain file operation it fundamentally is,
    // driven by a panel. The API and the resulting state are Apple's.

    /// Creates a copy of this document and opens it.
    open func duplicate(_ sender: Any?) {
        do {
            _ = try duplicateAndReturnError()
        } catch {
            lastError = error
            presentError(error)
        }
    }

    /// Creates and opens a copy of this document, returning it.
    ///
    /// The copy is untitled and edited, exactly as Apple's is: it exists only
    /// in memory until the user saves it, so it must not share this document's
    /// file.
    @discardableResult
    open func duplicateAndReturnError() throws -> NSDocument {
        let typeName = fileType ?? ""
        let copy = try NSDocumentController.shared.makeUntitledDocument(ofType: typeName)

        // Round-tripping through the document's own bytes is what makes this
        // work for any subclass without knowing anything about its model.
        try copy.read(from: try fileWrapper(ofType: typeName), ofType: typeName)

        copy.isDraft = true
        NSDocumentController.shared.addDocument(copy)
        copy.makeWindowControllers()
        copy.updateChangeCount(.changeDone)
        copy.showWindows()
        return copy
    }

    /// Renames the document's file, asking for the new name.
    open func rename(_ sender: Any?) {
        guard let fileURL else {
            return
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = fileURL.lastPathComponent
        panel.directoryURL = fileURL.deletingLastPathComponent()
        panel.title = "Rename Document"
        guard panel.runModal() == .OK, let destination = panel.url, destination != fileURL else {
            return
        }

        move(to: destination) { [weak self] error in
            if let error {
                self?.lastError = error
                self?.presentError(error)
            }
        }
    }

    /// Moves the document's file, asking where to put it.
    open func move(_ sender: Any?) {
        moveDocument { _ in }
    }

    /// Moves the document's file, reporting whether it happened.
    open func moveDocument(completionHandler: ((Bool) -> Void)? = nil) {
        guard let fileURL else {
            completionHandler?(false)
            return
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = fileURL.lastPathComponent
        panel.title = "Move Document"
        guard panel.runModal() == .OK, let destination = panel.url else {
            completionHandler?(false)
            return
        }

        move(to: destination) { [weak self] error in
            if let error {
                self?.lastError = error
                self?.presentError(error)
            }
            completionHandler?(error == nil)
        }
    }

    /// Moves the document's file to a URL.
    ///
    /// The document follows its file: `fileURL` becomes the destination, so the
    /// window title and any later save go to the new place.
    open func move(to url: URL, completionHandler: ((Error?) -> Void)? = nil) {
        guard let currentURL = fileURL else {
            completionHandler?(nil)
            return
        }

        do {
            let manager = FileManager.default
            if manager.fileExists(atPath: url.path) {
                try manager.removeItem(at: url)
            }
            try manager.moveItem(at: currentURL, to: url)
        } catch {
            completionHandler?(CocoaFileError.error(CocoaFileError.writeNoPermission, url: url,
                                                    reason: "The document couldn’t be moved."))
            return
        }

        fileURL = url
        winNotifyPresentersOfMove(from: currentURL, to: url)
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        synchronizeWindowTitles()
        completionHandler?(nil)
    }

    /// Locks the document against editing.
    open func lock(_ sender: Any?) {
        lock { _ in }
    }

    /// Locks the document, reporting any failure.
    open func lock(completionHandler: ((Error?) -> Void)? = nil) {
        isLocked = true
        synchronizeWindowTitles()
        completionHandler?(nil)
    }

    /// Unlocks the document.
    open func unlock(_ sender: Any?) {
        unlock { _ in }
    }

    /// Unlocks the document, reporting any failure.
    open func unlock(completionHandler: ((Error?) -> Void)? = nil) {
        isLocked = false
        synchronizeWindowTitles()
        completionHandler?(nil)
    }

    // MARK: - Activity and file access
    //
    // Documented boundary: on Apple these serialize work against a background
    // file-access queue so a save can proceed while the UI stays live. This
    // framework is single-threaded by design, so each runs its block
    // immediately. The API exists so ported code compiles and behaves
    // correctly; it just has nothing to wait for.

    /// Runs a block as a document activity.
    open func performActivity(withSynchronousWaiting waitSynchronously: Bool,
                              using block: (@escaping () -> Void) -> Void) {
        block({})
    }

    /// Continues an activity already in progress.
    open func continueActivity(using block: () -> Void) {
        block()
    }

    /// Runs a block on the main thread as part of asynchronous work.
    open func continueAsynchronousWorkOnMainThread(using block: @escaping () -> Void) {
        block()
    }

    /// Runs a block with synchronous file access.
    open func performSynchronousFileAccess(using block: () -> Void) {
        block()
    }

    /// Runs a block with asynchronous file access.
    open func performAsynchronousFileAccess(using block: (@escaping () -> Void) -> Void) {
        block({})
    }

    /// Lets queued interaction proceed during a long write.
    ///
    /// Nothing to unblock: writes are synchronous on the UI thread.
    open func unblockUserInteraction() {
    }

    // MARK: - Validation

    /// Decides whether an item sending a document action should be enabled.
    ///
    /// The judgements are Apple's, and each exists to stop an action that
    /// cannot do anything useful from looking available. The selector names are
    /// the Objective-C ones — see NSDocumentValidation.swift.
    open func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        guard let action = item.action else {
            return true
        }

        switch action.name {
        case "revertDocumentToSaved:":
            // Nothing to revert to without a file, nothing to revert without changes.
            return fileURL != nil && isDocumentEdited
        case "saveDocument:":
            // A document with no file can always be saved — that is Save As in
            // disguise. One with a file is only worth saving when it is dirty.
            return fileURL == nil || isDocumentEdited
        case "printDocument:":
            return (try? printOperation(withSettings: [:])) != nil
        case "renameDocument:", "moveDocument:", "duplicateDocument:":
            return fileURL != nil
        case "lockDocument:":
            return fileURL != nil && !isLocked
        case "unlockDocument:":
            return fileURL != nil && isLocked
        default:
            return responds(to: action)
        }
    }

    /// Routes menu validation to `validateUserInterfaceItem(_:)`.
    ///
    /// Both protocols exist on Apple and a document adopts both; one
    /// implementation forwarding to the other means a subclass overriding the
    /// general one automatically governs menus too.
    open func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        validateUserInterfaceItem(menuItem)
    }

    // MARK: - Selector dispatch

    /// Reports whether the document handles a document action selector.
    open override func responds(to aSelector: Selector?) -> Bool {
        guard let aSelector else {
            return false
        }
        if Self.winDocumentActions[aSelector.name] != nil {
            return true
        }
        return super.responds(to: aSelector)
    }

    /// Dispatches a document action selector to its method.
    @discardableResult
    open override func perform(_ aSelector: Selector, with object: Any?) -> Any? {
        guard let handler = Self.winDocumentActions[aSelector.name] else {
            return super.perform(aSelector, with: object)
        }
        handler(self, object)
        return nil
    }

    // MARK: - Shared mechanics

    /// Writes to a destination and folds the result back into the document.
    private func performSave(to url: URL?, ofType typeName: String?,
                             for saveOperation: SaveOperationType) {
        guard let url else {
            return
        }
        let resolvedType = typeName ?? fileType ?? url.pathExtension
        let token = changeCountToken(for: saveOperation)

        do {
            try writeSafely(to: url, ofType: resolvedType, for: saveOperation)
        } catch {
            lastError = error
            presentError(error)
            return
        }

        adoptSaveResult(url: url, typeName: resolvedType, operation: saveOperation, token: token)
    }

    /// Updates identity and change count after a successful write.
    ///
    /// A `saveToOperation` deliberately changes nothing but the recents list:
    /// it wrote a copy somewhere else, and the document being edited is still
    /// the same document, still with the same unsaved changes.
    private func adoptSaveResult(url: URL, typeName: String,
                                 operation: SaveOperationType, token: Any) {
        lastError = nil

        switch operation {
        case .saveOperation, .saveAsOperation, .autosaveAsOperation:
            let previousURL = fileURL
            fileURL = url
            fileType = typeName
            fileModificationDate = Date()
            isDraft = false
            updateChangeCount(withToken: token, for: operation)
            if let previousURL, previousURL != url {
                winNotifyPresentersOfMove(from: previousURL, to: url)
            }
            NSDocumentController.shared.noteNewRecentDocumentURL(url)

        case .autosaveInPlaceOperation, .autosaveElsewhereOperation:
            updateChangeCount(withToken: token, for: operation)

        case .saveToOperation:
            NSDocumentController.shared.noteNewRecentDocumentURL(url)
        }

        synchronizeWindowTitles()
    }

    /// Runs the save-changes alert, as a sheet when there is a window for it.
    private func runCloseAlert(_ alert: NSAlert) -> NSApplication.ModalResponse {
        guard let window = windowForSheet else {
            return alert.runModal()
        }
        var response = NSApplication.ModalResponse.alertSecondButtonReturn
        alert.beginSheetModal(for: window) { alertResponse in
            response = alertResponse
        }
        return response
    }

    /// Sends an outcome selector to a delegate, when both are present.
    ///
    /// **Divergence, recorded in Docs/AppKitCompatibilityDivergences.md.**
    /// AppKit's callbacks take three arguments — `document:didSave:contextInfo:`
    /// — dispatched through the Objective-C runtime. There is none here, and
    /// `perform(_:with:)` carries exactly one argument, so all three are boxed
    /// into a `CallbackInfo` and passed as that argument.
    ///
    /// The alternative was to pass only the document, which is what the first
    /// draft did — and it silently threw the success flag away, making a
    /// cancelled save indistinguishable from a completed one.
    internal func notify(_ delegate: Any?, _ selector: Selector?,
                         succeeded: Bool, contextInfo: UnsafeMutableRawPointer?) {
        guard let selector, let object = delegate as? NSObject,
              object.responds(to: selector) else {
            return
        }
        object.perform(selector, with: CallbackInfo(document: self,
                                                    succeeded: succeeded,
                                                    contextInfo: contextInfo))
    }

    /// Tells any file presenters that this document's file moved.
    internal func winNotifyPresentersOfMove(from oldURL: URL, to newURL: URL) {
        #if !canImport(Darwin)
        NSFileCoordinator(filePresenter: self).item(at: oldURL, didMoveTo: newURL)
        #endif
    }
}
