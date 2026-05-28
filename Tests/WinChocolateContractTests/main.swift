import WinChocolate

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fatalError(message)
    }
}

func clearApplicationWindows() {
    for window in NSApplication.shared.windows {
        NSApplication.shared.removeWindowsItem(window)
    }
}

func testWindowRealizationCreatesNativeHierarchy() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(10, 20, 320, 240),
        styleMask: [.titled, .closable, .resizable],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    window.title = "Chocolate"

    let contentView = NSView(frame: NSMakeRect(0, 0, 320, 240))
    let button = NSButton(title: "OK", frame: NSMakeRect(20, 20, 80, 30))
    contentView.addSubview(button)
    window.contentView = contentView

    let windowHandle = window.realizeNativePeer()

    expect(backend.records[windowHandle]?.kind == "window", "Window native record was not created.")
    expect(backend.records[windowHandle]?.text == "Chocolate", "Window title was not recorded.")
    expect(contentView.nativeHandle != nil, "Content view was not realized.")
    expect(button.nativeHandle != nil, "Button was not realized.")
    expect(backend.records[button.nativeHandle!]?.kind == "button", "Button native record was not created.")
    expect(backend.records[button.nativeHandle!]?.parent == contentView.nativeHandle, "Button parent was not content view.")
}

func testViewHierarchyMaintainsSuperviewOwnership() {
    let firstParent = NSView(frame: NSMakeRect(0, 0, 100, 100))
    let secondParent = NSView(frame: NSMakeRect(0, 0, 100, 100))
    let child = NSView(frame: NSMakeRect(0, 0, 20, 20))

    firstParent.addSubview(child)
    secondParent.addSubview(child)

    expect(firstParent.subviews.isEmpty, "Child remained in old parent.")
    expect(secondParent.subviews.count == 1, "Child was not added to new parent.")
    expect(child.superview === secondParent, "Child superview was not updated.")
}

func testViewInsertionReplacementTagsAndDescendants() {
    let parent = NSView(frame: NSMakeRect(0, 0, 200, 200))
    let first = NSView(frame: NSMakeRect(0, 0, 20, 20))
    let second = NSView(frame: NSMakeRect(0, 0, 20, 20))
    let belowSecond = NSView(frame: NSMakeRect(0, 0, 20, 20))
    let aboveFirst = NSView(frame: NSMakeRect(0, 0, 20, 20))
    let replacement = NSView(frame: NSMakeRect(0, 0, 20, 20))

    first.tag = 11
    replacement.tag = 22

    parent.addSubview(first)
    parent.addSubview(second)
    parent.addSubview(belowSecond, positioned: .below, relativeTo: second)
    parent.addSubview(aboveFirst, positioned: .above, relativeTo: first)

    expect(parent.subviews.count == 4, "Positioned subviews were not added.")
    expect(parent.subviews[0] === first, "First subview moved unexpectedly.")
    expect(parent.subviews[1] === aboveFirst, "Subview was not inserted above the reference view.")
    expect(parent.subviews[2] === belowSecond, "Subview was not inserted below the reference view.")
    expect(parent.subviews[3] === second, "Second subview moved unexpectedly.")
    expect(aboveFirst.isDescendant(of: parent), "Subview did not report descendant relationship.")
    expect(!parent.isDescendant(of: aboveFirst), "Ancestor reported descendant relationship.")
    expect(parent.viewWithTag(11) === first, "viewWithTag did not find existing tagged view.")

    parent.replaceSubview(first, with: replacement)

    expect(parent.subviews[0] === replacement, "Replacement did not preserve subview position.")
    expect(first.superview == nil, "Replaced view still had a superview.")
    expect(replacement.superview === parent, "Replacement superview was not updated.")
    expect(parent.viewWithTag(22) === replacement, "viewWithTag did not find replacement view.")
}

func testGeometryConvenienceFunctions() {
    let rect = NSMakeRect(10, 20, 100, 50)

    expect(NSZeroPoint == NSMakePoint(0, 0), "NSZeroPoint was not zero.")
    expect(NSZeroSize == NSMakeSize(0, 0), "NSZeroSize was not zero.")
    expect(NSZeroRect == NSMakeRect(0, 0, 0, 0), "NSZeroRect was not zero.")
    expect(NSMinX(rect) == 10, "NSMinX returned the wrong value.")
    expect(NSMidX(rect) == 60, "NSMidX returned the wrong value.")
    expect(NSMaxX(rect) == 110, "NSMaxX returned the wrong value.")
    expect(NSMinY(rect) == 20, "NSMinY returned the wrong value.")
    expect(NSMidY(rect) == 45, "NSMidY returned the wrong value.")
    expect(NSMaxY(rect) == 70, "NSMaxY returned the wrong value.")
    expect(NSWidth(rect) == 100, "NSWidth returned the wrong value.")
    expect(NSHeight(rect) == 50, "NSHeight returned the wrong value.")
    expect(NSPointInRect(NSMakePoint(10, 20), rect), "NSPointInRect rejected the minimum edge.")
    expect(!NSPointInRect(NSMakePoint(110, 70), rect), "NSPointInRect included the maximum edge.")
    expect(NSOffsetRect(rect, 3, 4) == NSMakeRect(13, 24, 100, 50), "NSOffsetRect returned the wrong rect.")
    expect(NSInsetRect(rect, 5, 6) == NSMakeRect(15, 26, 90, 38), "NSInsetRect returned the wrong rect.")
    expect(NSEqualRects(rect, NSMakeRect(10, 20, 100, 50)), "NSEqualRects rejected equal rects.")
}

func testViewCoordinateConversionAndHitTesting() {
    let root = NSView(frame: NSMakeRect(0, 0, 300, 300))
    let parent = NSView(frame: NSMakeRect(20, 30, 200, 200))
    let child = NSView(frame: NSMakeRect(5, 7, 40, 50))
    let hiddenChild = NSView(frame: NSMakeRect(6, 8, 10, 10))

    root.addSubview(parent)
    parent.addSubview(child)
    child.addSubview(hiddenChild)
    hiddenChild.isHidden = true

    expect(child.convert(NSMakePoint(1, 2), to: root) == NSMakePoint(26, 39), "Point conversion to ancestor failed.")
    expect(root.convert(NSMakePoint(26, 39), to: child) == NSMakePoint(1, 2), "Point conversion from ancestor failed.")
    expect(parent.convert(NSMakeRect(1, 2, 10, 11), from: child) == NSMakeRect(6, 9, 10, 11), "Rect conversion from child failed.")
    expect(root.hitTest(NSMakePoint(26, 39)) === child, "Hit testing did not return deepest visible child.")
    expect(root.hitTest(NSMakePoint(31, 46)) === child, "Hit testing returned hidden child.")
    expect(root.hitTest(NSMakePoint(250, 250)) === root, "Hit testing did not return root for empty visible area.")
    expect(root.hitTest(NSMakePoint(400, 400)) == nil, "Hit testing accepted a point outside bounds.")
}

final class RecordingResponder: NSResponder {
    var mouseDownCount = 0
    var keyDownCount = 0

    override func mouseDown(with event: NSEvent) {
        mouseDownCount += 1
    }

    override func keyDown(with event: NSEvent) {
        keyDownCount += 1
    }
}

final class RefusingResponder: NSResponder {
    override var acceptsFirstResponder: Bool {
        true
    }

    override func resignFirstResponder() -> Bool {
        false
    }
}

final class RecordingView: NSView {
    var mouseDownCount = 0
    var mouseUpCount = 0
    var mouseMovedCount = 0
    var keyDownCount = 0
    var keyUpCount = 0
    var lastEvent: NSEvent?

    override func mouseDown(with event: NSEvent) {
        mouseDownCount += 1
        lastEvent = event
    }

    override func mouseUp(with event: NSEvent) {
        mouseUpCount += 1
        lastEvent = event
    }

    override func mouseMoved(with event: NSEvent) {
        mouseMovedCount += 1
        lastEvent = event
    }

    override func keyDown(with event: NSEvent) {
        keyDownCount += 1
        lastEvent = event
    }

    override func keyUp(with event: NSEvent) {
        keyUpCount += 1
        lastEvent = event
    }
}

func testSubviewResponderChainTargetsSuperview() {
    let parent = NSView(frame: NSMakeRect(0, 0, 100, 100))
    let child = NSView(frame: NSMakeRect(0, 0, 20, 20))

    parent.addSubview(child)

    expect(child.nextResponder === parent, "Subview next responder was not its superview.")

    child.removeFromSuperview()

    expect(child.nextResponder == nil, "Subview next responder was not cleared on removal.")
}

func testResponderForwardsUnhandledEvents() {
    let child = NSResponder()
    let parent = RecordingResponder()
    let mouseEvent = NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(4, 5))
    let keyEvent = NSEvent(type: .keyDown, locationInWindow: NSMakePoint(0, 0))

    child.nextResponder = parent
    child.mouseDown(with: mouseEvent)
    child.keyDown(with: keyEvent)

    expect(parent.mouseDownCount == 1, "Mouse event did not forward to next responder.")
    expect(parent.keyDownCount == 1, "Key event did not forward to next responder.")
}

func testWindowIsContentViewNextResponder() {
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 100, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: InMemoryNativeControlBackend()
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 100, 100))

    window.contentView = contentView

    expect(contentView.nextResponder === window, "Window was not content view's next responder.")
}

func testWindowMakeFirstResponderFocusesNativeView() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 100, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 100, 100))

    window.contentView = contentView
    window.realizeNativePeer()

    expect(window.makeFirstResponder(contentView), "Window did not accept content view as first responder.")
    expect(window.firstResponder === contentView, "Window first responder was not updated.")
    expect(backend.focusedHandle == contentView.nativeHandle, "Backend did not receive native focus request.")
}

func testWindowMakeFirstResponderHonorsResignFailure() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 100, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let refusing = RefusingResponder()
    let next = NSView(frame: NSMakeRect(0, 0, 10, 10))

    expect(window.makeFirstResponder(refusing), "Window did not accept initial responder.")
    expect(!window.makeFirstResponder(next), "Window ignored first responder resign failure.")
    expect(window.firstResponder === refusing, "Window first responder changed after resign failure.")
}

func testApplicationTracksWindowListAndKeyMainWindow() {
    clearApplicationWindows()

    let first = NSWindow(
        contentRect: NSMakeRect(0, 0, 100, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: InMemoryNativeControlBackend()
    )
    let second = NSWindow(
        contentRect: NSMakeRect(0, 0, 100, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: InMemoryNativeControlBackend()
    )

    first.realizeNativePeer()
    second.realizeNativePeer()
    second.makeKeyAndOrderFront(nil)

    expect(NSApp === NSApplication.shared, "NSApp did not alias NSApplication.shared.")
    expect(NSApplication.shared.windows.contains { $0 === first }, "Application did not track first window.")
    expect(NSApplication.shared.windows.contains { $0 === second }, "Application did not track second window.")
    expect(NSApplication.shared.keyWindow === second, "Application key window was not updated.")
    expect(NSApplication.shared.mainWindow === second, "Application main window was not updated.")
    expect(second.isKeyWindow, "Window did not report key window state.")
    expect(second.isMainWindow, "Window did not report main window state.")

    second.close()

    expect(NSApplication.shared.keyWindow == nil, "Closing key window did not clear application key window.")
    expect(NSApplication.shared.mainWindow == nil, "Closing main window did not clear application main window.")
    expect(!NSApplication.shared.windows.contains { $0 === second }, "Closing window did not remove it from application windows.")

    clearApplicationWindows()
}

func testWindowSelectNextAndPreviousKeyView() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 100, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 100, 100))
    let first = NSButton(title: "First", frame: NSMakeRect(0, 0, 40, 20))
    let second = NSButton(title: "Second", frame: NSMakeRect(0, 24, 40, 20))

    first.nextKeyView = second
    second.previousKeyView = first
    contentView.addSubview(first)
    contentView.addSubview(second)
    window.contentView = contentView
    window.realizeNativePeer()

    expect(window.makeFirstResponder(first), "Window did not accept first key view.")

    window.selectNextKeyView(nil)

    expect(window.firstResponder === second, "Window did not select next key view.")
    expect(backend.focusedHandle == second.nativeHandle, "Backend focus did not move to next key view.")

    window.selectPreviousKeyView(nil)

    expect(window.firstResponder === first, "Window did not select previous key view.")
    expect(backend.focusedHandle == first.nativeHandle, "Backend focus did not move to previous key view.")
}

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

func testNativeMouseDownDispatchesToView() {
    let backend = InMemoryNativeControlBackend()
    let view = RecordingView(frame: NSMakeRect(0, 0, 100, 100))
    let handle = view.realizeNativePeer(in: backend, parent: nil)
    let event = NSEvent(type: .leftMouseDown, locationInWindow: NSMakePoint(12, 34))

    backend.mouseDownActions[handle]?(event)

    expect(view.mouseDownCount == 1, "Native mouse-down action did not reach view.")
    expect(view.lastEvent == event, "Native mouse-down event was not forwarded intact.")
}

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

func testNativeMouseUpDispatchesToView() {
    let backend = InMemoryNativeControlBackend()
    let view = RecordingView(frame: NSMakeRect(0, 0, 100, 100))
    let handle = view.realizeNativePeer(in: backend, parent: nil)
    let event = NSEvent(type: .leftMouseUp, locationInWindow: NSMakePoint(56, 78))

    backend.mouseUpActions[handle]?(event)

    expect(view.mouseUpCount == 1, "Native mouse-up action did not reach view.")
    expect(view.lastEvent == event, "Native mouse-up event was not forwarded intact.")
}

func testNativeMouseMovedDispatchesToView() {
    let backend = InMemoryNativeControlBackend()
    let view = RecordingView(frame: NSMakeRect(0, 0, 100, 100))
    let handle = view.realizeNativePeer(in: backend, parent: nil)
    let event = NSEvent(type: .mouseMoved, locationInWindow: NSMakePoint(7, 9), modifierFlags: [.shift])

    backend.mouseMovedActions[handle]?(event)

    expect(view.mouseMovedCount == 1, "Native mouse-moved action did not reach view.")
    expect(view.lastEvent == event, "Native mouse-moved event was not forwarded intact.")
}

func testNativeKeyDownDispatchesToView() {
    let backend = InMemoryNativeControlBackend()
    let view = RecordingView(frame: NSMakeRect(0, 0, 100, 100))
    let handle = view.realizeNativePeer(in: backend, parent: nil)
    let event = NSEvent(type: .keyDown, locationInWindow: NSMakePoint(0, 0), keyCode: 65, characters: "A", modifierFlags: [.shift])

    backend.keyDownActions[handle]?(event)

    expect(view.keyDownCount == 1, "Native key-down action did not reach view.")
    expect(view.lastEvent == event, "Native key-down event was not forwarded intact.")
}

func testNativeKeyUpDispatchesToView() {
    let backend = InMemoryNativeControlBackend()
    let view = RecordingView(frame: NSMakeRect(0, 0, 100, 100))
    let handle = view.realizeNativePeer(in: backend, parent: nil)
    let event = NSEvent(type: .keyUp, locationInWindow: NSMakePoint(0, 0), keyCode: 65, characters: "a")

    backend.keyUpActions[handle]?(event)

    expect(view.keyUpCount == 1, "Native key-up action did not reach view.")
    expect(view.lastEvent == event, "Native key-up event was not forwarded intact.")
}

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

func testSwitchButtonTogglesStateOnPerformClick() {
    let checkbox = NSButton(title: "Check", frame: NSMakeRect(0, 0, 120, 24))
    checkbox.setButtonType(.switchButton)

    checkbox.performClick(nil)
    expect(checkbox.state == .on, "Switch button did not toggle on.")

    checkbox.performClick(nil)
    expect(checkbox.state == .off, "Switch button did not toggle off.")
}

func testRadioButtonClearsSiblingRadioButtons() {
    let parent = NSView(frame: NSMakeRect(0, 0, 300, 100))
    let first = NSButton(title: "First", frame: NSMakeRect(0, 0, 80, 24))
    let second = NSButton(title: "Second", frame: NSMakeRect(90, 0, 80, 24))
    first.setButtonType(.radioButton)
    second.setButtonType(.radioButton)
    parent.addSubview(first)
    parent.addSubview(second)

    first.performClick(nil)
    second.performClick(nil)

    expect(first.state == .off, "First radio button was not cleared.")
    expect(second.state == .on, "Second radio button was not selected.")
}

func testRealizedViewStatePropagatesToBackend() {
    let backend = InMemoryNativeControlBackend()
    let view = NSView(frame: NSMakeRect(0, 0, 100, 100))
    let handle = view.realizeNativePeer(in: backend, parent: nil)

    view.frame = NSMakeRect(10, 20, 120, 140)
    view.isHidden = true

    expect(backend.records[handle]?.frame == NSMakeRect(10, 20, 120, 140), "Frame update did not reach backend.")
    expect(backend.records[handle]?.isHidden == true, "Hidden state did not reach backend.")
}

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

    expect(backend.records[handle]?.text == "Updated", "Window title update did not reach backend.")
    expect(backend.records[handle]?.frame == NSMakeRect(10, 20, 300, 200), "Window frame update did not reach backend.")
}

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

func testEditableTextFieldUsesEditableNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let textField = NSTextField(string: "Seed", frame: NSMakeRect(0, 0, 120, 24))
    textField.isEditable = true

    let handle = textField.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "editableTextField", "Editable text field did not request editable native peer.")
}

func testSwitchButtonUsesCheckboxNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let checkbox = NSButton(title: "Check", frame: NSMakeRect(0, 0, 120, 24))
    checkbox.setButtonType(.switchButton)
    checkbox.state = .on

    let handle = checkbox.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "checkbox", "Switch button did not request checkbox native peer.")
    expect(backend.records[handle]?.buttonState == .on, "Switch button state was not synced to backend.")
}

func testRadioButtonUsesRadioNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let radioButton = NSButton(title: "Radio", frame: NSMakeRect(0, 0, 120, 24))
    radioButton.setButtonType(.radioButton)
    radioButton.state = .on

    let handle = radioButton.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "radioButton", "Radio button did not request radio native peer.")
    expect(backend.records[handle]?.buttonState == .on, "Radio button state was not synced to backend.")
}

func testPopUpButtonUsesNativePeerAndSelection() {
    let backend = InMemoryNativeControlBackend()
    let popUpButton = NSPopUpButton(frame: NSMakeRect(0, 0, 140, 80), pullsDown: false)
    popUpButton.addItems(withTitles: ["Info", "Warning", "Critical"])
    popUpButton.selectItem(withTitle: "Warning")

    let handle = popUpButton.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.kind == "popUpButton", "Pop-up button did not request native peer.")
    expect(backend.records[handle]?.popUpItems == ["Info", "Warning", "Critical"], "Pop-up button items were not synced.")
    expect(backend.records[handle]?.popUpSelectedIndex == 1, "Pop-up button selection was not synced.")
    expect(popUpButton.titleOfSelectedItem == "Warning", "Pop-up button selected title was not reported.")
}

func testPopUpButtonNativeActionUpdatesSelection() {
    let backend = InMemoryNativeControlBackend()
    let popUpButton = NSPopUpButton(frame: NSMakeRect(0, 0, 140, 80), pullsDown: false)
    popUpButton.addItems(withTitles: ["Info", "Warning", "Critical"])
    let handle = popUpButton.realizeNativePeer(in: backend, parent: nil)
    var actionCount = 0

    popUpButton.onAction = { control in
        expect(control === popUpButton, "Pop-up action sender was not the control.")
        actionCount += 1
    }

    backend.setPopUpButtonSelectedIndex(2, for: handle)
    backend.actions[handle]?()

    expect(popUpButton.indexOfSelectedItem == 2, "Pop-up button did not read native selection.")
    expect(popUpButton.titleOfSelectedItem == "Critical", "Pop-up button selected title did not update.")
    expect(actionCount == 1, "Pop-up button action was not sent.")
}

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

func testBoxUsesNativePeerAndSyncsTitle() {
    let backend = InMemoryNativeControlBackend()
    let box = NSBox(title: "Group", frame: NSMakeRect(0, 0, 200, 120))

    let handle = box.realizeNativePeer(in: backend, parent: nil)
    box.title = "Updated Group"

    expect(backend.records[handle]?.kind == "box", "Box did not request native peer.")
    expect(backend.records[handle]?.text == "Updated Group", "Box title was not synced to backend.")
}

func testColorValuesClampComponents() {
    let color = NSColor(calibratedRed: 2, green: -1, blue: 0.25, alpha: 3)

    expect(color.redComponent == 1, "Color red component did not clamp high.")
    expect(color.greenComponent == 0, "Color green component did not clamp low.")
    expect(color.blueComponent == 0.25, "Color blue component changed unexpectedly.")
    expect(color.alphaComponent == 1, "Color alpha component did not clamp high.")
}

func testViewAndTextFieldColorsSyncToBackend() {
    let backend = InMemoryNativeControlBackend()
    let view = NSView(frame: NSMakeRect(0, 0, 100, 100))
    let textField = NSTextField(string: "Color", frame: NSMakeRect(0, 0, 80, 24))
    view.backgroundColor = .white
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

func testFontValuesClampSizeAndSyncToBackend() {
    let backend = InMemoryNativeControlBackend()
    let textField = NSTextField(string: "Font", frame: NSMakeRect(0, 0, 120, 24))
    let tinyFont = NSFont(name: "Segoe UI", size: -4)
    let boldFont = NSFont.boldSystemFont(ofSize: 16)

    textField.font = boldFont
    let handle = textField.realizeNativePeer(in: backend, parent: nil)

    expect(tinyFont.pointSize == 1, "Font point size did not clamp low.")
    expect(boldFont.fontName == "Segoe UI", "Bold system font did not use system face.")
    expect(boldFont.weight == .bold, "Bold system font did not use bold weight.")
    expect(backend.records[handle]?.font == boldFont, "Text field font was not synced.")
}


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

func testMenuItemStateAndSeparatorContracts() {
    let separator = NSMenuItem.separator()
    let item = NSMenuItem(title: "Toggle", action: nil, keyEquivalent: "t")

    item.isEnabled = false
    item.isHidden = true
    item.state = .on
    item.keyEquivalentModifierMask = [.command, .shift]

    expect(separator.isSeparatorItem, "Separator item was not recognized.")
    expect(!item.performAction(), "Disabled menu item performed action.")
    expect(item.isHidden, "Menu item hidden state was not stored.")
    expect(item.state == .on, "Menu item state was not stored.")
    expect(item.keyEquivalentModifierMask.contains(.command), "Menu item command modifier was not stored.")
    expect(item.keyEquivalentModifierMask.contains(.shift), "Menu item shift modifier was not stored.")
}

func testAlertReturnsFirstButtonInMemory() {
    NSApplication.shared.nativeBackend = InMemoryNativeControlBackend()
    let alert = NSAlert()
    alert.messageText = "Hello"
    alert.addButton(withTitle: "OK")

    let response = alert.runModal()

    expect(response == .alertFirstButtonReturn, "In-memory alert did not return first button.")
}

func testAlertRestoresKeyWindowAndFirstResponder() {
    clearApplicationWindows()

    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 200, 100),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let contentView = NSView(frame: NSMakeRect(0, 0, 200, 100))
    let button = NSButton(title: "Alert", frame: NSMakeRect(20, 20, 80, 24))
    let alert = NSAlert()

    contentView.addSubview(button)
    window.contentView = contentView
    window.makeKeyAndOrderFront(nil)
    _ = window.makeFirstResponder(button)

    let response = alert.runModal()

    expect(response == .alertFirstButtonReturn, "Alert did not return expected response.")
    expect(NSApplication.shared.keyWindow === window, "Alert did not restore key window.")
    expect(NSApplication.shared.mainWindow === window, "Alert did not restore main window.")
    expect(window.firstResponder === button, "Alert did not restore first responder.")
    expect(backend.focusedHandle == button.nativeHandle, "Alert did not restore native focus.")

    clearApplicationWindows()
}

testWindowRealizationCreatesNativeHierarchy()
testViewHierarchyMaintainsSuperviewOwnership()
testViewInsertionReplacementTagsAndDescendants()
testGeometryConvenienceFunctions()
testViewCoordinateConversionAndHitTesting()
testSubviewResponderChainTargetsSuperview()
testResponderForwardsUnhandledEvents()
testWindowIsContentViewNextResponder()
testWindowMakeFirstResponderFocusesNativeView()
testWindowMakeFirstResponderHonorsResignFailure()
testApplicationTracksWindowListAndKeyMainWindow()
testWindowSelectNextAndPreviousKeyView()
testWindowSelectNextKeyViewSkipsDisabledExplicitTarget()
testNativeMouseDownDispatchesToView()
testNativeMouseDownOnControlMakesControlFirstResponder()
testNativeMouseUpDispatchesToView()
testNativeMouseMovedDispatchesToView()
testNativeKeyDownDispatchesToView()
testNativeKeyUpDispatchesToView()
testControlClosureActionIsInvoked()
testButtonPerformClickHonorsEnabledState()
testSwitchButtonTogglesStateOnPerformClick()
testRadioButtonClearsSiblingRadioButtons()
testRealizedViewStatePropagatesToBackend()
testWindowTitleAndFramePropagateToBackend()
testWindowContentSizeAndCenterUpdateFrame()
testEditableTextFieldUsesEditableNativePeer()
testSwitchButtonUsesCheckboxNativePeer()
testRadioButtonUsesRadioNativePeer()
testPopUpButtonUsesNativePeerAndSelection()
testPopUpButtonNativeActionUpdatesSelection()
testNativeButtonActionMakesButtonFirstResponder()
testNativePopUpActionMakesPopUpFirstResponder()
testNativeTextChangeMakesEditableTextFieldFirstResponder()
testBoxUsesNativePeerAndSyncsTitle()
testColorValuesClampComponents()
testViewAndTextFieldColorsSyncToBackend()
testFontValuesClampSizeAndSyncToBackend()
testRemovingRealizedSubviewDestroysNativePeer()
testMainMenuQuitItemTerminatesApplication()
testMenuItemInsertionLookupAndRemoval()
testMenuItemStateAndSeparatorContracts()
testAlertReturnsFirstButtonInMemory()
testAlertRestoresKeyWindowAndFirstResponder()

print("WinChocolate contract tests passed.")
