/// Base class for objects that participate in event dispatch.
///
/// AppKit routes keyboard and mouse input through a responder chain. This first
/// WinChocolate implementation preserves that shape and forwards unhandled
/// events to `nextResponder`.
open class NSResponder: NSObject {
    /// The next object in the responder chain.
    open weak var nextResponder: NSResponder?

    /// Whether this responder can become first responder.
    open var acceptsFirstResponder: Bool {
        false
    }

    /// Called when the object is asked to become first responder.
    open func becomeFirstResponder() -> Bool {
        acceptsFirstResponder
    }

    /// Called when the object is asked to resign first responder.
    open func resignFirstResponder() -> Bool {
        true
    }

    /// Handles a left mouse button press.
    open func mouseDown(with event: NSEvent) {
        nextResponder?.mouseDown(with: event)
    }

    /// Handles a left mouse button release.
    open func mouseUp(with event: NSEvent) {
        nextResponder?.mouseUp(with: event)
    }

    /// Handles mouse movement.
    open func mouseMoved(with event: NSEvent) {
        nextResponder?.mouseMoved(with: event)
    }

    /// Handles a key press.
    open func keyDown(with event: NSEvent) {
        nextResponder?.keyDown(with: event)
    }

    /// Handles a key release.
    open func keyUp(with event: NSEvent) {
        nextResponder?.keyUp(with: event)
    }
}
