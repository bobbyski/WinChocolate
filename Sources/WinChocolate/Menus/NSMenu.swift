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

    /// Number of items in the menu.
    open var numberOfItems: Int {
        items.count
    }

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
        items.insert(newItem, at: clampedInsertionIndex(index))
    }

    /// Creates and inserts a menu item at a specific index.
    @discardableResult
    open func insertItem(withTitle string: String, action selector: Selector?, keyEquivalent charCode: String, at index: Int) -> NSMenuItem {
        let item = NSMenuItem(title: string, action: selector, keyEquivalent: charCode)
        insertItem(item, at: index)
        return item
    }

    /// Removes an item from the menu.
    open func removeItem(_ item: NSMenuItem) {
        items.removeAll { $0 === item }
        item.menu = nil
    }

    /// Removes an item at the given index.
    open func removeItem(at index: Int) {
        guard items.indices.contains(index) else {
            return
        }

        let item = items.remove(at: index)
        item.menu = nil
    }

    /// Removes every item from the menu.
    open func removeAllItems() {
        for item in items {
            item.menu = nil
        }
        items.removeAll()
    }

    /// Returns the item at the given index.
    open func item(at index: Int) -> NSMenuItem? {
        guard items.indices.contains(index) else {
            return nil
        }

        return items[index]
    }

    /// Returns the first item with the requested title.
    open func item(withTitle title: String) -> NSMenuItem? {
        items.first { $0.title == title }
    }

    /// Returns the index of the given item or `-1` when absent.
    open func index(of item: NSMenuItem) -> Int {
        items.firstIndex { $0 === item } ?? -1
    }

    /// Returns the index of the first item with the requested title or `-1`.
    open func indexOfItem(withTitle title: String) -> Int {
        items.firstIndex { $0.title == title } ?? -1
    }

    private func clampedInsertionIndex(_ index: Int) -> Int {
        min(max(index, 0), items.count)
    }
}
