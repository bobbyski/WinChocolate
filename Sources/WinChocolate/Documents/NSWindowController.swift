/// Manages one window of a document-based application.
///
/// This slice covers the programmatic form ported applications use most:
/// create a window, wrap it in a controller, attach the controller to an
/// `NSDocument`, and let the controller keep the window title in sync with
/// the document's name and edited state. Nib loading is out of scope.
open class NSWindowController: NSResponder {
    /// The window this controller manages.
    open var window: NSWindow?

    /// The document that owns this controller, when attached to one.
    ///
    /// Typed as the document class directly rather than AppKit's historical
    /// `AnyObject`, which is what ported code expects to read anyway.
    open weak var document: NSDocument? {
        didSet {
            synchronizeWindowTitleWithDocumentName()
        }
    }

    /// Whether closing this controller's window should close its document.
    ///
    /// Defaults to false like AppKit; documents set it on their last
    /// remaining controller.
    open var shouldCloseDocument = false

    /// Creates a controller managing a window.
    ///
    /// The controller becomes the window's delegate when it has none, so
    /// document windows get the save-changes prompt and close bookkeeping.
    public init(window: NSWindow?) {
        self.window = window
        super.init()
        if let window, window.delegate == nil {
            window.delegate = self
        }
    }

    /// Creates a controller that loads its window from a nib (Phase 15.5):
    /// the nib's first top-level window becomes `window` and
    /// `windowDidLoad()` runs. Loads eagerly (AppKit defers to first access);
    /// File's Owner connections resolve against the controller.
    public convenience init(windowNibName: NSNib.Name, bundle: Bundle? = nil) {
        var loaded: NSWindow?
        if let nib = NSNib(nibNamed: windowNibName, bundle: bundle),
           let instance = nib.winInstantiate(withOwner: nil) {
            loaded = instance.topLevelObjects.compactMap { $0 as? NSWindow }.first
        }
        self.init(window: loaded)
        windowDidLoad()
    }

    /// Called after the controller's window loads from its nib, matching AppKit.
    open func windowDidLoad() {
    }

    /// Whether the controller currently has a window.
    open var isWindowLoaded: Bool {
        window != nil
    }

    /// Shows the controller's window and makes it key.
    open func showWindow(_ sender: Any?) {
        window?.makeKeyAndOrderFront(sender)
    }

    /// Closes the controller's window.
    open func close() {
        window?.close()
    }

    /// Rewrites the window title from the document's display name.
    ///
    /// Edited documents gain the classic Windows asterisk prefix, standing in
    /// for the macOS title-bar dirty dot.
    open func synchronizeWindowTitleWithDocumentName() {
        guard let window, let document else {
            return
        }

        window.title = windowTitle(forDocumentDisplayName: document.displayName)
    }

    /// Returns the window title for a document display name.
    open func windowTitle(forDocumentDisplayName displayName: String) -> String {
        if document?.isDocumentEdited == true {
            return "*\(displayName)"
        }
        return displayName
    }
}

extension NSWindowController: NSWindowDelegate {
    /// Asks to save unsaved document changes before the window closes.
    ///
    /// Save runs the document's save flow (which may present a save panel)
    /// and only allows the close once the document is clean; Cancel vetoes
    /// the close; Don't Save discards.
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let document, document.isDocumentEdited else {
            return true
        }

        let alert = NSAlert()
        alert.messageText = "Do you want to save the changes made to \(document.displayName)?"
        alert.informativeText = "Your changes will be lost if you don't save them."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Don't Save")

        var response = NSApplication.ModalResponse.alertSecondButtonReturn
        alert.beginSheetModal(for: sender) { alertResponse in
            response = alertResponse
        }

        switch response {
        case .alertFirstButtonReturn:
            document.save(nil)
            return !document.isDocumentEdited
        case .alertThirdButtonReturn:
            return true
        default:
            return false
        }
    }

    /// Detaches from the document, closing it with its last window.
    public func windowWillClose(_ notification: NSNotification) {
        guard let document else {
            return
        }

        document.removeWindowController(self)
        if document.windowControllers.isEmpty {
            document.close()
        }
    }
}
