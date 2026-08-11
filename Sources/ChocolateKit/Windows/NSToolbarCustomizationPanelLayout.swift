internal extension NSToolbarCustomizationPanel {
    func stripTileWidths(for toolbar: NSToolbar) -> [CGFloat] {
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

    func wireDragHandlers(for tile: NSToolbarCustomizationTile, source: DragSource) {
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

    func moveDragPreview(for tile: NSToolbarCustomizationTile, frame: NSRect) -> Bool {
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

        // Removal affordance: dragging a strip item outside the strip tints
        // the preview toward the removal state (dropping there removes it).
        if case .toolbar = dragSource {
            dragPreview.winBackgroundColor = pendingInsertionIndex == nil
                ? WinCustomizeColors.removeTint
                : WinCustomizeColors.tileSelected
        }
        return true
    }

    func hideDragPreview() {
        dragPreview.isHidden = true
        dragPreview.frame = NSMakeRect(-10_000, -10_000, 1, 1)
        insertionIndicator.isHidden = true
        insertionIndicator.frame = NSMakeRect(-10_000, -10_000, 3, 1)
    }

    /// The x of the insertion bar for a strip insertion index.
    func insertionIndicatorX(forIndex index: Int) -> CGFloat {
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

    func finishDrag(from tile: NSToolbarCustomizationTile, event: NSEvent) {
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
    func stripInsertionIndex(for event: NSEvent) -> Int? {
        stripInsertionIndex(forContentPoint: content.convert(event.locationInWindow, from: nil))
    }

    /// Returns the strip insertion index for a content-space point, or `nil`
    /// when the point is outside the strip zone.
    func stripInsertionIndex(forContentPoint point: NSPoint) -> Int? {
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

    func insertIdentifier(_ identifier: NSToolbarItem.Identifier, at insertionIndex: Int) {
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

    func removeItem(at index: Int) {
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

    func moveItem(from currentIndex: Int, to insertionIndex: Int) {
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

    func tileWidth(for title: String) -> CGFloat {
        max(64, min(112, CGFloat(title.count * 7 + 24)))
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

        let item = customizedToolbar?.itemForCustomizationIdentifier(identifier, willBeInsertedIntoToolbar: false)
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

        let item = customizedToolbar?.itemForCustomizationIdentifier(identifier, willBeInsertedIntoToolbar: false)
        if let imageName = item?.image?.name, !imageName.isEmpty {
            return imageName
        }

        let key = "\(identifier.rawValue) \(item?.label ?? "") \(item?.paletteLabel ?? "")".lowercased()
        if key.contains("open") || key.contains("folder") { return "folder" }
        if key.contains("disable") && key.contains("save") { return "properties" }
        if key.contains("save") { return "save" }
        if key.contains("print") { return "print" }
        if key.contains("custom") || key.contains("setting") || key.contains("gear") { return "properties" }
        if key.contains("delete") || key.contains("remove") || key.contains("trash") { return "trash" }
        if key.contains("search") || key.contains("find") { return "search" }
        if key.contains("new") || key.contains("add") { return "plus" }
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
    internal var hasDragged = false
    internal var didBeginDrag = false
    internal var dragAnchor: NSPoint?
    internal var originalFrame: NSRect?

    internal convenience init(title: String, frame frameRect: NSRect) {
        self.init(title: title, imageName: "document", frame: frameRect)
    }

    internal init(title: String, imageName: String, frame frameRect: NSRect) {
        self.title = title
        self.imageName = imageName
        super.init(frame: frameRect)
        updateAppearance()
    }

    /// Inherited from `NSView.init(frame:)` being `required`. A tile always has
    /// a title, and it is never registered with a collection view, so the
    /// frame-only path is unsupported.
    internal required init(frame frameRect: NSRect) {
        fatalError("NSToolbarCustomizationTile requires init(title:imageName:frame:)")
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

    internal func dragFrame(for event: NSEvent) -> NSRect? {
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

    internal func updateAppearance() {
        switch style {
        case .toolbar:
            winBackgroundColor = nil
        case .palette:
            // Disabled palette tiles (item already in the toolbar) dim to a
            // flat gray, matching Apple's palette filtering.
            winBackgroundColor = isEnabled ? WinCustomizeColors.tileEnabled : WinCustomizeColors.tileDisabled
        case .defaultSet:
            winBackgroundColor = WinCustomizeColors.tileDefaultSet
        case .preview:
            winBackgroundColor = WinCustomizeColors.tileSelected
        }
    }

    internal var nativeText: String {
        "\(title)\n\(imageName)"
    }

    internal func updateNativeText() {
        guard let nativeHandle else {
            return
        }

        realizedBackend?.setText(nativeText, for: nativeHandle)
    }

    internal func updateNativeTextColor() {
        guard let nativeHandle, let realizedBackend else {
            return
        }

        updateNativeTextColor(for: nativeHandle, backend: realizedBackend)
    }

    internal func updateNativeTextColor(for handle: NativeHandle, backend: NativeControlBackend) {
        let color = isEnabled ? WinCustomizeColors.tileTextEnabled : WinCustomizeColors.tileTextDisabled
        backend.setTextColor(color, for: handle)
    }
}
