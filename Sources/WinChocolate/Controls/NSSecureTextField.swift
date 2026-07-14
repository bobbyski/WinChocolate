/// A single-line secure text entry control.
///
/// `NSSecureTextField` preserves AppKit's public name while mapping to a
/// password-style native edit control in the Windows backend.
open class NSSecureTextField: NSTextField {
    /// Creates a secure text field with a frame.
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isEditable = true
        isSelectable = true
        isBordered = true
        drawsBackground = true
    }

    /// Creates a secure text field with text and a frame.
    override init(string stringValue: String, frame frameRect: NSRect) {
        super.init(string: stringValue, frame: frameRect)
        isEditable = true
        isSelectable = true
        isBordered = true
        drawsBackground = true
    }

    /// Creates an editable secure text field with an initial string.
    public static func secureTextField(withString stringValue: String) -> NSSecureTextField {
        NSSecureTextField(string: stringValue, frame: NSZeroRect)
    }

    /// Creates the native Windows secure text field peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createSecureTextField(text: stringValue, frame: frame, parent: parent)
    }
}
