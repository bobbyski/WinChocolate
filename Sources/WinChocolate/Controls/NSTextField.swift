/// Horizontal text alignment, matching AppKit names.
public enum NSTextAlignment: Sendable {
    /// Left-aligned text.
    case left

    /// Center-aligned text.
    case center

    /// Right-aligned text.
    case right

    /// Natural alignment for the writing direction (left here).
    case natural
}

/// The methods a text field delegate uses to observe editing.
public protocol NSTextFieldDelegate: AnyObject {
    /// Tells the delegate that editing began in the control (focus gained).
    func controlTextDidBeginEditing(_ obj: NSNotification)

    /// Tells the delegate that the control's text changed.
    func controlTextDidChange(_ obj: NSNotification)

    /// Tells the delegate that editing ended in the control (focus lost).
    func controlTextDidEndEditing(_ obj: NSNotification)
}

extension NSTextFieldDelegate {
    /// Default no-op so delegates only implement the callbacks they need.
    public func controlTextDidBeginEditing(_ obj: NSNotification) {}

    /// Default no-op so delegates only implement the callbacks they need.
    public func controlTextDidChange(_ obj: NSNotification) {}

    /// Default no-op so delegates only implement the callbacks they need.
    public func controlTextDidEndEditing(_ obj: NSNotification) {}
}

/// A single-line text entry or label control.
///
/// `NSTextField` maps to a native Windows edit/static control depending on later
/// style support. This initial API preserves AppKit's `stringValue` property.
open class NSTextField: NSControl {
    /// Notification names posted by control text editing, matching AppKit.
    public static let textDidBeginEditingNotification = "NSControlTextDidBeginEditingNotification"

    /// Posted when the control's text changes during editing.
    public static let textDidChangeNotification = "NSControlTextDidChangeNotification"

    /// Posted when editing ends in the control.
    public static let textDidEndEditingNotification = "NSControlTextDidEndEditingNotification"

    /// The delegate notified about editing begin/change/end.
    open weak var delegate: NSTextFieldDelegate?
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
    open var drawsBackground: Bool = true {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setDrawsBackground(drawsBackground, for: nativeHandle)
        }
    }

    /// Placeholder text for editable fields.
    open var placeholderString: String? {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setTextPlaceholder(placeholderString, for: nativeHandle)
        }
    }

    /// Horizontal alignment of the field's text.
    open var alignment: NSTextAlignment = .natural {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setTextAlignment(alignment, for: nativeHandle)
        }
    }

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
        backend.createTextField(text: stringValue, frame: frame, parent: parent, isEditable: isEditable, isBordered: isBordered)
    }

    /// Ensures the text field has a native peer and registers text change dispatch.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        // Labels (non-editable, no explicit background color) show the window
        // color instead of an opaque control-face rectangle. Editable fields
        // and any field given a background color stay opaque.
        let showsBackground = (isEditable || backgroundColor != nil) && drawsBackground
        backend.setDrawsBackground(showsBackground, for: handle)
        backend.setTextColor(textColor, for: handle)
        backend.setFont(font, for: handle)
        if let placeholderString {
            backend.setTextPlaceholder(placeholderString, for: handle)
        }
        if alignment != .natural {
            backend.setTextAlignment(alignment, for: handle)
        }
        backend.registerTextChangeAction(for: handle) { [weak self] text in
            guard let self else {
                return
            }

            _ = self.window?.makeFirstResponder(self)
            self.updateStringValueFromNative(text)
        }
        // Editable fields report begin/end editing on focus change so
        // `NSTextFieldDelegate` and the AppKit editing notifications fire.
        if isEditable {
            backend.registerFocusChangeAction(for: handle) { [weak self] gained in
                guard let self else {
                    return
                }

                if gained {
                    self.delegate?.controlTextDidBeginEditing(self.editingNotification(named: Self.textDidBeginEditingNotification))
                } else {
                    self.delegate?.controlTextDidEndEditing(self.editingNotification(named: Self.textDidEndEditingNotification))
                }
            }
        }
        return handle
    }

    func updateStringValueFromNative(_ text: String) {
        isUpdatingFromNative = true
        stringValue = text
        isUpdatingFromNative = false
        nativeStringValueDidChange()
        onTextChanged?(self)
        delegate?.controlTextDidChange(editingNotification(named: Self.textDidChangeNotification))
    }

    func editingNotification(named name: String) -> NSNotification {
        NSNotification(name: name, object: self)
    }

    func nativeStringValueDidChange() {}
}
