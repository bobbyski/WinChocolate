/// A push button control.
///
/// `NSButton` maps to the native Windows button control when realized by a
/// backend. The public surface follows AppKit's common title, target, and action
/// workflow.
open class NSButton: NSControl {
    /// The button title.
    open var title: String

    /// Creates a button with a frame.
    public override init(frame frameRect: NSRect) {
        self.title = ""
        super.init(frame: frameRect)
    }

    /// Creates a titled button with a frame.
    public init(title: String, frame frameRect: NSRect) {
        self.title = title
        super.init(frame: frameRect)
    }

    /// Creates the native Windows button peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createButton(title: title, frame: frame, parent: parent)
    }
}
