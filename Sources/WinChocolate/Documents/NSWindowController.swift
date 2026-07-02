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
    public init(window: NSWindow?) {
        self.window = window
        super.init()
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
