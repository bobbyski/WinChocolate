// LinChocolate demo — a tabbed Controls app written against the AppKit-shaped
// API, rendered as native GTK controls on Linux. Mirrors the WinChocolate
// demo's paged structure; only the backend line is Linux-specific.
//
// Run it through the Ring 1 harness so the window shows on the Mac via XQuartz:
//   ./run-linux.sh LinChocolateDemo

import LinChocolate
import Foundation

let app = NSApplication.shared
app.nativeBackend = GTKNativeControlBackend()   // native Linux backend (GTK4)

let pageWidth = 540.0, pageHeight = 540.0

/// Top-down row stacker over AppKit's bottom-left coordinates: each call
/// reserves a row of the given height below the previous one and returns its y.
struct Rows {
    var cursor: Double
    init(top: Double) { cursor = top }
    mutating func next(_ rowHeight: Double, gap: Double = 14) -> Double {
        cursor -= rowHeight
        defer { cursor -= gap }
        return cursor
    }
}

let window = NSWindow(
    contentRect: NSMakeRect(0, 0, pageWidth, pageHeight + 60),
    styleMask: [.titled, .closable, .resizable],
    backing: .buffered,
    defer: false
)
window.title = "LinChocolate Controls"

// MARK: - Page 1 · Basics
let basics = NSView(frame: NSMakeRect(0, 0, pageWidth, pageHeight))
var r1 = Rows(top: pageHeight - 16)

let counter = NSTextField(labelWithString: "Clicks: 0", frame: NSMakeRect(24, r1.next(24), 300, 24))
let button  = NSButton(title: "Click me", frame: NSMakeRect(24, r1.next(36), 140, 36))
let disable = NSButton(checkboxWithTitle: "Disable button", frame: NSMakeRect(24, r1.next(28), 220, 28))

let sizeY = r1.next(24)
let sizeLabel  = NSTextField(labelWithString: "Choose a size:", frame: NSMakeRect(24, sizeY, 200, 24))
let sizeResult = NSTextField(labelWithString: "Size: —", frame: NSMakeRect(260, sizeY, 250, 24))
let small  = NSButton(radioWithTitle: "Small",  frame: NSMakeRect(40, r1.next(26), 120, 26))
let medium = NSButton(radioWithTitle: "Medium", frame: NSMakeRect(40, r1.next(26), 120, 26))
let large  = NSButton(radioWithTitle: "Large",  frame: NSMakeRect(40, r1.next(26), 120, 26))

let searchY = r1.next(32)
let searchLabel = NSTextField(labelWithString: "Search:", frame: NSMakeRect(24, searchY + 4, 90, 24))
let search = NSSearchField(string: "", frame: NSMakeRect(120, searchY, 290, 32))

let comboY = r1.next(34)
let comboLabel = NSTextField(labelWithString: "Fruit:", frame: NSMakeRect(24, comboY + 4, 90, 24))
let combo = NSComboBox(items: ["Apple", "Banana", "Cherry"], frame: NSMakeRect(120, comboY, 200, 34))

let passwordY = r1.next(32)
let passwordLabel = NSTextField(labelWithString: "Password:", frame: NSMakeRect(24, passwordY + 4, 90, 24))
let password = NSSecureTextField(string: "", frame: NSMakeRect(120, passwordY, 290, 32))

let echo = NSTextField(labelWithString: "Last edit: —", frame: NSMakeRect(24, r1.next(24), 486, 24))

for control in [counter, button, disable, sizeLabel, sizeResult, small, medium, large,
                searchLabel, search, comboLabel, combo, passwordLabel, password, echo] as [NSView] {
    basics.addSubview(control)
}

// MARK: - Page 2 · Values
let values = NSView(frame: NSMakeRect(0, 0, pageWidth, pageHeight))
var r2 = Rows(top: pageHeight - 16)

let volumeY = r2.next(30)
let volumeLabel = NSTextField(labelWithString: "Volume:", frame: NSMakeRect(24, volumeY + 3, 90, 24))
let slider = NSSlider(value: 30, minValue: 0, maxValue: 100, frame: NSMakeRect(120, volumeY, 300, 30))
let volumeValue = NSTextField(labelWithString: "30", frame: NSMakeRect(430, volumeY + 3, 80, 24))
let progress = NSProgressIndicator(value: 30, minValue: 0, maxValue: 100, frame: NSMakeRect(24, r2.next(20), 486, 20))

let stepperY = r2.next(34)
let stepperLabel = NSTextField(labelWithString: "Quantity:", frame: NSMakeRect(24, stepperY + 4, 90, 24))
let stepper = NSStepper(value: 1, minValue: 0, maxValue: 10, increment: 1, frame: NSMakeRect(120, stepperY, 120, 34))
let stepperResult = NSTextField(labelWithString: "Qty: 1", frame: NSMakeRect(260, stepperY + 4, 200, 24))

let levelY = r2.next(24)
let levelLabel = NSTextField(labelWithString: "Level:", frame: NSMakeRect(24, levelY, 90, 24))
let level = NSLevelIndicator(value: 6, minValue: 0, maxValue: 10, frame: NSMakeRect(120, levelY, 300, 22))

let tagsY = r2.next(36)
let tagsLabel = NSTextField(labelWithString: "Tags:", frame: NSMakeRect(24, tagsY + 6, 90, 24))
let tags = NSTokenField(tokens: ["swift", "gtk"], frame: NSMakeRect(120, tagsY, 320, 36))
let tagsResult = NSTextField(labelWithString: "2 tags", frame: NSMakeRect(452, tagsY + 6, 80, 24))

let alignY = r2.next(34)
let alignLabel = NSTextField(labelWithString: "Align:", frame: NSMakeRect(24, alignY + 4, 90, 24))
let segmented = NSSegmentedControl(labels: ["Left", "Center", "Right"], frame: NSMakeRect(120, alignY, 260, 34))
let alignResult = NSTextField(labelWithString: "Align: —", frame: NSMakeRect(396, alignY + 4, 130, 24))

for control in [volumeLabel, slider, volumeValue, progress,
                stepperLabel, stepper, stepperResult, levelLabel, level,
                tagsLabel, tags, tagsResult,
                alignLabel, segmented, alignResult] as [NSView] {
    values.addSubview(control)
}

// MARK: - Page 3 · Pickers
let pickers = NSView(frame: NSMakeRect(0, 0, pageWidth, pageHeight))
var r3 = Rows(top: pageHeight - 16)

let themeY = r3.next(34)
let themeLabel = NSTextField(labelWithString: "Theme:", frame: NSMakeRect(24, themeY + 4, 90, 24))
let theme = NSPopUpButton(items: ["System", "Light", "Dark"], frame: NSMakeRect(120, themeY, 180, 34))
let themeResult = NSTextField(labelWithString: "Theme: System", frame: NSMakeRect(320, themeY + 4, 200, 24))

let colorY = r3.next(34)
let colorLabel = NSTextField(labelWithString: "Color:", frame: NSMakeRect(24, colorY + 4, 90, 24))
let colorWell = NSColorWell(color: .orange, frame: NSMakeRect(120, colorY, 60, 34))
let colorResult = NSTextField(labelWithString: "Color: orange-ish", frame: NSMakeRect(200, colorY + 4, 280, 24))

let dateLabel = NSTextField(labelWithString: "Date:", frame: NSMakeRect(24, r3.next(24), 90, 24))
let datePicker = NSDatePicker(frame: NSMakeRect(24, r3.next(230), 320, 230))
let dateResult = NSTextField(labelWithString: "Picked: —", frame: NSMakeRect(24, r3.next(24), 486, 24))

for control in [themeLabel, theme, themeResult, colorLabel, colorWell, colorResult,
                dateLabel, datePicker, dateResult] as [NSView] {
    pickers.addSubview(control)
}

// MARK: - Page 4 · Text
let textPage = NSView(frame: NSMakeRect(0, 0, pageWidth, pageHeight))
var r4 = Rows(top: pageHeight - 16)

let styledLabel = NSTextField(labelWithString: "Bold 18pt, firebrick red (NSFont + textColor)", frame: NSMakeRect(24, r4.next(28), 486, 28))
styledLabel.font = .boldSystemFont(ofSize: 18)
styledLabel.textColor = NSColor(red: 0.70, green: 0.13, blue: 0.13)

let monoLabel = NSTextField(labelWithString: "", frame: NSMakeRect(24, r4.next(22), 486, 22))
let attributed = NSMutableAttributedString(string: "Attributed: red bold, plain, blue mono")
attributed.addAttribute(.foregroundColor, value: NSColor.red, range: NSMakeRange(12, 8))
attributed.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 14), range: NSMakeRange(12, 8))
attributed.addAttribute(.foregroundColor, value: NSColor.blue, range: NSMakeRange(29, 9))
attributed.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 13), range: NSMakeRange(29, 9))
monoLabel.attributedStringValue = attributed

let notesLabel = NSTextField(labelWithString: "Notes (monospace):", frame: NSMakeRect(24, r4.next(24), 200, 24))
let notes = NSTextView(string: "Type multi-line notes here…", frame: NSMakeRect(24, r4.next(120), 486, 120))
notes.font = .monospacedSystemFont(ofSize: 12)
let notesEdit = NSTextField(labelWithString: "Last edit: —", frame: NSMakeRect(24, r4.next(24), 486, 24))

let artworkLabel = NSTextField(labelWithString: "Artwork (NSImageView):", frame: NSMakeRect(24, r4.next(22), 300, 22))
let artwork = NSImageView(frame: NSMakeRect(24, r4.next(130), 130, 130))
artwork.image = NSImage(contentsOfFile: "Sources/LinChocolateDemo/Resources/Artwork.png")

for control in [styledLabel, monoLabel, notesLabel, notes, notesEdit, artworkLabel, artwork] as [NSView] {
    textPage.addSubview(control)
}

// MARK: - Page 5 · Layout (box, split view, scroll view)
let layoutPage = NSView(frame: NSMakeRect(0, 0, pageWidth, pageHeight))
var r5 = Rows(top: pageHeight - 16)

let splitLabel = NSTextField(labelWithString: "Split view (drag the divider):", frame: NSMakeRect(24, r5.next(22), 300, 22))

let split = NSSplitView(vertical: true, frame: NSMakeRect(24, r5.next(170), 486, 170))
let leftBox = NSBox(title: "Left pane", frame: NSMakeRect(0, 0, 200, 170))
let leftContent = NSView(frame: NSMakeRect(0, 0, 180, 140))
leftContent.addSubview(NSTextField(labelWithString: "Leading", frame: NSMakeRect(12, 100, 150, 24)))
leftBox.contentView = leftContent
let rightBox = NSBox(title: "Right pane", frame: NSMakeRect(0, 0, 260, 170))
let rightContent = NSView(frame: NSMakeRect(0, 0, 240, 140))
rightContent.addSubview(NSTextField(labelWithString: "Trailing", frame: NSMakeRect(12, 100, 150, 24)))
rightBox.contentView = rightContent
split.addArrangedSubview(leftBox)
split.addArrangedSubview(rightBox)
split.setPosition(200)

let scrollLabel = NSTextField(labelWithString: "Scroll view (tall document):", frame: NSMakeRect(24, r5.next(22), 300, 22))
let scroll = NSScrollView(frame: NSMakeRect(24, r5.next(200), 486, 200))
// Size the document to exactly fit its rows (no trailing empty space), so
// scrolling to the end lands the last row against the bottom edge.
let rowCount = 12, rowStride = 38.0, docTopMargin = 10.0, docBottomMargin = 10.0
let documentHeight = docTopMargin + Double(rowCount) * rowStride - (rowStride - 24) + docBottomMargin
let document = NSView(frame: NSMakeRect(0, 0, 440, documentHeight))
var docRows = Rows(top: documentHeight - docTopMargin)
for i in 1...rowCount {
    document.addSubview(NSTextField(labelWithString: "Scrollable row \(i)", frame: NSMakeRect(16, docRows.next(24), 300, 24)))
}
scroll.documentView = document

let scrollButtonY = r5.next(28)
let scrollButton = NSButton(title: "Scroll to bottom", frame: NSMakeRect(24, scrollButtonY, 150, 28))
let scrollInfo = NSTextField(labelWithString: "Offset: (0, 0)", frame: NSMakeRect(184, scrollButtonY + 3, 320, 22))
scroll.onScroll = { p in scrollInfo.stringValue = "Offset: (\(Int(p.x)), \(Int(p.y)))" }
scrollButton.onAction = { _ in scroll.scrollToEndOfDocument() }

for control in [splitLabel, split, scrollLabel, scroll, scrollButton, scrollInfo] as [NSView] {
    layoutPage.addSubview(control)
}

// MARK: - Page 6 · Table (NSTableView + data source)
final class DemoTableData: NSTableViewDataSource {
    var rows: [(name: String, status: String)] = [
        ("Aurora", "Ready"), ("Borealis", "Building"), ("Cascade", "Ready"),
        ("Dune", "Failed"), ("Ember", "Ready"), ("Fjord", "Queued"),
        ("Glacier", "Ready"), ("Harbor", "Building")
    ]
    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row < rows.count else { return nil }
        return tableColumn?.identifier == "status" ? rows[row].status : rows[row].name
    }
}
let tableData = DemoTableData()

let tablePage = NSView(frame: NSMakeRect(0, 0, pageWidth, pageHeight))
var r6 = Rows(top: pageHeight - 16)

final class OutlineNode {
    let name: String
    let children: [OutlineNode]
    init(_ name: String, _ children: [OutlineNode] = []) {
        self.name = name
        self.children = children
    }
}
final class DemoOutlineData: NSOutlineViewDataSource {
    let roots = [
        OutlineNode("Engineering", [OutlineNode("Compilers"), OutlineNode("UI Frameworks")]),
        OutlineNode("Design"),
        OutlineNode("Operations", [OutlineNode("Cloud")])
    ]
    private func children(of item: Any?) -> [OutlineNode] {
        (item as? OutlineNode)?.children ?? roots
    }
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        children(of: item).count
    }
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        children(of: item)[index]
    }
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        !((item as? OutlineNode)?.children.isEmpty ?? true)
    }
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        guard let node = item as? OutlineNode else { return nil }
        return tableColumn?.identifier == "members" ? node.children.count : node.name
    }
}
let outlineData = DemoOutlineData()

let tableTitle = NSTextField(labelWithString: "Projects (NSTableView):", frame: NSMakeRect(24, r6.next(22), 300, 22))
let table = NSTableView(frame: NSMakeRect(24, r6.next(200), 486, 200))
let nameColumn = NSTableColumn(identifier: "name");   nameColumn.title = "Name"
let statusColumn = NSTableColumn(identifier: "status"); statusColumn.title = "Status"
table.addTableColumn(nameColumn)
table.addTableColumn(statusColumn)
table.dataSource = tableData
let tableResult = NSTextField(labelWithString: "Selected: —", frame: NSMakeRect(24, r6.next(24), 486, 24))

let outlineTitle = NSTextField(labelWithString: "Departments (NSOutlineView):", frame: NSMakeRect(24, r6.next(22), 300, 22))
let outline = NSOutlineView(frame: NSMakeRect(24, r6.next(170), 486, 170))
let deptColumn = NSTableColumn(identifier: "name");    deptColumn.title = "Department"
let membersColumn = NSTableColumn(identifier: "members"); membersColumn.title = "Teams"
outline.addTableColumn(deptColumn)
outline.addTableColumn(membersColumn)
outline.dataSource = outlineData

for control in [tableTitle, table, tableResult, outlineTitle, outline] as [NSView] {
    tablePage.addSubview(control)
}

// MARK: - Page 7 · Grid (NSCollectionView)
final class DemoGridData: NSCollectionViewDataSource {
    let items = ["Agate", "Beryl", "Citrine", "Diamond", "Emerald", "Fluorite",
                 "Garnet", "Howlite", "Iolite", "Jasper", "Kunzite", "Larimar"]
    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }
    func collectionView(_ collectionView: NSCollectionView, representedObjectForItemAt index: Int) -> Any? {
        index < items.count ? items[index] : nil
    }
}
let gridData = DemoGridData()

let gridPage = NSView(frame: NSMakeRect(0, 0, pageWidth, pageHeight))
var r7 = Rows(top: pageHeight - 16)

let gridTitle = NSTextField(labelWithString: "Minerals (NSCollectionView):", frame: NSMakeRect(24, r7.next(22), 300, 22))
let grid = NSCollectionView(frame: NSMakeRect(24, r7.next(320), 486, 320))
grid.dataSource = gridData
let gridResult = NSTextField(labelWithString: "Selected: —", frame: NSMakeRect(24, r7.next(24), 486, 24))

for control in [gridTitle, grid, gridResult] as [NSView] {
    gridPage.addSubview(control)
}

// MARK: - Page 8 · Drawing (NSView.draw + NSBezierPath)
final class DemoCanvasView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        NSBezierPath(rect: dirtyRect).fill()

        NSColor.orange.setFill()
        NSBezierPath(rect: NSMakeRect(30, 290, 180, 120)).fill()

        NSColor.blue.setStroke()
        let oval = NSBezierPath(ovalIn: NSMakeRect(250, 270, 200, 140))
        oval.lineWidth = 4
        oval.stroke()

        NSColor.red.setFill()
        let triangle = NSBezierPath()
        triangle.move(to: NSMakePoint(60, 40))
        triangle.line(to: NSMakePoint(220, 40))
        triangle.line(to: NSMakePoint(140, 200))
        triangle.close()
        triangle.fill()

        NSColor.green.setStroke()
        let diagonal = NSBezierPath()
        diagonal.move(to: NSMakePoint(280, 60))
        diagonal.line(to: NSMakePoint(470, 220))
        diagonal.lineWidth = 6
        diagonal.stroke()
    }
}

let drawingPage = NSView(frame: NSMakeRect(0, 0, pageWidth, pageHeight))
var r8 = Rows(top: pageHeight - 16)
let drawingTitle = NSTextField(labelWithString: "Canvas (NSView.draw + NSBezierPath):", frame: NSMakeRect(24, r8.next(22), 400, 22))
let canvas = DemoCanvasView(frame: NSMakeRect(24, r8.next(440), 486, 440))
drawingPage.addSubview(drawingTitle)
drawingPage.addSubview(canvas)

// MARK: - Page 9 · Auto Layout (NSLayoutConstraint + anchors)
let autoLayoutPage = NSView(frame: NSMakeRect(0, 0, pageWidth, pageHeight))
var r9 = Rows(top: pageHeight - 16)
let autoLayoutTitle = NSTextField(
    labelWithString: "Leading / centered / trailing, positioned only by constraints:",
    frame: NSMakeRect(24, r9.next(22), 480, 22))
autoLayoutPage.addSubview(autoLayoutTitle)

// A container whose three boxes carry no manual frame — the solver places them.
let constraintBed = NSView(frame: NSMakeRect(24, r9.next(360), 486, 360))
autoLayoutPage.addSubview(constraintBed)

@MainActor func constraintBox(_ title: String) -> NSBox {
    let b = NSBox(title: title, frame: .zero)
    b.translatesAutoresizingMaskIntoConstraints = false
    constraintBed.addSubview(b)
    return b
}
let leadingBox = constraintBox("Leading")
let centerBox = constraintBox("Center")
let trailingBox = constraintBox("Trailing")

NSLayoutConstraint.activate([
    leadingBox.leadingAnchor.constraint(equalTo: constraintBed.leadingAnchor, constant: 16),
    leadingBox.centerYAnchor.constraint(equalTo: constraintBed.centerYAnchor),
    leadingBox.widthAnchor.constraint(equalToConstant: 130),
    leadingBox.heightAnchor.constraint(equalToConstant: 90),

    centerBox.centerXAnchor.constraint(equalTo: constraintBed.centerXAnchor),
    centerBox.centerYAnchor.constraint(equalTo: constraintBed.centerYAnchor),
    centerBox.widthAnchor.constraint(equalToConstant: 130),
    centerBox.heightAnchor.constraint(equalToConstant: 90),

    trailingBox.trailingAnchor.constraint(equalTo: constraintBed.trailingAnchor, constant: -16),
    trailingBox.centerYAnchor.constraint(equalTo: constraintBed.centerYAnchor),
    trailingBox.widthAnchor.constraint(equalToConstant: 130),
    trailingBox.heightAnchor.constraint(equalToConstant: 90),
])
constraintBed.layoutSubtreeIfNeeded()

// MARK: - Page 10 · Appearance (NSAppearance dark mode + NSVisualEffectView)
let appearancePage = NSView(frame: NSMakeRect(0, 0, pageWidth, pageHeight))
var r10 = Rows(top: pageHeight - 16)

let appearanceLabel = NSTextField(labelWithString: "Theme:", frame: NSMakeRect(24, r10.cursor - 30, 90, 24))
let themeToggle = NSSegmentedControl(labels: ["Light", "Dark"], frame: NSMakeRect(120, r10.next(34), 200, 34))
appearancePage.addSubview(appearanceLabel)
appearancePage.addSubview(themeToggle)

// Sample controls that visibly re-theme when the appearance flips.
let sampleField = NSTextField(string: "Editable text re-themes", frame: NSMakeRect(24, r10.next(30), 300, 30))
let buttonRowY = r10.next(32)
let sampleButton = NSButton(title: "A button", frame: NSMakeRect(24, buttonRowY, 140, 32))
let sampleCheck = NSButton(checkboxWithTitle: "A checkbox", frame: NSMakeRect(180, buttonRowY + 4, 160, 24))
appearancePage.addSubview(sampleField)
appearancePage.addSubview(sampleButton)
appearancePage.addSubview(sampleCheck)

// NSVisualEffectView material panels, each labelled.
let materialsLabel = NSTextField(labelWithString: "NSVisualEffectView materials:", frame: NSMakeRect(24, r10.next(24), 360, 22))
appearancePage.addSubview(materialsLabel)
let panelsTop = r10.next(150)
let materials: [(NSVisualEffectView.Material, String)] = [(.sidebar, "sidebar"), (.contentBackground, "content"), (.hudWindow, "hud")]
for (i, entry) in materials.enumerated() {
    let panel = NSVisualEffectView(frame: NSMakeRect(24 + Double(i) * 165, panelsTop, 150, 140), material: entry.0)
    let caption = NSTextField(labelWithString: entry.1, frame: NSMakeRect(10, 108, 130, 22))
    panel.addSubview(caption)
    appearancePage.addSubview(panel)
}

themeToggle.onAction = { seg in
    NSApplication.shared.appearance = seg.selectedSegment == 1 ? .darkAqua : .aqua
}
themeToggle.selectedSegment = 0

// MARK: - Page 11 · Drag & Drop (NSPasteboard + NSView DnD)
let dndPage = NSView(frame: NSMakeRect(0, 0, pageWidth, pageHeight))
var r11 = Rows(top: pageHeight - 16)

// Copy / paste through NSPasteboard.general.
let copyLabel = NSTextField(labelWithString: "Clipboard:", frame: NSMakeRect(24, r11.next(24) + 2, 90, 22))
let copyField = NSTextField(string: "Copy me", frame: NSMakeRect(120, copyLabel.frame.minY - 4, 200, 30))
let copyButton = NSButton(title: "Copy", frame: NSMakeRect(330, copyLabel.frame.minY - 5, 80, 30))
let pasteButton = NSButton(title: "Paste", frame: NSMakeRect(418, copyLabel.frame.minY - 5, 80, 30))
let pasteResult = NSTextField(labelWithString: "Pasted: —", frame: NSMakeRect(120, r11.next(24), 380, 22))
for c in [copyLabel, copyField, copyButton, pasteButton, pasteResult] as [NSView] { dndPage.addSubview(c) }
copyButton.onAction = { _ in
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(copyField.stringValue, forType: .string)
}
pasteButton.onAction = { _ in
    pasteResult.stringValue = "Pasted: \(NSPasteboard.general.string(forType: .string) ?? "—")"
}

// Drag a chip from the source onto the drop zone.
let dndHint = NSTextField(labelWithString: "Drag the chip onto the well:", frame: NSMakeRect(24, r11.next(28), 360, 22))
dndPage.addSubview(dndHint)
let zonesTop = r11.next(150)

let dragChip = NSVisualEffectView(frame: NSMakeRect(24, zonesTop, 150, 140), material: .hudWindow)
let chipCaption = NSTextField(labelWithString: "Drag me →", frame: NSMakeRect(20, 60, 120, 22))
dragChip.addSubview(chipCaption)
dragChip.registerDraggingSource { "🍫 dropped payload" }
dndPage.addSubview(dragChip)

let dropWell = NSVisualEffectView(frame: NSMakeRect(220, zonesTop, 260, 140), material: .sidebar)
let dropCaption = NSTextField(labelWithString: "Drop here", frame: NSMakeRect(16, 100, 200, 22))
let dropContents = NSTextField(labelWithString: "(empty)", frame: NSMakeRect(16, 60, 230, 22))
dropWell.addSubview(dropCaption)
dropWell.addSubview(dropContents)
dropWell.registerForDraggedTypes([.string])
dropWell.onPerformDragOperation = { info in
    dropContents.stringValue = info.draggingPasteboard.string(forType: .string) ?? "(empty)"
    return true
}
dndPage.addSubview(dropWell)

// MARK: - Page 12 · Forms (NSForm + NSMatrix composed layouts)
let formsPage = NSView(frame: NSMakeRect(0, 0, pageWidth, pageHeight))
var r12 = Rows(top: pageHeight - 16)

let formHeading = NSTextField(labelWithString: "NSForm (labelled rows):", frame: NSMakeRect(24, r12.next(24), 360, 22))
formHeading.font = .boldSystemFont(ofSize: 13)
formsPage.addSubview(formHeading)

let demoForm = NSForm(frame: NSMakeRect(24, r12.next(80), 400, 80))
demoForm.titleWidth = 72
let nameEntry = demoForm.addEntry("Name:")
let statusEntry = demoForm.addEntry("Status:")
nameEntry.stringValue = "LinChocolate"
statusEntry.stringValue = "Native"
formsPage.addSubview(demoForm)

let formEcho = NSTextField(labelWithString: "Form status: Native", frame: NSMakeRect(24, r12.next(24), 460, 22))
formsPage.addSubview(formEcho)
demoForm.textField(at: 1)?.onTextChange = { field in
    formEcho.stringValue = "Form status: \(field.stringValue)"
}

let matrixHeading = NSTextField(labelWithString: "NSMatrix (button grid):", frame: NSMakeRect(24, r12.next(28), 360, 22))
matrixHeading.font = .boldSystemFont(ofSize: 13)
formsPage.addSubview(matrixHeading)

let demoMatrix = NSMatrix(frame: NSMakeRect(24, r12.next(72), 240, 72), mode: .trackModeMatrix,
                          prototype: NSButtonCell(title: "Choice"), numberOfRows: 2, numberOfColumns: 2)
demoMatrix.cellSize = NSMakeSize(104, 28)
demoMatrix.intercellSpacing = NSMakeSize(8, 8)
demoMatrix.selectCell(atRow: 0, column: 0)
formsPage.addSubview(demoMatrix)

let matrixEcho = NSTextField(labelWithString: "Matrix selected: —", frame: NSMakeRect(24, r12.next(24), 460, 22))
formsPage.addSubview(matrixEcho)
demoMatrix.onAction = { m in
    matrixEcho.stringValue = "Matrix selected: row \(m.selectedRow + 1), column \(m.selectedColumn + 1)"
}

// MARK: - Tab view assembly
let tabView = NSTabView(frame: NSMakeRect(0, 0, pageWidth, pageHeight + 60))
for (label, page) in [("Basics", basics), ("Values", values), ("Pickers", pickers), ("Text", textPage), ("Layout", layoutPage), ("Table", tablePage), ("Grid", gridPage), ("Drawing", drawingPage), ("Auto Layout", autoLayoutPage), ("Appearance", appearancePage), ("Drag & Drop", dndPage), ("Forms", formsPage)] {
    let item = NSTabViewItem()
    item.label = label
    item.view = page
    tabView.addTabViewItem(item)
}

// MARK: - Wiring: every control drives something visible
var clicks = 0
button.onAction = { _ in clicks += 1; counter.stringValue = "Clicks: \(clicks)" }
disable.onAction = { button.isEnabled = !$0.isOn }
NSButton.group([small, medium, large])
for radio in [small, medium, large] { radio.onAction = { sizeResult.stringValue = "Size: \($0.title)" } }
search.onTextChange = { echo.stringValue = "Search: \($0.stringValue)" }
combo.onTextChange = { echo.stringValue = "Fruit: \($0.stringValue)" }
password.onTextChange = { echo.stringValue = "Password length: \($0.stringValue.count)" }

slider.onValueChange = { s in
    progress.doubleValue = s.doubleValue
    volumeValue.stringValue = "\(Int(s.doubleValue))"
}
stepper.onValueChange = { s in
    stepperResult.stringValue = "Qty: \(Int(s.doubleValue))"
    level.doubleValue = s.doubleValue          // the stepper drives the level gauge
}

theme.onSelectionChange = { themeResult.stringValue = "Theme: \($0.titleOfSelectedItem ?? "—")" }
colorWell.onColorChange = { well in
    let c = well.color
    colorResult.stringValue = String(format: "Color: %.2f, %.2f, %.2f", c.redComponent, c.greenComponent, c.blueComponent)
}
let dateFormatter = DateFormatter()
dateFormatter.dateStyle = .medium
datePicker.onDateChange = { dateResult.stringValue = "Picked: \(dateFormatter.string(from: $0.dateValue))" }

notes.onTextChange = { notesEdit.stringValue = "Last edit: \($0.string.count) chars" }
tags.onTokensChange = { tagsResult.stringValue = "\($0.objectValue.count) tags" }
grid.onSelectionChange = { g in
    let index = g.selectedIndex
    gridResult.stringValue = index >= 0 && index < gridData.items.count
        ? "Selected: \(gridData.items[index])" : "Selected: —"
}
table.onSelectionChange = { t in
    let row = t.selectedRow
    tableResult.stringValue = row >= 0 && row < tableData.rows.count
        ? "Selected: \(tableData.rows[row].name) — \(tableData.rows[row].status)"
        : "Selected: —"
}
segmented.onAction = { seg in
    alignResult.stringValue = "Align: \(seg.label(forSegment: seg.selectedSegment) ?? "—")"
}
segmented.selectedSegment = 0

// MARK: - Menu bar (AppKit-shaped: mainMenu of submenus)
let mainMenu = NSMenu()

let fileItem = NSMenuItem(title: "File")
let fileMenu = NSMenu(title: "File")
fileMenu.addItem(withTitle: "Reset Counter") { _ in
    clicks = 0
    counter.stringValue = "Clicks: 0 (reset)"
}
fileMenu.addItem(.separator())
fileMenu.addItem(withTitle: "Quit") { _ in NSApp.terminate(nil) }
mainMenu.addItem(fileItem)
mainMenu.setSubmenu(fileMenu, for: fileItem)

let helpItem = NSMenuItem(title: "Help")
let helpMenu = NSMenu(title: "Help")
helpMenu.addItem(withTitle: "About LinChocolate") { _ in
    let alert = NSAlert()
    alert.messageText = "LinChocolate"
    alert.informativeText = "The AppKit API, rendered as native GTK."
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Nice")
    let response = alert.runModal()
    echo.stringValue = "About closed: \(response == NSAlertFirstButtonReturn ? "OK" : "Nice")"
}
mainMenu.addItem(helpItem)
mainMenu.setSubmenu(helpMenu, for: helpItem)

NSApp.mainMenu = mainMenu

// MARK: - Toolbar (the deliberate Apple-look exception)
let toolbar = NSToolbar(identifier: "main")
let openItem = NSToolbarItem(itemIdentifier: "open")
openItem.label = "Open"
openItem.onAction = { _ in
    let panel = NSOpenPanel()
    echo.stringValue = panel.runModal() == NSModalResponseOK
        ? "Open: \(panel.url?.path ?? "?")" : "Open: cancelled"
}
let saveItem = NSToolbarItem(itemIdentifier: "save")
saveItem.label = "Save"
saveItem.onAction = { _ in
    let panel = NSSavePanel()
    panel.nameFieldStringValue = "untitled.txt"
    echo.stringValue = panel.runModal() == NSModalResponseOK
        ? "Save: \(panel.url?.path ?? "?")" : "Save: cancelled"
}
let infoItem = NSToolbarItem(itemIdentifier: "info")
infoItem.label = "Info"
infoItem.onAction = { _ in
    let alert = NSAlert()
    alert.messageText = "Toolbar"
    alert.informativeText = "The Apple-look toolbar exception, on Linux."
    alert.runModal()
}
toolbar.addItem(openItem)
toolbar.addItem(saveItem)
toolbar.addItem(.flexibleSpace())
toolbar.addItem(infoItem)
window.toolbar = toolbar

window.contentView = tabView
window.makeKeyAndOrderFront(nil)

app.run()
