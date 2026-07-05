/// A titled container view.
///
/// `NSBox` currently maps to a native Windows group box. It gives AppKit-shaped
/// code a familiar framed grouping surface while leaving future modern
/// rendering choices behind the backend.
open class NSBox: NSView {
    /// The box title.
    open var title: String {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setText(title, for: nativeHandle)
        }
    }

    /// Creates a box with a frame.
    public override init(frame frameRect: NSRect) {
        self.title = ""
        super.init(frame: frameRect)
    }

    /// Creates a titled box with a frame.
    public init(title: String, frame frameRect: NSRect) {
        self.title = title
        super.init(frame: frameRect)
    }

    /// Creates the native Windows group box peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createBox(title: title, frame: frame, parent: parent)
    }
}
