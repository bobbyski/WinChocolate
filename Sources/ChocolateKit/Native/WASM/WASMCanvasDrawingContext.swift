// `NativeDrawingContext` over Canvas 2D — the seam that lets framework-drawn
// controls paint themselves in a browser.
//
// Nine methods, and Canvas 2D can express all nine. The interesting part is not
// the mapping but the two places AppKit and the canvas disagree:
//
//   * **Text origin.** `drawText` places a run by its top-left corner;
//     `fillText` places it on the alphabetic baseline. Setting
//     `textBaseline = "top"` makes the two agree, once, centrally, instead of
//     every caller guessing at an ascent.
//   * **Gradient angle.** AppKit measures degrees counter-clockwise from the
//     positive x-axis with +y running *up*; the canvas has +y running down. One
//     negation at the angle, and nowhere else, keeps every gradient in the demo
//     pointing the way its author meant.

#if canImport(JavaScriptKit)

import JavaScriptKit
import SwiftDOM

/// Paints a view's `draw(_:)` output into a `<canvas>`.
public final class WASMCanvasDrawingContext: NativeDrawingContext {
    private var context: CanvasRenderingContext2D

    /// Images requested but not yet decoded, so a repaint can be scheduled.
    private let onImageReady: (() -> Void)?

    /// Loaded images by path, shared across paints so a repaint is not a reload.
    private let imageCache: WASMImageCache

    /// Wraps a canvas context for one paint pass.
    internal init(context: CanvasRenderingContext2D,
                  imageCache: WASMImageCache,
                  onImageReady: (() -> Void)?) {
        self.context = context
        self.imageCache = imageCache
        self.onImageReady = onImageReady
        // Set once, centrally: AppKit places a text run by its top-left corner
        // and `fillText` uses the alphabetic baseline.
        self.context.textBaseline = "top"
    }

    // MARK: - Paths

    /// Fills a path with a color using the nonzero winding rule.
    public func fillPath(_ segments: [NativePathSegment], color: NSColor) {
        guard !segments.isEmpty else { return }
        trace(segments)
        context.fillStyle = WASMNativeControlBackend.cssColor(color)
        context.fill()
    }

    /// Strokes a path with a color and line width.
    public func strokePath(_ segments: [NativePathSegment], color: NSColor, lineWidth: CGFloat) {
        guard !segments.isEmpty else { return }
        trace(segments)
        context.strokeStyle = WASMNativeControlBackend.cssColor(color)
        context.lineWidth = Double(lineWidth)
        context.stroke()
    }

    /// Intersects the current clip region with a path for later drawing.
    public func clip(to segments: [NativePathSegment]) {
        guard !segments.isEmpty else { return }
        trace(segments)
        context.clip()
    }

    /// Replays framework path segments into the canvas's current path.
    private func trace(_ segments: [NativePathSegment]) {
        context.beginPath()
        for segment in segments {
            switch segment {
            case .move(let point):
                context.moveTo(Double(point.x), Double(point.y))
            case .line(let point):
                context.lineTo(Double(point.x), Double(point.y))
            case .curve(let to, let control1, let control2):
                context.bezierCurveTo(
                    control1X: Double(control1.x), control1Y: Double(control1.y),
                    control2X: Double(control2.x), control2Y: Double(control2.y),
                    x: Double(to.x), y: Double(to.y))
            case .close:
                context.closePath()
            }
        }
    }

    // MARK: - Text

    /// Draws a single-line text run with its top-left corner at a point.
    public func drawText(_ text: String, at point: NSPoint, color: NSColor, font: NativeFontSpec) {
        context.font = Self.cssFont(font)
        context.fillStyle = WASMNativeControlBackend.cssColor(color)
        context.fillText(text, x: Double(point.x), y: Double(point.y))
    }

    /// A CSS `font` shorthand for a backend font spec.
    internal static func cssFont(_ font: NativeFontSpec) -> String {
        let style = font.italic ? "italic " : ""
        let weight = font.bold ? "600 " : ""
        let family = font.family.map { "\"\($0)\", system-ui, sans-serif" } ?? "system-ui, sans-serif"
        return "\(style)\(weight)\(font.size)px \(family)"
    }

    // MARK: - Gradients

    /// Fills a rectangle with a linear gradient along an angle in degrees.
    public func drawLinearGradient(_ stops: [NativeGradientStop], in rect: NSRect, angle: CGFloat) {
        guard !stops.isEmpty else { return }

        // AppKit's positive angles rotate toward the top of the view; the
        // canvas y-axis points down, so the angle is negated exactly here and
        // nowhere else.
        let radians = -Double(angle) * .pi / 180
        let halfWidth = Double(rect.size.width) / 2
        let halfHeight = Double(rect.size.height) / 2
        let centerX = Double(rect.origin.x) + halfWidth
        let centerY = Double(rect.origin.y) + halfHeight
        // Project the rectangle onto the gradient axis so the first and last
        // stops land exactly on the edges, whatever the angle.
        let extent = abs(halfWidth * cos(radians)) + abs(halfHeight * sin(radians))
        let deltaX = cos(radians) * extent
        let deltaY = sin(radians) * extent

        guard let gradient = context.createLinearGradient(
            x0: centerX - deltaX, y0: centerY - deltaY,
            x1: centerX + deltaX, y1: centerY + deltaY) else {
            return
        }

        for stop in stops.sorted(by: { $0.location < $1.location }) {
            gradient.addColorStop(Double(min(max(stop.location, 0), 1)),
                                  WASMNativeControlBackend.cssColor(stop.color))
        }
        context.setFillGradient(gradient)
        context.fillRect(x: Double(rect.origin.x), y: Double(rect.origin.y),
                         width: Double(rect.size.width), height: Double(rect.size.height))
    }

    // MARK: - Images

    /// Draws an image file scaled to fill a rectangle.
    ///
    /// Decoding is asynchronous and drawing is not, so a miss draws nothing and
    /// asks for a repaint; by the next frame the image is cached and paints.
    /// That is why the paint pass had to be a scheduler rather than a one-shot.
    public func drawImage(atPath path: String, in rect: NSRect, tint: NSColor?) {
        guard let image = imageCache.image(for: path, onReady: onImageReady) else {
            return
        }

        context.drawImage(image, x: Double(rect.origin.x), y: Double(rect.origin.y),
                          width: Double(rect.size.width), height: Double(rect.size.height))
        applyTint(tint, in: rect)
    }

    /// Draws an in-memory RGBA8 bitmap scaled to fill a rectangle.
    ///
    /// `putImageData` ignores both scaling and the clip region, so the pixels
    /// go into an offscreen canvas first and that canvas is drawn — which
    /// honours the destination rectangle and the clip like any other image.
    public func drawImage(rgbaPixels: [UInt8], width: Int, height: Int,
                          in rect: NSRect, tint: NSColor?) {
        guard width > 0, height > 0, !rgbaPixels.isEmpty else { return }

        let scratch = Element.canvas()
        let canvas = scratch.asCanvas
        canvas.width = width
        canvas.height = height
        guard let scratchContext = canvas.getContext2D(),
              let data = scratchContext.createImageData(width: width, height: height) else {
            return
        }

        data.setPixels(rgbaPixels)
        scratchContext.putImageData(data, x: 0, y: 0)
        context.drawImage(scratch, x: Double(rect.origin.x), y: Double(rect.origin.y),
                          width: Double(rect.size.width), height: Double(rect.size.height))
        applyTint(tint, in: rect)
    }

    /// Recolors the image just drawn, keeping its alpha — AppKit's template
    /// rendering. `source-atop` paints only where the image already is.
    private func applyTint(_ tint: NSColor?, in rect: NSRect) {
        guard let tint else { return }
        context.save()
        context.globalCompositeOperation = "source-atop"
        context.fillStyle = WASMNativeControlBackend.cssColor(tint)
        context.fillRect(x: Double(rect.origin.x), y: Double(rect.origin.y),
                         width: Double(rect.size.width), height: Double(rect.size.height))
        context.restore()
    }

    // MARK: - State

    /// Saves the drawing state, including the clip region.
    public func saveState() {
        context.save()
    }

    /// Restores the most recently saved drawing state.
    public func restoreState() {
        context.restore()
    }
}

/// Decoded images, kept across paints so a repaint is not a reload.
internal final class WASMImageCache {
    private var images: [String: Element] = [:]
    private var pending: Set<String> = []
    private var listeners: [EventListener] = []

    /// Returns a decoded image, or nil and starts decoding one.
    internal func image(for path: String, onReady: (() -> Void)?) -> Element? {
        if let image = images[path] {
            return image
        }
        guard !pending.contains(path) else {
            return nil
        }

        pending.insert(path)
        let image = Element.create("img")
        listeners.append(image.addEventListener(.load) { [weak self] _ in
            guard let self else { return }
            self.images[path] = image
            self.pending.remove(path)
            onReady?()
        })
        _ = image.setAttribute("src", WASMImageCache.url(for: path))
        return nil
    }

    /// Maps a framework file path onto the URL the page serves it from.
    private static func url(for path: String) -> String {
        let name = path.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last.map(String.init) ?? path
        return "Resources/\(WASMNativeControlBackend.repairingTruncatedExtension(name))"
    }
}

#endif
