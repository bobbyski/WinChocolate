/// The shared registry that tracks open documents and drives the Open flow.
///
/// This first slice covers the shared controller, the open-documents list,
/// the recent-documents list, and a panel-driven `openDocument(_:)`.
open class NSDocumentController: NSObject {
    /// Backing store for `shared`, captured by the first instantiation.
    nonisolated(unsafe) private static var sharedStorage: NSDocumentController?

    /// The shared document controller.
    ///
    /// As in AppKit, **the first document controller instantiated becomes the
    /// shared one** — an application subclasses `NSDocumentController`
    /// (overriding `documentClass(forType:)`) and creates its instance early;
    /// otherwise a plain controller is created on first access.
    /// WinChocolate UI objects are single-threaded on the main thread, so the
    /// shared instance opts out of strict concurrency checking like the other
    /// framework singletons.
    public static var shared: NSDocumentController {
        if let sharedStorage {
            return sharedStorage
        }

        return NSDocumentController()
    }

    /// All open documents, in the order they were added.
    open private(set) var documents: [NSDocument] = []

    /// The document most recently opened or added.
    open var currentDocument: NSDocument?

    /// Recently opened document locations, most recent first.
    open private(set) var recentDocumentURLs: [URL] = []

    /// The fallback document class when `documentClass(forType:)` is not
    /// overridden. Not API (18.8): applications override AppKit's real
    /// `documentClass(forType:)` on an `NSDocumentController` subclass.
    package var winDocumentClass: NSDocument.Type = NSDocument.self

    /// Returns the document class for a type, matching AppKit's
    /// `documentClass(forType:)`. AppKit resolves this from Info.plist
    /// document types; WinChocolate has no Info.plist, so subclasses override
    /// this to supply their `NSDocument` subclass (any type name maps to the
    /// app's one class in the common single-type case).
    open func documentClass(forType typeName: String) -> AnyClass? {
        winDocumentClass
    }

    /// The class `documentClass(forType:)` resolves, as a document type.
    private func winResolvedDocumentClass(forType typeName: String) -> NSDocument.Type {
        (documentClass(forType: typeName) as? NSDocument.Type) ?? winDocumentClass
    }

    /// Creates a document controller. As in AppKit, the first controller
    /// created becomes `shared`.
    public override init() {
        super.init()
        if NSDocumentController.sharedStorage == nil {
            NSDocumentController.sharedStorage = self
        }
    }

    /// Registers a document and makes it current.
    open func addDocument(_ document: NSDocument) {
        documents.append(document)
        currentDocument = document
        document.startAutosaveTimerIfNeeded()
    }

    /// Removes a document from the open-documents list.
    open func removeDocument(_ document: NSDocument) {
        documents.removeAll { $0 === document }
        if currentDocument === document {
            currentDocument = documents.last
        }
    }

    /// Creates a new untitled document with its windows shown.
    @discardableResult
    open func newDocument(_ sender: Any?) -> NSDocument {
        let document = winResolvedDocumentClass(forType: "").init()
        addDocument(document)
        document.makeWindowControllers()
        document.showWindows()
        return document
    }

    /// Presents an open panel and opens each chosen file as a document.
    ///
    /// Each URL becomes an instance of `winDocumentClass` with its window
    /// controllers made and shown; URLs whose read fails are skipped without
    /// adding a document.
    open func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel.openPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else {
            return
        }

        for url in panel.urls {
            let document = winResolvedDocumentClass(forType: url.pathExtension).init()
            do {
                try document.read(from: url, ofType: url.pathExtension)
            } catch {
                continue
            }

            addDocument(document)
            document.makeWindowControllers()
            document.showWindows()
            noteNewRecentDocumentURL(url)
        }
    }

    /// Moves a URL to the front of the recent-documents list.
    ///
    /// The list deduplicates by URL and keeps at most ten entries.
    open func noteNewRecentDocumentURL(_ url: URL) {
        recentDocumentURLs.removeAll { $0 == url }
        recentDocumentURLs.insert(url, at: 0)
        if recentDocumentURLs.count > 10 {
            recentDocumentURLs.removeLast(recentDocumentURLs.count - 10)
        }
    }

    /// Clears the recent-documents list.
    open func clearRecentDocuments(_ sender: Any?) {
        recentDocumentURLs = []
    }
}
