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
    public private(set) var items: [NSToolbarItem] = []

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
    public private(set) weak var window: NSWindow?

    /// Called when `isVisible` changes.
    public var visibilityDidChange: ((Bool) -> Void)?

    /// Called when the toolbar item list changes.
    public var itemsDidChange: (() -> Void)?

    private var itemStore: [NSToolbarItem.Identifier: NSToolbarItem] = [:]
    private var customizationPanel: NSPanel?
    /// Guards `validateVisibleItems` against reentry (an item's `isEnabled`
    /// change re-requests validation).
    private var isValidatingItems = false

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
    private func notifyWillAdd(_ item: NSToolbarItem) {
        delegate?.toolbarWillAddItem(Notification(name: Notification.Name(Self.willAddItemNotification.rawValue), object: self, userInfo: ["item": item]))
        NotificationCenter.default.post(name: Self.willAddItemNotification, object: self, userInfo: ["item": item])
    }

    /// Fires the AppKit did-remove hooks (delegate + notification).
    private func notifyDidRemove(_ item: NSToolbarItem) {
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
    private func winStandardItem(for identifier: NSToolbarItem.Identifier) -> NSToolbarItem? {
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

    private func itemForVisibleIdentifier(
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

internal extension NSToolbarItem.Identifier {
    /// Whether the identifier may appear multiple times in one toolbar.
    var allowsMultipleToolbarInstances: Bool {
        switch self {
        case .separator, .space, .flexibleSpace:
            return true
        default:
            return false
        }
    }
}

/// A composed AppKit-style toolbar renderer.
///
/// AppKit's `NSToolbar` is normally window chrome, not a regular content view.
/// This view renders `NSToolbarItem` values as ordinary WinChocolate child
/// views so custom items, separators, and standard controls share one layout
/// model instead of overlaying native toolbar placeholders.
open class NSToolbarView: NSView {
    /// Toolbar model rendered by this view.
    open var toolbar: NSToolbar? {
        didSet {
            oldValue?.visibilityDidChange = nil
            oldValue?.itemsDidChange = nil
            toolbar?.visibilityDidChange = { [weak self] isVisible in
                self?.isHidden = !isVisible
                self?.visibilityChanged?(isVisible)
            }
            toolbar?.itemsDidChange = { [weak self] in
                self?.reloadItems()
            }
            isHidden = !(toolbar?.isVisible ?? true)
            reloadItems()
        }
    }

    /// Item height inside the strip.
    open var itemHeight: CGFloat = 34

    /// Preferred strip height for the current toolbar display settings.
    open var preferredHeight: CGFloat {
        Self.preferredHeight(for: toolbar)
    }

    /// Horizontal padding before the first item.
    open var leadingPadding: CGFloat = 8

    /// Spacing between normal items.
    open var itemSpacing: CGFloat = 4

    /// Called after the hosted toolbar visibility changes.
    public var visibilityChanged: ((Bool) -> Void)?

    /// Called when display settings imply a different natural toolbar height.
    public var preferredHeightChanged: ((CGFloat) -> Void)?

    private var renderedItemViews: [NSView] = []
    private var lastPreferredHeight: CGFloat?
    /// Rendered strip items with their frames, for right-click hit-testing
    /// (the Mac's per-item "Remove Item" context entry).
    private var renderedItemHits: [(item: NSToolbarItem, frame: NSRect)] = []
    /// Elastic factor (0...1) applied to custom-view items between their min
    /// and max sizes: a narrow strip shrinks them toward `minSize` before any
    /// item overflows, matching the Mac's shrink-then-overflow behavior.
    private var winCustomViewShrink: CGFloat = 1

    /// Token for the live appearance-change observer, removed on deinit.
    private var winAppearanceObserver: NSObjectProtocol?

    /// Creates a toolbar view.
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // Blend with the window chrome the way AppKit toolbars extend the
        // title bar; a bottom hairline separates the strip from content.
        winBackgroundColor = .windowBackgroundColor
        // The strip fill is resolved for the current appearance and cached as a
        // brush; re-resolve it on a live system theme switch so the toolbar
        // follows the window chrome instead of staying its old shade.
        winAppearanceObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.winEffectiveAppearanceDidChangeNotification,
            object: nil, queue: nil
        ) { [weak self] _ in
            self?.winBackgroundColor = .windowBackgroundColor
            self?.needsDisplay = true
        }
    }

    deinit {
        if let winAppearanceObserver {
            NotificationCenter.default.removeObserver(winAppearanceObserver)
        }
    }

    /// The separator style after resolving `.automatic` for this presentation.
    private var resolvedSeparatorStyle: WinToolbarSeparatorStyle {
        switch toolbar?.winSeparatorStyle ?? .automatic {
        case .bar:
            return .bar
        case .space:
            return .space
        case .automatic:
            // Classic Win32 renders a vertical bar; the modern presentation
            // renders a blank gap, matching current Apple toolbars.
            return WinPresentation.selected == .modern ? .space : .bar
        }
    }

    /// Toolbar strips do not take focus; their items do.
    open override var acceptsFirstResponder: Bool {
        false
    }

    /// The brushed-silver chrome gradient shared by the strip and the item
    /// tiles' slice rendering.
    internal static func winMetallicChromeGradient() -> NSGradient? {
        NSGradient(colorsAndLocations:
            (NSColor(calibratedRed: 0.91, green: 0.91, blue: 0.92, alpha: 1.0), 0.0),
            (NSColor(calibratedRed: 0.78, green: 0.78, blue: 0.80, alpha: 1.0), 0.55),
            (NSColor(calibratedRed: 0.70, green: 0.70, blue: 0.72, alpha: 1.0), 1.0)
        )
    }

    /// The gradient's midtone: the erase color behind transparent children in
    /// metallic, so item windows never flash white over the chrome.
    internal static let winMetallicMidtone = NSColor(calibratedRed: 0.80, green: 0.80, blue: 0.82, alpha: 1.0)

    /// Paints the strip chrome for the selected Apple look: `.metallic` draws
    /// the classic brushed silver gradient; `.unified` keeps the flat
    /// background fill.
    open override func draw(_ dirtyRect: NSRect) {
        guard toolbar?.winResolvedAppleLook == .metallic else {
            return
        }
        Self.winMetallicChromeGradient()?.draw(in: bounds, angle: -90)
    }

    /// Right-clicking the toolbar (empty space, or an item — item views don't
    /// consume right-clicks, so they bubble here) pops the Mac toolbar context
    /// menu: the display-mode switches with the current mode checked, and
    /// "Customize Toolbar…" when customization is allowed.
    open override func rightMouseDown(with event: NSEvent) {
        guard let toolbar else {
            super.rightMouseDown(with: event)
            return
        }

        let point = convert(event.locationInWindow, from: nil)
        let hitItem = renderedItemHits.first { NSPointInRect(point, $0.frame) }?.item
        let menu = winToolbarContextMenu(for: toolbar, clickedItem: hitItem)
        _ = menu.popUp(positioning: nil, at: point, in: self)
    }

    /// Builds the Mac toolbar context menu for the current toolbar state; a
    /// right-click that lands on an item prepends "Remove Item" when
    /// customization is allowed, matching the Mac.
    internal func winToolbarContextMenu(for toolbar: NSToolbar, clickedItem: NSToolbarItem? = nil) -> NSMenu {
        let menu = NSMenu(title: "")

        if let clickedItem, toolbar.allowsUserCustomization {
            let remove = NSMenuItem(title: "Remove Item", action: nil, keyEquivalent: "")
            remove.winInternalAction = { [weak toolbar, weak clickedItem] _ in
                guard let toolbar, let clickedItem,
                      let index = toolbar.items.firstIndex(where: { $0 === clickedItem }) else {
                    return
                }
                _ = toolbar.removeItem(at: index)
            }
            menu.addItem(remove)
            menu.addItem(NSMenuItem.separator())
        }
        let currentMode: NSToolbar.DisplayMode = toolbar.displayMode == .default ? .iconAndLabel : toolbar.displayMode

        func addModeItem(_ title: String, _ mode: NSToolbar.DisplayMode) {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.state = currentMode == mode ? .on : .off
            item.winInternalAction = { [weak toolbar] _ in
                toolbar?.displayMode = mode
            }
            menu.addItem(item)
        }
        addModeItem("Icon and Text", .iconAndLabel)
        addModeItem("Icon Only", .iconOnly)
        addModeItem("Text Only", .labelOnly)

        if toolbar.allowsUserCustomization {
            menu.addItem(NSMenuItem.separator())
            let customize = NSMenuItem(title: "Customize Toolbar…", action: nil, keyEquivalent: "")
            customize.winInternalAction = { [weak toolbar] _ in
                toolbar?.runCustomizationPalette(nil)
            }
            menu.addItem(customize)
        }
        return menu
    }

    /// Rebuilds composed toolbar child views from the toolbar model.
    open func reloadItems() {
        guard let toolbar else {
            return
        }

        // The strip's own background is what transparent child windows erase
        // with: in metallic it must be the chrome midtone, never white.
        winBackgroundColor = toolbar.winResolvedAppleLook == .metallic
            ? Self.winMetallicMidtone
            : .windowBackgroundColor
        notifyPreferredHeightIfNeeded()
        rebuildItemViews(for: toolbar)
    }

    /// Returns the natural toolbar strip height for AppKit-style display settings.
    public static func preferredHeight(for toolbar: NSToolbar?) -> CGFloat {
        guard let toolbar else {
            return 40
        }

        let displayMode: NSToolbar.DisplayMode
        switch toolbar.displayMode {
        case .default:
            displayMode = .iconAndLabel
        case .iconAndLabel, .iconOnly, .labelOnly:
            displayMode = toolbar.displayMode
        }
        let hasCustomView = toolbar.items.contains { $0.view != nil }
        let customHeight = toolbar.items.reduce(CGFloat(0)) { height, item in
            guard item.view != nil else {
                return height
            }

            return max(height, min(max(item.minSize.height, item.maxSize.height), item.maxSize.height))
        }

        let baseHeight: CGFloat
        switch displayMode {
        case .default, .iconAndLabel:
            switch toolbar.sizeMode {
            case .small:
                baseHeight = 34
            case .default, .regular:
                baseHeight = 40
            }
        case .iconOnly:
            switch toolbar.sizeMode {
            case .small:
                baseHeight = 26
            case .default, .regular:
                baseHeight = 30
            }
        case .labelOnly:
            switch toolbar.sizeMode {
            case .small:
                baseHeight = 24
            case .default, .regular:
                baseHeight = 26
            }
        }

        guard hasCustomView else {
            return baseHeight
        }

        return max(baseHeight, customHeight + 8)
    }

    /// Creates the native host peer for the composed toolbar.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createView(frame: frame, parent: parent)
    }

    /// Ensures the toolbar host has a native peer and realizes composed children.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        if let toolbar {
            rebuildItemViews(for: toolbar)
        }
        return handle
    }

    private func rebuildItemViews(for toolbar: NSToolbar) {
        for renderedView in renderedItemViews {
            renderedView.removeFromSuperview()
        }
        renderedItemViews.removeAll()

        let layout = itemLayout(for: toolbar)
        for entry in layout {
            switch entry.kind {
            case .standard(let item):
                // Item groups render their subitems side by side (the Mac's
                // segmented-group look), each tile activating through the group.
                if let group = item as? NSToolbarItemGroup, !group.subitems.isEmpty {
                    let subitemWidth = entry.frame.size.width / CGFloat(group.subitems.count)
                    for (index, subitem) in group.subitems.enumerated() {
                        let tile = subitem.winCompositeView(
                            showItem: toolbar.displayMode != .labelOnly,
                            showLabel: toolbar.displayMode != .iconOnly,
                            toolbarHeight: frame.size.height
                        )
                        tile.frame = NSMakeRect(
                            entry.frame.origin.x + CGFloat(index) * subitemWidth,
                            entry.frame.origin.y,
                            subitemWidth,
                            entry.frame.size.height
                        )
                        // Selected subitems show the selection band.
                        if group.isSelected(at: index) {
                            tile.winBackgroundColor = NSColor(calibratedRed: 0.80, green: 0.84, blue: 0.90, alpha: 1.0)
                        }
                        if toolbar.winResolvedAppleLook == .metallic, let composite = tile as? NSToolbarCompositeItemView {
                            composite.metallicSlice = (stripHeight: frame.size.height, y: entry.frame.origin.y)
                        }
                        addRenderedSubview(tile)
                    }
                    continue
                }
                // Bordered items (macOS 10.15 shape) render as real buttons,
                // matching the Mac's button-style toolbar items.
                if item.isBordered {
                    let title = item.title.isEmpty ? item.label : item.title
                    let button = NSButton(title: title, frame: entry.frame)
                    button.isEnabled = item.isEnabled
                    button.toolTip = item.toolTip
                    button.winInternalAction = { [weak item] _ in
                        item?.performAction()
                    }
                    addSubview(button)
                    renderedItemViews.append(button)
                    continue
                }
                let compositeView = item.winCompositeView(
                    showItem: toolbar.displayMode != .labelOnly,
                    showLabel: toolbar.displayMode != .iconOnly,
                    toolbarHeight: frame.size.height
                )
                compositeView.frame = entry.frame
                // A selected item (selectedItemIdentifier) shows a subtle
                // pressed/selected band, matching the Mac toolbar look.
                if toolbar.selectedItemIdentifier == item.itemIdentifier {
                    compositeView.winBackgroundColor = NSColor(calibratedRed: 0.80, green: 0.84, blue: 0.90, alpha: 1.0)
                }
                // Metallic: the tile paints its slice of the chrome gradient
                // so the child window never breaks the strip's chrome.
                if toolbar.winResolvedAppleLook == .metallic, let composite = compositeView as? NSToolbarCompositeItemView {
                    composite.metallicSlice = (stripHeight: frame.size.height, y: entry.frame.origin.y)
                }
                addRenderedSubview(compositeView)
            case .custom(let item, let view):
                applyToolbarControlAppearance(to: view)
                view.frame = entry.frame
                view.toolTip = item.toolTip ?? view.toolTip
                if let control = view as? NSControl {
                    control.isEnabled = item.isEnabled
                }
                addRenderedSubview(view)
                applyRealizedToolbarControlAppearance(to: view)
            case .separator:
                let separatorItem = NSToolbarItem(itemIdentifier: .separator)
                let separatorView = separatorItem.winCompositeView(
                    showItem: true,
                    showLabel: false,
                    toolbarHeight: frame.size.height
                )
                separatorView.frame = entry.frame
                addRenderedSubview(separatorView)
            case .space:
                // Gaps host no child window at all: the strip surface (flat
                // background or gradient chrome) shows through directly in
                // every look — a child view would erase a flat patch over the
                // metallic gradient.
                break
            }
        }

        // Overflow chevron (»): pops a menu of the items the narrow strip
        // pushed out, matching the Mac toolbar's overflow behavior.
        let structuralIdentifiers: Set<NSToolbarItem.Identifier> = [
            .space, .flexibleSpace, .separator, .sidebarTrackingSeparator, .inspectorTrackingSeparator,
        ]
        let menuWorthy = overflowedItems(for: toolbar).filter { item in
            !structuralIdentifiers.contains(item.itemIdentifier)
        }
        if !menuWorthy.isEmpty {
            let chevron = NSToolbarOverflowChevronView(
                frame: NSMakeRect(max(frame.size.width - 26, 0), 0, 24, frame.size.height)
            )
            if toolbar.winResolvedAppleLook == .metallic {
                chevron.metallicSlice = (stripHeight: frame.size.height, y: 0)
            }
            chevron.onOpenMenu = { [weak self, weak toolbar] chevronView in
                guard let toolbar else {
                    return
                }
                let menu = NSMenu(title: "")
                for item in self?.overflowedItems(for: toolbar) ?? [] where !structuralIdentifiers.contains(item.itemIdentifier) {
                    let title = item.menuFormRepresentation?.title ?? item.label
                    let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                    menuItem.isEnabled = item.isEnabled
                    menuItem.winInternalAction = { [weak item] _ in
                        item?.performAction()
                    }
                    menu.addItem(menuItem)
                }
                _ = menu.popUp(positioning: nil, at: NSMakePoint(0, chevronView.frame.size.height), in: chevronView)
            }
            addRenderedSubview(chevron)
        }

        // Chrome hairline separating the toolbar strip from window content.
        // Added after the item views so item indices stay stable for callers.
        let bottomEdge = NSView(frame: NSMakeRect(0, max(frame.size.height - 1, 0), frame.size.width, 1))
        bottomEdge.winBackgroundColor = NSColor(calibratedRed: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
        bottomEdge.autoresizingMask = [.width]
        addSubview(bottomEdge)
        renderedItemViews.append(bottomEdge)
    }

    private func addRenderedSubview(_ view: NSView) {
        addSubview(view)
        // Separator bars, editable fields, and views carrying their own fill
        // (e.g. the selected-item highlight band) draw their own backgrounds.
        let keepsOwnBackground = view is NSToolbarSeparatorView
            || ((view as? NSTextField)?.isEditable ?? false)
            || view.winBackgroundColor != nil
        if !keepsOwnBackground {
            applyRealizedTransparentBackground(to: view)
        }
        renderedItemViews.append(view)
    }

    private func applyToolbarControlAppearance(to view: NSView) {
        view.winBackgroundColor = nil

        // Label-style text fields blend into the toolbar strip; editable
        // fields (search fields, text entries) keep their border and
        // background the way AppKit toolbar search fields do.
        if let textField = view as? NSTextField, !textField.isEditable {
            textField.isBordered = false
            textField.drawsBackground = false
        }
    }

    private func applyRealizedToolbarControlAppearance(to view: NSView) {
        guard let nativeHandle = view.nativeHandle, let backend = view.realizedBackend else {
            return
        }

        if let textField = view as? NSTextField, textField.isEditable {
            return
        }

        if view is NSTextField || view is NSPopUpButton {
            backend.setBackgroundColor(nil, for: nativeHandle)
            backend.setDrawsBackground(false, for: nativeHandle)
        }
    }

    private func applyRealizedTransparentBackground(to view: NSView) {
        guard let nativeHandle = view.nativeHandle, let backend = view.realizedBackend else {
            return
        }

        backend.setBackgroundColor(nil, for: nativeHandle)
        backend.setDrawsBackground(false, for: nativeHandle)
    }

    private enum RenderedItemKind {
        case standard(NSToolbarItem)
        case custom(NSToolbarItem, NSView)
        case separator
        case space
    }

    private struct RenderedItemLayout {
        var kind: RenderedItemKind
        var frame: NSRect
    }

    /// The strip items after priority-based overflow: when the natural widths
    /// exceed the strip, the lowest-`visibilityPriority` items (ties resolved
    /// from the trailing edge) collapse into the overflow menu, matching the
    /// Mac toolbar's narrow-window behavior.
    private func stripItems(for toolbar: NSToolbar) -> [NSToolbarItem] {
        var visible = toolbar.items
        toolbar.winOverflowedItemIdentifiers.removeAll()
        guard frame.size.width > 0 else {
            return visible
        }

        func naturalWidth(of items: [NSToolbarItem]) -> CGFloat {
            let flexibleMinimum: CGFloat = 24
            let content = items.reduce(CGFloat(0)) { width, item in
                width + (item.itemIdentifier == .flexibleSpace ? flexibleMinimum : displayWidth(for: item, in: toolbar))
            }
            return content + leadingPadding * 2 + max(CGFloat(items.count - 1), 0) * itemSpacing
        }

        winCustomViewShrink = 1
        guard naturalWidth(of: visible) > frame.size.width else {
            return visible
        }

        // Before anything overflows, shrink elastic custom-view items toward
        // their minimum sizes (the Mac's shrink-then-overflow behavior).
        let shrinkSlack = visible.reduce(CGFloat(0)) { slack, item in
            guard item.view != nil else {
                return slack
            }
            return slack + max(0, item.maxSize.width - item.minSize.width)
        }
        if shrinkSlack > 0 {
            let needed = naturalWidth(of: visible) - frame.size.width
            if needed <= shrinkSlack {
                winCustomViewShrink = 1 - (needed / shrinkSlack)
                return visible
            }
            // Even fully shrunken it can't fit: keep the customs at minimum
            // and fall through to overflow.
            winCustomViewShrink = 0
        }

        // Something must overflow, so the chevron needs room too.
        let chevronReserve: CGFloat = 28
        let target = frame.size.width - chevronReserve
        while naturalWidth(of: visible) > target && visible.count > 1 {
            // Victim: lowest priority, trailing-most among equals. Spaces and
            // separators are dropped silently (no menu entry), like the Mac.
            guard let victimIndex = visible.indices.min(by: { a, b in
                let pa = visible[a].visibilityPriority.rawValue
                let pb = visible[b].visibilityPriority.rawValue
                return pa != pb ? pa < pb : a > b
            }) else {
                break
            }
            let victim = visible.remove(at: victimIndex)
            toolbar.winOverflowedItemIdentifiers.insert(ObjectIdentifier(victim))
        }
        return visible
    }

    /// The items currently collapsed into the overflow menu, in toolbar order.
    private func overflowedItems(for toolbar: NSToolbar) -> [NSToolbarItem] {
        toolbar.items.filter { toolbar.winOverflowedItemIdentifiers.contains(ObjectIdentifier($0)) }
    }

    private func itemLayout(for toolbar: NSToolbar) -> [RenderedItemLayout] {
        let layoutItems = stripItems(for: toolbar)
        let flexibleCount = layoutItems.filter { $0.itemIdentifier == .flexibleSpace }.count
        let fixedWidth = layoutItems.reduce(CGFloat(0)) { width, item in
            if item.itemIdentifier == .flexibleSpace {
                return width
            }
            return width + displayWidth(for: item, in: toolbar)
        }
        let fixedSpacing = max(CGFloat(layoutItems.count - 1), 0) * itemSpacing
        let availableFlexibleWidth = max(24, frame.size.width - (leadingPadding * 2) - fixedWidth - fixedSpacing)
        let flexibleWidth = flexibleCount > 0 ? max(24, availableFlexibleWidth / CGFloat(flexibleCount)) : 24
        var x = leadingPadding
        var layout: [RenderedItemLayout] = []

        for item in layoutItems {
            let width = item.itemIdentifier == .flexibleSpace ? flexibleWidth : displayWidth(for: item, in: toolbar)
            let height = displayHeight(for: item)
            let y = max((frame.size.height - height) / 2, 0)
            let itemFrame = NSMakeRect(x, y, width, height)

            if let view = item.view {
                layout.append(RenderedItemLayout(kind: .custom(item, view), frame: itemFrame))
            } else if item.itemIdentifier == .separator {
                if resolvedSeparatorStyle == .space {
                    layout.append(RenderedItemLayout(kind: .space, frame: itemFrame))
                } else {
                    layout.append(RenderedItemLayout(kind: .separator, frame: NSMakeRect(x + ((width - 2) / 2), 6, 2, max(frame.size.height - 12, 8))))
                }
            } else if item.itemIdentifier == .space || item.itemIdentifier == .flexibleSpace
                        || item.itemIdentifier == .sidebarTrackingSeparator
                        || item.itemIdentifier == .inspectorTrackingSeparator {
                layout.append(RenderedItemLayout(kind: .space, frame: itemFrame))
            } else {
                layout.append(RenderedItemLayout(kind: .standard(item), frame: itemFrame))
            }

            x += width + itemSpacing
        }

        applyCenteredItemLayout(&layout, items: layoutItems, in: toolbar)
        // Record hit frames after centering so right-click hit-testing sees
        // the final positions (one layout entry per strip item, index-aligned).
        renderedItemHits = zip(layoutItems, layout).map { (item: $0, frame: $1.frame) }
        return layout
    }

    /// Shifts the contiguous run of `centeredItemIdentifiers` items so its
    /// midpoint sits at the strip's midpoint (macOS 13 behavior), clamped so
    /// the run never overlaps its natural neighbors.
    private func applyCenteredItemLayout(
        _ layout: inout [RenderedItemLayout],
        items: [NSToolbarItem],
        in toolbar: NSToolbar
    ) {
        guard !toolbar.centeredItemIdentifiers.isEmpty, layout.count == items.count else {
            return
        }
        let centeredIndexes = items.indices.filter { toolbar.centeredItemIdentifiers.contains(items[$0].itemIdentifier) }
        guard let first = centeredIndexes.first, let last = centeredIndexes.last else {
            return
        }

        let runMinX = layout[first].frame.origin.x
        let runMaxX = layout[last].frame.maxX
        let runMid = (runMinX + runMaxX) / 2
        var dx = (frame.size.width / 2) - runMid

        // The prefix stays put (clamp left); the run itself stays on-strip
        // (clamp right). Items *after* the run re-flow to its right, matching
        // the Mac's centered-group flow.
        if first > 0 {
            let leftLimit = layout[first - 1].frame.maxX + itemSpacing
            dx = max(dx, leftLimit - runMinX)
        } else {
            dx = max(dx, leadingPadding - runMinX)
        }
        dx = min(dx, (frame.size.width - leadingPadding) - runMaxX)
        guard dx > 0 else {
            return
        }

        for index in first...last {
            layout[index].frame.origin.x += dx
        }

        // Re-flow the suffix after the shifted run.
        var cursor = layout[last].frame.maxX + itemSpacing
        for index in (last + 1)..<layout.count {
            if layout[index].frame.origin.x < cursor {
                layout[index].frame.origin.x = cursor
            }
            cursor = layout[index].frame.maxX + itemSpacing
        }
    }

    private func notifyPreferredHeightIfNeeded() {
        let height = preferredHeight
        guard lastPreferredHeight != height else {
            return
        }

        lastPreferredHeight = height
        preferredHeightChanged?(height)
    }

    private func displayWidth(for item: NSToolbarItem, in toolbar: NSToolbar) -> CGFloat {
        if item.itemIdentifier == .flexibleSpace {
            return 24
        }
        if item.itemIdentifier == .separator {
            // A bar keeps a little whitespace on either side; a space is a
            // wider blank gap, matching Apple's varied separator treatments.
            return resolvedSeparatorStyle == .space ? 24 : 16
        }
        if item.itemIdentifier == .space {
            return 8
        }
        if item.itemIdentifier == .sidebarTrackingSeparator || item.itemIdentifier == .inspectorTrackingSeparator {
            // Tracking separators render as modest gaps on the classic backend
            // (there is no split-view divider to track).
            return 12
        }
        if item.view != nil {
            // Custom-view items are elastic between min and max size; the
            // shrink factor compresses them before overflow kicks in.
            let minWidth = item.minSize.width
            let maxWidth = max(minWidth, item.maxSize.width)
            return minWidth + (maxWidth - minWidth) * winCustomViewShrink
        }

        let mode: NSToolbar.DisplayMode
        switch toolbar.displayMode {
        case .default:
            mode = .iconAndLabel
        case .iconAndLabel, .iconOnly, .labelOnly:
            mode = toolbar.displayMode
        }

        // Groups take the sum of their subitems' natural widths.
        if let group = item as? NSToolbarItemGroup, !group.subitems.isEmpty {
            let total = group.subitems.reduce(CGFloat(0)) { width, subitem in
                width + standardNaturalWidth(for: subitem, mode: mode)
            }
            return max(item.minSize.width, total)
        }

        // `minSize`/`maxSize` bound the item's CONTENT (the icon box) — the
        // label renders below and may be wider, as on Apple, where "Disable
        // Save" shows in full under a 32×32 item.
        let showsLabel = mode != .iconOnly
        let labelWidth = showsLabel ? CGFloat(max(28, item.label.count * 6)) + 8 : 0
        let naturalWidth = standardNaturalWidth(for: item, mode: mode)
        let contentWidth = max(item.minSize.width, min(item.maxSize.width, naturalWidth))
        return max(contentWidth, labelWidth)
    }

    /// The natural width of a standard (composite icon/label) item in a mode.
    private func standardNaturalWidth(for item: NSToolbarItem, mode: NSToolbar.DisplayMode) -> CGFloat {
        let showsLabel = mode != .iconOnly
        let showsImage = mode != .labelOnly
        let iconWidth: CGFloat = showsImage && item.image != nil ? 24 : 0
        let labelWidth = showsLabel ? CGFloat(max(28, item.label.count * 6)) : 0
        return max(iconWidth, labelWidth) + 16
    }

    private func displayHeight(for item: NSToolbarItem) -> CGFloat {
        if item.itemIdentifier == .separator {
            return max(frame.size.height - 16, 8)
        }
        if item.itemIdentifier == .space || item.itemIdentifier == .flexibleSpace {
            return max(frame.size.height - 8, 8)
        }
        // A native closed combo renders a fixed ~24pt control anchored to the
        // top of whatever frame it gets (the given height only sizes the
        // dropdown), so center popups/combos by their visible height — else
        // they sit visually high next to fields that fill their frames.
        if item.view is NSPopUpButton || item.view is NSComboBox {
            return 24
        }
        if item.view == nil {
            return max(frame.size.height - 6, 8)
        }
        return min(max(frame.size.height - 6, 20), max(20, item.maxSize.height))
    }

}

/// The overflow chevron (») shown when a narrow toolbar pushes items into a
/// menu, matching the Mac toolbar's overflow control.
final class NSToolbarOverflowChevronView: NSView {
    /// Opens the overflow menu; installed by the toolbar renderer.
    var onOpenMenu: ((NSToolbarOverflowChevronView) -> Void)?

    /// Metallic chrome slice (see `NSToolbarCompositeItemView.metallicSlice`).
    var metallicSlice: (stripHeight: CGFloat, y: CGFloat)?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        toolTip = "More toolbar items"
        winBackgroundColor = nil
    }

    override var acceptsFirstResponder: Bool {
        false
    }

    override func draw(_ dirtyRect: NSRect) {
        if let metallicSlice {
            NSToolbarView.winMetallicChromeGradient()?.draw(
                in: NSMakeRect(0, -metallicSlice.y, frame.size.width, metallicSlice.stripHeight),
                angle: -90
            )
        }
        let onDarkStrip = metallicSlice == nil && NSApplication.shared.effectiveAppearance.winIsDark
        let chevronColor = onDarkStrip
            ? NSColor(calibratedWhite: 0.85, alpha: 1)
            : NSColor(calibratedRed: 0.25, green: 0.27, blue: 0.30, alpha: 1.0)
        "»".draw(at: NSMakePoint(max((frame.size.width - 10) / 2, 0), max((frame.size.height - 18) / 2, 0)), withAttributes: [
            .font: NSFont.boldSystemFont(ofSize: 13),
            .foregroundColor: chevronColor,
        ])
    }

    override func mouseUp(with event: NSEvent) {
        onOpenMenu?(self)
    }
}

/// Separator line used by composed toolbar rendering.
open class NSToolbarSeparatorView: NSView {
    /// Creates a separator view.
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // The view itself is the thin vertical bar; layout centers it inside
        // a wider separator slot so whitespace frames it on either side.
        winBackgroundColor = NSColor(calibratedRed: 0.66, green: 0.66, blue: 0.66, alpha: 1.0)
    }

    /// Separators are display-only.
    open override var acceptsFirstResponder: Bool {
        false
    }

    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = backend.createView(frame: frame, parent: parent)
        backend.setText(" \nseparator", for: handle)
        backend.setDrawsBackground(false, for: handle)
        return handle
    }
}

