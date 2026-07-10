import Foundation

/// AppKit-shaped color well (GtkColorButton) — a swatch that opens the native
/// color chooser. Reports changes through `onColorChange`; `color` is the
/// current selection.
public final class NSColorWell: NSView {

    private var backingColor: NSColor

    /// The chosen color. Setting it updates the swatch; the user's own choices
    /// flow back in via the backend.
    public var color: NSColor {
        get { backingColor }
        set {
            backingColor = newValue
            backend.setColor(newValue, for: handle)
        }
    }

    /// Called when the user picks a color in the chooser.
    public var onColorChange: ((NSColorWell) -> Void)?

    /// Creates a color well showing `color`.
    public init(color: NSColor = .blue, frame: NSRect) {
        self.backingColor = color
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createColorWell(color: color, frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
        backend.setColorChangeAction(for: handle) { [weak self] color in
            guard let self else { return }
            self.backingColor = color          // sync silently
            self.onColorChange?(self)
        }
    }
}
