import Foundation

/// AppKit-shaped keyboard modifier flags (subset), for menu key equivalents.
public struct NSEventModifierFlags: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let capsLock = NSEventModifierFlags(rawValue: 1 << 0)
    public static let shift = NSEventModifierFlags(rawValue: 1 << 1)
    public static let control = NSEventModifierFlags(rawValue: 1 << 2)
    public static let option = NSEventModifierFlags(rawValue: 1 << 3)
    public static let command = NSEventModifierFlags(rawValue: 1 << 4)
}

/// AppKit-shaped menu item: a titled entry with an action, or a separator.
public final class NSMenuItem {

    /// The item's displayed title.
    public var title: String

    /// Whether the item draws as a separator line.
    public let isSeparatorItem: Bool

    /// Called when the user picks the item.
    public var onAction: ((NSMenuItem) -> Void)?

    /// The key (e.g. "n") that triggers the item; empty = none.
    public var keyEquivalent: String = ""

    /// Modifiers for the key equivalent (Command maps to Control on Linux).
    public var keyEquivalentModifierMask: NSEventModifierFlags = .command

    /// The GTK accelerator string (e.g. "<Control>n"), or nil if no key set.
    var gtkAccelerator: String? {
        guard !keyEquivalent.isEmpty else { return nil }
        var mods = ""
        if keyEquivalentModifierMask.contains(.control) || keyEquivalentModifierMask.contains(.command) { mods += "<Control>" }
        if keyEquivalentModifierMask.contains(.shift) { mods += "<Shift>" }
        if keyEquivalentModifierMask.contains(.option) { mods += "<Alt>" }
        return mods + keyEquivalent.lowercased()
    }

    // AppKit-standard members (accepted for parity; selector dispatch maps a
    // couple of well-known actions, others are no-ops until responder routing).
    public var action: String?
    public weak var target: AnyObject?
    public var isEnabled: Bool = true
    public var tag: Int = 0
    public var state: NSControlStateValue = .off
    public var submenu: NSMenu?
    public var image: NSImage?

    /// Creates a titled, actionable item.
    public init(title: String, onAction: ((NSMenuItem) -> Void)? = nil) {
        self.title = title
        self.isSeparatorItem = false
        self.onAction = onAction
    }

    /// AppKit's `init(title:action:keyEquivalent:)` (selector-string action).
    public convenience init(title: String, action: String?, keyEquivalent: String) {
        let closure: ((NSMenuItem) -> Void)? = (action == "terminate:")
            ? { _ in NSApplication.shared.terminate(nil) } : nil
        self.init(title: title, onAction: closure)
        self.action = action
        self.keyEquivalent = keyEquivalent
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
            // A submenu may be attached either via `setSubmenu(_:for:)` (parent's
            // `submenus` map) or the AppKit-style `menuItem.submenu` property.
            guard let submenu = item.submenu ?? submenus[ObjectIdentifier(item)] else { return nil }
            let itemSpecs = submenu.items.map { sub in
                NativeMenuItemSpec(
                    title: sub.title,
                    isSeparator: sub.isSeparatorItem,
                    accelerator: sub.gtkAccelerator,
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
