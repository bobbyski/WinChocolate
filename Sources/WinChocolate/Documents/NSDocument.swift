/// Errors thrown by the base document implementation.
///
/// AppKit reports document failures through `NSError`; WinChocolate's
/// Foundation shim has no `NSError`, so the base class throws this Swift
/// error enum instead.
public enum NSDocumentError: Error, Equatable {
    /// A subclass did not override a required data or reading method.
    case unimplemented
}

/// An abstract model object that owns, reads, and writes one document's data.
///
/// This first slice covers the parts of AppKit's document architecture that
/// ported applications reach for most: file identity (`fileURL`, `fileType`,
/// `displayName`), the change count driving `isDocumentEdited`, throwing
/// data/read/write overridables, and menu-driven `save`/`saveAs` flows that
/// present an `NSSavePanel` when the document has no destination yet.
open class NSDocument: NSObject {
    /// A change to the document's edited state.
    ///
    /// Subset of AppKit's `NSDocument.ChangeType`; the undo-coalescing cases
    /// arrive with undo support.
    public enum ChangeType {
        /// A change that makes the document edited.
        case changeDone

        /// A change that marks the document as saved.
        case changeCleared
    }

    /// The document's on-disk location, when saved or opened.
    open var fileURL: URL?

    /// The document's type name, when known.
    open var fileType: String?

    /// The most recent save or write failure.
    ///
    /// Menu-driven `save(_:)`/`saveAs(_:)` have no throwing surface, so
    /// failures are reported here instead of being silently swallowed.
    public private(set) var lastError: Error?

    /// Whether the document has unsaved changes.
    open private(set) var isDocumentEdited = false

    /// The window controllers presenting this document.
    open private(set) var windowControllers: [NSWindowController] = []

    /// Whether documents of this class save automatically in place.
    ///
    /// Subclasses return true to opt in, matching AppKit; the shared
    /// document controller then autosaves edited documents that have a file
    /// on a periodic run-loop timer.
    open class var autosavesInPlace: Bool {
        false
    }

    private var autosaveTimer: Timer?

    /// Creates an empty document.
    ///
    /// `required` so `NSDocumentController` can instantiate its configured
    /// document class from a metatype.
    public required override init() {
        super.init()
    }

    /// The name shown in window titles: the file name, or "Untitled".
    open var displayName: String {
        fileURL?.lastPathComponent ?? "Untitled"
    }

    /// Creates this document's window controllers. Subclasses override.
    ///
    /// The base implementation creates nothing, matching AppKit's contract
    /// where documents without nib-driven windows build their own.
    open func makeWindowControllers() {
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

    /// Updates the change count that decides `isDocumentEdited`.
    open func updateChangeCount(_ change: ChangeType) {
        switch change {
        case .changeDone:
            isDocumentEdited = true
        case .changeCleared:
            isDocumentEdited = false
        }
        synchronizeWindowTitles()
    }

    private func synchronizeWindowTitles() {
        for controller in windowControllers {
            controller.synchronizeWindowTitleWithDocumentName()
        }
    }

    /// Returns the document's data for writing. Subclasses must override.
    open func data(ofType typeName: String) throws -> Data {
        throw NSDocumentError.unimplemented
    }

    /// Loads document contents from data. Subclasses must override.
    open func read(from data: Data, ofType typeName: String) throws {
        throw NSDocumentError.unimplemented
    }

    /// Loads document contents from a file URL and records the file identity.
    open func read(from url: URL, ofType typeName: String) throws {
        let data = try Data(contentsOf: url)
        try read(from: data, ofType: typeName)
        fileURL = url
        fileType = typeName
    }

    /// Writes the document's data to a file URL.
    open func write(to url: URL, ofType typeName: String) throws {
        let data = try data(ofType: typeName)
        try data.write(to: url)
    }

    /// Saves the document, asking for a destination when it has none.
    ///
    /// Failures land in `lastError` because menu actions cannot throw.
    open func save(_ sender: Any?) {
        guard let fileURL else {
            runSavePanelAndWrite()
            return
        }

        write(to: fileURL)
    }

    /// Saves the document to a destination chosen in a save panel.
    open func saveAs(_ sender: Any?) {
        runSavePanelAndWrite()
    }

    /// Closes the document, its windows, and its controller registration.
    open func close() {
        autosaveTimer?.invalidate()
        autosaveTimer = nil
        for controller in windowControllers {
            controller.close()
        }
        windowControllers.removeAll()
        NSDocumentController.shared.removeDocument(self)
    }

    /// Saves in place when the document is edited and bound to a file.
    ///
    /// Untitled documents are skipped: with no destination there is nothing
    /// to autosave without prompting, which autosave must never do.
    open func autosave() {
        guard isDocumentEdited, fileURL != nil else {
            return
        }

        save(nil)
    }

    /// Starts the periodic autosave timer for opted-in document classes.
    internal func startAutosaveTimerIfNeeded() {
        guard type(of: self).autosavesInPlace, autosaveTimer == nil else {
            return
        }

        autosaveTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.autosave()
        }
    }

    private func runSavePanelAndWrite() {
        let panel = NSSavePanel.savePanel()
        panel.nameFieldStringValue = displayName
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        write(to: url)
    }

    private func write(to url: URL) {
        do {
            try write(to: url, ofType: fileType ?? url.pathExtension)
            fileURL = url
            lastError = nil
            updateChangeCount(.changeCleared)
        } catch {
            lastError = error
        }
    }
}
