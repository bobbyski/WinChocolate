/// The registry that tracks open documents and drives New, Open, and Quit.
///
/// One per process. It owns the list of open documents, the recent-documents
/// list, and the type-to-class mapping that decides what New and Open actually
/// create.
///
/// ```
///   File ▸ New   ──▶ newDocument(_:)   ──▶ makeUntitledDocument(ofType:)
///   File ▸ Open  ──▶ openDocument(_:)  ──▶ open panel ──▶ makeDocument(withContentsOf:ofType:)
///   Quit         ──▶ reviewUnsavedDocuments(…) ──▶ each dirty document's canClose
/// ```
///
/// **Subclassing.** An application overrides `documentClass(forType:)` to say
/// what its documents are, and creates its subclass early — because, as on
/// Apple, **the first controller instantiated becomes the shared one**.
///
/// The framework's UI objects are single-threaded on the main thread, so the
/// shared instance opts out of strict concurrency checking like the other
/// framework singletons.
open class NSDocumentController: NSObject {
    /// Backing store for `shared`, captured by the first instantiation.
    nonisolated(unsafe) private static var sharedStorage: NSDocumentController?

    /// The shared document controller.
    ///
    /// As in AppKit, **the first document controller instantiated becomes the
    /// shared one** — an application subclasses `NSDocumentController`
    /// (overriding `documentClass(forType:)`) and creates its instance early;
    /// otherwise a plain controller is created on first access.
    public static var shared: NSDocumentController {
        if let sharedStorage {
            return sharedStorage
        }
        return NSDocumentController()
    }

    /// The shared controller **only if one already exists**, without creating one.
    ///
    /// Not API. `NSApplication`'s nil-target action chain ends at the document
    /// controller, and asking for `shared` there would quietly bring one into
    /// being inside every application that has none — which would then start
    /// answering `newDocument:` in apps that are not document-based at all.
    internal static var winSharedIfCreated: NSDocumentController? {
        sharedStorage
    }

    // MARK: - Open documents

    /// All open documents, in the order they were added.
    open private(set) var documents: [NSDocument] = []

    /// The document most recently opened, added, or brought forward.
    open var currentDocument: NSDocument?

    /// The directory the next open or save panel should start in.
    open var currentDirectory: String? {
        currentDocument?.fileURL?.deletingLastPathComponent().path
    }

    /// Whether any open document has unsaved changes.
    open var hasEditedDocuments: Bool {
        documents.contains { $0.isDocumentEdited }
    }

    /// How long to wait between autosaves, in seconds.
    ///
    /// **Zero by default, and that is Apple's default too** (measured). Zero
    /// means no periodic autosaving at all. This framework previously ran a
    /// hard-coded 30-second timer for any document class that opted into
    /// autosaving in place, which meant applications got disk writes they never
    /// asked for. An application that wants periodic autosaving sets this.
    open var autosavingDelay: TimeInterval = 0 {
        didSet {
            for document in documents {
                document.scheduleAutosaving()
            }
        }
    }

    /// Creates a document controller. As in AppKit, the first becomes `shared`.
    public override init() {
        super.init()
        if NSDocumentController.sharedStorage == nil {
            NSDocumentController.sharedStorage = self
        }
    }

    // MARK: - Document types
    //
    // AppKit reads these from the bundle's Info.plist. There is no plist here —
    // and often no bundle at all — so an application answers by overriding,
    // which is why each of these is `open` and empty rather than absent.

    /// The names of the document classes the app registered.
    open var documentClassNames: [String] { [] }

    /// The type a brand-new untitled document is created as.
    open var defaultType: String? { nil }

    /// The human-readable name of a registered type, for menus and panels.
    open func displayName(forType typeName: String) -> String? { nil }

    /// Resolves a file's type from its contents or extension.
    open func typeForContents(of url: URL) throws -> String {
        url.pathExtension
    }

    /// Returns the document class for a type.
    ///
    /// The hook an application overrides to say what its documents are. Nil
    /// means "I do not handle this type", and callers then fall back to a plain
    /// `NSDocument`.
    open func documentClass(forType typeName: String) -> AnyClass? {
        nil
    }

    /// The class `documentClass(forType:)` resolves, as a document type.
    private func resolvedDocumentClass(forType typeName: String) -> NSDocument.Type {
        (documentClass(forType: typeName) as? NSDocument.Type) ?? NSDocument.self
    }

    // MARK: - Registering documents

    /// Registers a document and makes it current.
    ///
    /// Also assigns the document its untitled number, because this is the only
    /// object that can see the other untitled documents — which is how AppKit
    /// arrives at "Untitled", "Untitled 2", "Untitled 3" (measured).
    open func addDocument(_ document: NSDocument) {
        guard !documents.contains(where: { $0 === document }) else {
            return
        }

        if document.fileURL == nil {
            document.untitledNumber = nextUntitledNumber()
        }
        documents.append(document)
        document.owningController = self
        currentDocument = document
        document.scheduleAutosaving()
    }

    /// Removes a document from the open-documents list.
    open func removeDocument(_ document: NSDocument) {
        documents.removeAll { $0 === document }
        if document.owningController === self {
            document.owningController = nil
        }
        if currentDocument === document {
            currentDocument = documents.last
        }
    }

    /// The lowest untitled number not already taken by an open document.
    ///
    /// Lowest-free rather than a running counter, so closing "Untitled 2" and
    /// making a new one gives back "Untitled 2" instead of marching on to
    /// "Untitled 5".
    private func nextUntitledNumber() -> Int {
        let taken = Set(documents.filter { $0.fileURL == nil }.map { $0.untitledNumber })
        var candidate = 1
        while taken.contains(candidate) {
            candidate += 1
        }
        return candidate
    }

    /// The open document for a file URL, when there is one.
    open func document(for url: URL) -> NSDocument? {
        documents.first { $0.fileURL == url }
    }

    /// The open document displayed by a window, when there is one.
    open func document(for window: NSWindow) -> NSDocument? {
        documents.first { document in
            document.windowControllers.contains { $0.window === window }
        }
    }

    // MARK: - Making documents

    /// Creates an untitled document of a type, without opening it.
    ///
    /// AppKit's factory hook: `newDocument(_:)` calls it, and applications
    /// override it to construct their own subclass.
    open func makeUntitledDocument(ofType typeName: String) throws -> NSDocument {
        let document = resolvedDocumentClass(forType: typeName).init()
        document.fileType = typeName
        return document
    }

    /// Creates a document read from a URL, without adding it.
    open func makeDocument(withContentsOf url: URL, ofType typeName: String) throws -> NSDocument {
        let document = resolvedDocumentClass(forType: typeName).init()
        try document.read(from: url, ofType: typeName)
        return document
    }

    /// Creates a document that belongs to one URL but reads from another.
    ///
    /// Used when reopening from an autosaved copy.
    open func makeDocument(for urlOrNil: URL?,
                           withContentsOf contentsURL: URL,
                           ofType typeName: String) throws -> NSDocument {
        let document = resolvedDocumentClass(forType: typeName).init()
        try document.read(from: contentsURL, ofType: typeName)
        document.fileURL = urlOrNil
        document.fileType = typeName
        return document
    }

    // MARK: - New

    /// Creates a new untitled document with its windows shown.
    @discardableResult
    open func newDocument(_ sender: Any?) -> NSDocument {
        (try? openUntitledDocumentAndDisplay(true)) ?? NSDocument()
    }

    /// Creates an untitled document, optionally showing it.
    @discardableResult
    open func openUntitledDocumentAndDisplay(_ displayDocument: Bool) throws -> NSDocument {
        let document = try makeUntitledDocument(ofType: defaultType ?? "")
        addDocument(document)
        document.makeWindowControllers()
        if displayDocument {
            document.showWindows()
        }
        return document
    }

    // MARK: - Open

    /// Presents an open panel and opens each chosen file as a document.
    open func openDocument(_ sender: Any?) {
        guard let urls = urlsFromRunningOpenPanel() else {
            return
        }
        for url in urls {
            openDocument(withContentsOf: url, display: true) { _, _, _ in }
        }
    }

    /// Opens a document from a URL, reporting the outcome.
    ///
    /// A file that is **already open** is brought forward rather than opened
    /// twice — the `documentWasAlreadyOpen` flag says which happened. Two
    /// windows onto one file, each with its own unsaved changes, is a data-loss
    /// bug, so this check is not an optimisation.
    open func openDocument(withContentsOf url: URL,
                           display displayDocument: Bool,
                           completionHandler: (NSDocument?, Bool, Error?) -> Void) {
        if let existing = document(for: url) {
            currentDocument = existing
            if displayDocument {
                existing.showWindows()
            }
            completionHandler(existing, true, nil)
            return
        }

        let document: NSDocument
        do {
            let typeName = try typeForContents(of: url)
            document = try makeDocument(withContentsOf: url, ofType: typeName)
        } catch {
            completionHandler(nil, false, error)
            return
        }

        addDocument(document)
        document.makeWindowControllers()
        if displayDocument {
            document.showWindows()
        }
        noteNewRecentDocumentURL(url)
        completionHandler(document, false, nil)
    }

    /// Reopens a document, reading from a possibly different URL.
    open func reopenDocument(for urlOrNil: URL?,
                             withContentsOf contentsURL: URL,
                             display displayDocument: Bool,
                             completionHandler: (NSDocument?, Bool, Error?) -> Void) {
        if let urlOrNil, let existing = document(for: urlOrNil) {
            completionHandler(existing, true, nil)
            return
        }

        let document: NSDocument
        do {
            let typeName = try typeForContents(of: contentsURL)
            document = try makeDocument(for: urlOrNil, withContentsOf: contentsURL, ofType: typeName)
        } catch {
            completionHandler(nil, false, error)
            return
        }

        addDocument(document)
        document.makeWindowControllers()
        if displayDocument {
            document.showWindows()
        }
        completionHandler(document, false, nil)
    }

    /// Opens a copy of a document at a URL as a new untitled document.
    @discardableResult
    open func duplicateDocument(withContentsOf url: URL,
                                copying duplicateByCopying: Bool,
                                displayName displayNameOrNil: String?) throws -> NSDocument {
        let typeName = try typeForContents(of: url)
        let document = try makeDocument(withContentsOf: url, ofType: typeName)

        // A duplicate has no file of its own until it is saved — otherwise
        // saving it would overwrite the document it was copied from.
        document.fileURL = nil
        document.isDraft = true
        if let displayNameOrNil {
            document.displayName = displayNameOrNil
        }

        addDocument(document)
        document.makeWindowControllers()
        document.updateChangeCount(.changeDone)
        document.showWindows()
        return document
    }

    // MARK: - Open panel

    /// Runs an open panel and returns what the user chose.
    open func urlsFromRunningOpenPanel() -> [URL]? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        if let currentDirectory {
            panel.directoryURL = URL(fileURLWithPath: currentDirectory)
        }

        let types = documentClassNames.isEmpty ? nil : documentClassNames
        guard runModalOpenPanel(panel, forTypes: types) == NSApplication.ModalResponse.OK.rawValue else {
            return nil
        }
        return panel.urls
    }

    /// Runs an open panel restricted to some types.
    ///
    /// The hook a subclass overrides to configure the panel.
    open func runModalOpenPanel(_ openPanel: NSOpenPanel, forTypes types: [String]?) -> Int {
        if let types, !types.isEmpty {
            openPanel.allowedFileTypes = types
        }
        return openPanel.runModal().rawValue
    }

    /// Runs an open panel and hands the chosen URLs to a handler.
    open func beginOpenPanel(completionHandler: ([URL]?) -> Void) {
        completionHandler(urlsFromRunningOpenPanel())
    }

    /// Runs an open panel for some types and reports the response code.
    open func beginOpenPanel(_ openPanel: NSOpenPanel,
                             forTypes inTypes: [String]?,
                             completionHandler: (Int) -> Void) {
        completionHandler(runModalOpenPanel(openPanel, forTypes: inTypes))
    }

    // MARK: - Saving and closing in bulk

    /// Saves every open document that has somewhere to be saved.
    ///
    /// Documents that have never been saved are skipped rather than each
    /// putting up a panel: Save All turning into a stack of modal dialogs is
    /// not what anyone means by it.
    open func saveAllDocuments(_ sender: Any?) {
        for document in documents where document.isDocumentEdited && document.fileURL != nil {
            document.save(sender)
        }
    }

    /// Asks about every unsaved document, then reports whether all were handled.
    ///
    /// What Quit runs. A single Cancel stops the whole review, because the user
    /// cancelling one document means they no longer want to quit.
    open func reviewUnsavedDocuments(withAlertTitle title: String?,
                                     cancellable: Bool,
                                     delegate: Any?,
                                     didReviewAll didReviewAllSelector: Selector?,
                                     contextInfo: UnsafeMutableRawPointer?) {
        var reviewedAll = true
        for document in documents where document.isDocumentEdited {
            if !winCanClose(document) {
                reviewedAll = false
                break
            }
        }
        notify(delegate, didReviewAllSelector, succeeded: reviewedAll, contextInfo: contextInfo)
    }

    /// Closes every open document, asking about unsaved changes first.
    open func closeAllDocuments(withDelegate delegate: Any?,
                                didCloseAll didCloseAllSelector: Selector?,
                                contextInfo: UnsafeMutableRawPointer?) {
        // Copied before iterating: closing a document removes it from
        // `documents`, so walking the live array would skip every other one.
        for document in Array(documents) {
            guard winCanClose(document) else {
                notify(delegate, didCloseAllSelector, succeeded: false, contextInfo: contextInfo)
                return
            }
            document.close()
        }
        notify(delegate, didCloseAllSelector, succeeded: true, contextInfo: contextInfo)
    }

    /// Asks a document whether it may close, synchronously.
    ///
    /// `canClose(withDelegate:shouldClose:contextInfo:)` reports through a
    /// selector; the bulk operations above need an answer inline, so this
    /// captures it.
    internal func winCanClose(_ document: NSDocument) -> Bool {
        let recorder = WinDocumentCloseRecorder()
        document.canClose(withDelegate: recorder,
                          shouldClose: Selector("document:shouldClose:contextInfo:"),
                          contextInfo: nil)
        return recorder.allowed
    }

    // MARK: - Recent documents

    /// Recently opened document locations, most recent first.
    open private(set) var recentDocumentURLs: [URL] = []

    /// How many recent documents to remember.
    ///
    /// Ten, which is Apple's value (measured).
    open var maximumRecentDocumentCount: Int { 10 }

    /// Records a document's file in the recent-documents list.
    open func noteNewRecentDocument(_ document: NSDocument) {
        guard let url = document.fileURL else {
            return
        }
        noteNewRecentDocumentURL(url)
    }

    /// Moves a URL to the front of the recent-documents list.
    open func noteNewRecentDocumentURL(_ url: URL) {
        recentDocumentURLs.removeAll { $0 == url }
        recentDocumentURLs.insert(url, at: 0)
        if recentDocumentURLs.count > maximumRecentDocumentCount {
            recentDocumentURLs.removeLast(recentDocumentURLs.count - maximumRecentDocumentCount)
        }
        winSaveRecentDocuments()
    }

    /// Clears the recent-documents list.
    open func clearRecentDocuments(_ sender: Any?) {
        recentDocumentURLs = []
        winSaveRecentDocuments()
    }

    /// The defaults key the recent-documents list is stored under.
    private static let recentDocumentsDefaultsKey = "NSRecentDocumentRecords"

    /// Persists the recent-documents list so it survives a restart.
    private func winSaveRecentDocuments() {
        UserDefaults.standard.set(recentDocumentURLs.map { $0.path },
                                  forKey: Self.recentDocumentsDefaultsKey)
    }

    /// Restores the recent-documents list saved by a previous run.
    ///
    /// Not called automatically: an application asks for it, because a process
    /// that never had recents should not grow them by merely existing.
    open func winLoadRecentDocuments() {
        guard let paths = UserDefaults.standard.array(forKey: Self.recentDocumentsDefaultsKey)
                as? [String] else {
            return
        }
        recentDocumentURLs = paths.map { URL(fileURLWithPath: $0) }
    }

    // MARK: - Error presentation

    /// Presents an error to the user.
    @discardableResult
    open func presentError(_ error: Error) -> Bool {
        _ = NSAlert(error: willPresentError(error)).runModal()
        return false
    }

    /// Presents an error as a sheet on a window, reporting to a delegate.
    open func presentError(_ error: Error,
                           modalFor window: NSWindow,
                           delegate: Any?,
                           didPresent didPresentSelector: Selector?,
                           contextInfo: UnsafeMutableRawPointer?) {
        NSAlert(error: willPresentError(error)).beginSheetModal(for: window) { _ in }
        notify(delegate, didPresentSelector, succeeded: false, contextInfo: contextInfo)
    }

    /// Lets a subclass replace an error on its way to the user.
    open func willPresentError(_ error: Error) -> Error {
        error
    }

    // MARK: - Validation

    /// Decides whether an item sending a controller action should be enabled.
    open func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool {
        guard let action = item.action else {
            return true
        }
        switch action.name {
        case "saveAllDocuments:":
            return hasEditedDocuments
        case "clearRecentDocuments:":
            return !recentDocumentURLs.isEmpty
        default:
            return responds(to: action)
        }
    }

    /// Routes menu validation to `validateUserInterfaceItem(_:)`.
    open func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        validateUserInterfaceItem(menuItem)
    }

    // MARK: - Selector dispatch
    //
    // The controller is the last link in `NSApplication`'s nil-target chain, so
    // these are the names a File menu's New and Open items carry. Same
    // mechanism and same hazard as `NSDocument`'s table: a name that is not
    // here silently does nothing.

    /// The Objective-C action names a document controller answers.
    private static var winControllerActions: [String: (NSDocumentController, Any?) -> Void] {
        [
            "newDocument:": { controller, sender in _ = controller.newDocument(sender) },
            "openDocument:": { controller, sender in controller.openDocument(sender) },
            "saveAllDocuments:": { controller, sender in controller.saveAllDocuments(sender) },
            "clearRecentDocuments:": { controller, sender in controller.clearRecentDocuments(sender) },
        ]
    }

    /// Reports whether the controller handles a document action selector.
    open override func responds(to aSelector: Selector?) -> Bool {
        guard let aSelector else {
            return false
        }
        if Self.winControllerActions[aSelector.name] != nil {
            return true
        }
        return super.responds(to: aSelector)
    }

    /// Dispatches a document action selector to its method.
    @discardableResult
    open override func perform(_ aSelector: Selector, with object: Any?) -> Any? {
        guard let handler = Self.winControllerActions[aSelector.name] else {
            return super.perform(aSelector, with: object)
        }
        handler(self, object)
        return nil
    }

    /// Sends an outcome selector to a delegate, when both are present.
    ///
    /// Same boxing as `NSDocument.notify(_:_:succeeded:contextInfo:)`; see that
    /// method for why the three arguments travel as one.
    internal func notify(_ delegate: Any?, _ selector: Selector?,
                         succeeded: Bool, contextInfo: UnsafeMutableRawPointer?) {
        guard let selector, let object = delegate as? NSObject,
              object.responds(to: selector) else {
            return
        }
        object.perform(selector, with: NSDocument.CallbackInfo(document: nil,
                                                               succeeded: succeeded,
                                                               contextInfo: contextInfo))
    }
}

extension NSDocumentController: NSUserInterfaceValidations {}
extension NSDocumentController: NSMenuItemValidation {}

/// Captures a document's `canClose` answer for the controller's bulk operations.
///
/// A tiny `NSObject` because the delegate contract is selector-based: the only
/// way to receive the answer is to be something `perform(_:with:)` can reach.
internal final class WinDocumentCloseRecorder: NSObject {
    /// Whether the document said it may close. False until told otherwise,
    /// because refusing is the answer that cannot lose the user's work.
    private(set) var allowed = false

    /// Claims the close-callback selector.
    override func responds(to aSelector: Selector?) -> Bool {
        aSelector?.name == "document:shouldClose:contextInfo:" || super.responds(to: aSelector)
    }

    /// Receives the answer, which travels in the callback box.
    @discardableResult
    override func perform(_ aSelector: Selector, with object: Any?) -> Any? {
        guard aSelector.name == "document:shouldClose:contextInfo:" else {
            return super.perform(aSelector, with: object)
        }
        allowed = (object as? NSDocument.CallbackInfo)?.succeeded ?? false
        return nil
    }
}
