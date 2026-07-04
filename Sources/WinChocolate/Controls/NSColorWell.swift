/// A color well control.
///
/// This implementation provides AppKit-compatible color state and a clickable
/// native swatch. Activating the well attaches it to the shared
/// `NSColorPanel`, so colors confirmed in the panel's chooser flow back into
/// the well's `color`.
open class NSColorWell: NSControl {
    /// The visual presentation style of a color well.
    public enum Style: Equatable, Sendable {
        /// The standard bordered swatch.
        case `default`

        /// A compact borderless swatch.
        case minimal

        /// A swatch with a dropdown affordance.
        case expanded
    }

    /// The color well's presentation style.
    open var colorWellStyle: Style = .default

    /// Whether the color well draws a border.
    open var isBordered: Bool = true

    /// The selected color.
    open var color: NSColor {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setBackgroundColor(color, for: nativeHandle)
        }
    }

    /// Whether the color well is active.
    open private(set) var isActive: Bool

    /// Creates a color well with a frame.
    public override init(frame frameRect: NSRect) {
        self.color = .white
        self.isActive = false
        super.init(frame: frameRect)
        self.objectValue = color
    }

    /// Activates the color well and attaches it to the shared color panel.
    open func activate(_ exclusive: Bool) {
        isActive = true
        let panel = NSColorPanel.shared
        panel.winActiveColorWell = self
        panel.color = color
    }

    /// Deactivates the color well and detaches it from the shared color panel.
    open func deactivate() {
        isActive = false
        if NSColorPanel.shared.winActiveColorWell === self {
            NSColorPanel.shared.winActiveColorWell = nil
        }
    }

    /// Creates the native swatch peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createImageView(description: "", imagePath: nil, frame: frame, parent: parent)
    }

    /// Ensures the swatch color is synced after realization.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        backend.setBackgroundColor(color, for: handle)
        return handle
    }

    open override func mouseDown(with event: NSEvent) {
        activate(true)
        objectValue = color
        sendAction()
        // Clicking a color well also brings up the shared color panel,
        // matching AppKit; panel picks then flow back into this well live.
        NSColorPanel.shared.makeKeyAndOrderFront(self)
        super.mouseDown(with: event)
    }
}
