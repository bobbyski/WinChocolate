/// A single-line text entry or label control.
///
/// `NSTextField` maps to a native Windows edit/static control depending on later
/// style support. This initial API preserves AppKit's `stringValue` property.
open class NSTextField: NSControl {
    /// The text field's current string value.
    open var stringValue: String

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
        backend.createTextField(text: stringValue, frame: frame, parent: parent)
    }
}
