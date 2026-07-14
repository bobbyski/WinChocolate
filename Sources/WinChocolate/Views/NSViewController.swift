/// Controller object that owns a view.
///
/// Covers AppKit's `view` ownership shape (so controls such as `NSPopover`
/// can accept controller-backed content) and nib-based loading (Phase 15.5):
/// `init(nibName:bundle:)` loads the controller's view from a `.xib`.
open class NSViewController: NSResponder {
    /// The controller's root view.
    open var view: NSView {
        didSet { view.nextResponder = self }
    }

    /// The nib name the controller was created with, if any.
    public private(set) var nibName: NSNib.Name?

    /// The bundle the controller's nib loads from, if any.
    public private(set) var nibBundle: Bundle?

    /// Creates a view controller with an empty root view.
    public override convenience init() {
        self.init(view: NSView(frame: NSZeroRect))
    }

    /// Creates a view controller with an explicit root view.
    public init(view: NSView) {
        self.view = view
        super.init()
        self.view.nextResponder = self
    }

    /// Creates a view controller that loads its view from a nib, matching
    /// AppKit's designated initializer. The view loads immediately (AppKit
    /// defers to first access; WinChocolate's stored `view` loads eagerly —
    /// `viewDidLoad()` still runs after the view is set).
    public convenience init(nibName: NSNib.Name?, bundle: Bundle? = nil) {
        self.init(view: NSView(frame: NSZeroRect))
        self.nibName = nibName
        self.nibBundle = bundle
        loadView()
        viewDidLoad()
    }

    /// Loads the controller's view: from the nib when a nib name was given
    /// (the first top-level view becomes `view`), else keeps the current
    /// view. Override to build the view in code, as in AppKit.
    open func loadView() {
        guard let nibName,
              let nib = NSNib(nibNamed: nibName, bundle: nibBundle),
              let instance = nib.winInstantiate(withOwner: self) else {
            return
        }
        if let loaded = instance.topLevelObjects.compactMap({ $0 as? NSView }).first {
            view = loaded
        }
    }

    /// Called after the controller's view is loaded, matching AppKit.
    open func viewDidLoad() {
    }
}
