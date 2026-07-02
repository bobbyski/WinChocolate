/// The shared registry that tracks open documents and drives the Open flow.
///
/// This first slice covers the shared controller, the open-documents list,
/// the recent-documents list, and a panel-driven `openDocument(_:)`.
open class NSDocumentController: NSObject {
    /// The shared document controller.
    ///
    /// WinChocolate UI objects are single-threaded on the main thread, so the
    /// shared instance opts out of strict concurrency checking like the other
    /// framework singletons.
    nonisolated(unsafe) public static let shared = NSDocumentController()

    /// All open documents, in the order they were added.
    open private(set) var documents: [NSDocument] = []

    /// The document most recently opened or added.
    open var currentDocument: NSDocument?

    /// Recently opened document locations, most recent first.
    open private(set) var recentDocumentURLs: [URL] = []

    /// The document class `openDocument(_:)` instantiates.
    ///
    /// AppKit resolves document classes from Info.plist document types;
    /// WinChocolate has no Info.plist yet, so this `win`-prefixed hook lets an
    /// application point the shared controller at its `NSDocument` subclass.
    open var winDocumentClass: NSDocument.Type = NSDocument.self

    /// Creates a document controller.
    public override init() {
        super.init()
    }

    /// Registers a document and makes it current.
    open func addDocument(_ document: NSDocument) {
        documents.append(document)
        currentDocument = document
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
        let document = winDocumentClass.init()
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
            let document = winDocumentClass.init()
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
