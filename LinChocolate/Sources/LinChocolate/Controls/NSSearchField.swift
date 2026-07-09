import Foundation

/// AppKit-shaped search field (GtkSearchEntry). An editable text field with
/// search affordances; reports edits through `onTextChange`.
public final class NSSearchField: NSView {

    private var backingValue: String

    /// The current search string.
    public var stringValue: String {
        get { backingValue }
        set {
            backingValue = newValue
            backend.setText(newValue, for: handle)
        }
    }

    /// Called as the user edits the search text.
    public var onTextChange: ((NSSearchField) -> Void)?

    /// Creates a search field.
    public init(string: String, frame: NSRect) {
        self.backingValue = string
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createSearchField(text: string, frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
        backend.setTextChangeAction(for: handle) { [weak self] text in
            guard let self else { return }
            self.backingValue = text          // sync silently
            self.onTextChange?(self)
        }
    }
}
