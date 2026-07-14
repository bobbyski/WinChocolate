import Foundation

/// AppKit-shaped editable combo box (GtkComboBoxText with an entry). The user
/// can type a value or pick from `itemTitles`; either way `stringValue` updates
/// and `onTextChange` fires.
public final class NSComboBox: NSView {

    /// The dropdown item titles, in order.
    public var itemTitles: [String]

    private var backingValue: String

    /// The current text (typed or chosen).
    public var stringValue: String {
        get { backingValue }
        set {
            backingValue = newValue
            backend.setText(newValue, for: handle)
        }
    }

    /// Called when the text changes (typing or selecting an item).
    public var onTextChange: ((NSComboBox) -> Void)?

    /// AppKit-shaped alias for `onTextChange` (WinChocolate's demo name).
    public var onComboBoxTextChanged: ((NSComboBox) -> Void)? {
        get { onTextChange }
        set { onTextChange = newValue }
    }

    /// Fired when the user commits a value (Return or picking an item).
    /// Wired off the same text-change signal for now.
    public var onAction: ((NSComboBox) -> Void)?

    /// AppKit's frame-only initializer: an empty combo box.
    public required convenience init(frame: NSRect) {
        self.init(items: [], frame: frame)
    }

    /// Creates a combo box showing `items` (first item selected initially).
    public init(items: [String], frame: NSRect) {
        self.itemTitles = items
        self.backingValue = items.first ?? ""
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createComboBox(items: items, text: backingValue, frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
        backend.setTextChangeAction(for: handle) { [weak self] text in
            guard let self else { return }
            self.backingValue = text          // sync silently
            self.onTextChange?(self)
            self.onAction?(self)
        }
    }
}
