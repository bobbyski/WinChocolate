// Part of the shared demo, split out of main.swift by topic.
//
// Only DECLARATIONS live here. main.swift is Swift's top-level-code file:
// its statements run in written order, and moving one here would turn it
// into a lazily-initialized global that never runs. Declarations have no
// such ordering, so they move freely.

#if canImport(WASMChocolate)
import WASMChocolate
#elseif canImport(LinChocolate)
import LinChocolate
#elseif canImport(WinChocolate)
import WinChocolate
#else
import AppKit
#endif

final class DemoContentView: NSView {
    /// The demo is authored in top-left coordinates (see `DemoFilledView`).
    override var isFlipped: Bool {
        true
    }

    /// Live system theme switch: AppKit calls this after the view's effective
    /// appearance changes, so the demo refreshes its appearance-derived colors
    /// here — the AppKit-standard hook, identical on every target.
    override func viewDidChangeEffectiveAppearance() {
        applyLiveAppearanceRefresh()
    }

    var onBlankAreaMouseDown: (@MainActor (NSEvent) -> Void)?
    var onBlankAreaMouseUp: (@MainActor (NSEvent) -> Void)?
    var onMouseMoved: (@MainActor (NSEvent) -> Void)?
    var onKeyDown: (@MainActor (NSEvent) -> Void)?
    var onKeyUp: (@MainActor (NSEvent) -> Void)?

    // The demo's own fill: AppKit's NSView has no backgroundColor, so this
    // subclass draws its background itself (plain AppKit).
    var backgroundColor: NSColor? {
        didSet {
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let backgroundColor else {
            return
        }

        backgroundColor.setFill()
        NSBezierPath(rect: bounds).fill()
    }

    override func mouseDown(with event: NSEvent) {
        let handler = onBlankAreaMouseDown
        nonisolated(unsafe) let sent = event
        MainActor.assumeIsolated {
            handler?(sent)
        }
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        let handler = onBlankAreaMouseUp
        nonisolated(unsafe) let sent = event
        MainActor.assumeIsolated {
            handler?(sent)
        }
        super.mouseUp(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        let handler = onMouseMoved
        nonisolated(unsafe) let sent = event
        MainActor.assumeIsolated {
            handler?(sent)
        }
        super.mouseMoved(with: event)
    }

    override func keyDown(with event: NSEvent) {
        let handler = onKeyDown
        nonisolated(unsafe) let sent = event
        MainActor.assumeIsolated {
            handler?(sent)
        }
        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        let handler = onKeyUp
        nonisolated(unsafe) let sent = event
        MainActor.assumeIsolated {
            handler?(sent)
        }
        super.keyUp(with: event)
    }
}

final class DemoPageView: NSView {
    /// The demo is authored in top-left coordinates (see `DemoFilledView`).
    override var isFlipped: Bool {
        true
    }

    override var acceptsFirstResponder: Bool {
        false
    }
}

/// A view that highlights while the cursor hovers it, driven by a tracking
/// area (3.21). Reports enter/exit through `onEvent`.
/// An image view that reports clicks.
///
/// `NSImageView` does **not** send its action when clicked — `NSImageCell` has no action
/// tracking, so neither `mouseDown` nor even `performClick(_:)` fires it (verified against
/// real AppKit). Setting `target`/`action` on a plain `NSImageView` is silently inert, so
/// "click the image to cycle" cannot be built that way. Apple marks `NSImageView` `open`
/// precisely so callers can add the behavior they need, which is what this does.
final class DemoClickableImageView: NSImageView {
    var onClick: (@MainActor () -> Void)?

    override func mouseDown(with event: NSEvent) {
        let handler = onClick
        MainActor.assumeIsolated {
            handler?()
        }
    }
}

final class DemoHoverView: NSView {

    /// The demo is authored in top-left coordinates (see `DemoFilledView`).
    override var isFlipped: Bool {
        true
    }
    var onEvent: (@MainActor (String) -> Void)?
    private var hovering = false

    override var acceptsFirstResponder: Bool { false }

    override func updateTrackingAreas() {
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func draw(_ dirtyRect: NSRect) {
        // The resting fill/text follow the appearance so the box isn't a light
        // slab in dark mode; the hover state stays accent-blue on both.
        let dark = NSAppearance.currentDrawing().bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let fill = hovering
            ? NSColor(calibratedRed: 0.30, green: 0.62, blue: 0.86, alpha: 1)
            : (dark ? NSColor(calibratedRed: 0.24, green: 0.24, blue: 0.26, alpha: 1)
                    : NSColor(calibratedRed: 0.90, green: 0.92, blue: 0.95, alpha: 1))
        fill.setFill()
        let body = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 8, yRadius: 8)
        body.fill()
        NSColor(calibratedRed: 0.55, green: 0.58, blue: 0.62, alpha: 1).setStroke()
        body.stroke()

        let text = hovering ? "Hovering" : "Hover me"
        text.draw(at: NSMakePoint(14, bounds.size.height / 2 - 8), withAttributes: [
            .font: NSFont.boldSystemFont(ofSize: 13),
            .foregroundColor: hovering
                ? NSColor.white
                : (dark ? NSColor(white: 0.85, alpha: 1) : NSColor(calibratedRed: 0.3, green: 0.3, blue: 0.32, alpha: 1)),
        ])
    }

    override func mouseEntered(with event: NSEvent) {
        hovering = true
        needsDisplay = true
        let handler = onEvent
        let message = "Hover entered (mouseEntered)"
        MainActor.assumeIsolated {
            handler?(message)
        }
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false
        needsDisplay = true
        let handler = onEvent
        let message = "Hover exited (mouseExited)"
        MainActor.assumeIsolated {
            handler?(message)
        }
    }
}

/// A drag source (3.18): dragging out of it starts a text or file drag.
final class DemoDragHandle: NSView, NSDraggingSource {

    /// The demo is authored in top-left coordinates (see `DemoFilledView`).
    override var isFlipped: Bool {
        true
    }
    var draggedText = "WinChocolate drag payload"
    var onEvent: (@MainActor (String) -> Void)?

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
        // A raw String isn't NSPasteboardWriting on Apple; an NSPasteboardItem
        // is (and WinChocolate accepts it too).
        let pasteboardItem = NSPasteboardItem()
        pasteboardItem.setString(draggedText, forType: .string)
        let item = NSDraggingItem(pasteboardWriter: pasteboardItem)
        item.draggingFrame = bounds
        let handler = onEvent
        let message = "Drag started: \"\(draggedText)\""
        MainActor.assumeIsolated {
            handler?(message)
        }
        _ = beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    // The drag outcome arrives through AppKit's real source callback; an
    // empty operation means the drag canceled.
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        let handler = onEvent
        let message = operation.isEmpty ? "Drag canceled" : "Drag dropped on a target"
        MainActor.assumeIsolated {
            handler?(message)
        }
    }
}

/// A drop destination (3.18): accepts dropped text and files, highlighting
/// while a drag hovers and reporting what landed.
final class DemoDropWell: NSView {

    /// The demo is authored in top-left coordinates (see `DemoFilledView`).
    override var isFlipped: Bool {
        true
    }
    var onEvent: (@MainActor (String) -> Void)?
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
        let handler = onEvent
        let message = lastDrop
        MainActor.assumeIsolated {
            handler?(message)
        }
        return true
    }
}

/// A custom-drawn sample used to demonstrate printing (3.22).
final class DemoPrintSample: NSView {

    /// The demo is authored in top-left coordinates (see `DemoFilledView`).
    override var isFlipped: Bool {
        true
    }
    override var acceptsFirstResponder: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        (bounds).fill()
        NSColor(calibratedRed: 0.55, green: 0.58, blue: 0.62, alpha: 1).setStroke()
        (bounds).frame()

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

struct ImageMode {
    let scaling: NSImageScaling
    let alignment: NSImageAlignment
    let path: String
    let description: String
}
