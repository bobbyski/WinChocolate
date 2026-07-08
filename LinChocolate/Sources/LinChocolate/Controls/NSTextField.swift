import Foundation

/// AppKit-shaped text field. This slice implements the static-label use
/// (non-editable), which is enough for the demo's counter readout; editable
/// entry is a Phase L3.2 follow-up.
public final class NSTextField: NSView {

    /// The displayed string.
    public var stringValue: String {
        didSet { backend.setText(stringValue, for: handle) }
    }

    /// Creates a label showing `string`.
    public init(string: String, frame: NSRect) {
        self.stringValue = string
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createLabel(text: string, frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
    }
}
