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

    /// Creates the native Windows text field peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createTextField(text: stringValue, frame: frame, parent: parent, isEditable: isEditable)
    }

    /// Ensures the text field has a native peer and registers text change dispatch.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        backend.registerTextChangeAction(for: handle) { [weak self] text in
            self?.updateStringValueFromNative(text)
        }
        return handle
    }

    private func updateStringValueFromNative(_ text: String) {
        isUpdatingFromNative = true
        stringValue = text
        isUpdatingFromNative = false
        onTextChanged?(self)
    }
}
