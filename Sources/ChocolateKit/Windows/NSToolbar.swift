/// Provides AppKit-compatible toolbar item customization hooks.
public protocol NSToolbarDelegate: NSObjectProtocol {
    /// Returns the identifiers allowed in the toolbar customization palette.
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]

    /// Returns the default toolbar identifiers.
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]

    /// Returns an item for an identifier that may be inserted into the toolbar.
    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem?

    /// Returns the identifiers of items that show a selected state, matching
    /// AppKit's `toolbarSelectableItemIdentifiers(_:)`.
    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier]

    /// Called just before an item is added to the toolbar; the item rides
    /// `notification.userInfo?["item"]`, matching AppKit.
    func toolbarWillAddItem(_ notification: Notification)

    /// Called after an item is removed from the toolbar; the item rides
    /// `notification.userInfo?["item"]`, matching AppKit.
    func toolbarDidRemoveItem(_ notification: Notification)
}

/// Adds public behavior to `NSToolbarDelegate`.
public extension NSToolbarDelegate {
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbar.items.map(\.itemIdentifier)
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbar.items.map(\.itemIdentifier)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        toolbar.item(withIdentifier: itemIdentifier)
    }

    /// Default: no items are selectable.
    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        []
    }

    /// Default no-op will-add hook.
    func toolbarWillAddItem(_ notification: Notification) {}

    /// Default no-op did-remove hook.
    func toolbarDidRemoveItem(_ notification: Notification) {}
}

/// A toolbar attached to an `NSWindow`.
///
/// This first slice models AppKit's toolbar/item relationship and lets demos or
/// compatibility code render toolbar items through a native Windows toolbar.
/// Future passes will add overflow, images, and a customization sheet matching
/// the classic AppKit toolbar experience.
open class NSToolbar: NSObject {
    /// Display style for toolbar item labels and images.
    public enum DisplayMode: Sendable {
        case `default`
        case iconAndLabel
        case iconOnly
        case labelOnly
    }

    /// Toolbar item sizing mode.
    public enum SizeMode: Sendable {
        case `default`
        case regular
        case small
    }

    /// Posted (via `NotificationCenter.default`) just before an item joins a
    /// toolbar, matching AppKit's `NSToolbar.willAddItemNotification`.
    public static let willAddItemNotification = Notification.Name("NSToolbarWillAddItemNotification")

    /// Posted after an item leaves a toolbar, matching AppKit's
    /// `NSToolbar.didRemoveItemNotification`.
    public static let didRemoveItemNotification = Notification.Name("NSToolbarDidRemoveItemNotification")

    /// Unique toolbar identifier.
    public let identifier: String

    /// The toolbar's visible items.
    public internal(set) var items: [NSToolbarItem] = []

    /// The items currently visible in the strip, matching AppKit's
    /// `visibleItems`: items pushed into the overflow menu by a narrow window
    /// are excluded.
    open var visibleItems: [NSToolbarItem]? {
        items.filter { !winOverflowedItemIdentifiers.contains(ObjectIdentifier($0)) }
    }

    /// Identifiers whose items show a selected (highlighted) state when they
    /// match `selectedItemIdentifier`, matching AppKit. Setting an identifier
    /// outside the delegate's selectable set clears the selection.
    open var selectedItemIdentifier: NSToolbarItem.Identifier? {
        didSet {
            if let selected = selectedItemIdentifier,
               let delegate,
               !delegate.toolbarSelectableItemIdentifiers(self).contains(selected) {
                selectedItemIdentifier = nil
            }
            guard oldValue != selectedItemIdentifier else {
                return
            }
            itemsDidChange?()
        }
    }

    /// Identifiers the layout keeps centered (macOS 13 shape). Stored for
    /// source compatibility; the modern presentation will honor it visually.
    open var centeredItemIdentifiers: Set<NSToolbarItem.Identifier> = []

    /// Items currently collapsed into the overflow menu (by object identity),
    /// maintained by the renderer when the strip is too narrow.
    internal var winOverflowedItemIdentifiers: Set<ObjectIdentifier> = []

    /// Whether users can customize this toolbar.
    open var allowsUserCustomization: Bool = false

    /// Object that supplies AppKit-style customization identifiers and items.
    open weak var delegate: NSToolbarDelegate?

    /// Whether toolbar customization changes are autosaved.
    open var autosavesConfiguration: Bool = false

    /// Whether the toolbar is visible.
    open var isVisible: Bool = true {
        didSet {
            visibilityDidChange?(isVisible)
            autosaveConfigurationIfNeeded()
        }
    }

    /// Preferred toolbar display mode.
    open var displayMode: DisplayMode = .default {
        didSet {
            itemsDidChange?()
            autosaveConfigurationIfNeeded()
        }
    }

    /// Preferred toolbar size mode.
    open var sizeMode: SizeMode = .default {
        didSet {
            itemsDidChange?()
        }
    }

    /// WinChocolate-specific separator rendering override.
    ///
    /// Apple has varied separator appearance across macOS releases, so prefer
    /// `.automatic`, which follows the active presentation: the classic Win32
    /// look renders a vertical bar and the future modern look will render a
    /// blank gap. Overriding this in application code is discouraged.
    open var winSeparatorStyle: WinToolbarSeparatorStyle = .automatic {
        didSet {
            itemsDidChange?()
        }
    }

    /// Which Apple toolbar look the strip renders — toolbars are the project's
    /// deliberate exception to the "look like Windows" rule, and this selects
    /// among the Apple looks: `.automatic` (follow the app-wide presentation,
    /// the default), `.unified` (the flat modern look), or `.metallic` (the
    /// classic brushed-gradient chrome).
    open var winAppleLook: WinToolbarAppleLook = .automatic {
        didSet {
            itemsDidChange?()
        }
    }

    /// The concrete look the renderer draws, resolving `.automatic` against the
    /// app-wide presentation (Phase 8): classic → metallic, modern → unified.
    /// This is the coordination point between the toolbar's Apple looks and the
    /// `WinPresentation` switch the rest of the app already follows.
    public var winResolvedAppleLook: WinToolbarAppleLook {
        switch winAppleLook {
        case .automatic:
            return WinPresentation.selected == .classic ? .metallic : .unified
        case .unified:
            return .unified
        case .metallic:
            return .metallic
        }
    }

    /// The window this toolbar is attached to.
    public internal(set) weak var window: NSWindow?

    /// Called when `isVisible` changes.
    public var visibilityDidChange: ((Bool) -> Void)?

    /// Called when the toolbar item list changes.
    public var itemsDidChange: (() -> Void)?

    internal var itemStore: [NSToolbarItem.Identifier: NSToolbarItem] = [:]
    internal var customizationPanel: NSPanel?
    /// Guards `validateVisibleItems` against reentry (an item's `isEnabled`
    /// change re-requests validation).
    internal var isValidatingItems = false

    /// Creates a toolbar with an AppKit-style identifier.
    public init(identifier: String) {
        self.identifier = identifier
        super.init()
    }

    /// Creates a toolbar with a default identifier (AppKit's `init()` shape).
    public convenience override init() {
        self.init(identifier: "NSToolbar")
    }

    /// Adds an item at the end of the toolbar. Not API: AppKit populates
    /// toolbars only through the delegate + `insertItem(withItemIdentifier:at:)`
    /// (18.6); this remains for framework internals (palette, tests).
    package func addItem(_ item: NSToolbarItem) {
        insertItem(item, at: items.count)
    }

    /// Inserts an item at the requested index.
    package func insertItem(_ item: NSToolbarItem, at index: Int) {
        item.toolbar = nil
        notifyWillAdd(item)
        let insertionIndex = min(max(index, 0), items.count)
        items.insert(item, at: insertionIndex)
        itemStore[item.itemIdentifier] = item
        item.toolbar = self
        itemsDidChange?()
        autosaveConfigurationIfNeeded()
    }

    /// Removes and returns the item at the given index.
    @discardableResult
    open func removeItem(at index: Int) -> NSToolbarItem? {
        guard items.indices.contains(index) else {
            return nil
        }

        let item = items.remove(at: index)
        item.toolbar = nil
        notifyDidRemove(item)
        itemsDidChange?()
        autosaveConfigurationIfNeeded()
        return item
    }

    /// Fires the AppKit will-add hooks: the delegate callback and the
    /// `willAddItemNotification` posting, with the item under `"item"`.
    internal func notifyWillAdd(_ item: NSToolbarItem) {
        delegate?.toolbarWillAddItem(Notification(name: Notification.Name(Self.willAddItemNotification.rawValue), object: self, userInfo: ["item": item]))
        NotificationCenter.default.post(name: Self.willAddItemNotification, object: self, userInfo: ["item": item])
    }

    /// Fires the AppKit did-remove hooks (delegate + notification).
    internal func notifyDidRemove(_ item: NSToolbarItem) {
        delegate?.toolbarDidRemoveItem(Notification(name: Notification.Name(Self.didRemoveItemNotification.rawValue), object: self, userInfo: ["item": item]))
        NotificationCenter.default.post(name: Self.didRemoveItemNotification, object: self, userInfo: ["item": item])
    }

    /// Returns the first item with the given identifier.
    open func item(withIdentifier identifier: NSToolbarItem.Identifier) -> NSToolbarItem? {
        items.first { $0.itemIdentifier == identifier } ?? itemStore[identifier]
    }

    /// Sends `validate()` to every autovalidating visible item (matching
    /// AppKit), then asks visible toolbar renderers to refresh their state.
    open func validateVisibleItems() {
        guard !isValidatingItems else {
            return
        }
        isValidatingItems = true
        for item in items where item.autovalidates {
            item.validate()
        }
        isValidatingItems = false
        itemsDidChange?()
    }

    /// Replaces visible toolbar items with the supplied identifiers.
    open func setVisibleItemIdentifiers(_ identifiers: [NSToolbarItem.Identifier]) {
        var replacementItems: [NSToolbarItem] = []
        replacementItems.reserveCapacity(identifiers.count)
        for identifier in identifiers {
            guard var item = itemForVisibleIdentifier(identifier, willBeInsertedIntoToolbar: true) else {
                continue
            }
            // A delegate may legitimately return one cached NSToolbarItem for
            // every request of a structural identifier (the demo reuses a single
            // separator instance). When two such identifiers arrive in the same
            // pass, itemForVisibleIdentifier only guards against reusing items
            // already in `self.items` — not ones we've just consumed here — so it
            // hands back the same instance twice. Aliasing one item into two slots
            // corrupts the index/identity operations the customization panel and
            // renderer rely on, so mint a fresh instance instead.
            if replacementItems.contains(where: { $0 === item }) {
                item = NSToolbarItem(itemIdentifier: identifier)
            }
            replacementItems.append(item)
        }

        for item in items {
            item.toolbar = nil
        }

        items = replacementItems
        for item in items {
            item.toolbar = self
        }
        itemsDidChange?()
        autosaveConfigurationIfNeeded()
    }

    /// Inserts an item by identifier, matching AppKit's customization pathway.
    open func insertItem(withItemIdentifier itemIdentifier: NSToolbarItem.Identifier, at index: Int) {
        guard let item = itemForVisibleIdentifier(itemIdentifier, willBeInsertedIntoToolbar: true) else {
            return
        }

        insertItem(item, at: index)
    }

    /// Restores the delegate-provided default visible toolbar items.
    open func resetVisibleItemsToDefault() {
        let identifiers = delegate?.toolbarDefaultItemIdentifiers(self) ?? itemStore.keys.map { $0 }
        setVisibleItemIdentifiers(identifiers)
    }

    /// Whether the customization palette is open, matching AppKit's
    /// `customizationPaletteIsRunning`.
    open var customizationPaletteIsRunning: Bool {
        customizationPanel?.isVisible ?? false
    }

    /// Opens the Apple-style toolbar customization palette.
    open func runCustomizationPalette(_ sender: Any?) {
        guard allowsUserCustomization else {
            return
        }

        let panel = NSToolbarCustomizationPanel(toolbar: self)
        customizationPanel = panel
        panel.makeKeyAndOrderFront(sender)
    }

    /// Allowed customization identifiers from the delegate or the item store.
    internal var customizationAllowedIdentifiers: [NSToolbarItem.Identifier] {
        delegate?.toolbarAllowedItemIdentifiers(self) ?? itemStore.keys.map { $0 }
    }

    /// Default customization identifiers from the delegate or the item store.
    internal var customizationDefaultIdentifiers: [NSToolbarItem.Identifier] {
        delegate?.toolbarDefaultItemIdentifiers(self) ?? itemStore.keys.map { $0 }
    }

    internal func itemForCustomizationIdentifier(
        _ identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        if let existing = itemStore[identifier] {
            return existing
        }

        if let item = delegate?.toolbar(self, itemForItemIdentifier: identifier, willBeInsertedIntoToolbar: flag) {
            itemStore[identifier] = item
            return item
        }

        // Standard Apple identifiers synthesize their built-in items when the
        // app supplies none, matching how AppKit vends them without delegate help.
        if let standard = winStandardItem(for: identifier) {
            itemStore[identifier] = standard
            return standard
        }

        return nil
    }

    /// Builds the built-in item for a standard Apple identifier, wired to the
    /// Mac behavior: colors/fonts open the shared panels, customize runs the
    /// palette, print runs a print operation on the key window's content.
    internal func winStandardItem(for identifier: NSToolbarItem.Identifier) -> NSToolbarItem? {
        let item: NSToolbarItem
        switch identifier {
        case .showColors:
            item = NSToolbarItem(itemIdentifier: identifier)
            item.label = "Colors"
            item.winInternalAction = { toolbarItem in
                NSColorPanel.shared.makeKeyAndOrderFront(toolbarItem)
            }
        case .showFonts:
            item = NSToolbarItem(itemIdentifier: identifier)
            item.label = "Fonts"
            item.winInternalAction = { toolbarItem in
                NSFontPanel.shared.makeKeyAndOrderFront(toolbarItem)
            }
        case .customizeToolbar:
            item = NSToolbarItem(itemIdentifier: identifier)
            item.label = "Customize"
            item.winInternalAction = { [weak self] toolbarItem in
                self?.runCustomizationPalette(toolbarItem)
            }
        case .toggleSidebar:
            // The identifier and label exist for source/palette parity; the
            // classic backend has no responder-chain `toggleSidebar:`, so the
            // app wires the action to its own split view.
            item = NSToolbarItem(itemIdentifier: identifier)
            item.label = "Sidebar"
        case .toggleInspector:
            // Same boundary as toggleSidebar: the app wires the action.
            item = NSToolbarItem(itemIdentifier: identifier)
            item.label = "Inspector"
        case .cloudSharing:
            // Windows has no macOS sharing service; the app wires its own UI.
            item = NSToolbarItem(itemIdentifier: identifier)
            item.label = "Share"
        case .sidebarTrackingSeparator, .inspectorTrackingSeparator:
            item = NSToolbarItem(itemIdentifier: identifier)
            item.label = ""
        case .print:
            item = NSToolbarItem(itemIdentifier: identifier)
            item.label = "Print"
            item.winInternalAction = { [weak self] _ in
                // AppKit sends printDocument: up the responder chain; the
                // closest classic-backend behavior prints the toolbar window's
                // content view. Apps override by assigning their own action.
                guard let window = self?.window ?? NSApplication.shared.keyWindow,
                      let contentView = window.contentView else {
                    return
                }
                _ = NSPrintOperation.printOperation(with: contentView).run()
            }
        default:
            return nil
        }
        item.paletteLabel = item.label
        return item
    }

    internal func itemForVisibleIdentifier(
        _ identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard identifier.allowsMultipleToolbarInstances else {
            return itemForCustomizationIdentifier(identifier, willBeInsertedIntoToolbar: flag)
        }

        if let item = delegate?.toolbar(self, itemForItemIdentifier: identifier, willBeInsertedIntoToolbar: flag),
           item.itemIdentifier == identifier,
           item.toolbar == nil,
           !items.contains(where: { $0 === item }) {
            return item
        }

        return NSToolbarItem(itemIdentifier: identifier)
    }

    internal func attach(to window: NSWindow?) {
        self.window = window
        if window != nil {
            // AppKit's population flow: a toolbar with no items yet fills
            // itself from the delegate's default identifiers when it attaches
            // (each resolved through `toolbar(_:itemForItemIdentifier:...)`).
            if items.isEmpty, delegate != nil {
                resetVisibleItemsToDefault()
            }
            restoreAutosavedConfigurationIfNeeded()
        }
    }

    // MARK: - Configuration autosave (AppKit's persistence contract)

    /// The defaults key AppKit uses for a toolbar's saved configuration.
    internal var winAutosaveDefaultsKey: String {
        "NSToolbar Configuration \(identifier)"
    }

    /// A property-list snapshot of the user-visible configuration, matching
    /// AppKit's `configurationDictionary` keys.
    open var configurationDictionary: [String: Any] {
        let displayModeValue: Int
        switch displayMode {
        case .default: displayModeValue = 0
        case .iconAndLabel: displayModeValue = 1
        case .iconOnly: displayModeValue = 2
        case .labelOnly: displayModeValue = 3
        }
        return [
            "TB Display Mode": displayModeValue,
            "TB Is Shown": isVisible ? 1 : 0,
            "TB Item Identifiers": items.map(\.itemIdentifier.rawValue),
        ]
    }

    /// Applies a previously saved configuration snapshot, matching AppKit's
    /// `setConfiguration(_:)`.
    open func setConfiguration(_ configDict: [String: Any]) {
        if let identifiers = (configDict["TB Item Identifiers"] as? [Any])?.compactMap({ $0 as? String }) {
            setVisibleItemIdentifiers(identifiers.map { NSToolbarItem.Identifier(rawValue: $0) })
        }
        if let displayModeValue = configDict["TB Display Mode"] as? Int {
            switch displayModeValue {
            case 1: displayMode = .iconAndLabel
            case 2: displayMode = .iconOnly
            case 3: displayMode = .labelOnly
            default: displayMode = .default
            }
        }
        if let shown = configDict["TB Is Shown"] as? Int {
            isVisible = shown != 0
        }
    }

    /// Persists the configuration when `autosavesConfiguration` is on, using
    /// AppKit's `"NSToolbar Configuration <identifier>"` defaults key.
    internal func autosaveConfigurationIfNeeded() {
        guard autosavesConfiguration else {
            return
        }
        UserDefaults.standard.set(configurationDictionary, forKey: winAutosaveDefaultsKey)
    }

    /// Restores a previously autosaved configuration, if one exists.
    internal func restoreAutosavedConfigurationIfNeeded() {
        guard autosavesConfiguration,
              let saved = UserDefaults.standard.dictionary(forKey: winAutosaveDefaultsKey) else {
            return
        }
        setConfiguration(saved)
    }
}
