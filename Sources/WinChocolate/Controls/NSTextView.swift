/// A multiline text editing view.
///
/// This first slice provides the common AppKit `string` surface and maps to a
/// native multiline Windows edit control.
open class NSTextView: NSControl {
    private var isUpdatingFromNative = false

    /// The text view's current string.
    open var string: String {
        didSet {
            guard !isUpdatingFromNative, let nativeHandle else {
                return
            }

            realizedBackend?.setText(string, for: nativeHandle)
        }
    }

    /// Whether the text view accepts editing.
    open var isEditable: Bool

    /// Whether the text view accepts selection.
    open var isSelectable: Bool

    /// The text color, when explicitly set.
    open var textColor: NSColor? {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setTextColor(textColor, for: nativeHandle)
        }
    }

    /// The text font, when explicitly set.
    open var font: NSFont? {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setFont(font, for: nativeHandle)
        }
    }

    /// Swift-native callback invoked when editing changes the text.
    open var onTextChanged: ((NSTextView) -> Void)?

    /// Creates a text view with a frame.
    public override init(frame frameRect: NSRect) {
        self.string = ""
        self.isEditable = true
        self.isSelectable = true
        super.init(frame: frameRect)
    }

    /// Replaces all text in the receiver.
    open func setString(_ string: String) {
        self.string = string
    }

    /// Appends text to the receiver.
    open func insertText(_ text: String) {
        string += text
    }

    /// Creates the native multiline text peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createTextView(text: string, frame: frame, parent: parent, isEditable: isEditable)
    }

    /// Ensures the text view has a native peer and registers text-change dispatch.
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
            self.updateStringFromNative(text)
        }
        return handle
    }

    private func updateStringFromNative(_ text: String) {
        isUpdatingFromNative = true
        string = text
        objectValue = text
        isUpdatingFromNative = false
        onTextChanged?(self)
    }
}
