/// Provides AppKit-compatible toolbar item customization hooks.
public protocol NSToolbarDelegate: AnyObject {
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
    func toolbarWillAddItem(_ notification: NSNotification)

    /// Called after an item is removed from the toolbar; the item rides
    /// `notification.userInfo?["item"]`, matching AppKit.
    func toolbarDidRemoveItem(_ notification: NSNotification)
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
    func toolbarWillAddItem(_ notification: NSNotification) {}

    /// Default no-op did-remove hook.
    func toolbarDidRemoveItem(_ notification: NSNotification) {}
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

    /// Adds an item at the end of the toolbar.
    open func addItem(_ item: NSToolbarItem) {
        insertItem(item, at: items.count)
    }

    /// Inserts an item at the requested index.
    open func insertItem(_ item: NSToolbarItem, at index: Int) {
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
        delegate?.toolbarWillAddItem(NSNotification(name: Self.willAddItemNotification.rawValue, object: self, userInfo: ["item": item]))
        NotificationCenter.default.post(name: Self.willAddItemNotification, object: self, userInfo: ["item": item])
    }

    /// Fires the AppKit did-remove hooks (delegate + notification).
    private func notifyDidRemove(_ item: NSToolbarItem) {
        delegate?.toolbarDidRemoveItem(NSNotification(name: Self.didRemoveItemNotification.rawValue, object: self, userInfo: ["item": item]))
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
        let replacementItems = identifiers.compactMap { identifier -> NSToolbarItem? in
            itemForVisibleIdentifier(identifier, willBeInsertedIntoToolbar: true)
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
            item.onAction = { toolbarItem in
                NSColorPanel.shared.makeKeyAndOrderFront(toolbarItem)
            }
        case .showFonts:
            item = NSToolbarItem(itemIdentifier: identifier)
            item.label = "Fonts"
            item.onAction = { toolbarItem in
                NSFontPanel.shared.makeKeyAndOrderFront(toolbarItem)
            }
        case .customizeToolbar:
            item = NSToolbarItem(itemIdentifier: identifier)
            item.label = "Customize"
            item.onAction = { [weak self] toolbarItem in
                self?.runCustomizationPalette(toolbarItem)
            }
        case .print:
            item = NSToolbarItem(itemIdentifier: identifier)
            item.label = "Print"
            item.onAction = { [weak self] _ in
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

    /// Creates a toolbar view.
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // Blend with the window chrome the way AppKit toolbars extend the
        // title bar; a bottom hairline separates the strip from content.
        backgroundColor = .windowBackgroundColor
    }

    /// The separator style after resolving `.automatic` for this presentation.
    private var resolvedSeparatorStyle: WinToolbarSeparatorStyle {
        switch toolbar?.winSeparatorStyle ?? .automatic {
        case .bar:
            return .bar
        case .space:
            return .space
        case .automatic:
            // Classic Win32 presentation; the modern look will resolve to `.space`.
            return .bar
        }
    }

    /// Toolbar strips do not take focus; their items do.
    open override var acceptsFirstResponder: Bool {
        false
    }

    /// Rebuilds composed toolbar child views from the toolbar model.
    open func reloadItems() {
        guard let toolbar else {
            return
        }

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
                let compositeView = item.winCompositeView(
                    showItem: toolbar.displayMode != .labelOnly,
                    showLabel: toolbar.displayMode != .iconOnly,
                    toolbarHeight: frame.size.height
                )
                compositeView.frame = entry.frame
                // A selected item (selectedItemIdentifier) shows a subtle
                // pressed/selected band, matching the Mac toolbar look.
                if toolbar.selectedItemIdentifier == item.itemIdentifier {
                    compositeView.backgroundColor = NSColor(calibratedRed: 0.80, green: 0.84, blue: 0.90, alpha: 1.0)
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
                let spaceView = NSView(frame: entry.frame)
                addRenderedSubview(spaceView)
            }
        }

        // Overflow chevron (»): pops a menu of the items the narrow strip
        // pushed out, matching the Mac toolbar's overflow behavior.
        let menuWorthy = overflowedItems(for: toolbar).filter { item in
            item.itemIdentifier != .space
                && item.itemIdentifier != .flexibleSpace
                && item.itemIdentifier != .separator
        }
        if !menuWorthy.isEmpty {
            let chevron = NSToolbarOverflowChevronView(
                frame: NSMakeRect(max(frame.size.width - 26, 0), 0, 24, frame.size.height)
            )
            chevron.onOpenMenu = { [weak self, weak toolbar] chevronView in
                guard let toolbar else {
                    return
                }
                let menu = NSMenu(title: "")
                for item in self?.overflowedItems(for: toolbar) ?? [] where item.itemIdentifier != .space
                    && item.itemIdentifier != .flexibleSpace
                    && item.itemIdentifier != .separator {
                    let title = item.menuFormRepresentation?.title ?? item.label
                    let menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                    menuItem.isEnabled = item.isEnabled
                    menuItem.onAction = { [weak item] _ in
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
        bottomEdge.backgroundColor = NSColor(calibratedRed: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
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
            || view.backgroundColor != nil
        if !keepsOwnBackground {
            applyRealizedTransparentBackground(to: view)
        }
        renderedItemViews.append(view)
    }

    private func applyToolbarControlAppearance(to view: NSView) {
        view.backgroundColor = nil

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

        guard naturalWidth(of: visible) > frame.size.width else {
            return visible
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
            } else if item.itemIdentifier == .space || item.itemIdentifier == .flexibleSpace {
                layout.append(RenderedItemLayout(kind: .space, frame: itemFrame))
            } else {
                layout.append(RenderedItemLayout(kind: .standard(item), frame: itemFrame))
            }

            x += width + itemSpacing
        }

        return layout
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
        if item.view != nil {
            return max(item.minSize.width, min(item.maxSize.width, item.maxSize.width))
        }

        let mode: NSToolbar.DisplayMode
        switch toolbar.displayMode {
        case .default:
            mode = .iconAndLabel
        case .iconAndLabel, .iconOnly, .labelOnly:
            mode = toolbar.displayMode
        }
        let showsLabel = mode != .iconOnly
        let showsImage = mode != .labelOnly
        let iconWidth: CGFloat = showsImage && item.image != nil ? 24 : 0
        let labelWidth = showsLabel ? CGFloat(max(28, item.label.count * 6)) : 0
        let naturalWidth = max(iconWidth, labelWidth) + 16
        return max(item.minSize.width, min(item.maxSize.width, naturalWidth))
    }

    private func displayHeight(for item: NSToolbarItem) -> CGFloat {
        if item.itemIdentifier == .separator {
            return max(frame.size.height - 16, 8)
        }
        if item.itemIdentifier == .space || item.itemIdentifier == .flexibleSpace {
            return max(frame.size.height - 8, 8)
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

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        toolTip = "More toolbar items"
        backgroundColor = nil
    }

    override var acceptsFirstResponder: Bool {
        false
    }

    override func draw(_ dirtyRect: NSRect) {
        "»".draw(at: NSMakePoint(max((frame.size.width - 10) / 2, 0), max((frame.size.height - 18) / 2, 0)), withAttributes: [
            .font: NSFont.boldSystemFont(ofSize: 13),
            .foregroundColor: NSColor(calibratedRed: 0.25, green: 0.27, blue: 0.30, alpha: 1.0),
        ])
    }

    override func mouseUp(with event: NSEvent) {
        onOpenMenu?(self)
    }
}

/// Separator line used by composed toolbar rendering.
open class NSToolbarSeparatorView: NSView {
    /// Creates a separator view.
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // The view itself is the thin vertical bar; layout centers it inside
        // a wider separator slot so whitespace frames it on either side.
        backgroundColor = NSColor(calibratedRed: 0.66, green: 0.66, blue: 0.66, alpha: 1.0)
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

/// WinChocolate-specific rendering style for toolbar separator items.
public enum WinToolbarSeparatorStyle: Sendable {
    /// Follow the active presentation: classic Win32 renders a bar, the
    /// future modern look renders a blank gap.
    case automatic

    /// A vertical bar with a little whitespace on either side.
    case bar

    /// A blank gap.
    case space
}

/// Position of a toolbar item's label relative to its item image or view.
public enum WinToolbarLabelPosition: Sendable {
    /// Place the label below the item image or view.
    case below

    /// Place the label above the item image or view.
    case above

    /// Place the label to the left of the item image or view.
    case left

    /// Place the label to the right of the item image or view.
    case right
}

/// WinChocolate-specific representation used while dragging a toolbar item.
public enum WinToolbarDragRepresentation {
    /// Use an image as the drag representation.
    case image(NSImage)

    /// Use a view as the drag representation.
    case view(NSView)
}

private final class NSToolbarCompositeItemView: NSView {
    weak var item: NSToolbarItem?
    var title: String {
        didSet {
            updateNativeText()
        }
    }
    var imageName: String {
        didSet {
            updateNativeText()
        }
    }
    var showItem: Bool {
        didSet {
            updateNativeText()
        }
    }
    var showLabel: Bool {
        didSet {
            updateNativeText()
        }
    }
    var labelLocation: WinToolbarLabelPosition {
        didSet {
            updateNativeText()
        }
    }
    var isEnabled: Bool {
        didSet {
            updateNativeTextColor()
        }
    }

    init(
        item: NSToolbarItem,
        title: String,
        imageName: String,
        showItem: Bool,
        showLabel: Bool,
        labelLocation: WinToolbarLabelPosition,
        frame frameRect: NSRect
    ) {
        self.item = item
        self.title = title
        self.imageName = imageName
        self.showItem = showItem
        self.showLabel = showLabel
        self.labelLocation = labelLocation
        self.isEnabled = item.isEnabled
        super.init(frame: frameRect)
        toolTip = item.toolTip
        backgroundColor = nil
    }

    override var acceptsFirstResponder: Bool {
        false
    }

    override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = backend.createView(frame: frame, parent: parent)
        backend.setText(nativeText, for: handle)
        backend.setDrawsBackground(false, for: handle)
        updateNativeTextColor(for: handle, backend: backend)
        return handle
    }

    override func mouseUp(with event: NSEvent) {
        item?.performAction()
    }

    private var nativeText: String {
        [
            "__WinChocolateToolbarItem",
            title,
            imageName,
            showItem ? "1" : "0",
            showLabel ? "1" : "0",
            labelLocation.nativeName
        ].joined(separator: "\t")
    }

    private func updateNativeText() {
        guard let nativeHandle else {
            return
        }

        realizedBackend?.setText(nativeText, for: nativeHandle)
    }

    private func updateNativeTextColor() {
        guard let nativeHandle, let realizedBackend else {
            return
        }

        updateNativeTextColor(for: nativeHandle, backend: realizedBackend)
    }

    private func updateNativeTextColor(for handle: NativeHandle, backend: NativeControlBackend) {
        let color = isEnabled
            ? NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.12, alpha: 1.0)
            : NSColor(calibratedRed: 0.42, green: 0.44, blue: 0.46, alpha: 1.0)
        backend.setTextColor(color, for: handle)
    }
}

private extension WinToolbarLabelPosition {
    var nativeName: String {
        switch self {
        case .below:
            return "below"
        case .above:
            return "above"
        case .left:
            return "left"
        case .right:
            return "right"
        }
    }
}

/// Lets an action target control a toolbar item's enabled state, matching
/// AppKit's `NSToolbarItemValidation` informal contract: `validate()` asks the
/// item's target and applies the answer to `isEnabled`.
public protocol NSToolbarItemValidation: AnyObject {
    /// Returns whether the item should be enabled right now.
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool
}

/// A toolbar item model matching AppKit naming.
open class NSToolbarItem: NSObject {
    /// Toolbar item identifier.
    public struct Identifier: RawRepresentable, Hashable, Sendable, ExpressibleByStringLiteral {
        /// Raw identifier string.
        public let rawValue: String

        /// Creates an identifier from a raw string.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// Creates an identifier from a string literal.
        public init(stringLiteral value: String) {
            self.rawValue = value
        }

        /// Space item identifier.
        public static let space = Identifier(rawValue: "NSToolbarSpaceItem")

        /// Flexible space item identifier.
        public static let flexibleSpace = Identifier(rawValue: "NSToolbarFlexibleSpaceItem")

        /// Separator item identifier.
        public static let separator = Identifier(rawValue: "NSToolbarSeparatorItem")

        /// Standard print item; prints the key window's content by default.
        public static let print = Identifier(rawValue: "NSToolbarPrintItem")

        /// Standard show-colors item; opens the shared color panel.
        public static let showColors = Identifier(rawValue: "NSToolbarShowColorsItem")

        /// Standard show-fonts item; opens the shared font panel.
        public static let showFonts = Identifier(rawValue: "NSToolbarShowFontsItem")

        /// Classic customize-toolbar item; runs the customization palette.
        public static let customizeToolbar = Identifier(rawValue: "NSToolbarCustomizeToolbarItem")
    }

    /// Toolbar item visibility priority.
    public enum VisibilityPriority: Int, Sendable {
        case standard = 0
        case low = -1000
        case high = 1000
        case user = 2000
    }

    /// The item identifier.
    public let itemIdentifier: Identifier

    /// Primary visible label.
    open var label: String {
        didSet {
            toolbar?.validateVisibleItems()
        }
    }

    /// Label used in customization UI.
    open var paletteLabel: String

    /// Title shown by bordered (button-style) items, matching AppKit.
    open var title: String = ""

    /// Whether the item renders as a bordered control (macOS 10.15+ shape).
    /// The classic presentation stores the flag; the modern look will render it.
    open var isBordered: Bool = false

    /// Application-defined integer tag, matching AppKit.
    open var tag: Int = -1

    /// Compact menu representation used when the item moves into the overflow
    /// menu (or text-only menus), matching AppKit's `menuFormRepresentation`.
    open var menuFormRepresentation: NSMenuItem?

    /// Whether `validateVisibleItems()` includes this item, matching AppKit's
    /// `autovalidates` (default `true`).
    open var autovalidates: Bool = true

    /// Tooltip text.
    open var toolTip: String?

    /// Target object for `action`.
    open weak var target: AnyObject?

    /// Selector sent when the item is activated.
    open var action: Selector?

    /// Custom view for this item.
    open var view: NSView?

    /// Image shown by icon-capable toolbar renderers.
    open var image: NSImage? {
        didSet {
            toolbar?.validateVisibleItems()
        }
    }

    /// WinChocolate-specific image shown for this item in the customization palette.
    open var winImageForPallate: NSImage?

    /// WinChocolate-specific image or view used as this item's drag representation.
    open var winRenderForDrag: WinToolbarDragRepresentation?

    /// Minimum item size.
    open var minSize: NSSize = NSMakeSize(32, 28)

    /// Maximum item size.
    open var maxSize: NSSize = NSMakeSize(160, 28)

    /// Whether this item is enabled.
    open var isEnabled: Bool = true {
        didSet {
            guard oldValue != isEnabled else {
                return
            }
            (view as? NSControl)?.isEnabled = isEnabled
            toolbar?.validateVisibleItems()
        }
    }

    /// Visibility priority used when a toolbar overflows.
    open var visibilityPriority: VisibilityPriority = .standard

    /// Swift-native action invoked by `performAction()`.
    open var onAction: ((NSToolbarItem) -> Void)?

    /// The containing toolbar.
    public internal(set) weak var toolbar: NSToolbar?

    /// Creates a toolbar item.
    public init(itemIdentifier: Identifier) {
        self.itemIdentifier = itemIdentifier
        self.label = itemIdentifier.rawValue
        self.paletteLabel = itemIdentifier.rawValue
        self.image = nil
        super.init()
    }

    /// Refreshes `isEnabled` from the item's target, matching AppKit's
    /// `validate()`: a target adopting `NSToolbarItemValidation` decides the
    /// enabled state; view-based items and targetless items are left alone.
    open func validate() {
        guard view == nil else {
            return
        }
        guard let validator = target as? NSToolbarItemValidation else {
            return
        }
        let valid = validator.validateToolbarItem(self)
        if valid != isEnabled {
            isEnabled = valid
        }
    }

    /// Programmatically activates the item.
    open func performAction() {
        guard isEnabled else {
            return
        }

        if let control = view as? NSControl {
            control.sendAction()
            return
        }

        onAction?(self)
    }

    /// Creates a transparent composite view for this item in a toolbar.
    open func winCompositeView(
        showItem: Bool,
        showLabel: Bool,
        winLabelLocation: WinToolbarLabelPosition = .below,
        toolbarHeight: CGFloat
    ) -> NSView {
        if itemIdentifier == .separator {
            let separatorView = NSToolbarSeparatorView(frame: NSMakeRect(0, 0, 8, max(toolbarHeight - 12, 8)))
            separatorView.toolTip = toolTip
            return separatorView
        }

        let imageSize = NSMakeSize(24, 20)
        let labelSize = showLabel ? NSMakeSize(max(28, CGFloat(label.count * 6)), 13) : NSMakeSize(0, 0)
        let gap: CGFloat = showItem && showLabel ? 2 : 0
        let itemSize = showItem ? imageSize : NSMakeSize(0, 0)
        let horizontal = winLabelLocation == .left || winLabelLocation == .right
        let width = horizontal
            ? itemSize.width + labelSize.width + gap + 8
            : max(itemSize.width, labelSize.width) + 8
        let contentHeight = horizontal
            ? max(itemSize.height, labelSize.height)
            : itemSize.height + labelSize.height + gap
        let height = min(max(contentHeight + 4, 20), max(toolbarHeight, 20))
        return NSToolbarCompositeItemView(
            item: self,
            title: label,
            imageName: winToolbarImageName,
            showItem: showItem,
            showLabel: showLabel,
            labelLocation: winLabelLocation,
            frame: NSMakeRect(0, 0, width, height)
        )
    }

    private var winToolbarImageName: String {
        if let name = (image ?? winImageForPallate)?.name, !name.isEmpty {
            return name
        }

        return itemIdentifier.rawValue
    }
}

/// AppKit-compatible toolbar item identifier alias.
public typealias NSToolbarItemIdentifier = NSToolbarItem.Identifier
