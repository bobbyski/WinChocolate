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

    /// Performs the first item whose key equivalent matches a key event.
    ///
    /// Items and submenus are walked in order. An item matches when its
    /// `keyEquivalent` equals the event's characters case-insensitively and the
    /// event modifiers satisfy the item's `keyEquivalentModifierMask`. Windows
    /// keyboards map Command shortcuts onto Control, so a `.command`
    /// requirement is satisfied by either the Control key or the Windows
    /// (Command) key.
    @discardableResult
    open func performKeyEquivalent(with event: NSEvent) -> Bool {
        for item in items {
            if !item.keyEquivalent.isEmpty,
               event.characters?.lowercased() == item.keyEquivalent.lowercased(),
               modifierFlags(event.modifierFlags, satisfy: item.keyEquivalentModifierMask) {
                _ = item.performAction()
                return true
            }

            if let submenu = item.submenu, submenu.performKeyEquivalent(with: event) {
                return true
            }
        }
        return false
    }

    /// Shows the menu as a context menu at a location in a view's coordinates.
    ///
    /// The location is converted from the view's coordinate space to the
    /// screen before the native menu is tracked. The positioning item is
    /// accepted for AppKit compatibility but does not offset the menu on the
    /// classic backend. Returns `true` when an item was chosen and performed.
    @discardableResult
    open func popUp(positioning item: NSMenuItem?, at location: NSPoint, in view: NSView?) -> Bool {
        let windowPoint = view?.convert(location, to: nil) ?? location
        let windowOrigin = view?.window?.frame.origin ?? NSZeroPoint
        let screenPoint = NSPoint(x: windowOrigin.x + windowPoint.x, y: windowOrigin.y + windowPoint.y)
        let backend = view?.realizedBackend ?? NSApplication.shared.nativeBackend
        return backend.runContextMenu(self, atScreenPoint: screenPoint) != nil
    }

    /// Returns whether event modifiers satisfy a key-equivalent mask, treating
    /// `.command` as satisfied by Control because Windows maps Cmd to Ctrl.
    private func modifierFlags(_ flags: NSEvent.ModifierFlags, satisfy mask: NSEvent.ModifierFlags) -> Bool {
        var required = mask
        if required.contains(.command) {
            required.remove(.command)
            guard flags.contains(.command) || flags.contains(.control) else {
                return false
            }
        }
        return flags.isSuperset(of: required)
    }

    private func clampedInsertionIndex(_ index: Int) -> Int {
        min(max(index, 0), items.count)
    }
}
