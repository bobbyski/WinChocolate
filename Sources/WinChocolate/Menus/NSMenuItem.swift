/// A selectable menu command or submenu owner.
///
/// `NSMenuItem` keeps AppKit-compatible `title`, `action`, `keyEquivalent`,
/// `target`, and `submenu` properties. On Windows, action dispatch is bridged
/// through `performAction()` and the Swift-native `onAction` closure.
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

    /// Swift-native action invoked by `performAction()`.
    open var onAction: ((NSMenuItem) -> Void)?

    /// Creates a blank item, matching AppKit's shape — callers set the title
    /// or attach a submenu afterwards.
    public convenience init() {
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

        if let onAction {
            onAction(self)
            return true
        }

        if action?.name == "terminate:" {
            let application = target as? NSApplication ?? NSApplication.shared
            application.terminate(self)
            return true
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
