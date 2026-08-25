/// A selectable menu command or submenu owner.
///
/// `NSMenuItem` keeps AppKit-compatible `title`, `action`, `keyEquivalent`,
/// `target`, and `submenu` properties. On Windows, action dispatch is bridged
/// through `performAction()`, dispatching the real target/action selector.
open class NSMenuItem: NSObject {
    /// The menu item title.
    open var title: String

    /// The action selector associated with this item.
    open var action: Selector?

    /// The keyboard equivalent string.
    open var keyEquivalent: String

    /// Modifier flags used with the keyboard equivalent.
    open var keyEquivalentModifierMask: NSEvent.ModifierFlags = [.command]

    /// The target object for selector-shaped dispatch.
    open weak var target: AnyObject?

    /// Whether the menu item can be performed.
    open var isEnabled: Bool = true

    /// An integer the application uses to identify the item.
    ///
    /// Find menu items carry `NSTextFinder.Action` raw values here, matching
    /// AppKit's tag-driven find dispatch.
    open var tag: Int = 0

    /// Whether the menu item is hidden from native menu construction.
    open var isHidden: Bool = false

    /// The menu item state for checkmark-like menus.
    open var state: NSControl.StateValue = .off

    /// The submenu opened by this item, if any.
    open var submenu: NSMenu?

    /// The parent menu containing this item.
    public weak var menu: NSMenu?

    /// An object the application associates with the item.
    ///
    /// AppKit never reads this; it exists so a menu can carry the model object
    /// its action needs without a parallel dictionary keyed by tag.
    open var representedObject: Any?

    /// An icon shown beside the title.
    ///
    /// Backends that can draw a menu icon do; where the native menu has no
    /// image slot the title still shows, because a menu item that vanished
    /// because of its decoration would be worse than one drawn plainly.
    open var image: NSImage?

    /// A styled title, taking precedence over `title` where the backend can
    /// render runs.
    ///
    /// Its plain text is kept in `title` as well, so a backend that draws only
    /// strings still shows the right words.
    open var attributedTitle: NSAttributedString? {
        didSet {
            if let attributedTitle {
                title = attributedTitle.string
            }
        }
    }

    /// How far the item is indented, in AppKit's indentation levels (0–15).
    open var indentationLevel: Int = 0

    /// Whether the item replaces the one above it while its modifiers are held.
    open var isAlternate: Bool = false

    /// A custom view drawn in place of the item's title.
    open var view: NSView?

    /// Whether the item is a section header rather than a command.
    ///
    /// AppKit's own header items are disabled and unselectable; setting this
    /// makes the item behave that way rather than merely look like it.
    open var isSectionHeader: Bool = false

    /// Creates a section header item, matching AppKit's factory.
    open class func sectionHeader(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isSectionHeader = true
        item.isEnabled = false
        return item
    }

    /// Framework-internal action hook for menu items the framework builds
    /// itself (search-field recents, toolbar context menus). Not API:
    /// application menu items use real target/action.
    var winInternalAction: ((NSMenuItem) -> Void)?

    /// Creates a blank item, matching AppKit's shape — callers set the title
    /// or attach a submenu afterwards.
    public override convenience init() {
        self.init(title: "", action: nil, keyEquivalent: "")
    }

    /// Creates a menu item.
    public init(title string: String, action selector: Selector?, keyEquivalent charCode: String) {
        self.title = string
        self.action = selector
        self.keyEquivalent = charCode
        super.init()
    }

    /// Performs the item action when enabled.
    @discardableResult
    open func performAction() -> Bool {
        guard isEnabled else {
            return false
        }

        if let winInternalAction {
            winInternalAction(self)
            return true
        }

        // Real AppKit dispatch: the action selector goes to the explicit
        // target, or down the nil-target responder chain (which ends at
        // `NSApplication`, so `terminate:` works with no target set).
        if let action {
            return NSApplication.shared.sendAction(action, to: target, from: self)
        }

        return false
    }

    /// Creates a separator item.
    public static func separator() -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    /// Whether this item is a separator.
    open var isSeparatorItem: Bool {
        title.isEmpty && action == nil && submenu == nil
    }
}
