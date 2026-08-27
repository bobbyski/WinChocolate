import WinChocolate

@MainActor
func testNibInstantiatesXibObjectGraph() {
    let xib = nibObjectGraphXIB

    final class PanelOwner {}
    let owner = PanelOwner()
    let nib = NSNib(nibData: Data(Array(xib.utf8)))
    guard let instance = nib.winInstantiate(withOwner: owner) else {
        expect(false, "The xib document should instantiate.")
        return
    }

    // One top-level view; placeholders resolve (owner for -2, stand-in for
    // custom objects) without becoming top-level views.
    expect(instance.topLevelObjects.count == 1, "The xib should yield one top-level view.")
    let root = instance.topLevelObjects.first as? NSView
    expect(root != nil, "The top-level object should be an NSView.")
    expect(root?.frame.size == NSMakeSize(300, 200), "The root view should take its xib frame.")
    expect(instance.object(withID: "-2") === owner, "File's Owner should resolve to the instantiate owner.")
    expect((instance.object(withID: "helper-1") as? WinNibCustomObject)?.customClassName == "DemoHelper",
           "A custom object should become a class-name-carrying stand-in.")

    // The button: type, title (with a decoded entity), tag, y-flip (cocoa
    // y=20 h=32 in a 200-high parent → top-down y=148), autoresizing flip
    // (Cocoa flexibleMinY = bottom margin → maxYMargin in top-down space).
    guard let button = instance.view(withIdentifier: "okButton") as? NSButton else {
        expect(false, "The xib button should be findable by identifier.")
        return
    }
    expect(button.title == "Press & Hold", "The button title should decode the &amp; entity.")
    expect(button.tag == 7, "The button should carry its xib tag.")
    expect(button.frame == NSMakeRect(20, 148, 120, 32),
           "The button frame should flip from Cocoa to top-down coordinates; got \(button.frame).")
    expect(button.autoresizingMask.contains(.maxYMargin),
           "Cocoa flexibleMinY should map to the top-down bottom margin.")

    // The action connection: target/action applied, record exposed.
    expect(button.target === owner, "The xib action should set the control's target to File's Owner.")
    expect(button.action == Selector("doThing:"), "The xib action should set the control's selector.")
    let actions = instance.connections.filter { $0.kind == .action }
    expect(actions.count == 1 && actions.first?.name == "doThing:", "The action connection should be recorded.")
    let outlets = instance.connections.filter { $0.kind == .outlet }
    expect(outlets.first?.name == "delegate" && outlets.first?.destination === instance.object(withID: "helper-1"),
           "The outlet connection should resolve its destination for manual wiring.")

    // The rest of the control mix.
    let check = instance.view(withIdentifier: "check") as? NSButton
    expect(check?.state == .on, "The checkbox should decode state=on.")
    expect(check?.buttonType == .switch, "type=check should decode as a switch button.")
    let field = instance.view(withIdentifier: "nameField") as? NSTextField
    expect(field?.isEditable == true && field?.stringValue == "Seed" && field?.placeholderString == "Name",
           "The text field should decode editability, text, and placeholder.")
    let slider = instance.view(withIdentifier: "volume") as? NSSlider
    expect(slider?.doubleValue == 42 && slider?.maxValue == 100, "The slider should decode its values.")

    // The Apple-shaped entry point yields the same top-level objects.
    var topLevel: NSArray?
    expect(nib.instantiate(withOwner: owner, topLevelObjects: &topLevel), "instantiate(withOwner:) should succeed.")
    expect(topLevel?.count == 1, "instantiate(withOwner:) should hand back the top-level objects.")
}

@MainActor
func testNibDecodesConstraintsThroughTheSolverTypes() {
    let xib = """
    <?xml version="1.0" encoding="UTF-8"?>
    <document type="com.apple.InterfaceBuilder3.Cocoa.XIB" version="3.0">
        <objects>
            <customView id="root" identifier="constraintRoot">
                <rect key="frame" x="0.0" y="0.0" width="400" height="300"/>
                <subviews>
                    <customView id="child" identifier="constraintChild" translatesAutoresizingMaskIntoConstraints="NO">
                        <rect key="frame" x="10" y="10" width="100" height="50"/>
                    </customView>
                </subviews>
                <constraints>
                    <constraint firstItem="child" firstAttribute="leading" secondItem="root" secondAttribute="leading" constant="20" id="k1"/>
                    <constraint firstItem="child" firstAttribute="width" constant="150" relation="greaterThanOrEqual" priority="750" id="k2"/>
                    <constraint firstItem="child" firstAttribute="centerX" secondItem="root" secondAttribute="centerX" multiplier="1:2" id="k3"/>
                </constraints>
            </customView>
        </objects>
    </document>
    """

    guard let instance = NSNib(nibData: Data(Array(xib.utf8))).winInstantiate() else {
        expect(false, "The constraint xib should instantiate.")
        return
    }
    let root = instance.view(withIdentifier: "constraintRoot")
    let child = instance.view(withIdentifier: "constraintChild")
    expect(child?.translatesAutoresizingMaskIntoConstraints == false,
           "The xib child should decode translatesAutoresizingMaskIntoConstraints=NO.")

    guard let leading = instance.object(withID: "k1") as? NSLayoutConstraint,
          let width = instance.object(withID: "k2") as? NSLayoutConstraint,
          let center = instance.object(withID: "k3") as? NSLayoutConstraint else {
        expect(false, "Each xib constraint should decode to an NSLayoutConstraint registered by id.")
        return
    }
    expect(leading.firstItem === child && leading.secondItem === root, "k1 items should resolve by xib id.")
    expect(leading.firstAttribute == .leading && leading.constant == 20, "k1 should decode attribute and constant.")
    expect(leading.isActive, "Decoded constraints should be active, as after an AppKit nib load.")
    expect(width.relation == .greaterThanOrEqual && width.constant == 150, "k2 should decode its inequality.")
    expect(width.priority.rawValue == 750, "k2 should decode its priority.")
    expect(width.secondItem == nil, "A bare width constraint has no second item.")
    expect(center.multiplier == 0.5, "A ratio multiplier (1:2) should decode as 0.5.")
}

@MainActor
func testNibLoadsWindowFromData() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        clearApplicationWindows()
    }

    // A window document: style mask, content rect, content subtree.
    let windowXib = nibWindowXIB
    guard let windowInstance = NSNib(nibData: Data(Array(windowXib.utf8))).winInstantiate() else {
        expect(false, "The window xib should instantiate.")
        return
    }
    let window = windowInstance.topLevelObjects.first as? NSWindow
    expect(window?.title == "Nib Window", "The nib window should carry its title.")
    expect(window?.styleMask.contains(.titled) == true, "The nib window should decode its style mask.")
    expect(windowInstance.view(withIdentifier: "windowButton") is NSButton,
           "The window's content subtree should instantiate and be searchable.")
}

@MainActor
func testNibLoadsDemoPanelFromDisk() {
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        clearApplicationWindows()
    }

    // The real demo resource loads from disk through the named-nib path.
    #if os(Windows)
    let resourceBundle = Bundle(path: "Demo\\DemoApplication\\Resources")
    expect(resourceBundle != nil, "The demo resources directory should resolve as a bundle.")
    #else
    let resourceBundle: Bundle? = nil
    #endif
    guard let nib = NSNib(nibNamed: "DemoNibPanel", bundle: resourceBundle) else {
        expect(false, "NSNib(nibNamed:) should find DemoNibPanel.xib in the demo resources.")
        return
    }
    final class PanelOwner {}
    let panelOwner = PanelOwner()
    guard let panel = nib.winInstantiate(withOwner: panelOwner) else {
        expect(false, "DemoNibPanel.xib should instantiate.")
        return
    }
    expect((panel.topLevelObjects.first as? NSView)?.frame.size == NSMakeSize(480, 240),
           "The demo panel should decode its xib size.")
    expect(panel.view(withIdentifier: "nibButton") is NSButton, "The demo panel button should load.")
    expect((panel.view(withIdentifier: "nibPopup") as? NSPopUpButton)?.titleOfSelectedItem == "Cocoa",
           "The demo panel popup should decode its items and selection.")
    expect((panel.view(withIdentifier: "nibSlider") as? NSSlider)?.doubleValue == 35,
           "The demo panel slider should decode its value.")
    let panelActions = panel.connections.filter { $0.kind == .action }
    expect(panelActions.map { $0.name } == ["increment:", "showValues:"],
           "The demo panel's action connections should parse in document order.")

    // The File's Owner outlets resolve against the instantiate owner and
    // point at the live controls — the outlet half of the wiring model the
    // demo's Show Outlet Values popup reads through.
    testNibDemoPanelOutlets(panel, owner: panelOwner)

    // Bundle.loadNibNamed, the classic AppKit entry point.
    #if os(Windows)
    var loaded: NSArray?
    expect(resourceBundle?.loadNibNamed("DemoNibPanel", owner: nil, topLevelObjects: &loaded) == true,
           "Bundle.loadNibNamed should load the demo panel.")
    expect(loaded?.count == 1, "Bundle.loadNibNamed should return the top-level objects.")
    #endif

    // NSViewController(nibName:) loads its view from the same document.
    let controller = NSViewController(nibName: "DemoNibPanel", bundle: resourceBundle)
    expect(controller.view.frame.size == NSMakeSize(480, 240),
           "NSViewController(nibName:) should adopt the nib's top-level view.")
    expect(controller.nibName == "DemoNibPanel", "The controller should record its nib name.")
}

@MainActor
func testNibDemoPanelOutlets(_ panel: WinNibInstance, owner: AnyObject) {
    let outlets = panel.connections.filter { $0.kind == .outlet && $0.source === owner }
    expect(outlets.count == 5, "The demo panel should declare five File's Owner outlets; got \(outlets.count).")
    func outlet(_ name: String) -> AnyObject? { outlets.first { $0.name == name }?.destination }
    expect(outlet("nameField") === panel.view(withIdentifier: "nibField"),
           "The nameField outlet should resolve to the xib text field.")
    expect(outlet("check") is NSButton, "The check outlet should resolve to the checkbox.")
    expect((outlet("slider") as? NSSlider)?.doubleValue == 35, "The slider outlet should reach the live slider.")
    expect((outlet("popup") as? NSPopUpButton)?.titleOfSelectedItem == "Cocoa",
           "The popup outlet should reach the live popup.")
    expect((outlet("countLabel") as? NSTextField)?.stringValue == "0",
           "The countLabel outlet should reach the count label.")
}

@MainActor
func testNibLoadsWindowsControllersAndTheDemoPanelFromDisk() {
    testNibLoadsWindowFromData()
    testNibLoadsDemoPanelFromDisk()
}

@MainActor
func testPlainAlertComposesADarkPanelInsteadOfTheLightMessageBox() {
    let backend = InMemoryNativeControlBackend()
    backend.nextModalResponseCode = NSApplication.ModalResponse.OK.rawValue
    let previousBackend = NSApplication.shared.nativeBackend
    let previousAppearance = NSApplication.shared.appearance
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        NSApplication.shared.appearance = previousAppearance
        clearApplicationWindows()
    }

    // A plain alert (no custom buttons/icon/suppression) in LIGHT mode uses the
    // native OS message box — which records no composed modal-panel session.
    NSApplication.shared.appearance = NSAppearance(named: .aqua)
    let lightAlert = NSAlert()
    lightAlert.messageText = "Values read through xib outlets"
    let sessionsBeforeLight = backend.modalSessions.count
    _ = lightAlert.runModal()
    expect(backend.modalSessions.count == sessionsBeforeLight,
           "A plain alert in light mode should use the native message box, not a composed panel.")

    // The same plain alert in DARK mode composes its own dark-aware panel (the
    // native message box can't honor dark mode) — which runs a modal session.
    NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
    let darkAlert = NSAlert()
    darkAlert.messageText = "Values read through xib outlets"
    let sessionsBeforeDark = backend.modalSessions.count
    _ = darkAlert.runModal()
    expect(backend.modalSessions.count == sessionsBeforeDark + 1,
           "A plain alert in dark mode should compose a dark panel rather than the light native message box.")
}

final class DispatchProbeTarget: NSObject {
    var received: [String] = []
    weak var lastSender: NSObject?

    override func responds(to aSelector: Selector?) -> Bool {
        aSelector?.name == "probe:" || super.responds(to: aSelector)
    }

    @discardableResult
    override func perform(_ aSelector: Selector, with object: Any?) -> Any? {
        guard aSelector.name == "probe:" else {
            return super.perform(aSelector, with: object)
        }

        received.append(aSelector.name)
        lastSender = object as? NSObject
        return nil
    }
}

final class DispatchProbeResponderView: NSView {
    var chainHits = 0

    override func responds(to aSelector: Selector?) -> Bool {
        aSelector?.name == "chainProbe:" || super.responds(to: aSelector)
    }

    @discardableResult
    override func perform(_ aSelector: Selector, with object: Any?) -> Any? {
        guard aSelector.name == "chainProbe:" else {
            return super.perform(aSelector, with: object)
        }

        chainHits += 1
        return nil
    }
}

private func explicitTargetActionProbe() -> DispatchProbeTarget {
    let target = DispatchProbeTarget()
    let button = NSButton(title: "Go", target: target, action: Selector("probe:"))
    button.sendAction()
    expect(target.received == ["probe:"], "The button's action selector should dispatch to its target.")
    expect(target.lastSender === button, "The action should carry the control as sender.")

    // Disabled controls must not fire.
    button.isEnabled = false
    button.sendAction()
    expect(target.received.count == 1, "A disabled control must not send its action.")
    button.isEnabled = true

    // NSControl.sendAction(_:to:) — Apple's explicit-pair method.
    let direct = NSButton(title: "Direct", target: nil, action: nil)
    expect(direct.sendAction(Selector("probe:"), to: target), "sendAction(_:to:) should dispatch and report true.")
    expect(target.received.count == 2, "sendAction(_:to:) should reach the target.")
    expect(!direct.sendAction(nil, to: target), "A nil action must return false.")
    return target
}

func testTargetActionDispatchesThroughRealSelectors() {
    let target = explicitTargetActionProbe()
    // Menu items dispatch the same way (the old terminate:-only special case
    // is gone — any selector reaches any target).
    let item = NSMenuItem(title: "Probe", action: Selector("probe:"), keyEquivalent: "")
    item.target = target
    expect(item.performAction(), "A menu item with target/action should dispatch.")
    expect(target.received.count == 3, "The menu item's selector should reach the target.")

    // Nil-target dispatch walks the key window's responder chain.
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 200, 120),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let probeView = DispatchProbeResponderView(frame: NSMakeRect(0, 0, 50, 20))
    window.contentView?.addSubview(probeView)
    window.makeKey()
    _ = window.makeFirstResponder(probeView)
    expect(
        NSApplication.shared.sendAction(Selector("chainProbe:"), to: nil, from: nil),
        "A nil-target action should resolve through the key window's first responder."
    )
    expect(probeView.chainHits == 1, "The first responder should have performed the chain action.")
    expect(
        (NSApplication.shared.target(forAction: Selector("chainProbe:")) as? NSObject) === probeView,
        "target(forAction:) should resolve the same responder without sending."
    )

    // The chain ends at NSApplication: terminate: resolves there when nothing
    // upstream claims it (resolution only — sending would quit the suite).
    expect(
        (NSApplication.shared.target(forAction: Selector("terminate:")) as? NSObject) === NSApplication.shared,
        "terminate: should resolve to the application at the end of the chain."
    )

    // Standard chain actions reach responders by selector name. As on Apple
    // (10.14+), changeFont:/changeColor: land only on NSFontChanging/
    // NSColorChanging adopters — a plain view refuses them and the chain walk
    // passes it by; copy: remains a plain responder action.
    expect(
        !probeView.responds(to: Selector("changeFont:")),
        "A plain responder should not claim changeFont: (NSFontChanging adopters only)."
    )
    expect(
        probeView.tryToPerform(Selector("copy:"), with: nil),
        "Standard responder actions should be performable by selector."
    )

    window.close()
}

final class TestDraggingInfo: NSObject, NSDraggingInfo {
    /// Settable, because "who started this drag?" is the interesting variable:
    /// nil is a drop from outside the process, and a destination view here is
    /// an internal reorder. Defaults to nil so the existing cases read the
    /// same as before this property existed.
    var draggingSource: AnyObject?

    var draggingPasteboard: NSPasteboard { NSPasteboard.general }
    var draggingLocation: NSPoint { .zero }
    var draggingSourceOperationMask: NSDragOperation { .move }
}

final class ReorderRecipeTableSource: NSObject, NSTableViewDataSource {
    var items = ["alpha", "bravo", "charlie"]

    func numberOfRows(in tableView: NSTableView) -> Int { items.count }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        items[row]
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        "\(row)"
    }
}

final class ReorderRecipeOutlineSource: NSObject, NSOutlineViewDataSource {
    var roots = ["Alpha", "Bravo", "Charlie"]

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        item == nil ? roots.count : 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        roots[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        false
    }

    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        String(describing: item)
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item parent: Any?, childIndex index: Int) -> Bool {
        guard parent == nil,
              let moved = info.draggingPasteboard.string(forType: .string),
              let current = roots.firstIndex(of: moved) else {
            return false
        }
        roots.remove(at: current)
        let dest = index > current ? index - 1 : index
        roots.insert(moved, at: min(max(0, dest), roots.count))
        return true
    }
}

@MainActor
func testAppKitReorderRecipeEnablesAndAcceptsDrops() {
    // Table: reorder is opt-in — a `.move` local mask plus a data-source
    // pasteboard writer arms the drag (AppKit's recipe, no win* handler).
    let table = NSTableView(frame: NSMakeRect(0, 0, 200, 120))
    let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    table.addTableColumn(column)
    let source = ReorderRecipeTableSource()
    table.dataSource = source
    table.reloadData()
    expect(!table.winReorderDragEnabled(forRow: 0), "Reorder must not arm without a .move local mask.")
    table.setDraggingSourceOperationMask(.move, forLocal: true)
    expect(table.winReorderDragEnabled(forRow: 0), "A .move local mask + writer should arm reorder.")

    // Outline: the mapped reorder drop reaches the outline data source's
    // acceptDrop with the writer's item representation on the pasteboard.
    let outline = NSOutlineView(frame: NSMakeRect(0, 0, 240, 160))
    let name = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
    outline.addTableColumn(name)
    let outlineSource = ReorderRecipeOutlineSource()
    outline.outlineDataSource = outlineSource
    outline.setDraggingSourceOperationMask(.move, forLocal: true)
    outline.reloadData()
    expect(outline.winReorderDragEnabled(forRow: 2), "Outline reorder should arm via mask + item writer.")

    // Drop "Charlie" (row 2) at the top (index 0) of the root list.
    let accepted = outline.winAcceptOutlineReorderDrop(fromRows: IndexSet(integer: 2), toIndex: 0, info: TestDraggingInfo())
    expect(accepted, "The outline reorder drop should be accepted by the data source.")
    expect(outlineSource.roots == ["Charlie", "Alpha", "Bravo"], "The data-source acceptDrop should have moved the item. Got \(outlineSource.roots).")
}

final class ParityPercentFormatter: NumberFormatter, @unchecked Sendable {
    override func string(for obj: Any?) -> String? {
        guard let value = obj as? Double else { return nil }
        return "\(Int(value * 100))%"
    }
}

@MainActor
func testPanelIsRealizedAsAnOwnedWindow() {
    // AppKit: a panel is auxiliary to the window it serves — it floats above
    // its owner, minimizes with it, and stays out of the taskbar. Win32 spells
    // that as the panel's GWLP_HWNDPARENT (which sets the *owner* for a
    // non-WS_CHILD window); GTK spells it as gtk_window_set_transient_for. The
    // shared core just pairs them through the backend seam.
    let backend = InMemoryNativeControlBackend()
    let previousBackend = NSApplication.shared.nativeBackend
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        clearApplicationWindows()
    }

    let main = NSWindow(contentRect: NSMakeRect(0, 0, 480, 320),
                        styleMask: [.titled, .closable, .resizable],
                        backing: .buffered, defer: false)
    main.makeKeyAndOrderFront(nil)

    let panel = NSPanel(contentRect: NSMakeRect(0, 0, 240, 160),
                        styleMask: [.titled, .closable, .utilityWindow],
                        backing: .buffered, defer: false)
    let panelHandle = panel.realizeNativePeer()

    expect(backend.windowParents[panelHandle] == main.nativeHandle,
           "A panel should be realized as an owned window of the main window.")

    // A plain window is NOT owned — only panels are auxiliary.
    let plain = NSWindow(contentRect: NSMakeRect(0, 0, 200, 200),
                         styleMask: [.titled], backing: .buffered, defer: false)
    let plainHandle = plain.realizeNativePeer()
    expect(backend.windowParents[plainHandle] == nil,
           "A plain NSWindow must not be given an owner.")
}

func testControlClassHierarchyMatchesAppKit() {
    // AppKit: NSPathControl derives from NSControl, NOT NSTextField. It used to
    // derive from NSTextField here, which made `view as? NSTextField` match a
    // path control on Windows but not on macOS — and the framework itself tests
    // exactly that in NSPanel and NSToolbar to decide chrome and focus
    // behavior, so a path control was being handled as a text field.
    let pathControl = NSPathControl(frame: NSMakeRect(0, 0, 200, 24))
    testPathControlProperties(pathControl)
    testPathControlURLInitializer()
}

private func testPathControlProperties(_ pathControl: NSPathControl) {
    let pathControlAsAny: Any = pathControl
    expect(pathControlAsAny is NSControl, "NSPathControl must be an NSControl, as on AppKit.")
    expect(!(pathControlAsAny is NSTextField), "NSPathControl must NOT be an NSTextField — AppKit's is not.")

    // The properties that used to arrive via NSTextField are declared on
    // NSPathControl itself, because AppKit declares them there.
    pathControl.stringValue = "C:\\Demo"
    pathControl.isEditable = false
    pathControl.backgroundColor = .windowBackgroundColor
    expect(pathControl.stringValue == "C:\\Demo", "NSPathControl should carry its own stringValue.")
    expect(pathControl.backgroundColor != nil, "NSPathControl.backgroundColor is real AppKit API.")

    // NOTE: NSProgressIndicator is deliberately NOT asserted here. AppKit's
    // derives from NSView, ours from NSControl — a known divergence that is
    // tracked, not fixed, because re-parenting it compiles and passes this very
    // suite while crashing the running demo. Asserting the AppKit shape would
    // just make the suite red against a deliberate state; see
    // Docs/AppKitFaithfulnessIssues.md, "NSProgressIndicator superclass".

    // The URL initializer still populates the breadcrumb through the new path.
    // "C:\A\B" is three components on Windows — the drive plus two directories.
}

private func testPathControlURLInitializer() {
    #if os(Windows)
    let componentTestPath = "C:\\A\\B"
    let expectedPathComponents = ["C:", "A", "B"]
    #else
    let componentTestPath = "/A/B"
    let expectedPathComponents = ["A", "B"]
    #endif
    let urlControl = NSPathControl(url: URL(fileURLWithPath: componentTestPath), frame: NSMakeRect(0, 0, 200, 24))
    expect(urlControl.pathComponentCells.map(\.title) == expectedPathComponents,
           "NSPathControl(url:) should build one cell per component. Got \(urlControl.pathComponentCells.map(\.title)).")
    expect(urlControl.stringValue.contains("A"), "NSPathControl(url:) should show the path.")
}

