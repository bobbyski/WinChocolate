import Foundation

/// AppKit-shaped toolbar item: an identifier, a label, and an action.
public final class NSToolbarItem {

    /// Identifier for the flexible-space system item.
    public static let flexibleSpaceIdentifier = "NSToolbarFlexibleSpaceItem"

    /// Stable identifier (also used for the flexible-space system item).
    public let itemIdentifier: String

    /// The button's title.
    public var label: String = ""

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

/// AppKit-shaped toolbar. **Deliberate Apple-look exception** (plan Goal 2):
/// unlike every other control, the toolbar keeps Apple's look and feel — a
/// light gradient strip with flat, hover-highlighted buttons — rather than
/// adopting a native GTK header bar. Assign to `NSWindow.toolbar` to dock it
/// under the menu bar. (Delegate-based item management and the customization
/// sheet are later parity items; this slice uses a direct item list.)
public final class NSToolbar {

    /// The toolbar's identifier.
    public let identifier: String

    /// The items, in display order.
    public private(set) var items: [NSToolbarItem] = []

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
}
