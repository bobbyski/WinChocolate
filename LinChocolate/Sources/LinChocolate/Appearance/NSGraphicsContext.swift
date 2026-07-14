import Foundation

/// AppKit-shaped graphics context. `current` is valid inside `NSView.draw(_:)`;
/// `NSBezierPath` and `NSColor.setFill()/setStroke()` draw through it.
public final class NSGraphicsContext {

    /// The active context during a draw pass (nil outside one).
    /// `nonisolated(unsafe)`: main-thread UI framework, same contract as `NSApp`.
    nonisolated(unsafe) public private(set) static var current: NSGraphicsContext?

    let native: NativeGraphicsContext

    // CG-shim state (see CGCompat.swift): the pending path built by `addPath`
    // et al., the user-space transform stack, and shadowed stroke/fill state.
    var cgPendingSegments: [CGPathSegment] = []
    var cgTransform = CGShimTransform()
    var cgTransformStack: [CGShimTransform] = []
    var cgLineWidth: CGFloat = 1
    var cgLineCap: CGLineCap = .butt
    var cgFillColor: NSColor = .black
    var cgStrokeColor: NSColor = .black

    init(native: NativeGraphicsContext) {
        self.native = native
    }

    static func setCurrent(_ context: NSGraphicsContext?) {
        current = context
    }
}
