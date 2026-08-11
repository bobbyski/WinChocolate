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
/// Appearance-aware colors for the customization sheet. The panel is
/// framework-drawn with fixed light colors historically; these resolve a dark
/// variant under a dark appearance so the sheet matches the rest of the app
/// (plan 8.5). Item labels use the dynamic `.textColor`, so darkening the
/// backgrounds keeps them legible without per-label changes.
enum WinCustomizeColors {
    static var isDark: Bool { NSApplication.shared.effectiveAppearance.winIsDark }
    internal static func pick(_ light: NSColor, _ dark: NSColor) -> NSColor { isDark ? dark : light }

    static var content: NSColor { pick(NSColor(calibratedRed: 0.93, green: 0.93, blue: 0.93, alpha: 1), NSColor(white: 0.15, alpha: 1)) }
    static var palette: NSColor { pick(NSColor(calibratedRed: 0.97, green: 0.97, blue: 0.96, alpha: 1), NSColor(white: 0.12, alpha: 1)) }
    static var stripEdge: NSColor { pick(NSColor(calibratedRed: 0.62, green: 0.62, blue: 0.60, alpha: 1), NSColor(white: 0.30, alpha: 1)) }
    static var divider: NSColor { pick(NSColor(calibratedRed: 0.78, green: 0.78, blue: 0.78, alpha: 1), NSColor(white: 0.28, alpha: 1)) }
    static var tileEnabled: NSColor { pick(NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.97, alpha: 1), NSColor(white: 0.20, alpha: 1)) }
    static var tileDisabled: NSColor { pick(NSColor(calibratedRed: 0.90, green: 0.90, blue: 0.89, alpha: 1), NSColor(white: 0.14, alpha: 1)) }
    static var tileDefaultSet: NSColor { pick(NSColor(calibratedRed: 0.95, green: 0.96, blue: 0.98, alpha: 1), NSColor(calibratedRed: 0.18, green: 0.20, blue: 0.24, alpha: 1)) }
    static var tileSelected: NSColor { pick(NSColor(calibratedRed: 0.84, green: 0.89, blue: 0.96, alpha: 1), NSColor(calibratedRed: 0.18, green: 0.32, blue: 0.50, alpha: 1)) }
    static var removeTint: NSColor { pick(NSColor(calibratedRed: 0.96, green: 0.85, blue: 0.84, alpha: 1), NSColor(calibratedRed: 0.42, green: 0.20, blue: 0.20, alpha: 1)) }
    static var tileTextEnabled: NSColor { pick(NSColor(calibratedRed: 0.08, green: 0.10, blue: 0.12, alpha: 1), NSColor(white: 0.92, alpha: 1)) }
    static var tileTextDisabled: NSColor { pick(NSColor(calibratedRed: 0.42, green: 0.44, blue: 0.46, alpha: 1), NSColor(white: 0.50, alpha: 1)) }
}

internal final class NSToolbarCustomizationPanel: NSPanel {
    /// Marks the content view as the toolbar drop surface for tests.
    internal static let contentTag = 1_100

    /// Marks the palette container view for tests.
    internal static let paletteTag = 1_101

    /// Marks the default-set container view for tests.
    internal static let defaultStripTag = 1_102

    /// Marks the mirrored toolbar strip container for tests.
    internal static let stripTag = 1_103

    internal enum Metrics {
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

    internal enum DragSource {
        case palette(NSToolbarItem.Identifier)
        case defaultSet
        case toolbar(index: Int, identifier: NSToolbarItem.Identifier)
    }

    internal weak var customizedToolbar: NSToolbar?
    internal let content: NSView
    internal let strip: NSView
    internal let dragPreview: NSToolbarCustomizationTile
    /// The drop-position insertion bar shown while a drag hovers the strip.
    internal let insertionIndicator = NSView(frame: NSMakeRect(-10_000, -10_000, 3, 1))
    internal var stripTiles: [NSToolbarCustomizationTile] = []
    /// Palette tiles with their identifiers, for live enable/dim refresh.
    internal var paletteTiles: [(tile: NSToolbarCustomizationTile, identifier: NSToolbarItem.Identifier)] = []
    internal var dragSource: DragSource?
    /// The strip insertion index the indicator currently shows, so the drop
    /// lands exactly where the user saw it, or `nil` outside the strip.
    internal var pendingInsertionIndex: Int?

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

    internal func buildContent() {
        guard let toolbar = customizedToolbar else {
            return
        }

        let width = Metrics.contentSize.width
        let height = Metrics.contentSize.height
        content.tag = Self.contentTag
        content.winBackgroundColor = WinCustomizeColors.content

        strip.tag = Self.stripTag
        // Match the live toolbar, which blends with the window chrome.
        strip.winBackgroundColor = .windowBackgroundColor
        strip.autoresizingMask = [.width]
        content.addSubview(strip)

        let stripEdge = NSView(frame: NSMakeRect(0, Metrics.stripHeight, width, 1))
        stripEdge.winBackgroundColor = WinCustomizeColors.stripEdge
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
        divider.winBackgroundColor = WinCustomizeColors.divider
        divider.autoresizingMask = [.width, .minYMargin]
        content.addSubview(divider)

        buildBottomBar(for: toolbar, width: width, height: height)

        rebuildStripTiles()
        insertionIndicator.winBackgroundColor = NSColor(calibratedRed: 0.16, green: 0.45, blue: 0.85, alpha: 1.0)
        insertionIndicator.isHidden = true
        content.addSubview(insertionIndicator)
        dragPreview.style = .preview
        dragPreview.isHidden = true
        content.addSubview(dragPreview)
        contentView = content
    }

    internal func makeLabel(_ text: String, frame: NSRect) -> NSTextField {
        let label = NSTextField(string: text, frame: frame)
        label.isBordered = false
        label.drawsBackground = false
        label.autoresizingMask = [.width]
        return label
    }

    internal func buildPaletteView(for toolbar: NSToolbar, top: CGFloat, width: CGFloat) -> NSView {
        let identifiers = toolbar.customizationAllowedIdentifiers
        let columns = max(1, Int((width - 20 + (Metrics.paletteColumnPitch - Metrics.paletteTileSize.width)) / Metrics.paletteColumnPitch))
        let rows = max(1, (identifiers.count + columns - 1) / columns)
        let paletteHeight = CGFloat(rows) * Metrics.paletteRowPitch + 12

        let paletteView = NSView(frame: NSMakeRect(Metrics.margin, top, width, paletteHeight))
        paletteView.tag = Self.paletteTag
        paletteView.winBackgroundColor = WinCustomizeColors.palette
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
    internal func refreshPaletteEnabling() {
        guard let toolbar = customizedToolbar else {
            return
        }
        let present = Set(toolbar.items.map(\.itemIdentifier))
        for entry in paletteTiles {
            entry.tile.isEnabled = entry.identifier.allowsMultipleToolbarInstances
                || !present.contains(entry.identifier)
        }
    }

    internal func buildDefaultStrip(for toolbar: NSToolbar, top: CGFloat, width: CGFloat) -> NSView {
        let identifiers = toolbar.customizationDefaultIdentifiers
        let strip = NSView(frame: NSMakeRect(Metrics.margin, top, width, Metrics.stripHeight))
        strip.tag = Self.defaultStripTag
        strip.winBackgroundColor = WinCustomizeColors.palette
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

    internal func buildBottomBar(for toolbar: NSToolbar, width: CGFloat, height: CGFloat) {
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
        displayModePopup.winInternalAction = { [weak self] control in
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
        doneButton.winInternalAction = { [weak self] _ in
            self?.close()
        }
        content.addSubview(doneButton)
    }

    // MARK: - Mirrored toolbar strip

    internal func rebuildStripTiles() {
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
}
