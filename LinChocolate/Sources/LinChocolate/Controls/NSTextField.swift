import Foundation

/// AppKit-shaped text field, in two flavors:
///  - `init(labelWithString:frame:)` → a static, non-editable label (GtkLabel).
///  - `init(string:frame:)`          → an editable single-line field (GtkEntry).
///
/// GTK backs labels and editable fields with different widgets, so the
/// editable/non-editable choice is fixed at creation in this slice (AppKit's
/// mutable `isEditable` is a later refinement).
public final class NSTextField: NSView {

    private var backingValue: String

    /// The displayed / edited string. Setting it writes through to the control;
    /// the user's own edits flow back in via the backend's text-change event.
    public var stringValue: String {
        get { backingValue }
        set {
            backingValue = newValue
            backend.setText(newValue, for: handle)
        }
    }

    /// Called after the user edits an editable field (never fired for labels).
    public var onTextChange: ((NSTextField) -> Void)?

    // Apple-look/behavior flags accepted for API parity; GTK renders labels vs
    // fields natively, so these are mostly presentational hints today.
    public var isBordered: Bool = true
    public var isBezeled: Bool = true
    public var drawsBackground: Bool = true
    /// Whether the field is editable. AppKit's default is `false` — a
    /// non-editable field renders as a borderless static label; setting it `true`
    /// turns it into a framed, editable field (matching Win32's STATIC vs EDIT).
    public var isEditable: Bool = false {
        didSet { backend.setTextEditable(isEditable, for: handle) }
    }
    public var isSelectable: Bool = true
    public var placeholderString: String?
    public var alignment: NSTextAlignment = .natural
    public var usesSingleLineMode: Bool = true
    public var maximumNumberOfLines: Int = 0
    public weak var delegate: NSTextFieldDelegate?
    public var formatter: Formatter?
    /// AppKit's `objectValue`; setting a value updates `stringValue`.
    public var objectValue: Any? {
        get { stringValue }
        set { if let newValue { stringValue = "\(newValue)" } }
    }

    /// The text's natural size, so Auto Layout can size intrinsic labels.
    /// An estimate (no text measurement on the seam yet): ~7.2px per character
    /// at the default UI size plus label padding.
    public override var intrinsicContentSize: NSSize {
        NSMakeSize(CGFloat(stringValue.count) * 7.2 + 8, 20)
    }

    /// The text's foreground color (nil = theme default).
    public var textColor: NSColor? {
        didSet {
            guard let textColor else { return }
            backend.setTextColor(textColor, for: handle)
        }
    }

    /// Styled text with ranged colors/fonts; replaces the plain string.
    public var attributedStringValue: NSAttributedString? {
        didSet {
            guard let attributedStringValue else { return }
            backend.setStyledText(attributedStringValue.nativeRuns(), for: handle)
        }
    }

    /// Creates a static, non-editable label with no initial frame (AppKit's
    /// frameless form; assign `frame` afterwards).
    public convenience init(labelWithString string: String) {
        self.init(labelWithString: string, frame: .zero)
    }

    /// Creates a static, non-editable label.
    public init(labelWithString string: String, frame: NSRect) {
        self.backingValue = string
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createLabel(text: string, frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
    }

    /// Creates an editable single-line text field.
    public init(string: String, frame: NSRect) {
        self.backingValue = string
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createTextField(text: string, frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
        backend.setTextChangeAction(for: handle) { [weak self] text in
            guard let self else { return }
            self.backingValue = text          // sync silently — no write-back loop
            self.onTextChange?(self)
        }
    }
}
