/// Draws the fixed separator item used between groups of toolbar controls.
open class NSToolbarSeparatorView: NSView {
    /// Creates a separator view.
    public required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // The view itself is the thin vertical bar; layout centers it inside
        // a wider separator slot so whitespace frames it on either side.
        winBackgroundColor = NSColor(calibratedRed: 0.66, green: 0.66, blue: 0.66, alpha: 1.0)
    }

    /// Separators are display-only.
    open override var acceptsFirstResponder: Bool {
        false
    }

    /// Creates the native separator peer used by the customization palette.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = backend.createView(frame: frame, parent: parent)
        backend.setText(" \nseparator", for: handle)
        backend.setDrawsBackground(false, for: handle)
        return handle
    }
}
