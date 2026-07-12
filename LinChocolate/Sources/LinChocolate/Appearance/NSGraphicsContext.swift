import Foundation

/// AppKit-shaped graphics context. `current` is valid inside `NSView.draw(_:)`;
/// `NSBezierPath` and `NSColor.setFill()/setStroke()` draw through it.
public final class NSGraphicsContext {

    /// The active context during a draw pass (nil outside one).
    /// `nonisolated(unsafe)`: main-thread UI framework, same contract as `NSApp`.
    nonisolated(unsafe) public private(set) static var current: NSGraphicsContext?

    let native: NativeGraphicsContext

    init(native: NativeGraphicsContext) {
        self.native = native
    }

    static func setCurrent(_ context: NSGraphicsContext?) {
        current = context
    }
}
