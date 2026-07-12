import Foundation

/// AppKit-shaped toolbar item: an identifier, a label, and an action.
public final class NSToolbarItem {

    /// A toolbar item identifier (AppKit's `NSToolbarItem.Identifier`).
    public typealias Identifier = String

    /// Identifier for the flexible-space system item.
    public static let flexibleSpaceIdentifier = "NSToolbarFlexibleSpaceItem"

    /// Stable identifier (also used for the flexible-space system item).
    public let itemIdentifier: String

    /// The button's title.
    public var label: String = ""

    /// The label shown in the customization palette (defaults to `label`).
    public var paletteLabel: String = ""

    /// The item's icon (AppKit's `NSToolbarItem.image`).
    public var image: NSImage?

    /// Called when the user clicks the item.
    public var onAction: ((NSToolbarItem) -> Void)?

    public init(itemIdentifier: String) {
        self.itemIdentifier = itemIdentifier
    }

    /// A stretching spacer separating item groups (AppKit's flexible space).
    public static func flexibleSpace() -> NSToolbarItem {
        NSToolbarItem(itemIdentifier: flexibleSpaceIdentifier)
    }
}

/// AppKit-shaped toolbar customization hooks.
public protocol NSToolbarDelegate: AnyObject {
    /// Identifiers offered in the customization palette.
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]
    /// The default set of identifiers.
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]
    /// Supplies (or reuses) an item for an identifier being inserted.
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem?
}

public extension NSToolbarDelegate {
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [] }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [] }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? { nil }
}

/// AppKit-shaped toolbar. **Deliberate Apple-look exception** (plan Goal 2):
/// unlike every other control, the toolbar keeps Apple's look and feel — a
/// light gradient strip with flat, hover-highlighted buttons — rather than
/// adopting a native GTK header bar. Assign to `NSWindow.toolbar` to dock it
/// under the menu bar.
///
/// Customization: set `delegate` + `allowsUserCustomization`, then
/// `runCustomizationPalette(_:)` opens a sheet where the user toggles which
/// allowed items are in the toolbar (the toolbar updates live).
public final class NSToolbar {

    /// The toolbar's identifier.
    public let identifier: String

    /// The items, in display order.
    public private(set) var items: [NSToolbarItem] = []

    /// Whether the user may customize the toolbar.
    public var allowsUserCustomization: Bool = false

    /// The customization delegate. Assigning it loads the default items.
    public weak var delegate: NSToolbarDelegate? {
        didSet { loadDefaultItems() }
    }

    /// Whether the customization palette is currently open.
    public private(set) var customizationPaletteIsRunning = false

    /// The window this toolbar is installed on (set by `NSWindow.toolbar`).
    weak var window: NSWindow?

    public init(identifier: String) {
        self.identifier = identifier
    }

    /// Appends `item` and refreshes the installed toolbar.
    public func addItem(_ item: NSToolbarItem) {
        items.append(item)
        window?.reinstallToolbar()
    }

    /// Inserts the delegate's item for `identifier` at `index`.
    public func insertItem(withItemIdentifier identifier: NSToolbarItem.Identifier, at index: Int) {
        guard let item = makeItem(identifier) else { return }
        items.insert(item, at: min(max(index, 0), items.count))
        window?.reinstallToolbar()
    }

    /// Removes the item at `index`.
    public func removeItem(at index: Int) {
        guard items.indices.contains(index) else { return }
        items.remove(at: index)
        window?.reinstallToolbar()
    }

    /// Opens the customization palette (a sheet of the allowed items). Requires
    /// `allowsUserCustomization`, a `delegate`, and an installed window.
    public func runCustomizationPalette(_ sender: Any?) {
        guard allowsUserCustomization, let delegate, let window else { return }
        let present = Set(items.map { $0.itemIdentifier })
        let paletteItems = delegate.toolbarAllowedItemIdentifiers(self).map { id -> NativeToolbarPaletteItem in
            let label: String
            if id == NSToolbarItem.flexibleSpaceIdentifier {
                label = "Flexible Space"
            } else {
                let resolved = makeItem(id).map { $0.paletteLabel.isEmpty ? $0.label : $0.paletteLabel } ?? id
                label = resolved.isEmpty ? id : resolved
            }
            return NativeToolbarPaletteItem(identifier: id, label: label, isInToolbar: present.contains(id))
        }
        customizationPaletteIsRunning = true
        window.backend.runToolbarCustomization(
            paletteItems,
            onToggle: { [weak self] id, isOn in self?.setItem(id, present: isOn) },
            onClose: { [weak self] in self?.customizationPaletteIsRunning = false },
            for: window.handle
        )
    }

    /// Converts the items to backend specs.
    func specs() -> [NativeToolbarItemSpec] {
        items.map { item in
            NativeToolbarItemSpec(
                identifier: item.itemIdentifier,
                label: item.label,
                iconName: item.image?.iconName,
                isFlexibleSpace: item.itemIdentifier == NSToolbarItem.flexibleSpaceIdentifier,
                action: item.itemIdentifier == NSToolbarItem.flexibleSpaceIdentifier ? nil : { [weak item] in
                    guard let item else { return }
                    item.onAction?(item)
                }
            )
        }
    }

    // MARK: Internals

    private func makeItem(_ identifier: NSToolbarItem.Identifier) -> NSToolbarItem? {
        if identifier == NSToolbarItem.flexibleSpaceIdentifier { return NSToolbarItem.flexibleSpace() }
        return delegate?.toolbar(self, itemForItemIdentifier: identifier, willBeInsertedIntoToolbar: true)
    }

    private func loadDefaultItems() {
        guard let delegate else { return }
        let ids = delegate.toolbarDefaultItemIdentifiers(self)
        guard !ids.isEmpty else { return }
        items = ids.compactMap { makeItem($0) }
        window?.reinstallToolbar()
    }

    /// Adds or removes an item by identifier (from a palette toggle).
    private func setItem(_ identifier: NSToolbarItem.Identifier, present: Bool) {
        let index = items.firstIndex { $0.itemIdentifier == identifier }
        if present, index == nil {
            insertItem(withItemIdentifier: identifier, at: items.count)
        } else if !present, let index {
            removeItem(at: index)
        }
    }
}
