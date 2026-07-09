import Foundation

/// AppKit-shaped secure (password) text field (GtkPasswordEntry). Like an
/// editable `NSTextField` but the characters are masked.
public final class NSSecureTextField: NSView {

    private var backingValue: String

    /// The entered string. Setting it updates the control; the user's edits
    /// flow back in via the backend.
    public var stringValue: String {
        get { backingValue }
        set {
            backingValue = newValue
            backend.setText(newValue, for: handle)
        }
    }

    /// Called after the user edits the field.
    public var onTextChange: ((NSSecureTextField) -> Void)?

    /// Creates a masked text field.
    public init(string: String, frame: NSRect) {
        self.backingValue = string
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createSecureTextField(text: string, frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
        backend.setTextChangeAction(for: handle) { [weak self] text in
            guard let self else { return }
            self.backingValue = text          // sync silently
            self.onTextChange?(self)
        }
    }
}
