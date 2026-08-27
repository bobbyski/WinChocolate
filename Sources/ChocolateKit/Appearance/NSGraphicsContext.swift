import WinCoreGraphics

/// The drawing destination active during a view's `draw(_:)` pass.
///
/// AppKit installs a current graphics context before calling `NSView.draw(_:)`
/// and drawing APIs (`NSBezierPath.fill()`, `NSColor.set()`, `NSRect.fill()`)
/// implicitly target it. WinChocolate preserves that shape: the framework
/// installs a context wrapping the backend's native drawing surface, and the
/// color state set through `NSColor` lives here.
open class NSGraphicsContext {
    /// The context drawing is currently directed at, when inside `draw(_:)`.
    ///
    /// Drawing happens on the native UI thread during paint dispatch, so this
    /// mirrors the backend's single-threaded access pattern.
    nonisolated(unsafe) public private(set) static var current: NSGraphicsContext?

    /// The backend surface this context rasterizes into.
    internal let nativeContext: NativeDrawingContext

    /// Color used by fill operations until changed through `NSColor`.
    internal var fillColor: NSColor = .black

    /// Color used by stroke operations until changed through `NSColor`.
    internal var strokeColor: NSColor = .black

    // MARK: CG-shim state (see CGCompat.swift)

    /// A 2×3 affine transform matching Core Graphics' layout:
    /// `x' = a·x + c·y + tx`, `y' = b·x + d·y + ty`.
    struct WinTransform {
        var a: CGFloat = 1
        var b: CGFloat = 0
        var c: CGFloat = 0
        var d: CGFloat = 1
        var tx: CGFloat = 0
        var ty: CGFloat = 0

        /// Applies the transform to a point.
        func apply(to point: NSPoint) -> NSPoint {
            NSPoint(x: a * point.x + c * point.y + tx, y: b * point.x + d * point.y + ty)
        }

        /// Concatenates another transform before this one (CG's convention
        /// for cumulative context transforms).
        mutating func prepend(_ transform: WinTransform) {
            let pa = transform.a
            let pb = transform.b
            let pc = transform.c
            let pd = transform.d
            let ptx = transform.tx
            let pty = transform.ty
            let na = a * pa + c * pb
            let nb = b * pa + d * pb
            let nc = a * pc + c * pd
            let nd = b * pc + d * pd
            let ntx = a * ptx + c * pty + tx
            let nty = b * ptx + d * pty + ty
            (a, b, c, d, tx, ty) = (na, nb, nc, nd, ntx, nty)
        }

        /// The overall scale magnitude (for radius-like values).
        var scaleMagnitude: CGFloat {
            let sx = a * a + b * b
            let sy = c * c + d * d
            return sqrt(max(sx, sy))
        }
    }

    /// The CG shim's current user-space transform.
    var winTransform = WinTransform()

    /// Saved transforms paired with `saveGState`/`restoreGState`.
    var winTransformStack: [WinTransform] = []

    /// The CG shim's pending path, consumed by fill/stroke/clip.
    var winPendingSegments: [NativePathSegment] = []

    /// The CG shim's stroke width.
    var winLineWidth: CGFloat = 1

    /// The CG shim's line cap (stored; native strokes render default caps).
    var winLineCap: CGLineCap = .butt

    /// The CG shim's line join (stored; native strokes render default joins).
    var winLineJoin: CGLineJoin = .miter

    /// The dash pattern set by `setLineDash(phase:lengths:)`, empty for solid.
    ///
    /// Kept here with the rest of the CG shim state because it is *state*: CG
    /// sets it on the context and every later stroke honours it until it is
    /// cleared or the gstate is restored.
    var winLineDashLengths: [CGFloat] = []

    /// How far into the dash pattern the first segment starts.
    var winLineDashPhase: CGFloat = 0

    /// The CG shim's global alpha, multiplied into every source colour.
    var winAlpha: CGFloat = 1

    /// The CG shim's antialiasing flag (stored; backends always antialias).
    var winShouldAntialias: Bool = true

    /// The paint state `saveGState` preserves alongside the transform.
    ///
    /// The transform has its own stack for historical reasons; everything the
    /// CG shim added since travels together in this one, so a `setAlpha` inside
    /// a save/restore bracket cannot leak past the restore.
    struct WinGState {
        var alpha: CGFloat
        var lineWidth: CGFloat
        var lineCap: CGLineCap
        var lineJoin: CGLineJoin
        var shouldAntialias: Bool
        var lineDashLengths: [CGFloat]
        var lineDashPhase: CGFloat
    }

    /// Paint state saved by `saveGState`.
    var winStateStack: [WinGState] = []

    /// Creates a context over a backend drawing surface.
    /// Core Graphics' bitmap-context initializer.
    ///
    /// **For code that needs a context to compute with, not to show.** The CG
    /// spelling is the standard way to get one: hit-testing measures text and
    /// paths through the same helpers that draw them, and those helpers take a
    /// context. Nothing this context receives is ever presented.
    ///
    /// There is no bitmap behind it. A page has no image buffer to hand back
    /// and no way to show one if it did, and the callers using this spelling
    /// are measuring rather than rasterizing — so the drawing is recorded and
    /// discarded. A caller who genuinely wants pixels wants `NSBitmapImageRep`,
    /// which is a different and honest API.
    ///
    /// **A designated initializer, not a convenience one.** `self.init` inside
    /// a convenience initializer dispatches to the *dynamic* type's designated
    /// initializer, and this class is `open` — which on wasm32 is a function
    /// signature mismatch trap at the first call rather than an error anywhere
    /// earlier.
    ///
    /// Fails on a zero or negative size, as Core Graphics does.
    public init?(
        data: UnsafeMutableRawPointer?,
        width: Int,
        height: Int,
        bitsPerComponent: Int,
        bytesPerRow: Int,
        space: CGColorSpace,
        bitmapInfo: UInt32
    ) {
        guard width > 0, height > 0 else { return nil }
        self.nativeContext = RecordingDrawingContext()
    }

    internal init(nativeContext: NativeDrawingContext) {
        self.nativeContext = nativeContext
    }

    /// Runs a drawing block with this context installed as `current`.
    internal func asCurrent(_ body: () -> Void) {
        let previous = NSGraphicsContext.current
        NSGraphicsContext.current = self
        body()
        NSGraphicsContext.current = previous
    }

    /// Saves the current context's graphics state, including the clip region.
    open class func saveGraphicsState() {
        current?.nativeContext.saveState()
    }

    /// Restores the current context's most recently saved graphics state.
    open class func restoreGraphicsState() {
        current?.nativeContext.restoreState()
    }

    /// Saves this context's graphics state, including the clip region.
    open func saveGraphicsState() {
        nativeContext.saveState()
    }

    /// Restores this context's most recently saved graphics state.
    open func restoreGraphicsState() {
        nativeContext.restoreState()
    }
}

// Rectangle drawing, matching AppKit's Swift overlay exactly: modern SDKs do
// not expose the C functions (`NSRectFill`, `NSFrameRect`, `NSRectClip`) to
// Swift — the spellings are `rect.fill()`, `rect.frame()`, and `rect.clip()`
// (18.12 round 2).
extension NSRect {
    /// Fills the rectangle with the current fill color.
    public func fill(using operation: NSCompositingOperation = .sourceOver) {
        NSBezierPath(rect: self).fill()
    }

    /// Frames the rectangle with a border in the current fill color.
    public func frame(withWidth width: CGFloat = 1.0, using operation: NSCompositingOperation = .sourceOver) {
        guard let context = NSGraphicsContext.current else {
            return
        }

        let path = NSBezierPath(rect: self)
        context.nativeContext.strokePath(path.nativeSegments, color: context.fillColor, lineWidth: width)
    }

    /// Intersects the current clip region with the rectangle.
    public func clip() {
        NSBezierPath(rect: self).addClip()
    }
}
