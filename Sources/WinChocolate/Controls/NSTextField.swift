/// A single-line text entry or label control.
///
/// `NSTextField` maps to a native Windows edit/static control depending on later
/// style support. This initial API preserves AppKit's `stringValue` property.
open class NSTextField: NSControl {
    private var isUpdatingFromNative = false

    /// The text field's current string value.
    open var stringValue: String {
        didSet {
            guard !isUpdatingFromNative else {
                return
            }

            guard let nativeHandle else {
                return
            }

            realizedBackend?.setText(stringValue, for: nativeHandle)
        }
    }

    /// Whether the text field accepts keyboard editing.
    open var isEditable: Bool = false

    /// Whether the text field accepts selection.
    open var isSelectable: Bool = false

    /// Whether the text field draws a border.
    open var isBordered: Bool = true

    /// Whether the text field draws its background.
    open var drawsBackground: Bool = true

    /// Placeholder text for editable fields.
    open var placeholderString: String?

    /// The text color, when explicitly set.
    open var textColor: NSColor? {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setTextColor(textColor, for: nativeHandle)
        }
    }

    /// The text field font, when explicitly set.
    open var font: NSFont? {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setFont(font, for: nativeHandle)
        }
    }

    /// Swift-native action invoked when user editing changes the string value.
    open var onTextChanged: ((NSTextField) -> Void)?

    /// Creates a text field with a frame.
    public override init(frame frameRect: NSRect) {
        self.stringValue = ""
        super.init(frame: frameRect)
    }

    /// Creates a text field with text and a frame.
    public init(string stringValue: String, frame frameRect: NSRect) {
        self.stringValue = stringValue
        super.init(frame: frameRect)
    }

    /// Creates a non-editable label-style text field.
    public static func label(withString stringValue: String) -> NSTextField {
        let field = NSTextField(string: stringValue, frame: NSZeroRect)
        field.isEditable = false
        field.isSelectable = false
        field.isBordered = false
        field.drawsBackground = false
        return field
    }

    /// Creates a non-editable wrapping label-style text field.
    public static func wrappingLabel(withString stringValue: String) -> NSTextField {
        label(withString: stringValue)
    }

    /// Creates an editable text field with an initial string.
    public static func textField(withString stringValue: String) -> NSTextField {
        let field = NSTextField(string: stringValue, frame: NSZeroRect)
        field.isEditable = true
        field.isSelectable = true
        field.isBordered = true
        field.drawsBackground = true
        return field
    }

    /// Creates the native Windows text field peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createTextField(text: stringValue, frame: frame, parent: parent, isEditable: isEditable)
    }

    /// Ensures the text field has a native peer and registers text change dispatch.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        backend.setTextColor(textColor, for: handle)
        backend.setFont(font, for: handle)
        backend.registerTextChangeAction(for: handle) { [weak self] text in
            guard let self else {
                return
            }

            _ = self.window?.makeFirstResponder(self)
            self.updateStringValueFromNative(text)
        }
        return handle
    }

    func updateStringValueFromNative(_ text: String) {
        isUpdatingFromNative = true
        stringValue = text
        isUpdatingFromNative = false
        nativeStringValueDidChange()
        onTextChanged?(self)
    }

    func nativeStringValueDidChange() {}
}
