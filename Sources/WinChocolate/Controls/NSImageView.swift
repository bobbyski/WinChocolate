/// A simple image value.
///
/// This is an initial placeholder for AppKit's `NSImage`. It records a name so
/// API ports can preserve image-view wiring before bitmap decoding is added.
open class NSImage: NSObject {
    /// Image name or identifier.
    open var name: String?

    /// Creates an image with an optional name.
    public init(named name: String? = nil) {
        self.name = name
        super.init()
    }
}

/// A view that displays an image.
///
/// The first backend slice records the image name and uses a native static peer
/// as a placeholder. Real bitmap loading and drawing are future work.
open class NSImageView: NSControl {
    /// The displayed image.
    open var image: NSImage? {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setText(imageDescription, for: nativeHandle)
        }
    }

    /// Creates an image view with a frame.
    public override init(frame frameRect: NSRect) {
        self.image = nil
        super.init(frame: frameRect)
    }

    /// Creates an image view with an image.
    public init(image: NSImage) {
        self.image = image
        super.init(frame: NSMakeRect(0, 0, 64, 64))
    }

    /// Image views do not participate in keyboard focus by default.
    open override var acceptsFirstResponder: Bool {
        false
    }

    /// Creates the native placeholder image-view peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createImageView(description: imageDescription, frame: frame, parent: parent)
    }

    private var imageDescription: String {
        image?.name ?? "NSImage"
    }
}
