// LinChocolate contract tests — hermetic, no display.
//
// These run against the in-memory backend and prove the AppKit-shaped API is
// genuinely backend-swappable (validation spike S4): the exact code path a real
// GTK click would take is exercised here through simulated input. Mirrors
// WinChocolate's executable contract-test style; exits non-zero on any failure.

import LinChocolate
import Foundation
// swift-corelibs-foundation also exports NSSortDescriptor (deprecated, no `key:`
// init); pull LinChocolate's into direct scope so the name resolves to ours.
import class LinChocolate.NSSortDescriptor

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

// MARK: 14 — Token field
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    let field = NSTokenField(tokens: ["a", "b"], frame: NSMakeRect(0, 0, 300, 36))
    check(backend.tokensByHandle[field.handle.rawValue] == ["a", "b"], "initial tokens reach the backend")
    check(field.objectValue == ["a", "b"], "objectValue reflects initial tokens")

    var changed: [String]?
    field.onTokensChange = { changed = $0.objectValue }
    backend.simulateTokensChange(field.handle, ["a", "b", "c"])
    check(field.objectValue == ["a", "b", "c"], "tokens sync from native add")
    check(changed == ["a", "b", "c"], "onTokensChange fires with new tokens")

    field.objectValue = ["x"]
    check(backend.tokensByHandle[field.handle.rawValue] == ["x"], "token setter writes through")
}

// MARK: 15 — Fonts and text color
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    let label = NSTextField(labelWithString: "styled", frame: NSMakeRect(0, 0, 100, 24))
    label.font = .boldSystemFont(ofSize: 18)
    let recorded = backend.fonts[label.handle.rawValue]
    check(recorded?.size == 18 && recorded?.bold == true, "bold system font reaches the backend")
    check(recorded?.family == nil, "system font has no explicit family")

    label.font = NSFont(name: "Serif", size: 14)
    check(backend.fonts[label.handle.rawValue]?.family == "Serif", "named font family carries through")

    label.textColor = .red
    check(backend.textColors[label.handle.rawValue] == .red, "text color writes through")

    let notes = NSTextView(string: "x", frame: NSMakeRect(0, 0, 200, 80))
    notes.font = .monospacedSystemFont(ofSize: 12)
    check(backend.fonts[notes.handle.rawValue]?.family == "Monospace", "text view font writes through")
    notes.textColor = .blue
    check(backend.textColors[notes.handle.rawValue] == .blue, "text view color writes through")
}

// MARK: 16 — Table view
final class TestTableData: NSTableViewDataSource {
    var rows = [("a", "1"), ("b", "2"), ("c", "3")]
    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        tableColumn?.identifier == "right" ? rows[row].1 : rows[row].0
    }
}
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    let table = NSTableView(frame: NSMakeRect(0, 0, 300, 200))
    let left = NSTableColumn(identifier: "left"); left.title = "Left"
    let right = NSTableColumn(identifier: "right"); right.title = "Right"
    table.addTableColumn(left)
    table.addTableColumn(right)
    check(backend.tableColumns[table.handle.rawValue] == ["Left", "Right"], "columns reach the backend in order")

    let data = TestTableData()
    table.dataSource = data
    check(backend.tableRowCounts[table.handle.rawValue] == 3, "dataSource assignment reloads row count")
    check(backend.tableCellText(table.handle, row: 1, column: 0) == "b", "cell provider resolves column 0")
    check(backend.tableCellText(table.handle, row: 2, column: 1) == "3", "cell provider resolves column 1")

    data.rows.append(("d", "4"))
    table.reloadData()
    check(backend.tableRowCounts[table.handle.rawValue] == 4, "reloadData picks up new rows")

    var selected = -2
    table.onSelectionChange = { selected = $0.selectedRow }
    backend.simulateSelection(table.handle, 2)
    check(table.selectedRow == 2, "selection syncs from native click")
    check(selected == 2, "onSelectionChange fires with the row")

    table.selectRow(at: 1)
    check(backend.selectedIndex(table.handle) == 1, "programmatic selectRow writes through")
}

// MARK: 17 — Outline view
final class TestNode {
    let name: String
    let children: [TestNode]
    init(_ name: String, _ children: [TestNode] = []) { self.name = name; self.children = children }
}
final class TestOutlineData: NSOutlineViewDataSource {
    let roots = [TestNode("A", [TestNode("A1"), TestNode("A2", [TestNode("A2x")])]), TestNode("B")]
    private func children(of item: Any?) -> [TestNode] { (item as? TestNode)?.children ?? roots }
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        children(of: item).count
    }
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        children(of: item)[index]
    }
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        !((item as? TestNode)?.children.isEmpty ?? true)
    }
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        guard let node = item as? TestNode else { return nil }
        return tableColumn?.identifier == "count" ? node.children.count : node.name
    }
}
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    let outline = NSOutlineView(frame: NSMakeRect(0, 0, 300, 200))
    let name = NSTableColumn(identifier: "name"); name.title = "Name"
    let count = NSTableColumn(identifier: "count"); count.title = "Count"
    outline.addTableColumn(name)
    outline.addTableColumn(count)
    check(backend.outlineColumns[outline.handle.rawValue] == ["Name", "Count"], "outline columns reach the backend")

    let data = TestOutlineData()   // strong ref: dataSource is weak
    outline.dataSource = data
    check(backend.outlineRootCounts[outline.handle.rawValue] == 2, "root count from dataSource")
    check(backend.outlineChildCount(outline.handle, path: "0") == 2, "expandable root reports children")
    check(backend.outlineChildCount(outline.handle, path: "1") == 0, "leaf root reports none")
    check(backend.outlineChildCount(outline.handle, path: "0.1") == 1, "nested child count resolves")
    check(backend.outlineCellText(outline.handle, path: "0.1", column: 0) == "A2", "cell text resolves path column 0")
    check(backend.outlineCellText(outline.handle, path: "0.1", column: 1) == "1", "cell text resolves path column 1")
    check(backend.outlineCellText(outline.handle, path: "0.1.0", column: 0) == "A2x", "deep path resolves")

    var selected = -2
    outline.onSelectionChange = { selected = $0.selectedRow }
    backend.simulateSelection(outline.handle, 1)
    check(outline.selectedRow == 1 && selected == 1, "outline selection syncs and fires")
}

// MARK: 18 — Collection view
final class TestGridData: NSCollectionViewDataSource {
    var items = ["x", "y", "z"]
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int { items.count }
    func collectionView(_ collectionView: NSCollectionView, representedObjectForItemAt index: Int) -> Any? { items[index] }
}
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    let grid = NSCollectionView(frame: NSMakeRect(0, 0, 300, 200))
    let data = TestGridData()   // strong ref: dataSource is weak
    grid.dataSource = data
    check(backend.collectionItemCounts[grid.handle.rawValue] == 3, "item count from dataSource")
    check(backend.collectionItemText(grid.handle, index: 1) == "y", "item provider resolves")

    data.items.append("w")
    grid.reloadData()
    check(backend.collectionItemCounts[grid.handle.rawValue] == 4, "reloadData picks up new items")

    var selected = -2
    grid.onSelectionChange = { selected = $0.selectedIndex }
    backend.simulateSelection(grid.handle, 2)
    check(grid.selectedIndex == 2 && selected == 2, "collection selection syncs and fires")
    check(grid.selectionIndexes == IndexSet(integer: 2), "selectionIndexes reflects the selection")
}

// MARK: 19 — Toolbar
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    let window = NSWindow(contentRect: NSMakeRect(0, 0, 300, 200),
                          styleMask: [.titled], backing: .buffered, defer: false)
    var opened = 0
    let toolbar = NSToolbar(identifier: "main")
    let open = NSToolbarItem(itemIdentifier: "open")
    open.label = "Open"
    open.onAction = { _ in opened += 1 }
    toolbar.addItem(open)
    toolbar.addItem(.flexibleSpace())
    let save = NSToolbarItem(itemIdentifier: "save")
    save.label = "Save"
    toolbar.addItem(save)
    window.toolbar = toolbar

    let specs = backend.toolbars[window.handle.rawValue]
    check(specs?.count == 3, "toolbar installs three items")
    check(specs?[0].label == "Open" && specs?[2].label == "Save", "item labels preserved in order")
    check(specs?[1].isFlexibleSpace == true, "flexible space carried through the seam")

    backend.simulateToolbarActivate(window.handle, item: 0)
    check(opened == 1, "toolbar item action fires")

    // Adding an item after install refreshes the toolbar.
    let extra = NSToolbarItem(itemIdentifier: "extra")
    extra.label = "Extra"
    toolbar.addItem(extra)
    check(backend.toolbars[window.handle.rawValue]?.count == 4, "late-added item reinstalls the bar")
}

// MARK: 19 — Open/save panels
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    let open = NSOpenPanel()
    backend.nextOpenPanelPath = "/tmp/pick.txt"
    check(open.runModal() == NSModalResponseOK, "open panel returns OK for a chosen path")
    check(open.url?.path == "/tmp/pick.txt", "open panel url set")
    check(open.urls.map(\.path) == ["/tmp/pick.txt"], "open panel urls set")

    backend.nextOpenPanelPath = nil
    check(open.runModal() == NSModalResponseCancel, "open panel returns Cancel for nil")

    let save = NSSavePanel()
    save.nameFieldStringValue = "report.md"
    save.directoryURL = URL(fileURLWithPath: "/tmp")
    backend.nextSavePanelPath = "/tmp/report.md"
    check(save.runModal() == NSModalResponseOK, "save panel returns OK")
    check(save.url?.path == "/tmp/report.md", "save panel url set")
    check(backend.savePanelRuns.last?.suggestedName == "report.md", "suggested name reaches the backend")
    check(backend.savePanelRuns.last?.directory == "/tmp", "initial directory reaches the backend")
}

// MARK: 20 — Attributed strings
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    let text = NSMutableAttributedString(string: "hello world")
    text.addAttribute(.foregroundColor, value: NSColor.red, range: NSMakeRange(0, 5))
    text.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 14), range: NSMakeRange(6, 5))
    let runs = text.nativeRuns()
    check(runs.count == 3, "attributes split into three runs")
    check(runs[0].text == "hello" && runs[0].color == .red && runs[0].font == nil, "first run colored")
    check(runs[1].text == " " && runs[1].color == nil && runs[1].font == nil, "middle run plain")
    check(runs[2].text == "world" && runs[2].font?.bold == true, "last run bold")

    let label = NSTextField(labelWithString: "", frame: NSMakeRect(0, 0, 200, 24))
    label.attributedStringValue = text
    check(backend.styledTexts[label.handle.rawValue]?.count == 3, "styled runs reach the backend")
    check(backend.text(for: label.handle) == "hello world", "plain text recorded alongside runs")
}

// MARK: 21 — Custom drawing (NSView.draw + NSBezierPath)
final class TestCanvas: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.red.setFill()
        NSBezierPath(rect: NSMakeRect(10, 20, 30, 40)).fill()
        NSColor.blue.setStroke()
        let line = NSBezierPath()
        line.move(to: NSMakePoint(0, 0))
        line.line(to: NSMakePoint(50, 50))
        line.lineWidth = 3
        line.stroke()
    }
}
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    let canvas = TestCanvas(frame: NSMakeRect(0, 0, 200, 100))
    canvas.needsDisplay = true
    let ops = backend.lastDrawOps[canvas.handle.rawValue] ?? []
    check(backend.displayRequests[canvas.handle.rawValue] == 1, "needsDisplay triggers a draw pass")
    check(ops.contains("fillColor(1.00,0.00,0.00)"), "fill color reaches the context")
    check(ops.contains("move(10,20)") && ops.contains("line(40,20)") && ops.contains("close"),
          "rect path replays into the context")
    check(ops.contains("fill"), "fill consumes the path")
    check(ops.contains("strokeColor(0.00,0.00,1.00)") && ops.contains("lineWidth(3)") && ops.contains("stroke"),
          "stroke color, width, and stroke op recorded")
    let fillIndex = ops.firstIndex(of: "fill")!
    let strokeIndex = ops.firstIndex(of: "stroke")!
    check(fillIndex < strokeIndex, "draw order preserved")

    // Oval renders as four curves.
    final class OvalCanvas: NSView {
        override func draw(_ dirtyRect: NSRect) {
            NSBezierPath(ovalIn: NSMakeRect(0, 0, 100, 100)).fill()
        }
    }
    let ovalCanvas = OvalCanvas(frame: NSMakeRect(0, 0, 100, 100))
    ovalCanvas.needsDisplay = true
    let ovalOps = backend.lastDrawOps[ovalCanvas.handle.rawValue] ?? []
    check(ovalOps.filter { $0.hasPrefix("curve") }.count == 4, "oval builds four bezier arcs")
}

// MARK: 22 — Auto Layout (NSLayoutConstraint + anchors + solver)
@MainActor
func approx(_ a: CGFloat, _ b: CGFloat, _ label: String) {
    check(abs(a - b) < 0.01, "\(label) (\(a) ≈ \(b))")
}
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    // Leading / centered / trailing row, sized and positioned only by constraints.
    let container = NSView(frame: NSMakeRect(0, 0, 486, 300))
    func box() -> NSView {
        let v = NSView(frame: .zero)
        v.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(v)
        return v
    }
    let a = box(), b = box(), c = box()
    NSLayoutConstraint.activate([
        a.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
        a.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        a.widthAnchor.constraint(equalToConstant: 130),
        a.heightAnchor.constraint(equalToConstant: 70),

        b.centerXAnchor.constraint(equalTo: container.centerXAnchor),
        b.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        b.widthAnchor.constraint(equalToConstant: 130),
        b.heightAnchor.constraint(equalToConstant: 70),

        c.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
        c.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        c.widthAnchor.constraint(equalToConstant: 130),
        c.heightAnchor.constraint(equalToConstant: 70),
    ])
    container.layoutSubtreeIfNeeded()

    approx(a.frame.minX, 16, "leading box pinned left"); approx(a.frame.minY, 115, "leading box vertically centered")
    approx(a.frame.width, 130, "leading box width"); approx(a.frame.height, 70, "leading box height")
    approx(b.frame.minX, 178, "center box centered X"); approx(b.frame.minY, 115, "center box centered Y")
    approx(c.frame.minX, 340, "trailing box pinned right"); approx(c.frame.minY, 115, "trailing box centered Y")
    // Frames reached the backend, not just the API object.
    check(backend.frames[a.handle.rawValue]?.width == 130, "solved frame routes to the backend")

    // Multiplier constraint: width = half the container.
    let half = NSView(frame: .zero)
    half.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(half)
    NSLayoutConstraint.activate([
        half.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.5),
        half.leadingAnchor.constraint(equalTo: container.leadingAnchor),
    ])
    container.layoutSubtreeIfNeeded()
    approx(half.frame.width, 243, "multiplier constraint yields half width")

    // Sibling chain: view2 sits 10pt to the right of view1's trailing edge.
    let chainContainer = NSView(frame: NSMakeRect(0, 0, 400, 100))
    let v1 = NSView(frame: .zero); v1.translatesAutoresizingMaskIntoConstraints = false
    let v2 = NSView(frame: .zero); v2.translatesAutoresizingMaskIntoConstraints = false
    chainContainer.addSubview(v1); chainContainer.addSubview(v2)
    NSLayoutConstraint.activate([
        v1.leadingAnchor.constraint(equalTo: chainContainer.leadingAnchor, constant: 20),
        v1.widthAnchor.constraint(equalToConstant: 100),
        v2.leadingAnchor.constraint(equalTo: v1.trailingAnchor, constant: 10),
        v2.widthAnchor.constraint(equalToConstant: 50),
    ])
    chainContainer.layoutSubtreeIfNeeded()
    approx(v1.frame.minX, 20, "chain: first view leading")
    approx(v2.frame.minX, 130, "chain: second view follows first's trailing + gap")

    // translates=true subview stays a fixed anchor point for its siblings.
    check(v1.translatesAutoresizingMaskIntoConstraints == false, "opted-in view is solver-driven")
}

// MARK: 23 — Appearance & materials (NSAppearance + NSVisualEffectView)
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend
    NSApplication.shared.appearance = nil

    check(NSApplication.shared.effectiveAppearance == .aqua, "default effective appearance is aqua (light)")
    check(backend.appearanceIsDark == false, "backend starts light")
    check(NSAppearance.darkAqua.isDark && !NSAppearance.aqua.isDark, "isDark distinguishes the variants")

    NSApplication.shared.appearance = .darkAqua
    check(backend.appearanceIsDark == true, "setting darkAqua flips the backend to dark")
    check(NSApplication.shared.effectiveAppearance.isDark, "effectiveAppearance reports dark")

    // A view's effectiveAppearance follows the app.
    let view = NSView(frame: NSMakeRect(0, 0, 10, 10))
    check(view.effectiveAppearance.isDark, "a view's effective appearance tracks the app")

    NSApplication.shared.appearance = .aqua
    check(backend.appearanceIsDark == false, "switching back to aqua un-darkens the backend")

    // NSVisualEffectView carries its material across the seam.
    let sidebar = NSVisualEffectView(frame: NSMakeRect(0, 0, 200, 400), material: .sidebar)
    check(backend.materials[sidebar.handle.rawValue] == "sidebar", "visual-effect view records its material")
    sidebar.material = .hudWindow
    check(backend.materials[sidebar.handle.rawValue] == "hudWindow", "changing material writes through")
    // It's a real NSView — it hosts subviews.
    let child = NSButton(title: "In material", frame: NSMakeRect(8, 8, 100, 24))
    sidebar.addSubview(child)
    check(backend.subviews[sidebar.handle.rawValue]?.contains(child.handle.rawValue) == true,
          "visual-effect view hosts subviews like any NSView")

    NSApplication.shared.appearance = nil   // leave the shared app as we found it
}

// MARK: 24 — Pasteboard & drag-and-drop (NSPasteboard + NSView DnD)
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    // Pasteboard copy/paste round-trip.
    let pb = NSPasteboard.general
    let before = pb.clearContents()
    check(pb.setString("hello clipboard", forType: .string), "setString reports success")
    check(pb.string(forType: .string) == "hello clipboard", "string round-trips through the board")
    check(backend.clipboard == "hello clipboard", "general board pushes to the system clipboard")
    check(pb.clearContents() == before + 1, "clearContents bumps the change count")
    check(pb.string(forType: .string) == nil, "cleared board holds nothing")

    // A drop destination consumes a dropped string.
    let dropZone = NSView(frame: NSMakeRect(0, 0, 200, 100))
    var dropped: String?
    var enteredMask: NSDragOperation = .none
    dropZone.onDraggingEntered = { info in
        enteredMask = info.draggingSourceOperationMask
        return .copy
    }
    dropZone.onPerformDragOperation = { info in
        dropped = info.draggingPasteboard.string(forType: .string)
        return true
    }
    dropZone.registerForDraggedTypes([.string])
    check(backend.dropTargetTypes[dropZone.handle.rawValue] == ["public.utf8-plain-text"],
          "registered dragged types reach the backend")
    let accepted = backend.simulateDrop("dragged text", at: NSMakePoint(10, 20), on: dropZone.handle)
    check(accepted == true, "destination accepts the drop")
    check(dropped == "dragged text", "performDragOperation reads the drop off the pasteboard")
    check(enteredMask == .copy, "draggingEntered sees the source operation mask")

    // A destination that rejects in draggingEntered blocks the drop.
    let picky = NSView(frame: NSMakeRect(0, 0, 50, 50))
    var pickyGotDrop = false
    picky.onDraggingEntered = { _ in .none }
    picky.onPerformDragOperation = { _ in pickyGotDrop = true; return true }
    picky.registerForDraggedTypes([.string])
    check(backend.simulateDrop("nope", on: picky.handle) == false, "draggingEntered .none rejects the drop")
    check(pickyGotDrop == false, "rejected drop never reaches performDragOperation")

    // Source → destination transfer via a real drag session.
    let source = NSView(frame: NSMakeRect(0, 0, 40, 40))
    source.registerDraggingSource { "payload from source" }
    var landed: String?
    let target = NSView(frame: NSMakeRect(0, 0, 40, 40))
    target.onPerformDragOperation = { info in landed = info.draggingPasteboard.string(forType: .string); return true }
    target.registerForDraggedTypes([.string])
    check(backend.simulateDragAndDrop(from: source.handle, to: target.handle) == true, "drag session completes")
    check(landed == "payload from source", "the source's provided string arrives at the destination")
}

// MARK: 25 — Composed text layouts (NSForm + NSMatrix)
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    // NSForm: labelled rows backed by real text fields.
    let form = NSForm(frame: NSMakeRect(0, 0, 256, 92))
    form.titleWidth = 72
    let nameCell = form.addEntry("Name:")
    let statusCell = form.addEntry("Status:")
    check(form.cells.count == 2, "form tracks its rows")
    check(backend.subviews[form.handle.rawValue]?.count == 4, "each row adds a label + a field")
    nameCell.stringValue = "LinChocolate"
    check(form.textField(at: 0)?.stringValue == "LinChocolate", "cell value reaches the row's field")
    form.setStringValue("Native", at: 1)
    check(statusCell.stringValue == "Native", "setStringValue(at:) writes the row")
    check(backend.text(for: statusCell.textField.handle) == "Native", "field text reaches the backend")
    // The row's field is a live text field: editing it drives onTextChange.
    var edited: String?
    form.textField(at: 1)?.onTextChange = { edited = $0.stringValue }
    backend.simulateTextChange(statusCell.textField.handle, "Edited")
    check(edited == "Edited", "editing a form field fires onTextChange")

    // NSMatrix: a rows×columns button grid.
    let matrix = NSMatrix(frame: NSMakeRect(0, 0, 240, 72), mode: .trackModeMatrix,
                          prototype: NSButtonCell(title: "Choice"),
                          numberOfRows: 2, numberOfColumns: 2)
    matrix.cellSize = NSMakeSize(104, 28)
    matrix.intercellSpacing = NSMakeSize(8, 8)
    check(backend.subviews[matrix.handle.rawValue]?.count == 4, "matrix builds one button per cell")
    check(matrix.selectedRow == -1 && matrix.selectedColumn == -1, "matrix starts unselected")
    matrix.selectCell(atRow: 0, column: 1)
    check(matrix.selectedRow == 0 && matrix.selectedColumn == 1, "selectCell records the selection")

    var firedRC: (Int, Int)?
    matrix.onAction = { m in firedRC = (m.selectedRow, m.selectedColumn) }
    // Clicking the bottom-right cell (row 1, col 1) selects it and fires onAction.
    let cells = matrix.subviews   // row-major: [ (0,0),(0,1),(1,0),(1,1) ]
    backend.simulateClick(cells[3].handle)
    check(matrix.selectedRow == 1 && matrix.selectedColumn == 1, "clicking a cell selects it")
    check(firedRC?.0 == 1 && firedRC?.1 == 1, "cell click fires onAction with the cell's row/column")
}

// MARK: 26 — Scrolling stack (NSScrollView + NSClipView + NSScroller)
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    // 200×100 viewport onto a 200×400 document.
    let scrollView = NSScrollView(frame: NSMakeRect(0, 0, 200, 100))
    let document = NSView(frame: NSMakeRect(0, 0, 200, 400))
    scrollView.documentView = document

    check(scrollView.contentView.documentRect == NSMakeRect(0, 0, 200, 400), "clip view reports the document rect")
    check(scrollView.documentVisibleRect == NSMakeRect(0, 0, 200, 100), "visible rect starts at the top-left")
    check(scrollView.verticalScroller.isVisible, "vertical scroller shows when content overflows")
    check(!scrollView.horizontalScroller.isVisible, "horizontal scroller hidden when content fits width")
    check(abs(scrollView.verticalScroller.knobProportion - 0.25) < 0.001, "knob proportion = visible/document (100/400)")

    // Scroller policy reaches the backend.
    scrollView.hasHorizontalScroller = false
    check(backend.scrollerPolicies[scrollView.handle.rawValue]?.horizontal == false, "scroller policy reaches the backend")

    // Programmatic scroll, clamped to the range and reported.
    var scrolled: NSPoint?
    scrollView.onScroll = { scrolled = $0 }
    scrollView.scroll(to: NSMakePoint(0, 150))
    check(scrollView.documentVisibleRect.origin.y == 150, "scroll(to:) moves the visible rect")
    check(scrollView.contentView.bounds.origin.y == 150, "clip view bounds origin follows the offset")
    check(scrolled == NSMakePoint(0, 150), "onScroll fires with the new offset")
    check(abs(scrollView.verticalScroller.doubleValue - 0.5) < 0.001, "scroller knob at 0.5 (150 of 300 range)")

    // Over-scroll clamps to the max offset (document 400 − visible 100 = 300).
    backend.simulateScroll(to: NSMakePoint(0, 999), on: scrollView.handle)
    check(scrollView.documentVisibleRect.origin.y == 300, "over-scroll clamps to the bottom")
    check(abs(scrollView.verticalScroller.doubleValue - 1.0) < 0.001, "scroller knob at the end")

    // scrollToEndOfDocument lands exactly at the max offset (last content at the
    // bottom edge, not overshot); scrollToBeginningOfDocument returns to the top.
    scrollView.scrollToBeginningOfDocument()
    check(scrollView.documentVisibleRect.origin.y == 0, "scrollToBeginningOfDocument returns to the top")
    scrollView.scrollToEndOfDocument()
    check(scrollView.documentVisibleRect.origin.y == 300, "scrollToEndOfDocument aligns the document end to the viewport bottom")
}

// MARK: 27 — Table sorting + double-click (NSSortDescriptor)
final class SortableTableSource: NSTableViewDataSource {
    var rows = ["Beta", "Alpha", "Gamma"]
    var lastSortKey: String?
    var lastAscending: Bool?
    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }
    func tableView(_ t: NSTableView, objectValueFor c: NSTableColumn?, row: Int) -> Any? { rows[row] }
    func tableView(_ t: NSTableView, sortDescriptorsDidChange old: [NSSortDescriptor]) {
        guard let d = t.sortDescriptors.first else { return }
        lastSortKey = d.key
        lastAscending = d.ascending
        rows.sort(by: d.ascending ? { $0 < $1 } : { $0 > $1 })
        t.reloadData()
    }
}
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    let table = NSTableView(frame: NSMakeRect(0, 0, 300, 200))
    let nameCol = NSTableColumn(identifier: "name")
    nameCol.title = "Name"
    nameCol.sortDescriptorPrototype = NSSortDescriptor(key: "name", ascending: true)
    table.addTableColumn(nameCol)
    let source = SortableTableSource()
    table.dataSource = source

    check(backend.sortableColumns[table.handle.rawValue]?.contains(0) == true, "column with a prototype becomes sortable")
    check(backend.tableColumns[table.handle.rawValue]?.first == "Name", "column header title reaches the backend")

    // Live retitle.
    nameCol.title = "Renamed"
    check(backend.tableColumns[table.handle.rawValue]?.first == "Renamed", "retitling a column updates the live header")

    // Header click (descending) → sortDescriptors update + data source re-sorts.
    backend.simulateSortColumn(0, ascending: false, on: table.handle)
    check(table.sortDescriptors.first?.key == "name", "clicking a header sets the column's sort key")
    check(table.sortDescriptors.first?.ascending == false, "sort direction reflects the click")
    check(source.lastSortKey == "name" && source.lastAscending == false, "data source's sortDescriptorsDidChange fires")
    check(source.rows == ["Gamma", "Beta", "Alpha"], "data source re-sorted descending")

    // Reversed descriptor helper.
    check(NSSortDescriptor(key: "x", ascending: true).reversedSortDescriptor.ascending == false, "reversedSortDescriptor flips direction")

    // Double-click activation.
    var activated: Int?
    table.onDoubleClick = { activated = $0 }
    backend.simulateRowActivate(2, on: table.handle)
    check(activated == 2, "onDoubleClick fires with the activated row")
    check(table.selectedRow == 2, "row activation also selects the row")
}

// MARK: 28 — NSBrowser (column navigation)
final class DemoBrowser: NSBrowserDelegate {
    let roots = ["Application", "Controls", "Tables"]
    let children = [
        "Application": ["NSApplication", "NSWindow"],
        "Controls": ["NSButton", "NSTextField", "NSBrowser"],
        "Tables": ["NSTableView", "NSOutlineView"],
    ]
    func browser(_ b: NSBrowser, numberOfChildrenOfItem item: Any?) -> Int {
        guard let item else { return roots.count }
        return children[String(describing: item)]?.count ?? 0
    }
    func browser(_ b: NSBrowser, child index: Int, ofItem item: Any?) -> Any {
        guard let item else { return roots[index] }
        return children[String(describing: item)]?[index] ?? ""
    }
    func browser(_ b: NSBrowser, isLeafItem item: Any?) -> Bool {
        guard let item else { return false }
        return children[String(describing: item)] == nil
    }
}
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    let browser = NSBrowser(frame: NSMakeRect(0, 0, 480, 150))
    browser.columnWidth = 160
    let delegate = DemoBrowser()
    browser.delegate = delegate
    browser.loadColumnZero()

    check(browser.numberOfRows(inColumn: 0) == 3, "column zero shows the root items")
    check(browser.numberOfRows(inColumn: 1) == 0, "deeper columns empty until a parent is selected")
    check(browser.path() == "/", "path starts at root")

    // Drill into "Controls" (index 1) → column 1 shows its 3 children.
    browser.selectRow(1, inColumn: 0)
    check(browser.numberOfRows(inColumn: 1) == 3, "selecting a parent populates the next column")
    check(browser.path() == "/Controls", "path reflects the first selection")
    check(browser.selectedRow(inColumn: 0) == 1, "selectedRow(inColumn:) reports the selection")

    // Drill into "NSTextField" (index 1 of Controls).
    browser.selectRow(1, inColumn: 1)
    check(browser.path() == "/Controls/NSTextField", "path extends through the second column")
    // NSTextField is a leaf → column 2 empty.
    check(browser.numberOfRows(inColumn: 2) == 0, "a leaf selection leaves the next column empty")

    // Re-selecting a shallower column truncates the deeper path.
    browser.selectRow(2, inColumn: 0)   // "Tables"
    check(browser.path() == "/Tables", "changing a shallow selection truncates the path")
    check(browser.numberOfRows(inColumn: 1) == 2, "and repopulates the next column for the new parent")
}

// MARK: 29 — Gradients + arcs + rounded rects (NSGradient / NSBezierPath)
final class GradientCanvas: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSGradient(starting: .red, ending: .blue)?.draw(in: NSMakeRect(0, 0, 100, 50), angle: 90)
        let circle = NSBezierPath()
        circle.appendArc(withCenter: NSMakePoint(50, 50), radius: 20, startAngle: 0, endAngle: 360)
        NSColor.green.setFill()
        circle.fill()
        let capsule = NSBezierPath(roundedRect: NSMakeRect(10, 10, 80, 40), xRadius: 8, yRadius: 8)
        NSGradient(colorsAndLocations: (.red, 0), (.green, 0.5), (.blue, 1))?.draw(in: capsule, angle: 45)
    }
}
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    let canvas = GradientCanvas(frame: NSMakeRect(0, 0, 120, 80))
    canvas.needsDisplay = true
    let ops = backend.lastDrawOps[canvas.handle.rawValue] ?? []

    check(ops.contains { $0.hasPrefix("linearGradient[1.00,0.00,0.00;0.00,0.00,1.00]@90") },
          "linear gradient fills a rect with its stops at the given angle")
    check(ops.contains("arc(50,50,20)"), "appendArc reaches the context as an arc op")
    // Path-clipped gradient: save → build path → clip → gradient → restore.
    let save = ops.firstIndex(of: "save"), clip = ops.firstIndex(of: "clip"), restore = ops.firstIndex(of: "restore")
    check(save != nil && clip != nil && restore != nil && save! < clip! && clip! < restore!,
          "path gradient clips inside a save/restore scope")
    check(ops.contains { $0.hasPrefix("linearGradient[1.00,0.00,0.00;0.00,1.00,0.00;0.00,0.00,1.00]") },
          "three-stop gradient carries all stops")
    // Rounded rect builds four Bézier corners + four edges.
    check(ops.filter { $0.hasPrefix("curve") }.count >= 4, "rounded rect uses four Bézier corners")

    check(NSGradient(colors: [.red])?.numberOfColorStops == nil, "a one-color gradient is nil (needs ≥2)")
    check(NSGradient(colors: [.red, .green, .blue])?.numberOfColorStops == 3, "colors init spaces stops evenly")

    let path = NSBezierPath(roundedRect: NSMakeRect(10, 20, 100, 40), xRadius: 5, yRadius: 5)
    check(!path.isEmpty, "rounded rect path is non-empty")
    check(abs(path.bounds.width - 100) < 0.01 && abs(path.bounds.minX - 10) < 0.01, "path bounds cover the rect")
}

// MARK: 30 — NSPopover
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    let anchor = NSButton(title: "Anchor", frame: NSMakeRect(0, 0, 80, 30))
    let content = NSView(frame: .zero)
    content.addSubview(NSTextField(labelWithString: "Hello", frame: NSMakeRect(8, 8, 100, 20)))

    let popover = NSPopover()
    popover.behavior = .transient
    popover.contentSize = NSMakeSize(220, 120)
    popover.contentViewController = NSViewController(view: content)

    check(!popover.isShown, "popover starts hidden")
    check(backend.shownPopovers.isEmpty, "no popovers shown initially")

    popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .maxY)
    check(popover.isShown, "show marks the popover shown")
    check(backend.shownPopovers.count == 1, "the popover reaches the backend as shown")
    check(content.frame.size == NSMakeSize(220, 120), "content view is sized to contentSize")
    check(backend.popoverContents.values.contains(content.handle.rawValue), "content installs into the popover")

    popover.performClose(nil)
    check(!popover.isShown, "performClose hides the popover")
    check(backend.shownPopovers.isEmpty, "closing removes it from the backend")

    // Re-show reuses the same popover handle.
    popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .maxY)
    check(backend.shownPopovers.count == 1, "re-showing works and reuses one popover")
}

if failures == 0 {
    print("\nAll contract tests passed.")
} else {
    print("\n\(failures) contract test(s) FAILED.")
    exit(1)
}
