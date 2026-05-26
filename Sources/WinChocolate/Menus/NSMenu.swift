/// A menu or menu bar containing menu items.
///
/// `NSMenu` mirrors AppKit's tree-shaped menu model. A top-level menu assigned
/// to `NSApplication.mainMenu` represents the menu bar; items inside it may own
/// submenus such as the application menu containing Quit.
open class NSMenu: NSObject {
    /// The menu title.
    open var title: String

    /// Items contained by this menu.
    public private(set) var items: [NSMenuItem] = []

    /// Creates an untitled menu.
    public override convenience init() {
        self.init(title: "")
    }

    /// Creates a menu with a title.
    public init(title: String) {
        self.title = title
        super.init()
    }

    /// Adds an item to the end of the menu.
    open func addItem(_ newItem: NSMenuItem) {
        newItem.menu = self
        items.append(newItem)
    }

    /// Creates and adds a menu item.
    @discardableResult
    open func addItem(withTitle string: String, action selector: Selector?, keyEquivalent charCode: String) -> NSMenuItem {
        let item = NSMenuItem(title: string, action: selector, keyEquivalent: charCode)
        addItem(item)
        return item
    }

    /// Inserts an item at a specific index.
    open func insertItem(_ newItem: NSMenuItem, at index: Int) {
        newItem.menu = self
        items.insert(newItem, at: index)
    }

    /// Removes an item from the menu.
    open func removeItem(_ item: NSMenuItem) {
        items.removeAll { $0 === item }
        item.menu = nil
    }

    /// Returns the first item with the requested title.
    open func item(withTitle title: String) -> NSMenuItem? {
        items.first { $0.title == title }
    }
}
