import Foundation

/// AppKit-shaped multi-line, editable text view (GtkTextView). Reports edits
/// through `onTextChange`; `string` is the full contents.
public final class NSTextView: NSView {

    private var backingString: String

    /// The full text. Setting it replaces the contents; the user's own edits
    /// flow back in via the backend's text-buffer change signal.
    public var string: String {
        get { backingString }
        set {
            backingString = newValue
            backend.setText(newValue, for: handle)
        }
    }

    /// Called after the user edits the text.
    public var onTextChange: ((NSTextView) -> Void)?

    /// The text's foreground color (nil = theme default).
    public var textColor: NSColor? {
        didSet {
            guard let textColor else { return }
            backend.setTextColor(textColor, for: handle)
        }
    }

    /// AppKit's frame-only initializer: an empty text view.
    public required convenience init(frame: NSRect) {
        self.init(string: "", frame: frame)
    }

    /// Creates a text view with initial `string`.
    public init(string: String, frame: NSRect) {
        self.backingString = string
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createTextView(text: string, frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
        backend.setTextChangeAction(for: handle) { [weak self] text in
            guard let self else { return }
            self.backingString = text          // sync silently
            self.onTextChange?(self)
        }
    }
}
