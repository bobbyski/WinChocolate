// The paint pass, and the only honest way to find a framework-drawn control.
//
// Most controls announce themselves: `createSlider` says "slider". A whole
// category does not. `NSSegmentedControl`, `NSColorWell`, `NSTokenField`, the
// drawn `NSTableView`, `NSToolbarView` and every custom `draw(_:)` view in the
// demo are plain `NSView`s that paint themselves — from the backend's side they
// are indistinguishable from an empty container, so they were the one place
// this backend still failed silently: an empty box, no caption, nothing to say
// a control belonged there.
//
// They cannot be found by name, because the whole point is that they are any
// class at all. But they can be found by *asking*: run the view's registered
// draw action into `RecordingDrawingContext` — which already exists, and which
// the contract suite already drives this exact way — and count what it emits.
// Nothing means a plain container. Anything means a view that would have drawn,
// and that is precisely the set that deserves a placeholder.
//
// The scheduler around it is not scaffolding either. `registerDrawAction` fires
// for every view, so probing inline would run every draw action during
// realization; batching on `requestAnimationFrame` collapses that to one pass
// and matches what the browser wants anyway.
//
// That probe now decides between three outcomes rather than two:
//
//   * no drawing commands       -> a plain container; leave it entirely alone
//   * one bounds-covering fill  -> a background colour, so CSS does it and no
//                                  canvas is created (the demo has hundreds)
//   * anything else             -> a real `<canvas>`, painted through
//                                  `WASMCanvasDrawingContext`
//
// The captioned placeholder survives as the fallback for a view whose canvas
// context cannot be obtained, which is the case that would otherwise be a
// silent empty box.

#if canImport(JavaScriptKit)

import JavaScriptKit
import SwiftDOM

extension WASMNativeControlBackend {
    /// Queues a view for the next paint pass.
    internal func markNeedsPaint(_ handle: NativeHandle) {
        dirtyHandles.insert(handle)
        guard !isPaintScheduled, DOM.isBrowser else {
            return
        }

        isPaintScheduled = true
        // `setTimeout`, not `requestAnimationFrame`. rAF is the textbook answer
        // for batching paint work and it is the wrong one here: frames
        // requested from inside a wasm call do not arrive in this runtime, so
        // every repaint after the initial synchronous flush was silently
        // dropped. Controls took their clicks, updated their state, marked
        // themselves dirty — and never redrew, which looks exactly like input
        // not working. `dispatchAsync` already proves `setTimeout` fires here.
        //
        // Coalescing is preserved: `isPaintScheduled` still collapses a burst
        // of invalidations into one drain on the next turn of the loop.
        _ = DOM.window.setTimeout(milliseconds: 0) { [weak self] in
            self?.drainPaint()
        }
    }

    /// Paints everything dirty now, whatever the frame clock is doing.
    ///
    /// Called once from `runApplication()` after the desktop is mounted, and
    /// this is not belt-and-braces — it is load-bearing. Every view realizes
    /// *before* `run()` is reached, so the first `requestAnimationFrame` is
    /// requested while wasm `main` is still on the stack, and that frame never
    /// arrives. `isPaintScheduled` then stays latched at `true`, every later
    /// mark is suppressed as "already scheduled", and painting is disabled for
    /// the lifetime of the page — from one missed frame. Draining here clears
    /// the latch and paints the tree the demo built during startup.
    internal func flushPaint() {
        isPaintScheduled = false
        drainPaint()
    }

    /// Probes every dirty view once and captions the ones that draw.
    internal func drainPaint() {
        isPaintScheduled = false
        let handles = dirtyHandles
        dirtyHandles.removeAll()
        for handle in handles {
            paintOnce(handle)
        }
    }

    /// Runs one view's draw action and decides what it is.
    internal func paintOnce(_ handle: NativeHandle) {
        // Settled already: either it drew and was captioned, or it is a control
        // with its own element and no business being probed.
        guard !drawnHandles.contains(handle),
              placeholderCaptions[handle] == nil,
              let element = elements[handle],
              let action = drawActions[handle],
              let record = records[handle] else {
            return
        }

        let bounds = NSMakeRect(0, 0, record.frame.size.width, record.frame.size.height)
        let recording = RecordingDrawingContext()
        action(recording, bounds)

        let commandCount = recording.fills.count + recording.strokes.count
            + recording.texts.count + recording.images.count
            + recording.bitmapImages.count + recording.gradients.count
        guard commandCount > 0 else {
            // A plain container. Leave it completely alone — this is the
            // overwhelmingly common case, and striping it would bury the page.
            return
        }

        // A view whose entire drawing is one fill covering its bounds is not
        // worth a canvas — it is a background colour, and CSS has those. The
        // demo is full of them (`DemoFilledView`, every page's backdrop), so
        // this keeps hundreds of canvases off the page and is exact, not an
        // approximation. Not marked as settled: a view that starts as a plain
        // fill may draw something richer once its state changes.
        if commandCount == 1, let fill = recording.fills.first,
           Self.coversBounds(fill.segments, bounds: bounds) {
            _ = element.setStyle("background-color", Self.cssColor(fill.color))
            return
        }

        paintToCanvas(handle, element: element, action: action, bounds: bounds)
    }

    /// Repaints a view into its own `<canvas>`.
    ///
    /// The canvas is the view's first child, so it sits behind the real
    /// controls parented into the same view — a drawn container still hosts
    /// live children on top of its own artwork.
    private func paintToCanvas(_ handle: NativeHandle, element: Element,
                               action: (NativeDrawingContext, NSRect) -> Void,
                               bounds: NSRect) {
        let scale = DOM.window.devicePixelRatio
        let canvas = canvasFor(handle, element: element, bounds: bounds, scale: scale)
        guard let context = canvas.asCanvas.getContext2D() else {
            // No 2D context to be had. Say so on screen rather than leaving an
            // empty box — this is the path the placeholder was built for.
            drawnHandles.insert(handle)
            stampDrawnPlaceholder(handle, element: element, commandCount: 1)
            return
        }

        context.save()
        // The backing store is in device pixels and every drawing call is in
        // AppKit points, so the scale is applied once, here, and nowhere else.
        context.scale(x: scale, y: scale)
        context.clearRect(x: 0, y: 0,
                          width: Double(bounds.size.width), height: Double(bounds.size.height))
        let drawing = WASMCanvasDrawingContext(
            context: context,
            imageCache: imageCache,
            onImageReady: { [weak self] in self?.markNeedsPaint(handle) })
        action(drawing, bounds)
        context.restore()
    }

    /// The view's canvas, created and sized on first use and resized after.
    private func canvasFor(_ handle: NativeHandle, element: Element,
                           bounds: NSRect, scale: Double) -> Element {
        let width = Int((Double(bounds.size.width) * scale).rounded())
        let height = Int((Double(bounds.size.height) * scale).rounded())

        if let existing = drawingCanvases[handle] {
            let canvas = existing.asCanvas
            if canvas.width != width || canvas.height != height {
                canvas.width = width
                canvas.height = height
                _ = existing
                    .setStyle("width", "\(bounds.size.width)px")
                    .setStyle("height", "\(bounds.size.height)px")
            }
            return existing
        }

        let surface = Element.canvas()
        let canvas = surface.asCanvas
        canvas.width = width
        canvas.height = height
        _ = surface
            .setStyle("position", "absolute")
            .setStyle("left", "0").setStyle("top", "0")
            .setStyle("width", "\(bounds.size.width)px")
            .setStyle("height", "\(bounds.size.height)px")
            // The view's own controls are its other children and must stay
            // clickable; the artwork behind them never is.
            .setStyle("pointer-events", "none")
        _ = element.prepend(surface)
        drawingCanvases[handle] = surface
        return surface
    }

    /// Whether a path's extent effectively covers a view's whole bounds.
    ///
    /// Only straight-edged paths qualify: a curve in the outline means a shape,
    /// and a shape is not a background however much of the box it spans.
    internal static func coversBounds(_ segments: [NativePathSegment], bounds: NSRect) -> Bool {
        guard bounds.size.width > 0, bounds.size.height > 0 else {
            return false
        }

        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        for segment in segments {
            switch segment {
            case .move(let point), .line(let point):
                minX = min(minX, point.x); maxX = max(maxX, point.x)
                minY = min(minY, point.y); maxY = max(maxY, point.y)
            case .curve:
                return false
            case .close:
                continue
            }
        }

        guard maxX > minX, maxY > minY else {
            return false
        }

        // A point of slack at each edge: framework fills routinely inset or
        // round by a fraction and are still plainly backgrounds.
        return minX <= 1 && minY <= 1
            && maxX >= bounds.size.width - 1
            && maxY >= bounds.size.height - 1
    }

    /// Marks a view that paints itself but cannot be painted yet.
    ///
    /// Styled like an ordinary placeholder but never a *container* placeholder:
    /// a drawn view's children are real and are already inside it, so this only
    /// adds a border and a caption and never touches layout.
    private func stampDrawnPlaceholder(_ handle: NativeHandle, element: Element,
                                       commandCount: Int) {
        let name = debugClassNames[handle] ?? "Custom NSView"
        _ = element
            .setStyle("box-sizing", "border-box")
            .setStyle("border", "1px dashed #7a6ac0")
            .setStyle("background",
                      "repeating-linear-gradient(-45deg, rgba(140,120,220,.14) 0 6px, transparent 6px 12px)")
        _ = element.setAttribute("data-cx-placeholder", "1")
        _ = element.setAttribute("data-cx-kind", "drawn")
        _ = element.setAttribute("data-cx-class", name)
        _ = element.setAttribute(
            "title",
            "\(name) — draws itself; \(commandCount) drawing operation\(commandCount == 1 ? "" : "s") pending a canvas (WASM backend)")

        let caption = Element.div()
            .setStyle("position", "absolute")
            .setStyle("left", "2px").setStyle("top", "0")
            .setStyle("max-width", "100%")
            .setStyle("font", "10px/1.2 ui-monospace, monospace")
            .setStyle("color", "#4c3f8a")
            .setStyle("white-space", "nowrap")
            .setStyle("overflow", "hidden")
            .setStyle("text-overflow", "ellipsis")
            .setStyle("pointer-events", "none")
        caption.textContent = "\(name) ✎\(commandCount)"
        _ = element.appendChild(caption)
        drawnCaptions[handle] = caption
    }
}

#endif
