internal extension NSToolbarView {
    func rebuildItemViews(for toolbar: NSToolbar) {
        for renderedView in renderedItemViews {
            renderedView.removeFromSuperview()
        }
        renderedItemViews.removeAll()

        let layout = itemLayout(for: toolbar)
        for entry in layout {
            switch entry.kind {
            case .standard(let item):
                addStandardToolbarItem(item, itemFrame: entry.frame, toolbar: toolbar)
            case .custom(let item, let view):
                addCustomToolbarItem(item, view: view, itemFrame: entry.frame)
            case .separator:
                addToolbarSeparator(itemFrame: entry.frame)
            case .space:
                // Gaps host no child window at all: the strip surface (flat
                // background or gradient chrome) shows through directly in
                // every look — a child view would erase a flat patch over the
                // metallic gradient.
                break
            }
        }

        addOverflowChevron(for: toolbar)
        addBottomEdge()
    }

    func addStandardToolbarItem(_ item: NSToolbarItem, itemFrame: NSRect, toolbar: NSToolbar) {
        if let group = item as? NSToolbarItemGroup, !group.subitems.isEmpty {
            addToolbarItemGroup(group, itemFrame: itemFrame, toolbar: toolbar)
            return
        }
        if item.isBordered {
            let title = item.title.isEmpty ? item.label : item.title
            let button = NSButton(title: title, frame: itemFrame)
            button.isEnabled = item.isEnabled
            button.toolTip = item.toolTip
            button.winInternalAction = { [weak item] _ in item?.performAction() }
            addSubview(button)
            renderedItemViews.append(button)
            return
        }
        let compositeView = item.winCompositeView(
            showItem: toolbar.displayMode != .labelOnly,
            showLabel: toolbar.displayMode != .iconOnly,
            toolbarHeight: frame.size.height
        )
        compositeView.frame = itemFrame
        if toolbar.selectedItemIdentifier == item.itemIdentifier {
            compositeView.winBackgroundColor = NSColor(calibratedRed: 0.80, green: 0.84, blue: 0.90, alpha: 1.0)
        }
        if toolbar.winResolvedAppleLook == .metallic, let composite = compositeView as? NSToolbarCompositeItemView {
            composite.metallicSlice = (stripHeight: frame.size.height, y: itemFrame.origin.y)
        }
        addRenderedSubview(compositeView)
    }

    func addToolbarItemGroup(_ group: NSToolbarItemGroup, itemFrame: NSRect, toolbar: NSToolbar) {
        let subitemWidth = itemFrame.size.width / CGFloat(group.subitems.count)
        for (index, subitem) in group.subitems.enumerated() {
            let tile = subitem.winCompositeView(
                showItem: toolbar.displayMode != .labelOnly,
                showLabel: toolbar.displayMode != .iconOnly,
                toolbarHeight: frame.size.height
            )
            tile.frame = NSMakeRect(
                itemFrame.origin.x + CGFloat(index) * subitemWidth,
                itemFrame.origin.y,
                subitemWidth,
                itemFrame.size.height
            )
            if group.isSelected(at: index) {
                tile.winBackgroundColor = NSColor(calibratedRed: 0.80, green: 0.84, blue: 0.90, alpha: 1.0)
            }
            if toolbar.winResolvedAppleLook == .metallic, let composite = tile as? NSToolbarCompositeItemView {
                composite.metallicSlice = (stripHeight: frame.size.height, y: itemFrame.origin.y)
            }
            addRenderedSubview(tile)
        }
    }

    func addCustomToolbarItem(_ item: NSToolbarItem, view: NSView, itemFrame: NSRect) {
        applyToolbarControlAppearance(to: view)
        view.frame = itemFrame
        view.toolTip = item.toolTip ?? view.toolTip
        (view as? NSControl)?.isEnabled = item.isEnabled
        addRenderedSubview(view)
        applyRealizedToolbarControlAppearance(to: view)
    }

    func addToolbarSeparator(itemFrame: NSRect) {
        let separatorItem = NSToolbarItem(itemIdentifier: .separator)
        let separatorView = separatorItem.winCompositeView(
            showItem: true,
            showLabel: false,
            toolbarHeight: frame.size.height
        )
        separatorView.frame = itemFrame
        addRenderedSubview(separatorView)
    }

    func addOverflowChevron(for toolbar: NSToolbar) {
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
    }

    func addBottomEdge() {
        let bottomEdge = NSView(frame: NSMakeRect(0, max(frame.size.height - 1, 0), frame.size.width, 1))
        bottomEdge.winBackgroundColor = NSColor(calibratedRed: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
        bottomEdge.autoresizingMask = [.width]
        addSubview(bottomEdge)
        renderedItemViews.append(bottomEdge)
    }

    func addRenderedSubview(_ view: NSView) {
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

    func applyToolbarControlAppearance(to view: NSView) {
        view.winBackgroundColor = nil

        // Label-style text fields blend into the toolbar strip; editable
        // fields (search fields, text entries) keep their border and
        // background the way AppKit toolbar search fields do.
        if let textField = view as? NSTextField, !textField.isEditable {
            textField.isBordered = false
            textField.drawsBackground = false
        }
    }

    func applyRealizedToolbarControlAppearance(to view: NSView) {
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

    func applyRealizedTransparentBackground(to view: NSView) {
        guard let nativeHandle = view.nativeHandle, let backend = view.realizedBackend else {
            return
        }

        backend.setBackgroundColor(nil, for: nativeHandle)
        backend.setDrawsBackground(false, for: nativeHandle)
    }

    enum RenderedItemKind {
        case standard(NSToolbarItem)
        case custom(NSToolbarItem, NSView)
        case separator
        case space
    }

    struct RenderedItemLayout {
        var kind: RenderedItemKind
        var frame: NSRect
    }

    /// The strip items after priority-based overflow: when the natural widths
    /// exceed the strip, the lowest-`visibilityPriority` items (ties resolved
    /// from the trailing edge) collapse into the overflow menu, matching the
    /// Mac toolbar's narrow-window behavior.
    func stripItems(for toolbar: NSToolbar) -> [NSToolbarItem] {
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
    func overflowedItems(for toolbar: NSToolbar) -> [NSToolbarItem] {
        toolbar.items.filter { toolbar.winOverflowedItemIdentifiers.contains(ObjectIdentifier($0)) }
    }

    func itemLayout(for toolbar: NSToolbar) -> [RenderedItemLayout] {
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
    func applyCenteredItemLayout(
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

    func notifyPreferredHeightIfNeeded() {
        let height = preferredHeight
        guard lastPreferredHeight != height else {
            return
        }

        lastPreferredHeight = height
        preferredHeightChanged?(height)
    }

    func displayWidth(for item: NSToolbarItem, in toolbar: NSToolbar) -> CGFloat {
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
    func standardNaturalWidth(for item: NSToolbarItem, mode: NSToolbar.DisplayMode) -> CGFloat {
        let showsLabel = mode != .iconOnly
        let showsImage = mode != .labelOnly
        let iconWidth: CGFloat = showsImage && item.image != nil ? 24 : 0
        let labelWidth = showsLabel ? CGFloat(max(28, item.label.count * 6)) : 0
        return max(iconWidth, labelWidth) + 16
    }

    func displayHeight(for item: NSToolbarItem) -> CGFloat {
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
