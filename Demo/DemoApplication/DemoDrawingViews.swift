// Part of the shared demo, split out of main.swift by topic.
//
// Only DECLARATIONS live here. main.swift is Swift's top-level-code file:
// its statements run in written order, and moving one here would turn it
// into a lazily-initialized global that never runs. Declarations have no
// such ordering, so they move freely.

#if canImport(LinChocolate)
import LinChocolate
#elseif canImport(WinChocolate)
import WinChocolate
#else
import AppKit
#endif

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
            let handler = onEvent
            let message = "Canvas reset (double-click)"
            MainActor.assumeIsolated {
                handler?(message)
            }
        } else {
            fillColorIndex = (fillColorIndex + 1) % Self.palette.count
            let handler = onEvent
            let message = "Canvas fill color (click)"
            MainActor.assumeIsolated {
                handler?(message)
            }
        }
        needsDisplay = true
    }

    override func rightMouseDown(with event: NSEvent) {
        strokeColorIndex = (strokeColorIndex + 1) % Self.palette.count
        let handler = onEvent
        let message = "Canvas stroke color (right-click)"
        MainActor.assumeIsolated {
            handler?(message)
        }
        needsDisplay = true
    }

    override func scrollWheel(with event: NSEvent) {
        radius = min(max(radius + event.scrollingDeltaY * 4, 16), 110)
        let handler = onEvent
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
