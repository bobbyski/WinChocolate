/// The toolbar customization sheet.
///
/// Toolbars are the project's deliberate exception to the "look like Windows"
/// rule: the customization experience should follow Apple's sheet. This panel
/// mirrors the classic AppKit layout with one compromise - the top strip
/// mirrors the window toolbar because dragging into the real toolbar is not
/// implemented yet (plan item 6.13):
///
/// ```text
/// +-----------------------------------------------+
/// | mirrored toolbar strip (drop, reorder, remove)|
/// +-----------------------------------------------+
/// | Drag your favorite items into the toolbar...  |
/// | +-------------------------------------------+ |
/// | | palette grid of allowed items             | |
/// | +-------------------------------------------+ |
/// | ... or drag the default set into the toolbar. |
/// | +-------------------------------------------+ |
/// | | default item set                          | |
/// | +-------------------------------------------+ |
/// +-----------------------------------------------+
/// | Show [display mode]                  [ Done ] |
/// +-----------------------------------------------+
/// ```
///
/// All interactions are drag based, matching Apple: drag palette items into
/// the strip, drag strip items to reorder, drag them out to remove, and drag
/// the default set in to restore it.
internal final class NSToolbarCustomizationPanel: NSPanel {
    /// Marks the content view as the toolbar drop surface for tests.
    internal static let contentTag = 1_100

    /// Marks the palette container view for tests.
    internal static let paletteTag = 1_101

    /// Marks the default-set container view for tests.
    internal static let defaultStripTag = 1_102

    /// Marks the mirrored toolbar strip container for tests.
    internal static let stripTag = 1_103

    private enum Metrics {
        static let contentSize = NSMakeSize(760, 396)
        static let stripHeight: CGFloat = 52
        static let tileHeight: CGFloat = 36
        static let paletteTileSize = NSMakeSize(124, 40)
        static let paletteColumnPitch: CGFloat = 136
        static let paletteRowPitch: CGFloat = 48
        static let margin: CGFloat = 24
        static let stripSpacing: CGFloat = 6
        static let bottomBarHeight: CGFloat = 64
    }

    private enum DragSource {
        case palette(NSToolbarItem.Identifier)
        case defaultSet
        case toolbar(index: Int, identifier: NSToolbarItem.Identifier)
    }

    private weak var customizedToolbar: NSToolbar?
    private let content: NSView
    private let strip: NSView
    private let dragPreview: NSToolbarCustomizationTile
    /// The drop-position insertion bar shown while a drag hovers the strip.
    private let insertionIndicator = NSView(frame: NSMakeRect(-10_000, -10_000, 3, 1))
    private var stripTiles: [NSToolbarCustomizationTile] = []
    /// Palette tiles with their identifiers, for live enable/dim refresh.
    private var paletteTiles: [(tile: NSToolbarCustomizationTile, identifier: NSToolbarItem.Identifier)] = []
    private var dragSource: DragSource?
    /// The strip insertion index the indicator currently shows, so the drop
    /// lands exactly where the user saw it, or `nil` outside the strip.
    private var pendingInsertionIndex: Int?

    /// Creates and populates the customization panel for a toolbar.
    internal init(toolbar: NSToolbar) {
        self.customizedToolbar = toolbar
        self.content = NSView(frame: NSRect(origin: NSZeroPoint, size: Metrics.contentSize))
        self.strip = NSView(frame: NSMakeRect(0, 0, Metrics.contentSize.width, Metrics.stripHeight))
        self.dragPreview = NSToolbarCustomizationTile(title: "", frame: NSMakeRect(-10_000, -10_000, 1, 1))
        super.init(
            contentRect: NSRect(origin: NSMakePoint(180, 180), size: Metrics.contentSize),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        title = "Customize Toolbar"
        buildContent()
    }

    // MARK: - Content construction

    private func buildContent() {
        guard let toolbar = customizedToolbar else {
            return
        }

        let width = Metrics.contentSize.width
        let height = Metrics.contentSize.height
        content.tag = Self.contentTag
        content.backgroundColor = NSColor(calibratedRed: 0.93, green: 0.93, blue: 0.93, alpha: 1.0)

        strip.tag = Self.stripTag
        // Match the live toolbar, which blends with the window chrome.
        strip.backgroundColor = .windowBackgroundColor
        strip.autoresizingMask = [.width]
        content.addSubview(strip)

        let stripEdge = NSView(frame: NSMakeRect(0, Metrics.stripHeight, width, 1))
        stripEdge.backgroundColor = NSColor(calibratedRed: 0.62, green: 0.62, blue: 0.60, alpha: 1.0)
        stripEdge.autoresizingMask = [.width]
        content.addSubview(stripEdge)

        let instructionLabel = makeLabel("Drag your favorite items into the toolbar...", frame: NSMakeRect(Metrics.margin, 66, width - Metrics.margin * 2, 20))
        content.addSubview(instructionLabel)

        let paletteView = buildPaletteView(for: toolbar, top: 92, width: width - Metrics.margin * 2)
        content.addSubview(paletteView)

        let defaultLabelTop = paletteView.frame.origin.y + paletteView.frame.size.height + 12
        let defaultLabel = makeLabel("... or drag the default set into the toolbar.", frame: NSMakeRect(Metrics.margin, defaultLabelTop, width - Metrics.margin * 2, 20))
        content.addSubview(defaultLabel)

        let defaultStrip = buildDefaultStrip(for: toolbar, top: defaultLabelTop + 26, width: width - Metrics.margin * 2)
        content.addSubview(defaultStrip)

        let divider = NSView(frame: NSMakeRect(0, height - Metrics.bottomBarHeight, width, 1))
        divider.backgroundColor = NSColor(calibratedRed: 0.78, green: 0.78, blue: 0.78, alpha: 1.0)
        divider.autoresizingMask = [.width, .minYMargin]
        content.addSubview(divider)

        buildBottomBar(for: toolbar, width: width, height: height)

        rebuildStripTiles()
        insertionIndicator.backgroundColor = NSColor(calibratedRed: 0.16, green: 0.45, blue: 0.85, alpha: 1.0)
        insertionIndicator.isHidden = true
        content.addSubview(insertionIndicator)
        dragPreview.style = .preview
        dragPreview.isHidden = true
        content.addSubview(dragPreview)
        contentView = content
    }

    private func makeLabel(_ text: String, frame: NSRect) -> NSTextField {
        let label = NSTextField(string: text, frame: frame)
        label.isBordered = false
        label.drawsBackground = false
        label.autoresizingMask = [.width]
        return label
    }

    private func buildPaletteView(for toolbar: NSToolbar, top: CGFloat, width: CGFloat) -> NSView {
        let identifiers = toolbar.customizationAllowedIdentifiers
        let columns = max(1, Int((width - 20 + (Metrics.paletteColumnPitch - Metrics.paletteTileSize.width)) / Metrics.paletteColumnPitch))
        let rows = max(1, (identifiers.count + columns - 1) / columns)
        let paletteHeight = CGFloat(rows) * Metrics.paletteRowPitch + 12

        let paletteView = NSView(frame: NSMakeRect(Metrics.margin, top, width, paletteHeight))
        paletteView.tag = Self.paletteTag
        paletteView.backgroundColor = NSColor(calibratedRed: 0.97, green: 0.97, blue: 0.96, alpha: 1.0)
        paletteView.autoresizingMask = [.width]

        for (index, identifier) in identifiers.enumerated() {
            let column = index % columns
            let row = index / columns
            let tile = NSToolbarCustomizationTile(
                title: title(for: identifier),
                imageName: imageName(for: identifier),
                frame: NSMakeRect(
                    10 + CGFloat(column) * Metrics.paletteColumnPitch,
                    6 + CGFloat(row) * Metrics.paletteRowPitch,
                    Metrics.paletteTileSize.width,
                    Metrics.paletteTileSize.height
                )
            )
            tile.style = .palette
            tile.toolTip = "Drag into the toolbar."
            wireDragHandlers(for: tile, source: .palette(identifier))
            paletteView.addSubview(tile)
            paletteTiles.append((tile: tile, identifier: identifier))
        }
        refreshPaletteEnabling()

        return paletteView
    }

    /// Dims palette tiles whose items are already in the toolbar and can't be
    /// duplicated, matching Apple's palette filtering; duplicable structural
    /// items (space/flexible space/separator) stay draggable.
    private func refreshPaletteEnabling() {
        guard let toolbar = customizedToolbar else {
            return
        }
        let present = Set(toolbar.items.map(\.itemIdentifier))
        for entry in paletteTiles {
            entry.tile.isEnabled = entry.identifier.allowsMultipleToolbarInstances
                || !present.contains(entry.identifier)
        }
    }

    private func buildDefaultStrip(for toolbar: NSToolbar, top: CGFloat, width: CGFloat) -> NSView {
        let identifiers = toolbar.customizationDefaultIdentifiers
        let strip = NSView(frame: NSMakeRect(Metrics.margin, top, width, Metrics.stripHeight))
        strip.tag = Self.defaultStripTag
        strip.backgroundColor = NSColor(calibratedRed: 0.97, green: 0.97, blue: 0.96, alpha: 1.0)
        strip.autoresizingMask = [.width]

        // Cap tile widths so the whole default set fits inside the strip;
        // labels ellipsize when the natural widths would overflow.
        let naturalWidths = identifiers.map { tileWidth(for: title(for: $0)) }
        let spacingTotal = CGFloat(max(identifiers.count - 1, 0)) * Metrics.stripSpacing
        let availableWidth = width - 20 - spacingTotal
        let naturalTotal = naturalWidths.reduce(0, +)
        let equalShare = identifiers.isEmpty ? availableWidth : availableWidth / CGFloat(identifiers.count)

        var x: CGFloat = 10
        for (index, identifier) in identifiers.enumerated() {
            let tileWidth = naturalTotal <= availableWidth
                ? naturalWidths[index]
                : max(48, min(naturalWidths[index], equalShare))
            let tile = NSToolbarCustomizationTile(
                title: title(for: identifier),
                imageName: imageName(for: identifier),
                frame: NSMakeRect(x, 6, tileWidth, Metrics.paletteTileSize.height)
            )
            tile.style = .defaultSet
            tile.toolTip = "Drag to restore the default toolbar."
            wireDragHandlers(for: tile, source: .defaultSet)
            strip.addSubview(tile)
            x += tileWidth + Metrics.stripSpacing
        }

        return strip
    }

    private func buildBottomBar(for toolbar: NSToolbar, width: CGFloat, height: CGFloat) {
        let showLabel = makeLabel("Show", frame: NSMakeRect(Metrics.margin, height - 44, 44, 22))
        showLabel.autoresizingMask = [.minYMargin]
        content.addSubview(showLabel)

        let displayModePopup = NSPopUpButton(frame: NSMakeRect(Metrics.margin + 46, height - 48, 160, 26), pullsDown: false)
        displayModePopup.autoresizingMask = [.minYMargin]
        displayModePopup.addItems(withTitles: ["Icon & Label", "Icon Only", "Label Only"])
        switch toolbar.displayMode {
        case .default, .iconAndLabel:
            displayModePopup.selectItem(at: 0)
        case .iconOnly:
            displayModePopup.selectItem(at: 1)
        case .labelOnly:
            displayModePopup.selectItem(at: 2)
        }
        displayModePopup.onAction = { [weak self] control in
            guard let popup = control as? NSPopUpButton else {
                return
            }

            switch popup.indexOfSelectedItem {
            case 1:
                self?.customizedToolbar?.displayMode = .iconOnly
            case 2:
                self?.customizedToolbar?.displayMode = .labelOnly
            default:
                self?.customizedToolbar?.displayMode = .iconAndLabel
            }
        }
        content.addSubview(displayModePopup)

        let doneButton = NSButton(title: "Done", frame: NSMakeRect(width - Metrics.margin - 90, height - 48, 90, 28))
        doneButton.autoresizingMask = [.minXMargin, .minYMargin]
        doneButton.onAction = { [weak self] _ in
            self?.close()
        }
        content.addSubview(doneButton)
    }

    // MARK: - Mirrored toolbar strip

    private func rebuildStripTiles() {
        guard let toolbar = customizedToolbar else {
            return
        }

        for tile in stripTiles {
            tile.removeFromSuperview()
        }
        stripTiles.removeAll()

        let widths = stripTileWidths(for: toolbar)
        var x: CGFloat = 8
        for (index, item) in toolbar.items.enumerated() {
            let identifier = item.itemIdentifier
            let tile = NSToolbarCustomizationTile(
                title: title(for: identifier, prefersPaletteLabel: false),
                imageName: imageName(for: identifier),
                frame: NSMakeRect(x, 8, widths[index], Metrics.tileHeight)
            )
            tile.style = .toolbar
            tile.toolTip = "Drag to reorder or drag out to remove."
            wireDragHandlers(for: tile, source: .toolbar(index: index, identifier: identifier))
            strip.addSubview(tile)
            stripTiles.append(tile)
            x += widths[index] + Metrics.stripSpacing
        }

        // Keep the indicator and drag preview above freshly created strip tiles.
        if insertionIndicator.superview === content {
            insertionIndicator.removeFromSuperview()
            content.addSubview(insertionIndicator)
        }
        if dragPreview.superview === content {
            dragPreview.removeFromSuperview()
            content.addSubview(dragPreview)
        }
        refreshPaletteEnabling()
    }

    /// Returns strip tile widths, capped so the whole set fits the strip.
    private func stripTileWidths(for toolbar: NSToolbar) -> [CGFloat] {
        let naturalWidths = toolbar.items.map { tileWidth(for: title(for: $0.itemIdentifier, prefersPaletteLabel: false)) }
        guard !naturalWidths.isEmpty else {
            return naturalWidths
        }

        let spacingTotal = CGFloat(naturalWidths.count - 1) * Metrics.stripSpacing
        let availableWidth = content.frame.size.width - 16 - spacingTotal
        guard naturalWidths.reduce(0, +) > availableWidth else {
            return naturalWidths
        }

        let equalShare = availableWidth / CGFloat(naturalWidths.count)
        return naturalWidths.map { max(48, min($0, equalShare)) }
    }

    // MARK: - Drag handling

    private func wireDragHandlers(for tile: NSToolbarCustomizationTile, source: DragSource) {
        tile.onBeginDrag = { [weak self] in
            self?.dragSource = source
        }
        tile.onDragFrameChanged = { [weak self] tile, frame in
            self?.moveDragPreview(for: tile, frame: frame) ?? false
        }
        tile.onDrop = { [weak self] tile, event in
            self?.finishDrag(from: tile, event: event)
        }
        tile.onEndDrag = { [weak self] in
            self?.hideDragPreview()
        }
    }

    private func moveDragPreview(for tile: NSToolbarCustomizationTile, frame: NSRect) -> Bool {
        guard let parent = tile.superview else {
            return false
        }

        let origin = content.convert(frame.origin, from: parent)
        dragPreview.title = tile.title
        dragPreview.imageName = tile.imageName
        dragPreview.frame = NSRect(origin: origin, size: frame.size)
        dragPreview.isHidden = false

        // Track the drop position: while the drag hovers the strip, show the
        // insertion bar at the prospective boundary (and remember it so the
        // drop lands exactly where the user saw it).
        let dragCenter = NSMakePoint(origin.x + frame.size.width / 2, origin.y + frame.size.height / 2)
        pendingInsertionIndex = stripInsertionIndex(forContentPoint: dragCenter)
        if let index = pendingInsertionIndex {
            insertionIndicator.frame = NSMakeRect(insertionIndicatorX(forIndex: index), 6, 3, Metrics.stripHeight - 12)
            insertionIndicator.isHidden = false
        } else {
            insertionIndicator.isHidden = true
        }
        return true
    }

    private func hideDragPreview() {
        dragPreview.isHidden = true
        dragPreview.frame = NSMakeRect(-10_000, -10_000, 1, 1)
        insertionIndicator.isHidden = true
        insertionIndicator.frame = NSMakeRect(-10_000, -10_000, 3, 1)
    }

    /// The x of the insertion bar for a strip insertion index.
    private func insertionIndicatorX(forIndex index: Int) -> CGFloat {
        guard let toolbar = customizedToolbar else {
            return 8
        }
        let widths = stripTileWidths(for: toolbar)
        var x: CGFloat = 8
        for (tileIndex, width) in widths.enumerated() {
            if tileIndex == index {
                break
            }
            x += width + Metrics.stripSpacing
        }
        return max(2, x - (Metrics.stripSpacing / 2) - 1)
    }

    private func finishDrag(from tile: NSToolbarCustomizationTile, event: NSEvent) {
        defer {
            dragSource = nil
            pendingInsertionIndex = nil
        }
        guard let source = dragSource else {
            return
        }

        // Drop where the insertion indicator showed (WYSIWYG); fall back to
        // the raw drop location if no preview frame ever tracked.
        let insertionIndex = pendingInsertionIndex ?? stripInsertionIndex(for: event)
        switch source {
        case .palette(let identifier):
            guard let insertionIndex else {
                return
            }
            insertIdentifier(identifier, at: insertionIndex)
        case .defaultSet:
            guard insertionIndex != nil else {
                return
            }
            customizedToolbar?.resetVisibleItemsToDefault()
            rebuildStripTiles()
        case .toolbar(let index, _):
            if let insertionIndex {
                moveItem(from: index, to: insertionIndex)
            } else {
                removeItem(at: index)
            }
        }
    }

    /// Returns the strip insertion index for a drop event, or `nil` outside the strip.
    private func stripInsertionIndex(for event: NSEvent) -> Int? {
        stripInsertionIndex(forContentPoint: content.convert(event.locationInWindow, from: nil))
    }

    /// Returns the strip insertion index for a content-space point, or `nil`
    /// when the point is outside the strip zone.
    private func stripInsertionIndex(forContentPoint point: NSPoint) -> Int? {
        guard let toolbar = customizedToolbar else {
            return nil
        }

        let stripFrame = NSMakeRect(0, 0, content.frame.size.width, Metrics.stripHeight + 6)
        guard NSPointInRect(point, stripFrame) else {
            return nil
        }

        let widths = stripTileWidths(for: toolbar)
        var x: CGFloat = 8
        for (index, width) in widths.enumerated() {
            if point.x < x + (width / 2) {
                return index
            }
            x += width + Metrics.stripSpacing
        }
        return toolbar.items.count
    }

    // MARK: - Toolbar mutations

    private func insertIdentifier(_ identifier: NSToolbarItem.Identifier, at insertionIndex: Int) {
        guard let toolbar = customizedToolbar else {
            return
        }

        var identifiers = toolbar.items.map(\.itemIdentifier)
        if !identifier.allowsMultipleToolbarInstances && identifiers.contains(identifier) {
            rebuildStripTiles()
            return
        }

        let destination = min(max(insertionIndex, 0), identifiers.count)
        identifiers.insert(identifier, at: destination)
        toolbar.setVisibleItemIdentifiers(identifiers)
        rebuildStripTiles()
    }

    private func removeItem(at index: Int) {
        guard let toolbar = customizedToolbar else {
            return
        }

        var identifiers = toolbar.items.map(\.itemIdentifier)
        guard identifiers.indices.contains(index) else {
            return
        }

        identifiers.remove(at: index)
        toolbar.setVisibleItemIdentifiers(identifiers)
        rebuildStripTiles()
    }

    private func moveItem(from currentIndex: Int, to insertionIndex: Int) {
        guard let toolbar = customizedToolbar else {
            return
        }

        var identifiers = toolbar.items.map(\.itemIdentifier)
        guard identifiers.indices.contains(currentIndex) else {
            return
        }

        let identifier = identifiers.remove(at: currentIndex)
        var destination = insertionIndex
        if currentIndex < insertionIndex {
            destination -= 1
        }
        destination = min(max(destination, 0), identifiers.count)
        identifiers.insert(identifier, at: destination)
        toolbar.setVisibleItemIdentifiers(identifiers)
        rebuildStripTiles()
    }

    // MARK: - Item presentation

    private func tileWidth(for title: String) -> CGFloat {
        max(64, min(112, CGFloat(title.count * 7 + 24)))
    }

    private func title(for identifier: NSToolbarItem.Identifier, prefersPaletteLabel: Bool = true) -> String {
        if identifier == .flexibleSpace {
            return "Flexible Space"
        }
        if identifier == .separator {
            return "Separator"
        }
        if identifier == .space {
            return "Space"
        }

        let item = customizedToolbar?.itemForCustomizationIdentifier(identifier, willBeInsertedIntoToolbar: false)
        if prefersPaletteLabel, let item, item.paletteLabel != identifier.rawValue {
            return item.paletteLabel
        }
        return item?.label ?? identifier.rawValue
    }

    private func imageName(for identifier: NSToolbarItem.Identifier) -> String {
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

        let item = customizedToolbar?.itemForCustomizationIdentifier(identifier, willBeInsertedIntoToolbar: false)
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
}

/// A draggable icon-and-label tile used by the toolbar customization panel.
internal final class NSToolbarCustomizationTile: NSView {
    /// Visual role of a tile inside the customization panel.
    internal enum Style {
        case toolbar
        case palette
        case defaultSet
        case preview
    }

    internal var title: String {
        didSet {
            updateNativeText()
        }
    }

    internal var imageName: String {
        didSet {
            updateNativeText()
        }
    }

    internal var style: Style = .palette {
        didSet {
            updateAppearance()
        }
    }

    internal var isEnabled = true {
        didSet {
            updateAppearance()
            updateNativeTextColor()
        }
    }

    internal var onBeginDrag: (() -> Void)?
    internal var onDrop: ((NSToolbarCustomizationTile, NSEvent) -> Void)?
    internal var onDragFrameChanged: ((NSToolbarCustomizationTile, NSRect) -> Bool)?
    internal var onEndDrag: (() -> Void)?
    private var hasDragged = false
    private var didBeginDrag = false
    private var dragAnchor: NSPoint?
    private var originalFrame: NSRect?

    internal convenience init(title: String, frame frameRect: NSRect) {
        self.init(title: title, imageName: "document", frame: frameRect)
    }

    internal init(title: String, imageName: String, frame frameRect: NSRect) {
        self.title = title
        self.imageName = imageName
        super.init(frame: frameRect)
        updateAppearance()
    }

    internal override var acceptsFirstResponder: Bool {
        false
    }

    internal override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = backend.createView(frame: frame, parent: parent)
        backend.setText(nativeText, for: handle)
        updateNativeTextColor(for: handle, backend: backend)
        return handle
    }

    internal override func mouseDown(with event: NSEvent) {
        guard isEnabled else {
            return
        }
        hasDragged = false
        didBeginDrag = false
        dragAnchor = event.locationInWindow
        originalFrame = frame
    }

    internal override func mouseDragged(with event: NSEvent) {
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

    internal override func mouseUp(with event: NSEvent) {
        guard isEnabled else {
            return
        }
        if hasDragged {
            onDrop?(self, event)
            onEndDrag?()
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
        switch style {
        case .toolbar:
            backgroundColor = nil
        case .palette:
            // Disabled palette tiles (item already in the toolbar) dim to a
            // flat gray, matching Apple's palette filtering.
            backgroundColor = isEnabled
                ? NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.97, alpha: 1.0)
                : NSColor(calibratedRed: 0.90, green: 0.90, blue: 0.89, alpha: 1.0)
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
