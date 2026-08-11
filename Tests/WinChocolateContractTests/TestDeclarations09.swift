import WinChocolate

@MainActor
func testWindowSelectNextKeyViewSkipsDisabledExplicitTarget() {
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 100, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: InMemoryNativeControlBackend()
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 100, 100))
    let first = NSButton(title: "First", frame: NSMakeRect(0, 0, 40, 20))
    let disabled = NSButton(title: "Disabled", frame: NSMakeRect(0, 24, 60, 20))
    let fallback = NSButton(title: "Fallback", frame: NSMakeRect(0, 48, 60, 20))

    disabled.isEnabled = false
    first.nextKeyView = disabled
    disabled.nextKeyView = fallback
    contentView.addSubview(first)
    contentView.addSubview(disabled)
    contentView.addSubview(fallback)
    window.contentView = contentView
    window.realizeNativePeer()

    expect(window.makeFirstResponder(first), "Window did not accept first key view.")

    window.selectNextKeyView(nil)

    expect(window.firstResponder === fallback, "Window did not skip disabled key view target.")
}

@MainActor
func testWindowSelectNextKeyViewSkipsHiddenContainerChildren() {
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 140, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: InMemoryNativeControlBackend()
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 140, 100))
    let first = NSButton(title: "First", frame: NSMakeRect(0, 0, 40, 20))
    let hiddenContainer = NSView(frame: NSMakeRect(0, 24, 80, 48))
    let hiddenChild = NSButton(title: "Hidden", frame: NSMakeRect(0, 0, 60, 20))
    let fallback = NSButton(title: "Fallback", frame: NSMakeRect(0, 76, 60, 20))

    hiddenContainer.isHidden = true
    first.nextKeyView = hiddenChild
    hiddenChild.nextKeyView = fallback
    hiddenContainer.addSubview(hiddenChild)
    contentView.addSubview(first)
    contentView.addSubview(hiddenContainer)
    contentView.addSubview(fallback)
    window.contentView = contentView
    window.realizeNativePeer()

    expect(window.makeFirstResponder(first), "Window did not accept first key view.")

    window.selectNextKeyView(nil)

    expect(window.firstResponder === fallback, "Window did not skip hidden key view container children.")
}

@MainActor
func testNativeMouseDownDispatchesToView() {
    let backend = InMemoryNativeControlBackend()
    let view = RecordingView(frame: NSMakeRect(0, 0, 100, 100))
    let handle = view.realizeNativePeer(in: backend, parent: nil)
    let event = NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(12, 34))

    backend.mouseDownActions[handle]?(event)

    expect(view.mouseDownCount == 1, "Native mouse-down action did not reach view.")
    expect(view.lastEvent == event, "Native mouse-down event was not forwarded intact.")
}

@MainActor
func testNativeMouseDownOnControlMakesControlFirstResponder() {
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

    contentView.addSubview(button)
    window.contentView = contentView
    window.realizeNativePeer()

    guard let handle = button.nativeHandle else {
        fatalError("Button did not realize.")
    }

    backend.mouseDownActions[handle]?(NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(2, 3)))

    expect(window.firstResponder === button, "Native mouse-down on control did not make it first responder.")
    expect(backend.focusedHandle == handle, "Native mouse-down on control did not request native focus.")
}

@MainActor
func testNativeMouseUpDispatchesToView() {
    let backend = InMemoryNativeControlBackend()
    let view = RecordingView(frame: NSMakeRect(0, 0, 100, 100))
    let handle = view.realizeNativePeer(in: backend, parent: nil)
    let event = NSEvent(type: .leftMouseUp, locationInWindow: NSMakePoint(56, 78))

    backend.mouseUpActions[handle]?(event)

    expect(view.mouseUpCount == 1, "Native mouse-up action did not reach view.")
    expect(view.lastEvent == event, "Native mouse-up event was not forwarded intact.")
}

@MainActor
func testNativeMouseMovedDispatchesToView() {
    let backend = InMemoryNativeControlBackend()
    let view = RecordingView(frame: NSMakeRect(0, 0, 100, 100))
    let handle = view.realizeNativePeer(in: backend, parent: nil)
    let event = NSEvent(type: .mouseMoved, locationInWindow: NSMakePoint(7, 9), modifierFlags: [.shift])

    backend.mouseMovedActions[handle]?(event)

    expect(view.mouseMovedCount == 1, "Native mouse-moved action did not reach view.")
    expect(view.lastEvent == event, "Native mouse-moved event was not forwarded intact.")
}

@MainActor
func testNativeMouseDraggedDispatchesToView() {
    let backend = InMemoryNativeControlBackend()
    let view = RecordingView(frame: NSMakeRect(0, 0, 100, 100))
    let handle = view.realizeNativePeer(in: backend, parent: nil)
    let event = NSEvent(type: .leftMouseDragged, locationInWindow: NSMakePoint(11, 13), modifierFlags: [.option])

    backend.mouseDraggedActions[handle]?(event)

    expect(view.mouseDraggedCount == 1, "Native mouse-dragged action did not reach view.")
    expect(view.lastEvent == event, "Native mouse-dragged event was not forwarded intact.")
}

@MainActor
func testNativeKeyDownDispatchesToView() {
    let backend = InMemoryNativeControlBackend()
    let view = RecordingView(frame: NSMakeRect(0, 0, 100, 100))
    let handle = view.realizeNativePeer(in: backend, parent: nil)
    let event = NSEvent(type: .keyDown, locationInWindow: NSMakePoint(0, 0), keyCode: 65, characters: "A", modifierFlags: [.shift])

    backend.keyDownActions[handle]?(event)

    expect(view.keyDownCount == 1, "Native key-down action did not reach view.")
    expect(view.lastEvent == event, "Native key-down event was not forwarded intact.")
}

@MainActor
func testNativeKeyUpDispatchesToView() {
    let backend = InMemoryNativeControlBackend()
    let view = RecordingView(frame: NSMakeRect(0, 0, 100, 100))
    let handle = view.realizeNativePeer(in: backend, parent: nil)
    let event = NSEvent(type: .keyUp, locationInWindow: NSMakePoint(0, 0), keyCode: 65, characters: "a")

    backend.keyUpActions[handle]?(event)

    expect(view.keyUpCount == 1, "Native key-up action did not reach view.")
    expect(view.lastEvent == event, "Native key-up event was not forwarded intact.")
}

@MainActor
func testControlClosureActionIsInvoked() {
    let button = NSButton(title: "Run", frame: NSMakeRect(0, 0, 80, 24))
    var actionCount = 0

    button.onAction = { control in
        expect(control === button, "Action control was not the sender.")
        actionCount += 1
    }

    button.sendAction()

    expect(actionCount == 1, "Action closure was not invoked once.")
}

@MainActor
func testButtonPerformClickHonorsEnabledState() {
    let button = NSButton(title: "Run", frame: NSMakeRect(0, 0, 80, 24))
    var actionCount = 0

    button.onAction = { _ in
        actionCount += 1
    }

    button.performClick(nil)
    button.isEnabled = false
    button.performClick(nil)

    expect(actionCount == 1, "Disabled button still sent its action.")
}

@MainActor
func testControlCompatibilityMetadataStoresValues() {
    let control = NSControl(frame: NSMakeRect(0, 0, 80, 24))

    control.objectValue = "Value"
    control.isContinuous = true

    expect(control.objectValue as? String == "Value", "Control objectValue was not stored.")
    expect(control.isContinuous, "Control continuous flag was not stored.")
}

@MainActor
func testSwitchButtonTogglesStateOnPerformClick() {
    let checkbox = NSButton(title: "Check", frame: NSMakeRect(0, 0, 120, 24))
    checkbox.setButtonType(.switch)

    checkbox.performClick(nil)
    expect(checkbox.state == .on, "Switch button did not toggle on.")

    checkbox.performClick(nil)
    expect(checkbox.state == .off, "Switch button did not toggle off.")
}

@MainActor
func testButtonMixedStateAndCompatibilityProperties() {
    let checkbox = NSButton(title: "Check", frame: NSMakeRect(0, 0, 120, 24))

    checkbox.setButtonType(.switch)
    checkbox.allowsMixedState = true
    checkbox.keyEquivalent = "\r"
    checkbox.isBordered = false

    checkbox.setNextState()
    expect(checkbox.state == .on, "Mixed-state button did not move from off to on.")
    checkbox.setNextState()
    expect(checkbox.state == .mixed, "Mixed-state button did not move from on to mixed.")
    checkbox.setNextState()
    expect(checkbox.state == .off, "Mixed-state button did not move from mixed to off.")
    expect(checkbox.keyEquivalent == "\r", "Button key equivalent was not stored.")
    expect(!checkbox.isBordered, "Button bordered flag was not stored.")
}

@MainActor
func testRadioButtonClearsSiblingRadioButtons() {
    let parent = NSView(frame: NSMakeRect(0, 0, 300, 100))
    let first = NSButton(title: "First", frame: NSMakeRect(0, 0, 80, 24))
    let second = NSButton(title: "Second", frame: NSMakeRect(90, 0, 80, 24))
    first.setButtonType(.radio)
    second.setButtonType(.radio)
    parent.addSubview(first)
    parent.addSubview(second)

    first.performClick(nil)
    second.performClick(nil)

    expect(first.state == .off, "First radio button was not cleared.")
    expect(second.state == .on, "Second radio button was not selected.")
}

@MainActor
func testRealizedViewStatePropagatesToBackend() {
    let backend = InMemoryNativeControlBackend()
    let view = NSView(frame: NSMakeRect(0, 0, 100, 100))
    let handle = view.realizeNativePeer(in: backend, parent: nil)

    view.frame = NSMakeRect(10, 20, 120, 140)
    view.isHidden = true

    expect(backend.records[handle]?.frame == NSMakeRect(10, 20, 120, 140), "Frame update did not reach backend.")
    expect(backend.records[handle]?.isHidden == true, "Hidden state did not reach backend.")
}

@MainActor
func testWindowTitleAndFramePropagateToBackend() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 100, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let handle = window.realizeNativePeer()

    window.title = "Updated"
    window.setFrame(NSMakeRect(10, 20, 300, 200), display: true)

    expect(backend.records[handle]?.usesMainMenu == true, "Normal windows should request the application main menu.")
    expect(backend.records[handle]?.text == "Updated", "Window title update did not reach backend.")
    expect(backend.records[handle]?.frame == NSMakeRect(10, 20, 300, 200), "Window frame update did not reach backend.")
}

@MainActor
func testWindowContentSizeAndCenterUpdateFrame() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(10, 20, 100, 80),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 100, 80))
    window.contentView = contentView
    let handle = window.realizeNativePeer()

    window.setContentSize(NSMakeSize(240, 160))

    expect(window.frame == NSMakeRect(10, 20, 240, 160), "setContentSize did not update window frame.")
    expect(contentView.frame == NSMakeRect(0, 0, 240, 160), "setContentSize did not update content view frame.")
    expect(window.contentLayoutRect == NSMakeRect(0, 0, 240, 160), "contentLayoutRect did not reflect content size.")
    expect(backend.records[handle]?.frame == NSMakeRect(10, 20, 240, 160), "setContentSize did not reach backend.")

    window.center()

    expect(window.frame == NSMakeRect(392, 304, 240, 160), "center did not use the expected default screen frame.")
    expect(backend.records[handle]?.frame == NSMakeRect(392, 304, 240, 160), "center did not reach backend.")
}

@MainActor
func testNativeWindowResizeUpdatesContentAndAutoresizesSubviews() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(10, 20, 200, 120),
        styleMask: [.titled, .resizable],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 200, 120))
    let stretchView = NSView(frame: NSMakeRect(10, 10, 80, 30))
    let trailingView = NSView(frame: NSMakeRect(150, 80, 30, 20))
    stretchView.autoresizingMask = [.width]
    trailingView.autoresizingMask = [.minXMargin, .minYMargin]
    contentView.addSubview(stretchView)
    contentView.addSubview(trailingView)
    window.contentView = contentView
    let handle = window.realizeNativePeer()

    guard let resizeAction = backend.windowResizeActions[handle] else {
        fatalError("Window did not register native resize action.")
    }

    resizeAction(NSMakeSize(260, 180))

    expect(window.frame.size == NSMakeSize(260, 180), "Native resize did not update window frame size.")
    expect(contentView.frame == NSMakeRect(0, 0, 260, 180), "Native resize did not update content view frame.")
    let contentHandle = requireValue(contentView.nativeHandle, "Content view should have a native handle.")
    expect(backend.records[contentHandle]?.frame == contentView.frame, "Native resize did not sync content view frame to backend.")
    expect(stretchView.frame == NSMakeRect(10, 10, 140, 30), "Autoresizing width mask did not stretch subview.")
    expect(trailingView.frame == NSMakeRect(210, 140, 30, 20), "Autoresizing margins did not move trailing subview.")
}

@MainActor
func testPanelStoresPanelStateAndOrdersFront() {
    clearApplicationWindows()

    let backend = InMemoryNativeControlBackend()
    let panel = NSPanel(
        contentRect: NSMakeRect(20, 30, 240, 120),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )

    panel.title = "Inspector"
    panel.isFloatingPanel = true
    panel.hidesOnDeactivate = true
    panel.becomesKeyOnlyIfNeeded = true
    panel.worksWhenModal = true
    panel.orderFrontRegardless()

    guard let handle = panel.nativeHandle else {
        fatalError("Panel did not realize native peer.")
    }

    expect(panel.isFloatingPanel, "Panel floating flag was not stored.")
    expect(panel.hidesOnDeactivate, "Panel deactivate-hiding flag was not stored.")
    expect(panel.becomesKeyOnlyIfNeeded, "Panel key-only-if-needed flag was not stored.")
    expect(panel.worksWhenModal, "Panel modal interaction flag was not stored.")
    expect(backend.records[handle]?.kind == "window", "Panel did not use the window backend peer.")
    expect(backend.records[handle]?.text == "Inspector", "Panel title was not synced.")
    expect(backend.records[handle]?.usesMainMenu == false, "Panel should not request the application main menu.")
    expect(NSApplication.shared.windows.contains { $0 === panel }, "Panel was not tracked in application windows.")
    expect(NSApplication.shared.keyWindow !== panel, "orderFrontRegardless should not force key window in this slice.")

    guard let closeAction = backend.windowCloseActions[handle] else {
        fatalError("Panel did not register native close cleanup.")
    }

    closeAction()

    expect(panel.nativeHandle == nil, "Native panel close did not clear panel handle.")
    expect(!NSApplication.shared.windows.contains { $0 === panel }, "Native panel close did not remove panel from application windows.")
    expect(!backend.didTerminateApplication, "Native panel close should not terminate the application.")

    panel.orderFrontRegardless()

    expect(panel.nativeHandle != nil, "Panel did not reopen after native close.")

    clearApplicationWindows()
}

@MainActor
func testPopoverShowsClosesAndReopensFromAnchorView() {
    clearApplicationWindows()

    let previousBackend = NSApplication.shared.nativeBackend
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        clearApplicationWindows()
    }

    let window = NSWindow(
        contentRect: NSMakeRect(100, 120, 400, 300),
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 400, 300))
    let anchor = NSButton(title: "Anchor", frame: NSMakeRect(24, 32, 80, 30))
    contentView.addSubview(anchor)
    window.contentView = contentView
    window.makeKeyAndOrderFront(nil)

    let popoverContent = NSView(frame: NSMakeRect(0, 0, 160, 90))
    let popover = NSPopover()
    popover.animates = false
    popover.behavior = .transient
    popover.contentSize = NSMakeSize(160, 90)
    popover.contentViewController = NSViewController(view: popoverContent)
    popover.show(relativeTo: NSMakeRect(4, 6, 20, 18), of: anchor, preferredEdge: .maxY)

    guard let panel = NSApplication.shared.windows.compactMap({ $0 as? NSPanel }).last,
          let panelHandle = panel.nativeHandle else {
        fatalError("Popover did not create a panel host.")
    }

    expect(popover.isShown, "Popover did not report shown state.")
    expect(panel.contentView === popoverContent, "Popover did not install controller view as panel content.")
    expect(panel.styleMask == .borderless, "Popover host should use a borderless panel style.")
    expect(backend.records[panelHandle]?.usesMainMenu == false, "Popover host should not request the application main menu.")
    expect(backend.records[panelHandle]?.frame == NSMakeRect(128, 184, 160, 90), "Popover did not position relative to anchor view.")

    popover.performClose(nil)

    expect(!popover.isShown, "Popover did not report closed state.")
    expect(panel.nativeHandle == nil, "Popover close did not close the host panel.")
    expect(!NSApplication.shared.windows.contains { $0 === panel }, "Popover close did not remove the host panel from application windows.")

    popover.show(relativeTo: NSMakeRect(4, 6, 20, 18), of: anchor, preferredEdge: .maxX)

    expect(popover.isShown, "Popover did not report shown state after reopening.")
    expect(panel.nativeHandle != nil, "Popover host panel did not reopen.")
}

@MainActor
func testPopoverFlipsWhenClipped() {
    clearApplicationWindows()
    let previousBackend = NSApplication.shared.nativeBackend
    let backend = InMemoryNativeControlBackend()
    backend.testScreenFrame = NSRect(x: 0, y: 0, width: 400, height: 300)
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        clearApplicationWindows()
    }

    // Anchor near the bottom of a short screen; a `.maxY` popover would run off.
    let window = NSWindow(contentRect: NSMakeRect(50, 250, 300, 40), styleMask: [.titled], backing: .buffered, defer: false)
    let content = NSView(frame: NSMakeRect(0, 0, 300, 40))
    let anchor = NSButton(title: "A", frame: NSMakeRect(10, 5, 40, 24))
    content.addSubview(anchor)
    window.contentView = content
    window.makeKeyAndOrderFront(nil)

    let popover = NSPopover()
    popover.behavior = .applicationDefined
    popover.contentSize = NSMakeSize(200, 200)
    popover.contentViewController = NSViewController(view: NSView(frame: NSMakeRect(0, 0, 200, 200)))
    popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .maxY)

    // The 200-tall popover below the anchor exceeds the 300-tall screen, so it flips.
    expect(popover.winResolvedEdge == .minY, "Popover did not flip an off-screen placement to the opposite edge.")

    // A placement that fits keeps the preferred edge.
    let popover2 = NSPopover()
    popover2.behavior = .applicationDefined
    popover2.contentSize = NSMakeSize(80, 40)
    popover2.contentViewController = NSViewController(view: NSView(frame: NSMakeRect(0, 0, 80, 40)))
    popover2.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .maxX)
    expect(popover2.winResolvedEdge == .maxX, "Popover flipped a placement that fit on screen.")
}

@MainActor
func testPopoverAnimatesFadesHost() {
    clearApplicationWindows()

    let previousBackend = NSApplication.shared.nativeBackend
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend
    defer {
        NSApplication.shared.nativeBackend = previousBackend
        clearApplicationWindows()
    }

    let window = NSWindow(
        contentRect: NSMakeRect(100, 120, 400, 300),
        styleMask: [.titled],
        backing: .buffered,
        defer: false
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 400, 300))
    let anchor = NSButton(title: "Anchor", frame: NSMakeRect(24, 32, 80, 30))
    contentView.addSubview(anchor)
    window.contentView = contentView
    window.makeKeyAndOrderFront(nil)

    let popover = NSPopover()
    popover.animates = true
    popover.behavior = .applicationDefined
    popover.contentSize = NSMakeSize(160, 90)
    popover.contentViewController = NSViewController(view: NSView(frame: NSMakeRect(0, 0, 160, 90)))
    popover.show(relativeTo: NSMakeRect(4, 6, 20, 18), of: anchor, preferredEdge: .maxY)

    guard let panel = NSApplication.shared.windows.compactMap({ $0 as? NSPanel }).last,
          let panelHandle = panel.nativeHandle else {
        fatalError("Popover did not create a panel host.")
    }

    // An animated show fades the host in rather than a plain show.
    expect(backend.fadedWindows[panelHandle] == true, "Animated popover did not fade its host in.")
    expect(backend.records[panelHandle]?.isHidden == false, "Faded-in popover host should be visible.")

    popover.performClose(nil)

    // An animated close fades the host out before it is destroyed.
    expect(backend.fadedWindows[panelHandle] == false, "Animated popover did not fade its host out on close.")
}

