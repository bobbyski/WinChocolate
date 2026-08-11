import WinChocolate

@MainActor
func testToolbarStandardItemIdentifiers() {
    let toolbar = NSToolbar(identifier: "standard")
    // No delegate: standard Apple identifiers synthesize their built-in items.
    toolbar.setVisibleItemIdentifiers([.showColors, .showFonts, .print, .customizeToolbar])
    let labels = toolbar.items.map(\.label)
    expect(labels == ["Colors", "Fonts", "Print", "Customize"],
           "Standard toolbar identifiers did not synthesize Mac-labeled items. Got \(labels).")
    expect(toolbar.item(withIdentifier: .showColors)?.paletteLabel == "Colors",
           "Standard item palette label was not set.")
}

final class AutosaveToolbarDelegate: NSObject, NSToolbarDelegate {
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [NSToolbarItem.Identifier("a"), NSToolbarItem.Identifier("b")]
    }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [NSToolbarItem.Identifier("a"), NSToolbarItem.Identifier("b")]
    }
    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        NSToolbarItem(itemIdentifier: itemIdentifier)
    }
}

@MainActor
func testToolbarAutosaveRoundTripsConfiguration() {
    let autosaveKey = "NSToolbar Configuration WinChocolateAutosaveTest"
    UserDefaults.standard.removeObject(forKey: autosaveKey)
    let delegate = AutosaveToolbarDelegate()

    // Customize a toolbar with autosave on: the configuration lands in defaults
    // under AppKit's key with AppKit's dictionary shape.
    let toolbar = NSToolbar(identifier: "WinChocolateAutosaveTest")
    toolbar.delegate = delegate
    toolbar.autosavesConfiguration = true
    toolbar.displayMode = .iconOnly
    toolbar.setVisibleItemIdentifiers([NSToolbarItem.Identifier("b")])
    let saved = UserDefaults.standard.dictionary(forKey: autosaveKey)
    expect((saved?["TB Item Identifiers"] as? [Any])?.compactMap { $0 as? String } == ["b"],
           "Autosave did not persist the visible identifiers. Got \(String(describing: saved)).")
    expect((saved?["TB Display Mode"] as? Int) == 2, "Autosave did not persist the display mode.")

    // A fresh toolbar with the same identifier restores on window attach.
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 320, 200),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: InMemoryNativeControlBackend()
    )
    let restored = NSToolbar(identifier: "WinChocolateAutosaveTest")
    restored.delegate = delegate
    restored.setVisibleItemIdentifiers([NSToolbarItem.Identifier("a"), NSToolbarItem.Identifier("b")])
    restored.autosavesConfiguration = true
    window.toolbar = restored
    expect(restored.items.map(\.itemIdentifier) == [NSToolbarItem.Identifier("b")],
           "Attaching did not restore the autosaved item set. Got \(restored.items.map(\.itemIdentifier)).")
    expect(restored.displayMode == .iconOnly, "Attaching did not restore the autosaved display mode.")

    UserDefaults.standard.removeObject(forKey: autosaveKey)
}

@MainActor
func testToolbarBorderedItemRendersAsButton() {
    let backend = InMemoryNativeControlBackend()
    let toolbar = NSToolbar(identifier: "bordered")
    let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("run"))
    item.label = "Run"
    item.title = "Run Task"
    item.isBordered = true
    var fired = 0
    item.onAction = { _ in fired += 1 }
    toolbar.addItem(item)

    let toolbarView = NSToolbarView(frame: NSMakeRect(0, 0, 300, 40))
    toolbarView.toolbar = toolbar
    _ = toolbarView.realizeNativePeer(in: backend, parent: nil)

    // The bordered item renders as a real button carrying the title, and
    // clicking it performs the item's action.
    guard let button = toolbarView.subviews.compactMap({ $0 as? NSButton }).first else {
        expect(false, "A bordered toolbar item did not render as a button.")
        return
    }
    expect(button.title == "Run Task", "The bordered item button did not carry the item title. Got \(button.title).")
    button.sendAction()
    expect(fired == 1, "Clicking the bordered item button did not perform the item action.")
}

@MainActor
func testToolbarCustomizationPaletteDimsInToolbarItems() {
    clearApplicationWindows()

    let toolbar = NSToolbar(identifier: "dimming")
    let openItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("open"))
    openItem.label = "Open"
    toolbar.allowsUserCustomization = true
    toolbar.addItem(openItem)

    let delegate = DimmingToolbarDelegate()
    toolbar.delegate = delegate

    toolbar.runCustomizationPalette(nil)
    guard let panel = NSApplication.shared.windows.compactMap({ $0 as? NSPanel }).last,
          let contentView = panel.contentView else {
        expect(false, "Toolbar customization palette did not create a panel.")
        return
    }

    // Palette tiles in allowed-identifier order: [open, flexibleSpace].
    let dimFill = NSColor(calibratedRed: 0.90, green: 0.90, blue: 0.89, alpha: 1.0)
    let palette = contentView.subviews.first { $0.tag == 1_101 }
    let paletteTiles = (palette?.subviews ?? [])
        .filter { $0.toolTip == "Drag into the toolbar." }
        .sorted { $0.frame.origin.x < $1.frame.origin.x }
    guard paletteTiles.count == 2 else {
        expect(false, "The palette did not build a tile per allowed identifier. Got \(paletteTiles.count).")
        return
    }

    // "Open" is in the toolbar and can't be duplicated → dimmed in the palette;
    // "Flexible Space" is structural (duplicable) → stays enabled.
    expect(paletteTiles[0].winBackgroundColor == dimFill,
           "The palette tile for an in-toolbar item was not dimmed.")
    expect(paletteTiles[1].winBackgroundColor != dimFill,
           "A duplicable structural palette tile was dimmed.")

    // A dimmed tile refuses drags: dragging "Open" into the strip changes nothing.
    let dimStart = paletteTiles[0].convert(NSMakePoint(10, 10), to: nil)
    let stripPoint = contentView.convert(NSMakePoint(30, 20), to: nil)
    paletteTiles[0].mouseDown(with: NSEvent(type: .leftMouseDown, locationInWindow: dimStart))
    paletteTiles[0].mouseDragged(with: NSEvent(type: .leftMouseDragged, locationInWindow: stripPoint))
    paletteTiles[0].mouseUp(with: NSEvent(type: .leftMouseUp, locationInWindow: stripPoint))
    expect(toolbar.items.map(\.itemIdentifier) == [NSToolbarItem.Identifier("open")], "A dimmed palette tile still mutated the toolbar.")

    // Drag "Open" out of the mirrored strip (removal) → the palette tile
    // re-enables live.
    let strip = contentView.subviews.first { $0.tag == 1_103 }
    guard let openTile = (strip?.subviews ?? []).first(where: { $0.toolTip == "Drag to reorder or drag out to remove." }) else {
        expect(false, "The mirrored strip did not build a tile for the toolbar item.")
        return
    }
    let start = openTile.convert(NSMakePoint(openTile.bounds.size.width / 2, openTile.bounds.size.height / 2), to: nil)
    let outside = contentView.convert(NSMakePoint(contentView.frame.size.width / 2, 220), to: nil)
    openTile.mouseDown(with: NSEvent(type: .leftMouseDown, locationInWindow: start))
    openTile.mouseDragged(with: NSEvent(type: .leftMouseDragged, locationInWindow: outside))
    openTile.mouseUp(with: NSEvent(type: .leftMouseUp, locationInWindow: outside))

    expect(toolbar.items.isEmpty, "Dragging the item out of the strip did not remove it.")
    expect(paletteTiles[0].winBackgroundColor != dimFill,
           "The palette tile did not re-enable after its item left the toolbar.")

    clearApplicationWindows()
}

final class DimmingToolbarDelegate: NSObject, NSToolbarDelegate {
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [NSToolbarItem.Identifier("open"), .flexibleSpace]
    }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [NSToolbarItem.Identifier("open")]
    }
}

@MainActor
func testToolbarCustomizationDragShowsInsertionIndicator() {
    clearApplicationWindows()

    let toolbar = NSToolbar(identifier: "indicator")
    for name in ["one", "two", "three"] {
        let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier(rawValue: name))
        item.label = name
        toolbar.addItem(item)
    }
    toolbar.allowsUserCustomization = true
    toolbar.runCustomizationPalette(nil)

    guard let panel = NSApplication.shared.windows.compactMap({ $0 as? NSPanel }).last,
          let contentView = panel.contentView else {
        expect(false, "Toolbar customization palette did not create a panel.")
        return
    }

    let accent = NSColor(calibratedRed: 0.16, green: 0.45, blue: 0.85, alpha: 1.0)
    func indicator() -> NSView? {
        contentView.subviews.first { $0.winBackgroundColor == accent }
    }
    expect(indicator()?.isHidden == true, "The insertion indicator should start hidden.")

    // Drag the first strip tile over the strip: the indicator appears at a
    // boundary; releasing hides it and the drop lands at the indicated slot.
    let strip = contentView.subviews.first { $0.tag == 1_103 }
    let tiles = (strip?.subviews ?? [])
        .filter { $0.toolTip == "Drag to reorder or drag out to remove." }
        .sorted { $0.frame.origin.x < $1.frame.origin.x }
    guard let firstTile = tiles.first else {
        expect(false, "The mirrored strip did not build tiles.")
        return
    }
    let start = firstTile.convert(NSMakePoint(firstTile.bounds.size.width / 2, firstTile.bounds.size.height / 2), to: nil)
    let overStrip = contentView.convert(NSMakePoint(contentView.frame.size.width - 40, 20), to: nil)
    firstTile.mouseDown(with: NSEvent(type: .leftMouseDown, locationInWindow: start))
    firstTile.mouseDragged(with: NSEvent(type: .leftMouseDragged, locationInWindow: overStrip))
    expect(indicator()?.isHidden == false, "The insertion indicator did not appear during a strip drag.")
    firstTile.mouseUp(with: NSEvent(type: .leftMouseUp, locationInWindow: overStrip))
    expect(indicator()?.isHidden == true, "The insertion indicator did not hide after the drop.")
    expect(toolbar.items.map(\.itemIdentifier) == [NSToolbarItem.Identifier("two"), NSToolbarItem.Identifier("three"), NSToolbarItem.Identifier("one")],
           "The drop did not land where the indicator showed. Got \(toolbar.items.map(\.itemIdentifier)).")

    clearApplicationWindows()
}

@MainActor
func testToolbarModernIdentifiersRenderAsGaps() {
    let backend = InMemoryNativeControlBackend()
    let toolbar = NSToolbar(identifier: "modern")
    toolbar.setVisibleItemIdentifiers([.toggleSidebar, .sidebarTrackingSeparator, .inspectorTrackingSeparator])

    // The synthesized items exist with Mac shapes.
    expect(toolbar.item(withIdentifier: .toggleSidebar)?.label == "Sidebar",
           "toggleSidebar did not synthesize a labeled item.")

    let toolbarView = NSToolbarView(frame: NSMakeRect(0, 0, 300, 40))
    toolbarView.toolbar = toolbar
    _ = toolbarView.realizeNativePeer(in: backend, parent: nil)

    // Tracking separators render as plain gaps — no composite item text
    // carrying their identifiers lands in the backend.
    let allTexts = backend.records.values.map(\.text).joined(separator: "|")
    expect(!allTexts.contains("SidebarTrackingSeparator") && !allTexts.contains("InspectorTrackingSeparator"),
           "Tracking separators rendered as labeled items instead of gaps.")
}

@MainActor
func testToolbarRightClickPopsContextMenu() {
    clearApplicationWindows()

    let backend = InMemoryNativeControlBackend()
    let toolbar = NSToolbar(identifier: "context")
    let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("doc"))
    item.label = "Doc"
    toolbar.addItem(item)
    toolbar.allowsUserCustomization = true
    toolbar.displayMode = .iconAndLabel

    let toolbarView = NSToolbarView(frame: NSMakeRect(0, 0, 300, 40))
    toolbarView.toolbar = toolbar
    _ = toolbarView.realizeNativePeer(in: backend, parent: nil)

    // Right-click pops the Mac context menu: three display modes (current one
    // checked) + separator + Customize Toolbar….
    toolbarView.rightMouseDown(with: NSEvent(type: .rightMouseDown, locationInWindow: NSMakePoint(150, 20)))
    guard let menu = backend.poppedContextMenus.last else {
        expect(false, "Right-clicking the toolbar did not pop a context menu.")
        return
    }
    let titles = menu.items.map(\.title)
    expect(titles == ["Icon and Text", "Icon Only", "Text Only", "", "Customize Toolbar…"],
           "The toolbar context menu did not carry the Mac entries. Got \(titles).")
    expect(menu.items[0].state == .on && menu.items[1].state == .off,
           "The current display mode was not checked in the context menu.")

    // Choosing "Text Only" switches the display mode.
    backend.nextContextMenuSelection = 2
    toolbarView.rightMouseDown(with: NSEvent(type: .rightMouseDown, locationInWindow: NSMakePoint(150, 20)))
    expect(toolbar.displayMode == .labelOnly, "Choosing Text Only did not switch the display mode.")

    // The re-popped menu checks the new mode.
    backend.nextContextMenuSelection = -1
    toolbarView.rightMouseDown(with: NSEvent(type: .rightMouseDown, locationInWindow: NSMakePoint(150, 20)))
    expect(backend.poppedContextMenus.last?.items[2].state == .on,
           "The re-popped menu did not check the newly selected mode.")

    // Choosing Customize Toolbar… opens the customization palette.
    backend.nextContextMenuSelection = 4
    toolbarView.rightMouseDown(with: NSEvent(type: .rightMouseDown, locationInWindow: NSMakePoint(150, 20)))
    expect(toolbar.customizationPaletteIsRunning, "Choosing Customize Toolbar… did not open the palette.")

    // A non-customizable toolbar's menu omits the Customize entry.
    backend.nextContextMenuSelection = -1
    toolbar.allowsUserCustomization = false
    toolbarView.rightMouseDown(with: NSEvent(type: .rightMouseDown, locationInWindow: NSMakePoint(150, 20)))
    expect(backend.poppedContextMenus.last?.items.map(\.title) == ["Icon and Text", "Icon Only", "Text Only"],
           "A non-customizable toolbar's context menu should omit Customize Toolbar….")

    clearApplicationWindows()
}

@MainActor
func testToolbarItemRightClickAddsRemoveItem() {
    let backend = InMemoryNativeControlBackend()
    let toolbar = NSToolbar(identifier: "removable")
    let doc = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("doc"))
    doc.label = "Doc"
    toolbar.addItem(doc)
    toolbar.allowsUserCustomization = true

    let toolbarView = NSToolbarView(frame: NSMakeRect(0, 0, 300, 40))
    toolbarView.toolbar = toolbar
    _ = toolbarView.realizeNativePeer(in: backend, parent: nil)

    // Right-click on the item (near the leading edge): the menu leads with
    // Remove Item.
    toolbarView.rightMouseDown(with: NSEvent(type: .rightMouseDown, locationInWindow: NSMakePoint(20, 20)))
    expect(backend.poppedContextMenus.last?.items.first?.title == "Remove Item",
           "Right-clicking an item did not offer Remove Item. Got \(backend.poppedContextMenus.last?.items.map(\.title) ?? []).")

    // Right-click on empty space: no Remove Item entry.
    toolbarView.rightMouseDown(with: NSEvent(type: .rightMouseDown, locationInWindow: NSMakePoint(250, 20)))
    expect(backend.poppedContextMenus.last?.items.first?.title == "Icon and Text",
           "Right-clicking empty space should not offer Remove Item.")

    // Choosing Remove Item removes the clicked item.
    backend.nextContextMenuSelection = 0
    toolbarView.rightMouseDown(with: NSEvent(type: .rightMouseDown, locationInWindow: NSMakePoint(20, 20)))
    backend.nextContextMenuSelection = -1
    expect(toolbar.items.isEmpty, "Remove Item did not remove the clicked toolbar item.")
}

@MainActor
func testToolbarCenteredItemsLayOutCentered() {
    let backend = InMemoryNativeControlBackend()
    let toolbar = NSToolbar(identifier: "centered")
    for name in ["alpha", "mid", "omega"] {
        let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier(rawValue: name))
        item.label = name
        toolbar.addItem(item)
    }
    toolbar.centeredItemIdentifiers = [NSToolbarItem.Identifier("mid")]

    let toolbarView = NSToolbarView(frame: NSMakeRect(0, 0, 600, 40))
    toolbarView.toolbar = toolbar
    _ = toolbarView.realizeNativePeer(in: backend, parent: nil)

    // The centered item's rendered tile sits at the strip's midpoint.
    let midTile = toolbarView.subviews.first { view in
        guard let handle = view.nativeHandle, let record = backend.records[handle] else {
            return false
        }
        return record.text.contains("\tmid\t")
    }
    guard let midTile else {
        expect(false, "The centered item's tile was not rendered.")
        return
    }
    let midX = midTile.frame.origin.x + midTile.frame.size.width / 2
    expect(abs(midX - 300) <= 4, "The centered item was not centered. midX = \(midX).")
}

@MainActor
func testToolbarCustomViewItemsShrinkBeforeOverflow() {
    let backend = InMemoryNativeControlBackend()
    let toolbar = NSToolbar(identifier: "elastic")
    let search = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("search"))
    search.label = "Search"
    search.view = NSTextField(string: "", frame: NSMakeRect(0, 0, 200, 24))
    search.minSize = NSMakeSize(40, 24)
    search.maxSize = NSMakeSize(200, 24)
    toolbar.addItem(search)
    for name in ["one", "two"] {
        let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier(rawValue: name))
        item.label = name
        toolbar.addItem(item)
    }

    // 220pt can't fit a 200pt search field + two items, but fits when the
    // field shrinks toward its minimum — nothing overflows.
    let toolbarView = NSToolbarView(frame: NSMakeRect(0, 0, 220, 40))
    toolbarView.toolbar = toolbar
    _ = toolbarView.realizeNativePeer(in: backend, parent: nil)

    expect(toolbar.visibleItems?.count == 3,
           "Elastic shrink did not prevent overflow. Visible: \(toolbar.visibleItems?.count ?? -1).")
    guard let fieldView = search.view else {
        expect(false, "The custom view disappeared.")
        return
    }
    expect(fieldView.frame.size.width < 200 && fieldView.frame.size.width >= 40,
           "The custom view did not shrink between min and max. Got \(fieldView.frame.size.width).")
}

@MainActor
func testToolbarItemGroupSelectsAndFires() {
    let backend = InMemoryNativeControlBackend()
    let toolbar = NSToolbar(identifier: "grouped")
    let group = NSToolbarItemGroup(
        itemIdentifier: NSToolbarItem.Identifier("align"),
        titles: ["Left", "Center", "Right"],
        selectionMode: .selectOne
    )
    var fired = 0
    group.onAction = { _ in fired += 1 }
    toolbar.addItem(group)

    expect(group.subitems.count == 3, "The titles convenience init did not build subitems.")
    expect(group.subitems[1].label == "Center", "Subitem labels were not derived from titles.")

    let toolbarView = NSToolbarView(frame: NSMakeRect(0, 0, 400, 40))
    toolbarView.toolbar = toolbar
    _ = toolbarView.realizeNativePeer(in: backend, parent: nil)

    // The group renders one tile per subitem.
    func tile(containing text: String) -> NSView? {
        toolbarView.subviews.first { view in
            guard let handle = view.nativeHandle, let record = backend.records[handle] else {
                return false
            }
            return record.text.contains("\t\(text)\t")
        }
    }
    guard let centerTile = tile(containing: "Center") else {
        expect(false, "The group did not render a tile per subitem.")
        return
    }

    // Clicking a subitem selects it (selectOne) and fires the group action.
    centerTile.mouseUp(with: NSEvent(type: .leftMouseUp, locationInWindow: NSZeroPoint))
    expect(group.selectedIndex == 1, "Clicking a subitem did not select it. Got \(group.selectedIndex).")
    expect(group.isSelected(at: 1) && !group.isSelected(at: 0),
           "selectOne did not keep exactly one selection.")
    expect(fired == 1, "Activating a subitem did not fire the group action.")

    // selectOne: choosing another subitem moves the selection.
    tile(containing: "Left")?.mouseUp(with: NSEvent(type: .leftMouseUp, locationInWindow: NSZeroPoint))
    expect(group.selectedIndex == 0 && !group.isSelected(at: 1),
           "selectOne did not move the selection.")

    // selectAny: activation toggles; momentary: no persistent selection.
    group.selectionMode = .selectAny
    group.setSelected(false, at: 0)
    tile(containing: "Right")?.mouseUp(with: NSEvent(type: .leftMouseUp, locationInWindow: NSZeroPoint))
    tile(containing: "Left")?.mouseUp(with: NSEvent(type: .leftMouseUp, locationInWindow: NSZeroPoint))
    expect(group.isSelected(at: 2) && group.isSelected(at: 0), "selectAny did not accumulate selections.")
    tile(containing: "Right")?.mouseUp(with: NSEvent(type: .leftMouseUp, locationInWindow: NSZeroPoint))
    expect(!group.isSelected(at: 2), "selectAny did not toggle off on re-activation.")
}

@MainActor
func testWindowToolbarActions() {
    clearApplicationWindows()

    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 320, 200),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: InMemoryNativeControlBackend()
    )
    let toolbar = NSToolbar(identifier: "windowActions")
    toolbar.allowsUserCustomization = true
    window.toolbar = toolbar

    // AppKit's View-menu action toggles visibility both ways.
    expect(toolbar.isVisible, "Toolbars start visible.")
    window.toggleToolbarShown(nil)
    expect(!toolbar.isVisible, "toggleToolbarShown did not hide the toolbar.")
    window.toggleToolbarShown(nil)
    expect(toolbar.isVisible, "toggleToolbarShown did not re-show the toolbar.")

    // The window-level customize action opens the palette.
    window.runToolbarCustomizationPalette(nil)
    expect(toolbar.customizationPaletteIsRunning, "runToolbarCustomizationPalette did not open the palette.")

    clearApplicationWindows()
}

@MainActor
func testToolbarMetallicLookDrawsGradientChrome() {
    let backend = InMemoryNativeControlBackend()
    let toolbar = NSToolbar(identifier: "looks")
    let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("doc"))
    item.label = "Doc"
    toolbar.addItem(item)

    let toolbarView = NSToolbarView(frame: NSMakeRect(0, 0, 300, 40))
    toolbarView.toolbar = toolbar
    let handle = toolbarView.realizeNativePeer(in: backend, parent: nil)

    // Unified: flat chrome, no gradient, window-colored strip. (Set explicitly
    // rather than relying on the default, which now resolves `.automatic`
    // against the app-wide presentation.)
    toolbar.winAppleLook = .unified
    let unified = backend.performDraw(for: handle, in: toolbarView.bounds)
    expect(unified.gradients.isEmpty, "The unified look should not draw gradient chrome.")
    expect(toolbarView.winBackgroundColor == .windowBackgroundColor,
           "The unified strip should keep the window background color.")

    // Metallic: the classic brushed gradient fills the strip.
    toolbar.winAppleLook = .metallic
    let metallic = backend.performDraw(for: handle, in: toolbarView.bounds)
    expect(!metallic.gradients.isEmpty, "The metallic look did not draw its gradient chrome.")

    // Regression guard (transparent child windows flashed white over the
    // chrome): in metallic the strip's own background — what transparent
    // children erase with — must be the gradient midtone, never white…
    expect(toolbarView.winBackgroundColor != .windowBackgroundColor && toolbarView.winBackgroundColor != nil,
           "The metallic strip background (the children's erase color) stayed white.")

    // …and the item tile itself paints its slice of the chrome gradient.
    let itemTile = toolbarView.subviews.first { view in
        guard let tileHandle = view.nativeHandle, let record = backend.records[tileHandle] else {
            return false
        }
        return record.text.hasPrefix("__WinChocolateToolbarItem")
    }
    guard let itemTile, let tileHandle = itemTile.nativeHandle else {
        expect(false, "The metallic toolbar did not render an item tile.")
        return
    }
    let tileDraw = backend.performDraw(for: tileHandle, in: itemTile.bounds)
    expect(!tileDraw.gradients.isEmpty,
           "The item tile did not paint its chrome gradient slice (it would erase white over the metal).")

    // Switching back to unified clears the slice rendering.
    toolbar.winAppleLook = .unified
    if let unifiedTile = toolbarView.subviews.first(where: { view in
        guard let h = view.nativeHandle, let record = backend.records[h] else {
            return false
        }
        return record.text.hasPrefix("__WinChocolateToolbarItem")
    }), let unifiedTileHandle = unifiedTile.nativeHandle {
        let unifiedTileDraw = backend.performDraw(for: unifiedTileHandle, in: unifiedTile.bounds)
        expect(unifiedTileDraw.gradients.isEmpty, "A unified item tile should not paint gradient slices.")
    }
}

@MainActor
func testToolbarAutomaticLookFollowsPresentation() {
    // `.automatic` (the default) resolves the Apple look against the app-wide
    // WinPresentation switch (Phase 8): classic → metallic, modern → unified.
    let previous = WinPresentation.selected
    defer { WinPresentation.selected = previous }

    let toolbar = NSToolbar(identifier: "autoLook")
    expect(toolbar.winAppleLook == .automatic, "The default Apple look should be .automatic.")

    WinPresentation.selected = .classic
    expect(toolbar.winResolvedAppleLook == .metallic,
        "Under the classic presentation, .automatic should resolve to the metallic look.")

    WinPresentation.selected = .modern
    expect(toolbar.winResolvedAppleLook == .unified,
        "Under the modern presentation, .automatic should resolve to the unified look.")

    // An explicit look overrides the presentation coordination.
    toolbar.winAppleLook = .metallic
    WinPresentation.selected = .modern
    expect(toolbar.winResolvedAppleLook == .metallic,
        "An explicit .metallic look should win over the presentation.")
}

