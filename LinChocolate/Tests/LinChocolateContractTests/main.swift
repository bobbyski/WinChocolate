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
    open.image = NSImage(named: "document-open-symbolic")
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
    check(specs?[0].iconName == "document-open-symbolic", "toolbar item icon reaches the backend")
    check(specs?[2].iconName == nil, "an item without an image has no icon")
    check(specs?[1].isFlexibleSpace == true, "flexible space carried through the seam")
    check(NSImage(named: "") == nil, "an empty image name is rejected (AppKit init? semantics)")

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

/// A view whose `isFlipped` changes at runtime (AppKit re-reads it; a cache lies).
final class DynamicFlipView: NSView {
    var flipsNow = true
    override var isFlipped: Bool { flipsNow }
}

// MARK: 29a — NSScroller: a standalone scroller is a real scrollbar
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend
    let scroller = NSScroller(frame: NSMakeRect(128, 340, 240, 18))

    // It must be a scroller, not a bare view: a standalone NSScroller used to
    // fall through to NSView's initializer and render as an empty container.
    check(backend.kinds[scroller.handle.rawValue] == .scroller, "a standalone scroller creates a scrollbar")

    // AppKit's NSScroller is the one control that starts DISABLED (probed from
    // real AppKit: isEnabled == false, usableParts == .noScrollerParts).
    check(scroller.isEnabled == false, "an NSScroller starts disabled, unlike every other control")
    check(backend.enabledStates[scroller.handle.rawValue] == false, "and the native side agrees")

    scroller.isEnabled = true
    check(backend.enabledStates[scroller.handle.rawValue] == true, "enabling it reaches the backend")

    // Geometry reaches the backend as AppKit's 0...1 fractions.
    scroller.knobProportion = 0.25
    scroller.doubleValue = 0.5
    check(backend.scrollerGeometry[scroller.handle.rawValue]?.knobProportion == 0.25, "knobProportion reaches the backend")
    check(backend.scrollerGeometry[scroller.handle.rawValue]?.value == 0.5, "doubleValue reaches the backend")

    // Setting the value in code must NOT fire the action — only the user's drag
    // does. (It used to fire here, reporting positions nobody scrolled to.)
    var fired = 0
    scroller.onAction = { _ in fired += 1 }
    scroller.doubleValue = 0.8
    check(fired == 0, "setting doubleValue in code does not send the action")

    // A drag does, and syncs the value.
    backend.simulateScrollerDrag(to: 0.73, for: scroller.handle)
    check(fired == 1, "the user's drag sends the action")
    check(abs(scroller.doubleValue - 0.73) < 0.0001, "and the dragged value is readable")
}

// MARK: 29b — NSLevelIndicator: styles, rating, editability, thresholds
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend
    let level = NSLevelIndicator(frame: NSMakeRect(0, 0, 144, 18))

    // Apple's raw values, read from real AppKit.
    check(NSLevelIndicatorStyle.relevancy.rawValue == 0, "relevancy is 0")
    check(NSLevelIndicatorStyle.continuousCapacity.rawValue == 1, "continuousCapacity is 1")
    check(NSLevelIndicatorStyle.discreteCapacity.rawValue == 2, "discreteCapacity is 2")
    check(NSLevelIndicatorStyle.rating.rawValue == 3, "rating is 3")

    // These were all accepted-and-ignored stubs; the demo sets every one of them.
    level.minValue = 0
    level.maxValue = 100
    level.warningValue = 70
    level.criticalValue = 90
    level.isEditable = true
    check(backend.levelThresholds[level.handle.rawValue]?.warning == 70, "warningValue reaches the backend")
    check(backend.levelThresholds[level.handle.rawValue]?.critical == 90, "criticalValue reaches the backend")
    check(backend.levelEditable[level.handle.rawValue] == true, "isEditable reaches the backend")

    // An editable capacity bar takes clicks, as on Apple — not just a rating.
    var levelFired = 0
    level.onAction = { _ in levelFired += 1 }
    backend.simulateLevelClick(to: 80, for: level.handle)
    check(levelFired == 1, "clicking an editable capacity bar sends the action")
    check(level.doubleValue == 80, "and sets the level")

    // A rating: the span is the star count.
    let rating = NSLevelIndicator(frame: NSMakeRect(786, 264, 140, 30))
    rating.levelIndicatorStyle = .rating
    rating.minValue = 0
    rating.maxValue = 5
    rating.doubleValue = 3
    rating.isEditable = true
    check(backend.levelStyles[rating.handle.rawValue] == NSLevelIndicatorStyle.rating.rawValue,
          "the rating style reaches the backend (it used to be discarded)")
    var ratingFired = 0
    rating.onAction = { _ in ratingFired += 1 }
    backend.simulateLevelClick(to: 5, for: rating.handle)
    check(ratingFired == 1 && rating.doubleValue == 5, "clicking a star sets the rating")
}

// MARK: 30a — NSDatePicker: format, elements, and stepping the SELECTED field
//
// Expected strings were read out of REAL AppKit (a probe printing
// NSDatePicker.stringValue and rendering the control to a PNG), not invented:
//   field       -> "5/31/2026, 8:00:00 PM"
//   stringValue -> "Sunday, May 31, 2026 at 8:00:00 PM Eastern Daylight Time"
// for 2026-06-01T00:00Z in en_US / America/New_York.
//
// NOTE the \u{202F}: ICU puts a NARROW NO-BREAK SPACE before AM/PM, on macOS
// and Linux alike (verified by dumping scalars on both). It is spelled with an
// escape here so the literal can't silently differ from the code by an
// invisible character.
//
// The picker's own surface stays Apple-exact (no `segments`/`displayText` on
// the control), so the rendered text and selection are observed where they
// actually cross the boundary: the backend seam.
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend
    let start = Date(timeIntervalSince1970: 1_780_272_000)   // 5/31/2026 8:00:00 PM EDT

    /// A fresh picker per assertion: stepping mutates the date, and calendar
    /// arithmetic does not round-trip (see the month check below), so sharing
    /// one picker across checks makes later expectations drift.
    func picker(_ elements: NSDatePickerElementFlags = [.yearMonthDay, .hourMinuteSecond]) -> NSDatePicker {
        let p = NSDatePicker(date: start, frame: NSMakeRect(0, 0, 184, 28))
        p.locale = Locale(identifier: "en_US")
        p.timeZone = TimeZone(identifier: "America/New_York")!
        p.calendar = Calendar(identifier: .gregorian)
        p.datePickerElements = elements
        return p
    }
    func field(_ p: NSDatePicker) -> String { backend.datePickerTexts[p.handle.rawValue] ?? "" }
    func selection(_ p: NSDatePicker) -> (location: Int, length: Int)? {
        backend.datePickerSelections[p.handle.rawValue]
    }

    check(picker().datePickerStyle == .textFieldAndStepper, "the default style is textFieldAndStepper")

    // Apple's real raw values — cumulative, not 1<<n.
    check(NSDatePickerElementFlags.yearMonthDay.rawValue == 0x00e0, "yearMonthDay is Apple's 0xe0")
    check(NSDatePickerElementFlags.hourMinuteSecond.rawValue == 0x000e, "hourMinuteSecond is Apple's 0xe")
    check(NSDatePickerElementFlags.yearMonthDay.contains(.yearMonth), "yearMonthDay contains yearMonth")
    check(NSDatePickerElementFlags.hourMinuteSecond.contains(.hourMinute), "hourMinuteSecond contains hourMinute")

    // The field renders AppKit's locale format, not ISO.
    check(field(picker()) == "5/31/2026, 8:00:00\u{202F}PM",
          "the field renders AppKit's locale format (was ISO) — got [\(field(picker()))]")

    // stringValue is AppKit's full/full style, independent of the elements.
    check(picker().stringValue == "Sunday, May 31, 2026 at 8:00:00\u{202F}PM Eastern Daylight Time",
          "stringValue is AppKit's full date+time (was Swift's Date description)")

    // The leftmost field starts selected and highlighted.
    check(selection(picker())?.location == 0, "the first field starts selected")

    // Stepping moves THE SELECTED field. The bug: it always moved the day.
    let month = picker()
    backend.simulateDateStep(1, for: month.handle)
    check(field(month) == "6/30/2026, 8:00:00\u{202F}PM",
          "stepping the selected month moves the MONTH — got [\(field(month))]")
    // ...and May 31 + 1 month is June *30*: the day clamps to the shorter month,
    // so stepping back lands on May 30, not May 31. That is Gregorian
    // arithmetic (Calendar's, and AppKit's), not a rounding bug.
    backend.simulateDateStep(-1, for: month.handle)
    check(field(month) == "5/30/2026, 8:00:00\u{202F}PM",
          "month arithmetic clamps and does not round-trip — got [\(field(month))]")

    // Click the year and step it.
    let year = picker()
    backend.simulateDatePickerClick(atCharacter: 6, for: year.handle)
    check(selection(year)?.location == 5 && selection(year)?.length == 4,
          "clicking the year highlights the year")
    backend.simulateDateStep(1, for: year.handle)
    check(field(year) == "5/31/2027, 8:00:00\u{202F}PM",
          "stepping the selected year moves the YEAR — got [\(field(year))]")

    // Click the minute and step it.
    let minute = picker()
    let minuteOffset = field(minute).distance(from: field(minute).startIndex,
                                              to: field(minute).range(of: ":00:")!.lowerBound) + 1
    backend.simulateDatePickerClick(atCharacter: minuteOffset, for: minute.handle)
    backend.simulateDateStep(1, for: minute.handle)
    check(field(minute) == "5/31/2026, 8:01:00\u{202F}PM",
          "stepping the selected minute moves the MINUTE — got [\(field(minute))]")

    // Left/right move the selection, as AppKit's arrow keys do.
    let day = picker()
    backend.simulateDatePickerClick(atCharacter: 0, for: day.handle)
    backend.simulateDatePickerMove(1, for: day.handle)
    backend.simulateDateStep(1, for: day.handle)
    check(field(day) == "6/1/2026, 8:00:00\u{202F}PM",
          "after moving right, stepping moves the DAY — got [\(field(day))]")

    // The AM/PM field flips by half a day.
    let ampm = picker()
    backend.simulateDatePickerClick(atCharacter: field(ampm).count - 1, for: ampm.handle)
    backend.simulateDateStep(1, for: ampm.handle)
    check(field(ampm) == "6/1/2026, 8:00:00\u{202F}AM",
          "stepping AM/PM moves by twelve hours — got [\(field(ampm))]")

    // ── Typing into the selected element (AppKit's date field is type-to-edit;
    //    stepping a minute to 55 one click at a time is unusable). ──

    // Type a two-digit minute: digits accumulate, then the selection moves on.
    let typed = picker()
    let minuteAt = field(typed).distance(from: field(typed).startIndex,
                                         to: field(typed).range(of: ":00:")!.lowerBound) + 1
    backend.simulateDatePickerClick(atCharacter: minuteAt, for: typed.handle)
    backend.simulateDatePickerTyping("4", for: typed.handle)
    check(field(typed) == "5/31/2026, 8:04:00\u{202F}PM",
          "the first digit applies immediately — got [\(field(typed))]")
    backend.simulateDatePickerTyping("5", for: typed.handle)
    check(field(typed) == "5/31/2026, 8:45:00\u{202F}PM",
          "the second digit extends it to 45, not 5 — got [\(field(typed))]")
    // The field was full, so the selection advanced to the seconds.
    backend.simulateDatePickerTyping("3", for: typed.handle)
    check(field(typed) == "5/31/2026, 8:45:03\u{202F}PM",
          "a full field advances, so the next digit lands in seconds — got [\(field(typed))]")

    // A field advances as soon as no further digit could be valid: no month
    // starts with 4 (40+ is impossible), so "4" commits April and hops on.
    // Typing the month also clamps the day — April has no 31st — matching what
    // stepping does rather than rolling over into May 1.
    let m = picker()
    backend.simulateDatePickerClick(atCharacter: 0, for: m.handle)
    backend.simulateDatePickerTyping("4", for: m.handle)
    check(field(m) == "4/30/2026, 8:00:00\u{202F}PM",
          "typing 4 selects April and clamps the day to the 30th — got [\(field(m))]")
    backend.simulateDatePickerTyping("9", for: m.handle)
    check(field(m) == "4/9/2026, 8:00:00\u{202F}PM",
          "the month already advanced, so 9 lands in the day — got [\(field(m))]")

    // A digit that can't extend the run starts a fresh value instead of being
    // dropped: on the day field, 3 then 5 is not 35 — it is the 5th.
    let restart = picker()
    backend.simulateDatePickerClick(atCharacter: 2, for: restart.handle)
    backend.simulateDatePickerTyping("3", for: restart.handle)
    check(field(restart) == "5/3/2026, 8:00:00\u{202F}PM",
          "typing 3 in the day waits for a second digit — got [\(field(restart))]")
    backend.simulateDatePickerTyping("5", for: restart.handle)
    check(field(restart) == "5/5/2026, 8:00:00\u{202F}PM",
          "35 is no day, so 5 starts over as the 5th — got [\(field(restart))]")

    // A leading zero is held, not rejected: "0" then "7" is July.
    let z = picker()
    backend.simulateDatePickerClick(atCharacter: 0, for: z.handle)
    backend.simulateDatePickerTyping("07", for: z.handle)
    check(field(z) == "7/31/2026, 8:00:00\u{202F}PM",
          "a leading zero is buffered, so 07 is July — got [\(field(z))]")

    // Four digits type a year.
    let y = picker()
    backend.simulateDatePickerClick(atCharacter: 6, for: y.handle)
    backend.simulateDatePickerTyping("1999", for: y.handle)
    check(field(y) == "5/31/1999, 8:00:00\u{202F}PM",
          "the year takes four digits — got [\(field(y))]")

    // Typing a 12-hour hour keeps the current half-day (8 PM -> 11 PM, not AM).
    let h = picker()
    let hourAt = field(h).distance(from: field(h).startIndex,
                                   to: field(h).range(of: "8:")!.lowerBound)
    backend.simulateDatePickerClick(atCharacter: hourAt, for: h.handle)
    backend.simulateDatePickerTyping("11", for: h.handle)
    check(field(h) == "5/31/2026, 11:00:00\u{202F}PM",
          "typing an hour keeps PM — got [\(field(h))]")

    // AM/PM takes letters, not digits.
    let ap = picker()
    backend.simulateDatePickerClick(atCharacter: field(ap).count - 1, for: ap.handle)
    backend.simulateDatePickerTyping("a", for: ap.handle)
    check(field(ap) == "5/31/2026, 8:00:00\u{202F}AM", "typing 'a' selects AM — got [\(field(ap))]")
    backend.simulateDatePickerTyping("p", for: ap.handle)
    check(field(ap) == "5/31/2026, 8:00:00\u{202F}PM", "typing 'p' selects PM — got [\(field(ap))]")
    backend.simulateDatePickerTyping("7", for: ap.handle)
    check(field(ap) == "5/31/2026, 8:00:00\u{202F}PM", "a digit does nothing to AM/PM")

    // Typing fires the action, as AppKit does.
    var typedFired = 0
    let notify = picker()
    notify.onDateChange = { _ in typedFired += 1 }
    backend.simulateDatePickerClick(atCharacter: 0, for: notify.handle)
    backend.simulateDatePickerTyping("3", for: notify.handle)
    check(typedFired == 1, "typing fires the picker's action")

    // Moving to a different field abandons a number in progress: "1" starts a
    // month, then clicking the day makes the next digit a day, not "15".
    let reset = picker()
    backend.simulateDatePickerClick(atCharacter: 0, for: reset.handle)
    backend.simulateDatePickerTyping("1", for: reset.handle)
    check(field(reset) == "1/31/2026, 8:00:00\u{202F}PM", "typing 1 starts January")
    backend.simulateDatePickerClick(atCharacter: 2, for: reset.handle)   // the day
    backend.simulateDatePickerTyping("5", for: reset.handle)
    check(field(reset) == "1/5/2026, 8:00:00\u{202F}PM",
          "changing field restarts the typed number — got [\(field(reset))]")

    // ...but the *same* field re-reporting its own selection must not: the GTK
    // backend echoes the selection back after every text change, so a reset
    // there would swallow the second digit (this exact bug: "45" -> "05").
    let echo = picker()
    let echoMinute = field(echo).distance(from: field(echo).startIndex,
                                          to: field(echo).range(of: ":00:")!.lowerBound) + 1
    backend.simulateDatePickerClick(atCharacter: echoMinute, for: echo.handle)
    backend.simulateDatePickerTyping("4", for: echo.handle)
    backend.simulateDatePickerClick(atCharacter: echoMinute, for: echo.handle)   // the echo
    backend.simulateDatePickerTyping("5", for: echo.handle)
    check(field(echo) == "5/31/2026, 8:45:00\u{202F}PM",
          "the field re-reporting itself keeps the run going — got [\(field(echo))]")

    // minDate/maxDate clamp real steps (they were no-op stubs).
    let bounded = picker()
    bounded.maxDate = start                       // already at the ceiling
    backend.simulateDateStep(1, for: bounded.handle)
    check(bounded.dateValue == start, "a step past maxDate is clamped")
    check(backend.dateRanges[bounded.handle.rawValue]?.max == start, "maxDate still reaches the backend")

    // The elements decide the field, and only the field.
    let dateOnly = picker([.yearMonthDay])
    check(field(dateOnly) == "5/31/2026", "a date-only picker shows only the date")
    check(dateOnly.stringValue == "Sunday, May 31, 2026 at 8:00:00\u{202F}PM Eastern Daylight Time",
          "stringValue ignores the elements, as on Apple")
    check(field(picker([.hourMinute])) == "8:00\u{202F}PM",
          "hourMinute drops the seconds — got [\(field(picker([.hourMinute])))]")
}

// MARK: 30a-ii — NSDatePicker .clockAndCalendar: the time is viewable and editable
//
// The calendar shows the date; a compact time field beside it shows and edits
// the time — the functionality that was entirely missing (the calendar had no
// clock). Time strings carry ICU's U+202F before AM/PM, as elsewhere.
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend
    let start = Date(timeIntervalSince1970: 1_780_272_000)   // 5/31/2026 8:00:00 PM EDT
    let picker = NSDatePicker(date: start, frame: NSMakeRect(724, 88, 276, 168))
    picker.locale = Locale(identifier: "en_US")
    picker.timeZone = TimeZone(identifier: "America/New_York")!
    picker.calendar = Calendar(identifier: .gregorian)
    picker.datePickerElements = [.yearMonthDay, .hourMinuteSecond]
    picker.datePickerStyle = .clockAndCalendar

    func field() -> String { backend.datePickerTexts[picker.handle.rawValue] ?? "" }

    // The field shows the TIME (not the date — the calendar owns that).
    check(field() == "8:00:00\u{202F}PM",
          "the clock field shows the time, not the date — got [\(field())]")
    // stringValue is still the full date+time.
    check(picker.stringValue == "Sunday, May 31, 2026 at 8:00:00\u{202F}PM Eastern Daylight Time",
          "stringValue stays full date+time in clockAndCalendar mode")

    // Stepping the time field's selected element edits the TIME.
    backend.simulateDatePickerClick(atCharacter: 0, for: picker.handle)   // the hour
    backend.simulateDateStep(1, for: picker.handle)
    check(field() == "9:00:00\u{202F}PM", "stepping the hour edits the time — got [\(field())]")

    // Typing works too.
    let minuteAt = field().distance(from: field().startIndex, to: field().range(of: ":00:")!.lowerBound) + 1
    backend.simulateDatePickerClick(atCharacter: minuteAt, for: picker.handle)
    backend.simulateDatePickerTyping("45", for: picker.handle)
    check(field() == "9:45:00\u{202F}PM", "typing edits the minute — got [\(field())]")

    // The crux: a calendar day-change keeps the time the user set (it does not
    // reset to the calendar's midnight). We are now at 9:45 PM on May 31; pick
    // a different day at a different time — only the DAY should move.
    var fired = 0
    picker.onDateChange = { _ in fired += 1 }
    let otherDay = Date(timeIntervalSince1970: 1_780_272_000 - 12 * 86_400 + 3 * 3600)  // 12 days back, +3h
    backend.simulateDateChange(picker.handle, otherDay)
    check(fired == 1, "a calendar pick fires the action")
    let calendar = picker.calendar!
    var cal = calendar; cal.timeZone = picker.timeZone!
    let picked = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: picker.dateValue)
    check(picked.day == 19, "the calendar changed the day to the 19th")
    check(picked.hour == 21 && picked.minute == 45,
          "the time the user set (9:45 PM) is preserved across the day change — got \(picked.hour ?? -1):\(picked.minute ?? -1)")
    // The time field still shows 9:45.
    check(field() == "9:45:00\u{202F}PM", "the field keeps the preserved time")
}

// MARK: 30b — CoordinateSpace: the one place a child's geometry is decided
do {
    // An unflipped (AppKit-default) parent: the child's bottom-left origin
    // becomes a top-left origin, so y = parentHeight - y - height.
    let child = NSMakeRect(10, 20, 100, 30)
    let placed = CoordinateSpace.place(child, inParentOfHeight: 200, parentIsFlipped: false)
    check(placed.origin.y == 150, "an unflipped parent flips the child's Y")
    check(placed.origin.x == 10, "X never flips")

    // A flipped parent (Win32/WinChocolate, and the shared demo) already
    // measures from the top, so Y passes through untouched.
    let flipped = CoordinateSpace.place(child, inParentOfHeight: 200, parentIsFlipped: true)
    check(flipped.origin.y == 20, "a flipped parent passes the child's Y through")

    // Size is never negotiated: in AppKit a view *is* its frame. This is the
    // property that stopped controls overlapping — GTK's size_request is only
    // a minimum, so a control whose intrinsic minimum exceeded its frame used
    // to overflow onto its neighbours.
    check(placed.size == child.size, "size passes through unchanged (the frame is law)")
    check(flipped.size == child.size, "size passes through unchanged when flipped too")

    // The flip is an involution: placing twice returns the original Y.
    let back = CoordinateSpace.place(placed, inParentOfHeight: 200, parentIsFlipped: false)
    check(back.origin.y == child.origin.y, "flipping twice restores the original Y")

    // A child taller than its parent lands above the top edge, not clamped —
    // AppKit does not clamp frames either.
    let tall = CoordinateSpace.place(NSMakeRect(0, 0, 10, 300), inParentOfHeight: 200, parentIsFlipped: false)
    check(tall.origin.y == -100, "an oversized child is placed, not clamped")
}

// MARK: 30b-i — stackedRowY: the container's OWN flip decides
do {
    // Row 0 is topmost under both conventions; rows 0..2 of 24pt content in a
    // 100pt container. Flipped counts down from 0; unflipped counts back from
    // the top edge. Both must agree on the visual order.
    let flippedYs = (0..<3).map {
        CoordinateSpace.stackedRowY(index: $0, rowHeight: 24, contentHeight: 24,
                                    containerHeight: 100, isFlipped: true)
    }
    let unflippedYs = (0..<3).map {
        CoordinateSpace.stackedRowY(index: $0, rowHeight: 24, contentHeight: 24,
                                    containerHeight: 100, isFlipped: false)
    }
    check(flippedYs == [0, 24, 48], "flipped rows count down from the top")
    check(unflippedYs == [76, 52, 28], "unflipped rows count back from the top edge")
    check(flippedYs[0] < flippedYs[1] && unflippedYs[0] > unflippedYs[1],
          "row 0 is topmost under both conventions (the Y ordering inverts)")

    // Spacing applies to the pitch, not the content height.
    check(CoordinateSpace.stackedRowY(index: 2, rowHeight: 20, spacing: 4, contentHeight: 20,
                                      containerHeight: 100, isFlipped: true) == 48,
          "spacing widens the row pitch")
    // A control shorter than its row is top-aligned within it when unflipped.
    check(CoordinateSpace.stackedRowY(index: 0, rowHeight: 40, contentHeight: 24,
                                      containerHeight: 100, isFlipped: false) == 76,
          "a short control is top-aligned in its row")
}

// MARK: 30b-ii — isFlipped is PER VIEW: neighbours need not agree
/// Two sibling containers that disagree about `isFlipped`, plus a child that
/// disagrees with its parent — AppKit reads each view's own flag.
final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
final class UnflippedView: NSView {
    override var isFlipped: Bool { false }
}
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend
    // The app-wide default must not decide any individual view's answer.
    NSView.defaultIsFlipped = true
    defer { NSView.defaultIsFlipped = true }

    let root = FlippedView(frame: NSMakeRect(0, 0, 400, 400))
    let flipped = FlippedView(frame: NSMakeRect(0, 0, 200, 200))
    let unflipped = UnflippedView(frame: NSMakeRect(200, 0, 200, 200))
    root.addSubview(flipped)
    root.addSubview(unflipped)
    check(backend.flippedViews[flipped.handle.rawValue] == true, "a flipped view reports flipped")
    check(backend.flippedViews[unflipped.handle.rawValue] == false,
          "an unflipped sibling reports unflipped, despite the app-wide default")

    // A child that disagrees with its parent: the parent's flip places the
    // child; the child's own flip governs its own children and drawing.
    let childOfUnflipped = FlippedView(frame: NSMakeRect(10, 20, 50, 30))
    unflipped.addSubview(childOfUnflipped)
    check(backend.flippedViews[unflipped.handle.rawValue] == false, "the parent keeps its own flip")
    check(backend.flippedViews[childOfUnflipped.handle.rawValue] == true, "the child keeps its own flip")

    // The two flips produce genuinely different placements for the same frame,
    // which is the whole reason they must not be assumed uniform.
    let frame = NSMakeRect(10, 20, 50, 30)
    let inFlipped = CoordinateSpace.place(frame, inParentOfHeight: 200, parentIsFlipped: true)
    let inUnflipped = CoordinateSpace.place(frame, inParentOfHeight: 200, parentIsFlipped: false)
    check(inFlipped.origin.y == 20 && inUnflipped.origin.y == 150,
          "the same frame lands in two different places under the two flips")

    // A dynamic override must be re-read, not cached from the first addSubview.
    let dynamic = DynamicFlipView(frame: NSMakeRect(0, 0, 100, 100))
    root.addSubview(dynamic)
    check(backend.flippedViews[dynamic.handle.rawValue] == true, "the initial flip reaches the backend")
    dynamic.flipsNow = false
    dynamic.frame = NSMakeRect(0, 0, 100, 101)   // any re-placement re-reads it
    check(backend.flippedViews[dynamic.handle.rawValue] == false,
          "a changed isFlipped is re-read, not served from the add-time cache")
}

// MARK: 30c — NSSplitView: panes are subviews (AppKit's original API)
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend
    let split = NSSplitView(vertical: true, frame: NSMakeRect(0, 0, 240, 96))
    let left = NSView(frame: .zero)
    let right = NSView(frame: .zero)
    split.addSubview(left)      // AppKit: a split view's subviews ARE its panes
    split.addSubview(right)
    check(split.arrangedSubviews.count == 2, "addSubview adds a pane")
    check(split.subviews.count == 2, "the panes are also subviews")
    check(left.superview === split, "a pane's superview is the split view")
    check(backend.splitPanes[split.handle.rawValue]?.count == 2, "both panes reach the backend")
}

// MARK: 31 — Toolbar customization (NSToolbarDelegate + palette)
final class CustomizeDelegate: NSToolbarDelegate {
    let items: [String: NSToolbarItem]
    init(_ items: [String: NSToolbarItem]) { self.items = items }
    func toolbarAllowedItemIdentifiers(_ t: NSToolbar) -> [String] { ["open", "save", "info"] }
    func toolbarDefaultItemIdentifiers(_ t: NSToolbar) -> [String] { ["open", "save"] }
    func toolbar(_ t: NSToolbar, itemForItemIdentifier id: String, willBeInsertedIntoToolbar f: Bool) -> NSToolbarItem? {
        items[id]
    }
}
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend

    let window = NSWindow(contentRect: NSMakeRect(0, 0, 400, 300), styleMask: [.titled], backing: .buffered, defer: false)
    let toolbar = NSToolbar(identifier: "custom")
    func item(_ id: String, _ label: String) -> NSToolbarItem {
        let i = NSToolbarItem(itemIdentifier: id); i.label = label; return i
    }
    let delegate = CustomizeDelegate(["open": item("open", "Open"), "save": item("save", "Save"), "info": item("info", "Info")])
    toolbar.allowsUserCustomization = true
    toolbar.delegate = delegate
    window.toolbar = toolbar

    // Delegate default identifiers populate the toolbar (info is absent).
    check(backend.toolbars[window.handle.rawValue]?.map { $0.label } == ["Open", "Save"], "delegate default items populate the toolbar")

    // Customization palette: allowed items become palette rows, with the
    // currently-present ones checked.
    check(!toolbar.customizationPaletteIsRunning, "palette starts closed")
    toolbar.runCustomizationPalette(nil)
    check(toolbar.customizationPaletteIsRunning, "runCustomizationPalette opens it")
    let palette = backend.toolbarCustomizationItems
    check(palette.map { $0.identifier } == ["open", "save", "info"], "palette lists the allowed identifiers")
    check(palette.first { $0.identifier == "info" }?.isInToolbar == false, "an absent item shows available (undimmed)")
    check(palette.first { $0.identifier == "open" }?.isInToolbar == true, "a present item shows dimmed")

    // The session mirrors Apple's sheet: the live strip plus the default set.
    check(backend.toolbarCustomizationSession?.strip.map { $0.label } == ["Open", "Save"], "the session's strip duplicates the live toolbar")
    check(backend.toolbarCustomizationSession?.defaultSet.map { $0.identifier } == ["open", "save"], "the session carries the default set")

    // Dragging "info" into the strip at position 1 inserts it live.
    backend.simulateToolbarCustomizationInsert("info", at: 1)
    check(backend.toolbars[window.handle.rawValue]?.map { $0.label } == ["Open", "Info", "Save"], "dragging an item in inserts at the drop position")
    // Dragging within the strip reorders.
    backend.simulateToolbarCustomizationMove(from: 0, to: 3)
    check(backend.toolbars[window.handle.rawValue]?.map { $0.label } == ["Info", "Save", "Open"], "dragging within the strip reorders")
    // Dragging an item off the strip removes it.
    backend.simulateToolbarCustomizationRemove(at: 1)
    check(backend.toolbars[window.handle.rawValue]?.map { $0.label } == ["Info", "Open"], "dragging an item off the strip removes it")
    // The refreshed session dims palette items now present.
    check(backend.toolbarCustomizationSession?.palette.first { $0.identifier == "info" }?.isInToolbar == true, "the pushed session reflects edits")
    // Dragging the default set in resets the strip.
    backend.simulateToolbarCustomizationReset()
    check(backend.toolbars[window.handle.rawValue]?.map { $0.label } == ["Open", "Save"], "dragging the default set in resets the toolbar")
    // The Show popup drives displayMode.
    backend.simulateToolbarCustomizationDisplayMode(1)
    check(toolbar.displayMode == .iconOnly, "the Show popup drives displayMode")
    check(backend.toolbarDisplayModes[window.handle.rawValue] == .iconOnly, "displayMode reaches the installed bar")
    backend.simulateToolbarCustomizationDisplayMode(0)

    backend.simulateToolbarCustomizationClose()
    check(!toolbar.customizationPaletteIsRunning, "closing the palette clears the running flag")

    // Programmatic insert/remove also refresh the installed toolbar.
    toolbar.insertItem(withItemIdentifier: "save", at: 0)
    check(backend.toolbars[window.handle.rawValue]?.first?.label == "Save", "insertItem places the item at the index")
    let countBefore = backend.toolbars[window.handle.rawValue]?.count ?? 0
    toolbar.removeItem(at: 0)
    check(backend.toolbars[window.handle.rawValue]?.count == countBefore - 1, "removeItem drops an item")

    // Customization requires opt-in.
    let locked = NSToolbar(identifier: "locked")
    locked.delegate = delegate
    window.toolbar = locked
    locked.runCustomizationPalette(nil)
    check(!locked.customizationPaletteIsRunning, "runCustomizationPalette is a no-op without allowsUserCustomization")
}

if failures == 0 {
    print("\nAll contract tests passed.")
} else {
    print("\n\(failures) contract test(s) FAILED.")
    exit(1)
}

// MARK: — Button title set post-creation (the shared demo's convenience path:
// `NSButton(frame:)` then `.title =`), which must reach the backend.
do {
    let backend = InMemoryNativeControlBackend()
    NSApplication.shared.nativeBackend = backend
    let button = NSButton(frame: NSMakeRect(0, 0, 100, 30))
    button.title = "Click"
    check(backend.texts[button.handle.rawValue] == "Click",
          "post-creation title reaches the backend (demo convenience path)")

    let radio = NSButton(radioWithTitle: "Info", frame: .zero)
    radio.frame = NSMakeRect(0, 0, 88, 24)
    check(backend.texts[radio.handle.rawValue] == "Info",
          "radio created with title keeps it after a frame change")
}
