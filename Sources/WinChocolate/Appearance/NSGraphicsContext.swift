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
}

/// Fills a rectangle with the current fill color.
public func NSRectFill(_ rect: NSRect) {
    NSBezierPath(rect: rect).fill()
}

/// Frames a rectangle with a 1-point border in the current fill color.
public func NSFrameRect(_ rect: NSRect) {
    guard let context = NSGraphicsContext.current else {
        return
    }

    let path = NSBezierPath(rect: rect)
    context.nativeContext.strokePath(path.nativeSegments, color: context.fillColor, lineWidth: 1)
}
