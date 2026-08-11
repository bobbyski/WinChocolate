import WinChocolate

@MainActor
func testAutoLayoutResizeReflowsPinnedEdges() {
    // The real test of a constraint layout: when the container resizes, every
    // constraint-driven subview must reflow. Each scenario lays out at one
    // size, resizes the container, re-runs the solver, and checks the frames.

    // A: edges pinned with insets — the box tracks the container's size.
    let containerA = NSView(frame: NSMakeRect(0, 0, 200, 100))
    let boxA = NSView(frame: .zero)
    boxA.translatesAutoresizingMaskIntoConstraints = false
    containerA.addSubview(boxA)
    NSLayoutConstraint.activate([
        boxA.leadingAnchor.constraint(equalTo: containerA.leadingAnchor, constant: 12),
        boxA.trailingAnchor.constraint(equalTo: containerA.trailingAnchor, constant: -12),
        boxA.topAnchor.constraint(equalTo: containerA.topAnchor, constant: 10),
        boxA.bottomAnchor.constraint(equalTo: containerA.bottomAnchor, constant: -10),
    ])
    containerA.layoutSubtreeIfNeeded()
    expect(winClose(boxA.frame.size.width, 176) && winClose(boxA.frame.size.height, 80),
        "Edge-pinned box wrong at 200×100: got \(boxA.frame).")
    containerA.frame = NSMakeRect(0, 0, 400, 200)
    containerA.layoutSubtreeIfNeeded()
    expect(winClose(boxA.frame.origin.x, 12) && winClose(boxA.frame.origin.y, 10)
        && winClose(boxA.frame.size.width, 376) && winClose(boxA.frame.size.height, 180),
        "Edge-pinned box should reflow to the larger container: got \(boxA.frame).")
}

@MainActor
func testAutoLayoutResizeRecentersFixedView() {
    // B: fixed size, centered — re-centers on resize.
    let containerB = NSView(frame: NSMakeRect(0, 0, 200, 100))
    let boxB = NSView(frame: .zero)
    boxB.translatesAutoresizingMaskIntoConstraints = false
    containerB.addSubview(boxB)
    NSLayoutConstraint.activate([
        boxB.widthAnchor.constraint(equalToConstant: 40),
        boxB.heightAnchor.constraint(equalToConstant: 20),
        boxB.centerXAnchor.constraint(equalTo: containerB.centerXAnchor),
        boxB.centerYAnchor.constraint(equalTo: containerB.centerYAnchor),
    ])
    containerB.layoutSubtreeIfNeeded()
    expect(winClose(boxB.frame.origin.x, 80) && winClose(boxB.frame.origin.y, 40),
        "Centered box wrong at 200×100: got \(boxB.frame).")
    containerB.frame = NSMakeRect(0, 0, 400, 200)
    containerB.layoutSubtreeIfNeeded()
    expect(winClose(boxB.frame.origin.x, 180) && winClose(boxB.frame.origin.y, 90)
        && winClose(boxB.frame.size.width, 40) && winClose(boxB.frame.size.height, 20),
        "Centered box should re-center and keep its size on resize: got \(boxB.frame).")
}

@MainActor
func testAutoLayoutResizeReflowsProportionalWidth() {
    // C: proportional width (50% of the container) — tracks the container.
    let containerC = NSView(frame: NSMakeRect(0, 0, 200, 100))
    let boxC = NSView(frame: .zero)
    boxC.translatesAutoresizingMaskIntoConstraints = false
    containerC.addSubview(boxC)
    NSLayoutConstraint.activate([
        boxC.leadingAnchor.constraint(equalTo: containerC.leadingAnchor),
        boxC.topAnchor.constraint(equalTo: containerC.topAnchor),
        boxC.heightAnchor.constraint(equalToConstant: 30),
        boxC.widthAnchor.constraint(equalTo: containerC.widthAnchor, multiplier: 0.5),
    ])
    containerC.layoutSubtreeIfNeeded()
    expect(winClose(boxC.frame.size.width, 100),
        "Proportional box should be half the 200-wide container: got \(boxC.frame.size.width).")
    containerC.frame = NSMakeRect(0, 0, 360, 120)
    containerC.layoutSubtreeIfNeeded()
    expect(winClose(boxC.frame.size.width, 180),
        "Proportional box should track to half the 360-wide container: got \(boxC.frame.size.width).")
}

@MainActor
func testAutoLayoutResizeReflowsFlexibleMiddle() {
    // D: a flexible middle — A pinned leading, C pinned trailing, B fills the
    // gap. B's width is entirely determined by the container width.
    let containerD = NSView(frame: NSMakeRect(0, 0, 200, 60))
    let dA = NSView(frame: .zero), dB = NSView(frame: .zero), dC = NSView(frame: .zero)
    for v in [dA, dB, dC] {
        v.translatesAutoresizingMaskIntoConstraints = false
        containerD.addSubview(v)
    }
    NSLayoutConstraint.activate([
        dA.leadingAnchor.constraint(equalTo: containerD.leadingAnchor),
        dA.widthAnchor.constraint(equalToConstant: 30),
        dC.trailingAnchor.constraint(equalTo: containerD.trailingAnchor),
        dC.widthAnchor.constraint(equalToConstant: 30),
        dB.leadingAnchor.constraint(equalTo: dA.trailingAnchor, constant: 8),
        dB.trailingAnchor.constraint(equalTo: dC.leadingAnchor, constant: -8),
        dA.topAnchor.constraint(equalTo: containerD.topAnchor),
        dA.heightAnchor.constraint(equalToConstant: 20),
        dB.topAnchor.constraint(equalTo: dA.topAnchor),
        dB.heightAnchor.constraint(equalTo: dA.heightAnchor),
        dC.topAnchor.constraint(equalTo: dA.topAnchor),
        dC.heightAnchor.constraint(equalTo: dA.heightAnchor),
    ])
    containerD.layoutSubtreeIfNeeded()
    expect(winClose(dB.frame.origin.x, 38) && winClose(dB.frame.size.width, 124),
        "Flexible middle wrong at width 200 (expected x=38 w=124): got \(dB.frame).")
    containerD.frame = NSMakeRect(0, 0, 400, 60)
    containerD.layoutSubtreeIfNeeded()
    expect(winClose(dC.frame.origin.x, 370),
        "Trailing-pinned box should move to the new right edge: got \(dC.frame.origin.x).")
    expect(winClose(dB.frame.origin.x, 38) && winClose(dB.frame.size.width, 324),
        "Flexible middle should absorb the extra width (expected x=38 w=324): got \(dB.frame).")

    // Round-trip: resizing back to the original size restores the exact layout
    // (no drift from the previous solve seeding the next).
    containerD.frame = NSMakeRect(0, 0, 200, 60)
    containerD.layoutSubtreeIfNeeded()
    expect(winClose(dB.frame.origin.x, 38) && winClose(dB.frame.size.width, 124),
        "Resizing back should restore the original layout with no drift: got \(dB.frame).")
}

@MainActor
func testAutoLayoutResizeReflowsConstraints() {
    testAutoLayoutResizeReflowsPinnedEdges()
    testAutoLayoutResizeRecentersFixedView()
    testAutoLayoutResizeReflowsProportionalWidth()
    testAutoLayoutResizeReflowsFlexibleMiddle()
}

@MainActor
func testAutoLayoutSiblingChainInequalityAndFixedAnchor() {
    // A sibling chain: A pinned to the leading edge, B trailing of A with a gap.
    let container = NSView(frame: NSMakeRect(0, 0, 200, 100))
    let a = NSView(frame: .zero)
    let b = NSView(frame: .zero)
    a.translatesAutoresizingMaskIntoConstraints = false
    b.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(a)
    container.addSubview(b)
    NSLayoutConstraint.activate([
        a.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        a.widthAnchor.constraint(equalToConstant: 40),
        a.topAnchor.constraint(equalTo: container.topAnchor),
        a.heightAnchor.constraint(equalToConstant: 20),
        b.leadingAnchor.constraint(equalTo: a.trailingAnchor, constant: 10),
        b.widthAnchor.constraint(equalToConstant: 60),
        b.topAnchor.constraint(equalTo: a.topAnchor),
        b.heightAnchor.constraint(equalToConstant: 20),
    ])
    container.layoutSubtreeIfNeeded()
    expect(winClose(a.frame.origin.x, 0) && winClose(a.frame.size.width, 40),
        "Chain head A wrong: got \(a.frame).")
    expect(winClose(b.frame.origin.x, 50) && winClose(b.frame.size.width, 60),
        "Chain tail B should begin at A.trailing+10 = 50: got \(b.frame).")

    // A required minimum-width inequality overrides a low-priority width.
    let grow = NSView(frame: .zero)
    grow.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(grow)
    let low = grow.widthAnchor.constraint(equalToConstant: 30)
    low.priority = .defaultLow
    NSLayoutConstraint.activate([
        grow.leadingAnchor.constraint(equalTo: container.leadingAnchor),
        grow.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),
        low,
    ])
    container.layoutSubtreeIfNeeded()
    expect(grow.frame.size.width >= 99,
        "Required min-width should beat the low-priority width: got \(grow.frame.size.width).")

    // A translates=true sibling is a fixed anchor others can pin to.
    let fixed = NSView(frame: NSMakeRect(0, 0, 40, 100))  // translates == true (default)
    let follower = NSView(frame: .zero)
    follower.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(fixed)
    container.addSubview(follower)
    NSLayoutConstraint.activate([
        follower.leadingAnchor.constraint(equalTo: fixed.trailingAnchor),
        follower.widthAnchor.constraint(equalToConstant: 30),
        follower.topAnchor.constraint(equalTo: container.topAnchor),
        follower.heightAnchor.constraint(equalToConstant: 10),
    ])
    container.layoutSubtreeIfNeeded()
    expect(winClose(follower.frame.origin.x, 40),
        "Follower should pin to the fixed sibling's trailing edge (40): got \(follower.frame).")
}

@MainActor
func clearApplicationWindows() {
    for window in NSApplication.shared.windows {
        NSApplication.shared.removeWindowsItem(window)
    }
}

final class RecordingToolbarDelegate: NSObject, NSToolbarDelegate {
    var allowedIdentifiers: [NSToolbarItem.Identifier] = [NSToolbarItem.Identifier("open"), NSToolbarItem.Identifier("save"), NSToolbarItem.Identifier("customize")]
    var defaultIdentifiers: [NSToolbarItem.Identifier] = [NSToolbarItem.Identifier("open"), NSToolbarItem.Identifier("save")]
    var requestedIdentifiers: [NSToolbarItem.Identifier] = []
    var insertionFlags: [Bool] = []

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        allowedIdentifiers
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        defaultIdentifiers
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        requestedIdentifiers.append(itemIdentifier)
        insertionFlags.append(flag)

        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = itemIdentifier.rawValue == "customize" ? "Customize" : "Save"
        item.paletteLabel = item.label
        return item
    }
}

@MainActor
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
    expect(backend.records[windowHandle]?.isHidden == true, "Realized window should stay hidden until ordered front.")
    expect(contentView.nativeHandle != nil, "Content view was not realized.")
    expect(button.nativeHandle != nil, "Button was not realized.")
    let buttonHandle = requireValue(button.nativeHandle, "Button should have a native handle.")
    expect(backend.records[buttonHandle]?.kind == "button", "Button native record was not created.")
    expect(backend.records[buttonHandle]?.parent == contentView.nativeHandle, "Button parent was not content view.")

    window.makeKeyAndOrderFront(nil)

    expect(backend.records[windowHandle]?.isHidden == false, "makeKeyAndOrderFront did not show the realized window.")

    clearApplicationWindows()
}

final class FullScreenSpyDelegate: NSObject, NSWindowDelegate {
    var willEnter = 0, didEnter = 0, willExit = 0, didExit = 0
    func windowWillEnterFullScreen(_ notification: Notification) { willEnter += 1 }
    func windowDidEnterFullScreen(_ notification: Notification) { didEnter += 1 }
    func windowWillExitFullScreen(_ notification: Notification) { willExit += 1 }
    func windowDidExitFullScreen(_ notification: Notification) { didExit += 1 }
}

@MainActor
func testWindowToggleFullScreenTracksStateAndDelegate() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 400, 300),
        styleMask: [.titled, .closable, .resizable],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    window.collectionBehavior = .fullScreenPrimary
    let spy = FullScreenSpyDelegate()
    window.delegate = spy
    let handle = window.realizeNativePeer()

    // Enter: state + styleMask flag + backend + will/did callbacks.
    window.toggleFullScreen(nil)
    expect(window.isFullScreen, "Window should report full screen after entering.")
    expect(window.styleMask.contains(.fullScreen), "styleMask should include .fullScreen in full screen.")
    expect(backend.fullScreenWindows.contains(handle), "Backend was not told the window entered full screen.")
    expect(spy.willEnter == 1 && spy.didEnter == 1, "Enter full-screen delegate callbacks did not fire once each.")

    // Exit: state clears, backend clears, exit callbacks fire.
    window.toggleFullScreen(nil)
    expect(!window.isFullScreen, "Window should not report full screen after exiting.")
    expect(!window.styleMask.contains(.fullScreen), "styleMask should drop .fullScreen after exiting.")
    expect(!backend.fullScreenWindows.contains(handle), "Backend was not told the window exited full screen.")
    expect(spy.willExit == 1 && spy.didExit == 1, "Exit full-screen delegate callbacks did not fire once each.")

    // A .fullScreenNone window ignores the toggle entirely.
    let locked = NSWindow(
        contentRect: NSMakeRect(0, 0, 200, 150),
        styleMask: [.titled],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    locked.collectionBehavior = .fullScreenNone
    _ = locked.realizeNativePeer()
    locked.toggleFullScreen(nil)
    expect(!locked.isFullScreen, "A .fullScreenNone window should not enter full screen.")

    clearApplicationWindows()
}

@MainActor
func testWindowTitleVisibilityBlanksCaption() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 200, 120),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    window.title = "Inspector"
    let handle = window.realizeNativePeer()
    expect(backend.records[handle]?.text == "Inspector", "Visible title was not pushed to the native window.")

    // Hiding the title blanks the caption text but keeps the window.
    window.titleVisibility = .hidden
    expect(backend.records[handle]?.text == "", "Hidden titleVisibility did not blank the caption.")

    // A title set while hidden stays blank, then reappears when shown.
    window.title = "Renamed"
    expect(backend.records[handle]?.text == "", "Title change while hidden should not reveal the caption.")
    window.titleVisibility = .visible
    expect(backend.records[handle]?.text == "Renamed", "Restoring visibility did not show the current title.")

    clearApplicationWindows()
}

@MainActor
func testWindowStandardButtonsAndStyleFlags() {
    let backend = InMemoryNativeControlBackend()
    let titled = NSWindow(
        contentRect: NSMakeRect(0, 0, 200, 120),
        styleMask: [.titled, .closable, .fullSizeContentView],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )

    // fullSizeContentView is a recognized style option.
    expect(titled.styleMask.contains(.fullSizeContentView), "fullSizeContentView flag was not stored in the style mask.")

    // A non-activating panel carries the style option (applies WS_EX_NOACTIVATE natively).
    let panel = NSPanel(
        contentRect: NSMakeRect(0, 0, 120, 80),
        styleMask: [.titled, .nonactivatingPanel],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    expect(panel.styleMask.contains(.nonactivatingPanel), "nonactivatingPanel flag was not stored in the style mask.")

    // Titled windows vend proxy buttons; the same instance is returned each time.
    let close = titled.standardWindowButton(.closeButton)
    expect(close != nil, "Titled window did not vend a close-button proxy.")
    close?.isHidden = true
    expect(titled.standardWindowButton(.closeButton)?.isHidden == true, "Standard button proxy did not persist its state.")

    // titlebarAppearsTransparent round-trips.
    titled.titlebarAppearsTransparent = true
    expect(titled.titlebarAppearsTransparent, "titlebarAppearsTransparent did not store.")

    // Borderless windows vend no standard buttons.
    let borderless = NSWindow(
        contentRect: NSMakeRect(0, 0, 100, 60),
        styleMask: [],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    expect(borderless.standardWindowButton(.closeButton) == nil, "Borderless window should not vend standard buttons.")

    clearApplicationWindows()
}

@MainActor
func testWindowStandardButtonHidingReflectsToCaption() {
    let backend = InMemoryNativeControlBackend()
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 200, 120),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false,
        nativeBackend: backend
    )
    let handle = window.realizeNativePeer()

    // Realizing reflects the (all-visible) initial state.
    expect(backend.windowButtonsHidden[handle]?.minimize == false, "Minimize should start visible.")

    // Hiding a standard-button proxy reflects onto the native caption.
    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    expect(backend.windowButtonsHidden[handle]?.minimize == true, "Hiding the minimize proxy did not reach the caption.")
    window.standardWindowButton(.closeButton)?.isHidden = true
    expect(backend.windowButtonsHidden[handle]?.close == true, "Hiding the close proxy did not reach the caption.")
    window.standardWindowButton(.miniaturizeButton)?.isHidden = false
    expect(backend.windowButtonsHidden[handle]?.minimize == false, "Showing the minimize proxy did not restore the caption.")

    clearApplicationWindows()
}

@MainActor
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

@MainActor
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

@MainActor
func testViewCompatibilityMetadataStoresValues() {
    let view = NSView(frame: NSMakeRect(0, 0, 100, 100))

    view.autoresizingMask = [.width, .height]
    view.autoresizesSubviews = false
    view.wantsLayer = true
    view.toolTip = "Hello"

    expect(view.autoresizingMask.contains(.width), "Autoresizing width mask was not stored.")
    expect(view.autoresizingMask.contains(.height), "Autoresizing height mask was not stored.")
    expect(!view.autoresizesSubviews, "autoresizesSubviews was not stored.")
    expect(view.wantsLayer, "wantsLayer was not stored.")
    expect(view.toolTip == "Hello", "toolTip was not stored.")
}

@MainActor
func testViewTooltipSyncsToNativePeer() {
    let backend = InMemoryNativeControlBackend()
    let view = NSView(frame: NSMakeRect(0, 0, 100, 100))
    view.toolTip = "Before"

    let handle = view.realizeNativePeer(in: backend, parent: nil)

    expect(backend.records[handle]?.toolTip == "Before", "Initial tooltip was not sent to native peer.")

    view.toolTip = "After"

    expect(backend.records[handle]?.toolTip == "After", "Updated tooltip was not sent to native peer.")

    view.toolTip = nil

    expect(backend.records[handle]?.toolTip == nil, "Cleared tooltip was not sent to native peer.")
}

@MainActor
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

@MainActor
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

@MainActor
func testScrollViewHostsDocumentView() {
    let scrollView = NSScrollView(frame: NSMakeRect(0, 0, 200, 120))
    let documentView = NSView(frame: NSMakeRect(0, 0, 180, 240))

    scrollView.hasVerticalScroller = true
    scrollView.documentView = documentView

    expect(scrollView.subviews.count == 1, "Scroll view should own one clip view child.")
    expect(scrollView.subviews.first === scrollView.contentView, "Scroll view subview was not the clip view.")
    expect(scrollView.contentView.documentView === documentView, "Clip view did not host the document view.")
    expect(documentView.superview === scrollView.contentView, "Document view superview was not the clip view.")
    expect(!scrollView.contentView.acceptsFirstResponder, "Clip view should skip key-view traversal.")
}

