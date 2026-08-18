import WinChocolate

@MainActor
func testToolbarStoresItemsAndAttachesToWindow() {
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 320, 200),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: InMemoryNativeControlBackend()
    )
    let toolbar = NSToolbar(identifier: "main")
    let openItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("open"))
    let flexibleItem = NSToolbarItem(itemIdentifier: .flexibleSpace)
    let saveItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("save"))

    openItem.label = "Open"
    openItem.paletteLabel = "Open File"
    openItem.toolTip = "Open a document"
    toolbar.addItem(openItem)
    toolbar.addItem(saveItem)
    toolbar.insertItem(flexibleItem, at: 1)
    toolbar.displayMode = .iconAndLabel
    toolbar.sizeMode = .small
    toolbar.allowsUserCustomization = true

    window.toolbar = toolbar

    expect(window.toolbar === toolbar, "Window did not store toolbar.")
    expect(toolbar.window === window, "Toolbar did not attach back to window.")
    expect(toolbar.items.map(\.itemIdentifier) == [NSToolbarItem.Identifier("open"), .flexibleSpace, NSToolbarItem.Identifier("save")], "Toolbar item ordering was not preserved.")
    expect(toolbar.item(withIdentifier: NSToolbarItem.Identifier("open")) === openItem, "Toolbar did not find item by identifier.")
    expect(openItem.toolbar === toolbar, "Toolbar item did not retain toolbar back-reference.")
    expect(openItem.label == "Open", "Toolbar item label was not stored.")
    expect(openItem.paletteLabel == "Open File", "Toolbar item palette label was not stored.")
    expect(openItem.toolTip == "Open a document", "Toolbar item tooltip was not stored.")
    expect(toolbar.displayMode == .iconAndLabel, "Toolbar display mode was not stored.")
    expect(toolbar.sizeMode == .small, "Toolbar size mode was not stored.")
    expect(toolbar.allowsUserCustomization, "Toolbar customization flag was not stored.")

    let removed = toolbar.removeItem(at: 1)

    expect(removed === flexibleItem, "Toolbar did not remove the expected item.")
    expect(flexibleItem.toolbar == nil, "Removed toolbar item still referenced its toolbar.")
    expect(toolbar.items.map(\.itemIdentifier) == [NSToolbarItem.Identifier("open"), NSToolbarItem.Identifier("save")], "Toolbar removal did not update ordering.")

    let replacement = NSToolbar(identifier: "secondary")
    window.toolbar = replacement

    expect(toolbar.window == nil, "Replacing window toolbar did not detach old toolbar.")
    expect(replacement.window === window, "Replacing window toolbar did not attach new toolbar.")
}

@MainActor
func testToolbarVisibilityAndItemActions() {
    let toolbar = NSToolbar(identifier: "actions")
    let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("click"))
    let button = NSButton(title: "Click", frame: NSMakeRect(0, 0, 80, 28))
    var visibilityStates: [Bool] = []
    var toolbarActionCount = 0
    var buttonActionCount = 0

    toolbar.visibilityDidChange = { isVisible in
        visibilityStates.append(isVisible)
    }
    item.onAction = { _ in
        toolbarActionCount += 1
    }
    button.onAction = { _ in
        buttonActionCount += 1
    }

    item.view = button
    item.isEnabled = false
    item.performAction()

    expect(!button.isEnabled, "Toolbar item enabled state did not sync to its control view.")
    expect(buttonActionCount == 0, "Disabled toolbar item should not activate its control view.")
    expect(toolbarActionCount == 0, "Disabled toolbar item should not invoke closure action.")

    item.isEnabled = true
    item.performAction()

    expect(button.isEnabled, "Toolbar item did not re-enable its control view.")
    expect(buttonActionCount == 1, "Toolbar item did not activate its custom control view.")
    expect(toolbarActionCount == 0, "Toolbar item with a control view should prefer the control action.")

    item.view = nil
    item.performAction()

    expect(toolbarActionCount == 1, "Toolbar item did not invoke its closure action.")

    toolbar.isVisible = false
    toolbar.isVisible = true

    expect(visibilityStates == [false, true], "Toolbar visibility change callback did not receive expected states.")
}

@MainActor
func testToolbarCustomizationDelegateAndDefaultItems() {
    let toolbar = NSToolbar(identifier: "customizable")
    let delegate = RecordingToolbarDelegate()
    let openItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("open"))

    openItem.label = "Open"
    toolbar.delegate = delegate
    toolbar.addItem(openItem)

    toolbar.setVisibleItemIdentifiers([NSToolbarItem.Identifier("open"), NSToolbarItem.Identifier("customize")])

    expect(toolbar.items.map(\.itemIdentifier) == [NSToolbarItem.Identifier("open"), NSToolbarItem.Identifier("customize")], "Toolbar did not apply visible customization identifiers.")
    expect(toolbar.item(withIdentifier: NSToolbarItem.Identifier("customize"))?.label == "Customize", "Toolbar did not retain delegate-created customization item.")
    expect(delegate.requestedIdentifiers == [NSToolbarItem.Identifier("customize")], "Toolbar did not ask delegate for missing customization item.")
    expect(delegate.insertionFlags == [true], "Toolbar did not pass insertion flag when creating visible item.")
    expect(openItem.toolbar === toolbar, "Existing toolbar item lost its toolbar back-reference.")

    toolbar.resetVisibleItemsToDefault()

    expect(toolbar.items.map(\.itemIdentifier) == [NSToolbarItem.Identifier("open"), NSToolbarItem.Identifier("save")], "Toolbar did not restore delegate default item identifiers.")
    expect(toolbar.item(withIdentifier: NSToolbarItem.Identifier("save"))?.label == "Save", "Toolbar did not create default item through delegate.")
    expect(toolbar.item(withIdentifier: NSToolbarItem.Identifier("customize"))?.label == "Customize", "Toolbar item store did not preserve hidden customization item.")
}

@MainActor
func testToolbarCustomizationAllowsDuplicateStructuralItems() {
    let toolbar = NSToolbar(identifier: "customizable")

    toolbar.setVisibleItemIdentifiers([.separator, .separator, .flexibleSpace, .flexibleSpace])

    expect(toolbar.items.map(\.itemIdentifier) == [.separator, .separator, .flexibleSpace, .flexibleSpace], "Toolbar did not keep duplicate structural customization items.")
    expect(toolbar.items[0] !== toolbar.items[1], "Duplicate separators should be distinct toolbar item instances.")
    expect(toolbar.items[2] !== toolbar.items[3], "Duplicate flexible spaces should be distinct toolbar item instances.")
}

final class SharedSeparatorToolbarDelegate: NSObject, NSToolbarDelegate {
    // Mirrors the demo (and common AppKit apps): one cached NSToolbarItem reused
    // for every .separator request, instead of a fresh instance each time.
    let sharedSeparator = NSToolbarItem(itemIdentifier: .separator)

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.separator, NSToolbarItem.Identifier("a")]
    }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.separator, .separator]
    }
    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        if itemIdentifier == .separator {
            return sharedSeparator
        }
        return NSToolbarItem(itemIdentifier: itemIdentifier)
    }
}

@MainActor
func testToolbarKeepsDistinctSeparatorsWithSharedDelegateItem() {
    let delegate = SharedSeparatorToolbarDelegate()
    let toolbar = NSToolbar(identifier: "shared-separator")
    toolbar.delegate = delegate

    // A delegate that reuses one cached NSToolbarItem for every .separator must
    // still yield two DISTINCT toolbar items when two separators are requested in
    // a single pass — the path that autosave restore and a two-separator default
    // set both take. Aliasing the same instance into two slots corrupts the
    // index-based reorder/remove the customization panel relies on.
    toolbar.setVisibleItemIdentifiers([.separator, .separator])
    expect(toolbar.items.count == 2, "Two separators should produce two items; got \(toolbar.items.count).")
    expect(toolbar.items[0] !== toolbar.items[1], "A shared delegate separator was aliased into two slots.")

    // Restoring an autosaved two-separator configuration must not alias either.
    toolbar.setConfiguration(["TB Item Identifiers": [NSToolbarItem.Identifier.separator.rawValue, NSToolbarItem.Identifier.separator.rawValue]])
    expect(toolbar.items.count == 2, "Restore should produce two separators; got \(toolbar.items.count).")
    expect(toolbar.items[0] !== toolbar.items[1], "Restored shared delegate separators were aliased.")
}

@MainActor
func testToolbarCustomizationPaletteShowsToolbarDropTargetAtTop() {
    clearApplicationWindows()

    let toolbar = NSToolbar(identifier: "customizable")
    let delegate = RecordingToolbarDelegate()
    let openItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("open"))
    let saveItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("save"))

    openItem.label = "Open"
    saveItem.label = "Save"
    toolbar.delegate = delegate
    toolbar.allowsUserCustomization = true
    toolbar.addItem(openItem)
    toolbar.addItem(saveItem)

    toolbar.runCustomizationPalette(nil)

    guard let panel = NSApplication.shared.windows.compactMap({ $0 as? NSPanel }).last,
          let contentView = panel.contentView else {
        expect(false, "Toolbar customization palette did not create a panel.")
        return
    }

    let strip = contentView.subviews.first { $0.tag == 1_103 }
    let toolbarTiles = (strip?.subviews ?? [])
        .filter { $0.toolTip == "Drag to reorder or drag out to remove." && $0.frame.origin.y == 8 }

    expect(panel.styleMask.contains(.resizable), "Toolbar customization palette should be resizable.")
    expect(contentView.tag == 1_100, "Toolbar customization palette did not mark the content as the toolbar drop surface.")
    expect(strip?.frame.origin.y == 0, "Toolbar customization strip was not docked at the top.")
    expect(toolbarTiles.count == 2, "Toolbar customization top row did not mirror visible toolbar item count.")
    expect(toolbar.items.map(\.label) == ["Open", "Save"], "Toolbar customization top row did not mirror visible toolbar items.")
    expect(toolbarTiles.allSatisfy { $0.frame.origin.y < 42 }, "Toolbar customization top row was not docked at the top.")
    expect(!contentView.subviews.compactMap { ($0 as? NSTextField)?.stringValue }.contains("Mock toolbar drop target:"), "Toolbar customization palette still labels the drop target as a mock toolbar.")

    let paletteWidth = contentView.subviews.first { $0.tag == 1_101 }?.frame.size.width ?? 0
    expect(paletteWidth > 0, "Toolbar customization palette container was not tagged for lookup.")
    panel.setContentSize(NSMakeSize(900, 560))
    let resizedPaletteWidth = contentView.subviews.first { $0.tag == 1_101 }?.frame.size.width ?? 0
    expect(resizedPaletteWidth > paletteWidth, "Toolbar customization palette contents did not autoresize horizontally.")

    clearApplicationWindows()
}

@MainActor
func testToolbarCustomizationMovesExistingItemToEnd() {
    clearApplicationWindows()

    let toolbar = NSToolbar(identifier: "customizable")
    let openItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("open"))
    let saveItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("save"))
    let printItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("print"))

    openItem.label = "Open"
    saveItem.label = "Save"
    printItem.label = "Print"
    toolbar.allowsUserCustomization = true
    toolbar.addItem(openItem)
    toolbar.addItem(saveItem)
    toolbar.addItem(printItem)

    toolbar.runCustomizationPalette(nil)

    guard let panel = NSApplication.shared.windows.compactMap({ $0 as? NSPanel }).last,
          let contentView = panel.contentView else {
        expect(false, "Toolbar customization palette did not create a panel.")
        return
    }

    let strip = contentView.subviews.first { $0.tag == 1_103 }
    let toolbarTiles = (strip?.subviews ?? [])
        .filter { $0.toolTip == "Drag to reorder or drag out to remove." && $0.frame.origin.y == 8 }
        .sorted { $0.frame.origin.x < $1.frame.origin.x }

    guard let openTile = toolbarTiles.first else {
        expect(false, "Toolbar customization top row did not create toolbar item tiles.")
        return
    }

    let start = openTile.convert(NSMakePoint(openTile.bounds.size.width / 2, openTile.bounds.size.height / 2), to: nil)
    // Drop just inside the trailing edge of the toolbar strip; the content view
    // is resized to the native client area, so the width cannot be hard-coded.
    let end = contentView.convert(NSMakePoint(contentView.frame.size.width - 10, 20), to: nil)

    openTile.mouseDown(with: NSEvent(type: .leftMouseDown, locationInWindow: start))
    openTile.mouseDragged(with: NSEvent(type: .leftMouseDragged, locationInWindow: end))
    openTile.mouseUp(with: NSEvent(type: .leftMouseUp, locationInWindow: end))

    expect(toolbar.items.map(\.itemIdentifier) == [NSToolbarItem.Identifier("save"), NSToolbarItem.Identifier("print"), NSToolbarItem.Identifier("open")], "Dragging an existing toolbar item to the far end did not move it to the end.")

    clearApplicationWindows()
}

@MainActor
func testToolbarViewComposesItemsAndDispatchesActions() {
    let backend = InMemoryNativeControlBackend()
    let toolbar = NSToolbar(identifier: "native")
    let openItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("open"))
    let separator = NSToolbarItem(itemIdentifier: .separator)
    let flexibleSpace = NSToolbarItem(itemIdentifier: .flexibleSpace)
    let saveItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("save"))
    let toolbarView = NSToolbarView(frame: NSMakeRect(0, 0, 280, 36))
    var firedIdentifiers: [String] = []

    openItem.label = "Open"
    openItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: "Open")
    saveItem.label = "Save"
    saveItem.isEnabled = false
    openItem.onAction = { item in
        firedIdentifiers.append(item.itemIdentifier.rawValue)
    }
    saveItem.onAction = { item in
        firedIdentifiers.append(item.itemIdentifier.rawValue)
    }
    toolbar.addItem(openItem)
    toolbar.addItem(separator)
    toolbar.addItem(flexibleSpace)
    toolbar.addItem(saveItem)
    toolbarView.toolbar = toolbar

    let handle = toolbarView.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "view", "Toolbar view did not request a composed native host view.")
    expect(backend.records[handle]?.toolbarItems.isEmpty == true, "Composed toolbar host should not install native toolbar item descriptors.")

    // Spaces and flexible spaces host NO child window — the strip surface
    // (flat or gradient chrome) shows through the gap directly — so the
    // subviews are: open item, separator bar, save item, chrome hairline.
    testToolbarViewComposedHierarchy(toolbarView, backend: backend)

    let realizedItemTexts = backend.records.values.compactMap(\.text)
    expect(
        realizedItemTexts.contains("__WinChocolateToolbarItem\tOpen\tfolder\t1\t1\tbelow\t"),
        "Composed toolbar did not render the open item label and image."
    )
    expect(
        realizedItemTexts.contains("__WinChocolateToolbarItem\tSave\tsave\t1\t1\tbelow\t"),
        "Composed toolbar did not render the save item label and image."
    )

    let firstPoint = toolbarView.subviews[0].convert(NSMakePoint(4, 4), to: nil)
    let lastPoint = toolbarView.subviews[2].convert(NSMakePoint(4, 4), to: nil)
    toolbarView.subviews[0].mouseDown(with: NSEvent(type: .leftMouseDown, locationInWindow: firstPoint))
    toolbarView.subviews[0].mouseUp(with: NSEvent(type: .leftMouseUp, locationInWindow: firstPoint))
    toolbarView.subviews[2].mouseDown(with: NSEvent(type: .leftMouseDown, locationInWindow: lastPoint))
    toolbarView.subviews[2].mouseUp(with: NSEvent(type: .leftMouseUp, locationInWindow: lastPoint))

    expect(firedIdentifiers == ["open"], "Composed toolbar dispatch did not honor enabled item actions.")

    saveItem.isEnabled = true
    toolbarView.reloadItems()

    let enabledPoint = toolbarView.subviews[2].convert(NSMakePoint(4, 4), to: nil)
    toolbarView.subviews[2].mouseDown(with: NSEvent(type: .leftMouseDown, locationInWindow: enabledPoint))
    toolbarView.subviews[2].mouseUp(with: NSEvent(type: .leftMouseUp, locationInWindow: enabledPoint))
    expect(firedIdentifiers == ["open", "save"], "Toolbar reload did not update enabled state.")

    testToolbarViewDisplayModes(toolbar, backend: backend)
}

@MainActor
func testToolbarViewComposedHierarchy(_ toolbarView: NSToolbarView, backend: InMemoryNativeControlBackend) {
    expect(toolbarView.subviews.count == 4, "Composed toolbar did not create one view per visible item plus chrome. Got \(toolbarView.subviews.count).")
    expect(toolbarView.subviews[0].subviews.isEmpty, "Composed toolbar open item should be one self-contained view.")
    expect(toolbarView.subviews[0].winBackgroundColor == nil, "Composed toolbar item should let the toolbar background show through.")
    if let handle = toolbarView.subviews[0].nativeHandle {
        expect(backend.records[handle]?.drawsBackground == false, "Composed toolbar item should request a clear native background.")
    }
    expect(toolbarView.subviews[1] is NSToolbarSeparatorView, "Composed toolbar separator did not render as a separator view.")
    if let handle = toolbarView.subviews[1].nativeHandle {
        expect(backend.records[handle]?.drawsBackground == false, "Composed toolbar separator should request a clear background.")
    }
    expect(toolbarView.subviews[2].subviews.isEmpty, "Composed toolbar save item should be one self-contained view.")
    expect(toolbarView.subviews[2].winBackgroundColor == nil, "Composed toolbar item should not draw its own background.")
}

@MainActor
func testToolbarViewDisplayModes(_ toolbar: NSToolbar, backend: InMemoryNativeControlBackend) {
    toolbar.displayMode = .iconOnly
    let iconOnlyTexts = backend.records.values.compactMap(\.text)
    expect(iconOnlyTexts.contains("__WinChocolateToolbarItem\tOpen\tfolder\t1\t0\tbelow\t"),
           "Toolbar icon-only mode did not preserve the item image.")
    toolbar.displayMode = .labelOnly
    let labelOnlyTexts = backend.records.values.compactMap(\.text)
    expect(labelOnlyTexts.contains("__WinChocolateToolbarItem\tOpen\tfolder\t0\t1\tbelow\t"),
           "Toolbar label-only mode should preserve item labels.")
}

@MainActor
func testToolbarViewHostsCustomItemView() {
    let backend = InMemoryNativeControlBackend()
    let toolbar = NSToolbar(identifier: "customView")
    let selector = NSPopUpButton(frame: NSMakeRect(0, 0, 140, 28), pullsDown: false)
    let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("selector"))
    let toolbarView = NSToolbarView(frame: NSMakeRect(0, 0, 300, 40))

    selector.addItems(withTitles: ["One", "Two"])
    item.label = "Selector"
    item.view = selector
    item.minSize = NSMakeSize(140, 28)
    item.maxSize = NSMakeSize(140, 28)
    toolbar.addItem(item)
    toolbarView.toolbar = toolbar

    let handle = toolbarView.realizeNativePeer(in: backend, parent: nil)

    expect(selector.superview === toolbarView, "Toolbar custom item view was not hosted by toolbar view.")
    expect(selector.nativeHandle != nil, "Toolbar custom item view did not realize a native peer.")
    // Popups center by their ~24pt visible closed-combo height (the declared
    // 28pt only sizes the dropdown), so they align with neighboring fields.
    expect(selector.frame == NSMakeRect(8, 8, 140, 24), "Toolbar custom item view was not positioned in the toolbar strip. Got \(selector.frame).")
    expect(selector.winBackgroundColor == nil, "Toolbar custom item view should let the toolbar background show through.")
    if let selectorHandle = selector.nativeHandle {
        expect(backend.records[selectorHandle]?.drawsBackground == false, "Toolbar custom control should request a clear native background.")
    }
    expect(backend.records[handle]?.kind == "view", "Toolbar custom item view should be hosted by a composed native view.")
    expect(backend.records[handle]?.toolbarItems.isEmpty == true, "Composed toolbar custom item should not reserve native toolbar separator space.")
}

@MainActor
func testToolbarItemCreatesCompositeImageLabelView() {
    let backend = InMemoryNativeControlBackend()
    let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("open"))
    item.label = "Open"
    item.image = NSImage(named: "folder")

    let view = item.winCompositeView(showItem: true, showLabel: true, toolbarHeight: 44)
    let handle = view.realizeNativePeer(in: backend, parent: nil)

    expect(view.winBackgroundColor == nil, "Toolbar composite view should have a transparent background.")
    expect(view.subviews.isEmpty, "Toolbar composite view should render as one self-contained native view.")
    expect(view.frame.size.height <= 40, "Toolbar composite view did not fit within the toolbar height.")
    expect(
        backend.records[handle]?.text == "__WinChocolateToolbarItem\tOpen\tfolder\t1\t1\tbelow\t",
        "Toolbar composite view did not carry the label and image key."
    )
    expect(backend.records[handle]?.drawsBackground == false, "Toolbar composite view should request a clear native background.")

    let separator = NSToolbarItem(itemIdentifier: .separator)
    let separatorView = separator.winCompositeView(showItem: true, showLabel: false, toolbarHeight: 44)
    let separatorHandle = separatorView.realizeNativePeer(in: backend, parent: nil)

    expect(separatorView is NSToolbarSeparatorView, "Toolbar separator composite should be a simple separator view.")
    expect(separatorView.winBackgroundColor != nil, "Toolbar separator view should draw its own bar color.")
    expect(backend.records[separatorHandle]?.text.contains("separator") == true, "Toolbar separator view did not carry a separator image key.")
    expect(backend.records[separatorHandle]?.drawsBackground == false, "Toolbar separator view should request a clear native background.")
}

@MainActor
func testUserDefaultsRoundTripsPlistValues() {
    #if os(Windows)
    // Pure store logic (no disk).
    let memory = UserDefaults(persistsToDisk: false)
    memory.set("hello", forKey: "s")
    memory.set(42, forKey: "i")
    memory.set(true, forKey: "b")
    memory.set(["a", "b"], forKey: "list")
    memory.set(["nested": ["x", "y"], "n": 7] as [String: Any], forKey: "dict")
    expect(memory.string(forKey: "s") == "hello", "UserDefaults did not round-trip a string.")
    expect(memory.integer(forKey: "i") == 42, "UserDefaults did not round-trip an integer.")
    expect(memory.bool(forKey: "b"), "UserDefaults did not round-trip a boolean.")
    expect(memory.stringArray(forKey: "list") == ["a", "b"], "UserDefaults did not round-trip a string array.")
    expect((memory.dictionary(forKey: "dict")?["n"] as? Int) == 7, "UserDefaults did not round-trip a nested dictionary.")
    memory.removeObject(forKey: "s")
    expect(memory.string(forKey: "s") == nil, "UserDefaults removeObject did not delete the value.")
    memory.register(defaults: ["fallback": "reg"])
    expect(memory.string(forKey: "fallback") == "reg", "UserDefaults registration domain was not consulted.")

    // Real persistence: write through one instance, read through a fresh one.
    let writer = UserDefaults()
    writer.set(["one", "two"], forKey: "WinChocolateTestMarker")
    writer.set(3.5, forKey: "WinChocolateTestDouble")
    let reader = UserDefaults()
    expect(reader.stringArray(forKey: "WinChocolateTestMarker") == ["one", "two"],
           "UserDefaults did not persist an array to disk and back.")
    expect(reader.double(forKey: "WinChocolateTestDouble") == 3.5,
           "UserDefaults did not persist a double to disk and back.")
    writer.removeObject(forKey: "WinChocolateTestMarker")
    writer.removeObject(forKey: "WinChocolateTestDouble")
    #endif
}

final class ToolbarValidationTarget: NSToolbarItemValidation {
    var allows = false
    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        allows
    }
}

@MainActor
func testToolbarItemValidationAndMenuForm() {
    let toolbar = NSToolbar(identifier: "validation")
    let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("save"))
    item.tag = 7
    let menuForm = NSMenuItem(title: "Save Document", action: nil, keyEquivalent: "")
    item.menuFormRepresentation = menuForm
    expect(item.tag == 7, "Toolbar item tag was not stored.")
    expect(item.menuFormRepresentation?.title == "Save Document", "menuFormRepresentation was not stored.")

    let target = ToolbarValidationTarget()
    item.target = target
    toolbar.addItem(item)

    // validateVisibleItems consults the target's NSToolbarItemValidation.
    target.allows = false
    toolbar.validateVisibleItems()
    expect(!item.isEnabled, "validate() did not disable the item per its validation target.")
    target.allows = true
    toolbar.validateVisibleItems()
    expect(item.isEnabled, "validate() did not re-enable the item per its validation target.")

    // autovalidates=false leaves the item alone.
    item.autovalidates = false
    target.allows = false
    toolbar.validateVisibleItems()
    expect(item.isEnabled, "An autovalidates=false item was validated anyway.")
}

final class SelectionToolbarDelegate: NSObject, NSToolbarDelegate {
    var added: [NSToolbarItem] = []
    var removed: [NSToolbarItem] = []
    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [NSToolbarItem.Identifier("inbox"), NSToolbarItem.Identifier("sent")]
    }
    func toolbarWillAddItem(_ notification: Notification) {
        if let item = notification.userInfo?["item"] as? NSToolbarItem {
            added.append(item)
        }
    }
    func toolbarDidRemoveItem(_ notification: Notification) {
        if let item = notification.userInfo?["item"] as? NSToolbarItem {
            removed.append(item)
        }
    }
}

@MainActor
func testToolbarSelectionAndDelegateCallbacks() {
    let toolbar = NSToolbar(identifier: "selection")
    let delegate = SelectionToolbarDelegate()
    toolbar.delegate = delegate

    // The add/remove lifecycle also posts through NotificationCenter.default
    // (AppKit's willAddItemNotification), filtered to this toolbar.
    final class SendableCounter: @unchecked Sendable { var value = 0 }
    let centerPostCount = SendableCounter()
    let observer = NotificationCenter.default.addObserver(
        forName: NSToolbar.willAddItemNotification,
        object: toolbar,
        queue: nil
    ) { notification in
        if notification.userInfo?["item"] is NSToolbarItem {
            centerPostCount.value += 1
        }
    }
    defer { NotificationCenter.default.removeObserver(observer) }

    let inbox = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("inbox"))
    let drafts = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("drafts"))
    toolbar.addItem(inbox)
    toolbar.addItem(drafts)

    // Will-add fired for both, carrying the item under "item".
    expect(delegate.added.count == 2 && delegate.added[0] === inbox,
           "toolbarWillAddItem did not deliver the added items. Got \(delegate.added.count).")
    expect(centerPostCount.value == 2,
           "willAddItemNotification did not post through NotificationCenter. Got \(centerPostCount.value).")

    // A selectable identifier sticks; a non-selectable one clears the selection.
    toolbar.selectedItemIdentifier = NSToolbarItem.Identifier("inbox")
    expect(toolbar.selectedItemIdentifier == NSToolbarItem.Identifier("inbox"), "A selectable identifier did not stick.")
    toolbar.selectedItemIdentifier = NSToolbarItem.Identifier("drafts")
    expect(toolbar.selectedItemIdentifier == nil, "A non-selectable identifier was not cleared.")

    // Did-remove fires with the removed item.
    _ = toolbar.removeItem(at: 1)
    expect(delegate.removed.count == 1 && delegate.removed[0] === drafts,
           "toolbarDidRemoveItem did not deliver the removed item.")

    // With nothing overflowed, visibleItems mirrors items.
    expect(toolbar.visibleItems?.map(\.itemIdentifier) == [NSToolbarItem.Identifier("inbox")], "visibleItems did not mirror items.")
    expect(!toolbar.customizationPaletteIsRunning, "The customization palette should not report running by default.")
}

