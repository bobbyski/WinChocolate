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
