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
    open var sizeMode: SizeMode = .default {
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
            styleMask: [.titled, .closable, .resizable],
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
        let showLabel = NSTextField(string: "Show:", frame: NSMakeRect(24, 58, 64, 24))
        let displayModePopup = NSPopUpButton(frame: NSMakeRect(90, 56, 172, 26), pullsDown: false)
        let doneButton = NSButton(title: "Done", frame: NSMakeRect(520, 56, 76, 28))
        let instructionLabel = NSTextField(string: "Drag your favorite items into the toolbar:", frame: NSMakeRect(24, 96, 360, 24))
        let paletteView = NSView(frame: NSMakeRect(24, 126, 572, 106))
        let defaultInstructionLabel = NSTextField(string: "or drag the default set into the toolbar:", frame: NSMakeRect(24, 246, 420, 24))
        let defaultStrip = NSView(frame: NSMakeRect(24, 276, 572, 42))
        let selectionLabel = NSTextField(string: "Selected: none", frame: NSMakeRect(24, 334, 180, 24))
        let moveLeftButton = NSButton(title: "Move Left", frame: NSMakeRect(214, 332, 86, 28))
        let moveRightButton = NSButton(title: "Move Right", frame: NSMakeRect(308, 332, 92, 28))
        let removeButton = NSButton(title: "Remove", frame: NSMakeRect(408, 332, 76, 28))
        let dragPreview = NSToolbarCustomizationTile(title: "", frame: NSMakeRect(-10_000, -10_000, 1, 1))
        var selectedIndex: Int?
        var dragSource: CustomizationDragSource?
        var toolbarTileViews: [NSView] = []

        content.backgroundColor = NSColor(calibratedRed: 0.89, green: 0.91, blue: 0.93, alpha: 1.0)
        paletteView.backgroundColor = NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.97, alpha: 1.0)
        defaultStrip.backgroundColor = NSColor(calibratedRed: 0.95, green: 0.96, blue: 0.98, alpha: 1.0)
        paletteView.autoresizingMask = [.width]
        defaultInstructionLabel.autoresizingMask = [.width, .minYMargin]
        defaultStrip.autoresizingMask = [.width, .minYMargin]
        selectionLabel.autoresizingMask = [.minYMargin]
        moveLeftButton.autoresizingMask = [.minYMargin]
        moveRightButton.autoresizingMask = [.minYMargin]
        removeButton.autoresizingMask = [.minYMargin]
        doneButton.autoresizingMask = [.minXMargin]
        dragPreview.style = .preview
        dragPreview.isHidden = true
        content.tag = 1_100
        for label in [showLabel, instructionLabel, defaultInstructionLabel, selectionLabel] {
            label.isBordered = false
            label.drawsBackground = false
        }
        selectionLabel.textColor = NSColor(calibratedRed: 0.20, green: 0.24, blue: 0.28, alpha: 1.0)
        displayModePopup.addItems(withTitles: ["Icon & Label", "Icon Only", "Label Only"])
        switch displayMode {
        case .default, .iconAndLabel:
            displayModePopup.selectItem(at: 0)
        case .iconOnly:
            displayModePopup.selectItem(at: 1)
        case .labelOnly:
            displayModePopup.selectItem(at: 2)
        }

        func title(for identifier: NSToolbarItem.Identifier, prefersPaletteLabel: Bool = true) -> String {
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
            if prefersPaletteLabel, let item, item.paletteLabel != identifier.rawValue {
                return item.paletteLabel
            }
            return item?.label ?? identifier.rawValue
        }

        func imageName(for identifier: NSToolbarItem.Identifier) -> String {
            switch identifier {
            case .separator:
                return "separator"
            case .space:
                return "space"
            case .flexibleSpace:
                return "flexibleSpace"
            default:
                break
            }

            let item = itemForCustomizationIdentifier(identifier, willBeInsertedIntoToolbar: false)
            if let imageName = item?.image?.name, !imageName.isEmpty {
                return imageName
            }

            let key = "\(identifier.rawValue) \(item?.label ?? "") \(item?.paletteLabel ?? "")".lowercased()
            if key.contains("open") || key.contains("folder") {
                return "folder"
            }
            if key.contains("disable") && key.contains("save") {
                return "properties"
            }
            if key.contains("save") {
                return "save"
            }
            if key.contains("print") {
                return "print"
            }
            if key.contains("custom") || key.contains("setting") || key.contains("gear") {
                return "properties"
            }
            if key.contains("delete") || key.contains("remove") || key.contains("trash") {
                return "trash"
            }
            if key.contains("search") || key.contains("find") {
                return "search"
            }
            if key.contains("new") || key.contains("add") {
                return "plus"
            }
            return "document"
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
            let buttonTitle = baseTitle
            let naturalWidth = max(64, min(112, CGFloat(buttonTitle.count * 7 + 24)))
            guard let availableWidth else {
                return naturalWidth
            }
            return max(48, min(naturalWidth, availableWidth))
        }

        func toolbarItemWidth(for identifier: NSToolbarItem.Identifier, selected: Bool = false) -> CGFloat {
            let itemCount = max(CGFloat(items.count), 1)
            let toolbarWidth = max(48, content.frame.size.width)
            let availableWidth = max(48, (toolbarWidth - 16 - ((itemCount - 1) * 6)) / itemCount)
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
            let toolbarFrame = NSMakeRect(0, 0, content.frame.size.width, 46)
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
            var destination = insertionIndex
            if currentIndex < insertionIndex {
                destination = max(destination - 1, 0)
            }
            destination = min(max(destination, 0), identifiers.count)
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
            dragPreview.imageName = tile.imageName
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

            var x: CGFloat = 10
            for (index, identifier) in items.map(\.itemIdentifier).enumerated() {
                let selected = index == selectedIndex
                let width = toolbarItemWidth(for: identifier, selected: selected)
                let tile = NSToolbarCustomizationTile(title: title(for: identifier, prefersPaletteLabel: false), imageName: imageName(for: identifier), frame: NSMakeRect(x, 8, width, 30))
                tile.style = .toolbar
                tile.isSelected = selected
                tile.toolTip = "Drag to reorder or drag out to remove."
                tile.onBeginDrag = {
                    dragSource = .toolbar(index: index, identifier: identifier)
                }
                tile.onClick = {
                    selectedIndex = index
                    rebuildToolbarStrip()
                }
                tile.onDrop = { tile, event in
                    selectedIndex = index
                    if toolbarInsertionIndex(for: event, source: tile) != nil {
                        finishDrop(onToolbarFrom: dragSource ?? .toolbar(index: index, identifier: identifier), event: event, sourceView: tile)
                    } else {
                        removeSelectedItem()
                    }
                    dragSource = nil
                }
                tile.onDragFrameChanged = { tile, frame in
                    updateDragPreview(for: tile, frame: frame)
                }
                tile.onEndDrag = {
                    clearDragPreview()
                }
                content.addSubview(tile)
                toolbarTileViews.append(tile)
                x += width + 8
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
            let tile = NSToolbarCustomizationTile(title: title(for: identifier), imageName: imageName(for: identifier), frame: NSMakeRect(Double(column * 138 + 10), Double(64 - (row * 36)), 124, 30))
            tile.style = .palette
            tile.toolTip = "Drag into the toolbar."
            tile.onBeginDrag = {
                dragSource = .palette(identifier)
            }
            tile.onDrop = { tile, event in
                finishDrop(onToolbarFrom: dragSource ?? .palette(identifier), event: event, sourceView: tile)
                dragSource = nil
            }
            tile.onDragFrameChanged = { tile, frame in
                updateDragPreview(for: tile, frame: frame)
            }
            tile.onEndDrag = {
                clearDragPreview()
            }
            paletteView.addSubview(tile)
        }

        let defaultIdentifiers = delegate?.toolbarDefaultItemIdentifiers(self) ?? itemStore.keys.map { $0 }
        var defaultX: CGFloat = 10
        let defaultWidth = rowItemWidth(count: defaultIdentifiers.count, rowWidth: defaultStrip.frame.size.width, spacing: 8, horizontalInset: 10)
        for identifier in defaultIdentifiers {
            let tile = NSToolbarCustomizationTile(title: title(for: identifier), imageName: imageName(for: identifier), frame: NSMakeRect(defaultX, 7, defaultWidth, 28))
            tile.style = .defaultSet
            tile.toolTip = "Drag to restore the default toolbar."
            tile.onBeginDrag = {
                dragSource = .defaultSet
            }
            tile.onDrop = { tile, event in
                finishDrop(onToolbarFrom: dragSource ?? .defaultSet, event: event, sourceView: tile)
                dragSource = nil
            }
            tile.onDragFrameChanged = { tile, frame in
                updateDragPreview(for: tile, frame: frame)
            }
            tile.onEndDrag = {
                clearDragPreview()
            }
            defaultStrip.addSubview(tile)
            defaultX += defaultWidth + 8
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

private final class NSToolbarCustomizationTile: NSView {
    enum Style {
        case toolbar
        case palette
        case defaultSet
        case preview
    }

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

    var style: Style = .palette {
        didSet {
            updateAppearance()
        }
    }

    var isSelected = false {
        didSet {
            updateAppearance()
        }
    }

    var isEnabled = true {
        didSet {
            updateAppearance()
            updateNativeTextColor()
        }
    }

    var onBeginDrag: (() -> Void)?
    var onClick: (() -> Void)?
    var onDrop: ((NSToolbarCustomizationTile, NSEvent) -> Void)?
    var onDragFrameChanged: ((NSToolbarCustomizationTile, NSRect) -> Bool)?
    var onEndDrag: (() -> Void)?
    private var hasDragged = false
    private var didBeginDrag = false
    private var dragAnchor: NSPoint?
    private var originalFrame: NSRect?

    convenience init(title: String, frame frameRect: NSRect) {
        self.init(title: title, imageName: "document", frame: frameRect)
    }

    init(title: String, imageName: String, frame frameRect: NSRect) {
        self.title = title
        self.imageName = imageName
        super.init(frame: frameRect)
        updateAppearance()
    }

    override var acceptsFirstResponder: Bool {
        false
    }

    override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = backend.createView(frame: frame, parent: parent)
        backend.setText(nativeText, for: handle)
        updateNativeTextColor(for: handle, backend: backend)
        return handle
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else {
            return
        }
        hasDragged = false
        didBeginDrag = false
        dragAnchor = event.locationInWindow
        originalFrame = frame
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEnabled else {
            return
        }
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
        guard isEnabled else {
            return
        }
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

    private func updateAppearance() {
        if isSelected {
            backgroundColor = NSColor(calibratedRed: 0.70, green: 0.80, blue: 0.94, alpha: 1.0)
            return
        }

        switch style {
        case .toolbar:
            backgroundColor = nil
        case .palette:
            backgroundColor = NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.97, alpha: 1.0)
        case .defaultSet:
            backgroundColor = NSColor(calibratedRed: 0.95, green: 0.96, blue: 0.98, alpha: 1.0)
        case .preview:
            backgroundColor = NSColor(calibratedRed: 0.84, green: 0.89, blue: 0.96, alpha: 1.0)
        }
    }

    private var nativeText: String {
        "\(title)\n\(imageName)"
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
        backgroundColor = NSColor(calibratedRed: 0.84, green: 0.84, blue: 0.80, alpha: 1.0)
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
    }

    private func addRenderedSubview(_ view: NSView) {
        addSubview(view)
        applyRealizedTransparentBackground(to: view)
        renderedItemViews.append(view)
    }

    private func applyToolbarControlAppearance(to view: NSView) {
        view.backgroundColor = nil

        if let textField = view as? NSTextField {
            textField.isBordered = false
            textField.drawsBackground = false
        }
    }

    private func applyRealizedToolbarControlAppearance(to view: NSView) {
        guard let nativeHandle = view.nativeHandle, let backend = view.realizedBackend else {
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

    private func itemLayout(for toolbar: NSToolbar) -> [RenderedItemLayout] {
        let flexibleCount = toolbar.items.filter { $0.itemIdentifier == .flexibleSpace }.count
        let fixedWidth = toolbar.items.reduce(CGFloat(0)) { width, item in
            if item.itemIdentifier == .flexibleSpace {
                return width
            }
            return width + displayWidth(for: item, in: toolbar)
        }
        let fixedSpacing = max(CGFloat(toolbar.items.count - 1), 0) * itemSpacing
        let availableFlexibleWidth = max(24, frame.size.width - (leadingPadding * 2) - fixedWidth - fixedSpacing)
        let flexibleWidth = flexibleCount > 0 ? max(24, availableFlexibleWidth / CGFloat(flexibleCount)) : 24
        var x = leadingPadding
        var layout: [RenderedItemLayout] = []

        for item in toolbar.items {
            let width = item.itemIdentifier == .flexibleSpace ? flexibleWidth : displayWidth(for: item, in: toolbar)
            let height = displayHeight(for: item)
            let y = max((frame.size.height - height) / 2, 0)
            let itemFrame = NSMakeRect(x, y, width, height)

            if let view = item.view {
                layout.append(RenderedItemLayout(kind: .custom(item, view), frame: itemFrame))
            } else if item.itemIdentifier == .separator {
                layout.append(RenderedItemLayout(kind: .separator, frame: NSMakeRect(x + ((width - 2) / 2), 8, 2, max(frame.size.height - 16, 8))))
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
        if item.itemIdentifier == .separator || item.itemIdentifier == .space {
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

/// Separator line used by composed toolbar rendering.
open class NSToolbarSeparatorView: NSView {
    /// Creates a separator view.
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        backgroundColor = nil
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
