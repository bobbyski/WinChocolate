import Foundation

/// AppKit-shaped toolbar item: an identifier, a label, and an action.
public final class NSToolbarItem: NSObject {

    /// AppKit's target/action pair; clicking the item performs `action` on
    /// `target` (alongside the closure hook).
    public weak var target: AnyObject?
    public var action: Selector?

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

    /// Size constraints + tooltip + enabled state (accepted for API parity).
    public var minSize: NSSize = .zero
    public var maxSize: NSSize = .zero
    public var toolTip: String?
    public var isEnabled: Bool = true
    /// A custom view for the item (accepted; the composed strip uses buttons).
    public var view: NSView?

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

    /// Display mode + config autosave (accepted for API parity).
    public enum DisplayMode: Sendable { case `default`, iconAndLabel, iconOnly, labelOnly }
    public var displayMode: DisplayMode = .default {
        didSet { window?.reinstallToolbar() }
    }

    /// The backend rendering mode for the current `displayMode`.
    var nativeDisplayMode: NativeToolbarDisplayMode {
        switch displayMode {
        case .default, .iconAndLabel: return .iconAndLabel
        case .iconOnly: return .iconOnly
        case .labelOnly: return .labelOnly
        }
    }
    public var autosavesConfiguration: Bool = false
    /// WinChocolate's Apple-look toggle (metallic/unified) — accepted no-op.
    public var winAppleLook: WinAppleLook = .unified
    public enum WinAppleLook: Sendable { case unified, metallic }

    /// The customization delegate. Assigning it loads the default items.
    public weak var delegate: NSToolbarDelegate? {
        didSet { loadDefaultItems() }
    }

    /// True while `items` holds the delegate's auto-loaded defaults (not yet
    /// overridden by an explicit `addItem`). The first explicit `addItem` clears
    /// them, so a demo that both sets a delegate *and* populates via `addItem`
    /// (as AppKit consumers do) ends up with one set, not two.
    private var itemsAreDelegateLoaded = false

    /// Whether the customization palette is currently open.
    public private(set) var customizationPaletteIsRunning = false

    /// The window this toolbar is installed on (set by `NSWindow.toolbar`).
    weak var window: NSWindow?

    public init(identifier: String) {
        self.identifier = identifier
    }

    /// Appends `item` and refreshes the installed toolbar.
    public func addItem(_ item: NSToolbarItem) {
        if itemsAreDelegateLoaded {
            items.removeAll()
            itemsAreDelegateLoaded = false
        }
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
        customizationPaletteIsRunning = true
        let handlers = NativeToolbarCustomizationHandlers(
            onInsert: { [weak self] identifier, index in
                guard let self, let item = self.makeItem(identifier) else { return }
                self.items.insert(item, at: min(max(index, 0), self.items.count))
                self.window?.reinstallToolbar()
                self.pushCustomizationSession()
            },
            onMove: { [weak self] from, to in
                guard let self, self.items.indices.contains(from) else { return }
                let item = self.items.remove(at: from)
                let target = from < to ? to - 1 : to
                self.items.insert(item, at: min(max(target, 0), self.items.count))
                self.window?.reinstallToolbar()
                self.pushCustomizationSession()
            },
            onRemove: { [weak self] index in
                guard let self, self.items.indices.contains(index) else { return }
                self.items.remove(at: index)
                self.window?.reinstallToolbar()
                self.pushCustomizationSession()
            },
            onResetToDefault: { [weak self] in
                guard let self, let delegate = self.delegate else { return }
                self.items = delegate.toolbarDefaultItemIdentifiers(self).compactMap { self.makeItem($0) }
                self.window?.reinstallToolbar()
                self.pushCustomizationSession()
            },
            onDisplayMode: { [weak self] index in
                guard let self else { return }
                self.displayMode = [.iconAndLabel, .iconOnly, .labelOnly][min(max(index, 0), 2)]
                self.pushCustomizationSession()
            },
            onClose: { [weak self] in self?.customizationPaletteIsRunning = false }
        )
        window.backend.runToolbarCustomization(customizationSession(), handlers: handlers, for: window.handle)
    }

    /// The panel's current model: live strip, allowed palette (present items
    /// dimmed), the default set, and the display mode.
    private func customizationSession() -> NativeToolbarCustomizationSession {
        let present = Set(items.map { $0.itemIdentifier })
        let allowed = delegate?.toolbarAllowedItemIdentifiers(self) ?? []
        let palette = allowed.map { paletteEntry(for: $0, present: present) }
        let defaults = (delegate?.toolbarDefaultItemIdentifiers(self) ?? []).map {
            paletteEntry(for: $0, present: [])
        }
        let modeIndex: Int
        switch displayMode {
        case .default, .iconAndLabel: modeIndex = 0
        case .iconOnly: modeIndex = 1
        case .labelOnly: modeIndex = 2
        }
        return NativeToolbarCustomizationSession(strip: specs(), palette: palette,
                                                 defaultSet: defaults, displayModeIndex: modeIndex)
    }

    private func paletteEntry(for id: NSToolbarItem.Identifier, present: Set<String>) -> NativeToolbarPaletteItem {
        var label: String
        var resolvedItem: NSToolbarItem?
        if id == NSToolbarItem.flexibleSpaceIdentifier {
            label = "Flexible Space"
        } else {
            resolvedItem = makeItem(id)
            let resolved = resolvedItem.map { $0.paletteLabel.isEmpty ? $0.label : $0.paletteLabel } ?? id
            label = resolved.isEmpty ? NSToolbar.standardPaletteName(for: id) : resolved
        }
        var palette = NativeToolbarPaletteItem(identifier: id, label: label, isInToolbar: present.contains(id))
        palette.imagePath = resolvedItem?.image?.path
        palette.imageIsTemplate = resolvedItem?.image?.isTemplate ?? false
        palette.iconName = resolvedItem?.image?.iconName
        return palette
    }

    /// Refreshes the open panel after any edit.
    private func pushCustomizationSession() {
        guard customizationPaletteIsRunning, let window else { return }
        window.backend.updateToolbarCustomization(customizationSession())
    }

    /// Converts the items to backend specs.
    func specs() -> [NativeToolbarItemSpec] {
        items.map { item in
            NativeToolbarItemSpec(
                imagePath: item.image?.path,
                imageIsTemplate: item.image?.isTemplate ?? false,
                identifier: item.itemIdentifier,
                label: item.label,
                iconName: item.image?.iconName,
                isFlexibleSpace: item.itemIdentifier == NSToolbarItem.flexibleSpaceIdentifier,
                viewHandle: item.view?.handle,
                action: item.itemIdentifier == NSToolbarItem.flexibleSpaceIdentifier ? nil : { [weak item] in
                    guard let item else { return }
                    item.onAction?(item)
                    if let action = item.action, let target = item.target as? NSObject {
                        _ = target.perform(action, with: item)
                    }
                }
            )
        }
    }

    // MARK: Internals

    private func makeItem(_ identifier: NSToolbarItem.Identifier) -> NSToolbarItem? {
        if identifier == NSToolbarItem.flexibleSpaceIdentifier { return NSToolbarItem.flexibleSpace() }
        if let provided = delegate?.toolbar(self, itemForItemIdentifier: identifier, willBeInsertedIntoToolbar: true) {
            return provided
        }
        return NSToolbar.standardItem(for: identifier)
    }

    /// The palette name for a standard identifier a bare item was supplied
    /// for (Apple names these itself; raw identifiers never leak to the user).
    static func standardPaletteName(for identifier: NSToolbarItem.Identifier) -> String {
        switch identifier {
        case "NSToolbarSeparatorItem": return "Separator"
        case "NSToolbarSpaceItem": return "Space"
        case "NSToolbarFlexibleSpaceItem": return "Flexible Space"
        case "NSToolbarShowColorsItem": return "Colors"
        case "NSToolbarShowFontsItem": return "Fonts"
        case "NSToolbarPrintItem": return "Print"
        default: return identifier
        }
    }

    /// Synthesizes Apple's standard toolbar items when the delegate returns
    /// nil for their identifiers (AppKit's 6.6 behavior): friendly labels,
    /// theme icons, and the built-in behaviors.
    static func standardItem(for identifier: NSToolbarItem.Identifier) -> NSToolbarItem? {
        func item(_ label: String, icon: String, action: (() -> Void)? = nil) -> NSToolbarItem {
            let standard = NSToolbarItem(itemIdentifier: identifier)
            standard.label = label
            standard.paletteLabel = label
            standard.image = NSImage(named: icon)
            if let action {
                standard.onAction = { _ in action() }
            }
            return standard
        }

        switch identifier {
        case "NSToolbarSeparatorItem":
            let separator = NSToolbarItem(itemIdentifier: identifier)
            separator.label = ""
            separator.paletteLabel = "Separator"
            return separator
        case "NSToolbarSpaceItem":
            let space = NSToolbarItem(itemIdentifier: identifier)
            space.label = ""
            space.paletteLabel = "Space"
            return space
        case "NSToolbarShowColorsItem":
            return item("Colors", icon: "color-select-symbolic") {
                NSColorPanel.shared.makeKeyAndOrderFront(nil)
            }
        case "NSToolbarShowFontsItem":
            return item("Fonts", icon: "font-x-generic-symbolic") {
                NSFontManager.shared.orderFrontFontPanel(nil)
            }
        case "NSToolbarPrintItem":
            return item("Print", icon: "document-print-symbolic")
        default:
            return nil
        }
    }

    private func loadDefaultItems() {
        guard let delegate else { return }
        let ids = delegate.toolbarDefaultItemIdentifiers(self)
        guard !ids.isEmpty else { return }
        items = ids.compactMap { makeItem($0) }
        itemsAreDelegateLoaded = true
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
