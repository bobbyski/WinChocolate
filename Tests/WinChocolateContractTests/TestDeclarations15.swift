import WinChocolate

@MainActor
func testWinFoundationValueTypeCompatibility() {
    testWinFoundationIndexSetCompatibility()
    testWinFoundationDateAndUUIDCompatibility()
}

@MainActor
func testWinFoundationIndexSetCompatibility() {
    #if os(Windows)
    var indexes = IndexSet(integer: 2)
    indexes.insert(1)
    indexes.insert(3)
    indexes.remove(2)
    expect(Array(indexes) == [1, 3], "WinFoundation IndexSet ordering or mutation failed.")
    expect(indexes.first == 1, "WinFoundation IndexSet first failed.")
    expect(indexes.last == 3, "WinFoundation IndexSet last failed.")

    var rangeIndexes = IndexSet(integersIn: 4..<7)
    rangeIndexes.insert(integersIn: 8...9)
    rangeIndexes.remove(integersIn: 5..<6)
    expect(Array(rangeIndexes) == [4, 6, 8, 9], "WinFoundation IndexSet range mutation failed.")
    expect(rangeIndexes.contains(integersIn: 8...9), "WinFoundation IndexSet closed range contains failed.")
    expect(!rangeIndexes.contains(integersIn: 4...6), "WinFoundation IndexSet range contains should require all indexes.")
    expect(rangeIndexes.intersects(integersIn: 5...6), "WinFoundation IndexSet range intersects failed.")
    expect(rangeIndexes.integerGreaterThan(6) == 8, "WinFoundation IndexSet integerGreaterThan failed.")
    expect(rangeIndexes.integerGreaterThanOrEqualTo(6) == 6, "WinFoundation IndexSet integerGreaterThanOrEqualTo failed.")
    expect(rangeIndexes.integerLessThan(8) == 6, "WinFoundation IndexSet integerLessThan failed.")
    expect(rangeIndexes.integerLessThanOrEqualTo(8) == 8, "WinFoundation IndexSet integerLessThanOrEqualTo failed.")

    let unionIndexes = indexes.union(rangeIndexes)
    expect(Array(unionIndexes) == [1, 3, 4, 6, 8, 9], "WinFoundation IndexSet union failed.")
    expect(Array(unionIndexes.intersection(IndexSet(integersIn: 3...8))) == [3, 4, 6, 8], "WinFoundation IndexSet intersection failed.")
    expect(Array(unionIndexes.subtracting(IndexSet(integersIn: 4...8))) == [1, 3, 9], "WinFoundation IndexSet subtracting failed.")
    #endif
}

@MainActor
func testWinFoundationDateAndUUIDCompatibility() {
    #if os(Windows)
    let early = Date(timeIntervalSinceReferenceDate: 1)
    let later = Date(timeIntervalSinceReferenceDate: 2)
    expect(early < later, "WinFoundation Date comparison failed.")
    expect(Date(timeIntervalSince1970: 978_307_201).timeIntervalSinceReferenceDate == 1, "WinFoundation Date Unix epoch initializer failed.")
    expect(early.timeIntervalSince1970 == 978_307_201, "WinFoundation Date timeIntervalSince1970 failed.")
    expect(later.timeIntervalSince(early) == 1, "WinFoundation Date timeIntervalSince failed.")
    expect(early.addingTimeInterval(10).timeIntervalSinceReferenceDate == 11, "WinFoundation Date addingTimeInterval failed.")
    expect(early.distance(to: later) == 1, "WinFoundation Date distance(to:) failed.")
    expect(early.advanced(by: 4).timeIntervalSinceReferenceDate == 5, "WinFoundation Date advanced(by:) failed.")

    let now = Date()
    expect(now.timeIntervalSince1970 > 1_700_000_000, "WinFoundation Date() did not use a real current clock.")
    let future = Date(timeIntervalSinceNow: 5)
    expect(future.timeIntervalSince(now) > 0, "WinFoundation Date(timeIntervalSinceNow:) failed.")
    expect(Date.now.timeIntervalSince1970 > 1_700_000_000, "WinFoundation Date.now did not use a real current clock.")

    let knownUUID = UUID(uuidString: "00112233-4455-6677-8899-AABBCCDDEEFF")
    expect(knownUUID?.uuidString == "00112233-4455-6677-8899-AABBCCDDEEFF", "WinFoundation UUID uuidString failed.")
    expect(UUID(uuidString: "00112233445566778899aabbccddeeff")?.uuidString == "00112233-4455-6677-8899-AABBCCDDEEFF", "WinFoundation UUID compact/lowercase parser failed.")
    expect(UUID(uuidString: "not-a-uuid") == nil, "WinFoundation UUID should reject invalid strings.")
    let tupleUUID = UUID(uuid: (
        0x00, 0x11, 0x22, 0x33,
        0x44, 0x55, 0x66, 0x77,
        0x88, 0x99, 0xAA, 0xBB,
        0xCC, 0xDD, 0xEE, 0xFF
    ))
    expect(tupleUUID == knownUUID, "WinFoundation UUID raw tuple initializer failed.")
    expect(tupleUUID.description == tupleUUID.uuidString, "WinFoundation UUID description failed.")
    expect(UUID().uuidString != UUID().uuidString, "WinFoundation UUID() should create distinct values.")

    let interval: TimeInterval = 2.5
    expect(Date(timeInterval: interval, since: early).timeIntervalSinceReferenceDate == 3.5, "WinFoundation TimeInterval alias failed.")

    #endif
}

@MainActor
func testWinFoundationBundleAndNotificationCompatibility() {
    #if os(Windows)
    guard let packageBundle = Bundle(path: ".") else {
        fatalError("WinFoundation Bundle(path:) failed.")
    }
    expect(packageBundle.bundleURL.isFileURL, "WinFoundation Bundle bundleURL should be a file URL.")
    expect(!packageBundle.bundlePath.isEmpty, "WinFoundation Bundle bundlePath failed.")
    expect(packageBundle.path(forResource: "Package", ofType: "swift")?.hasSuffix("Package.swift") == true, "WinFoundation Bundle resource path lookup failed.")
    expect(packageBundle.url(forResource: "Package", withExtension: "swift")?.lastPathComponent == "Package.swift", "WinFoundation Bundle resource URL lookup failed.")
    expect(packageBundle.path(forResource: "Missing", ofType: "swift") == nil, "WinFoundation Bundle should return nil for missing resources.")
    expect(Bundle(path: ".")?.path(forResource: "WinChocolateArtwork", ofType: "bmp", inDirectory: "Demo\\DemoApplication\\Resources") != nil, "WinFoundation Bundle should find demo resources from the package working directory.")
    expect(Bundle(path: ".")?.path(forResource: "WinChocolateArtworkDemo", ofType: "bmp", inDirectory: "Demo\\DemoApplication\\Resources") != nil, "WinFoundation Bundle should find resized demo resources from the package working directory.")
    expect(Bundle(url: packageBundle.bundleURL)?.bundlePath == packageBundle.bundlePath, "WinFoundation Bundle(url:) failed.")
    expect(Bundle.main.bundleURL.isFileURL, "WinFoundation Bundle.main should expose a file URL.")
    expect(Bundle.main.executableURL?.pathExtension == "exe", "WinFoundation Bundle.main executableURL failed.")

    let center = NotificationCenter()
    let notificationName = Notification.Name("WinFoundationNotification")
    let sender = NSButton(title: "Sender", frame: NSMakeRect(0, 0, 80, 24))
    var deliveredNames: [String] = []
    var deliveredUserInfoValue = ""
    let token = center.addObserver(forName: notificationName, object: sender, queue: nil) { notification in
        deliveredNames.append(notification.name.rawValue)
        deliveredUserInfoValue = notification.userInfo?["value"] as? String ?? ""
    }
    center.post(name: notificationName, object: NSButton(title: "Other", frame: NSMakeRect(0, 0, 80, 24)))
    expect(deliveredNames.isEmpty, "WinFoundation NotificationCenter should filter nonmatching objects.")
    center.post(name: notificationName, object: sender, userInfo: ["value": "delivered"])
    expect(deliveredNames == ["WinFoundationNotification"], "WinFoundation NotificationCenter did not deliver matching notification.")
    expect(deliveredUserInfoValue == "delivered", "WinFoundation NotificationCenter did not preserve userInfo.")
    center.removeObserver(token)
    center.post(name: notificationName, object: sender)
    expect(deliveredNames.count == 1, "WinFoundation NotificationCenter removeObserver failed.")

    var wildcardCount = 0
    let wildcardToken = center.addObserver(forName: nil, object: nil, queue: OperationQueue.main) { _ in
        wildcardCount += 1
    }
    center.post(Notification(name: "WildcardOne"))
    center.post(name: "WildcardTwo")
    expect(wildcardCount == 2, "WinFoundation NotificationCenter wildcard observer failed.")
    center.removeObserver(wildcardToken)
    #endif
}

@MainActor
func testImageViewStoresImageAndUsesNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let imageView = NSImageView(frame: NSMakeRect(0, 0, 64, 64))
    let packageURL = URL(fileURLWithPath: "Package.swift")
    let urlImage = NSImage(contentsOf: packageURL)
    let dataImage = NSImage(data: Data([1, 2, 3, 4]))
    let symbolImage = NSImage(systemSymbolName: "folder", accessibilityDescription: "Open folder")

    expect(urlImage?.filePath == packageURL.path, "NSImage(contentsOf:) did not preserve file URL path.")
    expect((urlImage?.data?.count ?? 0) > 0, "NSImage(contentsOf:) did not load file data.")
    expect(dataImage?.data == Data([1, 2, 3, 4]), "NSImage(data:) did not preserve image data.")
    expect(NSImage(data: Data()) == nil, "NSImage(data:) should reject empty data.")
    expect(symbolImage?.name == "folder", "NSImage(systemSymbolName:) did not preserve the symbol name.")
    expect(symbolImage?.accessibilityDescription == "Open folder", "NSImage(systemSymbolName:) did not preserve accessibility description.")

    imageView.image = NSImage(contentsOfFile: "Resources/Icon.bmp")
    imageView.imageScaling = .scaleNone
    imageView.imageAlignment = .alignTopLeft
    imageView.imageFrameStyle = .grayBezel

    let handle = imageView.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "imageView", "Image view did not request native peer.")
    expect(backend.records[handle]?.imagePath == "Resources/Icon.bmp", "Image view did not sync image path.")
    expect(backend.records[handle]?.text == "Resources/Icon.bmp\nno scale, top left", "Image view did not sync image description.")
    expect(!imageView.acceptsFirstResponder, "Image view should not accept first responder by default.")
    expect(imageView.imageFrameStyle == .grayBezel, "Image view frame style was not stored.")

    imageView.image = NSImage(contentsOfFile: "Resources/Updated.bmp")
    expect(backend.records[handle]?.imagePath == "Resources/Updated.bmp", "Image view image path changes did not sync.")
    expect(backend.records[handle]?.text == "Resources/Updated.bmp\nno scale, top left", "Image view image changes did not sync.")

    imageView.imageScaling = .scaleProportionallyUpOrDown
    imageView.imageAlignment = .alignBottomRight
    expect(backend.records[handle]?.text == "Resources/Updated.bmp\nscale fit, bottom right", "Image view scaling/alignment changes did not sync.")
}

@MainActor
func testTabViewStoresItemsSelectionAndUsesNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let tabView = NSTabView(frame: NSMakeRect(0, 0, 220, 80))
    let first = NSTabViewItem(identifier: "first")
    let second = NSTabViewItem(identifier: "second")
    first.label = "First"
    second.label = "Second"

    tabView.addTabViewItem(first)
    tabView.addTabViewItem(second)

    let handle = tabView.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "tabView", "Tab view did not request native peer.")
    expect(backend.records[handle]?.tabViewItems == ["First", "Second"], "Tab view labels were not synced.")
    expect(tabView.selectedTabViewItem === first, "Tab view did not select first item by default.")

    tabView.selectTabViewItem(second)
    expect(tabView.selectedTabViewItem === second, "Tab view did not update selected item.")
    expect(backend.records[handle]?.tabViewSelectedIndex == 1, "Tab view selection was not synced.")
}

@MainActor
func testTabViewNativeSelectionDispatchesAction() {
    let backend = InMemoryNativeControlBackend()
    let tabView = NSTabView(frame: NSMakeRect(0, 0, 220, 80))
    let first = NSTabViewItem(identifier: "first")
    let second = NSTabViewItem(identifier: "second")
    first.label = "First"
    second.label = "Second"
    tabView.addTabViewItem(first)
    tabView.addTabViewItem(second)
    var selectionCount = 0

    tabView.onSelectionChanged = { tabs in
        selectionCount += 1
        expect(tabs.selectedTabViewItem === second, "Native tab selection did not update selected item.")
    }

    let handle = tabView.realizeNativePeer(in: backend, parent: nil)
    backend.setTabViewSelectedIndex(1, for: handle)
    backend.actions[handle]?()

    expect(selectionCount == 1, "Native tab selection callback did not fire.")
}

@MainActor
func testNativeButtonActionMakesButtonFirstResponder() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 200, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 200, 100))
    let button = NSButton(title: "Click", frame: NSMakeRect(20, 20, 80, 24))
    var actionCount = 0

    button.onAction = { _ in
        actionCount += 1
    }
    contentView.addSubview(button)
    window.contentView = contentView
    window.realizeNativePeer()

    guard let handle = button.nativeHandle else {
        fatalError("Button did not realize.")
    }

    backend.actions[handle]?()

    expect(window.firstResponder === button, "Native button action did not make button first responder.")
    expect(backend.focusedHandle == handle, "Native button action did not request native focus.")
    expect(actionCount == 1, "Native button action did not send action.")
}

@MainActor
func testNativePopUpActionMakesPopUpFirstResponder() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 200, 120),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 200, 120))
    let popUpButton = NSPopUpButton(frame: NSMakeRect(20, 20, 140, 80), pullsDown: false)

    popUpButton.addItems(withTitles: ["Info", "Warning"])
    contentView.addSubview(popUpButton)
    window.contentView = contentView
    window.realizeNativePeer()

    guard let handle = popUpButton.nativeHandle else {
        fatalError("Pop-up button did not realize.")
    }

    backend.actions[handle]?()

    expect(window.firstResponder === popUpButton, "Native pop-up action did not make pop-up first responder.")
    expect(backend.focusedHandle == handle, "Native pop-up action did not request native focus.")
}

@MainActor
func testNativeTextChangeMakesEditableTextFieldFirstResponder() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 200, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 200, 100))
    let textField = NSTextField(string: "", frame: NSMakeRect(20, 20, 140, 24))

    textField.isEditable = true
    contentView.addSubview(textField)
    window.contentView = contentView
    window.realizeNativePeer()

    guard let handle = textField.nativeHandle else {
        fatalError("Text field did not realize.")
    }

    backend.textChangeActions[handle]?("Typed")

    expect(window.firstResponder === textField, "Native text change did not make text field first responder.")
    expect(backend.focusedHandle == handle, "Native text change did not request native focus.")
    expect(textField.stringValue == "Typed", "Native text change did not update string value.")
}

@MainActor
func testNativeTextChangeMakesSecureTextFieldFirstResponder() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 200, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 200, 100))
    let secureField = NSSecureTextField(string: "", frame: NSMakeRect(20, 20, 140, 24))

    contentView.addSubview(secureField)
    window.contentView = contentView
    window.realizeNativePeer()

    guard let handle = secureField.nativeHandle else {
        fatalError("Secure text field did not realize.")
    }

    backend.textChangeActions[handle]?("Typed")

    expect(window.firstResponder === secureField, "Native secure text change did not make secure field first responder.")
    expect(backend.focusedHandle == handle, "Native secure text change did not request native focus.")
    expect(secureField.stringValue == "Typed", "Native secure text change did not update string value.")
}

@MainActor
func testNativeTextChangeMakesTextViewFirstResponder() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 240, 140),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 240, 140))
    let textView = NSTextView(frame: NSMakeRect(20, 20, 160, 80))

    contentView.addSubview(textView)
    window.contentView = contentView
    window.realizeNativePeer()

    guard let handle = textView.nativeHandle else {
        fatalError("Text view did not realize.")
    }

    var callbackText = ""
    textView.onTextChanged = { view in
        callbackText = view.string
    }
    backend.textChangeActions[handle]?("Typed\nMore")

    expect(window.firstResponder === textView, "Native text view change did not make text view first responder.")
    expect(backend.focusedHandle == handle, "Native text view change did not request native focus.")
    expect(textView.string == "Typed\nMore", "Native text view change did not update string.")
    expect(callbackText == "Typed\nMore", "Native text view change did not invoke callback.")
}

@MainActor
func testBoxUsesNativePeerAndSyncsTitle() {
    let backend = InMemoryNativeControlBackend()
    let box = NSBox(title: "Group", frame: NSMakeRect(0, 0, 200, 120))

    let handle = box.realizeNativePeer(in: backend, parent: nil)
    box.title = "Updated Group"

    expect(backend.records[handle]?.kind == "box", "Box did not request native peer.")
    expect(backend.records[handle]?.text == "Updated Group", "Box title was not synced to backend.")
}

@MainActor
func testColorValuesClampComponents() {
    let color = NSColor(calibratedRed: 2, green: -1, blue: 0.25, alpha: 3)

    expect(color.redComponent == 1, "Color red component did not clamp high.")
    expect(color.greenComponent == 0, "Color green component did not clamp low.")
    expect(color.blueComponent == 0.25, "Color blue component changed unexpectedly.")
    expect(color.alphaComponent == 1, "Color alpha component did not clamp high.")
}

@MainActor
func testViewAndTextFieldColorsSyncToBackend() {
    let backend = InMemoryNativeControlBackend()
    let view = NSView(frame: NSMakeRect(0, 0, 100, 100))
    let textField = NSTextField(string: "Color", frame: NSMakeRect(0, 0, 80, 24))
    view.winBackgroundColor = .white
    textField.textColor = .blue
    textField.backgroundColor = NSColor(calibratedRed: 0.9, green: 0.95, blue: 1, alpha: 1)
    view.addSubview(textField)

    let viewHandle = view.realizeNativePeer(in: backend, parent: nil)
    guard let textHandle = textField.nativeHandle else {
        fatalError("Text field did not realize.")
    }

    expect(backend.records[viewHandle]?.backgroundColor == .white, "View background color was not synced.")
    expect(backend.records[textHandle]?.textColor == .blue, "Text field text color was not synced.")
    expect(backend.records[textHandle]?.backgroundColor == NSColor(calibratedRed: 0.9, green: 0.95, blue: 1, alpha: 1), "Text field background color was not synced.")
}

@MainActor
func testVisualEffectViewStoresMaterialAndUsesFallbackBackground() {
    let backend = InMemoryNativeControlBackend()
    let effectView = NSVisualEffectView(frame: NSMakeRect(0, 0, 180, 80))

    effectView.material = .sidebar
    effectView.blendingMode = .withinWindow
    effectView.state = .active

    let handle = effectView.realizeNativePeer(in: backend, parent: nil)

    expect(effectView.material == .sidebar, "Visual effect material was not stored.")
    expect(effectView.blendingMode == .withinWindow, "Visual effect blending mode was not stored.")
    expect(effectView.state == .active, "Visual effect state was not stored.")
    expect(!effectView.acceptsFirstResponder, "Visual effect view should skip key-view traversal.")
    expect(backend.records[handle]?.kind == "view", "Visual effect view did not use a view peer.")
    expect(backend.records[handle]?.backgroundColor == effectView.winBackgroundColor, "Visual effect fallback background was not synced.")

    effectView.material = .hudWindow
    expect(backend.records[handle]?.backgroundColor == effectView.winBackgroundColor, "Visual effect material change did not update fallback background.")
}

@MainActor
func testAppearanceSwitchNotificationReresolvesCachedBackgrounds() {
    // Views that cache a resolved background brush (built once from the launch
    // appearance) must re-resolve it when the system theme switches live —
    // otherwise the strip/material stays its old shade under a repaint. Both
    // observe the effective-appearance notification the backend posts.
    NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
    defer { NSApplication.shared.appearance = NSAppearance(named: .aqua) }

    let effectView = NSVisualEffectView(frame: NSMakeRect(0, 0, 180, 80))
    effectView.material = .sidebar
    let toolbarView = NSToolbarView(frame: NSMakeRect(0, 0, 300, 40))

    guard let darkEffect = effectView.winBackgroundColor,
          let darkStrip = toolbarView.winBackgroundColor else {
        fatalError("Both views should have a background color under the dark appearance.")
    }
    expect(darkEffect.whiteComponent < 0.4,
           "The sidebar material should start dark under the dark appearance. Got \(darkEffect).")
    expect(darkStrip.whiteComponent < 0.4,
           "The toolbar strip should start dark under the dark appearance. Got \(darkStrip).")

    // Flip to light and post the live-switch notification the backend emits.
    NSApplication.shared.appearance = NSAppearance(named: .aqua)
    NotificationCenter.default.post(
        name: NSApplication.winEffectiveAppearanceDidChangeNotification, object: nil)

    guard let lightEffect = effectView.winBackgroundColor,
          let lightStrip = toolbarView.winBackgroundColor else {
        fatalError("Both views should still have a background color after the switch.")
    }
    expect(lightEffect.whiteComponent > 0.7,
           "The sidebar material should re-resolve light after a live switch. Got \(lightEffect).")
    expect(lightStrip.whiteComponent > 0.7,
           "The toolbar strip should re-resolve light after a live switch. Got \(lightStrip).")
}

@MainActor
func testFontValuesClampSizeAndSyncToBackend() {
    let backend = InMemoryNativeControlBackend()
    let textField = NSTextField(string: "Font", frame: NSMakeRect(0, 0, 120, 24))
    let tinyFont = NSFont(name: "Segoe UI", size: -4, weight: .regular)
    let boldFont = NSFont.boldSystemFont(ofSize: 16)

    textField.font = boldFont
    let handle = textField.realizeNativePeer(in: backend, parent: nil)

    expect(tinyFont.pointSize == 1, "Font point size did not clamp low.")
    expect(boldFont.fontName == "Segoe UI", "Bold system font did not use system face.")
    expect(boldFont.weight == .bold, "Bold system font did not use bold weight.")
    expect(backend.records[handle]?.font == boldFont, "Text field font was not synced.")
}

@MainActor
func testRemovingRealizedSubviewDestroysNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let parent = NSView(frame: NSMakeRect(0, 0, 100, 100))
    let child = NSView(frame: NSMakeRect(0, 0, 20, 20))
    parent.addSubview(child)
    parent.realizeNativePeer(in: backend, parent: nil)

    guard let childHandle = child.nativeHandle else {
        fatalError("Child did not realize.")
    }

    child.removeFromSuperview()

    expect(child.nativeHandle == nil, "Child native handle was not cleared.")
    expect(backend.records[childHandle] == nil, "Child native record was not destroyed.")
}

@MainActor
func testMainMenuQuitItemTerminatesApplication() {
    let backend = InMemoryNativeControlBackend()
    let app = NSApplication(nativeBackend: backend)
    let menuBar = NSMenu()
    let appMenuItem = NSMenuItem(title: "WinChocolate", action: nil, keyEquivalent: "")
    let appMenu = NSMenu(title: "WinChocolate")
    let quitItem = NSMenuItem(title: "Quit WinChocolate", action: "terminate:", keyEquivalent: "q")

    quitItem.target = app
    appMenu.addItem(quitItem)
    appMenuItem.submenu = appMenu
    menuBar.addItem(appMenuItem)
    app.mainMenu = menuBar

    expect(backend.installedMainMenu === menuBar, "Main menu was not installed in the backend.")
    expect(quitItem.performAction(), "Quit menu item did not perform.")
    expect(backend.didTerminateApplication, "Quit menu item did not terminate the application.")
}

@MainActor
func testMenuItemInsertionLookupAndRemoval() {
    let menu = NSMenu(title: "File")
    let open = menu.addItem(withTitle: "Open", action: nil, keyEquivalent: "o")
    let save = NSMenuItem(title: "Save", action: nil, keyEquivalent: "s")
    let close = menu.insertItem(withTitle: "Close", action: nil, keyEquivalent: "w", at: 1)

    menu.insertItem(save, at: 99)

    expect(menu.numberOfItems == 3, "Menu item count was wrong.")
    expect(menu.item(at: 0) === open, "Menu item lookup by index failed.")
    expect(menu.item(at: 1) === close, "Menu insertItem(withTitle:) inserted at wrong index.")
    expect(menu.item(at: 2) === save, "Menu insertItem clamping failed.")
    expect(menu.item(withTitle: "Save") === save, "Menu lookup by title failed.")
    expect(menu.index(of: close) == 1, "Menu index(of:) failed.")
    expect(menu.indexOfItem(withTitle: "Missing") == -1, "Menu missing title index should be -1.")
    expect(save.menu === menu, "Inserted item did not receive parent menu.")

    menu.removeItem(at: 1)

    expect(close.menu == nil, "Removed item retained parent menu.")
    expect(menu.numberOfItems == 2, "removeItem(at:) did not remove one item.")

    menu.removeItem(open)

    expect(open.menu == nil, "removeItem did not clear parent menu.")
    expect(menu.numberOfItems == 1, "removeItem did not remove matching item.")

    menu.removeAllItems()

    expect(save.menu == nil, "removeAllItems did not clear parent menu.")
    expect(menu.numberOfItems == 0, "removeAllItems did not clear menu.")
}

