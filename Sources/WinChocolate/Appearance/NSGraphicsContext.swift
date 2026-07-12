/// The drawing destination active during a view's `draw(_:)` pass.
///
/// AppKit installs a current graphics context before calling `NSView.draw(_:)`
/// and drawing APIs (`NSBezierPath.fill()`, `NSColor.set()`, `NSRectFill`)
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
        mutating func prepend(a pa: CGFloat, b pb: CGFloat, c pc: CGFloat, d pd: CGFloat, tx ptx: CGFloat, ty pty: CGFloat) {
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

    /// Creates a context over a backend drawing surface.
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

/// Fills a rectangle with the current fill color.
public func NSRectFill(_ rect: NSRect) {
    NSBezierPath(rect: rect).fill()
}

/// Intersects the current clip region with a rectangle.
public func NSRectClip(_ rect: NSRect) {
    NSBezierPath(rect: rect).addClip()
}

/// Frames a rectangle with a 1-point border in the current fill color.
public func NSFrameRect(_ rect: NSRect) {
    guard let context = NSGraphicsContext.current else {
        return
    }

    let path = NSBezierPath(rect: rect)
    context.nativeContext.strokePath(path.nativeSegments, color: context.fillColor, lineWidth: 1)
}
