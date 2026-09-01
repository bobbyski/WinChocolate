/// Manages one window, and connects it to a document when there is one.
///
/// A window controller is the link between a document and what the user sees.
/// Its two jobs are keeping the window's title in step with the document's
/// name, and standing in the responder chain so document actions can travel
/// through it:
///
/// ```
///   window ──nextResponder──▶ NSWindowController
///                                    │
///                                    └─ supplementalTarget(forAction:) ──▶ document
/// ```
///
/// That second job is why a File menu works with nothing wired up: a
/// `saveDocument:` sent to no target walks up from the key window, reaches this
/// controller, finds nothing, and is offered the document.
open class NSWindowController: NSResponder {
    // MARK: - Window

    /// Backing store, so `window` can load lazily on first access.
    private var storedWindow: NSWindow?

    /// Whether `loadWindow()` has already run, so it runs exactly once.
    private var hasAttemptedLoad = false

    /// The window this controller manages.
    ///
    /// Reading this loads the window when the controller was created from a nib
    /// name and has not loaded yet — measured against AppKit, where
    /// `isWindowLoaded` is false until the first read and the load sequence
    /// (`windowWillLoad()` → `loadWindow()` → `windowDidLoad()`) runs once.
    ///
    /// Assigning a window links it back, so a controller that builds its window
    /// inside `loadWindow()` still lands in that window's responder chain.
    open var window: NSWindow? {
        get {
            if storedWindow == nil, !hasAttemptedLoad, windowNibName != nil {
                loadWindowIfNeeded()
            }
            return storedWindow
        }
        set {
            let oldValue = storedWindow
            storedWindow = newValue
            guard newValue !== oldValue else {
                return
            }
            if oldValue?.windowController === self {
                oldValue?.windowController = nil
            }
            newValue?.windowController = self
            if newValue != nil, newValue?.delegate == nil {
                newValue?.delegate = self
            }
        }
    }

    /// Whether the controller's window has been loaded.
    open var isWindowLoaded: Bool {
        storedWindow != nil
    }

    /// The nib this controller loads its window from, when it uses one.
    open private(set) var windowNibName: NSNib.Name?

    /// The path of the nib this controller loads its window from.
    open private(set) var windowNibPath: String?

    /// The object nib connections resolve against. The controller itself by
    /// default, matching AppKit's `init(windowNibName:)`.
    open private(set) weak var owner: AnyObject?

    /// The autosave name the window's frame is remembered under.
    open var windowFrameAutosaveName: String = "" {
        didSet {
            window?.setFrameAutosaveName(windowFrameAutosaveName)
        }
    }

    // MARK: - Document

    /// The document this controller is showing, when there is one.
    ///
    /// Typed `AnyObject?` because Apple's is (`@property (nullable, assign) id
    /// document`). Callers write `controller.document as? NSDocument`. It was
    /// previously typed `NSDocument?` here, which was more convenient and not
    /// what AppKit says — and the set-in-stone rule is that Apple's API is the
    /// specification, convenience included.
    open weak var document: AnyObject? {
        didSet {
            synchronizeWindowTitleWithDocumentName()
            setDocumentEdited((document as? NSDocument)?.isDocumentEdited ?? false)
        }
    }

    /// Whether closing this controller's window should close its document.
    ///
    /// Defaults to false like AppKit; documents set it on their last remaining
    /// controller.
    open var shouldCloseDocument = false

    /// Whether successive windows are offset from each other rather than
    /// opening in the same place.
    ///
    /// True, as AppKit's is (measured). Apps set it false when they restore
    /// window frames themselves and do not want the cascade fighting them.
    open var shouldCascadeWindows = true

    /// The view controller supplying the window's content.
    open var contentViewController: NSViewController? {
        didSet {
            guard let contentViewController else {
                return
            }
            window?.contentView = contentViewController.view
        }
    }

    // MARK: - Creating

    /// Creates a controller managing a window.
    ///
    /// The controller becomes the window's delegate when it has none, so
    /// document windows get the save-changes prompt and close bookkeeping, and
    /// takes its place in the window's responder chain so document actions can
    /// reach through it.
    public init(window: NSWindow?) {
        super.init()
        // Through the property, so the window linking and delegate adoption
        // happen in one place rather than being repeated per initializer.
        self.window = window
        self.hasAttemptedLoad = window != nil
    }

    /// Creates a controller that loads its window from a nib.
    ///
    /// The window is **not** loaded here: as on Apple, loading is deferred to
    /// the first read of `window`. An earlier version of this loaded eagerly in
    /// the initializer, which meant `windowDidLoad()` ran before a caller could
    /// configure the controller it was called on.
    public convenience init(windowNibName: NSNib.Name) {
        self.init(windowNibName: windowNibName, owner: NSNull())
    }

    /// Creates a controller loading from a nib with an explicit owner.
    public init(windowNibName: NSNib.Name, owner: Any) {
        super.init()
        self.windowNibName = windowNibName
        // Apple types this `Any` and non-optional, and `init(windowNibName:)`
        // documents the controller as its own owner. `NSNull` is the marker
        // that single-argument form passes, since there is no nil to pass.
        self.owner = (owner as? NSNull) == nil ? owner as AnyObject : self
    }

    /// Creates a controller loading from a nib at a path.
    public init(windowNibPath: String, owner: Any) {
        super.init()
        self.windowNibPath = windowNibPath
        self.owner = (owner as? NSNull) == nil ? owner as AnyObject : self
    }

    // MARK: - Loading

    /// Runs the load sequence once, if it has not run already.
    private func loadWindowIfNeeded() {
        guard !hasAttemptedLoad else {
            return
        }
        hasAttemptedLoad = true

        windowWillLoad()
        (document as? NSDocument)?.windowControllerWillLoadNib(self)
        loadWindow()
        (document as? NSDocument)?.windowControllerDidLoadNib(self)
        windowDidLoad()
    }

    /// Loads the controller's window.
    ///
    /// The default reads the nib named by `windowNibName` (or found at
    /// `windowNibPath`) and takes its first top-level window. A subclass may
    /// override to build a window in code instead — that is the supported way
    /// to have a lazily-created window without a nib at all.
    open func loadWindow() {
        let nib: NSNib?
        if let windowNibName {
            nib = NSNib(nibNamed: windowNibName, bundle: nil)
        } else if let windowNibPath {
            nib = NSNib(nibNamed: NSNib.Name(windowNibPath), bundle: nil)
        } else {
            nib = nil
        }

        guard let nib, let instance = nib.winInstantiate(withOwner: owner) else {
            return
        }
        window = instance.topLevelObjects.compactMap { $0 as? NSWindow }.first
    }

    /// Called just before the controller's window loads.
    open func windowWillLoad() {
    }

    /// Called after the controller's window has loaded.
    open func windowDidLoad() {
    }

    // MARK: - Showing and closing

    /// Shows the controller's window and makes it key.
    open func showWindow(_ sender: Any?) {
        window?.makeKeyAndOrderFront(sender)
    }

    /// Closes the controller's window.
    open func close() {
        storedWindow?.close()
    }

    /// Dismisses the controller, closing its window.
    open func dismissController(_ sender: Any?) {
        close()
    }

    // MARK: - Titles

    /// Rewrites the window title from the document's display name.
    ///
    /// Also sets `representedURL`, which is what lets a window show its file's
    /// identity in the way its own platform does.
    open func synchronizeWindowTitleWithDocumentName() {
        guard let window = storedWindow, let document = document as? NSDocument else {
            return
        }
        window.title = windowTitle(forDocumentDisplayName: document.displayName)
        window.representedURL = document.fileURL
    }

    /// Returns the window title for a document display name.
    ///
    /// Returns the name **unchanged**, which is what AppKit does even for an
    /// edited document — measured in Docs/NSDOCUMENT_PLAN.md § Ground Truth.
    /// This framework used to prepend `"*"` here; that was a divergence, and
    /// the asterisk has moved to where it belongs, the Win32 and GTK window
    /// chrome, which draw it as their native rendering of
    /// `NSWindow.isDocumentEdited`.
    open func windowTitle(forDocumentDisplayName displayName: String) -> String {
        displayName
    }

    /// Marks the window as having unsaved changes.
    ///
    /// Each backend renders this its own way — a dot in the close button on a
    /// Mac, an asterisk in the title bar on Windows and GTK.
    open func setDocumentEdited(_ dirtyFlag: Bool) {
        storedWindow?.isDocumentEdited = dirtyFlag
    }

    // MARK: - Responder chain

    /// Offers this controller's document to the responder chain.
    ///
    /// `NSDocument` is not an `NSResponder`, so it cannot be a link in the
    /// chain itself. This is AppKit's answer, and it is what makes a File menu
    /// work with no target wired up.
    ///
    /// Verified against real AppKit — see `Docs/NSDOCUMENT_PLAN.md`
    /// § Ground Truth, where `supplementalTarget(forAction: "saveDocument:")`
    /// on a document's window controller returns the document.
    open override func supplementalTarget(forAction action: Selector, sender: Any?) -> Any? {
        if let document = document as? NSObject, document.responds(to: action) {
            return document
        }
        return super.supplementalTarget(forAction: action, sender: sender)
    }
}

extension NSWindowController: NSWindowDelegate {
    /// Asks the document whether the window may close.
    ///
    /// The three-way Save / Cancel / Don't Save prompt lives on `NSDocument`,
    /// where AppKit keeps it — this controller used to run its own, which asked
    /// about unsaved changes even when closing one of several windows onto the
    /// same document.
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let document = document as? NSDocument, document.isDocumentEdited else {
            return true
        }

        let recorder = WinDocumentCloseRecorder()
        document.shouldCloseWindowController(
            self,
            delegate: recorder,
            shouldClose: Selector("document:shouldClose:contextInfo:"),
            contextInfo: nil)
        return recorder.allowed
    }

    /// Detaches from the document, closing it with its last window.
    public func windowWillClose(_ notification: Notification) {
        guard let document = document as? NSDocument else {
            return
        }
        document.removeWindowController(self)
        if document.windowControllers.isEmpty {
            document.close()
        }
    }
}
