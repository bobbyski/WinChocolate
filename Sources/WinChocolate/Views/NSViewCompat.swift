extension NSView {
    /// Sets the frame origin, keeping the current size.
    public func setFrameOrigin(_ newOrigin: NSPoint) {
        frame.origin = newOrigin
    }

    /// Sets the frame size, keeping the current origin.
    public func setFrameSize(_ newSize: NSSize) {
        frame.size = newSize
    }

    /// Marks the whole view as needing display.
    public func setNeedsDisplay() {
        needsDisplay = true
    }

    /// Requests that the view redraw. WinChocolate schedules the redraw through
    /// the native invalidation path rather than drawing synchronously.
    public func display() {
        needsDisplay = true
    }

    /// Returns whether a point (in this view's coordinates) lies in a rectangle.
    public func mouse(_ point: NSPoint, in rect: NSRect) -> Bool {
        rect.contains(point)
    }

    /// Flags the view's intrinsic size as stale, scheduling a layout pass so the
    /// solver re-reads `intrinsicContentSize` (9.2). A control whose content
    /// (e.g. text) changed its natural size calls this to re-lay-out.
    public func invalidateIntrinsicContentSize() {
        needsLayout = true
    }
}
