import WinChocolate

let app = NSApplication.shared

let menuBar = NSMenu()
let appMenuItem = NSMenuItem(title: "WinChocolate", action: nil, keyEquivalent: "")
let appMenu = NSMenu(title: "WinChocolate")
let quitItem = NSMenuItem(title: "Quit WinChocolate", action: "terminate:", keyEquivalent: "q")
quitItem.target = app
appMenu.addItem(quitItem)
appMenuItem.submenu = appMenu
menuBar.addItem(appMenuItem)
app.mainMenu = menuBar

let window = NSWindow(
    contentRect: NSMakeRect(100, 100, 1120, 760),
    styleMask: [.titled, .closable, .miniaturizable, .resizable],
    backing: .buffered,
    defer: false
)
window.title = "WinChocolate Click Counter"
// 3.2: constrain how far the user can resize the window.
window.contentMinSize = NSMakeSize(900, 600)
// A generous cap: still demonstrates contentMaxSize, but lets the Zoom button
// on the "New in 3.x" page visibly maximize on large displays.
window.contentMaxSize = NSMakeSize(4000, 2400)

final class DemoContentView: NSView {
    var onBlankAreaMouseDown: ((NSEvent) -> Void)?
    var onBlankAreaMouseUp: ((NSEvent) -> Void)?
    var onMouseMoved: ((NSEvent) -> Void)?
    var onKeyDown: ((NSEvent) -> Void)?
    var onKeyUp: ((NSEvent) -> Void)?

    override func mouseDown(with event: NSEvent) {
        onBlankAreaMouseDown?(event)
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        onBlankAreaMouseUp?(event)
        super.mouseUp(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        onMouseMoved?(event)
        super.mouseMoved(with: event)
    }

    override func keyDown(with event: NSEvent) {
        onKeyDown?(event)
        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        onKeyUp?(event)
        super.keyUp(with: event)
    }
}

final class DemoPageView: NSView {
    override var acceptsFirstResponder: Bool {
        false
    }
}

/// Adapts `NSTextFieldDelegate` begin/end editing to closures for the demo.
final class DemoFieldDelegate: NSTextFieldDelegate {
    var onBegin: (() -> Void)?
    var onEnd: (() -> Void)?

    func controlTextDidBeginEditing(_ obj: NSNotification) {
        onBegin?()
    }

    func controlTextDidEndEditing(_ obj: NSNotification) {
        onEnd?()
    }
}

final class DemoCanvasView: NSView {
    static let palette: [NSColor] = [
        NSColor(calibratedRed: 0.86, green: 0.29, blue: 0.25, alpha: 1),
        NSColor(calibratedRed: 0.30, green: 0.62, blue: 0.86, alpha: 1),
        NSColor(calibratedRed: 0.22, green: 0.60, blue: 0.35, alpha: 1),
        NSColor(calibratedRed: 0.94, green: 0.72, blue: 0.25, alpha: 1)
    ]

    var fillColorIndex = 0
    var strokeColorIndex = 1
    var radius: CGFloat = 36
    var onEvent: ((String) -> Void)?

    override var acceptsFirstResponder: Bool {
        false
    }

    override func resetCursorRects() {
        // Crosshair inside the drawing surface, published as a cursor rect.
        addCursorRect(NSMakeRect(4, 4, frame.size.width - 8, frame.size.height - 8), cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        let inset = NSMakeRect(4, 4, frame.size.width - 8, frame.size.height - 8)
        NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.96, alpha: 1).setFill()
        let backdrop = NSBezierPath(roundedRect: inset, xRadius: 10, yRadius: 10)
        backdrop.fill()
        NSColor(calibratedRed: 0.55, green: 0.55, blue: 0.55, alpha: 1).setStroke()
        backdrop.stroke()

        Self.palette[strokeColorIndex].setStroke()
        let cross = NSBezierPath()
        cross.move(to: NSMakePoint(inset.origin.x + 10, inset.origin.y + 10))
        cross.line(to: NSMakePoint(NSMaxX(inset) - 10, NSMaxY(inset) - 10))
        cross.move(to: NSMakePoint(NSMaxX(inset) - 10, inset.origin.y + 10))
        cross.line(to: NSMakePoint(inset.origin.x + 10, NSMaxY(inset) - 10))
        cross.lineWidth = 2
        cross.stroke()

        Self.palette[fillColorIndex].setFill()
        let circle = NSBezierPath(ovalIn: NSMakeRect(
            NSMidX(inset) - radius,
            NSMidY(inset) - radius,
            radius * 2,
            radius * 2
        ))
        circle.fill()
        Self.palette[strokeColorIndex].setStroke()
        circle.lineWidth = 3
        circle.stroke()
    }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount > 1 {
            fillColorIndex = 0
            strokeColorIndex = 1
            radius = 36
            onEvent?("Canvas reset (double-click)")
        } else {
            fillColorIndex = (fillColorIndex + 1) % Self.palette.count
            onEvent?("Canvas fill color (click)")
        }
        needsDisplay = true
    }

    override func rightMouseDown(with event: NSEvent) {
        strokeColorIndex = (strokeColorIndex + 1) % Self.palette.count
        onEvent?("Canvas stroke color (right-click)")
        needsDisplay = true
    }

    override func scrollWheel(with event: NSEvent) {
        radius = min(max(radius + event.scrollingDeltaY * 4, 16), 110)
        onEvent?("Canvas radius (scroll)")
        needsDisplay = true
    }
}

final class DemoShapesView: NSView {
    var contextMenu: NSMenu?

    override var acceptsFirstResponder: Bool {
        false
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let contextMenu else {
            super.rightMouseDown(with: event)
            return
        }

        contextMenu.popUp(positioning: nil, at: convert(event.locationInWindow, from: nil), in: self)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        NSRectFill(NSMakeRect(0, 0, frame.size.width, frame.size.height))
        NSColor(calibratedRed: 0.55, green: 0.55, blue: 0.55, alpha: 1).setFill()
        NSFrameRect(NSMakeRect(0, 0, frame.size.width, frame.size.height))

        // Five-point star built from explicit line segments.
        let star = NSBezierPath()
        star.move(to: NSMakePoint(100, 75))
        star.line(to: NSMakePoint(118.8, 124.1))
        star.line(to: NSMakePoint(171.3, 126.8))
        star.line(to: NSMakePoint(130.4, 159.9))
        star.line(to: NSMakePoint(144.1, 210.7))
        star.line(to: NSMakePoint(100, 182))
        star.line(to: NSMakePoint(55.9, 210.7))
        star.line(to: NSMakePoint(69.6, 159.9))
        star.line(to: NSMakePoint(28.7, 126.8))
        star.line(to: NSMakePoint(81.2, 124.1))
        star.close()
        NSColor(calibratedRed: 0.94, green: 0.72, blue: 0.25, alpha: 1).setFill()
        star.fill()
        NSColor(calibratedRed: 0.61, green: 0.43, blue: 0.16, alpha: 1).setStroke()
        star.lineWidth = 2
        star.stroke()

        // S-curve demonstrating cubic Bezier stroking.
        let wave = NSBezierPath()
        wave.move(to: NSMakePoint(210, 90))
        wave.curve(
            to: NSMakePoint(400, 120),
            controlPoint1: NSMakePoint(270, 20),
            controlPoint2: NSMakePoint(340, 200)
        )
        wave.lineWidth = 3
        NSColor(calibratedRed: 0.30, green: 0.62, blue: 0.86, alpha: 1).setStroke()
        wave.stroke()

        // Rounded rectangle with fill and outline.
        let card = NSBezierPath(roundedRect: NSMakeRect(230, 150, 160, 90), xRadius: 14, yRadius: 14)
        NSColor(calibratedRed: 0.22, green: 0.60, blue: 0.35, alpha: 1).setFill()
        card.fill()
        NSColor(calibratedRed: 0.10, green: 0.35, blue: 0.18, alpha: 1).setStroke()
        card.lineWidth = 2
        card.stroke()

        // Concentric ovals demonstrating curve fills.
        let ring = NSBezierPath(ovalIn: NSMakeRect(60, 228, 44, 30))
        NSColor(calibratedRed: 0.86, green: 0.29, blue: 0.25, alpha: 1).setFill()
        ring.fill()

        // Text drawn through the attributed-string drawing API.
        "WinChocolate".draw(
            at: NSMakePoint(14, 10),
            withAttributes: [
                .font: NSFont.boldSystemFont(ofSize: 16),
                .foregroundColor: NSColor.red
            ]
        )

        // Demo artwork scaled into a corner via NSImage.draw(in:).
        NSImage(contentsOfFile: demoArtworkPath)?.draw(in: NSMakeRect(330, 16, 72, 54))

        // ICO decoding through the GDI+ fallback.
        NSImage(contentsOfFile: demoIconPath)?.draw(in: NSMakeRect(350, 80, 32, 32))
    }
}

final class DemoGradientsView: NSView {
    override var acceptsFirstResponder: Bool {
        false
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        NSRectFill(NSMakeRect(0, 0, frame.size.width, frame.size.height))
        NSColor(calibratedRed: 0.55, green: 0.55, blue: 0.55, alpha: 1).setFill()
        NSFrameRect(NSMakeRect(0, 0, frame.size.width, frame.size.height))

        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: NSColor.darkGray
        ]
        let sampleY: CGFloat = 30
        let sampleHeight: CGFloat = 56

        // Two-color horizontal gradient.
        "angle 0".draw(at: NSMakePoint(12, 10), withAttributes: labelAttributes)
        let horizontal = NSMakeRect(12, sampleY, 150, sampleHeight)
        NSGradient(
            starting: NSColor(calibratedRed: 0.30, green: 0.62, blue: 0.86, alpha: 1),
            ending: NSColor.white
        )?.draw(in: horizontal, angle: 0)
        NSColor.gray.setFill()
        NSFrameRect(horizontal)

        // Two-color vertical gradient, dark at the bottom per AppKit's angle 90.
        "angle 90".draw(at: NSMakePoint(184, 10), withAttributes: labelAttributes)
        let vertical = NSMakeRect(184, sampleY, 150, sampleHeight)
        NSGradient(
            starting: NSColor(calibratedRed: 0.13, green: 0.35, blue: 0.22, alpha: 1),
            ending: NSColor(calibratedRed: 0.66, green: 0.90, blue: 0.72, alpha: 1)
        )?.draw(in: vertical, angle: 90)
        NSColor.gray.setFill()
        NSFrameRect(vertical)

        // Multi-stop diagonal gradient with explicit locations.
        "multi-stop 45".draw(at: NSMakePoint(356, 10), withAttributes: labelAttributes)
        let diagonal = NSMakeRect(356, sampleY, 150, sampleHeight)
        NSGradient(colorsAndLocations:
            (NSColor(calibratedRed: 0.86, green: 0.29, blue: 0.25, alpha: 1), 0),
            (NSColor(calibratedRed: 0.94, green: 0.72, blue: 0.25, alpha: 1), 0.3),
            (NSColor(calibratedRed: 0.22, green: 0.60, blue: 0.35, alpha: 1), 1)
        )?.draw(in: diagonal, angle: 45)
        NSColor.gray.setFill()
        NSFrameRect(diagonal)

        // Gradient filling a rounded-rect path (clips internally).
        "path fill".draw(at: NSMakePoint(528, 10), withAttributes: labelAttributes)
        let capsule = NSBezierPath(roundedRect: NSMakeRect(528, sampleY, 150, sampleHeight), xRadius: 28, yRadius: 28)
        NSGradient(
            starting: NSColor(calibratedRed: 0.45, green: 0.30, blue: 0.75, alpha: 1),
            ending: NSColor(calibratedRed: 0.86, green: 0.55, blue: 0.90, alpha: 1)
        )?.draw(in: capsule, angle: -60)
        NSColor(calibratedRed: 0.35, green: 0.22, blue: 0.58, alpha: 1).setStroke()
        capsule.lineWidth = 2
        capsule.stroke()

        // Explicit clipping: stripes confined to an oval via addClip().
        "addClip stripes".draw(at: NSMakePoint(700, 10), withAttributes: labelAttributes)
        let ovalRect = NSMakeRect(700, sampleY, 150, sampleHeight)
        let oval = NSBezierPath(ovalIn: ovalRect)
        NSGraphicsContext.saveGraphicsState()
        oval.addClip()
        for band in 0..<8 {
            let color = band % 2 == 0
                ? NSColor(calibratedRed: 0.94, green: 0.72, blue: 0.25, alpha: 1)
                : NSColor(calibratedRed: 0.86, green: 0.29, blue: 0.25, alpha: 1)
            color.setFill()
            NSRectFill(NSMakeRect(ovalRect.origin.x + CGFloat(band) * 19, ovalRect.origin.y, 19, sampleHeight))
        }
        NSGraphicsContext.restoreGraphicsState()
        NSColor(calibratedRed: 0.61, green: 0.43, blue: 0.16, alpha: 1).setStroke()
        oval.lineWidth = 2
        oval.stroke()
    }
}

// MARK: - "New in 3.x" showcase views

/// A view that highlights while the cursor hovers it, driven by a tracking
/// area (3.21). Reports enter/exit through `onEvent`.
final class DemoHoverView: NSView {
    var onEvent: ((String) -> Void)?
    private var hovering = false

    override var acceptsFirstResponder: Bool { false }

    override func updateTrackingAreas() {
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func draw(_ dirtyRect: NSRect) {
        let fill = hovering
            ? NSColor(calibratedRed: 0.30, green: 0.62, blue: 0.86, alpha: 1)
            : NSColor(calibratedRed: 0.90, green: 0.92, blue: 0.95, alpha: 1)
        fill.setFill()
        let body = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 8, yRadius: 8)
        body.fill()
        NSColor(calibratedRed: 0.55, green: 0.58, blue: 0.62, alpha: 1).setStroke()
        body.stroke()

        let text = hovering ? "Hovering" : "Hover me"
        text.draw(at: NSMakePoint(14, bounds.size.height / 2 - 8), withAttributes: [
            .font: NSFont.boldSystemFont(ofSize: 13),
            .foregroundColor: hovering ? NSColor.white : NSColor(calibratedRed: 0.3, green: 0.3, blue: 0.32, alpha: 1),
        ])
    }

    override func mouseEntered(with event: NSEvent) {
        hovering = true
        needsDisplay = true
        onEvent?("Hover entered (mouseEntered)")
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false
        needsDisplay = true
        onEvent?("Hover exited (mouseExited)")
    }
}

/// A drag source (3.18): dragging out of it starts a text or file drag.
final class DemoDragHandle: NSView, NSDraggingSource {
    var draggedText = "WinChocolate drag payload"
    var onEvent: ((String) -> Void)?

    override var acceptsFirstResponder: Bool { false }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedRed: 0.22, green: 0.60, blue: 0.35, alpha: 1).setFill()
        let body = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 8, yRadius: 8)
        body.fill()
        "Drag me →".draw(at: NSMakePoint(14, bounds.size.height / 2 - 8), withAttributes: [
            .font: NSFont.boldSystemFont(ofSize: 13),
            .foregroundColor: NSColor.white,
        ])
    }

    override func mouseDown(with event: NSEvent) {
        let item = NSDraggingItem(pasteboardWriter: draggedText)
        item.draggingFrame = bounds
        onEvent?("Drag started: \"\(draggedText)\"")
        let session = beginDraggingSession(with: [item], event: event, source: self)
        onEvent?(session.winDropped ? "Drag dropped on a target" : "Drag canceled")
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }
}

/// A drop destination (3.18): accepts dropped text and files, highlighting
/// while a drag hovers and reporting what landed.
final class DemoDropWell: NSView {
    var onEvent: ((String) -> Void)?
    private var accepting = false
    private var lastDrop = "Drop text or files here"

    override var acceptsFirstResponder: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        (accepting
            ? NSColor(calibratedRed: 0.85, green: 0.93, blue: 0.85, alpha: 1)
            : NSColor(calibratedRed: 0.97, green: 0.97, blue: 0.95, alpha: 1)).setFill()
        let body = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 8, yRadius: 8)
        body.fill()
        (accepting ? NSColor(calibratedRed: 0.22, green: 0.6, blue: 0.35, alpha: 1) : NSColor(calibratedRed: 0.6, green: 0.62, blue: 0.64, alpha: 1)).setStroke()
        body.lineWidth = accepting ? 2 : 1
        body.stroke()
        lastDrop.draw(at: NSMakePoint(14, bounds.size.height / 2 - 8), withAttributes: [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor(calibratedRed: 0.3, green: 0.3, blue: 0.32, alpha: 1),
        ])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        accepting = true
        needsDisplay = true
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        accepting = false
        needsDisplay = true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        accepting = false
        if let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], !urls.isEmpty {
            lastDrop = "Dropped \(urls.count) file(s): \(urls.map { $0.lastPathComponent }.joined(separator: ", "))"
        } else if let text = sender.draggingPasteboard.string(forType: .string) {
            lastDrop = "Dropped text: \"\(text)\""
        } else {
            lastDrop = "Dropped (unknown content)"
        }
        needsDisplay = true
        onEvent?(lastDrop)
        return true
    }
}

/// A custom-drawn sample used to demonstrate printing (3.22).
final class DemoPrintSample: NSView {
    override var acceptsFirstResponder: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        NSRectFill(bounds)
        NSColor(calibratedRed: 0.55, green: 0.58, blue: 0.62, alpha: 1).setStroke()
        NSFrameRect(bounds)

        "WinChocolate Print Sample".draw(at: NSMakePoint(16, bounds.size.height - 34), withAttributes: [
            .font: NSFont.boldSystemFont(ofSize: 16),
            .foregroundColor: NSColor.black,
        ])
        "This view renders identically to screen and printer.".draw(at: NSMakePoint(16, bounds.size.height - 58), withAttributes: [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor(calibratedRed: 0.35, green: 0.35, blue: 0.4, alpha: 1),
        ])

        let bars: [NSColor] = [
            NSColor(calibratedRed: 0.86, green: 0.29, blue: 0.25, alpha: 1),
            NSColor(calibratedRed: 0.30, green: 0.62, blue: 0.86, alpha: 1),
            NSColor(calibratedRed: 0.22, green: 0.60, blue: 0.35, alpha: 1),
            NSColor(calibratedRed: 0.94, green: 0.72, blue: 0.25, alpha: 1),
        ]
        for (index, color) in bars.enumerated() {
            color.setFill()
            let height = CGFloat(20 + index * 16)
            NSBezierPath(rect: NSMakeRect(16 + CGFloat(index) * 40, 16, 30, height)).fill()
        }
    }
}

/// Data source for the showcase's framework-drawn (view-based) table (5.5).
final class DemoViewTableDataSource: NSTableViewDataSource {
    var tasks = [
        "Review the pull request", "Ship the nightly build", "Write the release notes",
        "Triage the bug backlog", "Update the changelog", "Refresh the screenshots",
        "Tag the release", "Post the announcement", "Close the milestone", "Archive the branch",
    ]
    var done = Array(repeating: false, count: 10)
    var notes = [
        "high", "nightly", "draft", "backlog", "minor",
        "1.0", "signed", "blog", "v5", "cleanup",
    ]

    func numberOfRows(in tableView: NSTableView) -> Int {
        tasks.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        tableColumn?.identifier == "note" ? notes[row] : tasks[row]
    }

    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        guard tableColumn?.identifier == "note" else {
            return
        }
        notes[row] = object.map { String(describing: $0) } ?? ""
    }
}

/// Delegate that vends a real control per cell so the drawn table hosts them
/// inside its cells — something a native list view can't do.
final class DemoViewTableDelegate: NSTableViewDelegate {
    let source: DemoViewTableDataSource
    var onEvent: ((String) -> Void)?

    init(source: DemoViewTableDataSource) {
        self.source = source
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableColumn?.identifier == "task" {
            let field = NSTextField(string: source.tasks[row], frame: NSMakeRect(0, 0, 200, 22))
            field.isBordered = false
            field.drawsBackground = false
            return field
        }
        // The "note" column vends no view → the drawn table paints it as text
        // and edits it in place (double-click) on this editable column.
        if tableColumn?.identifier == "note" {
            return nil
        }
        let button = NSButton(title: source.done[row] ? "Done ✓" : "Mark done", frame: NSMakeRect(0, 0, 110, 22))
        button.onAction = { [weak self, weak tableView] _ in
            guard let self else {
                return
            }
            self.source.done[row].toggle()
            self.onEvent?("Row \(row) → \(self.source.done[row] ? "done" : "not done")")
            tableView?.reloadData()
        }
        return button
    }

    /// Completed rows render taller — a live demo of the drawn table honoring
    /// per-row heights (toggle "Mark done" and watch the row grow).
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        source.done[row] ? 44 : 24
    }
}

/// A small pipeline-status list showcasing `NSTableRowView` hosting: each row
/// gets a full-width colored row view behind hosted label cells.
final class DemoStatusRowDataSource: NSTableViewDataSource {
    let items: [(stage: String, status: String)] = [
        ("Build", "passing"), ("Unit tests", "passing"), ("Lint", "warning"),
        ("Deploy", "failed"), ("Docs", "passing"), ("Package", "passing"),
    ]
    func numberOfRows(in tableView: NSTableView) -> Int { items.count }
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        tableColumn?.identifier == "stage" ? items[row].stage : items[row].status
    }
}

final class DemoStatusRowDelegate: NSTableViewDelegate {
    let source: DemoStatusRowDataSource
    init(source: DemoStatusRowDataSource) { self.source = source }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        // Hosted (transparent) labels sit above the colored row view.
        let text = tableColumn?.identifier == "stage" ? source.items[row].stage : source.items[row].status
        let field = NSTextField(string: text, frame: NSMakeRect(0, 0, 120, 20))
        field.isBordered = false
        field.drawsBackground = false
        return field
    }

    func tableView(_ tableView: NSTableView, rowViewFor row: Int) -> NSTableRowView? {
        let rowView = NSTableRowView(frame: .zero)
        switch source.items[row].status {
        case "passing": rowView.backgroundColor = NSColor(red: 0.85, green: 0.95, blue: 0.85, alpha: 1)
        case "warning": rowView.backgroundColor = NSColor(red: 1.0, green: 0.97, blue: 0.80, alpha: 1)
        case "failed": rowView.backgroundColor = NSColor(red: 1.0, green: 0.87, blue: 0.87, alpha: 1)
        default: rowView.backgroundColor = .white
        }
        return rowView
    }
}

/// A plain-text document demonstrating the NSDocument window-controller flow.
final class DemoNoteDocument: NSDocument {
    var text = ""

    override func data(ofType typeName: String) throws -> Data {
        Data(Array(text.utf8))
    }

    override func read(from data: Data, ofType typeName: String) throws {
        text = String(decoding: data, as: UTF8.self)
    }

    override func makeWindowControllers() {
        let noteWindow = NSWindow(
            contentRect: NSMakeRect(220, 180, 460, 320),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        let editor = NSTextView(frame: NSMakeRect(12, 12, 436, 296))
        editor.string = text
        editor.allowsUndo = true
        editor.onTextChanged = { [weak self] textView in
            self?.text = textView.string
            self?.updateChangeCount(.changeDone)
        }
        let noteContent = NSView(frame: NSMakeRect(0, 0, 460, 320))
        noteContent.addSubview(editor)
        noteWindow.contentView = noteContent
        addWindowController(NSWindowController(window: noteWindow))
    }
}


/// Reports split-view divider drags in the status label.
final class DemoSplitDelegate: NSSplitViewDelegate {
    var onResize: (() -> Void)?

    func splitViewDidResizeSubviews(_ notification: NSNotification) {
        onResize?()
    }
}

let demoSplitDelegate = DemoSplitDelegate()

/// Enables Edit-menu items from the notes text view's undo stacks.
final class EditMenuController: NSMenuItemValidation {
    var textView: NSTextView?

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        guard let manager = textView?.undoManager else {
            return false
        }

        // Titles refresh live ("Undo Typing") because the native menu
        // rebuilds from the NSMenu on WM_INITMENUPOPUP.
        if menuItem.keyEquivalentModifierMask.contains(.shift) {
            menuItem.title = manager.redoMenuItemTitle
            return manager.canRedo
        }
        menuItem.title = manager.undoMenuItemTitle
        return manager.canUndo
    }
}

let editMenuController = EditMenuController()

final class DemoTableDataSource: NSTableViewDataSource {
    var rows: [[String]] = [
        ["NSApplication", "Running"],
        ["NSWindow", "Key/Main"],
        ["NSButton", "Actions"],
        ["NSTextField", "Editing"],
        ["NSForm", "Composed rows"],
        ["NSMatrix", "Legacy grid"],
        ["NSSecureTextField", "Password"],
        ["NSSearchField", "Immediate search"],
        ["NSComboBox", "Editable list"],
        ["NSLevelIndicator", "Value meter"],
        ["NSDatePicker", "Date/time"],
        ["NSColorWell", "Color swatch"],
        ["NSSegmentedControl", "Composed segments"],
        ["NSTabView", "Native tabs"],
        ["NSImageView", "Bitmap artwork"],
        ["NSBrowser", "Column browser"],
        ["NSOutlineView", "Tree table"],
        ["NSTableView", "First slice"],
        ["NSTableColumn", "Identifiers"],
        ["NSTableCellView", "View based"],
        ["NSTableRowView", "Selection state"],
        ["NSScrollView", "Document view"],
        ["NSResponder", "Key loop"],
        ["NSEvent", "Keyboard/mouse"],
        ["NSMenu", "Quit command"],
        ["NSAlert", "Modal"],
        ["NSColor", "Native paint"],
        ["NSFont", "Native font"]
    ]

    func numberOfRows(in tableView: NSTableView) -> Int {
        rows.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard rows.indices.contains(row) else {
            return nil
        }

        switch tableColumn?.identifier.rawValue {
        case "name":
            return rows[row][0]
        case "status":
            return rows[row][1]
        default:
            return nil
        }
    }

    func sort(using descriptor: NSSortDescriptor) {
        guard let key = descriptor.key else {
            return
        }

        let columnIndex: Int
        switch key {
        case "name":
            columnIndex = 0
        case "status":
            columnIndex = 1
        default:
            return
        }

        rows.sort { left, right in
            let leftValue = left.indices.contains(columnIndex) ? left[columnIndex] : ""
            let rightValue = right.indices.contains(columnIndex) ? right[columnIndex] : ""
            if descriptor.ascending {
                return leftValue < rightValue
            }

            return leftValue > rightValue
        }
    }
}

final class DemoOutlineDataSource: NSOutlineViewDataSource {
    let roots = ["Application", "Controls", "Tables"]
    let children: [String: [String]] = [
        "Application": ["NSApplication", "NSWindow", "NSMenu"],
        "Controls": ["NSButton", "NSTextField", "NSMatrix"],
        "Tables": ["NSTableView", "NSOutlineView", "NSTableColumn"]
    ]

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        guard let item else {
            return roots.count
        }

        return children[String(describing: item)]?.count ?? 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let item {
            return children[String(describing: item)]?[index] ?? ""
        }

        return roots[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        !(children[String(describing: item)] ?? []).isEmpty
    }

    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        guard let item else {
            return nil
        }

        let value = String(describing: item)
        if tableColumn?.identifier.rawValue == "outlineStatus" {
            return children[value] == nil ? "Leaf" : "Group"
        }

        return value
    }
}

final class DemoBrowserDataSource: NSBrowserDelegate {
    let roots = ["Application", "Controls", "Tables"]
    let children: [String: [String]] = [
        "Application": ["NSApplication", "NSWindow", "NSMenu", "NSAlert"],
        "Controls": ["NSButton", "NSTextField", "NSComboBox", "NSBrowser"],
        "Tables": ["NSTableView", "NSOutlineView", "NSTableColumn", "NSScrollView"]
    ]

    func browser(_ browser: NSBrowser, numberOfChildrenOfItem item: Any?) -> Int {
        guard let item else {
            return roots.count
        }

        return children[String(describing: item)]?.count ?? 0
    }

    func browser(_ browser: NSBrowser, child index: Int, ofItem item: Any?) -> Any {
        if let item {
            return children[String(describing: item)]?[index] ?? ""
        }

        return roots[index]
    }

    func browser(_ browser: NSBrowser, isLeafItem item: Any?) -> Bool {
        guard let item else {
            return false
        }

        return children[String(describing: item)] == nil
    }
}

final class DemoCollectionDataSource: NSCollectionViewDataSource {
    let values = ["NSButton", "NSTextField", "NSTableView", "NSImageView", "NSBrowser", "NSOutlineView"]

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        values.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = NSCollectionViewItem()
        let title = values[indexPath.item]
        item.representedObject = title
        item.view = NSButton(title: title, frame: NSMakeRect(0, 0, 112, 28))
        return item
    }
}

/// A multi-section collection source (with section headers) so the flow
/// layout's wrapping, re-tiling, and section headers are all demonstrable.
final class DemoFlowCollectionDataSource: NSCollectionViewDataSource {
    let sections: [(title: String, items: [String])] = [
        ("Views", ["NSView", "NSImageView", "NSTextField", "NSButton", "NSSlider", "NSStepper"]),
        ("Controls", ["NSComboBox", "NSPopUpButton", "NSDatePicker", "NSColorWell", "NSSegmentedControl", "NSLevelIndicator", "NSPathControl", "NSTokenField"]),
        ("Containers", ["NSTableView", "NSOutlineView", "NSBrowser", "NSScrollView", "NSSplitView", "NSTabView", "NSBox"]),
    ]

    func numberOfSections(in collectionView: NSCollectionView) -> Int {
        sections.count
    }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        sections[section].items.count
    }

    func collectionView(_ collectionView: NSCollectionView, itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = NSCollectionViewItem()
        let title = sections[indexPath.section].items[indexPath.item]
        item.representedObject = title
        let button = NSButton(title: title, frame: NSMakeRect(0, 0, 120, 28))
        item.view = button
        return item
    }

    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> NSView? {
        guard kind == NSCollectionView.elementKindSectionHeader else {
            return nil
        }
        let header = NSTextField(string: "  \(sections[indexPath.section].title)", frame: .zero)
        header.isBordered = false
        header.font = NSFont.boldSystemFont(ofSize: 12)
        header.backgroundColor = NSColor(red: 0.90, green: 0.93, blue: 0.98, alpha: 1)
        return header
    }
}

/// Sizes each collection item to fit its label, demonstrating per-item flow
/// sizing (`NSCollectionViewDelegateFlowLayout`).
final class DemoFlowSizeDelegate: NSCollectionViewDelegateFlowLayout {
    let source: DemoFlowCollectionDataSource
    init(_ source: DemoFlowCollectionDataSource) { self.source = source }
    func collectionView(_ collectionView: NSCollectionView, layout collectionViewLayout: NSCollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> NSSize {
        NSMakeSize(28 + CGFloat(source.sections[indexPath.section].items[indexPath.item].count) * 8, 28)
    }
}

let contentView = DemoContentView(frame: NSMakeRect(0, 0, 1120, 760))
let controlsPage = DemoPageView(frame: NSMakeRect(0, 144, 1120, 560))
let valuesPage = DemoPageView(frame: NSMakeRect(0, 144, 1120, 560))
let tablesPage = DemoPageView(frame: NSMakeRect(0, 144, 1120, 560))
let drawingPage = DemoPageView(frame: NSMakeRect(0, 144, 1120, 560))
let showcasePage = DemoPageView(frame: NSMakeRect(0, 144, 1120, 560))
let listsPage = DemoPageView(frame: NSMakeRect(0, 144, 1120, 560))
valuesPage.isHidden = true
tablesPage.isHidden = true
drawingPage.isHidden = true
showcasePage.isHidden = true
listsPage.isHidden = true
let counterLabel = NSTextField(string: "Clicks: 0", frame: NSMakeRect(32, 36, 300, 24))
let statusLabel = NSTextField(string: "Ready", frame: NSMakeRect(32, 74, 640, 24))
let focusLabel = NSTextField(string: "Focus: none", frame: NSMakeRect(744, 74, 300, 24))
let button = NSButton(title: "Click", frame: NSMakeRect(32, 24, 100, 34))
// 3.1: Return activates the default button, from anywhere but a text view.
button.keyEquivalent = "\r"
let enableButton = NSButton(title: "Disable Click", frame: NSMakeRect(152, 24, 144, 34))
let hideButton = NSButton(title: "Hide Counter", frame: NSMakeRect(316, 24, 144, 34))
let moveButton = NSButton(title: "Move Click", frame: NSMakeRect(480, 24, 128, 34))
let panelButton = NSButton(title: "Panel", frame: NSMakeRect(632, 24, 100, 34))
let popoverButton = NSButton(title: "Popover", frame: NSMakeRect(752, 24, 112, 34))
let askToSaveButton = NSButton(title: "Ask to Save", frame: NSMakeRect(884, 24, 112, 34))
let editableLabel = NSTextField(string: "Type here:", frame: NSMakeRect(32, 88, 104, 24))
let editableTextField = NSTextField(string: "", frame: NSMakeRect(152, 86, 360, 28))
let secureLabel = NSTextField(string: "Password:", frame: NSMakeRect(32, 122, 104, 24))
let secureTextField = NSSecureTextField(string: "", frame: NSMakeRect(152, 120, 240, 28))
let alertButton = NSButton(title: "Alert", frame: NSMakeRect(32, 152, 100, 34))
let titleCheckbox = NSButton(title: "Show count in title", frame: NSMakeRect(152, 152, 228, 34))
let alertStyleBox = NSBox(title: "Alert Style", frame: NSMakeRect(448, 120, 248, 116))
let alertStyleLabel = NSTextField(string: "Alert style:", frame: NSMakeRect(472, 156, 112, 24))
let alertStylePopup = NSPopUpButton(frame: NSMakeRect(472, 186, 184, 96), pullsDown: false)
let infoRadio = NSButton(title: "Info", frame: NSMakeRect(32, 234, 88, 24))
let warningRadio = NSButton(title: "Warning", frame: NSMakeRect(136, 234, 116, 24))
let criticalRadio = NSButton(title: "Critical", frame: NSMakeRect(268, 234, 116, 24))
let notesLabel = NSTextField(string: "Notes:", frame: NSMakeRect(32, 286, 104, 24))
let notesTextView = NSTextView(frame: NSMakeRect(152, 286, 360, 96))
let selectWordButton = NSButton(title: "Select Word", frame: NSMakeRect(528, 286, 120, 34))
let tokenLabel = NSTextField(string: "Tokens:", frame: NSMakeRect(32, 410, 104, 24))
let tokenField = NSTokenField(tokens: ["Cocoa", "AppKit", "WinChocolate"], frame: NSMakeRect(152, 408, 360, 28))
let priceLabel = NSTextField(string: "Price:", frame: NSMakeRect(528, 410, 56, 24))
let priceField = NSTextField(string: "", frame: NSMakeRect(588, 408, 144, 28))
priceField.isEditable = true
priceField.isSelectable = true
priceField.isBordered = true
let priceFormatter = NumberFormatter()
priceFormatter.numberStyle = .currency
priceField.formatter = priceFormatter
priceField.objectValue = NSNumber(value: 1234.5)
let formLabel = NSTextField(string: "Form:", frame: NSMakeRect(744, 120, 80, 24))
let form = NSForm(frame: NSMakeRect(824, 120, 256, 92))
let matrixLabel = NSTextField(string: "Matrix:", frame: NSMakeRect(744, 240, 80, 24))
let matrix = NSMatrix(
    frame: NSMakeRect(824, 240, 240, 72),
    mode: .trackModeMatrix,
    prototype: NSButtonCell(title: "Choice"),
    numberOfRows: 2,
    numberOfColumns: 2
)
let sliderLabel = NSTextField(string: "Slider:", frame: NSMakeRect(32, 28, 72, 24))
let slider = NSSlider(value: 50, minValue: 0, maxValue: 100, target: nil, action: "sliderChanged:")
let sliderValueLabel = NSTextField(string: "50", frame: NSMakeRect(312, 28, 48, 24))
let verticalSliderLabel = NSTextField(string: "Vert:", frame: NSMakeRect(604, 28, 44, 24))
let verticalSlider = NSSlider(value: 50, minValue: 0, maxValue: 100, target: nil, action: nil)
let progressLabel = NSTextField(string: "Progress:", frame: NSMakeRect(32, 60, 88, 24))
let progressIndicator = NSProgressIndicator(frame: NSMakeRect(128, 64, 232, 18))
let activityIndicator = NSProgressIndicator(frame: NSMakeRect(388, 64, 160, 18))
let stepperLabel = NSTextField(string: "Stepper:", frame: NSMakeRect(32, 94, 88, 24))
let stepper = NSStepper(frame: NSMakeRect(128, 94, 20, 28))
let stepperValueLabel = NSTextField(string: "50", frame: NSMakeRect(176, 94, 64, 24))
let comboLabel = NSTextField(string: "Combo:", frame: NSMakeRect(32, 154, 88, 24))
let comboBox = NSComboBox(frame: NSMakeRect(128, 152, 184, 28))
let searchLabel = NSTextField(string: "Search:", frame: NSMakeRect(32, 190, 88, 24))
let searchField = NSSearchField(frame: NSMakeRect(128, 188, 232, 28))
let levelLabel = NSTextField(string: "Level:", frame: NSMakeRect(32, 226, 88, 24))
let levelIndicator = NSLevelIndicator(frame: NSMakeRect(128, 230, 144, 18))
let colorWellLabel = NSTextField(string: "Color:", frame: NSMakeRect(288, 226, 56, 24))
let colorWell = NSColorWell(frame: NSMakeRect(348, 224, 32, 28))
colorWell.colorWellStyle = .default
let fontButton = NSButton(title: "Font...", frame: NSMakeRect(396, 222, 92, 30))
let segmentedLabel = NSTextField(string: "Segments:", frame: NSMakeRect(32, 286, 104, 24))
let segmentedControl = NSSegmentedControl(labels: ["One", "Two", "Three"], frame: NSMakeRect(152, 284, 240, 28))
let scrollerLabel = NSTextField(string: "Scroller:", frame: NSMakeRect(32, 334, 88, 24))
let scroller = NSScroller(frame: NSMakeRect(128, 340, 240, 18))
let scrollerValueLabel = NSTextField(string: "0", frame: NSMakeRect(384, 334, 48, 24))
let timerTickLabel = NSTextField(string: "Timer: 0s", frame: NSMakeRect(548, 382, 160, 24))
let dateLabel = NSTextField(string: "Date:", frame: NSMakeRect(32, 382, 88, 24))
let datePicker = NSDatePicker(date: Date(timeIntervalSince1970: 1_780_272_000), frame: NSMakeRect(128, 378, 184, 28))
let dateValueLabel = NSTextField(string: "2026-06-01", frame: NSMakeRect(328, 382, 192, 24))
let calendarLabel = NSTextField(string: "Calendar:", frame: NSMakeRect(724, 60, 120, 24))
let calendarPicker = NSDatePicker(date: Date(timeIntervalSince1970: 1_780_272_000), frame: NSMakeRect(724, 88, 224, 168))
calendarPicker.datePickerStyle = .clockAndCalendar
let ratingLabel = NSTextField(string: "Rating:", frame: NSMakeRect(724, 268, 60, 24))
let ratingIndicator = NSLevelIndicator(frame: NSMakeRect(786, 264, 140, 30))
ratingIndicator.levelIndicatorStyle = .rating
ratingIndicator.minValue = 0
ratingIndicator.maxValue = 5
ratingIndicator.doubleValue = 3
ratingIndicator.isEditable = true
let canvasLabel = NSTextField(string: "Canvas:", frame: NSMakeRect(32, 36, 200, 24))
let canvasView = DemoCanvasView(frame: NSMakeRect(32, 68, 420, 280))
let canvasHintLabel = NSTextField(string: "Click: fill color   Right-click: outline   Scroll: size   Double-click: reset", frame: NSMakeRect(32, 356, 520, 24))
let drawingEventLabel = NSTextField(string: "Last canvas event: none", frame: NSMakeRect(32, 388, 520, 24))
let shapesLabel = NSTextField(string: "Paths:", frame: NSMakeRect(490, 36, 200, 24))
let shapesView = DemoShapesView(frame: NSMakeRect(0, 0, 420, 280))
let shapesScrollView = NSScrollView(frame: NSMakeRect(490, 68, 420, 280))
let shapesZoomInButton = NSButton(title: "Zoom In", frame: NSMakeRect(620, 356, 88, 28))
let shapesZoomOutButton = NSButton(title: "Zoom Out", frame: NSMakeRect(716, 356, 88, 28))
let shapesZoomResetButton = NSButton(title: "1x", frame: NSMakeRect(812, 356, 48, 28))
let shapesZoomLabel = NSTextField(string: "1.00x", frame: NSMakeRect(868, 358, 64, 24))
let gradientsLabel = NSTextField(string: "Gradients and clipping:", frame: NSMakeRect(32, 420, 300, 24))
let gradientsView = DemoGradientsView(frame: NSMakeRect(32, 448, 878, 100))
let pageSelector = NSPopUpButton(frame: NSMakeRect(0, 0, 168, 28), pullsDown: false)
let imageLabel = NSTextField(string: "Image view:", frame: NSMakeRect(32, 28, 104, 24))
let imageView = NSImageView(frame: NSMakeRect(152, 28, 300, 190))
let clipLabel = NSTextField(string: "Clip view:", frame: NSMakeRect(496, 28, 104, 24))
let clipView = NSClipView(frame: NSMakeRect(616, 28, 220, 110))
let clipDocumentView = NSView(frame: NSMakeRect(0, 0, 420, 220))
let clipTopLeftPane = NSView(frame: NSMakeRect(0, 0, 210, 110))
let clipTopRightPane = NSView(frame: NSMakeRect(210, 0, 210, 110))
let clipBottomLeftPane = NSView(frame: NSMakeRect(0, 110, 210, 110))
let clipBottomRightPane = NSView(frame: NSMakeRect(210, 110, 210, 110))
let clipTopLeftLabel = NSTextField(string: "0,0", frame: NSMakeRect(12, 12, 72, 24))
let clipTopRightLabel = NSTextField(string: "right", frame: NSMakeRect(222, 12, 72, 24))
let clipBottomLeftLabel = NSTextField(string: "down", frame: NSMakeRect(12, 122, 72, 24))
let clipBottomRightLabel = NSTextField(string: "far corner", frame: NSMakeRect(222, 122, 100, 24))
let clipOriginLabel = NSTextField(string: "origin 0,0", frame: NSMakeRect(848, 28, 96, 24))
let clipHomeButton = NSButton(title: "Home", frame: NSMakeRect(848, 60, 72, 28))
let clipCenterButton = NSButton(title: "Center", frame: NSMakeRect(928, 60, 72, 28))
let clipCornerButton = NSButton(title: "Corner", frame: NSMakeRect(1008, 60, 72, 28))
let pathLabel = NSTextField(string: "Path:", frame: NSMakeRect(496, 286, 104, 24))
let pathControl = NSPathControl(url: URL(fileURLWithPath: "C:\\AIResearch\\WinChocolate\\Code\\WinChocolate"), frame: NSMakeRect(616, 284, 360, 28))
let splitLabel = NSTextField(string: "Split view:", frame: NSMakeRect(496, 160, 104, 24))
let splitView = NSSplitView(frame: NSMakeRect(616, 160, 240, 96))
let splitLeftPane = NSView(frame: NSZeroRect)
let splitRightPane = NSView(frame: NSZeroRect)
let tableLabel = NSTextField(string: "Table view:", frame: NSMakeRect(32, 336, 120, 24))
let scrollSelectedButton = NSButton(title: "Scroll Selected", frame: NSMakeRect(32, 368, 120, 30))
let tableScrollView = NSScrollView(frame: NSMakeRect(152, 336, 520, 176))
let tableView = NSTableView(frame: NSMakeRect(0, 0, 520, 176))
let tableDataSource = DemoTableDataSource()
let outlineLabel = NSTextField(string: "Outline view:", frame: NSMakeRect(704, 336, 120, 24))
let outlineScrollView = NSScrollView(frame: NSMakeRect(824, 336, 256, 176))
let outlineView = NSOutlineView(frame: NSMakeRect(0, 0, 256, 176))
let outlineDataSource = DemoOutlineDataSource()
let browserLabel = NSTextField(string: "Browser:", frame: NSMakeRect(32, 216, 120, 24))
let browser = NSBrowser(frame: NSMakeRect(152, 216, 360, 104))
let browserDataSource = DemoBrowserDataSource()
let collectionLabel = NSTextField(string: "Collection:", frame: NSMakeRect(32, 230, 120, 24))
let collectionView = NSCollectionView(frame: NSMakeRect(152, 226, 392, 96))
let collectionDataSource = DemoCollectionDataSource()
let visualEffectLabel = NSTextField(string: "Visual effect:", frame: NSMakeRect(880, 116, 120, 24))
let visualEffectView = NSVisualEffectView(frame: NSMakeRect(880, 146, 200, 86))
let visualEffectTitle = NSTextField(string: "material: sidebar", frame: NSMakeRect(12, 12, 160, 24))
let visualEffectButton = NSButton(title: "Cycle", frame: NSMakeRect(12, 50, 80, 28))
let demoToolbar = NSToolbar(identifier: "WinChocolateDemoToolbar")
let openToolbarItem = NSToolbarItem(itemIdentifier: "open")
let saveToolbarItem = NSToolbarItem(itemIdentifier: "save")
let toolbarSeparatorItem = NSToolbarItem(itemIdentifier: .separator)
let toolbarFlexibleSpaceItem = NSToolbarItem(itemIdentifier: .flexibleSpace)
let pageToolbarItem = NSToolbarItem(itemIdentifier: "pageSelector")
let toolbarSearchField = NSSearchField(frame: NSMakeRect(0, 0, 160, 24))
let searchToolbarItem = NSToolbarItem(itemIdentifier: "toolbarSearch")
let toggleToolbarItem = NSToolbarItem(itemIdentifier: "toggleToolbar")
let customizeToolbarItem = NSToolbarItem(itemIdentifier: "customizeToolbar")
let contentFocusColor = NSColor(calibratedRed: 0.92, green: 0.97, blue: 1.0, alpha: 1.0)
let normalContentColor = NSColor.windowBackgroundColor
let controlFocusColor = NSColor(calibratedRed: 1.0, green: 0.96, blue: 0.72, alpha: 1.0)
let normalTextFieldColor = NSColor.white
var clickCount = 0
var isClickEnabled = true
var isCounterHidden = false
var movedRight = false
var suppressNextTableSelectionStatus = false
var colorIndex = 0
var inspectorPanel: NSPanel?
let popover = NSPopover()
let demoColors: [NSColor] = [.red, .green, .blue, .white]
var visualEffectIndex = 0
let visualEffectMaterials: [(NSVisualEffectView.Material, String)] = [
    (.sidebar, "sidebar"),
    (.selection, "selection"),
    (.menu, "menu"),
    (.hudWindow, "hud")
]
func demoResourcePath(named name: String, ofType type: String = "bmp") -> String {
    Bundle.main.path(forResource: name, ofType: type, inDirectory: "Resources")
        ?? Bundle(path: ".")?.path(forResource: name, ofType: type, inDirectory: "Demo\\DemoApplication\\Resources")
        ?? "Demo\\DemoApplication\\Resources\\\(name).\(type)"
}

/// Writes a 32x32 ICO file at runtime so the demo can exercise icon decoding.
func demoIconResourcePath() -> String {
    let side = 32
    var rows: [UInt8] = []

    // Pixel rows bottom-up in BGRA: a blue disc on a yellow field.
    for y in stride(from: side - 1, through: 0, by: -1) {
        for x in 0..<side {
            let dx = x - side / 2
            let dy = y - side / 2
            if dx * dx + dy * dy <= 144 {
                rows.append(contentsOf: [200, 120, 40, 255])
            } else {
                rows.append(contentsOf: [60, 200, 250, 255])
            }
        }
    }
    let andMask = Array(repeating: UInt8(0), count: side * 4)

    var bytes: [UInt8] = []
    func appendU16(_ value: UInt16) {
        bytes.append(UInt8(value & 0xff))
        bytes.append(UInt8(value >> 8))
    }
    func appendU32(_ value: UInt32) {
        for shift: UInt32 in [0, 8, 16, 24] {
            bytes.append(UInt8((value >> shift) & 0xff))
        }
    }

    // ICONDIR + one ICONDIRENTRY + BITMAPINFOHEADER (double height) + masks.
    appendU16(0)
    appendU16(1)
    appendU16(1)
    bytes.append(UInt8(side))
    bytes.append(UInt8(side))
    bytes.append(0)
    bytes.append(0)
    appendU16(1)
    appendU16(32)
    appendU32(UInt32(40 + rows.count + andMask.count))
    appendU32(22)
    appendU32(40)
    appendU32(UInt32(side))
    appendU32(UInt32(side * 2))
    appendU16(1)
    appendU16(32)
    appendU32(0)
    appendU32(UInt32(rows.count + andMask.count))
    appendU32(0)
    appendU32(0)
    appendU32(0)
    appendU32(0)
    bytes.append(contentsOf: rows)
    bytes.append(contentsOf: andMask)

    let candidates = [
        URL(fileURLWithPath: Bundle.main.bundlePath).appendingPathComponent("WinChocolateIconDemo.ico").path,
        "C:\\AIResearch\\WinChocolate\\Code\\WinChocolate\\.build\\aarch64-unknown-windows-msvc\\debug\\WinChocolateIconDemo.ico",
        "C:\\Users\\bobby\\AppData\\Local\\Temp\\WinChocolateIconDemo.ico"
    ]
    for path in candidates {
        let url = URL(fileURLWithPath: path)
        do {
            try Data(bytes).write(to: url)
            if (try? Data(contentsOf: url))?.isEmpty == false {
                return path
            }
        } catch {
            continue
        }
    }

    return candidates[0]
}

func demoToolbarBitmapPath(named name: String, width: Int, kind: String) -> String {
    let height = 34
    var pixels = Array(repeating: UInt8(240), count: width * height * 3)

    func setPixel(_ x: Int, _ y: Int, _ r: UInt8, _ g: UInt8, _ b: UInt8) {
        guard x >= 0, x < width, y >= 0, y < height else {
            return
        }
        let offset = (y * width + x) * 3
        pixels[offset] = b
        pixels[offset + 1] = g
        pixels[offset + 2] = r
    }

    func fillRect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ r: UInt8, _ g: UInt8, _ b: UInt8) {
        for yy in y..<(y + h) {
            for xx in x..<(x + w) {
                setPixel(xx, yy, r, g, b)
            }
        }
    }

    func strokeRect(_ x: Int, _ y: Int, _ w: Int, _ h: Int, _ r: UInt8 = 72, _ g: UInt8 = 78, _ b: UInt8 = 84) {
        for xx in x..<(x + w) {
            setPixel(xx, y, r, g, b)
            setPixel(xx, y + h - 1, r, g, b)
        }
        for yy in y..<(y + h) {
            setPixel(x, yy, r, g, b)
            setPixel(x + w - 1, yy, r, g, b)
        }
    }

    func fillCircle(_ cx: Int, _ cy: Int, _ radius: Int, _ r: UInt8, _ g: UInt8, _ b: UInt8) {
        for yy in (cy - radius)...(cy + radius) {
            for xx in (cx - radius)...(cx + radius) where ((xx - cx) * (xx - cx) + (yy - cy) * (yy - cy)) <= radius * radius {
                setPixel(xx, yy, r, g, b)
            }
        }
    }

    func characterRows(_ character: Character) -> [String] {
        switch character {
        case "A": return ["111", "101", "111", "101", "101"]
        case "B": return ["110", "101", "110", "101", "110"]
        case "C": return ["111", "100", "100", "100", "111"]
        case "D": return ["110", "101", "101", "101", "110"]
        case "E": return ["111", "100", "110", "100", "111"]
        case "I": return ["111", "010", "010", "010", "111"]
        case "L": return ["100", "100", "100", "100", "111"]
        case "M": return ["101", "111", "111", "101", "101"]
        case "N": return ["101", "111", "111", "111", "101"]
        case "O": return ["111", "101", "101", "101", "111"]
        case "P": return ["111", "101", "111", "100", "100"]
        case "R": return ["110", "101", "110", "101", "101"]
        case "S": return ["111", "100", "111", "001", "111"]
        case "T": return ["111", "010", "010", "010", "010"]
        case "U": return ["101", "101", "101", "101", "111"]
        case "V": return ["101", "101", "101", "101", "010"]
        case "Z": return ["111", "001", "010", "100", "111"]
        default: return ["000", "000", "000", "000", "000"]
        }
    }

    func drawText(_ text: String, y: Int) {
        let characters = Array(text)
        let textWidth = max(0, characters.count * 4 - 1)
        var x = max((width - textWidth) / 2, 1)
        for character in characters {
            if character == " " {
                x += 4
                continue
            }

            let rows = characterRows(character)
            for (rowIndex, row) in rows.enumerated() {
                for (columnIndex, pixel) in row.enumerated() where pixel == "1" {
                    fillRect(x + columnIndex, y + rowIndex, 1, 1, 28, 34, 42)
                }
            }
            x += 4
        }
    }

    let centerX = width / 2
    let label: String
    switch kind {
    case "open":
        label = "OPEN"
        fillRect(centerX - 12, 4, 24, 13, 246, 174, 58)
        fillRect(centerX - 10, 2, 11, 5, 255, 205, 92)
        strokeRect(centerX - 12, 4, 24, 13)
        strokeRect(centerX - 10, 2, 11, 5)
    case "save":
        label = "SAVE"
        fillRect(centerX - 9, 3, 18, 18, 128, 96, 172)
        strokeRect(centerX - 9, 3, 18, 18)
        fillRect(centerX - 5, 6, 10, 5, 245, 245, 245)
        fillRect(centerX - 5, 15, 10, 5, 205, 190, 226)
    case "toggle":
        label = "DISABLE"
        fillCircle(centerX, 11, 9, 120, 130, 142)
        fillCircle(centerX, 11, 4, 245, 245, 245)
        fillRect(centerX - 1, 1, 2, 5, 72, 78, 84)
        fillRect(centerX - 1, 17, 2, 5, 72, 78, 84)
        fillRect(centerX - 13, 10, 6, 2, 72, 78, 84)
        fillRect(centerX + 7, 10, 6, 2, 72, 78, 84)
    default:
        label = "CUSTOMIZE"
        fillRect(centerX - 13, 5, 26, 2, 72, 78, 84)
        fillRect(centerX - 13, 11, 26, 2, 72, 78, 84)
        fillRect(centerX - 13, 17, 26, 2, 72, 78, 84)
        fillCircle(centerX - 6, 6, 4, 58, 126, 206)
        fillCircle(centerX + 4, 12, 4, 58, 126, 206)
        fillCircle(centerX - 1, 18, 4, 58, 126, 206)
    }
    drawText(label, y: 27)

    let rowSize = ((24 * width + 31) / 32) * 4
    let pixelSize = rowSize * height
    let fileSize = 54 + pixelSize
    var bytes = Array(repeating: UInt8(0), count: fileSize)

    func writeInt32(_ value: Int, at offset: Int) {
        bytes[offset] = UInt8(value & 0xff)
        bytes[offset + 1] = UInt8((value >> 8) & 0xff)
        bytes[offset + 2] = UInt8((value >> 16) & 0xff)
        bytes[offset + 3] = UInt8((value >> 24) & 0xff)
    }

    bytes[0] = 0x42
    bytes[1] = 0x4d
    writeInt32(fileSize, at: 2)
    writeInt32(54, at: 10)
    writeInt32(40, at: 14)
    writeInt32(width, at: 18)
    writeInt32(height, at: 22)
    bytes[26] = 1
    bytes[28] = 24
    writeInt32(pixelSize, at: 34)

    for y in 0..<height {
        let sourceY = height - 1 - y
        for x in 0..<width {
            let source = (sourceY * width + x) * 3
            let destination = 54 + (y * rowSize) + (x * 3)
            bytes[destination] = pixels[source]
            bytes[destination + 1] = pixels[source + 1]
            bytes[destination + 2] = pixels[source + 2]
        }
    }

    let candidates = [
        URL(fileURLWithPath: Bundle.main.bundlePath).appendingPathComponent("\(name).bmp").path,
        "C:\\AIResearch\\WinChocolate\\Code\\WinChocolate\\.build\\aarch64-unknown-windows-msvc\\debug\\\(name).bmp",
        "C:\\Users\\bobby\\AppData\\Local\\Temp\\\(name).bmp"
    ]

    for path in candidates {
        let url = URL(fileURLWithPath: path)
        do {
            try Data(bytes).write(to: url)
            if (try? Data(contentsOf: url))?.isEmpty == false {
                return path
            }
        } catch {
            continue
        }
    }

    return candidates[0]
}

let demoArtworkPath = demoResourcePath(named: "WinChocolateArtworkDemo")
let demoIconPath = demoIconResourcePath()
let demoScreenArtworkPath = demoResourcePath(named: "WinChocolateScreenArtworkDemo")
let demoPngPath = demoResourcePath(named: "WinChocolatePngDemo", ofType: "png")
let toolbarOpenImagePath = demoToolbarBitmapPath(named: "ToolbarOpen", width: 58, kind: "open")
let toolbarSaveImagePath = demoToolbarBitmapPath(named: "ToolbarSave", width: 58, kind: "save")
let toolbarToggleImagePath = demoToolbarBitmapPath(named: "ToolbarToggle", width: 96, kind: "toggle")
let toolbarCustomizeImagePath = demoToolbarBitmapPath(named: "ToolbarCustomize", width: 86, kind: "customize")
var imageModeIndex = 0
let imageModes: [(NSImageView.ImageScaling, NSImageView.ImageAlignment, String, String)] = [
    (.scaleProportionallyDown, .alignCenter, demoArtworkPath, "bird center/down"),
    (.scaleProportionallyUpOrDown, .alignTopLeft, demoScreenArtworkPath, "screen top-left/fit"),
    (.scaleAxesIndependently, .alignBottomRight, demoArtworkPath, "bird bottom-right/axes"),
    (.scaleNone, .alignRight, demoScreenArtworkPath, "screen right/none"),
    (.scaleProportionallyDown, .alignCenter, demoPngPath, "png center/down")
]

final class DemoToolbarDelegate: NSToolbarDelegate {
    let allowedIdentifiers: [NSToolbarItem.Identifier]
    let defaultIdentifiers: [NSToolbarItem.Identifier]
    let itemProvider: (NSToolbarItem.Identifier) -> NSToolbarItem?

    init(
        allowedIdentifiers: [NSToolbarItem.Identifier],
        defaultIdentifiers: [NSToolbarItem.Identifier],
        itemProvider: @escaping (NSToolbarItem.Identifier) -> NSToolbarItem?
    ) {
        self.allowedIdentifiers = allowedIdentifiers
        self.defaultIdentifiers = defaultIdentifiers
        self.itemProvider = itemProvider
    }

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
        itemProvider(itemIdentifier)
    }
}

func modifierText(for event: NSEvent) -> String {
    var names: [String] = []
    if event.modifierFlags.contains(.shift) {
        names.append("shift")
    }
    if event.modifierFlags.contains(.control) {
        names.append("control")
    }
    if event.modifierFlags.contains(.option) {
        names.append("option")
    }
    if event.modifierFlags.contains(.command) {
        names.append("command")
    }
    return names.isEmpty ? "" : " [" + names.joined(separator: "+") + "]"
}

func keyName(for keyCode: UInt16) -> String? {
    switch keyCode {
    case 0x08:
        return "Backspace"
    case 0x09:
        return "Tab"
    case 0x0d:
        return "Enter"
    case 0x10:
        return "Shift"
    case 0x11:
        return "Control"
    case 0x12:
        return "Alt"
    case 0x1b:
        return "Escape"
    case 0x20:
        return "Space"
    case 0x21:
        return "Page Up"
    case 0x22:
        return "Page Down"
    case 0x23:
        return "End"
    case 0x24:
        return "Home"
    case 0x26:
        return "Up"
    case 0x28:
        return "Down"
    case 0x5b:
        return "Left Windows"
    case 0x5c:
        return "Right Windows"
    case 0xa0:
        return "Left Shift"
    case 0xa1:
        return "Right Shift"
    case 0xa2:
        return "Left Control"
    case 0xa3:
        return "Right Control"
    case 0xa4:
        return "Left Alt"
    case 0xa5:
        return "Right Alt"
    default:
        return nil
    }
}

func printableCharacterText(for event: NSEvent) -> String {
    guard let characters = event.characters, !characters.isEmpty else {
        return ""
    }

    switch characters {
    case "\t":
        return " <tab>"
    case "\n":
        return " <enter>"
    case "\u{1b}":
        return " <escape>"
    case "\u{8}":
        return " <backspace>"
    default:
        return " '\(characters)'"
    }
}

func keyText(for event: NSEvent) -> String {
    let code = event.keyCode ?? 0
    let name = keyName(for: code).map { " \($0)" } ?? ""
    return "\(code)\(name)\(printableCharacterText(for: event))\(modifierText(for: event))"
}

func tableRowSummary(_ table: NSTableView, prefix: String) -> String {
    let row = table.clickedRow
    if row >= 0,
       let name = table.value(atColumn: 0, row: row),
       let status = table.value(atColumn: 1, row: row) {
        let column = table.clickedColumn
        if column >= 0,
           let tableColumn = table.tableColumn(at: column) {
            return "\(prefix): row \(row + 1), \(tableColumn.title) - \(name) - \(status)"
        }

        return "\(prefix): row \(row + 1) - \(name) - \(status)"
    }

    return "\(prefix): no row"
}

func tableColumnSummary(_ table: NSTableView) -> String? {
    let column = table.clickedColumn
    guard table.clickedRow < 0,
          column >= 0,
          let tableColumn = table.tableColumn(at: column) else {
        return nil
    }

    return "Table column: \(tableColumn.title)"
}

func selectedTableRowValues(_ table: NSTableView) -> [String]? {
    guard table.selectedRow >= 0 else {
        return nil
    }

    let values = (0..<table.numberOfColumns).map { column in
        table.value(atColumn: column, row: table.selectedRow) ?? ""
    }
    return values.isEmpty ? nil : values
}

@discardableResult
func selectTableRow(matching values: [String], in table: NSTableView) -> Bool {
    for row in 0..<table.numberOfRows {
        let rowValues = (0..<table.numberOfColumns).map { column in
            table.value(atColumn: column, row: row) ?? ""
        }
        if rowValues == values {
            table.selectRowIndexes([row], byExtendingSelection: false)
            table.scrollRowToVisible(row)
            return true
        }
    }

    return false
}

@MainActor
func configureToolbarKeyLoop() {
    popoverButton.nextKeyView = editableTextField
    editableTextField.previousKeyView = popoverButton
}

@MainActor
func focusName() -> String {
    guard let responder = window.firstResponder else {
        return "none"
    }

    if responder === contentView {
        return "content"
    }
    if responder === editableTextField {
        return "text field"
    }
    if responder === secureTextField {
        return "secure text field"
    }
    if responder === button {
        return "click button"
    }
    if responder === enableButton {
        return "disable button"
    }
    if responder === hideButton {
        return "hide button"
    }
    if responder === moveButton {
        return "move button"
    }
    if responder === panelButton {
        return "panel button"
    }
    if responder === popoverButton {
        return "popover button"
    }
    if responder === alertButton {
        return "alert button"
    }
    if responder === titleCheckbox {
        return "title checkbox"
    }
    if responder === alertStylePopup {
        return "alert style popup"
    }
    if responder === infoRadio {
        return "info radio"
    }
    if responder === warningRadio {
        return "warning radio"
    }
    if responder === criticalRadio {
        return "critical radio"
    }
    if responder === notesTextView {
        return "notes"
    }
    if responder === tokenField {
        return "token field"
    }
    if responder === form.textField(at: 0) {
        return "form name"
    }
    if responder === form.textField(at: 1) {
        return "form status"
    }
    if responder === matrix.button(atRow: 0, column: 0) {
        return "matrix 1,1"
    }
    if responder === matrix.button(atRow: 0, column: 1) {
        return "matrix 1,2"
    }
    if responder === matrix.button(atRow: 1, column: 0) {
        return "matrix 2,1"
    }
    if responder === matrix.button(atRow: 1, column: 1) {
        return "matrix 2,2"
    }
    if responder === slider {
        return "slider"
    }
    if responder === stepper {
        return "stepper"
    }
    if responder === comboBox {
        return "combo box"
    }
    if responder === searchField {
        return "search field"
    }
    if responder === toolbarSearchField {
        return "toolbar search"
    }
    if responder === levelIndicator {
        return "level indicator"
    }
    if responder === colorWell {
        return "color well"
    }
    if responder === segmentedControl {
        return "segments"
    }
    if responder === scroller {
        return "scroller"
    }
    if responder === datePicker {
        return "date picker"
    }
    if responder === clipHomeButton {
        return "clip home"
    }
    if responder === clipCenterButton {
        return "clip center"
    }
    if responder === clipCornerButton {
        return "clip corner"
    }
    if responder === pathControl {
        return "path control"
    }
    if responder === collectionView {
        return "collection view"
    }
    if responder === visualEffectButton {
        return "visual effect button"
    }
    if responder === scrollSelectedButton {
        return "scroll selected"
    }
    if responder === pageSelector {
        return "page selector"
    }
    if responder === tableView {
        return "table view"
    }
    if responder === outlineView {
        return "outline view"
    }
    return "view"
}

@MainActor
func updateFocusDisplay() {
    let name = focusName()
    focusLabel.stringValue = "Focus: \(name)"
    contentView.backgroundColor = name == "content" ? contentFocusColor : normalContentColor
    editableTextField.backgroundColor = name == "text field"
        ? controlFocusColor
        : normalTextFieldColor
    secureTextField.backgroundColor = name == "secure text field"
        ? controlFocusColor
        : normalTextFieldColor
    searchField.backgroundColor = name == "search field"
        ? controlFocusColor
        : normalTextFieldColor
    tokenField.backgroundColor = name == "token field"
        ? controlFocusColor
        : normalTextFieldColor
    pathControl.backgroundColor = name == "path control"
        ? controlFocusColor
        : normalTextFieldColor
}

contentView.backgroundColor = normalContentColor
counterLabel.font = NSFont.boldSystemFont(ofSize: 14)
counterLabel.textColor = .green
statusLabel.font = NSFont.systemFont(ofSize: 13)
statusLabel.textColor = .blue
statusLabel.backgroundColor = NSColor(calibratedRed: 0.94, green: 0.97, blue: 1.0, alpha: 1.0)
focusLabel.font = NSFont.boldSystemFont(ofSize: 12)
focusLabel.textColor = .black
focusLabel.backgroundColor = NSColor(calibratedRed: 1.0, green: 0.98, blue: 0.86, alpha: 1.0)
slider.frame = NSMakeRect(120, 28, 184, 28)
sliderLabel.font = NSFont.boldSystemFont(ofSize: 12)
sliderValueLabel.textColor = .blue
progressLabel.font = NSFont.boldSystemFont(ofSize: 12)
progressIndicator.minValue = 0
progressIndicator.maxValue = 100
progressIndicator.doubleValue = slider.doubleValue
stepperLabel.font = NSFont.boldSystemFont(ofSize: 12)
stepper.minValue = 0
stepper.maxValue = 100
stepper.increment = 1
stepper.doubleValue = 50
stepperValueLabel.textColor = .blue
comboLabel.font = NSFont.boldSystemFont(ofSize: 12)
comboBox.addItems(withObjectValues: ["Cocoa", "AppKit", "WinChocolate", "Windows", "Wingding"])
comboBox.completes = true
comboBox.numberOfVisibleItems = 8
comboBox.stringValue = "WinChocolate"

// 3.1 depth on the Values page: slider tick marks, a vertical slider,
// and a right-aligned editable field with a placeholder.
slider.numberOfTickMarks = 11
// Placed in the open right-hand column so it clears the Progress/Stepper rows.
verticalSlider.frame = NSMakeRect(612, 56, 26, 150)
verticalSlider.isVertical = true
verticalSlider.numberOfTickMarks = 6
verticalSlider.allowsTickMarkValuesOnly = true
editableTextField.placeholderString = "Type here…"
editableTextField.alignment = .right
searchLabel.font = NSFont.boldSystemFont(ofSize: 12)
searchField.placeholderString = "Find controls"
levelLabel.font = NSFont.boldSystemFont(ofSize: 12)
levelIndicator.minValue = 0
levelIndicator.maxValue = 100
levelIndicator.warningValue = 70
levelIndicator.criticalValue = 90
levelIndicator.doubleValue = stepper.doubleValue
levelIndicator.isEditable = true
colorWellLabel.font = NSFont.boldSystemFont(ofSize: 12)
colorWell.color = demoColors[colorIndex]
segmentedLabel.font = NSFont.boldSystemFont(ofSize: 12)
segmentedControl.selectedSegment = 0
scrollerLabel.font = NSFont.boldSystemFont(ofSize: 12)
scroller.doubleValue = 0
scroller.knobProportion = 0.25
scrollerValueLabel.textColor = .blue
dateLabel.font = NSFont.boldSystemFont(ofSize: 12)
datePicker.minDate = Date(timeIntervalSince1970: 1_735_689_600)
datePicker.maxDate = Date(timeIntervalSince1970: 1_893_456_000)
// Show both date and time fields (3.1 datePickerElements).
datePicker.datePickerElements = [.yearMonthDay, .hourMinuteSecond]
dateValueLabel.textColor = .blue
dateValueLabel.stringValue = datePicker.stringValue
pageSelector.addItems(withTitles: ["Controls", "Values", "Tables/Media", "Drawing", "New in 3.x", "Lists (5.x)"])
imageLabel.font = NSFont.boldSystemFont(ofSize: 12)
imageView.image = NSImage(contentsOfFile: demoArtworkPath) ?? NSImage(named: "WinChocolate artwork")
imageView.imageFrameStyle = .grayBezel
clipLabel.font = NSFont.boldSystemFont(ofSize: 12)
clipOriginLabel.textColor = .blue
clipView.backgroundColor = .white
clipDocumentView.backgroundColor = NSColor(calibratedRed: 0.97, green: 0.97, blue: 0.97, alpha: 1.0)
clipTopLeftPane.backgroundColor = NSColor(calibratedRed: 0.84, green: 0.92, blue: 1.0, alpha: 1.0)
clipTopRightPane.backgroundColor = NSColor(calibratedRed: 1.0, green: 0.94, blue: 0.72, alpha: 1.0)
clipBottomLeftPane.backgroundColor = NSColor(calibratedRed: 0.86, green: 1.0, blue: 0.86, alpha: 1.0)
clipBottomRightPane.backgroundColor = NSColor(calibratedRed: 1.0, green: 0.86, blue: 0.88, alpha: 1.0)
clipDocumentView.addSubview(clipTopLeftPane)
clipDocumentView.addSubview(clipTopRightPane)
clipDocumentView.addSubview(clipBottomLeftPane)
clipDocumentView.addSubview(clipBottomRightPane)
clipDocumentView.addSubview(clipTopLeftLabel)
clipDocumentView.addSubview(clipTopRightLabel)
clipDocumentView.addSubview(clipBottomLeftLabel)
clipDocumentView.addSubview(clipBottomRightLabel)
clipView.documentView = clipDocumentView
splitLabel.font = NSFont.boldSystemFont(ofSize: 12)
splitLeftPane.backgroundColor = NSColor(calibratedRed: 0.86, green: 0.93, blue: 1.0, alpha: 1.0)
splitRightPane.backgroundColor = NSColor(calibratedRed: 1.0, green: 0.92, blue: 0.84, alpha: 1.0)
splitView.addSubview(splitLeftPane)
splitView.addSubview(splitRightPane)
splitView.setPosition(70, ofDividerAt: 0)
splitView.delegate = demoSplitDelegate
demoSplitDelegate.onResize = {
    statusLabel.stringValue = "Split resized: left pane \(Int(splitLeftPane.frame.size.width))px"
}
notesLabel.font = NSFont.boldSystemFont(ofSize: 12)
secureLabel.font = NSFont.boldSystemFont(ofSize: 12)
notesTextView.isRichText = true
notesTextView.string = "Multiline NSTextView"
tokenLabel.font = NSFont.boldSystemFont(ofSize: 12)
formLabel.font = NSFont.boldSystemFont(ofSize: 12)
form.titleWidth = 72
let formNameCell = form.addEntry("Name:")
let formStatusCell = form.addEntry("Status:")
formNameCell.stringValue = "WinChocolate"
formStatusCell.stringValue = "Native"
form.setStringValue(formNameCell.stringValue, at: 0)
form.setStringValue(formStatusCell.stringValue, at: 1)
matrixLabel.font = NSFont.boldSystemFont(ofSize: 12)
matrix.cellSize = NSMakeSize(104, 28)
matrix.intercellSpacing = NSMakeSize(8, 8)
matrix.selectCell(atRow: 0, column: 0)
pathLabel.font = NSFont.boldSystemFont(ofSize: 12)
collectionLabel.font = NSFont.boldSystemFont(ofSize: 12)
collectionView.dataSource = collectionDataSource
// Drive the collection with a real flow layout (5.4).
let collectionFlowLayout = NSCollectionViewFlowLayout()
collectionFlowLayout.itemSize = NSMakeSize(116, 28)
collectionFlowLayout.minimumInteritemSpacing = 8
collectionFlowLayout.minimumLineSpacing = 8
collectionFlowLayout.sectionInset = NSEdgeInsetsMake(4, 4, 4, 4)
collectionView.collectionViewLayout = collectionFlowLayout
collectionView.reloadData()
visualEffectLabel.font = NSFont.boldSystemFont(ofSize: 12)
visualEffectView.material = visualEffectMaterials[visualEffectIndex].0
visualEffectView.blendingMode = .withinWindow
visualEffectView.state = .active
visualEffectView.addSubview(visualEffectTitle)
visualEffectView.addSubview(visualEffectButton)
openToolbarItem.label = "Open"
openToolbarItem.paletteLabel = "Open"
openToolbarItem.toolTip = "Toolbar open item"
openToolbarItem.image = NSImage(contentsOfFile: toolbarOpenImagePath) ?? NSImage(systemSymbolName: "folder", accessibilityDescription: "Open")
openToolbarItem.minSize = NSMakeSize(58, 34)
openToolbarItem.maxSize = NSMakeSize(58, 34)
saveToolbarItem.label = "Save"
saveToolbarItem.paletteLabel = "Save"
saveToolbarItem.toolTip = "Toolbar save item"
saveToolbarItem.image = NSImage(contentsOfFile: toolbarSaveImagePath) ?? NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: "Save")
saveToolbarItem.minSize = NSMakeSize(58, 34)
saveToolbarItem.maxSize = NSMakeSize(58, 34)
toggleToolbarItem.label = "Disable Save"
toggleToolbarItem.paletteLabel = "Toggle Toolbar"
toggleToolbarItem.toolTip = "Enable or disable the Save toolbar item"
toggleToolbarItem.image = NSImage(contentsOfFile: toolbarToggleImagePath) ?? NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Toggle Save")
toggleToolbarItem.minSize = NSMakeSize(96, 34)
toggleToolbarItem.maxSize = NSMakeSize(96, 34)
customizeToolbarItem.label = "Customize"
customizeToolbarItem.paletteLabel = "Customize Toolbar"
customizeToolbarItem.toolTip = "Customize the toolbar"
customizeToolbarItem.image = NSImage(contentsOfFile: toolbarCustomizeImagePath) ?? NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: "Customize Toolbar")
customizeToolbarItem.minSize = NSMakeSize(86, 34)
customizeToolbarItem.maxSize = NSMakeSize(86, 34)
pageToolbarItem.label = "Page"
pageToolbarItem.paletteLabel = "Page Selector"
pageToolbarItem.toolTip = "Choose the demo page"
pageToolbarItem.view = pageSelector
pageToolbarItem.minSize = NSMakeSize(168, 28)
pageToolbarItem.maxSize = NSMakeSize(168, 28)
toolbarSearchField.sendsSearchStringImmediately = true
searchToolbarItem.label = "Search"
searchToolbarItem.paletteLabel = "Search"
searchToolbarItem.toolTip = "Search from the toolbar"
searchToolbarItem.view = toolbarSearchField
searchToolbarItem.minSize = NSMakeSize(160, 24)
searchToolbarItem.maxSize = NSMakeSize(160, 24)
let demoToolbarDelegate = DemoToolbarDelegate(
    allowedIdentifiers: [
        "open",
        "save",
        "pageSelector",
        "toolbarSearch",
        .separator,
        .flexibleSpace,
        "toggleToolbar",
        "customizeToolbar"
    ],
    defaultIdentifiers: [
        "open",
        "save",
        "pageSelector",
        "toolbarSearch",
        .separator,
        .flexibleSpace,
        "toggleToolbar",
        "customizeToolbar"
    ],
    itemProvider: { identifier in
        switch identifier.rawValue {
        case "open":
            return openToolbarItem
        case "save":
            return saveToolbarItem
        case "pageSelector":
            return pageToolbarItem
        case "toolbarSearch":
            return searchToolbarItem
        case NSToolbarItem.Identifier.separator.rawValue:
            return toolbarSeparatorItem
        case NSToolbarItem.Identifier.flexibleSpace.rawValue:
            return toolbarFlexibleSpaceItem
        case "toggleToolbar":
            return toggleToolbarItem
        case "customizeToolbar":
            return customizeToolbarItem
        default:
            return nil
        }
    }
)
demoToolbar.displayMode = .iconAndLabel
demoToolbar.allowsUserCustomization = true
demoToolbar.delegate = demoToolbarDelegate
demoToolbar.addItem(openToolbarItem)
demoToolbar.addItem(saveToolbarItem)
demoToolbar.addItem(pageToolbarItem)
demoToolbar.addItem(searchToolbarItem)
demoToolbar.addItem(toolbarSeparatorItem)
demoToolbar.addItem(toolbarFlexibleSpaceItem)
demoToolbar.addItem(toggleToolbarItem)
demoToolbar.addItem(customizeToolbarItem)
window.toolbar = demoToolbar
contentView.onBlankAreaMouseDown = { event in
    updateFocusDisplay()
}
contentView.onBlankAreaMouseUp = { event in
    statusLabel.stringValue = "Mouse up at \(Int(event.locationInWindow.x)), \(Int(event.locationInWindow.y))\(modifierText(for: event))"
}
// Keep mouse-move dispatch wired in the framework, but leave demo status quiet
// unless we are actively testing mouse movement.
contentView.onMouseMoved = nil
contentView.onKeyDown = { event in
    if event.keyCode == 0x09 {
        if event.modifierFlags.contains(.shift) {
            window.selectPreviousKeyView(nil)
        } else {
            window.selectNextKeyView(nil)
        }
        updateFocusDisplay()
        statusLabel.stringValue = "Focus moved with Tab"
        return
    }

    statusLabel.stringValue = "Key down: \(keyText(for: event))"
}
contentView.onKeyUp = { event in
    if event.keyCode == 0x09 {
        return
    }

    statusLabel.stringValue = "Key up: \(keyText(for: event))"
}

@MainActor
func showDemoPage(_ index: Int) {
    controlsPage.isHidden = index != 0
    valuesPage.isHidden = index != 1
    tablesPage.isHidden = index != 2
    drawingPage.isHidden = index != 3
    showcasePage.isHidden = index != 4
    listsPage.isHidden = index != 5
    updateFocusDisplay()
}

titleCheckbox.setButtonType(.switchButton)
titleCheckbox.state = .on
infoRadio.setButtonType(.radioButton)
warningRadio.setButtonType(.radioButton)
criticalRadio.setButtonType(.radioButton)
infoRadio.state = .on
alertStylePopup.addItems(withTitles: ["Info", "Warning", "Critical"])
// Tag each style so the alert can read the choice by tag, not title.
alertStylePopup.setTag(0, forItemAt: 0)
alertStylePopup.setTag(1, forItemAt: 1)
alertStylePopup.setTag(2, forItemAt: 2)
alertStylePopup.selectItem(withTitle: "Info")
let tableNameColumn = NSTableColumn(identifier: "name")
let tableStatusColumn = NSTableColumn(identifier: "status")
tableNameColumn.title = "Name"
tableStatusColumn.title = "Status"
tableNameColumn.width = 250
tableStatusColumn.width = 240
tableNameColumn.sortDescriptorPrototype = NSSortDescriptor(key: "name", ascending: true)
tableStatusColumn.sortDescriptorPrototype = NSSortDescriptor(key: "status", ascending: true)
tableView.addTableColumn(tableNameColumn)
tableView.addTableColumn(tableStatusColumn)
tableView.dataSource = tableDataSource
tableView.allowsColumnSelection = true
tableView.reloadData()
tableView.selectRowIndexes([0], byExtendingSelection: false)
tableView.selectColumnIndexes([0], byExtendingSelection: false)
tableScrollView.hasVerticalScroller = true
tableScrollView.documentView = tableView
outlineLabel.font = NSFont.boldSystemFont(ofSize: 12)
let outlineNameColumn = NSTableColumn(identifier: "outlineName")
let outlineStatusColumn = NSTableColumn(identifier: "outlineStatus")
outlineNameColumn.title = "Item"
outlineStatusColumn.title = "Kind"
outlineNameColumn.width = 160
outlineStatusColumn.width = 88
outlineView.addTableColumn(outlineNameColumn)
outlineView.addTableColumn(outlineStatusColumn)
outlineView.outlineDataSource = outlineDataSource
outlineView.expandItem("Application")
outlineView.expandItem("Controls")
outlineView.reloadData()
outlineView.selectRowIndexes([0], byExtendingSelection: false)
outlineScrollView.hasVerticalScroller = true
outlineScrollView.documentView = outlineView
contentView.nextKeyView = button
editableTextField.nextKeyView = secureTextField
secureTextField.nextKeyView = alertButton
button.nextKeyView = enableButton
enableButton.nextKeyView = hideButton
hideButton.nextKeyView = moveButton
moveButton.nextKeyView = panelButton
panelButton.nextKeyView = popoverButton
popoverButton.nextKeyView = editableTextField
alertButton.nextKeyView = titleCheckbox
titleCheckbox.nextKeyView = alertStylePopup
alertStylePopup.nextKeyView = infoRadio
infoRadio.nextKeyView = warningRadio
warningRadio.nextKeyView = criticalRadio
criticalRadio.nextKeyView = notesTextView
notesTextView.nextKeyView = tokenField
tokenField.nextKeyView = form.textField(at: 0)
form.textField(at: 0)?.nextKeyView = form.textField(at: 1)
form.textField(at: 1)?.nextKeyView = matrix.button(atRow: 0, column: 0)
matrix.button(atRow: 0, column: 0)?.nextKeyView = matrix.button(atRow: 0, column: 1)
matrix.button(atRow: 0, column: 1)?.nextKeyView = matrix.button(atRow: 1, column: 0)
matrix.button(atRow: 1, column: 0)?.nextKeyView = matrix.button(atRow: 1, column: 1)
matrix.button(atRow: 1, column: 1)?.nextKeyView = slider
slider.nextKeyView = stepper
stepper.nextKeyView = comboBox
comboBox.nextKeyView = searchField
searchField.nextKeyView = levelIndicator
levelIndicator.nextKeyView = colorWell
colorWell.nextKeyView = segmentedControl
segmentedControl.nextKeyView = scroller
scroller.nextKeyView = datePicker
datePicker.nextKeyView = pageSelector
pageSelector.nextKeyView = toolbarSearchField
toolbarSearchField.nextKeyView = clipHomeButton
clipHomeButton.nextKeyView = clipCenterButton
clipCenterButton.nextKeyView = clipCornerButton
clipCornerButton.nextKeyView = pathControl
pathControl.nextKeyView = collectionView
collectionView.nextKeyView = scrollSelectedButton
scrollSelectedButton.nextKeyView = tableView
tableView.nextKeyView = outlineView
outlineView.nextKeyView = contentView

contentView.previousKeyView = outlineView
outlineView.previousKeyView = tableView
tableView.previousKeyView = scrollSelectedButton
scrollSelectedButton.previousKeyView = collectionView
collectionView.previousKeyView = pathControl
pathControl.previousKeyView = clipCornerButton
clipCornerButton.previousKeyView = clipCenterButton
clipCenterButton.previousKeyView = clipHomeButton
clipHomeButton.previousKeyView = toolbarSearchField
toolbarSearchField.previousKeyView = pageSelector
pageSelector.previousKeyView = datePicker
datePicker.previousKeyView = scroller
scroller.previousKeyView = segmentedControl
segmentedControl.previousKeyView = colorWell
colorWell.previousKeyView = levelIndicator
levelIndicator.previousKeyView = searchField
searchField.previousKeyView = comboBox
comboBox.previousKeyView = stepper
stepper.previousKeyView = slider
slider.previousKeyView = matrix.button(atRow: 1, column: 1)
matrix.button(atRow: 1, column: 1)?.previousKeyView = matrix.button(atRow: 1, column: 0)
matrix.button(atRow: 1, column: 0)?.previousKeyView = matrix.button(atRow: 0, column: 1)
matrix.button(atRow: 0, column: 1)?.previousKeyView = matrix.button(atRow: 0, column: 0)
matrix.button(atRow: 0, column: 0)?.previousKeyView = form.textField(at: 1)
form.textField(at: 1)?.previousKeyView = form.textField(at: 0)
form.textField(at: 0)?.previousKeyView = tokenField
tokenField.previousKeyView = notesTextView
notesTextView.previousKeyView = criticalRadio
criticalRadio.previousKeyView = warningRadio
warningRadio.previousKeyView = infoRadio
infoRadio.previousKeyView = alertStylePopup
alertStylePopup.previousKeyView = titleCheckbox
titleCheckbox.previousKeyView = alertButton
alertButton.previousKeyView = secureTextField
moveButton.previousKeyView = hideButton
hideButton.previousKeyView = enableButton
enableButton.previousKeyView = button
button.previousKeyView = contentView
secureTextField.previousKeyView = editableTextField
editableTextField.previousKeyView = popoverButton
popoverButton.previousKeyView = panelButton
panelButton.previousKeyView = moveButton
configureToolbarKeyLoop()

editableTextField.isEditable = true
editableTextField.onTextChanged = { field in
    updateFocusDisplay()
    statusLabel.stringValue = field.stringValue.isEmpty
        ? "Edit field cleared"
        : "Typed: \(field.stringValue)"
}
// NSTextFieldDelegate begin/end editing on focus, shown in the status line.
let editableFieldDelegate = DemoFieldDelegate()
editableFieldDelegate.onBegin = { statusLabel.stringValue = "Began editing field" }
editableFieldDelegate.onEnd = { statusLabel.stringValue = "Ended editing field" }
editableTextField.delegate = editableFieldDelegate

secureTextField.onTextChanged = { field in
    updateFocusDisplay()
    statusLabel.stringValue = "Password length: \(field.stringValue.count)"
}

comboBox.onComboBoxTextChanged = { combo in
    updateFocusDisplay()
    statusLabel.stringValue = "Combo typed: \(combo.stringValue)"
}
comboBox.onAction = { control in
    guard let combo = control as? NSComboBox else {
        return
    }

    updateFocusDisplay()
    statusLabel.stringValue = "Combo selected: \(combo.stringValue)"
}

searchField.onAction = { control in
    guard let searchField = control as? NSSearchField else {
        return
    }

    updateFocusDisplay()
    statusLabel.stringValue = searchField.stringValue.isEmpty
        ? "Search cleared"
        : "Search: \(searchField.stringValue)"
}

levelIndicator.onAction = { control in
    guard let level = control as? NSLevelIndicator else {
        return
    }

    updateFocusDisplay()
    statusLabel.stringValue = "Level value: \(level.intValue)"
}

colorWell.onAction = { _ in
    updateFocusDisplay()
    // Clicking presents the shared color panel; report and reflect picks on
    // this well's swatch.
    let panel = NSColorPanel.shared
    panel.winColorDidChange = { color in
        colorWell.color = color
        statusLabel.stringValue = "Color well changed: RGB \(Int(color.redComponent * 255)), \(Int(color.greenComponent * 255)), \(Int(color.blueComponent * 255))"
    }
    colorWell.activate(true)
    panel.makeKeyAndOrderFront(colorWell)
}

pathControl.onAction = { control in
    guard let path = control as? NSPathControl else {
        return
    }

    statusLabel.stringValue = "Path clicked: \(path.clickedPathComponentCell?.title ?? "?")"
}

fontButton.onAction = { _ in
    updateFocusDisplay()
    let manager = NSFontManager.shared
    manager.winFontDidChange = { font in
        let weight = font.weight == .bold ? " bold" : ""
        statusLabel.stringValue = "Font chosen: \(font.fontName) \(Int(font.pointSize))pt\(weight)"
    }
    manager.orderFrontFontPanel(fontButton)
}

segmentedControl.onAction = { control in
    guard let segmentedControl = control as? NSSegmentedControl else {
        return
    }

    updateFocusDisplay()
    let index = segmentedControl.selectedSegment
    let label = segmentedControl.label(forSegment: index) ?? "none"
    statusLabel.stringValue = "Segment selected: \(label)"
}

scroller.onAction = { control in
    guard let scroller = control as? NSScroller else {
        return
    }

    updateFocusDisplay()
    let percent = Int((scroller.doubleValue * 100).rounded())
    scrollerValueLabel.stringValue = "\(percent)"
    statusLabel.stringValue = "Scroller value: \(percent)%"
}

datePicker.onAction = { control in
    guard let picker = control as? NSDatePicker else {
        return
    }

    updateFocusDisplay()
    dateValueLabel.stringValue = picker.stringValue
    statusLabel.stringValue = "Date picked: \(picker.stringValue)"
}

calendarPicker.onAction = { control in
    guard let picker = control as? NSDatePicker else {
        return
    }

    dateValueLabel.stringValue = picker.stringValue
    statusLabel.stringValue = "Calendar picked: \(picker.stringValue)"
}

pageSelector.onAction = { control in
    guard let selector = control as? NSPopUpButton else {
        return
    }

    showDemoPage(selector.indexOfSelectedItem)
    updateFocusDisplay()
    statusLabel.stringValue = "Page selected: \(selector.titleOfSelectedItem ?? "none")"
}

toolbarSearchField.onAction = { control in
    guard let searchField = control as? NSSearchField else {
        return
    }

    updateFocusDisplay()
    statusLabel.stringValue = searchField.stringValue.isEmpty
        ? "Toolbar search cleared"
        : "Toolbar search: \(searchField.stringValue)"
}

imageView.onAction = { _ in
    updateFocusDisplay()
    imageModeIndex = (imageModeIndex + 1) % imageModes.count
    let mode = imageModes[imageModeIndex]
    imageView.imageScaling = mode.0
    imageView.imageAlignment = mode.1
    imageView.image = NSImage(contentsOfFile: mode.2) ?? NSImage(named: mode.2)
    statusLabel.stringValue = "Image mode: \(mode.3)"
}

@MainActor
func scrollClipDemo(to origin: NSPoint, name: String) {
    clipView.scroll(to: origin)
    let visible = clipView.documentVisibleRect
    clipOriginLabel.stringValue = "origin \(Int(visible.origin.x)),\(Int(visible.origin.y))"
    updateFocusDisplay()
    statusLabel.stringValue = "Clip view: \(name) visible \(Int(visible.origin.x)),\(Int(visible.origin.y))"
}

clipHomeButton.onAction = { _ in
    scrollClipDemo(to: NSMakePoint(0, 0), name: "home")
}

clipCenterButton.onAction = { _ in
    scrollClipDemo(to: NSMakePoint(100, 55), name: "center")
}

clipCornerButton.onAction = { _ in
    scrollClipDemo(to: NSMakePoint(220, 110), name: "corner")
}

notesTextView.onTextChanged = { textView in
    updateFocusDisplay()
    statusLabel.stringValue = "Notes length: \(textView.string.count)"
}

selectWordButton.onAction = { _ in
    if notesTextView.string.isEmpty {
        notesTextView.insertText("WinChocolate Notes", replacementRange: NSMakeRange(NSNotFound, 0))
    }

    _ = window.makeFirstResponder(notesTextView)
    let firstWordLength = notesTextView.string.utf16.prefix { $0 != 32 }.count
    let selection = NSMakeRange(0, firstWordLength)
    // Rich text through the text storage: the styled word round-trips to
    // the native peer, and Edit > Copy stages RTF alongside the string.
    if let storage = notesTextView.textStorage {
        storage.beginEditing()
        storage.addAttribute(.font, value: NSFont(name: "Georgia", size: 14, weight: .bold, italic: true), range: selection)
        storage.addAttribute(.foregroundColor, value: NSColor.blue, range: selection)
        storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: selection)
        storage.endEditing()
    }
    notesTextView.setSelectedRange(selection)
    statusLabel.stringValue = "Notes selection styled: location \(selection.location), length \(selection.length)"
}

tokenField.onTextChanged = { field in
    guard let tokenField = field as? NSTokenField else {
        return
    }

    updateFocusDisplay()
    statusLabel.stringValue = "Tokens: \(tokenField.tokens.joined(separator: " | "))"
}

form.textField(at: 0)?.onTextChanged = { field in
    formNameCell.stringValue = field.stringValue
    updateFocusDisplay()
    statusLabel.stringValue = "Form name: \(field.stringValue)"
}

form.textField(at: 1)?.onTextChanged = { field in
    formStatusCell.stringValue = field.stringValue
    updateFocusDisplay()
    statusLabel.stringValue = "Form status: \(field.stringValue)"
}

matrix.onAction = { control in
    guard let matrix = control as? NSMatrix else {
        return
    }

    updateFocusDisplay()
    statusLabel.stringValue = "Matrix selected: row \(matrix.selectedRow + 1), column \(matrix.selectedColumn + 1)"
}

button.onAction = { _ in
    updateFocusDisplay()
    clickCount += 1
    counterLabel.stringValue = "Clicks: \(clickCount)"
    if titleCheckbox.state == .on {
        window.title = "WinChocolate Click Counter (\(clickCount))"
    }
    statusLabel.stringValue = "Click button fired"
}

enableButton.onAction = { _ in
    updateFocusDisplay()
    isClickEnabled.toggle()
    button.isEnabled = isClickEnabled
    enableButton.title = isClickEnabled ? "Disable Click" : "Enable Click"
    statusLabel.stringValue = isClickEnabled ? "Click button enabled" : "Click button disabled"
}

hideButton.onAction = { _ in
    updateFocusDisplay()
    isCounterHidden.toggle()
    counterLabel.isHidden = isCounterHidden
    hideButton.title = isCounterHidden ? "Show Counter" : "Hide Counter"
    statusLabel.stringValue = isCounterHidden ? "Counter hidden" : "Counter visible"
}

moveButton.onAction = { _ in
    updateFocusDisplay()
    movedRight.toggle()
    button.frame = movedRight
        ? NSMakeRect(32, 430, 100, 34)
        : NSMakeRect(32, 24, 100, 34)
    statusLabel.stringValue = movedRight ? "Click button moved down" : "Click button moved back"
}

panelButton.onAction = { _ in
    updateFocusDisplay()
    let panel: NSPanel
    if let existing = inspectorPanel {
        panel = existing
    } else {
        let newPanel = NSPanel(
            contentRect: NSMakeRect(180, 160, 280, 140),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newPanel.title = "WinChocolate Panel"
        newPanel.isFloatingPanel = true
        newPanel.hidesOnDeactivate = true
        let panelContent = NSView(frame: NSMakeRect(0, 0, 280, 140))
        let panelTitle = NSTextField(string: "NSPanel", frame: NSMakeRect(24, 24, 120, 24))
        let panelInfo = NSTextField(string: "Floating inspector slice", frame: NSMakeRect(24, 58, 200, 24))
        panelTitle.font = NSFont.boldSystemFont(ofSize: 14)
        panelContent.addSubview(panelTitle)
        panelContent.addSubview(panelInfo)
        newPanel.contentView = panelContent
        inspectorPanel = newPanel
        panel = newPanel
    }

    panel.orderFrontRegardless()
    statusLabel.stringValue = "Panel ordered front"
}

let popoverContent = NSView(frame: NSMakeRect(0, 0, 260, 120))
let popoverTitle = NSTextField(string: "NSPopover", frame: NSMakeRect(20, 16, 120, 24))
let popoverInfo = NSTextField(string: "Borderless transient host", frame: NSMakeRect(20, 46, 200, 24))
let popoverCloseButton = NSButton(title: "Close", frame: NSMakeRect(20, 82, 80, 28))
popoverTitle.font = NSFont.boldSystemFont(ofSize: 14)
popoverContent.backgroundColor = NSColor(calibratedRed: 1.0, green: 0.94, blue: 0.84, alpha: 1.0)
popoverContent.addSubview(popoverTitle)
popoverContent.addSubview(popoverInfo)
popoverContent.addSubview(popoverCloseButton)
popover.contentSize = NSMakeSize(260, 120)
popover.behavior = .transient
popover.contentViewController = NSViewController(view: popoverContent)

popoverButton.onAction = { _ in
    updateFocusDisplay()
    if popover.isShown {
        popover.performClose(nil)
        statusLabel.stringValue = "Popover closed"
    } else {
        popover.show(relativeTo: popoverButton.bounds, of: popoverButton, preferredEdge: .maxY)
        statusLabel.stringValue = "Popover shown"
    }
}

popoverCloseButton.onAction = { _ in
    popover.performClose(nil)
    statusLabel.stringValue = "Popover close button"
}

canvasView.onEvent = { message in
    statusLabel.stringValue = message
    drawingEventLabel.stringValue = "Last canvas event: \(message)"
}

shapesScrollView.hasVerticalScroller = true
shapesScrollView.hasHorizontalScroller = true
shapesScrollView.allowsMagnification = true
shapesScrollView.documentView = shapesView

let updateShapesZoom: (CGFloat) -> Void = { magnification in
    shapesScrollView.magnification = magnification
    let rounded = (shapesScrollView.magnification * 100).rounded() / 100
    shapesZoomLabel.stringValue = "\(rounded)x"
    statusLabel.stringValue = "Paths zoom: \(rounded)x"
}

shapesZoomInButton.onAction = { _ in
    updateShapesZoom(shapesScrollView.magnification * 1.25)
}

shapesZoomOutButton.onAction = { _ in
    updateShapesZoom(shapesScrollView.magnification / 1.25)
}

shapesZoomResetButton.onAction = { _ in
    updateShapesZoom(1)
}

askToSaveButton.onAction = { _ in
    updateFocusDisplay()
    let alert = NSAlert()
    alert.messageText = "Do you want to save the changes to Untitled?"
    alert.informativeText = "Your changes will be lost if you don't save them."
    alert.addButton(withTitle: "Save")
    alert.addButton(withTitle: "Don't Save")
    alert.addButton(withTitle: "Cancel")
    alert.showsSuppressionButton = true

    let accessoryLabel = NSTextField(string: "Accessory views work", frame: NSMakeRect(0, 0, 240, 20))
    accessoryLabel.isBordered = false
    accessoryLabel.drawsBackground = false
    alert.accessoryView = accessoryLabel

    alert.beginSheetModal(for: window) { response in
        let choice: String
        switch response {
        case .alertFirstButtonReturn:
            choice = "Save"
        case .alertSecondButtonReturn:
            choice = "Don't Save"
        case .alertThirdButtonReturn:
            choice = "Cancel"
        default:
            choice = "Dismissed"
        }
        let suppressed = alert.suppressionButton?.state == .on ? ", don't ask again" : ""
        statusLabel.stringValue = "Ask to Save: \(choice)\(suppressed)"
    }
}

openToolbarItem.onAction = { _ in
    updateFocusDisplay()
    let panel = NSOpenPanel.openPanel()
    panel.title = "Open Demo File"
    panel.allowsMultipleSelection = true
    panel.beginSheetModal(for: window) { response in
        if response == .OK {
            let names = panel.urls.map(\.lastPathComponent).joined(separator: ", ")
            statusLabel.stringValue = "Open: \(names)"
        } else {
            statusLabel.stringValue = "Open cancelled"
        }
    }
}
saveToolbarItem.onAction = { _ in
    updateFocusDisplay()
    let panel = NSSavePanel.savePanel()
    panel.title = "Save Demo File"
    panel.nameFieldStringValue = "Untitled.txt"
    panel.allowedFileTypes = ["txt"]
    panel.allowsOtherFileTypes = true
    panel.beginSheetModal(for: window) { response in
        if response == .OK, let url = panel.url {
            statusLabel.stringValue = "Save: \(url.lastPathComponent)"
        } else {
            statusLabel.stringValue = "Save cancelled"
        }
    }
}
toggleToolbarItem.onAction = { _ in
    updateFocusDisplay()
    saveToolbarItem.isEnabled.toggle()
    toggleToolbarItem.label = saveToolbarItem.isEnabled ? "Disable Save" : "Enable Save"
    demoToolbar.validateVisibleItems()
    statusLabel.stringValue = saveToolbarItem.isEnabled ? "Toolbar Save enabled" : "Toolbar Save disabled"
}
customizeToolbarItem.onAction = { _ in
    updateFocusDisplay()
    demoToolbar.runCustomizationPalette(nil)
    statusLabel.stringValue = "Toolbar customization opened"
}

alertButton.onAction = { _ in
    updateFocusDisplay()
    let alert = NSAlert()
    alert.messageText = "WinChocolate is running"
    alert.informativeText = "This composed NSAlert shows a help button; click ? for help."
    // Read the style from the popup's tag rather than its title.
    switch alertStylePopup.selectedTag() {
    case 1:
        alert.alertStyle = .warning
    case 2:
        alert.alertStyle = .critical
    default:
        alert.alertStyle = .informational
    }
    alert.showsHelp = true
    alert.winHelpButtonAction = {
        statusLabel.stringValue = "Alert help requested"
    }
    alert.addButton(withTitle: "OK")
    _ = alert.runModal()
    updateFocusDisplay()
    statusLabel.stringValue = "Alert dismissed"
}

titleCheckbox.onAction = { _ in
    updateFocusDisplay()
    statusLabel.stringValue = titleCheckbox.state == .on
        ? "Title count enabled"
        : "Title count disabled"
    if titleCheckbox.state == .off {
        window.title = "WinChocolate Click Counter"
    }
}

infoRadio.onAction = { _ in
    updateFocusDisplay()
    alertStylePopup.selectItem(withTitle: "Info")
    statusLabel.stringValue = "Alert style: info"
}

warningRadio.onAction = { _ in
    updateFocusDisplay()
    alertStylePopup.selectItem(withTitle: "Warning")
    statusLabel.stringValue = "Alert style: warning"
}

criticalRadio.onAction = { _ in
    updateFocusDisplay()
    alertStylePopup.selectItem(withTitle: "Critical")
    statusLabel.stringValue = "Alert style: critical"
}

alertStylePopup.onAction = { _ in
    updateFocusDisplay()
    let title = alertStylePopup.titleOfSelectedItem ?? "Info"
    if title == "Warning" {
        warningRadio.performClick(nil)
    } else if title == "Critical" {
        criticalRadio.performClick(nil)
    } else {
        infoRadio.performClick(nil)
    }
}

slider.onAction = { control in
    guard let slider = control as? NSSlider else {
        return
    }

    updateFocusDisplay()
    sliderValueLabel.stringValue = "\(slider.intValue)"
    progressIndicator.doubleValue = slider.doubleValue
    statusLabel.stringValue = "Slider value: \(slider.intValue)"
}

stepper.onAction = { control in
    guard let stepper = control as? NSStepper else {
        return
    }

    updateFocusDisplay()
    stepperValueLabel.stringValue = "\(stepper.intValue)"
    levelIndicator.doubleValue = stepper.doubleValue
    statusLabel.stringValue = "Stepper value: \(stepper.intValue)"
}

tableView.onSelectionChanged = { table in
    updateFocusDisplay()
    if suppressNextTableSelectionStatus {
        suppressNextTableSelectionStatus = false
        return
    }

    statusLabel.stringValue = tableRowSummary(table, prefix: "Table selected")
}
scrollSelectedButton.onAction = { _ in
    updateFocusDisplay()
    let targetRow = max(0, tableView.numberOfRows - 1)
    tableView.selectRowIndexes([targetRow], byExtendingSelection: false)
    if let nativeHandle = tableView.nativeHandle {
        NSApp.nativeBackend.scrollTableRowToVisible(targetRow, for: nativeHandle)
    }
    statusLabel.stringValue = tableRowSummary(tableView, prefix: "Scrolled to selected")
}
collectionView.onAction = { control in
    guard let collectionView = control as? NSCollectionView,
          let indexPath = collectionView.selectionIndexPaths.sorted(by: { left, right in
              if left.section == right.section {
                  return left.item < right.item
              }
              return left.section < right.section
          }).first,
          let value = collectionView.item(at: indexPath)?.representedObject else {
        return
    }

    updateFocusDisplay()
    statusLabel.stringValue = "Collection selected: \(value)"
}
visualEffectButton.onAction = { _ in
    updateFocusDisplay()
    visualEffectIndex = (visualEffectIndex + 1) % visualEffectMaterials.count
    let material = visualEffectMaterials[visualEffectIndex]
    visualEffectView.material = material.0
    visualEffectTitle.stringValue = "material: \(material.1)"
    statusLabel.stringValue = "Visual effect material: \(material.1)"
}
tableView.onAction = { control in
    guard let table = control as? NSTableView else {
        return
    }

    updateFocusDisplay()
    suppressNextTableSelectionStatus = true
    if let columnSummary = tableColumnSummary(table) {
        // The framework already applied the column's sort prototype on the
        // header click; re-sort the model with the resulting descriptor.
        if let sortDescriptor = table.sortDescriptors.first {
            let selectedValues = selectedTableRowValues(table)
            tableDataSource.sort(using: sortDescriptor)
            NSApp.nativeBackend.dispatchAsync {
                table.reloadData()
                if let selectedValues {
                    suppressNextTableSelectionStatus = selectTableRow(matching: selectedValues, in: table)
                }
            }
            statusLabel.stringValue = "\(columnSummary), sorted \(sortDescriptor.ascending ? "ascending" : "descending")"
        } else {
            statusLabel.stringValue = columnSummary
        }
        return
    }

    statusLabel.stringValue = tableColumnSummary(table) ?? tableRowSummary(table, prefix: "Table action")
}
tableView.doubleAction = "openTableRow:"
tableView.onDoubleAction = { table in
    updateFocusDisplay()
    statusLabel.stringValue = tableRowSummary(table, prefix: "Table double action")
}

outlineView.onAction = { control in
    guard let outline = control as? NSOutlineView else {
        return
    }

    updateFocusDisplay()
    let actionRow = outline.selectedRow
    guard let item = outline.item(atRow: actionRow) else {
        statusLabel.stringValue = "Outline action: none"
        return
    }

    let itemText = String(describing: item)
    let shouldExpand = outline.isItemExpandable(item)
    outline.toggleItem(item)
    if shouldExpand {
        let row = outline.row(forItem: item)
        if row >= 0 {
            outline.selectRowIndexes([row], byExtendingSelection: false)
        }
    }

    statusLabel.stringValue = shouldExpand
        ? "Outline \(outline.isItemExpanded(item) ? "expanded" : "collapsed"): \(itemText)"
        : "Outline action: \(itemText), level \(outline.level(forItem: item))"
}
outlineView.onSelectionChanged = { table in
    guard let outline = table as? NSOutlineView else {
        return
    }

    updateFocusDisplay()
    let item = outline.item(atRow: outline.selectedRow).map { String(describing: $0) } ?? "none"
    statusLabel.stringValue = "Outline selected: \(item)"
}
contentView.addSubview(counterLabel)
contentView.addSubview(statusLabel)
contentView.addSubview(focusLabel)
contentView.addSubview(controlsPage)
contentView.addSubview(valuesPage)
contentView.addSubview(tablesPage)
contentView.addSubview(drawingPage)
contentView.addSubview(showcasePage)
contentView.addSubview(listsPage)

controlsPage.addSubview(editableLabel)
controlsPage.addSubview(editableTextField)
controlsPage.addSubview(secureLabel)
controlsPage.addSubview(secureTextField)
controlsPage.addSubview(button)
controlsPage.addSubview(enableButton)
controlsPage.addSubview(hideButton)
controlsPage.addSubview(moveButton)
controlsPage.addSubview(panelButton)
controlsPage.addSubview(popoverButton)
controlsPage.addSubview(askToSaveButton)
controlsPage.addSubview(alertButton)
controlsPage.addSubview(titleCheckbox)
controlsPage.addSubview(alertStyleBox)
controlsPage.addSubview(alertStyleLabel)
controlsPage.addSubview(alertStylePopup)
controlsPage.addSubview(infoRadio)
controlsPage.addSubview(warningRadio)
controlsPage.addSubview(criticalRadio)
controlsPage.addSubview(notesLabel)
controlsPage.addSubview(notesTextView)
controlsPage.addSubview(selectWordButton)
controlsPage.addSubview(tokenLabel)
controlsPage.addSubview(tokenField)
controlsPage.addSubview(priceLabel)
controlsPage.addSubview(priceField)
controlsPage.addSubview(formLabel)
controlsPage.addSubview(form)
controlsPage.addSubview(matrixLabel)
controlsPage.addSubview(matrix)

valuesPage.addSubview(sliderLabel)
valuesPage.addSubview(slider)
valuesPage.addSubview(sliderValueLabel)
valuesPage.addSubview(verticalSliderLabel)
valuesPage.addSubview(verticalSlider)
valuesPage.addSubview(progressLabel)
valuesPage.addSubview(progressIndicator)
activityIndicator.isIndeterminate = true
activityIndicator.startAnimation(nil)
valuesPage.addSubview(activityIndicator)
valuesPage.addSubview(stepperLabel)
valuesPage.addSubview(stepper)
valuesPage.addSubview(stepperValueLabel)
valuesPage.addSubview(comboLabel)
valuesPage.addSubview(comboBox)
valuesPage.addSubview(searchLabel)
valuesPage.addSubview(searchField)
valuesPage.addSubview(levelLabel)
valuesPage.addSubview(levelIndicator)
valuesPage.addSubview(colorWellLabel)
valuesPage.addSubview(colorWell)
valuesPage.addSubview(fontButton)
valuesPage.addSubview(segmentedLabel)
valuesPage.addSubview(segmentedControl)
valuesPage.addSubview(scrollerLabel)
valuesPage.addSubview(scroller)
valuesPage.addSubview(scrollerValueLabel)
valuesPage.addSubview(dateLabel)
valuesPage.addSubview(datePicker)
valuesPage.addSubview(dateValueLabel)
valuesPage.addSubview(calendarLabel)
valuesPage.addSubview(calendarPicker)
valuesPage.addSubview(ratingLabel)
valuesPage.addSubview(ratingIndicator)
valuesPage.addSubview(timerTickLabel)

// A repeating run-loop Timer ticking the label once per second.
var timerTicks = 0
Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
    timerTicks += 1
    timerTickLabel.stringValue = "Timer: \(timerTicks)s"
}

drawingPage.addSubview(canvasLabel)
drawingPage.addSubview(canvasView)
drawingPage.addSubview(canvasHintLabel)
drawingPage.addSubview(drawingEventLabel)
drawingPage.addSubview(shapesLabel)
drawingPage.addSubview(shapesScrollView)
drawingPage.addSubview(shapesZoomInButton)
drawingPage.addSubview(shapesZoomOutButton)
drawingPage.addSubview(shapesZoomResetButton)
drawingPage.addSubview(shapesZoomLabel)
drawingPage.addSubview(gradientsLabel)
drawingPage.addSubview(gradientsView)

tablesPage.addSubview(imageLabel)
tablesPage.addSubview(imageView)
tablesPage.addSubview(clipLabel)
tablesPage.addSubview(clipView)
tablesPage.addSubview(clipOriginLabel)
tablesPage.addSubview(clipHomeButton)
tablesPage.addSubview(clipCenterButton)
tablesPage.addSubview(clipCornerButton)
tablesPage.addSubview(pathLabel)
tablesPage.addSubview(pathControl)
tablesPage.addSubview(collectionLabel)
tablesPage.addSubview(collectionView)
tablesPage.addSubview(visualEffectLabel)
tablesPage.addSubview(visualEffectView)
tablesPage.addSubview(splitLabel)
tablesPage.addSubview(splitView)
tablesPage.addSubview(tableLabel)
tablesPage.addSubview(scrollSelectedButton)
tablesPage.addSubview(tableScrollView)
tablesPage.addSubview(outlineLabel)
tablesPage.addSubview(outlineScrollView)

// MARK: - "New in 3.x" showcase page

@MainActor
func showcaseSectionLabel(_ text: String, _ frame: NSRect) -> NSTextField {
    let label = NSTextField(string: text, frame: frame)
    label.isBordered = false
    label.drawsBackground = false
    label.font = NSFont.boldSystemFont(ofSize: 13)
    return label
}

// 3.12 — framework-drawn spinner.
let spinnerSectionLabel = showcaseSectionLabel("Spinner (3.12)", NSMakeRect(24, 16, 320, 20))
let showcaseSpinner = NSProgressIndicator(frame: NSMakeRect(24, 44, 40, 40))
showcaseSpinner.style = .spinning
showcaseSpinner.startAnimation(nil)
let spinnerStartButton = NSButton(title: "Start", frame: NSMakeRect(76, 48, 72, 30))
let spinnerStopButton = NSButton(title: "Stop", frame: NSMakeRect(152, 48, 72, 30))
spinnerStartButton.onAction = { _ in
    showcaseSpinner.startAnimation(nil)
    statusLabel.stringValue = "Spinner animating"
}
spinnerStopButton.onAction = { _ in
    showcaseSpinner.stopAnimation(nil)
    statusLabel.stringValue = "Spinner stopped"
}

// 3.13 — template image tinting.
let templateSectionLabel = showcaseSectionLabel("Template image tint (3.13)", NSMakeRect(24, 100, 320, 20))
let templateImageView = NSImageView(frame: NSMakeRect(24, 128, 48, 48))
let templateImage = NSImage(contentsOfFile: demoIconPath)
templateImage?.isTemplate = true
templateImageView.image = templateImage
templateImageView.contentTintColor = .systemBlue
let templateTintWell = NSColorWell(frame: NSMakeRect(84, 134, 44, 36))
templateTintWell.color = .systemBlue
templateTintWell.onAction = { _ in
    // Clicking presents the shared color panel. As its selection changes,
    // update this well's own swatch and re-tint the glyph.
    let panel = NSColorPanel.shared
    panel.winColorDidChange = { color in
        templateTintWell.color = color
        templateImageView.contentTintColor = color
        statusLabel.stringValue = "Template tint changed"
    }
    templateTintWell.activate(true)
    panel.makeKeyAndOrderFront(templateTintWell)
}
let templateHintLabel = NSTextField(string: "The glyph takes the well's color.", frame: NSMakeRect(140, 140, 240, 20))
templateHintLabel.isBordered = false
templateHintLabel.drawsBackground = false
templateHintLabel.font = NSFont.systemFont(ofSize: 11)

// 3.21 — hover tracking.
let hoverSectionLabel = showcaseSectionLabel("Hover tracking (3.21)", NSMakeRect(24, 196, 320, 20))
let showcaseHoverView = DemoHoverView(frame: NSMakeRect(24, 224, 200, 44))
showcaseHoverView.onEvent = { statusLabel.stringValue = $0 }

// 3.18 — drag and drop.
let dragSectionLabel = showcaseSectionLabel("Drag and drop (3.18)", NSMakeRect(400, 16, 360, 20))
let showcaseDragHandle = DemoDragHandle(frame: NSMakeRect(400, 44, 150, 40))
showcaseDragHandle.onEvent = { statusLabel.stringValue = $0 }
let showcaseDropWell = DemoDropWell(frame: NSMakeRect(400, 96, 380, 48))
showcaseDropWell.onEvent = { statusLabel.stringValue = $0 }
showcaseDropWell.registerForDraggedTypes([.string, .fileURL])

// 3.22 — printing.
let printSectionLabel = showcaseSectionLabel("Printing (3.22)", NSMakeRect(400, 168, 360, 20))
let showcasePrintSample = DemoPrintSample(frame: NSMakeRect(400, 196, 320, 150))
let printButton = NSButton(title: "Print Sample…", frame: NSMakeRect(400, 356, 140, 30))
printButton.onAction = { _ in
    let operation = NSPrintOperation.printOperation(with: showcasePrintSample)
    operation.jobTitle = "WinChocolate Print Sample"
    statusLabel.stringValue = operation.run() ? "Printed sample" : "Print canceled"
}

// 3.7 — NSAlert(error:).
let errorAlertButton = NSButton(title: "Show Error Alert…", frame: NSMakeRect(560, 356, 160, 30))
errorAlertButton.onAction = { _ in
    let error = NSError(domain: "WinChocolate.Demo", code: 42, userInfo: [
        NSLocalizedDescriptionKey: "The document could not be opened.",
        NSLocalizedFailureReasonErrorKey: "The file is in use by another application.",
    ])
    let alert = NSAlert(error: error)
    _ = alert.runModal()
    statusLabel.stringValue = "Error alert dismissed"
}

// 3.19 — screens and window state.
let screenSectionLabel = showcaseSectionLabel("Screens & window state (3.19)", NSMakeRect(800, 16, 300, 20))
let mainScreen = NSScreen.main
let screenInfoLabel = NSTextField(
    string: "Screens: \(NSScreen.screens.count)   main \(Int(mainScreen?.frame.size.width ?? 0))×\(Int(mainScreen?.frame.size.height ?? 0))",
    frame: NSMakeRect(800, 44, 300, 20)
)
screenInfoLabel.isBordered = false
screenInfoLabel.drawsBackground = false
screenInfoLabel.font = NSFont.systemFont(ofSize: 11)
let workAreaLabel = NSTextField(
    string: "work area \(Int(mainScreen?.visibleFrame.size.width ?? 0))×\(Int(mainScreen?.visibleFrame.size.height ?? 0))",
    frame: NSMakeRect(800, 66, 300, 20)
)
workAreaLabel.isBordered = false
workAreaLabel.drawsBackground = false
workAreaLabel.font = NSFont.systemFont(ofSize: 11)
let miniaturizeButton = NSButton(title: "Minimize", frame: NSMakeRect(800, 96, 96, 30))
let zoomButton = NSButton(title: "Zoom", frame: NSMakeRect(902, 96, 96, 30))
miniaturizeButton.onAction = { _ in
    window.miniaturize(nil)
    statusLabel.stringValue = "Window minimized (restore from the taskbar)"
}
zoomButton.onAction = { _ in
    window.zoom(nil)
    statusLabel.stringValue = window.isZoomed ? "Window zoomed" : "Window restored"
}

// 5.5 — framework-drawn, view-based table hosting real controls in its cells.
// Placed in the clear full-width band below the print section (y > 386).
let viewTableSectionLabel = showcaseSectionLabel("Framework-drawn table — view-based cells (5.5)", NSMakeRect(24, 392, 480, 20))
let viewTableHint = NSTextField(string: "Hosts real controls; double-click a Note to edit, drag a row to reorder.", frame: NSMakeRect(24, 412, 560, 18))
viewTableHint.isBordered = false
viewTableHint.drawsBackground = false
viewTableHint.font = NSFont.systemFont(ofSize: 11)
let viewTableSource = DemoViewTableDataSource()
let viewTableDelegate = DemoViewTableDelegate(source: viewTableSource)
viewTableDelegate.onEvent = { statusLabel.stringValue = $0 }
let viewTableScrollView = NSScrollView(frame: NSMakeRect(24, 434, 470, 104))
viewTableScrollView.hasVerticalScroller = true
let viewTable = NSTableView(frame: NSMakeRect(0, 0, 470, 104))
let taskColumn = NSTableColumn(identifier: "task")
taskColumn.title = "Task"
taskColumn.width = 210
let noteColumn = NSTableColumn(identifier: "note")
noteColumn.title = "Note (dbl-click)"
noteColumn.width = 130
noteColumn.isEditable = true
let actionColumn = NSTableColumn(identifier: "action")
actionColumn.title = "Action"
actionColumn.width = 128
viewTable.addTableColumn(taskColumn)
viewTable.addTableColumn(noteColumn)
viewTable.addTableColumn(actionColumn)
viewTable.gridStyleMask = [.solidHorizontalGridLineMask, .solidVerticalGridLineMask]
viewTable.usesAlternatingRowBackgroundColors = true
viewTable.dataSource = viewTableSource
viewTable.delegate = viewTableDelegate
// No opt-in flag: the table auto-detects view-based mode because the delegate
// vends cell views (AppKit semantics).
// Drag a row to reorder it (5.8): move the parallel model arrays together.
viewTable.winRowReorderHandler = { [weak viewTable] from, toIndex in
    let dest = toIndex > from ? toIndex - 1 : toIndex
    let task = viewTableSource.tasks.remove(at: from)
    viewTableSource.tasks.insert(task, at: dest)
    let note = viewTableSource.notes.remove(at: from)
    viewTableSource.notes.insert(note, at: dest)
    let done = viewTableSource.done.remove(at: from)
    viewTableSource.done.insert(done, at: dest)
    viewTable?.reloadData()
    statusLabel.stringValue = "Moved row \(from) → \(dest)"
}
viewTableScrollView.documentView = viewTable

// 5.5 — NSTableRowView hosting: full-width colored row views behind hosted
// label cells (a CI-status list). Placed to the right of the view table.
let rowViewSectionLabel = showcaseSectionLabel("Row views — full-width row backgrounds (5.5)", NSMakeRect(520, 392, 380, 20))
let rowViewHint = NSTextField(string: "Each row hosts an NSTableRowView; click a row to see the selection fill.", frame: NSMakeRect(520, 412, 400, 18))
rowViewHint.isBordered = false
rowViewHint.drawsBackground = false
rowViewHint.font = NSFont.systemFont(ofSize: 11)
let statusRowSource = DemoStatusRowDataSource()
let statusRowDelegate = DemoStatusRowDelegate(source: statusRowSource)
let statusRowScrollView = NSScrollView(frame: NSMakeRect(520, 434, 300, 104))
statusRowScrollView.hasVerticalScroller = true
let statusRowTable = NSTableView(frame: NSMakeRect(0, 0, 300, 104))
let stageColumn = NSTableColumn(identifier: "stage")
stageColumn.title = "Stage"
stageColumn.width = 170
let statusColumn = NSTableColumn(identifier: "status")
statusColumn.title = "Status"
statusColumn.width = 128
statusRowTable.addTableColumn(stageColumn)
statusRowTable.addTableColumn(statusColumn)
statusRowTable.dataSource = statusRowSource
statusRowTable.delegate = statusRowDelegate
// Auto-detected view-based (the delegate vends cell + row views).
statusRowScrollView.documentView = statusRowTable

showcasePage.addSubview(spinnerSectionLabel)
showcasePage.addSubview(showcaseSpinner)
showcasePage.addSubview(spinnerStartButton)
showcasePage.addSubview(spinnerStopButton)
showcasePage.addSubview(templateSectionLabel)
showcasePage.addSubview(templateImageView)
showcasePage.addSubview(templateTintWell)
showcasePage.addSubview(templateHintLabel)
showcasePage.addSubview(hoverSectionLabel)
showcasePage.addSubview(showcaseHoverView)
showcasePage.addSubview(dragSectionLabel)
showcasePage.addSubview(showcaseDragHandle)
showcasePage.addSubview(showcaseDropWell)
showcasePage.addSubview(printSectionLabel)
showcasePage.addSubview(showcasePrintSample)
showcasePage.addSubview(printButton)
showcasePage.addSubview(errorAlertButton)
showcasePage.addSubview(screenSectionLabel)
showcasePage.addSubview(screenInfoLabel)
showcasePage.addSubview(workAreaLabel)
showcasePage.addSubview(miniaturizeButton)
showcasePage.addSubview(zoomButton)
showcasePage.addSubview(viewTableSectionLabel)
showcasePage.addSubview(viewTableHint)
showcasePage.addSubview(viewTableScrollView)
showcasePage.addSubview(rowViewSectionLabel)
showcasePage.addSubview(rowViewHint)
showcasePage.addSubview(statusRowScrollView)

// MARK: - "Lists (5.x)" page — NSBrowser path + NSCollectionView flow layout
// A dedicated page so both are laid out with room and are directly clickable.

// 5.3 — column browser with a live path readout.
let listsBrowserLabel = showcaseSectionLabel("Column browser — NSBrowser (5.3)", NSMakeRect(24, 20, 500, 20))
let listsBrowserHint = NSTextField(string: "Click through the columns; the path below updates via NSBrowser.path().", frame: NSMakeRect(24, 42, 620, 18))
listsBrowserHint.isBordered = false
listsBrowserHint.drawsBackground = false
listsBrowserHint.font = NSFont.systemFont(ofSize: 11)
browser.frame = NSMakeRect(24, 66, 520, 150)
browser.columnWidth = 160
browser.delegate = browserDataSource
browser.loadColumnZero()
let listsBrowserPathLabel = NSTextField(string: "Path: /", frame: NSMakeRect(24, 224, 720, 22))
listsBrowserPathLabel.isBordered = false
listsBrowserPathLabel.drawsBackground = false
listsBrowserPathLabel.font = NSFont.boldSystemFont(ofSize: 12)
listsBrowserPathLabel.textColor = .blue
browser.onAction = { [weak browser] _ in
    guard let browser else {
        return
    }
    listsBrowserPathLabel.stringValue = "Path: \(browser.path())"
    statusLabel.stringValue = "Browser path: \(browser.path())"
}

// 5.4 — collection flow layout with live re-tiling controls.
let listsCollectionLabel = showcaseSectionLabel("Collection view — NSCollectionViewFlowLayout (5.4)", NSMakeRect(24, 268, 600, 20))
let listsCollectionHint = NSTextField(string: "Change item size, spacing, or direction — the items re-flow live.", frame: NSMakeRect(24, 290, 620, 18))
listsCollectionHint.isBordered = false
listsCollectionHint.drawsBackground = false
listsCollectionHint.font = NSFont.systemFont(ofSize: 11)

let listsFlowSource = DemoFlowCollectionDataSource()
let listsFlowLayout = NSCollectionViewFlowLayout()
listsFlowLayout.itemSize = NSMakeSize(120, 28)
listsFlowLayout.minimumInteritemSpacing = 8
listsFlowLayout.minimumLineSpacing = 8
listsFlowLayout.sectionInset = NSEdgeInsetsMake(6, 6, 10, 6)
listsFlowLayout.headerReferenceSize = NSMakeSize(0, 24)
let listsCollectionScrollView = NSScrollView(frame: NSMakeRect(24, 352, 860, 168))
listsCollectionScrollView.hasVerticalScroller = true
let listsCollectionView = NSCollectionView(frame: NSMakeRect(0, 0, 860, 168))
listsCollectionView.dataSource = listsFlowSource
listsCollectionView.collectionViewLayout = listsFlowLayout
listsCollectionScrollView.documentView = listsCollectionView
listsCollectionView.reloadData()

let listsItemSizeControl = NSSegmentedControl(labels: ["Small", "Medium", "Large"], frame: NSMakeRect(24, 316, 210, 26))
listsItemSizeControl.selectedSegment = 1
listsItemSizeControl.onAction = { _ in
    switch listsItemSizeControl.selectedSegment {
    case 0: listsFlowLayout.itemSize = NSMakeSize(90, 24)
    case 2: listsFlowLayout.itemSize = NSMakeSize(170, 40)
    default: listsFlowLayout.itemSize = NSMakeSize(120, 28)
    }
    listsCollectionView.reloadData()
    statusLabel.stringValue = "Collection item size changed"
}
let listsSpacingControl = NSSegmentedControl(labels: ["Tight", "Normal", "Loose"], frame: NSMakeRect(246, 316, 210, 26))
listsSpacingControl.selectedSegment = 1
listsSpacingControl.onAction = { _ in
    let gap: CGFloat = listsSpacingControl.selectedSegment == 0 ? 2 : (listsSpacingControl.selectedSegment == 2 ? 24 : 8)
    listsFlowLayout.minimumInteritemSpacing = gap
    listsFlowLayout.minimumLineSpacing = gap
    listsCollectionView.reloadData()
    statusLabel.stringValue = "Collection spacing changed"
}
let listsDirectionControl = NSSegmentedControl(labels: ["Vertical", "Horizontal"], frame: NSMakeRect(468, 316, 200, 26))
listsDirectionControl.selectedSegment = 0
listsDirectionControl.onAction = { _ in
    listsFlowLayout.scrollDirection = listsDirectionControl.selectedSegment == 1 ? .horizontal : .vertical
    listsCollectionScrollView.hasVerticalScroller = listsDirectionControl.selectedSegment == 0
    listsCollectionScrollView.hasHorizontalScroller = listsDirectionControl.selectedSegment == 1
    listsCollectionView.reloadData()
    statusLabel.stringValue = "Collection scroll direction changed"
}

// Per-item sizing: "By label" installs a flow delegate that sizes each item to
// its title; "Uniform" clears it so the layout's itemSize applies.
let listsFlowSizeDelegate = DemoFlowSizeDelegate(listsFlowSource)
let listsSizeModeControl = NSSegmentedControl(labels: ["Uniform size", "Size by label"], frame: NSMakeRect(680, 316, 220, 26))
listsSizeModeControl.selectedSegment = 0
listsSizeModeControl.onAction = { _ in
    listsCollectionView.delegate = listsSizeModeControl.selectedSegment == 1 ? listsFlowSizeDelegate : nil
    listsCollectionView.reloadData()
    statusLabel.stringValue = listsSizeModeControl.selectedSegment == 1 ? "Items sized to their labels" : "Uniform item size"
}

listsPage.addSubview(listsBrowserLabel)
listsPage.addSubview(listsBrowserHint)
listsPage.addSubview(browser)
listsPage.addSubview(listsBrowserPathLabel)
listsPage.addSubview(listsCollectionLabel)
listsPage.addSubview(listsCollectionHint)
listsPage.addSubview(listsItemSizeControl)
listsPage.addSubview(listsSpacingControl)
listsPage.addSubview(listsDirectionControl)
listsPage.addSubview(listsSizeModeControl)
listsPage.addSubview(listsCollectionScrollView)
// Document-architecture demo: a New Note window driven by NSDocument,
// NSWindowController, and the shared NSDocumentController. The window title
// gains the classic asterisk while the note has unsaved edits.
NSDocumentController.shared.winDocumentClass = DemoNoteDocument.self
let newNoteItem = NSMenuItem(title: "New Note Document", action: nil, keyEquivalent: "n")
newNoteItem.onAction = { _ in
    let document = NSDocumentController.shared.newDocument(nil)
    statusLabel.stringValue = "New note document (\(NSDocumentController.shared.documents.count) open)"
    _ = document
}
appMenu.insertItem(newNoteItem, at: 0)

// Edit menu drives the notes text view's undo stack; items enable through
// NSMenuItemValidation just before the menu opens.
let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
let editMenu = NSMenu(title: "Edit")
notesTextView.allowsUndo = true
let undoItem = NSMenuItem(title: "Undo", action: nil, keyEquivalent: "z")
undoItem.target = editMenuController
undoItem.onAction = { _ in
    notesTextView.undoManager?.undo()
    statusLabel.stringValue = "Undo (notes)"
}
let redoItem = NSMenuItem(title: "Redo", action: nil, keyEquivalent: "z")
redoItem.keyEquivalentModifierMask = [.command, .shift]
redoItem.target = editMenuController
redoItem.onAction = { _ in
    notesTextView.undoManager?.redo()
    statusLabel.stringValue = "Redo (notes)"
}
editMenu.addItem(undoItem)
editMenu.addItem(redoItem)
editMenu.addItem(NSMenuItem.separator())

// Find targets the focused text view like AppKit's responder-chain
// dispatch, falling back to the main window's notes view.
let activeFindTextView: () -> NSTextView = {
    (NSApplication.shared.keyWindow?.firstResponder as? NSTextView) ?? notesTextView
}

// Find items dispatch through NSTextFinder.Action tags, AppKit-style.
let findItem = NSMenuItem(title: "Find...", action: nil, keyEquivalent: "f")
findItem.tag = NSTextFinder.Action.showFindInterface.rawValue
let findNextItem = NSMenuItem(title: "Find Next", action: nil, keyEquivalent: "g")
findNextItem.tag = NSTextFinder.Action.nextMatch.rawValue
let findPreviousItem = NSMenuItem(title: "Find Previous", action: nil, keyEquivalent: "g")
findPreviousItem.keyEquivalentModifierMask = [.command, .shift]
findPreviousItem.tag = NSTextFinder.Action.previousMatch.rawValue
let useSelectionItem = NSMenuItem(title: "Use Selection for Find", action: nil, keyEquivalent: "e")
useSelectionItem.tag = NSTextFinder.Action.setSearchString.rawValue
for item in [findItem, findNextItem, findPreviousItem, useSelectionItem] {
    item.onAction = { sender in
        activeFindTextView().performTextFinderAction(sender)
    }
    editMenu.addItem(item)
}

// Clipboard actions dispatch to the focused text view over NSPasteboard.
editMenu.addItem(NSMenuItem.separator())
let cutItem = NSMenuItem(title: "Cut", action: nil, keyEquivalent: "x")
cutItem.onAction = { _ in
    activeFindTextView().cut(nil)
    statusLabel.stringValue = "Cut (notes)"
}
let copyItem = NSMenuItem(title: "Copy", action: nil, keyEquivalent: "c")
copyItem.onAction = { _ in
    activeFindTextView().copy(nil)
    statusLabel.stringValue = "Copied: \(NSPasteboard.general.string(forType: .string) ?? "")"
}
let pasteItem = NSMenuItem(title: "Paste", action: nil, keyEquivalent: "v")
pasteItem.onAction = { _ in
    activeFindTextView().paste(nil)
    statusLabel.stringValue = "Pasted: \(NSPasteboard.general.string(forType: .string) ?? "")"
}
let selectAllItem = NSMenuItem(title: "Select All", action: nil, keyEquivalent: "a")
selectAllItem.onAction = { _ in
    activeFindTextView().selectAll(nil)
    statusLabel.stringValue = "Select All (notes)"
}
for item in [cutItem, copyItem, pasteItem, selectAllItem] {
    editMenu.addItem(item)
}
editMenuItem.submenu = editMenu
menuBar.addItem(editMenuItem)
editMenuController.textView = notesTextView

// View menu mirrors the toolbar page selector so every demo page also has a
// menu entry.
let viewMenuItem = NSMenuItem(title: "View", action: nil, keyEquivalent: "")
let viewMenu = NSMenu(title: "View")
for (index, pageTitle) in ["Controls Page", "Values Page", "Tables/Media Page", "Drawing Page", "New in 3.x Page", "Lists Page"].enumerated() {
    // Ctrl+1...Ctrl+5 switch pages (the .command mask maps onto Ctrl on Windows).
    let item = NSMenuItem(title: pageTitle, action: nil, keyEquivalent: "\(index + 1)")
    item.onAction = { _ in
        pageSelector.selectItem(at: index)
        showDemoPage(index)
        statusLabel.stringValue = "Page selected: \(pageTitle)"
    }
    viewMenu.addItem(item)
}
viewMenuItem.submenu = viewMenu
menuBar.addItem(viewMenuItem)
app.mainMenu = menuBar

// Right-clicking the paths view opens a checkmark-style context menu.
let shapesContextMenu = NSMenu(title: "Shapes")
for shapeTitle in ["Star", "Wave", "Card"] {
    let shapeItem = NSMenuItem(title: shapeTitle, action: nil, keyEquivalent: "")
    shapeItem.onAction = { item in
        item.state = item.state == .on ? .off : .on
        statusLabel.stringValue = "Shape \(shapeTitle) \(item.state == .on ? "checked" : "unchecked")"
    }
    shapesContextMenu.addItem(shapeItem)
}
shapesView.contextMenu = shapesContextMenu

window.contentView = contentView
showDemoPage(0)
updateFocusDisplay()

if CommandLine.arguments.contains("--diagnose") {
    // Validate native window creation without ordering the window front so
    // build scripts do not flash a full demo window on screen.
    _ = window.realizeNativePeer()
    window.makeMain()
    window.makeKey()
    print("Window native handle: \(window.nativeHandle?.rawValue ?? 0)")
    print("App windows: \(NSApp.windows.count)")
    print("Is key window: \(window.isKeyWindow)")
    print("Is main window: \(window.isMainWindow)")
    print("Demo artwork path: \(demoArtworkPath)")
    print("Demo screen artwork path: \(demoScreenArtworkPath)")
    window.close()
} else {
    statusLabel.stringValue = "Ready - window shown"
    window.makeKeyAndOrderFront(nil)
    statusLabel.stringValue = window.isKeyWindow && window.isMainWindow
        ? "Ready - key/main window"
        : "Ready - window shown"
    app.run()
}
