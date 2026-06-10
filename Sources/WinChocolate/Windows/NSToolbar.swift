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

    /// Unique toolbar identifier.
    public let identifier: String

    /// The toolbar's visible items.
    public private(set) var items: [NSToolbarItem] = []

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
        }
    }

    /// Preferred toolbar display mode.
    open var displayMode: DisplayMode = .default {
        didSet {
            itemsDidChange?()
        }
    }

    /// Preferred toolbar size mode.
    open var sizeMode: SizeMode = .default

    /// The window this toolbar is attached to.
    public private(set) weak var window: NSWindow?

    /// Called when `isVisible` changes.
    public var visibilityDidChange: ((Bool) -> Void)?

    /// Called when the toolbar item list changes.
    public var itemsDidChange: (() -> Void)?

    private var itemStore: [NSToolbarItem.Identifier: NSToolbarItem] = [:]
    private var customizationPanel: NSPanel?

    /// Creates a toolbar with an AppKit-style identifier.
    public init(identifier: String) {
        self.identifier = identifier
        super.init()
    }

    /// Adds an item at the end of the toolbar.
    open func addItem(_ item: NSToolbarItem) {
        insertItem(item, at: items.count)
    }

    /// Inserts an item at the requested index.
    open func insertItem(_ item: NSToolbarItem, at index: Int) {
        item.toolbar = nil
        let insertionIndex = min(max(index, 0), items.count)
        items.insert(item, at: insertionIndex)
        itemStore[item.itemIdentifier] = item
        item.toolbar = self
        itemsDidChange?()
    }

    /// Removes and returns the item at the given index.
    @discardableResult
    open func removeItem(at index: Int) -> NSToolbarItem? {
        guard items.indices.contains(index) else {
            return nil
        }

        let item = items.remove(at: index)
        item.toolbar = nil
        itemsDidChange?()
        return item
    }

    /// Returns the first item with the given identifier.
    open func item(withIdentifier identifier: NSToolbarItem.Identifier) -> NSToolbarItem? {
        items.first { $0.itemIdentifier == identifier } ?? itemStore[identifier]
    }

    /// Asks visible toolbar renderers to refresh their item state.
    open func validateVisibleItems() {
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

    /// Opens a toolbar customization palette.
    open func runCustomizationPalette(_ sender: Any?) {
        guard allowsUserCustomization else {
            return
        }

        let allowedIdentifiers = delegate?.toolbarAllowedItemIdentifiers(self) ?? itemStore.keys.map { $0 }
        let panel = NSPanel(
            contentRect: NSMakeRect(180, 180, 620, 440),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Customize Toolbar"

        enum CustomizationDragSource {
            case palette(NSToolbarItem.Identifier)
            case defaultSet
            case toolbar(index: Int, identifier: NSToolbarItem.Identifier)
        }

        let content = NSView(frame: NSMakeRect(0, 0, 620, 440))
        let toolbarFrame = NSMakeRect(0, 0, 620, 42)
        let showLabel = NSTextField(string: "Show:", frame: NSMakeRect(24, 54, 64, 24))
        let displayModePopup = NSPopUpButton(frame: NSMakeRect(90, 52, 172, 26), pullsDown: false)
        let doneButton = NSButton(title: "Done", frame: NSMakeRect(520, 52, 76, 28))
        let instructionLabel = NSTextField(string: "Drag your favorite items into the toolbar:", frame: NSMakeRect(24, 90, 360, 24))
        let paletteView = NSView(frame: NSMakeRect(24, 122, 572, 100))
        let defaultInstructionLabel = NSTextField(string: "or drag the default set into the toolbar:", frame: NSMakeRect(24, 234, 420, 24))
        let defaultStrip = NSView(frame: NSMakeRect(24, 264, 572, 38))
        let selectionLabel = NSTextField(string: "Selected: none", frame: NSMakeRect(24, 324, 180, 24))
        let moveLeftButton = NSButton(title: "Move Left", frame: NSMakeRect(214, 322, 86, 28))
        let moveRightButton = NSButton(title: "Move Right", frame: NSMakeRect(308, 322, 92, 28))
        let removeButton = NSButton(title: "Remove", frame: NSMakeRect(408, 322, 76, 28))
        let dragPreview = NSToolbarCustomizationTile(title: "", frame: NSMakeRect(-10_000, -10_000, 1, 1))
        var selectedIndex: Int?
        var dragSource: CustomizationDragSource?
        var toolbarTileViews: [NSView] = []

        paletteView.backgroundColor = NSColor(calibratedRed: 0.94, green: 0.94, blue: 0.94, alpha: 1.0)
        defaultStrip.backgroundColor = NSColor(calibratedRed: 0.97, green: 0.97, blue: 0.97, alpha: 1.0)
        dragPreview.isEnabled = false
        dragPreview.isHidden = true
        content.tag = 1_100
        displayModePopup.addItems(withTitles: ["Icon & Label", "Icon Only", "Label Only"])
        switch displayMode {
        case .default, .iconAndLabel:
            displayModePopup.selectItem(at: 0)
        case .iconOnly:
            displayModePopup.selectItem(at: 1)
        case .labelOnly:
            displayModePopup.selectItem(at: 2)
        }

        func title(for identifier: NSToolbarItem.Identifier) -> String {
            if identifier == .flexibleSpace {
                return "Flexible Space"
            }
            if identifier == .separator {
                return "Separator"
            }
            if identifier == .space {
                return "Space"
            }

            let item = itemForCustomizationIdentifier(identifier, willBeInsertedIntoToolbar: false)
            if let item, item.paletteLabel != identifier.rawValue {
                return item.paletteLabel
            }
            return item?.label ?? identifier.rawValue
        }

        func setDisplayModeFromPopup() {
            switch displayModePopup.indexOfSelectedItem {
            case 1:
                displayMode = .iconOnly
            case 2:
                displayMode = .labelOnly
            default:
                displayMode = .iconAndLabel
            }
        }

        func customizationItemWidth(for identifier: NSToolbarItem.Identifier, selected: Bool = false, availableWidth: CGFloat? = nil) -> CGFloat {
            let baseTitle = title(for: identifier)
            let buttonTitle = selected ? "[\(baseTitle)]" : baseTitle
            let naturalWidth = max(56, min(104, CGFloat(buttonTitle.count * 7 + 20)))
            guard let availableWidth else {
                return naturalWidth
            }
            return max(48, min(naturalWidth, availableWidth))
        }

        func toolbarItemWidth(for identifier: NSToolbarItem.Identifier, selected: Bool = false) -> CGFloat {
            let itemCount = max(CGFloat(items.count), 1)
            let availableWidth = max(48, (toolbarFrame.size.width - 16 - ((itemCount - 1) * 6)) / itemCount)
            return customizationItemWidth(for: identifier, selected: selected, availableWidth: availableWidth)
        }

        func rowItemWidth(count: Int, rowWidth: CGFloat, spacing: CGFloat, horizontalInset: CGFloat) -> CGFloat {
            let itemCount = max(CGFloat(count), 1)
            return max(48, (rowWidth - (horizontalInset * 2) - ((itemCount - 1) * spacing)) / itemCount)
        }

        func contentPoint(from event: NSEvent, source _: NSView) -> NSPoint {
            content.convert(event.locationInWindow, from: nil)
        }

        func toolbarInsertionIndex(for event: NSEvent, source: NSView) -> Int? {
            let point = contentPoint(from: event, source: source)
            guard NSPointInRect(point, toolbarFrame) else {
                return nil
            }

            let localX = point.x - toolbarFrame.origin.x
            var x: CGFloat = 8
            for (index, identifier) in items.map(\.itemIdentifier).enumerated() {
                let width = toolbarItemWidth(for: identifier, selected: index == selectedIndex)
                if localX < x + (width / 2) {
                    return index
                }
                x += width + 6
            }
            return items.count
        }

        func addIdentifierToToolbar(_ identifier: NSToolbarItem.Identifier, at insertionIndex: Int? = nil) {
            var identifiers = items.map(\.itemIdentifier)
            if !identifier.allowsMultipleToolbarInstances && identifiers.contains(identifier) {
                selectedIndex = identifiers.firstIndex(of: identifier)
                rebuildToolbarStrip()
                return
            }

            let destination = min(max(insertionIndex ?? (identifiers.firstIndex(of: .flexibleSpace) ?? identifiers.count), 0), identifiers.count)
            identifiers.insert(identifier, at: destination)
            setVisibleItemIdentifiers(identifiers)
            selectedIndex = destination
            rebuildToolbarStrip()
        }

        func removeSelectedItem() {
            guard let currentSelection = selectedIndex else {
                return
            }

            var identifiers = items.map(\.itemIdentifier)
            guard identifiers.indices.contains(currentSelection) else {
                return
            }

            identifiers.remove(at: currentSelection)
            setVisibleItemIdentifiers(identifiers)
            selectedIndex = nil
            rebuildToolbarStrip()
        }

        func moveSelectedItem(by offset: Int) {
            guard let currentIndex = selectedIndex else {
                return
            }

            var identifiers = items.map(\.itemIdentifier)
            guard identifiers.indices.contains(currentIndex) else {
                return
            }

            let destination = min(max(currentIndex + offset, 0), identifiers.count - 1)
            guard destination != currentIndex else {
                return
            }

            let identifier = identifiers.remove(at: currentIndex)
            identifiers.insert(identifier, at: destination)
            setVisibleItemIdentifiers(identifiers)
            selectedIndex = destination
            rebuildToolbarStrip()
        }

        func moveItem(from currentIndex: Int, to insertionIndex: Int) {
            var identifiers = items.map(\.itemIdentifier)
            guard identifiers.indices.contains(currentIndex) else {
                return
            }

            let movedIdentifier = identifiers.remove(at: currentIndex)
            var destination = min(max(insertionIndex, 0), identifiers.count)
            if currentIndex < insertionIndex {
                destination = max(destination - 1, 0)
            }
            identifiers.insert(movedIdentifier, at: destination)
            setVisibleItemIdentifiers(identifiers)
            selectedIndex = destination
            rebuildToolbarStrip()
        }

        func finishDrop(onToolbarFrom source: CustomizationDragSource?, event: NSEvent, sourceView: NSView) {
            guard let source, let insertionIndex = toolbarInsertionIndex(for: event, source: sourceView) else {
                return
            }

            switch source {
            case .palette(let identifier):
                addIdentifierToToolbar(identifier, at: insertionIndex)
            case .defaultSet:
                self.resetVisibleItemsToDefault()
                selectedIndex = nil
                rebuildToolbarStrip()
            case .toolbar(let index, _):
                moveItem(from: index, to: insertionIndex)
            }
        }

        func updateDragPreview(for tile: NSToolbarCustomizationTile, frame: NSRect) -> Bool {
            guard let parent = tile.superview else {
                return false
            }

            let origin = content.convert(frame.origin, from: parent)
            dragPreview.title = tile.title
            dragPreview.frame = NSMakeRect(origin.x, origin.y, frame.size.width, frame.size.height)
            dragPreview.isHidden = false
            return true
        }

        func clearDragPreview() {
            dragPreview.isHidden = true
            dragPreview.frame = NSMakeRect(-10_000, -10_000, 1, 1)
        }

        func rebuildToolbarStrip() {
            for view in toolbarTileViews {
                view.removeFromSuperview()
            }
            toolbarTileViews.removeAll()

            var x: CGFloat = 8
            for (index, identifier) in items.map(\.itemIdentifier).enumerated() {
                let selected = index == selectedIndex
                let buttonTitle = selected ? "[\(title(for: identifier))]" : title(for: identifier)
                let width = toolbarItemWidth(for: identifier, selected: selected)
                let button = NSToolbarCustomizationTile(title: buttonTitle, frame: NSMakeRect(x, 7, width, 28))
                button.onBeginDrag = {
                    dragSource = .toolbar(index: index, identifier: identifier)
                }
                button.onClick = {
                    selectedIndex = index
                    rebuildToolbarStrip()
                }
                button.onDrop = { tile, event in
                    selectedIndex = index
                    if toolbarInsertionIndex(for: event, source: tile) != nil {
                        finishDrop(onToolbarFrom: dragSource ?? .toolbar(index: index, identifier: identifier), event: event, sourceView: tile)
                    } else {
                        removeSelectedItem()
                    }
                    dragSource = nil
                }
                content.addSubview(button)
                toolbarTileViews.append(button)
                x += width + 6
            }

            if let selectedIndex, items.indices.contains(selectedIndex) {
                selectionLabel.stringValue = "Selected: \(title(for: items[selectedIndex].itemIdentifier))"
            } else {
                selectionLabel.stringValue = "Selected: none"
            }
        }

        for (index, identifier) in allowedIdentifiers.enumerated() {
            let column = index % 4
            let row = index / 4
            let button = NSToolbarCustomizationTile(title: title(for: identifier), frame: NSMakeRect(Double(column * 138 + 8), Double(58 - (row * 34)), 126, 28))
            button.onBeginDrag = {
                dragSource = .palette(identifier)
            }
            button.onDrop = { tile, event in
                finishDrop(onToolbarFrom: dragSource ?? .palette(identifier), event: event, sourceView: tile)
                dragSource = nil
            }
            button.onDragFrameChanged = { tile, frame in
                updateDragPreview(for: tile, frame: frame)
            }
            button.onEndDrag = {
                clearDragPreview()
            }
            paletteView.addSubview(button)
        }

        let defaultIdentifiers = delegate?.toolbarDefaultItemIdentifiers(self) ?? itemStore.keys.map { $0 }
        var defaultX: CGFloat = 8
        let defaultWidth = rowItemWidth(count: defaultIdentifiers.count, rowWidth: defaultStrip.frame.size.width, spacing: 6, horizontalInset: 8)
        for identifier in defaultIdentifiers {
            let button = NSToolbarCustomizationTile(title: title(for: identifier), frame: NSMakeRect(defaultX, 7, defaultWidth, 26))
            button.onBeginDrag = {
                dragSource = .defaultSet
            }
            button.onDrop = { tile, event in
                finishDrop(onToolbarFrom: dragSource ?? .defaultSet, event: event, sourceView: tile)
                dragSource = nil
            }
            button.onDragFrameChanged = { tile, frame in
                updateDragPreview(for: tile, frame: frame)
            }
            button.onEndDrag = {
                clearDragPreview()
            }
            defaultStrip.addSubview(button)
            defaultX += defaultWidth + 6
        }

        displayModePopup.onAction = { _ in
            setDisplayModeFromPopup()
        }
        moveLeftButton.onAction = { _ in
            moveSelectedItem(by: -1)
        }
        moveRightButton.onAction = { _ in
            moveSelectedItem(by: 1)
        }
        removeButton.onAction = { _ in
            removeSelectedItem()
        }
        doneButton.onAction = { _ in
            panel.close()
        }

        content.addSubview(instructionLabel)
        content.addSubview(paletteView)
        content.addSubview(defaultInstructionLabel)
        content.addSubview(defaultStrip)
        content.addSubview(selectionLabel)
        content.addSubview(moveLeftButton)
        content.addSubview(moveRightButton)
        content.addSubview(removeButton)
        content.addSubview(showLabel)
        content.addSubview(displayModePopup)
        content.addSubview(doneButton)
        panel.contentView = content
        customizationPanel = panel
        rebuildToolbarStrip()
        content.addSubview(dragPreview)
        panel.makeKeyAndOrderFront(sender)
    }

    private func itemForCustomizationIdentifier(
        _ identifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        if let existing = itemStore[identifier] {
            return existing
        }

        guard let item = delegate?.toolbar(self, itemForItemIdentifier: identifier, willBeInsertedIntoToolbar: flag) else {
            return nil
        }

        itemStore[identifier] = item
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
    }
}

private extension NSToolbarItem.Identifier {
    var allowsMultipleToolbarInstances: Bool {
        switch self {
        case .separator, .space, .flexibleSpace:
            return true
        default:
            return false
        }
    }
}

private final class NSToolbarCustomizationTile: NSButton {
    var onBeginDrag: (() -> Void)?
    var onClick: (() -> Void)?
    var onDrop: ((NSToolbarCustomizationTile, NSEvent) -> Void)?
    var onDragFrameChanged: ((NSToolbarCustomizationTile, NSRect) -> Bool)?
    var onEndDrag: (() -> Void)?
    private var hasDragged = false
    private var didBeginDrag = false
    private var dragAnchor: NSPoint?
    private var originalFrame: NSRect?

    override init(title: String, frame frameRect: NSRect) {
        super.init(title: title, frame: frameRect)
        isBordered = true
    }

    override var acceptsFirstResponder: Bool {
        false
    }

    override func mouseDown(with event: NSEvent) {
        hasDragged = false
        didBeginDrag = false
        dragAnchor = event.locationInWindow
        originalFrame = frame
    }

    override func mouseDragged(with event: NSEvent) {
        hasDragged = true
        if !didBeginDrag {
            didBeginDrag = true
            onBeginDrag?()
        }

        if let dragFrame = dragFrame(for: event) {
            if onDragFrameChanged?(self, dragFrame) != true {
                frame = dragFrame
            }
        }
    }

    private func dragFrame(for event: NSEvent) -> NSRect? {
        guard let dragAnchor, let originalFrame else {
            return nil
        }

        return NSMakeRect(
                originalFrame.origin.x + (event.locationInWindow.x - dragAnchor.x),
                originalFrame.origin.y + (event.locationInWindow.y - dragAnchor.y),
                originalFrame.size.width,
                originalFrame.size.height
            )
    }

    override func mouseUp(with event: NSEvent) {
        if hasDragged {
            onDrop?(self, event)
            onEndDrag?()
        } else {
            onClick?()
        }
        hasDragged = false
        didBeginDrag = false
        dragAnchor = nil
        if let originalFrame, superview != nil {
            frame = originalFrame
        }
        originalFrame = nil
    }
}

/// A classic native toolbar renderer.
///
/// AppKit's `NSToolbar` is normally window chrome, not a regular content view.
/// This view hosts the current classic `ToolbarWindow32` peer from the same
/// `NSToolbarItem` model and is owned by `NSWindow` when `window.toolbar` is set.
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
    open var itemHeight: CGFloat = 30

    /// Horizontal padding before the first item.
    open var leadingPadding: CGFloat = 8

    /// Spacing between normal items.
    open var itemSpacing: CGFloat = 4

    /// Called after the hosted toolbar visibility changes.
    public var visibilityChanged: ((Bool) -> Void)?

    /// Creates a toolbar view.
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        backgroundColor = NSColor(calibratedRed: 0.84, green: 0.84, blue: 0.80, alpha: 1.0)
    }

    /// Toolbar strips do not take focus; their items do.
    open override var acceptsFirstResponder: Bool {
        false
    }

    /// Rebuilds the native toolbar items from the toolbar model.
    open func reloadItems() {
        guard let toolbar, let nativeHandle, let realizedBackend else {
            return
        }

        realizedBackend.setToolbarItems(nativeItems(from: toolbar), for: nativeHandle)
    }

    /// Creates the native toolbar peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createToolbar(items: toolbar.map(nativeItems(from:)) ?? [], frame: frame, parent: parent)
    }

    /// Ensures the toolbar has a native peer and registers item dispatch.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        backend.registerToolbarAction(for: handle) { [weak self] identifier in
            guard let item = self?.toolbar?.item(withIdentifier: NSToolbarItem.Identifier(rawValue: identifier)) else {
                return
            }

            item.performAction()
        }
        backend.setToolbarItems(toolbar.map(nativeItems(from:)) ?? [], for: handle)
        return handle
    }

    private func nativeItems(from toolbar: NSToolbar) -> [NativeToolbarItem] {
        toolbar.items.map { item in
            switch item.itemIdentifier {
            case .flexibleSpace:
                return NativeToolbarItem(
                    identifier: item.itemIdentifier.rawValue,
                    label: "",
                    isSeparator: true,
                    isFlexibleSpace: true,
                    isEnabled: false
                )
            case .separator, .space:
                return NativeToolbarItem(identifier: item.itemIdentifier.rawValue, label: "", isSeparator: true, isEnabled: false)
            default:
                let showsLabel = toolbar.displayMode != .iconOnly
                let showsImage = toolbar.displayMode != .labelOnly
                return NativeToolbarItem(
                    identifier: item.itemIdentifier.rawValue,
                    label: showsLabel ? item.label : "",
                    imageName: showsImage ? item.image?.name : nil,
                    isSeparator: false,
                    isEnabled: item.isEnabled
                )
            }
        }
    }
}

/// Separator line used by composed toolbar rendering.
open class NSToolbarSeparatorView: NSView {
    /// Creates a separator view.
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        backgroundColor = NSColor(calibratedRed: 0.52, green: 0.52, blue: 0.48, alpha: 1.0)
    }

    /// Separators are display-only.
    open override var acceptsFirstResponder: Bool {
        false
    }
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

    /// Minimum item size.
    open var minSize: NSSize = NSMakeSize(32, 28)

    /// Maximum item size.
    open var maxSize: NSSize = NSMakeSize(160, 28)

    /// Whether this item is enabled.
    open var isEnabled: Bool = true {
        didSet {
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

    /// Sends the configured action if possible.
    open func validate() -> Bool {
        isEnabled
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
}

/// AppKit-compatible toolbar item identifier alias.
public typealias NSToolbarItemIdentifier = NSToolbarItem.Identifier
