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

    /// Handles mouse dragging with the left button down.
    open func mouseDragged(with event: NSEvent) {
        nextResponder?.mouseDragged(with: event)
    }

    /// Handles a right mouse button press.
    open func rightMouseDown(with event: NSEvent) {
        nextResponder?.rightMouseDown(with: event)
    }

    /// Handles a right mouse button release.
    open func rightMouseUp(with event: NSEvent) {
        nextResponder?.rightMouseUp(with: event)
    }

    /// Handles a tertiary (middle) mouse button press.
    open func otherMouseDown(with event: NSEvent) {
        nextResponder?.otherMouseDown(with: event)
    }

    /// Handles a tertiary (middle) mouse button release.
    open func otherMouseUp(with event: NSEvent) {
        nextResponder?.otherMouseUp(with: event)
    }

    /// Handles a scroll wheel movement.
    open func scrollWheel(with event: NSEvent) {
        nextResponder?.scrollWheel(with: event)
    }

    /// Applies a font change from the shared font panel.
    ///
    /// AppKit sends `changeFont(_:)` along the responder chain while the font
    /// panel selection changes; responders that handle fonts override this
    /// and read the new font from `NSFontManager.shared`. Unhandled changes
    /// continue to the next responder.
    open func changeFont(_ sender: Any?) {
        nextResponder?.changeFont(sender)
    }

    /// Applies a color change from the shared color panel.
    ///
    /// Sent along the responder chain while the color panel selection
    /// changes, matching AppKit's `changeColor(_:)` convention.
    open func changeColor(_ sender: Any?) {
        nextResponder?.changeColor(sender)
    }

    /// Copies the selection to the general pasteboard.
    ///
    /// Sent along the responder chain like AppKit's Edit-menu actions;
    /// responders with selections override this.
    open func copy(_ sender: Any?) {
        nextResponder?.copy(sender)
    }

    /// Deletes the selection after copying it to the general pasteboard.
    open func cut(_ sender: Any?) {
        nextResponder?.cut(sender)
    }

    /// Inserts the general pasteboard's contents at the selection.
    open func paste(_ sender: Any?) {
        nextResponder?.paste(sender)
    }

    /// Handles a key press.
    open func keyDown(with event: NSEvent) {
        nextResponder?.keyDown(with: event)
    }

    /// Handles a key release.
    open func keyUp(with event: NSEvent) {
        nextResponder?.keyUp(with: event)
    }

    /// Handles a change to the keyboard modifier flags.
    open func flagsChanged(with event: NSEvent) {
        nextResponder?.flagsChanged(with: event)
    }

    /// Handles the cursor entering a tracking area.
    ///
    /// The tracking-area delivery machinery is item 3.21 (hover tracking); this
    /// override point exists so responders that implement it compile and can be
    /// wired up when tracking areas land.
    open func mouseEntered(with event: NSEvent) {
        nextResponder?.mouseEntered(with: event)
    }

    /// Handles the cursor leaving a tracking area (see `mouseEntered(with:)`).
    open func mouseExited(with event: NSEvent) {
        nextResponder?.mouseExited(with: event)
    }
}
