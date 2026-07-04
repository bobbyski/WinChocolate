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

    /// Lays out this view's subtree if it has been flagged as needing layout.
    public func layoutSubtreeIfNeeded() {
        if needsLayout {
            layout()
            needsLayout = false
        }
    }

    /// Flags the view's intrinsic size as stale. A no-op until a constraint
    /// solver exists, but keeps call sites source-compatible.
    public func invalidateIntrinsicContentSize() {}
}
