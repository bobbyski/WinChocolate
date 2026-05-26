import WinChocolate

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fatalError(message)
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

testWindowRealizationCreatesNativeHierarchy()
testViewHierarchyMaintainsSuperviewOwnership()
testControlClosureActionIsInvoked()
testMainMenuQuitItemTerminatesApplication()

print("WinChocolate contract tests passed.")
