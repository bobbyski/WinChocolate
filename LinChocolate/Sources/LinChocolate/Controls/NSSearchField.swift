import Foundation

/// AppKit-shaped search field (GtkSearchEntry). An editable text field with
/// search affordances; reports edits through `onTextChange`.
open class NSSearchField: NSControl {

    /// Background fill (inherited from NSTextField on Apple; these classes are
    /// NSControl siblings here until the field hierarchy lands — Issue tracked).
    public var backgroundColor: NSColor? {
        didSet { backend.setBackgroundColor(backgroundColor, for: handle) }
    }

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

    /// AppKit-shaped alias for `onTextChange`.
    public var onTextChanged: ((NSSearchField) -> Void)? {
        get { onTextChange }
        set { onTextChange = newValue }
    }

    /// Fired when the user commits the search (Return / clears the field).
    /// Wired off the same text-change signal for now.
    public var onAction: ((NSSearchField) -> Void)?

    /// AppKit's placeholder text (accepted for parity).
    public var placeholderString: String?

    /// AppKit's frame-only initializer: an empty search field.
    public required convenience init(frame: NSRect) {
        self.init(string: "", frame: frame)
    }

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
            self.sendAction()
            self.onAction?(self)
            self.sendAction()
        }
    }
}
