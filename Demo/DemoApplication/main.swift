// One source, three libraries — the AppKit-compatibility proof. On Linux
// `import LinChocolate` (GTK), on Windows `import WinChocolate` (Win32), and on
// macOS the real Apple `AppKit` (the ground truth both are faithful to). The
// same demo is written once against Apple's API; platform-only bits are
// `#if`-guarded.
//
// SET IN STONE (Bobby, 2026-07-14): the Apple-native way must work and be
// sufficient — this demo must build and RUN on real Apple AppKit, and every
// capability must be reachable through the real Apple API with no convenience
// *required*. A convenience helper is allowed ONLY as demo-local sugar built
// entirely on real AppKit primitives (e.g. a closure `onAction` that sets the
// actual target/action the library dispatches through) — such a helper compiles
// and runs on real AppKit too. BANNED: WinChocolate-only API the demo depends
// on, and one-sided `#if os(macOS)` shims (why PlatformShims.swift was deleted).
// Any place the demo leans on a WinChocolate invention (framework `onAction`,
// frame-carrying inits, `NSView.backgroundColor`, `winIsDark`, …) is a bug —
// fix by making the real Apple mechanism work and moving any sugar demo-side
// over real primitives. See Phase 18.
#if canImport(LinChocolate)
import LinChocolate
#elseif canImport(WinChocolate)
import WinChocolate
#elseif canImport(AppKit)
import AppKit
#endif

#if canImport(WinChocolate)
// The framework defaults to the modern presentation (ComCtl32 v6 visual
// styles, plan 8.4); pass --classic to compare against the unthemed classic
// look. Must be selected before the application (and its backend) is
// created — the binding is one-way for the process.
if CommandLine.arguments.contains("--classic") {
    WinPresentation.selected = .classic
}
#endif

let app = NSApplication.shared
#if canImport(LinChocolate)
// The one Linux-specific line: install the native GTK backend before any
// windows/controls are created (WinChocolate wires its Win32 backend itself).
app.nativeBackend = GTKNativeControlBackend()
// This demo is authored top-left (Win32/WinChocolate use a top-left origin).
// LinChocolate defaults to AppKit's bottom-left origin for its own demos, so opt
// this one into a top-left origin so subview Y coordinates match WinChocolate.
NSView.defaultIsFlipped = true
#endif

// The demo follows the Windows system theme by default (AppKit's behavior:
// no override means the effective appearance tracks the system). --light and
// --dark force one appearance for side-by-side QA. Like the presentation,
// appearance-derived visuals resolve at creation.
if CommandLine.arguments.contains("--dark") {
    app.appearance = NSAppearance(named: .darkAqua)
} else if CommandLine.arguments.contains("--light") {
    app.appearance = NSAppearance(named: .aqua)
}

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
    /// The demo is authored in top-left coordinates (see `DemoFilledView`).
    override var isFlipped: Bool {
        true
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
        nonisolated(unsafe) let handler = onBlankAreaMouseDown
        nonisolated(unsafe) let sent = event
        MainActor.assumeIsolated {
            handler?(sent)
        }
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        nonisolated(unsafe) let handler = onBlankAreaMouseUp
        nonisolated(unsafe) let sent = event
        MainActor.assumeIsolated {
            handler?(sent)
        }
        super.mouseUp(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        nonisolated(unsafe) let handler = onMouseMoved
        nonisolated(unsafe) let sent = event
        MainActor.assumeIsolated {
            handler?(sent)
        }
        super.mouseMoved(with: event)
    }

    override func keyDown(with event: NSEvent) {
        nonisolated(unsafe) let handler = onKeyDown
        nonisolated(unsafe) let sent = event
        MainActor.assumeIsolated {
            handler?(sent)
        }
        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        nonisolated(unsafe) let handler = onKeyUp
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

/// Adapts `NSTextFieldDelegate` begin/end editing to closures for the demo.
final class DemoFieldDelegate: NSObject, NSTextFieldDelegate {
    var onBegin: (@MainActor () -> Void)?
    var onEnd: (@MainActor () -> Void)?
    var onChange: (@MainActor (NSTextField) -> Void)?

    func controlTextDidBeginEditing(_ obj: Notification) {
        nonisolated(unsafe) let handler = onBegin
        MainActor.assumeIsolated {
            handler?()
        }
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        nonisolated(unsafe) let handler = onEnd
        MainActor.assumeIsolated {
            handler?()
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        if let field = obj.object as? NSTextField {
            nonisolated(unsafe) let handler = onChange
            nonisolated(unsafe) let sent = field
            MainActor.assumeIsolated {
                handler?(sent)
            }
        }
    }
}

/// Receives the alert help-button click through the real `NSAlertDelegate`.
final class DemoAlertHelpDelegate: NSObject, NSAlertDelegate {
    var onHelp: (@MainActor () -> Void)?

    func alertShowHelp(_ alert: NSAlert) -> Bool {
        nonisolated(unsafe) let handler = onHelp
        MainActor.assumeIsolated {
            handler?()
        }
        return true
    }
}

/// Applies live font-panel picks through the real `changeFont(_:)` chain
/// action — `NSFontChanging`, AppKit's shape since 10.14 (`NSFontManager`'s
/// target receives it).
final class DemoFontChangeResponder: NSResponder, NSFontChanging {
    var handler: (@MainActor (NSFont) -> Void)?

    func changeFont(_ sender: NSFontManager?) {
        nonisolated(unsafe) let stored = handler
        nonisolated(unsafe) let font = (sender ?? NSFontManager.shared).convert(NSFont.systemFont(ofSize: 13))
        MainActor.assumeIsolated {
            stored?(font)
        }
    }
}

final class DemoCanvasView: NSView {

    /// The demo is authored in top-left coordinates (see `DemoFilledView`).
    override var isFlipped: Bool {
        true
    }
    static let palette: [NSColor] = [
        NSColor(calibratedRed: 0.86, green: 0.29, blue: 0.25, alpha: 1),
        NSColor(calibratedRed: 0.30, green: 0.62, blue: 0.86, alpha: 1),
        NSColor(calibratedRed: 0.22, green: 0.60, blue: 0.35, alpha: 1),
        NSColor(calibratedRed: 0.94, green: 0.72, blue: 0.25, alpha: 1)
    ]

    var fillColorIndex = 0
    var strokeColorIndex = 1
    var radius: CGFloat = 36
    var onEvent: (@MainActor (String) -> Void)?

    override var acceptsFirstResponder: Bool {
        false
    }

    override func resetCursorRects() {
        // Crosshair inside the drawing surface, published as a cursor rect.
        addCursorRect(NSMakeRect(4, 4, frame.size.width - 8, frame.size.height - 8), cursor: .crosshair)
    }

    override func draw(_ dirtyRect: NSRect) {
        let inset = NSMakeRect(4, 4, frame.size.width - 8, frame.size.height - 8)
        // The artboard follows the appearance (light paper / dark board) so
        // the canvas doesn't read as a white slab in dark mode.
        let dark = NSAppearance.currentDrawing().bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        (dark ? NSColor(calibratedRed: 0.17, green: 0.17, blue: 0.18, alpha: 1)
              : NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.96, alpha: 1)).setFill()
        let backdrop = NSBezierPath(roundedRect: inset, xRadius: 10, yRadius: 10)
        backdrop.fill()
        (dark ? NSColor(calibratedRed: 0.40, green: 0.40, blue: 0.42, alpha: 1)
              : NSColor(calibratedRed: 0.55, green: 0.55, blue: 0.55, alpha: 1)).setStroke()
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
            nonisolated(unsafe) let handler = onEvent
            let message = "Canvas reset (double-click)"
            MainActor.assumeIsolated {
                handler?(message)
            }
        } else {
            fillColorIndex = (fillColorIndex + 1) % Self.palette.count
            nonisolated(unsafe) let handler = onEvent
            let message = "Canvas fill color (click)"
            MainActor.assumeIsolated {
                handler?(message)
            }
        }
        needsDisplay = true
    }

    override func rightMouseDown(with event: NSEvent) {
        strokeColorIndex = (strokeColorIndex + 1) % Self.palette.count
        nonisolated(unsafe) let handler = onEvent
        let message = "Canvas stroke color (right-click)"
        MainActor.assumeIsolated {
            handler?(message)
        }
        needsDisplay = true
    }

    override func scrollWheel(with event: NSEvent) {
        radius = min(max(radius + event.scrollingDeltaY * 4, 16), 110)
        nonisolated(unsafe) let handler = onEvent
        let message = "Canvas radius (scroll)"
        MainActor.assumeIsolated {
            handler?(message)
        }
        needsDisplay = true
    }
}

final class DemoShapesView: NSView {

    /// The demo is authored in top-left coordinates (see `DemoFilledView`).
    override var isFlipped: Bool {
        true
    }
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
        // The artboard follows the appearance (light paper / dark board) so it
        // doesn't read as a white slab in dark mode; the shapes are saturated
        // colors that stay legible on either.
        let dark = NSAppearance.currentDrawing().bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        (dark ? NSColor(calibratedRed: 0.17, green: 0.17, blue: 0.18, alpha: 1)
              : NSColor.white).setFill()
        (NSMakeRect(0, 0, frame.size.width, frame.size.height)).fill()
        (dark ? NSColor(calibratedRed: 0.40, green: 0.40, blue: 0.42, alpha: 1)
              : NSColor(calibratedRed: 0.55, green: 0.55, blue: 0.55, alpha: 1)).setFill()
        (NSMakeRect(0, 0, frame.size.width, frame.size.height)).frame()

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

    /// The demo is authored in top-left coordinates (see `DemoFilledView`).
    override var isFlipped: Bool {
        true
    }
    override var acceptsFirstResponder: Bool {
        false
    }

    override func draw(_ dirtyRect: NSRect) {
        // Appearance-aware board (light paper / dark board) so it doesn't read as
        // a white slab in dark mode; the gradient swatches stay legible on either.
        let dark = NSAppearance.currentDrawing().bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        (dark ? NSColor(calibratedRed: 0.17, green: 0.17, blue: 0.18, alpha: 1)
              : NSColor.white).setFill()
        (NSMakeRect(0, 0, frame.size.width, frame.size.height)).fill()
        (dark ? NSColor(calibratedRed: 0.40, green: 0.40, blue: 0.42, alpha: 1)
              : NSColor(calibratedRed: 0.55, green: 0.55, blue: 0.55, alpha: 1)).setFill()
        (NSMakeRect(0, 0, frame.size.width, frame.size.height)).frame()

        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10),
            .foregroundColor: dark ? NSColor(white: 0.78, alpha: 1) : NSColor.darkGray
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
        (horizontal).frame()

        // Two-color vertical gradient, dark at the bottom per AppKit's angle 90.
        "angle 90".draw(at: NSMakePoint(184, 10), withAttributes: labelAttributes)
        let vertical = NSMakeRect(184, sampleY, 150, sampleHeight)
        NSGradient(
            starting: NSColor(calibratedRed: 0.13, green: 0.35, blue: 0.22, alpha: 1),
            ending: NSColor(calibratedRed: 0.66, green: 0.90, blue: 0.72, alpha: 1)
        )?.draw(in: vertical, angle: 90)
        NSColor.gray.setFill()
        (vertical).frame()

        // Multi-stop diagonal gradient with explicit locations.
        "multi-stop 45".draw(at: NSMakePoint(356, 10), withAttributes: labelAttributes)
        let diagonal = NSMakeRect(356, sampleY, 150, sampleHeight)
        NSGradient(colorsAndLocations:
            (NSColor(calibratedRed: 0.86, green: 0.29, blue: 0.25, alpha: 1), 0),
            (NSColor(calibratedRed: 0.94, green: 0.72, blue: 0.25, alpha: 1), 0.3),
            (NSColor(calibratedRed: 0.22, green: 0.60, blue: 0.35, alpha: 1), 1)
        )?.draw(in: diagonal, angle: 45)
        NSColor.gray.setFill()
        (diagonal).frame()

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
            NSMakeRect(ovalRect.origin.x + CGFloat(band) * 19, ovalRect.origin.y, 19, sampleHeight).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        NSColor(calibratedRed: 0.61, green: 0.43, blue: 0.16, alpha: 1).setStroke()
        oval.lineWidth = 2
        oval.stroke()
    }
}

// MARK: - Scroll-stress paint-heavy view

/// A deliberately expensive-to-paint view: a full-width base gradient plus a
/// dense grid of individual gradient tiles (dozens of `NSGradient.draw` calls
/// per `draw(_:)`). Used on the scroll-stress page so scrolling and resizing
/// exercise the repaint pipeline with slow content, making flicker/coalescing
/// issues obvious.
final class DemoSlowGradientView: NSView {

    /// The demo is authored in top-left coordinates (see `DemoFilledView`).
    override var isFlipped: Bool {
        true
    }
    var label: String = ""
    /// Grid density — higher means slower paint.
    var columns = 18
    var rows = 4

    override var acceptsFirstResponder: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let dark = NSAppearance.currentDrawing().bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        (dark ? NSColor(calibratedRed: 0.14, green: 0.14, blue: 0.16, alpha: 1)
              : NSColor(calibratedRed: 0.96, green: 0.96, blue: 0.98, alpha: 1)).setFill()
        (NSMakeRect(0, 0, frame.size.width, frame.size.height)).fill()

        // Full-width multi-stop base gradient.
        NSGradient(colorsAndLocations:
            (NSColor(calibratedRed: 0.30, green: 0.62, blue: 0.86, alpha: 1), 0),
            (NSColor(calibratedRed: 0.55, green: 0.35, blue: 0.80, alpha: 1), 0.5),
            (NSColor(calibratedRed: 0.90, green: 0.45, blue: 0.35, alpha: 1), 1)
        )?.draw(in: NSMakeRect(0, 0, frame.size.width, frame.size.height), angle: 20)

        // A dense grid of individual gradient tiles — the expensive part.
        let tileW = frame.size.width / CGFloat(columns)
        let tileH = frame.size.height / CGFloat(rows)
        for r in 0..<rows {
            for c in 0..<columns {
                let t = CGFloat((r * columns + c) % 24) / 24.0
                let rect = NSMakeRect(CGFloat(c) * tileW + 2, CGFloat(r) * tileH + 2,
                                      max(1, tileW - 4), max(1, tileH - 4))
                NSGradient(
                    starting: NSColor(calibratedRed: t, green: 0.55, blue: 1 - t, alpha: 1),
                    ending: NSColor(calibratedRed: 1 - t, green: 0.75, blue: t, alpha: 1)
                )?.draw(in: rect, angle: CGFloat((c * 20) % 360))
            }
        }

        label.draw(at: NSMakePoint(10, 6), withAttributes: [
            .font: NSFont.boldSystemFont(ofSize: 12),
            .foregroundColor: NSColor.white
        ])
    }
}

// MARK: - WinCoreGraphics (Phase 13) showcase view
//
// 18.10 exclusion: this view uses WinCoreGraphics' BMP-centric `CGImage`
// surface (`CGImage(width:height:rgbaPixels:)`, `encodeBMP`, `pixel(atX:y:)`),
// which Apple's CGImage does not have. Until Phase 13 presents an
// Apple-shaped `CGImage`/`CGDataProvider`, this page is fenced out of the
// macOS cross-check build — excluded, never shimmed.
/// An artboard drawn entirely through the CoreGraphics-shaped surface — `CGContext`
/// (paths, gradients, transforms via save/rotate/translate) and a `CGImage` round-tripped
/// through a real BMP encode/decode, read back pixel by pixel.
///
/// Every canvas is plain CoreGraphics/AppKit, so the whole artboard is shared across all
/// three targets with no conditional compilation (see DEMO_CHANGES.md).
final class DemoCoreGraphicsView: NSView {

    /// The demo is authored in top-left coordinates (see `DemoFilledView`).
    override var isFlipped: Bool {
        true
    }
    /// An 8×8 heart sprite, round-tripped through a real BMP encode/decode so the codec
    /// is exercised by the running demo, not just by tests.
    ///
    /// Built entirely from Apple's surface: raw RGBA → `CGDataProvider` → `CGImage`'s
    /// designated initializer → `NSBitmapImageRep`, which *is* Apple's BMP codec
    /// (`representation(using: .bmp)` / `init(data:)`). Kept as the rep rather than the
    /// `CGImage` because Apple's pixel accessor lives on the rep (`colorAt(x:y:)`);
    /// `CGImage` has none.
    /// (The demo is single-threaded on the UI thread, so the unchecked static is safe —
    /// same reasoning as `dataBackedSprite`, which reads this in its own default value.)
    nonisolated(unsafe) static let spriteRep: NSBitmapImageRep? = {
        let w = 8, h = 8
        let heart: [String] = [
            "........",
            ".XX..XX.",
            "XXXXXXXX",
            "XXXXXXXX",
            ".XXXXXX.",
            "..XXXX..",
            "...XX...",
            "........",
        ]
        var rgba = [UInt8]()
        rgba.reserveCapacity(w * h * 4)
        for row in heart {
            for character in row {
                if character == "X" {
                    rgba.append(contentsOf: [214, 60, 80, 255])
                } else {
                    rgba.append(contentsOf: [0, 0, 0, 0])
                }
            }
        }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let source = CGImage(width: w, height: h,
                                   bitsPerComponent: 8, bitsPerPixel: 32,
                                   bytesPerRow: w * 4,
                                   space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                                   provider: provider, decode: nil,
                                   shouldInterpolate: false, intent: .defaultIntent),
              // Encode to real BMP bytes and decode them back — the round-trip is the point.
              let bmp = NSBitmapImageRep(cgImage: source).representation(using: .bmp, properties: [:]),
              let decoded = NSBitmapImageRep(data: bmp) else {
            return nil
        }

        return decoded
    }()

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let dark = NSAppearance.currentDrawing().bestMatch(from: [.aqua, .darkAqua]) == .darkAqua

        // Artboard backdrop, matching the Drawing page's appearance behavior.
        let inset = NSMakeRect(4, 4, frame.size.width - 8, frame.size.height - 8)
        context.setFillColor((dark ? NSColor(calibratedRed: 0.17, green: 0.17, blue: 0.18, alpha: 1)
                                   : NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.96, alpha: 1)).cgColor)
        let backdrop = CGMutablePath()
        backdrop.addRoundedRect(in: inset, cornerWidth: 10, cornerHeight: 10)
        context.addPath(backdrop)
        context.fillPath()

        let label = dark ? NSColor(white: 0.85, alpha: 1) : NSColor(white: 0.25, alpha: 1)
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: label,
            .font: NSFont.systemFont(ofSize: 11)
        ]

        // 1) CGMutablePath: a curved leaf, filled and stroked.
        "CGPath curves".draw(at: NSMakePoint(inset.origin.x + 16, inset.origin.y + 10), withAttributes: attributes)
        let leafOrigin = NSMakePoint(inset.origin.x + 30, inset.origin.y + 40)
        let leaf = CGMutablePath()
        leaf.move(to: CGPoint(x: leafOrigin.x, y: leafOrigin.y + 70))
        leaf.addCurve(to: CGPoint(x: leafOrigin.x + 70, y: leafOrigin.y),
                      control1: CGPoint(x: leafOrigin.x, y: leafOrigin.y + 10),
                      control2: CGPoint(x: leafOrigin.x + 10, y: leafOrigin.y))
        leaf.addCurve(to: CGPoint(x: leafOrigin.x, y: leafOrigin.y + 70),
                      control1: CGPoint(x: leafOrigin.x + 60, y: leafOrigin.y + 70),
                      control2: CGPoint(x: leafOrigin.x, y: leafOrigin.y + 70))
        context.setFillColor(NSColor(calibratedRed: 0.30, green: 0.62, blue: 0.36, alpha: 1).cgColor)
        context.addPath(leaf)
        context.fillPath()
        context.setStrokeColor((dark ? NSColor(white: 0.8, alpha: 1) : NSColor(white: 0.3, alpha: 1)).cgColor)
        context.setLineWidth(1.5)
        context.addPath(leaf)
        context.strokePath()

        // 2) Gradients: a linear ramp in a rounded clip + a radial disc.
        "Linear + radial gradients".draw(at: NSMakePoint(inset.origin.x + 160, inset.origin.y + 10), withAttributes: attributes)
        if let ramp = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: [NSColor(calibratedRed: 0.98, green: 0.60, blue: 0.20, alpha: 1).cgColor,
                                          NSColor(calibratedRed: 0.55, green: 0.20, blue: 0.65, alpha: 1).cgColor] as CFArray,
                                 locations: [0, 1]) {
            context.saveGState()
            let rampRect = NSMakeRect(inset.origin.x + 170, inset.origin.y + 34, 120, 80)
            let clipPath = CGMutablePath()
            clipPath.addRoundedRect(in: rampRect, cornerWidth: 8, cornerHeight: 8)
            context.addPath(clipPath)
            context.clip()
            context.drawLinearGradient(ramp,
                                       start: CGPoint(x: rampRect.minX, y: rampRect.minY),
                                       end: CGPoint(x: rampRect.maxX, y: rampRect.maxY),
                                       options: [])
            context.restoreGState()
        }
        if let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: [NSColor(calibratedRed: 0.35, green: 0.65, blue: 0.95, alpha: 1).cgColor,
                                          NSColor(calibratedRed: 0.08, green: 0.18, blue: 0.38, alpha: 1).cgColor] as CFArray,
                                 locations: [0, 1]) {
            context.drawRadialGradient(glow,
                                       startCenter: CGPoint(x: inset.origin.x + 355, y: inset.origin.y + 74),
                                       startRadius: 2,
                                       endCenter: CGPoint(x: inset.origin.x + 355, y: inset.origin.y + 74),
                                       endRadius: 40,
                                       options: [])
        }

        // 3) Transforms: one square, stamped around a ring with
        // save/translate/rotate — the classic transform rosette.
        "Transform rosette".draw(at: NSMakePoint(inset.origin.x + 440, inset.origin.y + 10), withAttributes: attributes)
        let rosetteCenter = CGPoint(x: inset.origin.x + 500, y: inset.origin.y + 78)
        let petals = 10
        for index in 0..<petals {
            context.saveGState()
            context.translateBy(x: rosetteCenter.x, y: rosetteCenter.y)
            context.rotate(by: CGFloat(index) * (2 * .pi / CGFloat(petals)))
            context.translateBy(x: 26, y: 0)
            let shade = 0.35 + 0.6 * Double(index) / Double(petals)
            context.setFillColor(NSColor(calibratedRed: shade, green: 0.30, blue: 1 - shade, alpha: 1).cgColor)
            context.fill(CGRect(x: -8, y: -8, width: 16, height: 16))
            context.restoreGState()
        }

        // 4) The BMP-round-tripped sprite, read back pixel by pixel and drawn as cells —
        //    proving the decode produced the bytes that went in. Apple's pixel accessor is
        //    NSBitmapImageRep.colorAt(x:y:); CGImage has none.
        "CGImage via BMP codec".draw(at: NSMakePoint(inset.origin.x + 650, inset.origin.y + 10), withAttributes: attributes)
        if let rep = Self.spriteRep {
            let cell: CGFloat = 11
            let originX = inset.origin.x + 660
            let originY = inset.origin.y + 34
            for y in 0..<rep.pixelsHigh {
                for x in 0..<rep.pixelsWide {
                    guard let pixel = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                          pixel.alphaComponent > 0 else {
                        continue
                    }

                    context.setFillColor(pixel.cgColor)
                    context.fill(CGRect(x: originX + CGFloat(x) * cell,
                                        y: originY + CGFloat(y) * cell,
                                        width: cell - 1, height: cell - 1))
                }
            }
        }

        // 5) NSImage(data:): the same sprite as PNG bytes, decoded by
        // WinCoreGraphics and blitted through the data-backed draw path — the
        // 3.13 in-memory boundary, now closed.
        "NSImage(data:) → CGImage".draw(at: NSMakePoint(inset.origin.x + 840, inset.origin.y + 10), withAttributes: attributes)
        if let dataImage = Self.dataBackedSprite {
            dataImage.draw(in: NSMakeRect(inset.origin.x + 850, inset.origin.y + 40, 96, 96))
        }
    }

    /// The sprite re-expressed as a BMP-data-backed `NSImage`, so the demo
    /// exercises the full data → CGImage → native-blit path live. (The demo is
    /// single-threaded on the UI thread, so the unchecked static is safe.)
    nonisolated(unsafe) static let dataBackedSprite: NSImage? = {
        guard let bmp = spriteRep?.representation(using: .bmp, properties: [:]) else {
            return nil
        }

        return NSImage(data: bmp)
    }()
}

// MARK: - "New in 3.x" showcase views

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
        nonisolated(unsafe) let handler = onClick
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
        nonisolated(unsafe) let handler = onEvent
        let message = "Hover entered (mouseEntered)"
        MainActor.assumeIsolated {
            handler?(message)
        }
    }

    override func mouseExited(with event: NSEvent) {
        hovering = false
        needsDisplay = true
        nonisolated(unsafe) let handler = onEvent
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
        nonisolated(unsafe) let handler = onEvent
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
        nonisolated(unsafe) let handler = onEvent
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
        nonisolated(unsafe) let handler = onEvent
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

/// Data source for the showcase's framework-drawn (view-based) table (5.5).
final class DemoViewTableDataSource: NSObject, NSTableViewDataSource {
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
        tableColumn?.identifier.rawValue == "note" ? notes[row] : tasks[row]
    }

    func tableView(_ tableView: NSTableView, setObjectValue object: Any?, for tableColumn: NSTableColumn?, row: Int) {
        guard tableColumn?.identifier.rawValue == "note" else {
            return
        }
        notes[row] = object.map { String(describing: $0) } ?? ""
    }

    // MARK: Row reorder — AppKit's drag-and-drop data-source recipe
    // (a `.move` local mask + a pasteboard writer per row + acceptDrop).

    /// Reported after a reorder so the page can update its status line.
    var onReorder: (@MainActor (_ movedCount: Int, _ destination: Int) -> Void)?

    /// Apple declares this returning `NSPasteboardWriting?`, and the type matters: this is
    /// an `@objc` protocol with *optional* methods, so a signature that does not match the
    /// requirement is never exposed to Objective-C and AppKit simply never calls it —
    /// `responds(to: "tableView:pasteboardWriterForRow:")` is **false**. Declared
    /// `-> Any?` (as the chocolate frameworks' own protocol has it) the drag silently
    /// carried no data and every row snapped back, with no error anywhere.
    /// `NSString` is the writer here because Swift's `String` does not itself conform.
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        "\(row)" as NSString
    }

    /// Required by AppKit for a drop to be accepted at all: without a validate that
    /// returns a real operation, `acceptDrop` is never reached and the row snaps back.
    ///
    /// Reordering only ever means "between rows" (`.above`). AppKit proposes `.on`
    /// whenever the pointer is over a row's *body* — which is nearly the whole table — so
    /// rejecting `.on` outright left only the hairline gap between rows as a valid target
    /// and the row snapped back almost everywhere. Retarget `.on` to the nearest gap with
    /// `setDropRow(_:dropOperation:)` instead: that is the standard reorder recipe, and it
    /// makes the whole table a drop target while still only ever inserting between rows.
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int,
                   proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if dropOperation == .on {
            tableView.setDropRow(row, dropOperation: .above)
        }

        return .move
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row toIndex: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard dropOperation == .above else {
            return false
        }

        // One pasteboard *item* per dragged row — that is what a writer-per-row produces.
        // This used to read `draggingPasteboard.string(forType:)` and split it on commas,
        // which is a single-string format: on AppKit that call returns only the *first*
        // item, so a multi-row drag silently moved just one row.
        let sortedRows = (info.draggingPasteboard.pasteboardItems ?? [])
            .compactMap { Int($0.string(forType: .string) ?? "") }
            .sorted()
        guard !sortedRows.isEmpty, sortedRows.allSatisfy({ tasks.indices.contains($0) }) else {
            return false
        }

        // Move one or many rows (parallel model arrays) to the drop index.
        let dest = toIndex - sortedRows.filter { $0 < toIndex }.count
        let movedTasks = sortedRows.map { tasks[$0] }
        let movedNotes = sortedRows.map { notes[$0] }
        let movedDone = sortedRows.map { done[$0] }
        for row in sortedRows.reversed() {
            tasks.remove(at: row)
            notes.remove(at: row)
            done.remove(at: row)
        }
        tasks.insert(contentsOf: movedTasks, at: dest)
        notes.insert(contentsOf: movedNotes, at: dest)
        done.insert(contentsOf: movedDone, at: dest)

        // The model moved; the view has no idea. A table does NOT reload itself after a
        // drop — the data source owns the model, so it has to say when it changed. Without
        // this the drop succeeds (this returns true, the model is correct) and the rows
        // keep rendering in the old order, which looks *exactly* like the drag snapping
        // back. Re-select the moved rows so the result is visible, as a reorder should.
        tableView.reloadData()
        tableView.selectRowIndexes(IndexSet(dest..<(dest + sortedRows.count)), byExtendingSelection: false)

        nonisolated(unsafe) let handler = onReorder
        MainActor.assumeIsolated {
            handler?(sortedRows.count, dest)
        }
        return true
    }
}

/// Delegate that vends a real control per cell so the drawn table hosts them
/// inside its cells — something a native list view can't do.
final class DemoViewTableDelegate: NSObject, NSTableViewDelegate {
    let source: DemoViewTableDataSource
    var onEvent: (@MainActor (String) -> Void)?

    init(source: DemoViewTableDataSource) {
        self.source = source
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if tableColumn?.identifier.rawValue == "task" {
            let field = NSTextField(string: source.tasks[row], frame: NSMakeRect(0, 0, 200, 22))
            field.isBordered = false
            field.drawsBackground = false
            return field
        }
        // The "note" column is editable: double-click a note to edit it.
        //
        // This used to `return nil` and rely on the table painting the column itself as
        // drawn text. AppKit has no such per-column fallback — a table is view-based or
        // cell-based, and this one is view-based because the delegate vends views at all,
        // so a nil view means an *empty cell*, with nothing to double-click. The column
        // has to vend an editable field like any other view-based column.
        if tableColumn?.identifier.rawValue == "note" {
            let field = NSTextField(string: source.notes[row], frame: NSMakeRect(0, 0, 160, 22))
            field.isBordered = false
            field.drawsBackground = false
            field.isEditable = true
            field.onAction = { [weak self] control in
                guard let self, let edited = control as? NSTextField else {
                    return
                }
                self.source.notes[row] = edited.stringValue
                nonisolated(unsafe) let handler = onEvent
                let message = "Note \(row) → \(edited.stringValue)"
                MainActor.assumeIsolated {
                    handler?(message)
                }
            }
            return field
        }
        let button = NSButton(title: source.done[row] ? "Done ✓" : "Mark done", frame: NSMakeRect(0, 0, 110, 22))
        button.onAction = { [weak self, weak tableView] _ in
            guard let self else {
                return
            }
            self.source.done[row].toggle()
            nonisolated(unsafe) let handler = onEvent
            let message = "Row \(row) → \(self.source.done[row] ? "done" : "not done")"
            MainActor.assumeIsolated {
                handler?(message)
            }
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
final class DemoStatusRowDataSource: NSObject, NSTableViewDataSource {
    let items: [(stage: String, status: String)] = [
        ("Build", "passing"), ("Unit tests", "passing"), ("Lint", "warning"),
        ("Deploy", "failed"), ("Docs", "passing"), ("Package", "passing"),
    ]
    func numberOfRows(in tableView: NSTableView) -> Int { items.count }
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        tableColumn?.identifier.rawValue == "stage" ? items[row].stage : items[row].status
    }
}

final class DemoStatusRowDelegate: NSObject, NSTableViewDelegate {
    let source: DemoStatusRowDataSource
    init(source: DemoStatusRowDataSource) { self.source = source }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        // Hosted (transparent) labels sit above the colored row view.
        let text = tableColumn?.identifier.rawValue == "stage" ? source.items[row].stage : source.items[row].status
        let field = NSTextField(string: text, frame: NSMakeRect(0, 0, 120, 20))
        field.isBordered = false
        field.drawsBackground = false
        return field
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
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
/// The document is its editor's real `NSTextViewDelegate` — the plain AppKit
/// idiom for tracking dirty state.
final class DemoNoteDocument: NSDocument, NSTextViewDelegate {
    // The delegate conformance infers @MainActor on the class; NSDocument's
    // read/write overrides stay nonisolated, so the backing text opts out
    // (the demo is single-threaded).
    nonisolated(unsafe) var text = ""

    override func data(ofType typeName: String) throws -> Data {
        Data(Array(text.utf8))
    }

    override func read(from data: Data, ofType typeName: String) throws {
        text = String(decoding: data, as: UTF8.self)
    }

    func textDidChange(_ notification: Notification) {
        guard let editor = notification.object as? NSTextView else {
            return
        }

        text = editor.string
        updateChangeCount(.changeDone)
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
        editor.delegate = self
        let noteContent = DemoPageView(frame: NSMakeRect(0, 0, 460, 320))
        noteContent.addSubview(editor)
        noteWindow.contentView = noteContent
        addWindowController(NSWindowController(window: noteWindow))
    }
}


/// Reports split-view divider drags in the status label.
final class DemoSplitDelegate: NSObject, NSSplitViewDelegate {
    var onResize: (@MainActor () -> Void)?

    func splitViewDidResizeSubviews(_ notification: Notification) {
        nonisolated(unsafe) let handler = onResize
        MainActor.assumeIsolated {
            handler?()
        }
    }
}

let demoSplitDelegate = DemoSplitDelegate()

/// Enables Edit-menu items from the notes text view's undo stacks.
final class EditMenuController: NSObject, NSMenuItemValidation {
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

final class DemoTableDataSource: NSObject, NSTableViewDataSource {
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

final class DemoOutlineDataSource: NSObject, NSOutlineViewDataSource {
    var roots = ["Application", "Controls", "Tables"]
    var children: [String: [String]] = [
        "Application": ["NSApplication", "NSWindow", "NSMenu"],
        "Controls": ["NSButton", "NSTextField", "NSMatrix"],
        "Tables": ["NSTableView", "NSOutlineView", "NSTableColumn"]
    ]

    /// Moves `item` to `childIndex` under `parent` (nil = the root list),
    /// supporting **reparenting** — the item is pulled out of wherever it
    /// currently lives (root or any branch) and inserted under the target,
    /// adjusting the index when it moved down within the same list.
    func moveItem(_ item: String, under parent: Any?, to childIndex: Int) {
        let targetKey = parent.map { String(describing: $0) }
        var adjust = 0
        if let idx = roots.firstIndex(of: item) {
            if targetKey == nil, idx < childIndex { adjust = 1 }
            roots.remove(at: idx)
        }
        for key in children.keys {
            if let idx = children[key]?.firstIndex(of: item) {
                if targetKey == key, idx < childIndex { adjust = 1 }
                children[key]?.remove(at: idx)
            }
        }
        let dest = max(0, childIndex - adjust)
        if let targetKey {
            var list = children[targetKey] ?? []
            list.insert(item, at: min(dest, list.count))
            children[targetKey] = list
        } else {
            roots.insert(item, at: min(dest, roots.count))
        }
    }

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

    // MARK: Sibling/reparenting reorder — AppKit's drag-and-drop recipe
    // (a `.move` local mask + a pasteboard writer per item + acceptDrop).

    /// Reported after a reorder so the page can update its status line.
    var onReorder: (@MainActor (_ movedItem: String, _ childIndex: Int) -> Void)?

    func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> NSPasteboardWriting? {
        String(describing: item) as NSString
    }

    func outlineView(_ outlineView: NSOutlineView, acceptDrop info: NSDraggingInfo, item parent: Any?, childIndex index: Int) -> Bool {
        guard let moved = info.draggingPasteboard.string(forType: .string) else {
            return false
        }
        moveItem(moved, under: parent, to: index)
        nonisolated(unsafe) let handler = onReorder
        MainActor.assumeIsolated {
            handler?(moved, index)
        }
        return true
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

final class DemoBrowserDataSource: NSObject, NSBrowserDelegate {
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

    /// The item-based browser interface requires all four of
    /// `numberOfChildrenOfItem`, `child:ofItem:`, `isLeafItem:` and
    /// `objectValueForItem:`. AppKit probes for them with `respondsToSelector:`
    /// and silently falls back to the old matrix-based interface — raising
    /// "Illegal NSBrowser delegate" — if any one is absent. A Swift
    /// protocol-extension default does not satisfy that probe, so this must be
    /// implemented here rather than defaulted by the framework.
    func browser(_ browser: NSBrowser, objectValueForItem item: Any?) -> Any? {
        item.map { String(describing: $0) }
    }
}

final class DemoCollectionDataSource: NSObject, NSCollectionViewDataSource {
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
final class DemoFlowCollectionDataSource: NSObject, NSCollectionViewDataSource {
    /// Reuse identifiers for the section band views. AppKit requires every
    /// supplementary view to be registered under an identifier and then vended
    /// by `makeSupplementaryView` — returning a freshly built view raises
    /// "was not retrieved by calling -makeSupplementaryViewOfKind:…".
    static let headerID = NSUserInterfaceItemIdentifier("DemoSectionHeader")
    static let footerID = NSUserInterfaceItemIdentifier("DemoSectionFooter")

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

    func collectionView(_ collectionView: NSCollectionView, viewForSupplementaryElementOfKind kind: NSCollectionView.SupplementaryElementKind, at indexPath: IndexPath) -> NSView {
        let section = sections[indexPath.section]
        // Resolve the appearance live (not the cached launch value) so bands
        // recreated during a redraw after a system switch pick up the new look.
        let dark = NSApplication.shared.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        if kind == NSCollectionView.elementKindSectionHeader {
            let header = collectionView.makeSupplementaryView(
                ofKind: kind, withIdentifier: Self.headerID, for: indexPath) as! NSTextField
            header.stringValue = "  \(section.title)"
            header.isBordered = false
            header.isEditable = false
            header.font = NSFont.boldSystemFont(ofSize: 12)
            // Appearance-aware band so the dynamic label color stays legible.
            header.drawsBackground = true
            header.backgroundColor = dark
                ? NSColor(red: 0.16, green: 0.22, blue: 0.34, alpha: 1)
                : NSColor(red: 0.90, green: 0.93, blue: 0.98, alpha: 1)
            return header
        }
        if kind == NSCollectionView.elementKindSectionFooter {
            let footer = collectionView.makeSupplementaryView(
                ofKind: kind, withIdentifier: Self.footerID, for: indexPath) as! NSTextField
            footer.stringValue = "  — \(section.items.count) classes —"
            footer.isBordered = false
            footer.isEditable = false
            footer.font = NSFont.boldSystemFont(ofSize: 10)
            footer.textColor = dark ? NSColor(white: 0.75, alpha: 1) : NSColor(white: 0.35, alpha: 1)
            footer.drawsBackground = true
            footer.backgroundColor = dark
                ? NSColor(red: 0.30, green: 0.27, blue: 0.20, alpha: 1)
                : NSColor(red: 0.95, green: 0.93, blue: 0.88, alpha: 1)
            return footer
        }
        // Unhandled kinds return an empty view (the protocol's return is
        // non-optional, as on Apple).
        return NSView()
    }
}

/// Sizes each collection item to fit its label, demonstrating per-item flow
/// sizing (`NSCollectionViewDelegateFlowLayout`).
final class DemoFlowSizeDelegate: NSObject, NSCollectionViewDelegateFlowLayout {
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
let bezelsPage = DemoPageView(frame: NSMakeRect(0, 144, 1120, 560))
let layoutPage = DemoPageView(frame: NSMakeRect(0, 144, 1120, 560))
let coreGraphicsPage = DemoPageView(frame: NSMakeRect(0, 144, 1120, 560))
let stressPage = DemoPageView(frame: NSMakeRect(0, 144, 1120, 560))
let nibPage = DemoPageView(frame: NSMakeRect(0, 144, 1120, 560))
valuesPage.isHidden = true
tablesPage.isHidden = true
drawingPage.isHidden = true
showcasePage.isHidden = true
listsPage.isHidden = true
bezelsPage.isHidden = true
layoutPage.isHidden = true
coreGraphicsPage.isHidden = true
stressPage.isHidden = true
nibPage.isHidden = true
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
let secureTextField = NSSecureTextField(frame: NSMakeRect(152, 120, 240, 28))
let alertButton = NSButton(title: "Alert", frame: NSMakeRect(32, 152, 100, 34))
let titleCheckbox = NSButton(title: "Show count in title", frame: NSMakeRect(152, 152, 228, 34))
let alertStyleBox = NSBox(title: "Alert Style", frame: NSMakeRect(448, 120, 248, 116))
let alertStyleLabel = NSTextField(string: "Alert style:", frame: NSMakeRect(472, 156, 112, 24))
// A pop-up button is one control row tall (AppKit draws it at ~26pt; the menu is not
// part of the frame). The old 96 came from Win32, where a COMBOBOX's creation height
// has to include its drop-down list — WinChocolate already handles that quirk itself
// (`max(frame.size.height, 160)` in Win32PopUpControls), so the frame here is just the
// button, as on Apple. At 96 it overflowed the Alert Style box by 46pt.
let alertStylePopup = NSPopUpButton(frame: NSMakeRect(472, 186, 184, 26), pullsDown: false)
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
// Apple deprecated NSForm in macOS 10.10: "Use NSTextField directly instead, and
// consider NSStackView for layout assistance." The page shows both — the recommended
// NSTextField rows here, and the deprecated NSForm below the matrix — so the two can be
// compared side by side.
let formLabel = NSTextField(string: "Form:", frame: NSMakeRect(744, 120, 80, 24))
let contactNameLabel = NSTextField(string: "Name:", frame: NSMakeRect(824, 120, 60, 24))
let contactNameField = NSTextField(string: "WinChocolate", frame: NSMakeRect(888, 120, 192, 24))
let contactStatusLabel = NSTextField(string: "Status:", frame: NSMakeRect(824, 152, 60, 24))
let contactStatusField = NSTextField(string: "Native", frame: NSMakeRect(888, 152, 192, 24))
let matrixLabel = NSTextField(string: "Matrix:", frame: NSMakeRect(744, 240, 80, 24))
let matrix = NSMatrix(
    frame: NSMakeRect(824, 240, 240, 72),
    mode: .trackModeMatrix,
    prototype: NSButtonCell(textCell: "Choice"),
    numberOfRows: 2,
    numberOfColumns: 2
)
// The deprecated original. Deprecated is not removed: Apple still ships NSForm, so both
// chocolate frameworks owe it exact parity for as long as Apple does, and the demo
// covers it alongside the NSTextField replacement above. Both sections are expected to
// render correctly on all three targets. This one drops when Apple drops NSForm — not
// before. See DEMO_CHANGES.md for the MUST FIX list its #if below depends on.
let deprecatedFormLabel = NSTextField(string: "Form:", frame: NSMakeRect(744, 372, 80, 24))
let deprecatedFormNote = NSTextField(string: "NSForm — deprecated (macOS 10.10)", frame: NSMakeRect(824, 344, 240, 18))
let form = NSForm(frame: NSMakeRect(824, 372, 256, 92))
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
// A .clockAndCalendar picker draws a calendar AND a clock side by side. AppKit's
// intrinsicContentSize is 275.5 x 148, so the old 224-wide frame clipped the clock off
// the right edge — widened to 276 to fit it. The 168 height is deliberate and stays:
// WinChocolate's calendar needs the extra room, and AppKit is happy in a taller frame
// (148 is its minimum, not its maximum).
let calendarPicker = NSDatePicker(date: Date(timeIntervalSince1970: 1_780_272_000), frame: NSMakeRect(724, 88, 276, 168))
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
let imageView = DemoClickableImageView(frame: NSMakeRect(152, 28, 300, 190))
let clipLabel = NSTextField(string: "Clip view:", frame: NSMakeRect(496, 28, 104, 24))
let clipView = NSClipView(frame: NSMakeRect(616, 28, 220, 110))
let clipDocumentView = DemoFilledView(frame: NSMakeRect(0, 0, 420, 220))
let clipTopLeftPane = DemoFilledView(frame: NSMakeRect(0, 0, 210, 110))
let clipTopRightPane = DemoFilledView(frame: NSMakeRect(210, 0, 210, 110))
let clipBottomLeftPane = DemoFilledView(frame: NSMakeRect(0, 110, 210, 110))
let clipBottomRightPane = DemoFilledView(frame: NSMakeRect(210, 110, 210, 110))
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
let splitLeftPane = DemoFilledView(frame: NSZeroRect)
let splitRightPane = DemoFilledView(frame: NSZeroRect)
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
let openToolbarItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("open"))
let saveToolbarItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("save"))
let toolbarSeparatorItem = NSToolbarItem(itemIdentifier: .separator)
let toolbarFlexibleSpaceItem = NSToolbarItem(itemIdentifier: .flexibleSpace)
let pageToolbarItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("pageSelector"))
let toolbarSearchField = NSSearchField(frame: NSMakeRect(0, 0, 160, 24))
let searchToolbarItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("toolbarSearch"))
let toggleToolbarItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("toggleToolbar"))
let customizeToolbarItem = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("customizeToolbar"))
let contentFocusColor = NSColor(calibratedRed: 0.92, green: 0.97, blue: 1.0, alpha: 1.0)
let normalContentColor = NSColor.windowBackgroundColor
// The focus tint and resting field face follow the appearance so the focus
// demo reads correctly in dark mode too (resolved once at launch, matching
// the process-wide appearance binding).
let isDarkDemo = NSApplication.shared.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
let controlFocusColor = isDarkDemo
    ? NSColor(calibratedRed: 0.35, green: 0.32, blue: 0.12, alpha: 1.0)
    : NSColor(calibratedRed: 1.0, green: 0.96, blue: 0.72, alpha: 1.0)
let normalTextFieldColor = NSColor.controlBackgroundColor
// Value/echo labels: the classic demo blue is illegible on the dark surface,
// so dark mode lightens it (labels on explicit light bands keep plain blue).
let demoValueTextColor = isDarkDemo
    ? NSColor(calibratedRed: 0.45, green: 0.68, blue: 1.0, alpha: 1.0)
    : NSColor.blue
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

let demoArtworkPath = demoResourcePath(named: "WinChocolateArtworkDemo")
let demoIconPath = demoIconResourcePath()
let demoScreenArtworkPath = demoResourcePath(named: "WinChocolateScreenArtworkDemo")
let demoPngPath = demoResourcePath(named: "WinChocolatePngDemo", ofType: "png")
// Toolbar artwork: Tabler Icons (MIT), rendered from their 24×24 outline SVGs to 64px PNGs
// — folder-open, device-floppy, ban, adjustments-horizontal. They are black-on-transparent,
// so `isTemplate = true` lets each framework tint them for the current appearance instead of
// the demo shipping a light and a dark copy. 64px into a 32pt item is exactly 1:1 on retina.
let toolbarOpenImagePath = demoResourcePath(named: "ToolbarOpen", ofType: "png")
let toolbarSaveImagePath = demoResourcePath(named: "ToolbarSave", ofType: "png")
let toolbarToggleImagePath = demoResourcePath(named: "ToolbarToggle", ofType: "png")
let toolbarCustomizeImagePath = demoResourcePath(named: "ToolbarCustomize", ofType: "png")
var imageModeIndex = 0
let imageModes: [(NSImageScaling, NSImageAlignment, String, String)] = [
    (.scaleProportionallyDown, .alignCenter, demoArtworkPath, "bird center/down"),
    (.scaleProportionallyUpOrDown, .alignTopLeft, demoScreenArtworkPath, "screen top-left/fit"),
    (.scaleAxesIndependently, .alignBottomRight, demoArtworkPath, "bird bottom-right/axes"),
    (.scaleNone, .alignRight, demoScreenArtworkPath, "screen right/none"),
    (.scaleProportionallyDown, .alignCenter, demoPngPath, "png center/down")
]

final class DemoToolbarDelegate: NSObject, NSToolbarDelegate {
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

/// Reads a cell's display string the plain-AppKit way: ask the table's data
/// source for the column/row object value (there is no cell-string accessor
/// on Apple's `NSTableView`).
@MainActor
func demoTableCellString(_ table: NSTableView, column: Int, row: Int) -> String? {
    guard row >= 0, table.tableColumns.indices.contains(column) else {
        return nil
    }

    // Ask through the concrete demo source: the protocol requirement is
    // @objc-optional on Apple, so a generic protocol call spells differently
    // per platform — the concrete method is identical on both.
    let value = (table.dataSource as? DemoTableDataSource)?
        .tableView(table, objectValueFor: table.tableColumns[column], row: row)
    return (value as? String) ?? value.map { String(describing: $0) }
}

@MainActor
func tableRowSummary(_ table: NSTableView, prefix: String) -> String {
    let row = table.clickedRow
    if row >= 0,
       let name = demoTableCellString(table, column: 0, row: row),
       let status = demoTableCellString(table, column: 1, row: row) {
        let column = table.clickedColumn
        if column >= 0, table.tableColumns.indices.contains(column) {
            return "\(prefix): row \(row + 1), \(table.tableColumns[column].title) - \(name) - \(status)"
        }

        return "\(prefix): row \(row + 1) - \(name) - \(status)"
    }

    return "\(prefix): no row"
}

@MainActor
func tableColumnSummary(_ table: NSTableView) -> String? {
    let column = table.clickedColumn
    guard table.clickedRow < 0,
          column >= 0,
          table.tableColumns.indices.contains(column) else {
        return nil
    }

    return "Table column: \(table.tableColumns[column].title)"
}

@MainActor
func selectedTableRowValues(_ table: NSTableView) -> [String]? {
    guard table.selectedRow >= 0 else {
        return nil
    }

    let values = (0..<table.numberOfColumns).map { column in
        demoTableCellString(table, column: column, row: table.selectedRow) ?? ""
    }
    return values.isEmpty ? nil : values
}

@discardableResult
@MainActor
func selectTableRow(matching values: [String], in table: NSTableView) -> Bool {
    for row in 0..<table.numberOfRows {
        let rowValues = (0..<table.numberOfColumns).map { column in
            demoTableCellString(table, column: column, row: row) ?? ""
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
    // NSForm and NSMatrix are cell-based on Apple — focus inside them is
    // identified by containment, not by child-view identity.
    if let view = responder as? NSView, view.isDescendant(of: form) {
        return "form"
    }
    if let view = responder as? NSView, view.isDescendant(of: matrix) {
        return "matrix"
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
    // The content view is the container for every page, so tinting its whole
    // background on focus turns the entire app blue (and shows through/around the
    // pages on resize and tab switches, reading as a repaint bug). Keep the
    // container at its normal color and show content focus only via the label
    // above; the small input controls below still demo their own focus tint.
    // Resolve the surface from the live appearance (windowBackgroundColor is
    // dynamic) — a cached launch value would clobber the content background back
    // to the old shade after a system switch.
    contentView.backgroundColor = NSColor.windowBackgroundColor
    // Resolve the focus tint from the live appearance so a system switch while a
    // field is focused rebuilds its brush at the new shade.
    let controlFocusColor = NSApplication.shared.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        ? NSColor(calibratedRed: 0.35, green: 0.32, blue: 0.12, alpha: 1.0)
        : NSColor(calibratedRed: 1.0, green: 0.96, blue: 0.72, alpha: 1.0)
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
// Under dark mode the status/focus bands go neutral (a subtle field lifted just
// off the page) and let the text carry the info-blue / attention-amber meaning,
// so they sit with the theme instead of reading as colored slabs. Light mode
// keeps the classic tinted bands.
statusLabel.textColor = isDarkDemo ? NSColor(calibratedRed: 0.55, green: 0.78, blue: 1.0, alpha: 1) : .blue
statusLabel.backgroundColor = isDarkDemo
    ? NSColor(white: 0.16, alpha: 1)
    : NSColor(calibratedRed: 0.94, green: 0.97, blue: 1.0, alpha: 1.0)
focusLabel.font = NSFont.boldSystemFont(ofSize: 12)
focusLabel.textColor = isDarkDemo ? NSColor(calibratedRed: 1.0, green: 0.83, blue: 0.4, alpha: 1) : .black
focusLabel.backgroundColor = isDarkDemo
    ? NSColor(white: 0.16, alpha: 1)
    : NSColor(calibratedRed: 1.0, green: 0.98, blue: 0.86, alpha: 1.0)
slider.frame = NSMakeRect(120, 28, 184, 28)
// Captions, not input fields — same reason as the Controls page: NSTextField(string:)
// builds an editable, bordered field, so every caption must switch that off.
for caption in [sliderLabel, verticalSliderLabel, progressLabel, stepperLabel,
                comboLabel, searchLabel, levelLabel, colorWellLabel, segmentedLabel,
                scrollerLabel, dateLabel, calendarLabel, ratingLabel] {
    caption.isBordered = false
    caption.drawsBackground = false
    caption.isEditable = false
    caption.isSelectable = false
}
sliderLabel.font = NSFont.boldSystemFont(ofSize: 12)
sliderValueLabel.textColor = demoValueTextColor
progressLabel.font = NSFont.boldSystemFont(ofSize: 12)
// An NSProgressIndicator is INDETERMINATE by default, and an indeterminate bar ignores
// doubleValue entirely — it stores the value but animates a barber pole instead. This is
// what stopped the bar tracking the slider; the determinate bar must ask for it.
progressIndicator.isIndeterminate = false
progressIndicator.minValue = 0
progressIndicator.maxValue = 100
progressIndicator.doubleValue = slider.doubleValue
stepperLabel.font = NSFont.boldSystemFont(ofSize: 12)
stepper.minValue = 0
stepper.maxValue = 100
stepper.increment = 1
stepper.doubleValue = 50
stepperValueLabel.textColor = demoValueTextColor
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
// Show the separated segment style (8.3): the segments stand apart as
// individual pills rather than a joined strip.
segmentedControl.segmentStyle = .separated
segmentedControl.selectedSegment = 0
scrollerLabel.font = NSFont.boldSystemFont(ofSize: 12)
// An NSScroller starts DISABLED (unlike other controls), which leaves usableParts at
// .noScrollerParts — no knob is drawn and nothing responds, however you set the value or
// style. Enabling it flips usableParts to .allScrollerParts.
scroller.isEnabled = true
scroller.doubleValue = 0
scroller.knobProportion = 0.25
scrollerValueLabel.textColor = demoValueTextColor
dateLabel.font = NSFont.boldSystemFont(ofSize: 12)
datePicker.minDate = Date(timeIntervalSince1970: 1_735_689_600)
datePicker.maxDate = Date(timeIntervalSince1970: 1_893_456_000)
// Show both date and time fields (3.1 datePickerElements).
datePicker.datePickerElements = [.yearMonthDay, .hourMinuteSecond]
dateValueLabel.textColor = demoValueTextColor
dateValueLabel.stringValue = datePicker.stringValue
pageSelector.addItems(withTitles: ["Controls", "Values", "Tables/Media", "Drawing", "New in 3.x", "Lists (5.x)", "Bezels (8.3)", "Auto Layout (9.x)", "CoreGraphics (13)", "Scroll Stress", "Nib (15)"])
imageLabel.font = NSFont.boldSystemFont(ofSize: 12)
imageView.image = NSImage(contentsOfFile: demoArtworkPath) ?? NSImage(named: "WinChocolate artwork")
imageView.imageFrameStyle = .grayBezel
clipLabel.font = NSFont.boldSystemFont(ofSize: 12)
clipOriginLabel.textColor = demoValueTextColor
// The demonstrative quadrant/pane colors keep their hues but darken in dark
// mode so the panels read as distinct tiles rather than bright light slabs.
clipView.backgroundColor = isDarkDemo ? NSColor(calibratedRed: 0.14, green: 0.14, blue: 0.15, alpha: 1.0) : .white
clipDocumentView.backgroundColor = isDarkDemo
    ? NSColor(calibratedRed: 0.17, green: 0.17, blue: 0.18, alpha: 1.0)
    : NSColor(calibratedRed: 0.97, green: 0.97, blue: 0.97, alpha: 1.0)
clipTopLeftPane.backgroundColor = isDarkDemo
    ? NSColor(calibratedRed: 0.16, green: 0.24, blue: 0.36, alpha: 1.0)
    : NSColor(calibratedRed: 0.84, green: 0.92, blue: 1.0, alpha: 1.0)
clipTopRightPane.backgroundColor = isDarkDemo
    ? NSColor(calibratedRed: 0.34, green: 0.29, blue: 0.14, alpha: 1.0)
    : NSColor(calibratedRed: 1.0, green: 0.94, blue: 0.72, alpha: 1.0)
clipBottomLeftPane.backgroundColor = isDarkDemo
    ? NSColor(calibratedRed: 0.16, green: 0.30, blue: 0.18, alpha: 1.0)
    : NSColor(calibratedRed: 0.86, green: 1.0, blue: 0.86, alpha: 1.0)
clipBottomRightPane.backgroundColor = isDarkDemo
    ? NSColor(calibratedRed: 0.34, green: 0.18, blue: 0.20, alpha: 1.0)
    : NSColor(calibratedRed: 1.0, green: 0.86, blue: 0.88, alpha: 1.0)
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
splitLeftPane.backgroundColor = isDarkDemo
    ? NSColor(calibratedRed: 0.16, green: 0.25, blue: 0.37, alpha: 1.0)
    : NSColor(calibratedRed: 0.86, green: 0.93, blue: 1.0, alpha: 1.0)
splitRightPane.backgroundColor = isDarkDemo
    ? NSColor(calibratedRed: 0.35, green: 0.28, blue: 0.17, alpha: 1.0)
    : NSColor(calibratedRed: 1.0, green: 0.92, blue: 0.84, alpha: 1.0)
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
deprecatedFormLabel.font = NSFont.boldSystemFont(ofSize: 12)
deprecatedFormNote.font = NSFont.systemFont(ofSize: 11)
// Captions, not input fields: NSTextField(string:) builds an *editable, bordered*
// field, so a caption must switch both off (the demo's showcaseSectionLabel idiom).
for caption in [alertStyleLabel, formLabel, matrixLabel,
                deprecatedFormLabel, deprecatedFormNote,
                contactNameLabel, contactStatusLabel] {
    caption.isBordered = false
    caption.drawsBackground = false
    caption.isEditable = false
    caption.isSelectable = false
}
// Title widths live on the cells, as on Apple.
let formNameCell = form.addEntry("Name:")
let formStatusCell = form.addEntry("Status:")
formNameCell.titleWidth = 72
formStatusCell.titleWidth = 72
formNameCell.stringValue = "WinChocolate"
formStatusCell.stringValue = "Native"
// Both lines below are unreachable on WinChocolate/LinChocolate and exist only because
// those frameworks diverge from Apple; delete the #if once they match (see the MUST ADD
// list in DEMO_CHANGES.md).
//
//  • cellSize — Apple's NSForm is an NSMatrix subclass whose cellSize starts at
//    height 0, so every row collapses onto the next until the caller sets it (measured:
//    font, autosizesCells and sizeToCells all leave it at 0). The chocolate frameworks
//    expose a non-Apple `rowHeight` instead and do not inherit NSMatrix.
//  • setBezeled/setBordered — NSFormCell descends from NSActionCell and draws an
//    old-style bezel that reads as a heavy white outline in dark mode, unlike every
//    other field on the page. It has no bezelStyle, so the modern rounded bezel is
//    unreachable; a plain border is the closest match to the rest of the page.
#if !canImport(WinChocolate) && !canImport(LinChocolate)
form.cellSize = NSMakeSize(256, 26)
form.setBezeled(false)
form.setBordered(true)
#endif
// The NSTextField rows Apple points to instead of NSForm. Nothing to configure beyond
// the captions above: an NSTextField is already an editable, bezelled field, so these
// match every other text field on the page by construction.
contactNameField.isEditable = true
contactStatusField.isEditable = true
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
openToolbarItem.image?.isTemplate = true
openToolbarItem.minSize = NSMakeSize(32, 32)
openToolbarItem.maxSize = NSMakeSize(32, 32)
saveToolbarItem.label = "Save"
saveToolbarItem.paletteLabel = "Save"
saveToolbarItem.toolTip = "Toolbar save item"
saveToolbarItem.image = NSImage(contentsOfFile: toolbarSaveImagePath) ?? NSImage(systemSymbolName: "square.and.arrow.down", accessibilityDescription: "Save")
saveToolbarItem.image?.isTemplate = true
saveToolbarItem.minSize = NSMakeSize(32, 32)
saveToolbarItem.maxSize = NSMakeSize(32, 32)
toggleToolbarItem.label = "Disable Save"
toggleToolbarItem.paletteLabel = "Toggle Toolbar"
toggleToolbarItem.toolTip = "Enable or disable the Save toolbar item"
toggleToolbarItem.image = NSImage(contentsOfFile: toolbarToggleImagePath) ?? NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Toggle Save")
toggleToolbarItem.image?.isTemplate = true
toggleToolbarItem.minSize = NSMakeSize(32, 32)
toggleToolbarItem.maxSize = NSMakeSize(32, 32)
customizeToolbarItem.label = "Customize"
customizeToolbarItem.paletteLabel = "Customize Toolbar"
customizeToolbarItem.toolTip = "Customize the toolbar"
customizeToolbarItem.image = NSImage(contentsOfFile: toolbarCustomizeImagePath) ?? NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: "Customize Toolbar")
customizeToolbarItem.image?.isTemplate = true
customizeToolbarItem.minSize = NSMakeSize(32, 32)
customizeToolbarItem.maxSize = NSMakeSize(32, 32)
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
        NSToolbarItem.Identifier("open"),
        NSToolbarItem.Identifier("save"),
        NSToolbarItem.Identifier("pageSelector"),
        NSToolbarItem.Identifier("toolbarSearch"),
        .separator,
        .flexibleSpace,
        NSToolbarItem.Identifier("toggleToolbar"),
        NSToolbarItem.Identifier("customizeToolbar"),
        // Standard Apple items — synthesized by the framework (6.6): the
        // delegate returns nil for these and the built-in behaviors kick in.
        .showColors,
        .showFonts,
        .print
    ],
    defaultIdentifiers: [
        NSToolbarItem.Identifier("open"),
        NSToolbarItem.Identifier("save"),
        NSToolbarItem.Identifier("pageSelector"),
        NSToolbarItem.Identifier("toolbarSearch"),
        .separator,
        .flexibleSpace,
        NSToolbarItem.Identifier("toggleToolbar"),
        NSToolbarItem.Identifier("customizeToolbar")
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
// Customizations persist across launches (6.8): the configuration autosaves
// to UserDefaults under AppKit's "NSToolbar Configuration <id>" key and is
// restored when the toolbar attaches to the window.
demoToolbar.autosavesConfiguration = true
demoToolbar.delegate = demoToolbarDelegate
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
    bezelsPage.isHidden = index != 6
    layoutPage.isHidden = index != 7
    coreGraphicsPage.isHidden = index != 8
    stressPage.isHidden = index != 9
    nibPage.isHidden = index != 10
    updateFocusDisplay()
}

titleCheckbox.setButtonType(.switch)
titleCheckbox.state = .on
infoRadio.setButtonType(.radio)
warningRadio.setButtonType(.radio)
criticalRadio.setButtonType(.radio)
infoRadio.state = .on
alertStylePopup.addItems(withTitles: ["Info", "Warning", "Critical"])
// Tag each style so the alert can read the choice by tag, not title.
alertStylePopup.selectItem(withTitle: "Info")
let tableNameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
let tableStatusColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("status"))
tableNameColumn.title = "Name"
tableStatusColumn.title = "Status"
tableNameColumn.width = 250
tableStatusColumn.width = 240
tableNameColumn.sortDescriptorPrototype = NSSortDescriptor(key: "name", ascending: true)
tableStatusColumn.sortDescriptorPrototype = NSSortDescriptor(key: "status", ascending: true)
tableView.addTableColumn(tableNameColumn)
tableView.addTableColumn(tableStatusColumn)
tableView.dataSource = tableDataSource
// allowsColumnSelection stays at AppKit's default (false) so a header click *sorts*
// rather than selecting the whole column. Setting it true — as this demo used to — is
// Apple asking "do you want header clicks to select columns?", and answering yes: the
// entire Name column then highlights on every sort click, and selectColumnIndexes below
// pre-highlighted it at launch. (With the default, selectColumnIndexes is a no-op, so
// the row selection is the only one that survives — which is the intent here.)
tableView.reloadData()
tableView.selectRowIndexes([0], byExtendingSelection: false)
tableScrollView.hasVerticalScroller = true
tableScrollView.documentView = tableView
outlineLabel.font = NSFont.boldSystemFont(ofSize: 12)
let outlineNameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("outlineName"))
let outlineStatusColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("outlineStatus"))
outlineNameColumn.title = "Item"
outlineStatusColumn.title = "Kind"
outlineNameColumn.width = 160
outlineStatusColumn.width = 88
outlineView.addTableColumn(outlineNameColumn)
outlineView.addTableColumn(outlineStatusColumn)
outlineView.dataSource = outlineDataSource
// Drag a row to reorder it among its siblings (5.2) — the plain-AppKit
// recipe: a `.move` local source mask plus the outline data source's
// pasteboard writer and acceptDrop.
outlineView.setDraggingSourceOperationMask(.move, forLocal: true)
outlineDataSource.onReorder = { movedItem, childIndex in
    statusLabel.stringValue = "Moved \(movedItem) → index \(childIndex)"
}
outlineView.expandItem("Application")
outlineView.expandItem("Controls")
outlineView.reloadData()
outlineView.selectRowIndexes([0], byExtendingSelection: false)
outlineScrollView.hasVerticalScroller = true
outlineScrollView.documentView = outlineView

// MARK: - Scroll-stress page (flicker/paint tuning)
//
// A tall scrolling document packed with many native controls and interspersed
// with deliberately paint-heavy gradient bands, so scrolling and resizing this
// page exercise the repaint/coalescing pipeline under load.
let stressHeader = NSTextField(string: "Scroll stress — many controls + slow gradient bands. Scroll and resize to check for flicker.",
                               frame: NSMakeRect(12, 6, 1060, 22))
stressHeader.isEditable = false
stressHeader.isBordered = false
stressHeader.drawsBackground = false
stressHeader.font = NSFont.boldSystemFont(ofSize: 13)
stressPage.addSubview(stressHeader)

let stressScrollView = NSScrollView(frame: NSMakeRect(12, 34, 1096, 512))
stressScrollView.hasVerticalScroller = true
let stressDocView = DemoPageView(frame: NSMakeRect(0, 0, 1060, 10))

var stressY: CGFloat = 12
for i in 0..<28 {
    let rowLabel = NSTextField(string: "Row \(i + 1)", frame: NSMakeRect(12, stressY + 2, 64, 20))
    rowLabel.isEditable = false
    rowLabel.isBordered = false
    rowLabel.drawsBackground = false
    stressDocView.addSubview(rowLabel)

    let field = NSTextField(string: "Editable field \(i + 1)", frame: NSMakeRect(84, stressY, 180, 24))
    field.isEditable = true
    stressDocView.addSubview(field)

    let rowButton = NSButton(title: "Button \(i + 1)", frame: NSMakeRect(276, stressY, 120, 26))
    stressDocView.addSubview(rowButton)

    let slider = NSSlider(frame: NSMakeRect(408, stressY, 150, 24))
    slider.minValue = 0
    slider.maxValue = 100
    slider.doubleValue = Double((i * 7) % 100)
    stressDocView.addSubview(slider)

    let popup = NSPopUpButton(frame: NSMakeRect(570, stressY, 130, 26))
    popup.addItems(withTitles: ["Alpha", "Beta", "Gamma", "Delta"])
    popup.selectItem(at: i % 4)
    stressDocView.addSubview(popup)

    let check = NSButton(title: "Enabled", frame: NSMakeRect(712, stressY, 96, 24))
    check.setButtonType(.switch)
    check.state = (i % 2 == 0) ? .on : .off
    stressDocView.addSubview(check)

    let combo = NSComboBox(frame: NSMakeRect(818, stressY, 120, 26))
    combo.addItems(withObjectValues: ["One", "Two", "Three"])
    stressDocView.addSubview(combo)

    let well = NSColorWell(frame: NSMakeRect(948, stressY, 44, 26))
    well.color = DemoCanvasView.palette[i % DemoCanvasView.palette.count]
    stressDocView.addSubview(well)

    stressY += 36

    // Every four rows, drop in an expensive gradient band.
    if i % 4 == 3 {
        let band = DemoSlowGradientView(frame: NSMakeRect(12, stressY, 1000, 120))
        band.label = "Slow gradient band \(i / 4 + 1) — dozens of gradient fills per paint"
        stressDocView.addSubview(band)
        stressY += 132
    }
}

stressDocView.frame = NSMakeRect(0, 0, 1060, stressY + 12)
stressScrollView.documentView = stressDocView
stressPage.addSubview(stressScrollView)

// MARK: - Nib page (Phase 15)
//
// Loads DemoNibPanel.xib — a real Interface Builder document — through NSNib,
// embeds the instantiated view, and wires its controls via identifier lookup
// (the 15.4 first-slice wiring model while automatic @IBOutlet binding awaits
// a KVC layer).
//
// The page renders on all three. The wiring model differs because the *language* does, not
// because the demo is papering over a gap:
//
//   * macOS — Apple's automatic binding. `@IBOutlet`/`@IBAction` + the ObjC runtime resolve
//     the xib's <outlet>/<action> connections at instantiate time. Nothing is looked up by
//     hand. AppKit loads the *compiled* .nib, so run-mac.sh runs ibtool over the xib.
//   * Windows/Linux — the same xib, parsed at runtime, with the connection records read
//     back explicitly (the 15.4 wiring model). `@objc`/`@IBOutlet` do not exist off-Darwin,
//     which is the whole reason for the seam — the same language-level seam
//     DemoConveniences documents for `@objc` action selectors, not a shim.
//
// Both halves below are real: each target uses its own genuine mechanism, and the page's
// behaviour is identical.
let nibIntroLabel = NSTextField(string: "NSNib (Phase 15): the panel below is instantiated from DemoNibPanel.xib at runtime — controls, frames (y-flipped from Cocoa coordinates), identifiers, and the button's action connection all come from the xib.",
                                frame: NSMakeRect(12, 6, 1080, 36))
nibIntroLabel.isEditable = false
nibIntroLabel.isBordered = false
nibIntroLabel.drawsBackground = false
nibPage.addSubview(nibIntroLabel)

let nibStatusLabel = NSTextField(string: "", frame: NSMakeRect(24, 320, 1000, 22))
nibStatusLabel.isEditable = false
nibStatusLabel.isBordered = false
nibStatusLabel.drawsBackground = false
nibPage.addSubview(nibStatusLabel)

#if canImport(WinChocolate) || canImport(LinChocolate)

/// Stands in for the xib's `DemoNibPanelController` File's Owner: the xib's
/// `<outlet>` connections resolve against this object, and the demo reads the
/// controls back through those records (the 15.4 wiring model).
final class DemoNibOwner {}
let nibOwner = DemoNibOwner()
var nibIncrementCount = 0
do {
    let xibPath = demoResourcePath(named: "DemoNibPanel", ofType: "xib")
    if let xibData = try? Data(contentsOf: URL(fileURLWithPath: xibPath)) {
        let nib = NSNib(nibData: xibData)
        if let instance = nib.winInstantiate(withOwner: nibOwner),
           let panel = instance.topLevelObjects.compactMap({ $0 as? NSView }).first {
            panel.frame = NSMakeRect(24, 52, panel.frame.size.width, panel.frame.size.height)
            nibPage.addSubview(panel)

            // Manual outlet wiring through the xib identifiers.
            let countLabel = instance.view(withIdentifier: "nibCountLabel") as? NSTextField
            if let button = instance.view(withIdentifier: "nibButton") as? NSButton {
                button.onAction = { _ in
                    nibIncrementCount += 1
                    countLabel?.stringValue = "\(nibIncrementCount)"
                    statusLabel.stringValue = "Nib button clicked (count \(nibIncrementCount)) — action \(button.action?.name ?? "?") wired from the xib"
                }
            }
            if let slider = instance.view(withIdentifier: "nibSlider") as? NSSlider {
                slider.onAction = { control in
                    statusLabel.stringValue = "Nib slider: \((control as? NSSlider)?.doubleValue ?? 0)"
                }
            }

            // The Show Outlet Values button reads the live control values back
            // through the xib's <outlet> connections on File's Owner — the
            // outlet half of the wiring model (the Increment button proves the
            // action half). No identifier lookup here: every control below is
            // resolved from the outlet records the xib declared.
            let ownerOutlets = instance.connections.filter { $0.kind == .outlet && $0.source === nibOwner }
            func nibOutlet(_ property: String) -> AnyObject? {
                ownerOutlets.first { $0.name == property }?.destination
            }
            if let showButton = instance.view(withIdentifier: "nibShowButton") as? NSButton {
                showButton.onAction = { _ in
                    let field = nibOutlet("nameField") as? NSTextField
                    let check = nibOutlet("check") as? NSButton
                    let slider = nibOutlet("slider") as? NSSlider
                    let popup = nibOutlet("popup") as? NSPopUpButton
                    let count = nibOutlet("countLabel") as? NSTextField
                    let alert = NSAlert()
                    alert.messageText = "Values read through xib outlets"
                    alert.informativeText = """
                    nameField: "\(field?.stringValue ?? "?")"
                    check: \(check?.state == .on ? "on" : "off")
                    slider: \(slider?.doubleValue ?? 0)
                    popup: \(popup?.titleOfSelectedItem ?? "?")
                    countLabel: \(count?.stringValue ?? "?")

                    All five controls were resolved from the <outlet> connections the xib declares on File's Owner — edit the field, toggle the checkbox, drag the slider, then show again.
                    """
                    _ = alert.runModal()
                    statusLabel.stringValue = "Outlet popup shown — \(ownerOutlets.count) outlets resolved from the xib"
                }
            }

            let actionWirings = instance.connections.filter { $0.kind == .action }
            nibStatusLabel.stringValue = "Instantiated \(instance.topLevelObjects.count) top-level object(s), \(instance.objectsByID.count) identified objects, \(actionWirings.count) action connection(s): \(actionWirings.map { $0.name }.joined(separator: ", ")); \(ownerOutlets.count) outlet(s) on File's Owner: \(ownerOutlets.map { $0.name }.joined(separator: ", "))"
        } else {
            nibStatusLabel.stringValue = "DemoNibPanel.xib failed to instantiate."
        }
    } else {
        nibStatusLabel.stringValue = "DemoNibPanel.xib not found at \(xibPath)."
    }
}
#else
// macOS: Apple's automatic @IBOutlet/@IBAction binding.
//
// File's Owner in the xib is `customClass="DemoNibPanelController"` with five <outlet>
// connections and two <action>s. AppKit resolves every one of them through the ObjC
// runtime during `instantiate(withOwner:topLevelObjects:)` — this class only has to
// declare them.
final class DemoNibPanelController: NSObject {
    @IBOutlet weak var nameField: NSTextField?
    @IBOutlet weak var check: NSButton?
    @IBOutlet weak var slider: NSSlider?
    @IBOutlet weak var popup: NSPopUpButton?
    @IBOutlet weak var countLabel: NSTextField?

    var increments = 0

    @IBAction func increment(_ sender: Any?) {
        increments += 1
        countLabel?.stringValue = "\(increments)"
        MainActor.assumeIsolated {
            statusLabel.stringValue = "Nib button clicked (count \(increments)) — action increment: wired from the xib"
        }
    }

    @IBAction func showValues(_ sender: Any?) {
        // Reads the live controls straight off the outlets AppKit bound — the outlet half
        // of the wiring model, exactly as the Windows/Linux branch does through records.
        MainActor.assumeIsolated {
            let alert = NSAlert()
            alert.messageText = "Values read through xib outlets"
            alert.informativeText = """
            nameField: "\(nameField?.stringValue ?? "?")"
            check: \(check?.state == .on ? "on" : "off")
            slider: \(slider?.doubleValue ?? 0)
            popup: \(popup?.titleOfSelectedItem ?? "?")
            countLabel: \(countLabel?.stringValue ?? "?")

            All five controls were bound automatically from the <outlet> connections the xib declares on File's Owner — edit the field, toggle the checkbox, drag the slider, then show again.
            """
            _ = alert.runModal()
            statusLabel.stringValue = "Outlet popup shown — 5 outlets bound automatically by AppKit"
        }
    }
}

let nibOwner = DemoNibPanelController()
do {
    // AppKit loads the COMPILED nib (run-mac.sh runs ibtool over the xib).
    let nibPath = demoResourcePath(named: "DemoNibPanel", ofType: "nib")
    if let nibData = try? Data(contentsOf: URL(fileURLWithPath: nibPath)) {
        var topLevel: NSArray?
        let nib = NSNib(nibData: nibData, bundle: nil)
        if nib.instantiate(withOwner: nibOwner, topLevelObjects: &topLevel),
           let panel = (topLevel as? [Any])?.compactMap({ $0 as? NSView }).first {
            panel.frame = NSMakeRect(24, 52, panel.frame.size.width, panel.frame.size.height)
            nibPage.addSubview(panel)
            let bound = [nibOwner.nameField, nibOwner.check, nibOwner.slider,
                         nibOwner.popup, nibOwner.countLabel].compactMap { $0 }.count
            nibStatusLabel.stringValue = "Instantiated \((topLevel as? [Any])?.count ?? 0) top-level object(s); \(bound)/5 outlets and 2 actions (increment:, showValues:) bound automatically by AppKit from the xib's connections."
        } else {
            nibStatusLabel.stringValue = "DemoNibPanel.nib failed to instantiate."
        }
    } else {
        nibStatusLabel.stringValue = "DemoNibPanel.nib not found at \(nibPath) — run-mac.sh compiles it from the xib with ibtool."
    }
}
#endif

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
// NSForm and NSMatrix are single stops in the key loop on Apple; Tab moves
// through their entries internally.
tokenField.nextKeyView = form
form.nextKeyView = matrix
matrix.nextKeyView = slider
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

configureToolbarKeyLoop()

editableTextField.isEditable = true
// One real NSTextFieldDelegate handles begin/end/change for this field
// (a field has a single delegate — plain AppKit rules).
let editableFieldDelegate = DemoFieldDelegate()
editableFieldDelegate.onBegin = { statusLabel.stringValue = "Began editing field" }
editableFieldDelegate.onEnd = { statusLabel.stringValue = "Ended editing field" }
editableFieldDelegate.onChange = { field in
    updateFocusDisplay()
    statusLabel.stringValue = field.stringValue.isEmpty
        ? "Edit field cleared"
        : "Typed: \(field.stringValue)"
}
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

// Same recipe as the template tint well: the well's own action reports the pick, and
// clicking it presents the shared color panel without any help from the demo.
colorWell.onAction = { control in
    guard let well = control as? NSColorWell else {
        return
    }

    updateFocusDisplay()
    let color = well.color
    statusLabel.stringValue = "Color well changed: RGB \(Int(color.redComponent * 255)), \(Int(color.greenComponent * 255)), \(Int(color.blueComponent * 255))"
}

pathControl.onAction = { control in
    guard let path = control as? NSPathControl else {
        return
    }

    let clickedName = path.clickedPathComponentCell()?.url?.lastPathComponent ?? "?"
    statusLabel.stringValue = "Path clicked: \(clickedName)"
}

let demoFontChangeResponder = DemoFontChangeResponder()
fontButton.onAction = { _ in
    updateFocusDisplay()
    // Live picks arrive through the REAL `changeFont(_:)` responder action:
    // the manager's target receives it and converts the selection, as any
    // AppKit app does.
    let manager = NSFontManager.shared
    demoFontChangeResponder.handler = { font in
        let weight = font.fontDescriptor.symbolicTraits.contains(.bold) ? " bold" : ""
        statusLabel.stringValue = "Font chosen: \(font.fontName) \(Int(font.pointSize))pt\(weight)"
    }
    manager.target = demoFontChangeResponder
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

imageView.onClick = {
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
        // Bold italic via the descriptor, as on Apple (no combined NSFont init).
        let boldItalic = NSFontDescriptor(name: "Georgia", size: 14).withSymbolicTraits([.bold, .italic])
        storage.addAttribute(.font, value: NSFont(descriptor: boldItalic, size: 14) ?? NSFont.systemFont(ofSize: 14), range: selection)
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
    let tokens = (tokenField.objectValue as? [String]) ?? []
    statusLabel.stringValue = "Tokens: \(tokens.joined(separator: " | "))"
}

// NSForm edits its cells in place; a continuous control sends its action on
// every change (plain NSControl behavior), and the cells carry the values.
form.isContinuous = true
form.onAction = { control in
    guard let form = control as? NSForm else {
        return
    }

    updateFocusDisplay()
    let name = (form.cell(at: 0) as? NSFormCell)?.stringValue ?? ""
    let status = (form.cell(at: 1) as? NSFormCell)?.stringValue ?? ""
    statusLabel.stringValue = "Form: \(name) — \(status)"
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
        let panelContent = DemoPageView(frame: NSMakeRect(0, 0, 280, 140))
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

let popoverContent = DemoFilledView(frame: NSMakeRect(0, 0, 260, 120))
let popoverTitle = NSTextField(string: "NSPopover", frame: NSMakeRect(20, 16, 120, 24))
let popoverInfo = NSTextField(string: "Borderless transient host", frame: NSMakeRect(20, 46, 200, 24))
let popoverCloseButton = NSButton(title: "Close", frame: NSMakeRect(20, 82, 80, 28))
popoverTitle.font = NSFont.boldSystemFont(ofSize: 14)
// The two lines are captions, not input fields — without this they render as editable
// bordered fields (and the title even shows a focus ring and selected text), which is
// what made dark field bezels sit on the light surface below.
for caption in [popoverTitle, popoverInfo] {
    caption.isBordered = false
    caption.drawsBackground = false
    caption.isEditable = false
    caption.isSelectable = false
    // Dynamic — resolves against whichever appearance the popover ends up drawing in.
    caption.textColor = .labelColor
}
// The surface has to follow the appearance. Hardcoding the cream below put a light
// background under dark-mode controls and dynamic (near-white) label text, which is
// why the popover was unreadable. Keep the warm character in both modes instead.
let popoverDark = NSApplication.shared.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
popoverContent.backgroundColor = popoverDark
    ? NSColor(calibratedRed: 0.26, green: 0.22, blue: 0.16, alpha: 1.0)
    : NSColor(calibratedRed: 1.00, green: 0.94, blue: 0.84, alpha: 1.0)
popoverContent.addSubview(popoverTitle)
popoverContent.addSubview(popoverInfo)
popoverContent.addSubview(popoverCloseButton)
popover.contentSize = NSMakeSize(260, 120)
popover.behavior = .transient
// Apple has no NSViewController(view:); make one and assign its root view.
let popoverViewController = NSViewController()
popoverViewController.view = popoverContent
popover.contentViewController = popoverViewController

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
    let panel = NSOpenPanel()
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
    let panel = NSSavePanel()
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

let demoAlertHelpDelegate = DemoAlertHelpDelegate()
alertButton.onAction = { _ in
    updateFocusDisplay()
    let alert = NSAlert()
    alert.messageText = "WinChocolate is running"
    alert.informativeText = "This composed NSAlert shows a help button; click ? for help."
    // Read the style from the popup's selection index (plain AppKit —
    // WinChocolate's popup items are not menu-item backed, so no item tags).
    switch alertStylePopup.indexOfSelectedItem {
    case 1:
        alert.alertStyle = .warning
    case 2:
        alert.alertStyle = .critical
    default:
        alert.alertStyle = .informational
    }
    alert.showsHelp = true
    // Help clicks arrive through the REAL NSAlertDelegate.alertShowHelp(_:).
    demoAlertHelpDelegate.onHelp = {
        statusLabel.stringValue = "Alert help requested"
    }
    alert.delegate = demoAlertHelpDelegate
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
    // Scroll the *existing* selection into view — and do not disturb it. This used to
    // compute `numberOfRows - 1` and select it, i.e. "select the last row and scroll
    // there", which is a different feature and contradicted the button's name.
    // selectedRow is -1 when nothing is selected, as on Apple.
    let selected = tableView.selectedRow
    guard selected >= 0 else {
        statusLabel.stringValue = "Scroll to selected: nothing selected"
        return
    }

    tableView.scrollRowToVisible(selected)
    statusLabel.stringValue = tableRowSummary(tableView, prefix: "Scrolled to selected")
}
collectionView.onSelectionChanged = { collectionView in
    guard let indexPath = collectionView.selectionIndexPaths.sorted(by: { left, right in
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
            #if canImport(WinChocolate) || canImport(LinChocolate)
            // Windows-only seam: defer the reload past the native header-click
            // notification (reentrancy protection in the classic backend).
            NSApp.nativeBackend.dispatchAsync {
                table.reloadData()
                if let selectedValues {
                    suppressNextTableSelectionStatus = selectTableRow(matching: selectedValues, in: table)
                }
            }
            #else
            table.reloadData()
            if let selectedValues {
                suppressNextTableSelectionStatus = selectTableRow(matching: selectedValues, in: table)
            }
            #endif
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
    let shouldExpand = outline.isExpandable(item)
    // Toggle with the real AppKit pair (there is no toggle method on Apple).
    if outline.isItemExpanded(item) {
        outline.collapseItem(item)
    } else {
        outline.expandItem(item)
    }
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
outlineView.onOutlineSelectionChanged = { outline in
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
contentView.addSubview(bezelsPage)
contentView.addSubview(layoutPage)
contentView.addSubview(coreGraphicsPage)
contentView.addSubview(stressPage)
contentView.addSubview(nibPage)

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
controlsPage.addSubview(contactNameLabel)
controlsPage.addSubview(contactNameField)
controlsPage.addSubview(contactStatusLabel)
controlsPage.addSubview(contactStatusField)
controlsPage.addSubview(matrixLabel)
controlsPage.addSubview(matrix)
controlsPage.addSubview(deprecatedFormNote)
controlsPage.addSubview(deprecatedFormLabel)
controlsPage.addSubview(form)

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
    // Real Foundation (LinChocolate and AppKit) types this block @Sendable, so
    // touching the main-actor UI globals directly won't type-check; hop to the
    // main actor. WinChocolate's WinFoundation block inherits the main actor, so
    // it stays synchronous and unchanged.
    #if canImport(WinChocolate)
    timerTicks += 1
    timerTickLabel.stringValue = "Timer: \(timerTicks)s"
    #else
    Task { @MainActor in
        timerTicks += 1
        timerTickLabel.stringValue = "Timer: \(timerTicks)s"
    }
    #endif
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
// An NSColorWell sends its action when its *color changes*, and clicking it presents the
// shared color panel on its own — so reading `well.color` here is the whole recipe.
//
// This used to open NSColorPanel.shared by hand and point its target/action at a
// trampoline, then call `activate(true)`. That cannot work: activating a well makes the
// well the panel's client, discarding the target/action set moments earlier — so the
// trampoline that was going to tint the glyph never ran.
templateTintWell.onAction = { control in
    guard let well = control as? NSColorWell else {
        return
    }

    templateImageView.contentTintColor = well.color
    statusLabel.stringValue = "Template tint changed"
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
    let operation = NSPrintOperation(view: showcasePrintSample)
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
// 480 wide, not 620: the right-hand column starts at x=520, and a 620-wide field
// starting at x=24 ran to x=644 — straight through it. Two lines instead of one.
let viewTableHint = NSTextField(string: "Hosts real controls; double-click a Note to edit, drag a row to reorder, drag a header to move a column.", frame: NSMakeRect(24, 412, 480, 34))
viewTableHint.isBordered = false
viewTableHint.drawsBackground = false
viewTableHint.font = NSFont.systemFont(ofSize: 11)
// A taller frame alone does not wrap: an NSTextField is single-line by default, so the
// text just runs past the edge (which is how it reached the next column).
viewTableHint.usesSingleLineMode = false
viewTableHint.maximumNumberOfLines = 2
let viewTableSource = DemoViewTableDataSource()
let viewTableDelegate = DemoViewTableDelegate(source: viewTableSource)
viewTableDelegate.onEvent = { statusLabel.stringValue = $0 }
let viewTableScrollView = NSScrollView(frame: NSMakeRect(24, 450, 470, 104))
viewTableScrollView.hasVerticalScroller = true
let viewTable = NSTableView(frame: NSMakeRect(0, 0, 470, 104))
let taskColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("task"))
taskColumn.title = "Task"
taskColumn.width = 210
let noteColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("note"))
noteColumn.title = "Note (dbl-click)"
noteColumn.width = 130
noteColumn.isEditable = true
let actionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("action"))
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
// Drag a row to reorder it (5.8) — the plain-AppKit recipe: a `.move` local
// source mask plus the data source's pasteboard writer and acceptDrop.
viewTable.setDraggingSourceOperationMask(.move, forLocal: true)
// A table only *receives* drags for types it has registered — without this AppKit never
// routes the drop to validateDrop/acceptDrop and the dragged row just snaps back. The
// pasteboard writer above vends the row index as a String, so register that type.
viewTable.registerForDraggedTypes([.string])
viewTableSource.onReorder = { movedCount, dest in
    statusLabel.stringValue = "Moved \(movedCount) row(s) → \(dest)"
}
// Multi-row reorder needs multiple selection.
viewTable.allowsMultipleSelection = true
// Drag a column header past another to reorder the columns (5.7).
viewTable.allowsColumnReordering = true
viewTableScrollView.documentView = viewTable

// 5.5 — NSTableRowView hosting: full-width colored row views behind hosted
// label cells (a CI-status list). Placed to the right of the view table.
let rowViewSectionLabel = showcaseSectionLabel("Row views — full-width row backgrounds (5.5)", NSMakeRect(520, 392, 380, 20))
let rowViewHint = NSTextField(string: "Each row hosts an NSTableRowView; click a row to see the selection fill.", frame: NSMakeRect(520, 412, 400, 34))
rowViewHint.isBordered = false
rowViewHint.drawsBackground = false
rowViewHint.font = NSFont.systemFont(ofSize: 11)
rowViewHint.usesSingleLineMode = false
rowViewHint.maximumNumberOfLines = 2
let statusRowSource = DemoStatusRowDataSource()
let statusRowDelegate = DemoStatusRowDelegate(source: statusRowSource)
let statusRowScrollView = NSScrollView(frame: NSMakeRect(520, 450, 300, 104))
statusRowScrollView.hasVerticalScroller = true
let statusRowTable = NSTableView(frame: NSMakeRect(0, 0, 300, 104))
let stageColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("stage"))
stageColumn.title = "Stage"
stageColumn.width = 170
let statusColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("status"))
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
browser.delegate = browserDataSource
// A browser sizes its own columns by default — columnResizingType is .autoColumnResizing —
// so the divider shows a resize cursor and then refuses to move: the browser owns the
// widths, not the user. .userColumnResizing hands them over. (Measured: this alone does
// not widen anything, so the two symptoms below are independent bugs.)
browser.columnResizingType = .userColumnResizing
// The default minColumnWidth is 100, which is what truncated "Application" to "Applicat…":
// a 520-wide browser lays out 5 columns of ~103pt. 170 fits the class names, and the user
// can now drag from there.
browser.minColumnWidth = 170
browser.loadColumnZero()
// Titled columns: the first is labeled; deeper columns auto-title with the
// selected parent item.
browser.setTitle("Frameworks", ofColumn: 0)
let listsBrowserPathLabel = NSTextField(string: "Path: /", frame: NSMakeRect(24, 224, 720, 22))
listsBrowserPathLabel.isBordered = false
listsBrowserPathLabel.drawsBackground = false
listsBrowserPathLabel.font = NSFont.boldSystemFont(ofSize: 12)
listsBrowserPathLabel.textColor = demoValueTextColor
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
listsFlowLayout.footerReferenceSize = NSMakeSize(0, 16)
let listsCollectionScrollView = NSScrollView(frame: NSMakeRect(24, 352, 860, 168))
listsCollectionScrollView.hasVerticalScroller = true
let listsCollectionView = NSCollectionView(frame: NSMakeRect(0, 0, 860, 168))
listsCollectionView.collectionViewLayout = listsFlowLayout
// Register after the layout and before the data source. AppKit only accepts
// supplementary views vended by makeSupplementaryView, which needs the class
// registered for the kind+identifier — and assigning collectionViewLayout
// discards existing registrations, so registering earlier silently loses them
// and makeSupplementaryView then falls back to hunting for a nib named after
// the identifier.
listsCollectionView.register(NSTextField.self,
                             forSupplementaryViewOfKind: NSCollectionView.elementKindSectionHeader,
                             withIdentifier: DemoFlowCollectionDataSource.headerID)
listsCollectionView.register(NSTextField.self,
                             forSupplementaryViewOfKind: NSCollectionView.elementKindSectionFooter,
                             withIdentifier: DemoFlowCollectionDataSource.footerID)
listsCollectionView.dataSource = listsFlowSource
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
// The plain-AppKit pattern: subclass NSDocumentController overriding
// documentClass(forType:), and instantiate it early — the first controller
// created becomes `shared`.
final class DemoDocumentController: NSDocumentController {
    override func documentClass(forType typeName: String) -> AnyClass? {
        DemoNoteDocument.self
    }
}
_ = DemoDocumentController()
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
for (index, pageTitle) in ["Controls Page", "Values Page", "Tables/Media Page", "Drawing Page", "New in 3.x Page", "Lists Page", "Bezels Page", "Auto Layout Page", "CoreGraphics Page", "Scroll Stress Page", "Nib Page"].enumerated() {
    // Ctrl+1...Ctrl+8 switch pages (the .command mask maps onto Ctrl on Windows).
    let item = NSMenuItem(title: pageTitle, action: nil, keyEquivalent: "\(index + 1)")
    item.onAction = { _ in
        pageSelector.selectItem(at: index)
        showDemoPage(index)
        statusLabel.stringValue = "Page selected: \(pageTitle)"
    }
    viewMenu.addItem(item)
}
viewMenu.addItem(NSMenuItem.separator())
// AppKit's standard View-menu toolbar actions (6.2) + the Apple looks (6.10).
let toggleToolbarMenuItem = NSMenuItem(title: "Show/Hide Toolbar", action: nil, keyEquivalent: "")
toggleToolbarMenuItem.onAction = { _ in
    window.toggleToolbarShown(nil)
}
viewMenu.addItem(toggleToolbarMenuItem)
// `winAppleLook` is the sanctioned presentation exception (Project Goal 1:
// toolbars keep the Apple look on Windows) — a WinChocolate-only surface, so
// the toggle exists only where WinChocolate is the framework. On real AppKit
// the toolbar already IS Apple's; there is nothing to toggle.
#if canImport(WinChocolate) || canImport(LinChocolate)
let metallicMenuItem = NSMenuItem(title: "Use Metallic Toolbar", action: nil, keyEquivalent: "")
metallicMenuItem.onAction = { item in
    let metallic = demoToolbar.winAppleLook == .metallic
    demoToolbar.winAppleLook = metallic ? .unified : .metallic
    item.state = metallic ? .off : .on
    statusLabel.stringValue = "Toolbar look: \(metallic ? "unified" : "metallic")"
}
viewMenu.addItem(metallicMenuItem)
#endif
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

// ---------------------------------------------------------------------------
// Bezels (8.3) page — showcases the framework-drawn NSButton bezel styles, the
// NSSegmentedControl styles, and the accent-aware drawn controls added in 8.3.
// Toggle to dark mode (run with --dark, or set Windows to dark) to see the
// appearance-aware fills.
// ---------------------------------------------------------------------------
@MainActor
func bezelCaption(_ text: String, _ frame: NSRect) -> NSTextField {
    let label = NSTextField(string: text, frame: frame)
    label.isBordered = false
    label.drawsBackground = false
    label.font = NSFont.systemFont(ofSize: 11)
    return label
}

let bezelsIntro = bezelCaption("Framework-drawn button bezels and segmented styles (Phase 8.3). Click the toggles; run with --dark to see the appearance-aware fills.", NSMakeRect(24, 12, 1000, 20))

let buttonBezelHeader = showcaseSectionLabel("NSButton.bezelStyle — framework-drawn (8.3)", NSMakeRect(24, 42, 520, 20))

let disclosureButton = NSButton(title: "", frame: NSMakeRect(28, 74, 22, 22))
disclosureButton.bezelStyle = .disclosure
disclosureButton.onAction = { _ in
    statusLabel.stringValue = "Disclosure: \(disclosureButton.state == .on ? "open" : "closed")"
}
let disclosureCaption = bezelCaption("Disclosure", NSMakeRect(56, 74, 78, 20))

let roundedDisclosureButton = NSButton(title: "", frame: NSMakeRect(150, 74, 24, 22))
roundedDisclosureButton.bezelStyle = .roundedDisclosure
roundedDisclosureButton.onAction = { _ in
    statusLabel.stringValue = "Rounded disclosure: \(roundedDisclosureButton.state == .on ? "open" : "closed")"
}
let roundedDisclosureCaption = bezelCaption("Rounded", NSMakeRect(180, 74, 70, 20))

let circularBezelButton = NSButton(title: "?", frame: NSMakeRect(262, 70, 30, 30))
circularBezelButton.bezelStyle = .circular
circularBezelButton.onAction = { _ in
    statusLabel.stringValue = "Circular button clicked"
}
let circularCaption = bezelCaption("Circular", NSMakeRect(298, 74, 66, 20))

let recessedBezelButton = NSButton(title: "Bold", frame: NSMakeRect(372, 72, 64, 26))
recessedBezelButton.bezelStyle = .recessed
recessedBezelButton.onAction = { _ in
    statusLabel.stringValue = "Recessed toggle: \(recessedBezelButton.state == .on ? "on" : "off")"
}
let recessedCaption = bezelCaption("Recessed (toggle)", NSMakeRect(444, 74, 130, 20))

let inlineBezelButton = NSButton(title: "NEW", frame: NSMakeRect(576, 73, 52, 24))
inlineBezelButton.bezelStyle = .inline
inlineBezelButton.onAction = { _ in
    statusLabel.stringValue = "Inline pill clicked"
}
let inlineCaption = bezelCaption("Inline pill", NSMakeRect(634, 74, 90, 20))

let segmentHeader = showcaseSectionLabel("NSSegmentedControl.segmentStyle (8.3)", NSMakeRect(24, 124, 520, 20))

let roundedSegCaption = bezelCaption(".rounded (joined)", NSMakeRect(24, 150, 250, 20))
let roundedSeg = NSSegmentedControl(labels: ["Day", "Week", "Month"], frame: NSMakeRect(24, 172, 250, 28))
roundedSeg.segmentStyle = .rounded
roundedSeg.selectedSegment = 0

let separatedSegCaption = bezelCaption(".separated (gapped)", NSMakeRect(298, 150, 250, 20))
let separatedSeg = NSSegmentedControl(labels: ["Day", "Week", "Month"], frame: NSMakeRect(298, 172, 250, 28))
separatedSeg.segmentStyle = .separated
separatedSeg.selectedSegment = 1

let texturedSegCaption = bezelCaption(".texturedSquare (flat)", NSMakeRect(572, 150, 250, 20))
let texturedSeg = NSSegmentedControl(labels: ["Day", "Week", "Month"], frame: NSMakeRect(572, 172, 250, 28))
texturedSeg.segmentStyle = .texturedSquare
texturedSeg.selectedSegment = 2

let capsuleSegCaption = bezelCaption(".capsule (joined)", NSMakeRect(846, 150, 250, 20))
let capsuleSeg = NSSegmentedControl(labels: ["Day", "Week", "Month"], frame: NSMakeRect(846, 172, 250, 28))
capsuleSeg.segmentStyle = .capsule
capsuleSeg.selectedSegment = 0

for seg in [roundedSeg, separatedSeg, texturedSeg, capsuleSeg] {
    seg.onAction = { control in
        guard let seg = control as? NSSegmentedControl else {
            return
        }
        statusLabel.stringValue = "Segment: \(seg.label(forSegment: seg.selectedSegment) ?? "none")"
    }
}

let drawnHeader = showcaseSectionLabel("Accent-aware drawn controls (8.3)", NSMakeRect(24, 224, 520, 20))

let ratingCaption = bezelCaption("NSLevelIndicator .rating", NSMakeRect(24, 250, 180, 20))
let bezelsRating = NSLevelIndicator(frame: NSMakeRect(24, 272, 150, 24))
bezelsRating.levelIndicatorStyle = .rating
bezelsRating.minValue = 0
bezelsRating.maxValue = 5
bezelsRating.doubleValue = 3
bezelsRating.isEditable = true
bezelsRating.onAction = { _ in
    statusLabel.stringValue = "Rating: \(bezelsRating.intValue)/5"
}

let discreteCaption = bezelCaption(".discreteCapacity", NSMakeRect(200, 250, 180, 20))
let discreteIndicator = NSLevelIndicator(frame: NSMakeRect(200, 272, 150, 24))
discreteIndicator.levelIndicatorStyle = .discreteCapacity
discreteIndicator.minValue = 0
discreteIndicator.maxValue = 10
discreteIndicator.doubleValue = 6

let relevancyCaption = bezelCaption(".relevancy", NSMakeRect(376, 250, 180, 20))
let relevancyIndicator = NSLevelIndicator(frame: NSMakeRect(376, 272, 150, 24))
relevancyIndicator.levelIndicatorStyle = .relevancy
relevancyIndicator.minValue = 0
relevancyIndicator.maxValue = 12
relevancyIndicator.doubleValue = 8

let tokenCaption = bezelCaption("NSTokenField chips", NSMakeRect(560, 250, 180, 20))
let bezelsTokenField = NSTokenField(tokens: ["Swift", "AppKit", "Windows"], frame: NSMakeRect(560, 272, 280, 26))

for control in [
    bezelsIntro, buttonBezelHeader,
    disclosureButton, disclosureCaption,
    roundedDisclosureButton, roundedDisclosureCaption,
    circularBezelButton, circularCaption,
    recessedBezelButton, recessedCaption,
    inlineBezelButton, inlineCaption,
    segmentHeader,
    roundedSegCaption, roundedSeg, separatedSegCaption, separatedSeg,
    texturedSegCaption, texturedSeg, capsuleSegCaption, capsuleSeg,
    drawnHeader,
    ratingCaption, bezelsRating, discreteCaption, discreteIndicator,
    relevancyCaption, relevancyIndicator, tokenCaption, bezelsTokenField
] as [NSView] {
    bezelsPage.addSubview(control)
}

// ── Auto Layout (9.x) page ───────────────────────────────────────────
// Every box on this page is positioned by the constraint solver
// (`NSLayoutConstraint` + anchors + intrinsic sizes), not a fixed frame:
// each demo container adds constraint-driven subviews and calls
// `layoutSubtreeIfNeeded()` to compute their frames.
let layoutIntro = bezelCaption(
    "Every box below is positioned by the Auto Layout solver (NSLayoutConstraint + anchors), not a fixed frame.",
    NSMakeRect(24, 10, 1040, 20))
let layoutHeader = showcaseSectionLabel(
    "NSLayoutConstraint + anchors + intrinsic sizes (9.1/9.2)", NSMakeRect(24, 36, 660, 20))

func layoutDemoContainer(at x: CGFloat) -> NSView {
    let container = DemoFilledView(frame: NSMakeRect(x, 84, 250, 150))
    container.backgroundColor = NSColor(calibratedWhite: 0.30, alpha: 1)
    return container
}
func layoutBox(_ color: NSColor) -> NSView {
    let box = DemoFilledView(frame: .zero)
    box.translatesAutoresizingMaskIntoConstraints = false
    box.backgroundColor = color
    return box
}
let layoutBlue = NSColor(calibratedRed: 0.30, green: 0.56, blue: 0.95, alpha: 1)
let layoutGreen = NSColor(calibratedRed: 0.30, green: 0.75, blue: 0.45, alpha: 1)
let layoutRed = NSColor(calibratedRed: 0.90, green: 0.36, blue: 0.36, alpha: 1)
let layoutOrange = NSColor(calibratedRed: 0.95, green: 0.64, blue: 0.24, alpha: 1)
let layoutPurple = NSColor(calibratedRed: 0.66, green: 0.44, blue: 0.90, alpha: 1)

// Demo 1: pin all four edges with a 12pt inset — the box fills the container.
let demo1Caption = bezelCaption("Pinned to edges (inset 12)", NSMakeRect(24, 60, 250, 18))
let demo1 = layoutDemoContainer(at: 24)
let demo1Box = layoutBox(layoutBlue)
demo1.addSubview(demo1Box)
NSLayoutConstraint.activate([
    demo1Box.leadingAnchor.constraint(equalTo: demo1.leadingAnchor, constant: 12),
    demo1Box.trailingAnchor.constraint(equalTo: demo1.trailingAnchor, constant: -12),
    demo1Box.topAnchor.constraint(equalTo: demo1.topAnchor, constant: 12),
    demo1Box.bottomAnchor.constraint(equalTo: demo1.bottomAnchor, constant: -12),
])
demo1.layoutSubtreeIfNeeded()

// Demo 2: fixed 90×48, centered in the container.
let demo2Caption = bezelCaption("Fixed 90×48, centered", NSMakeRect(292, 60, 250, 18))
let demo2 = layoutDemoContainer(at: 292)
let demo2Box = layoutBox(layoutGreen)
demo2.addSubview(demo2Box)
NSLayoutConstraint.activate([
    demo2Box.widthAnchor.constraint(equalToConstant: 90),
    demo2Box.heightAnchor.constraint(equalToConstant: 48),
    demo2Box.centerXAnchor.constraint(equalTo: demo2.centerXAnchor),
    demo2Box.centerYAnchor.constraint(equalTo: demo2.centerYAnchor),
])
demo2.layoutSubtreeIfNeeded()

// Demo 3: a horizontal sibling chain — equal widths, 10pt gaps.
let demo3Caption = bezelCaption("Sibling chain (equal, gap 10)", NSMakeRect(560, 60, 250, 18))
let demo3 = layoutDemoContainer(at: 560)
let boxA = layoutBox(layoutRed)
let boxB = layoutBox(layoutOrange)
let boxC = layoutBox(layoutPurple)
demo3.addSubview(boxA)
demo3.addSubview(boxB)
demo3.addSubview(boxC)
NSLayoutConstraint.activate([
    boxA.leadingAnchor.constraint(equalTo: demo3.leadingAnchor, constant: 12),
    boxA.topAnchor.constraint(equalTo: demo3.topAnchor, constant: 12),
    boxA.bottomAnchor.constraint(equalTo: demo3.bottomAnchor, constant: -12),
    boxA.widthAnchor.constraint(equalToConstant: 44),
    boxB.leadingAnchor.constraint(equalTo: boxA.trailingAnchor, constant: 10),
    boxB.topAnchor.constraint(equalTo: boxA.topAnchor),
    boxB.bottomAnchor.constraint(equalTo: boxA.bottomAnchor),
    boxB.widthAnchor.constraint(equalTo: boxA.widthAnchor),
    boxC.leadingAnchor.constraint(equalTo: boxB.trailingAnchor, constant: 10),
    boxC.topAnchor.constraint(equalTo: boxA.topAnchor),
    boxC.bottomAnchor.constraint(equalTo: boxA.bottomAnchor),
    boxC.widthAnchor.constraint(equalTo: boxA.widthAnchor),
])
demo3.layoutSubtreeIfNeeded()

// Demo 4: intrinsic-sized labels stacked in a column (width from text).
let demo4Caption = bezelCaption("Intrinsic-sized labels (column)", NSMakeRect(828, 60, 250, 18))
let demo4 = layoutDemoContainer(at: 828)
let layoutLabel1 = NSTextField(string: "Short", frame: .zero)
let layoutLabel2 = NSTextField(string: "A considerably longer label", frame: .zero)
for label in [layoutLabel1, layoutLabel2] {
    label.translatesAutoresizingMaskIntoConstraints = false
    label.isEditable = false
    label.isBordered = false
    label.drawsBackground = true
    label.backgroundColor = layoutBlue
    label.textColor = .white
}
demo4.addSubview(layoutLabel1)
demo4.addSubview(layoutLabel2)
NSLayoutConstraint.activate([
    layoutLabel1.leadingAnchor.constraint(equalTo: demo4.leadingAnchor, constant: 12),
    layoutLabel1.topAnchor.constraint(equalTo: demo4.topAnchor, constant: 16),
    layoutLabel2.leadingAnchor.constraint(equalTo: layoutLabel1.leadingAnchor),
    layoutLabel2.topAnchor.constraint(equalTo: layoutLabel1.bottomAnchor, constant: 12),
])
demo4.layoutSubtreeIfNeeded()

// Live resize demo: left/right boxes pinned to the edges, the middle box fills
// the gap. The window-resize handler (below) widens this container and re-runs
// the solver, so dragging the window reflows the middle box in real time.
let resizeDemoCaption = bezelCaption(
    "Resize the window → the green middle box reflows live (left/right pinned to the edges, middle fills the gap).",
    NSMakeRect(24, 250, 1000, 18))
let resizeContainer = DemoFilledView(frame: NSMakeRect(24, 274, 1072, 90))
resizeContainer.backgroundColor = NSColor(calibratedWhite: 0.30, alpha: 1)
let resizeLeft = layoutBox(layoutBlue)
let resizeMiddle = layoutBox(layoutGreen)
let resizeRight = layoutBox(layoutRed)
resizeContainer.addSubview(resizeLeft)
resizeContainer.addSubview(resizeMiddle)
resizeContainer.addSubview(resizeRight)
NSLayoutConstraint.activate([
    resizeLeft.leadingAnchor.constraint(equalTo: resizeContainer.leadingAnchor, constant: 12),
    resizeLeft.widthAnchor.constraint(equalToConstant: 70),
    resizeLeft.topAnchor.constraint(equalTo: resizeContainer.topAnchor, constant: 12),
    resizeLeft.bottomAnchor.constraint(equalTo: resizeContainer.bottomAnchor, constant: -12),
    resizeRight.trailingAnchor.constraint(equalTo: resizeContainer.trailingAnchor, constant: -12),
    resizeRight.widthAnchor.constraint(equalToConstant: 70),
    resizeRight.topAnchor.constraint(equalTo: resizeLeft.topAnchor),
    resizeRight.bottomAnchor.constraint(equalTo: resizeLeft.bottomAnchor),
    resizeMiddle.leadingAnchor.constraint(equalTo: resizeLeft.trailingAnchor, constant: 10),
    resizeMiddle.trailingAnchor.constraint(equalTo: resizeRight.leadingAnchor, constant: -10),
    resizeMiddle.topAnchor.constraint(equalTo: resizeLeft.topAnchor),
    resizeMiddle.bottomAnchor.constraint(equalTo: resizeLeft.bottomAnchor),
])
resizeContainer.layoutSubtreeIfNeeded()

// NSStackView (9.4): a horizontal row and a vertical column, each arranging its
// views with a distribution + spacing. The horizontal one also stretches with
// the window (see the resize handler) to show the stack refilling live.
let stackHeader = showcaseSectionLabel("NSStackView (9.4)", NSMakeRect(24, 370, 400, 20))
let hStackCaption = bezelCaption("Horizontal .fillEqually, spacing 8", NSMakeRect(24, 414, 520, 18))
let hStack = NSStackView(views: [layoutBox(layoutBlue), layoutBox(layoutGreen), layoutBox(layoutRed), layoutBox(layoutOrange)])
hStack.orientation = .horizontal
hStack.distribution = .fillEqually
hStack.spacing = 8
hStack.frame = NSMakeRect(24, 436, 620, 56)
hStack.layoutSubtreeIfNeeded()

let vStackCaption = bezelCaption("Vertical .fillEqually", NSMakeRect(680, 414, 260, 18))
let vStack = NSStackView(views: [layoutBox(layoutPurple), layoutBox(layoutBlue), layoutBox(layoutGreen)])
vStack.orientation = .vertical
vStack.distribution = .fillEqually
vStack.spacing = 6
vStack.frame = NSMakeRect(680, 436, 130, 110)
vStack.layoutSubtreeIfNeeded()

// NSGridView (9.5): a label-and-field form — column 0 sizes to the widest label
// and right-aligns them, column 1 is a fixed width the field boxes fill.
func formLabel(_ text: String) -> NSTextField {
    let label = NSTextField(string: text, frame: .zero)
    label.isEditable = false
    label.isBordered = false
    label.drawsBackground = false
    return label
}
func fieldBox() -> NSTextField {
    // A real editable field so the form actually accepts focus and typing.
    let field = NSTextField(string: "", frame: NSMakeRect(0, 0, 120, 22))
    field.isEditable = true
    field.isBezeled = true
    field.isBordered = true
    return field
}
let gridCaption = bezelCaption("NSGridView form + merged header (9.5)", NSMakeRect(840, 414, 280, 18))
let formHeader = formLabel("Contact details")
let formGrid = NSGridView(views: [
    [formHeader, formLabel("")],
    [formLabel("Name:"), fieldBox()],
    [formLabel("Email address:"), fieldBox()],
    [formLabel("Role:"), fieldBox()],
])
formGrid.rowSpacing = 8
formGrid.columnSpacing = 10
formGrid.column(at: 0).xPlacement = .trailing
formGrid.column(at: 1).width = 130
formGrid.column(at: 1).xPlacement = .fill
// 9.5: merge the top row across both columns so the section header spans the
// whole form and centers over the label/field columns below it.
formGrid.mergeCells(inHorizontalRange: NSMakeRange(0, 2), verticalRange: NSMakeRange(0, 1))
formGrid.cell(atColumnIndex: 0, rowIndex: 0).xPlacement = .center
formGrid.frame = NSMakeRect(840, 436, 270, 130)
formGrid.layoutSubtreeIfNeeded()

for view in [
    layoutIntro, layoutHeader,
    demo1Caption, demo1, demo2Caption, demo2,
    demo3Caption, demo3, demo4Caption, demo4,
    resizeDemoCaption, resizeContainer,
    stackHeader, hStackCaption, hStack, vStackCaption, vStack,
    gridCaption, formGrid
] as [NSView] {
    layoutPage.addSubview(view)
}

// Reflow the whole Auto Layout page from the current width: the four top demos
// become equal columns, the resize strip spans full width, and on the bottom
// row the form pins right, the vertical stack sits to its left, and the
// horizontal stack fills the remaining space. Each container re-runs the solver
// so its constraint-driven contents adapt. Called at startup and on resize.
@MainActor
func reflowAutoLayoutPage(width pageWidth: CGFloat) {
    let margin: CGFloat = 24
    let gap: CGFloat = 18
    let available = max(pageWidth - margin * 2, 240)

    // Top row: four equal-width demo columns.
    let colWidth = max((available - gap * 3) / 4, 120)
    let topCaptions = [demo1Caption, demo2Caption, demo3Caption, demo4Caption]
    let topContainers = [demo1, demo2, demo3, demo4]
    for i in 0..<4 {
        let x = margin + CGFloat(i) * (colWidth + gap)
        topCaptions[i].frame = NSMakeRect(x, 60, colWidth, 18)
        topContainers[i].frame = NSMakeRect(x, 84, colWidth, 150)
        topContainers[i].layoutSubtreeIfNeeded()
    }

    // Middle: the live-reflow strip spans the full width.
    resizeDemoCaption.frame = NSMakeRect(margin, 250, available, 18)
    resizeContainer.frame = NSMakeRect(margin, 274, available, 80)
    resizeContainer.layoutSubtreeIfNeeded()

    // Bottom row: form pinned to the right, vertical stack to its left, and the
    // horizontal stack filling everything left of them. Sits high enough that the
    // taller grid (a merged header row + three fields) clears the window bottom.
    let formWidth: CGFloat = 270
    let vStackWidth: CGFloat = 130
    let formX = pageWidth - margin - formWidth
    let vStackX = formX - 30 - vStackWidth
    gridCaption.frame = NSMakeRect(formX, 394, formWidth, 18)
    formGrid.frame = NSMakeRect(formX, 416, formWidth, 130)
    formGrid.layoutSubtreeIfNeeded()
    vStackCaption.frame = NSMakeRect(vStackX, 394, 200, 18)
    vStack.frame = NSMakeRect(vStackX, 416, vStackWidth, 110)
    vStack.layoutSubtreeIfNeeded()
    let hStackWidth = max(vStackX - 20 - margin, 200)
    hStackCaption.frame = NSMakeRect(margin, 394, hStackWidth, 18)
    hStack.frame = NSMakeRect(margin, 416, hStackWidth, 56)
    hStack.layoutSubtreeIfNeeded()
}
reflowAutoLayoutPage(width: 1120)

// ── CoreGraphics (Phase 13) page ─────────────────────────────────────
// Everything on the artboard is drawn through the CoreGraphics-shaped
// surface: CGMutablePath curves, CGGradient (linear in a clip + radial),
// saveGState/translate/rotate transforms, and a CGImage round-tripped
// through the WinCoreGraphics BMP codec, rendered from its pixels.
let cgIntro = NSTextField(labelWithString: "Drawn through the CG surface — CGPath, CGGradient, CGContext transforms, and a CGImage round-tripped through a real BMP encode/decode (NSBitmapImageRep).")
cgIntro.frame = NSMakeRect(24, 24, 1072, 18)
let cgArtboard = DemoCoreGraphicsView(frame: NSMakeRect(24, 52, 1072, 180))
let cgFootnote = NSTextField(labelWithString: "Every canvas here is plain CoreGraphics/AppKit — no framework-specific surface. The geometry types (CGRect, CGPoint, CGAffineTransform…) come from the standalone WinCoreGraphics module, re-exported by WinChocolate — Apple's layering, where NSRect is CGRect.")
cgFootnote.frame = NSMakeRect(24, 244, 1072, 18)
for view in [cgIntro, cgArtboard, cgFootnote] as [NSView] {
    coreGraphicsPage.addSubview(view)
}

// Follow a live system dark/light switch (8.5). The framework re-themes and
// repaints its own windows/controls; the demo re-applies the few colors it
// caches at startup (the status/focus bands) and redraws. Skipped implicitly
// when --light/--dark pin an override, since the framework won't post then.
// Body of the appearance-change handler, factored out so the observer block can
// dispatch to it. Real Foundation (LinChocolate/AppKit) types the observer block
// @Sendable, so it can't touch the main-actor UI globals directly — it hops to
// the main actor below; WinChocolate's block inherits the main actor and calls
// this synchronously.
@MainActor
func applyLiveAppearanceRefresh() {
    let dark = NSApplication.shared.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    // The content view was given a background resolved at launch; re-resolve it
    // (windowBackgroundColor is dynamic) so the page surface follows the switch.
    contentView.backgroundColor = NSColor.windowBackgroundColor
    statusLabel.textColor = dark ? NSColor(calibratedRed: 0.55, green: 0.78, blue: 1.0, alpha: 1) : .blue
    statusLabel.backgroundColor = dark
        ? NSColor(white: 0.16, alpha: 1)
        : NSColor(calibratedRed: 0.94, green: 0.97, blue: 1.0, alpha: 1.0)
    focusLabel.textColor = dark ? NSColor(calibratedRed: 1.0, green: 0.83, blue: 0.4, alpha: 1) : .black
    focusLabel.backgroundColor = dark
        ? NSColor(white: 0.16, alpha: 1)
        : NSColor(calibratedRed: 1.0, green: 0.98, blue: 0.86, alpha: 1.0)

    // The demo caches a number of appearance-tuned colors at launch and sets
    // them on views scattered across every page. Setting a view's
    // backgroundColor builds a solid brush at that shade, so a live switch has
    // to re-set each one to rebuild the brush — a plain repaint keeps the old
    // color. Re-derive every cached color from the live appearance here.
    let valueText = dark
        ? NSColor(calibratedRed: 0.45, green: 0.68, blue: 1.0, alpha: 1.0)
        : NSColor.blue
    for label in [stepperValueLabel, scrollerValueLabel, dateValueLabel,
                  clipOriginLabel, listsBrowserPathLabel] {
        label.textColor = valueText
    }

    // Clip-view page: document surface + four demonstrative quadrant tiles.
    clipView.backgroundColor = dark
        ? NSColor(calibratedRed: 0.14, green: 0.14, blue: 0.15, alpha: 1.0) : .white
    clipDocumentView.backgroundColor = dark
        ? NSColor(calibratedRed: 0.17, green: 0.17, blue: 0.18, alpha: 1.0)
        : NSColor(calibratedRed: 0.97, green: 0.97, blue: 0.97, alpha: 1.0)
    clipTopLeftPane.backgroundColor = dark
        ? NSColor(calibratedRed: 0.16, green: 0.24, blue: 0.36, alpha: 1.0)
        : NSColor(calibratedRed: 0.84, green: 0.92, blue: 1.0, alpha: 1.0)
    clipTopRightPane.backgroundColor = dark
        ? NSColor(calibratedRed: 0.34, green: 0.29, blue: 0.14, alpha: 1.0)
        : NSColor(calibratedRed: 1.0, green: 0.94, blue: 0.72, alpha: 1.0)
    clipBottomLeftPane.backgroundColor = dark
        ? NSColor(calibratedRed: 0.16, green: 0.30, blue: 0.18, alpha: 1.0)
        : NSColor(calibratedRed: 0.86, green: 1.0, blue: 0.86, alpha: 1.0)
    clipBottomRightPane.backgroundColor = dark
        ? NSColor(calibratedRed: 0.34, green: 0.18, blue: 0.20, alpha: 1.0)
        : NSColor(calibratedRed: 1.0, green: 0.86, blue: 0.88, alpha: 1.0)

    // Split-view page: the two demonstrative panes.
    splitLeftPane.backgroundColor = dark
        ? NSColor(calibratedRed: 0.16, green: 0.25, blue: 0.37, alpha: 1.0)
        : NSColor(calibratedRed: 0.86, green: 0.93, blue: 1.0, alpha: 1.0)
    splitRightPane.backgroundColor = dark
        ? NSColor(calibratedRed: 0.35, green: 0.28, blue: 0.17, alpha: 1.0)
        : NSColor(calibratedRed: 1.0, green: 0.92, blue: 0.84, alpha: 1.0)

    // A focused field is tinted with the (cached) focus color; re-apply so a
    // switch while a field holds focus rebuilds its brush too.
    updateFocusDisplay()

    // The collection views' section header/footer bands are supplementary
    // views built once from the launch appearance and not recreated on a
    // repaint — reload so the delegate rebuilds them for the live appearance.
    collectionView.reloadData()
    listsCollectionView.reloadData()

    contentView.needsDisplay = true
}

// Live system theme switches: AppKit has no notification for effective-
// appearance changes (apps use KVO, which is gated on the 12.1 reflection
// layer), so this observer is a fenced platform seam — the chocolates post
// their own notification after re-theming.
#if canImport(WinChocolate) || canImport(LinChocolate)
_ = NotificationCenter.default.addObserver(
    forName: NSApplication.winEffectiveAppearanceDidChangeNotification,
    object: nil,
    queue: nil
) { _ in
    applyLiveAppearanceRefresh()
}
#endif

// MARK: - Captions
//
// Every caption in the demo is an NSTextField, and `NSTextField(string:)` is real AppKit
// for an *editable, bordered, background-drawing* field — that is its documented job.
// Left alone they draw a box, take first responder and swallow typing (the Clicks label
// was eating keystrokes). AppKit's own answer for a caption is `NSTextField(labelWithString:)`,
// which is exactly these four properties; the demo carries frames, so it sets them here.
//
// This runs after every page is assembled, so it is the single place that decides what is
// a caption. The demo's real input fields are listed separately below and never touched.
//
// statusLabel/focusLabel keep drawsBackground — they are deliberate colored panels
// (applyLiveAppearanceRefresh re-resolves their backgroundColor on a theme switch) — but
// they lose their borders like every other caption.
let demoCaptions: [NSTextField] = [
    counterLabel, statusLabel, focusLabel,
    // Controls page
    editableLabel, secureLabel, alertStyleLabel, notesLabel, tokenLabel, priceLabel,
    formLabel, contactNameLabel, contactStatusLabel, matrixLabel,
    deprecatedFormLabel, deprecatedFormNote,
    // Values page
    sliderLabel, sliderValueLabel, verticalSliderLabel, progressLabel, stepperLabel,
    stepperValueLabel, comboLabel, searchLabel, levelLabel, colorWellLabel,
    segmentedLabel, scrollerLabel, scrollerValueLabel, timerTickLabel, dateLabel,
    dateValueLabel, calendarLabel, ratingLabel,
    // Drawing page
    canvasLabel, canvasHintLabel, drawingEventLabel, shapesLabel, shapesZoomLabel,
    gradientsLabel, pathLabel,
    // Tables/Media page
    imageLabel, clipLabel, clipTopLeftLabel, clipTopRightLabel, clipBottomLeftLabel,
    clipBottomRightLabel, clipOriginLabel, splitLabel, tableLabel, outlineLabel,
    browserLabel, collectionLabel, visualEffectLabel, visualEffectTitle,
    // Lists / Auto Layout pages
    templateHintLabel, listsBrowserPathLabel, layoutLabel1, layoutLabel2,
    // The Nib page's labels are absent here on purpose: that page is fenced out of the
    // macOS build (see the 18.11 exclusion above) and already sets these itself.
]
for caption in demoCaptions {
    caption.isBordered = false
    caption.isEditable = false
    caption.isSelectable = false
    if caption !== statusLabel && caption !== focusLabel {
        caption.drawsBackground = false
    }
}

window.contentView = contentView

// Live Auto Layout resize: when the Auto Layout page is showing, stretch the
// page + the resize-demo container to the window's content width and re-run the
// solver, so dragging the window reflows the constraint-driven boxes in real
// time. Other pages stay frame-based, so nothing else needs a resize pass.
final class DemoWindowDelegate: NSObject, NSWindowDelegate {
    /// Apple declares this as `windowDidResize(_ notification: Notification)` — the Swift
    /// value type, not `NSNotification`. `NSWindowDelegate` is an `@objc` protocol with
    /// *optional* methods, so a near-miss signature is not a witness, never gets
    /// `@objc`-exposed, and is simply never called: `responds(to: "windowDidResize:")` is
    /// **false**. Declared `NSNotification` (the chocolate frameworks' spelling) this
    /// method compiled, read correctly, and never once ran — which is why the Auto Layout
    /// page never reflowed and every box on it sat static.
    ///
    /// Swift *does* warn: "instance method 'windowDidResize' nearly matches optional
    /// requirement". That warning is the only signal this class of bug gives.
    func windowDidResize(_ notification: Notification) {
        MainActor.assumeIsolated {
            guard !layoutPage.isHidden else {
                return
            }
            let width = contentView.frame.size.width
            layoutPage.frame = NSRect(origin: layoutPage.frame.origin,
                                      size: NSSize(width: width, height: layoutPage.frame.size.height))
            // Reflow the whole page to the new width.
            reflowAutoLayoutPage(width: width)
        }
    }
}
let demoWindowDelegate = DemoWindowDelegate()
window.delegate = demoWindowDelegate

// --page N opens directly on a given page (handy for QA of a specific page).
// Page 9 is the scroll-stress page. `--stress` is a shortcut for it.
var initialPage = 0
if let pageFlag = CommandLine.arguments.firstIndex(of: "--page"),
   CommandLine.arguments.indices.contains(pageFlag + 1),
   let page = Int(CommandLine.arguments[pageFlag + 1]) {
    initialPage = page
}
if CommandLine.arguments.contains("--stress") {
    initialPage = 9
}
initialPage = max(0, min(initialPage, pageSelector.numberOfItems - 1))
pageSelector.selectItem(at: initialPage)
showDemoPage(initialPage)
updateFocusDisplay()

#if canImport(WinChocolate) || canImport(LinChocolate)
// Windows/Linux-only build diagnostics: `--diagnose` probes the native peer
// plumbing (backend surface, not AppKit) — a legitimate platform seam (16.2).
let demoRunsDiagnostics = CommandLine.arguments.contains("--diagnose")
#else
let demoRunsDiagnostics = false
#endif

if demoRunsDiagnostics {
    #if canImport(WinChocolate) || canImport(LinChocolate)
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
    #endif
} else {
    statusLabel.stringValue = "Ready - window shown"
    window.makeKeyAndOrderFront(nil)
    statusLabel.stringValue = window.isKeyWindow && window.isMainWindow
        ? "Ready - key/main window"
        : "Ready - window shown"
    app.run()
}
