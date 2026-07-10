// LinChocolate contract tests — hermetic, no display.
//
// These run against the in-memory backend and prove the AppKit-shaped API is
// genuinely backend-swappable (validation spike S4): the exact code path a real
// GTK click would take is exercised here through simulated input. Mirrors
// WinChocolate's executable contract-test style; exits non-zero on any failure.

import LinChocolate
import Foundation

var failures = 0
// Top-level `main.swift` code is @MainActor in Swift 6, so `failures` is
// main-actor-isolated; the helper must share that isolation to mutate it.
@MainActor
func check(_ condition: Bool, _ message: String) {
    if condition {
        print("PASS: \(message)")
    } else {
        print("FAIL: \(message)")
        failures += 1
    }
}

// MARK: 1 — Backend contract (in-memory)
do {
    let backend = InMemoryNativeControlBackend()

    let window = backend.createWindow(title: "T", frame: NSMakeRect(0, 0, 100, 50), styleMask: [])
    let button = backend.createButton(title: "B", frame: NSMakeRect(0, 0, 10, 10))
    check(window != button, "distinct handles are allocated")
    check(backend.text(for: button) == "B", "button title is recorded")

    backend.setText("B2", for: button)
    check(backend.text(for: button) == "B2", "setText updates recorded text")

    backend.setEnabled(false, for: button)
    check(backend.isEnabled(button) == false, "setEnabled updates state")

    var fired = false
    backend.registerAction(for: button) { fired = true }
    backend.simulateClick(button)
    check(fired, "registered action fires on simulated click")

    check(backend.isVisible(window) == false, "window starts hidden")
    backend.showWindow(window)
    check(backend.isVisible(window), "showWindow marks the window visible")
}

// MARK: 2 — AppKit-shaped API over the backend (the click-counter, headless)
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 480, 220),
        styleMask: [.titled, .closable],
        backing: .buffered, defer: false
    )
    window.title = "Counter"
    check(backend.titles[window.handle.rawValue] == "Counter", "NSWindow.title reaches the backend")

    let content = NSView(frame: NSMakeRect(0, 0, 480, 220))
    let label = NSTextField(string: "Clicks: 0", frame: NSMakeRect(24, 24, 240, 24))
    let button = NSButton(title: "Click me", frame: NSMakeRect(24, 64, 140, 36))

    var clicks = 0
    button.onAction = { _ in
        clicks += 1
        label.stringValue = "Clicks: \(clicks)"
    }
    content.addSubview(label)
    content.addSubview(button)
    window.contentView = content
    window.makeKeyAndOrderFront(nil)

    check(backend.isVisible(window.handle), "makeKeyAndOrderFront shows the window")
    check(backend.subviews[content.handle.rawValue]?.count == 2, "content view has two subviews")

    // The crux: a native click (simulated) drives onAction through the backend,
    // updating the label — same path GTK's "clicked" signal would take.
    backend.simulateClick(button.handle)
    check(clicks == 1, "NSButton.onAction fires via the backend action")
    check(backend.text(for: label.handle) == "Clicks: 1", "label text updated through the backend")

    backend.simulateClick(button.handle)
    check(backend.text(for: label.handle) == "Clicks: 2", "second click accumulates")
}

// MARK: 3 — Coordinate model (AppKit bottom-left → GTK top-left)
do {
    check(CoordinateSpace.gtkY(for: NSMakeRect(0, 24, 240, 24), parentHeight: 220) == 172,
          "Y-flip: bottom-anchored child maps to a large GTK y")
    check(CoordinateSpace.gtkY(for: NSMakeRect(0, 0, 10, 10), parentHeight: 100) == 90,
          "Y-flip: origin child sits at the GTK bottom")
    check(CoordinateSpace.gtkY(for: NSMakeRect(0, 90, 10, 10), parentHeight: 100) == 0,
          "Y-flip: top child maps to GTK y=0")

    // Setting NSView.frame reaches the backend (live reposition/resize).
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend
    let view = NSView(frame: NSMakeRect(0, 0, 50, 50))
    view.frame = NSMakeRect(10, 20, 60, 70)
    check(backend.frames[view.handle.rawValue] == NSMakeRect(10, 20, 60, 70),
          "NSView.frame setter reaches the backend")
}

// MARK: 4 — Editable text field + checkbox (L4.1 controls)
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    // Editable text field: a native edit drives onTextChange and stringValue.
    let field = NSTextField(string: "a", frame: NSMakeRect(0, 0, 100, 24))
    var changedTo = ""
    field.onTextChange = { changedTo = $0.stringValue }
    backend.simulateTextChange(field.handle, "hello")
    check(field.stringValue == "hello", "editable NSTextField.stringValue syncs from native edits")
    check(changedTo == "hello", "NSTextField.onTextChange fires on native edit")

    // Label: the setter writes through to the backend.
    let label = NSTextField(labelWithString: "x", frame: NSMakeRect(0, 0, 100, 24))
    label.stringValue = "y"
    check(backend.text(for: label.handle) == "y", "label NSTextField.stringValue writes through")

    // Checkbox: a native toggle drives isOn and onAction.
    let checkbox = NSButton(checkboxWithTitle: "On?", frame: NSMakeRect(0, 0, 120, 24))
    var toggledState: Bool?
    checkbox.onAction = { toggledState = $0.isOn }
    check(checkbox.isOn == false, "checkbox starts off")
    backend.simulateToggle(checkbox.handle, true)
    check(checkbox.isOn, "checkbox NSButton.isOn syncs from native toggle")
    check(toggledState == true, "checkbox onAction fires with the new state")
}

// MARK: 5 — Radio, slider, progress, pop-up (L4 controls page)
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    // Radio buttons: grouping gives mutual exclusion; selection fires onAction.
    let a = NSButton(radioWithTitle: "A", frame: NSMakeRect(0, 0, 80, 24))
    let b = NSButton(radioWithTitle: "B", frame: NSMakeRect(0, 0, 80, 24))
    let c = NSButton(radioWithTitle: "C", frame: NSMakeRect(0, 0, 80, 24))
    NSButton.group([a, b, c])
    var picked = ""
    for radio in [a, b, c] { radio.onAction = { picked = $0.title } }
    backend.simulateRadioSelect(b.handle)
    check(b.isOn && !a.isOn && !c.isOn, "radio group is mutually exclusive")
    check(picked == "B", "radio selection fires onAction")
    backend.simulateRadioSelect(c.handle)
    check(c.isOn && !b.isOn, "selecting another radio deselects the previous")

    // Slider: a native drag drives doubleValue and onValueChange.
    let slider = NSSlider(value: 10, minValue: 0, maxValue: 100, frame: NSMakeRect(0, 0, 200, 24))
    var slid = 0.0
    slider.onValueChange = { slid = $0.doubleValue }
    backend.simulateValueChange(slider.handle, 42)
    check(slider.doubleValue == 42, "slider doubleValue syncs from native drag")
    check(slid == 42, "slider onValueChange fires")

    // Progress: setting doubleValue reaches the backend.
    let progress = NSProgressIndicator(value: 0, minValue: 0, maxValue: 100, frame: NSMakeRect(0, 0, 200, 20))
    progress.doubleValue = 75
    check(backend.doubleValue(progress.handle) == 75, "progress doubleValue writes through")

    // Pop-up: selection drives index, title, and onSelectionChange.
    let popup = NSPopUpButton(items: ["System", "Light", "Dark"], frame: NSMakeRect(0, 0, 160, 30))
    var chosen = ""
    popup.onSelectionChange = { chosen = $0.titleOfSelectedItem ?? "" }
    check(popup.titleOfSelectedItem == "System", "pop-up starts on the first item")
    backend.simulateSelection(popup.handle, 2)
    check(popup.indexOfSelectedItem == 2, "pop-up index syncs from native selection")
    check(popup.titleOfSelectedItem == "Dark", "pop-up title reflects the selection")
    check(chosen == "Dark", "pop-up onSelectionChange fires")
}

// MARK: 6 — Secure / search / combo text inputs (L4.2)
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    let password = NSSecureTextField(string: "", frame: NSMakeRect(0, 0, 120, 24))
    var secret = ""
    password.onTextChange = { secret = $0.stringValue }
    backend.simulateTextChange(password.handle, "hunter2")
    check(password.stringValue == "hunter2", "secure field stringValue syncs from native edits")
    check(secret == "hunter2", "secure field onTextChange fires")

    let search = NSSearchField(string: "", frame: NSMakeRect(0, 0, 200, 24))
    var query = ""
    search.onTextChange = { query = $0.stringValue }
    backend.simulateTextChange(search.handle, "swift")
    check(search.stringValue == "swift", "search field stringValue syncs")
    check(query == "swift", "search field onTextChange fires")

    let combo = NSComboBox(items: ["Apple", "Banana"], frame: NSMakeRect(0, 0, 160, 30))
    check(combo.stringValue == "Apple", "combo starts on the first item")
    var chosen = ""
    combo.onTextChange = { chosen = $0.stringValue }
    backend.simulateTextChange(combo.handle, "Cherry")   // typed value, not in the list
    check(combo.stringValue == "Cherry", "combo accepts a typed value")
    check(chosen == "Cherry", "combo onTextChange fires")
}

// MARK: 6 — Stepper, level indicator, text view
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    // Stepper: a native step drives doubleValue and onValueChange.
    let stepper = NSStepper(value: 1, minValue: 0, maxValue: 10, increment: 1, frame: NSMakeRect(0, 0, 80, 24))
    var stepped = 0.0
    stepper.onValueChange = { stepped = $0.doubleValue }
    backend.simulateValueChange(stepper.handle, 4)
    check(stepper.doubleValue == 4, "stepper doubleValue syncs from native step")
    check(stepped == 4, "stepper onValueChange fires")

    // Level indicator: setting doubleValue writes through.
    let level = NSLevelIndicator(value: 2, minValue: 0, maxValue: 10, frame: NSMakeRect(0, 0, 120, 20))
    level.doubleValue = 7
    check(backend.doubleValue(level.handle) == 7, "level indicator doubleValue writes through")

    // Text view: a native edit drives string and onTextChange.
    let notes = NSTextView(string: "hi", frame: NSMakeRect(0, 0, 200, 80))
    var edited = ""
    notes.onTextChange = { edited = $0.string }
    backend.simulateTextChange(notes.handle, "hello world")
    check(notes.string == "hello world", "text view string syncs from native edit")
    check(edited == "hello world", "text view onTextChange fires")
}

// MARK: 7 — Date picker and color well
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    // Date picker: a native pick drives dateValue and onDateChange.
    let start = Date(timeIntervalSince1970: 1_000_000)
    let picker = NSDatePicker(date: start, frame: NSMakeRect(0, 0, 300, 200))
    check(backend.date(picker.handle) == start, "date picker initial date reaches the backend")
    var picked: Date?
    picker.onDateChange = { picked = $0.dateValue }
    let newDate = Date(timeIntervalSince1970: 2_000_000)
    backend.simulateDateChange(picker.handle, newDate)
    check(picker.dateValue == newDate, "date picker dateValue syncs from native pick")
    check(picked == newDate, "date picker onDateChange fires")

    // Color well: a native choice drives color and onColorChange.
    let well = NSColorWell(color: .red, frame: NSMakeRect(0, 0, 60, 34))
    check(backend.color(well.handle) == .red, "color well initial color reaches the backend")
    var chosen: NSColor?
    well.onColorChange = { chosen = $0.color }
    backend.simulateColorChange(well.handle, .green)
    check(well.color == .green, "color well color syncs from native choice")
    check(chosen == .green, "color well onColorChange fires")
    well.color = .blue
    check(backend.color(well.handle) == .blue, "color well setter writes through")
}

// MARK: 8 — Tab view
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    let tabs = NSTabView(frame: NSMakeRect(0, 0, 400, 300))
    let pageA = NSView(frame: NSMakeRect(0, 0, 400, 260))
    let pageB = NSView(frame: NSMakeRect(0, 0, 400, 260))
    let itemA = NSTabViewItem(); itemA.label = "A"; itemA.view = pageA
    let itemB = NSTabViewItem(); itemB.label = "B"; itemB.view = pageB
    tabs.addTabViewItem(itemA)
    tabs.addTabViewItem(itemB)

    let recorded = backend.tabPages[tabs.handle.rawValue] ?? []
    check(recorded.count == 2, "tab view records two pages")
    check(recorded.first?.label == "A" && recorded.last?.label == "B", "tab labels preserved in order")
    check(recorded.first?.page == pageA.handle.rawValue, "tab page handle reaches the backend")

    check(tabs.indexOfSelectedTab == 0, "first tab selected initially")
    tabs.selectTabViewItem(at: 1)
    check(backend.selectedIndex(tabs.handle) == 1, "programmatic tab select writes through")

    var switched = -1
    tabs.onSelectionChange = { switched = $0.indexOfSelectedTab }
    backend.simulateSelection(tabs.handle, 0)
    check(tabs.indexOfSelectedTab == 0, "tab index syncs from native switch")
    check(switched == 0, "tab onSelectionChange fires")
    check(tabs.selectedTabViewItem === itemA, "selectedTabViewItem tracks the index")
}

// MARK: 9 — Box, scroll view, split view
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    // Box: title + content wire through.
    let box = NSBox(title: "Group", frame: NSMakeRect(0, 0, 200, 100))
    check(backend.text(for: box.handle) == "Group", "box title reaches the backend")
    let inner = NSView(frame: NSMakeRect(0, 0, 180, 80))
    box.contentView = inner
    check(backend.contentViews[box.handle.rawValue] == inner.handle.rawValue, "box content view installs")
    box.title = "Renamed"
    check(backend.text(for: box.handle) == "Renamed", "box title setter writes through")

    // Scroll view: document view installs.
    let scroll = NSScrollView(frame: NSMakeRect(0, 0, 200, 150))
    let doc = NSView(frame: NSMakeRect(0, 0, 400, 600))
    scroll.documentView = doc
    check(backend.contentViews[scroll.handle.rawValue] == doc.handle.rawValue, "scroll documentView installs")

    // Split view: panes in order + divider position.
    let split = NSSplitView(vertical: true, frame: NSMakeRect(0, 0, 400, 200))
    let a = NSView(frame: NSMakeRect(0, 0, 100, 200))
    let b = NSView(frame: NSMakeRect(0, 0, 100, 200))
    split.addArrangedSubview(a)
    split.addArrangedSubview(b)
    check(backend.splitPanes[split.handle.rawValue] == [a.handle.rawValue, b.handle.rawValue],
          "split panes recorded in order")
    split.setPosition(160)
    check(backend.dividerPositions[split.handle.rawValue] == 160, "divider position writes through")
}

// MARK: 10 — Segmented control
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    let seg = NSSegmentedControl(labels: ["L", "C", "R"], frame: NSMakeRect(0, 0, 240, 34))
    check(backend.itemsByHandle[seg.handle.rawValue] == ["L", "C", "R"], "segment labels reach the backend")
    check(seg.selectedSegment == -1, "segmented starts with no selection")

    var picked = -1
    seg.onAction = { picked = $0.selectedSegment }
    backend.simulateSelection(seg.handle, 1)
    check(seg.selectedSegment == 1, "segmented selection syncs from native click")
    check(picked == 1, "segmented onAction fires with the index")
    check(seg.label(forSegment: 1) == "C", "label(forSegment:) resolves")

    seg.selectedSegment = 2
    check(backend.selectedIndex(seg.handle) == 2, "segmented setter writes through")
}

// MARK: 11 — Menu bar
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend
    NSApplication.shared.mainMenu = nil

    let window = NSWindow(contentRect: NSMakeRect(0, 0, 300, 200),
                          styleMask: [.titled], backing: .buffered, defer: false)
    check(NSApplication.shared.windows.contains(where: { $0 === window }), "window registers with NSApp")

    var resetCount = 0
    var aboutCount = 0
    let main = NSMenu()
    let fileItem = NSMenuItem(title: "File")
    let fileMenu = NSMenu(title: "File")
    fileMenu.addItem(withTitle: "Reset") { _ in resetCount += 1 }
    fileMenu.addItem(.separator())
    fileMenu.addItem(withTitle: "Quit") { _ in }
    main.addItem(fileItem)
    main.setSubmenu(fileMenu, for: fileItem)
    let helpItem = NSMenuItem(title: "Help")
    let helpMenu = NSMenu(title: "Help")
    helpMenu.addItem(withTitle: "About") { _ in aboutCount += 1 }
    main.addItem(helpItem)
    main.setSubmenu(helpMenu, for: helpItem)
    NSApplication.shared.mainMenu = main

    let bars = backend.menuBars[window.handle.rawValue]
    check(bars?.count == 2, "menu bar installs two top-level menus")
    check(bars?.first?.title == "File" && bars?.last?.title == "Help", "menu titles preserved")
    check(bars?.first?.items.count == 3, "File menu has three items (incl. separator)")
    check(bars?.first?.items[1].isSeparator == true, "separator carried through the seam")

    backend.simulateMenuActivate(window.handle, menu: 0, item: 0)
    check(resetCount == 1, "File > Reset action fires")
    backend.simulateMenuActivate(window.handle, menu: 1, item: 0)
    check(aboutCount == 1, "Help > About action fires")

    // A window created *after* the menu is set also gets the bar.
    let late = NSWindow(contentRect: NSMakeRect(0, 0, 300, 200),
                        styleMask: [.titled], backing: .buffered, defer: false)
    check(backend.menuBars[late.handle.rawValue]?.count == 2, "late window inherits the main menu")
}

// MARK: 12 — Alert
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    let alert = NSAlert()
    alert.messageText = "Save changes?"
    alert.informativeText = "Your edits will be lost otherwise."
    alert.addButton(withTitle: "Save")
    alert.addButton(withTitle: "Discard")

    backend.nextAlertResponse = 0
    check(alert.runModal() == NSAlertFirstButtonReturn, "first button maps to NSAlertFirstButtonReturn")
    backend.nextAlertResponse = 1
    check(alert.runModal() == NSAlertSecondButtonReturn, "second button maps to NSAlertSecondButtonReturn")

    let recorded = backend.alerts.last
    check(recorded?.message == "Save changes?", "alert message reaches the backend")
    check(recorded?.buttons == ["Save", "Discard"], "alert buttons preserved in order")

    let bare = NSAlert()
    bare.messageText = "Hi"
    backend.nextAlertResponse = 0
    check(bare.runModal() == NSAlertFirstButtonReturn, "buttonless alert defaults to OK")
    check(backend.alerts.last?.buttons == ["OK"], "default OK button synthesized")
}

// MARK: 13 — Image view
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    check(NSImage(contentsOfFile: "/nonexistent/nope.png") == nil, "NSImage nil for missing file")

    // Package.swift is a file guaranteed to exist relative to the test cwd.
    let image = NSImage(contentsOfFile: "Package.swift")
    check(image != nil, "NSImage loads an existing file")

    let view = NSImageView(frame: NSMakeRect(0, 0, 100, 100))
    view.image = image
    check(backend.imagePaths[view.handle.rawValue] == "Package.swift", "image path reaches the backend")
    view.image = nil
    check(backend.imagePaths[view.handle.rawValue] == nil, "nil image clears the path")
}

if failures == 0 {
    print("\nAll contract tests passed.")
} else {
    print("\n\(failures) contract test(s) FAILED.")
    exit(1)
}
