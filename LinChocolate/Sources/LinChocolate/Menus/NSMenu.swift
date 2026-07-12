import Foundation

/// AppKit-shaped menu item: a titled entry with an action, or a separator.
public final class NSMenuItem {

    /// The item's displayed title.
    public var title: String

    /// Whether the item draws as a separator line.
    public let isSeparatorItem: Bool

    /// Called when the user picks the item.
    public var onAction: ((NSMenuItem) -> Void)?

    /// Creates a titled, actionable item.
    public init(title: String, onAction: ((NSMenuItem) -> Void)? = nil) {
        self.title = title
        self.isSeparatorItem = false
        self.onAction = onAction
    }

    private init(separator: Bool) {
        self.title = ""
        self.isSeparatorItem = separator
        self.onAction = nil
    }

    /// A separator line, as in AppKit.
    public static func separator() -> NSMenuItem { NSMenuItem(separator: true) }
}

/// AppKit-shaped menu: a titled list of items. Assign a menu of menus to
/// `NSApplication.mainMenu` to show the menu bar (rendered natively by
/// GtkPopoverMenuBar on Linux).
public final class NSMenu {

    /// The menu's title (shown in the menu bar for top-level menus).
    public var title: String

    /// The items, in order.
    public private(set) var items: [NSMenuItem] = []

    /// Submenus of top-level items, keyed by the item. (Slice: the main menu is
    /// one level deep — each top-level item carries its submenu here.)
    var submenus: [ObjectIdentifier: NSMenu] = [:]

    public init(title: String = "") {
        self.title = title
    }

    /// Appends `item`.
    public func addItem(_ item: NSMenuItem) {
        items.append(item)
    }

    /// Appends a titled item wired to `action` and returns it.
    @discardableResult
    public func addItem(withTitle title: String, action: ((NSMenuItem) -> Void)? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, onAction: action)
        addItem(item)
        return item
    }

    /// Attaches `submenu` under `item` (AppKit's `setSubmenu(_:for:)`).
    public func setSubmenu(_ submenu: NSMenu, for item: NSMenuItem) {
        submenus[ObjectIdentifier(item)] = submenu
    }

    /// Flattens this menu-of-menus into backend specs: each top-level item with
    /// a submenu becomes one menu-bar entry.
    func menuBarSpecs() -> [NativeMenuSpec] {
        items.compactMap { item in
            guard let submenu = submenus[ObjectIdentifier(item)] else { return nil }
            let itemSpecs = submenu.items.map { sub in
                NativeMenuItemSpec(
                    title: sub.title,
                    isSeparator: sub.isSeparatorItem,
                    action: sub.isSeparatorItem ? nil : { [weak sub] in
                        guard let sub else { return }
                        sub.onAction?(sub)
                    }
                )
            }
            let title = item.title.isEmpty ? submenu.title : item.title
            return NativeMenuSpec(title: title, items: itemSpecs)
        }
    }
}
