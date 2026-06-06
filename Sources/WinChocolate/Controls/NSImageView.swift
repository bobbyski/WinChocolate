/// A simple image value.
///
/// This is an initial placeholder for AppKit's `NSImage`. It records a name so
/// API ports can preserve image-view wiring before bitmap decoding is added.
open class NSImage: NSObject {
    /// Image name or identifier.
    open var name: String?

    /// Filesystem path for file-backed images.
    open var filePath: String?

    /// Raw image data when the image was loaded from data or a file URL.
    open var data: Data?

    /// Accessibility description associated with a named system image.
    open var accessibilityDescription: String?

    /// Creates an image with an optional name.
    public init(named name: String? = nil) {
        self.name = name
        self.filePath = nil
        self.data = nil
        self.accessibilityDescription = nil
        super.init()
    }

    /// Creates an image from a system symbol name.
    ///
    /// WinChocolate records the symbol name for API compatibility. Apple SF
    /// Symbols are not bundled on Windows; native backends may map known names
    /// to local glyphs or platform stock images.
    public init?(systemSymbolName: String, accessibilityDescription: String?) {
        guard !systemSymbolName.isEmpty else {
            return nil
        }

        self.name = systemSymbolName
        self.filePath = nil
        self.data = nil
        self.accessibilityDescription = accessibilityDescription
        super.init()
    }

    /// Creates an image from a filesystem path.
    public init?(contentsOfFile filePath: String) {
        self.name = filePath
        self.filePath = filePath
        self.data = nil
        self.accessibilityDescription = nil
        super.init()
    }

    /// Creates an image from a file URL.
    public init?(contentsOf url: URL) {
        guard url.isFileURL else {
            return nil
        }
        self.name = url.lastPathComponent
        self.filePath = url.path
        self.data = try? Data(contentsOf: url)
        self.accessibilityDescription = nil
        super.init()
    }

    /// Creates an image from raw data.
    public init?(data: Data) {
        guard !data.isEmpty else {
            return nil
        }
        self.name = nil
        self.filePath = nil
        self.data = data
        self.accessibilityDescription = nil
        super.init()
    }
}

/// A view that displays an image.
///
/// The first backend slice records the image name and uses a native static peer
/// as a placeholder. Real bitmap loading and drawing are future work.
open class NSImageView: NSControl {
    /// How the image is scaled inside the image view.
    public enum ImageScaling: Sendable {
        /// Scale down proportionally when the image is larger than the view.
        case scaleProportionallyDown

        /// Scale independently along each axis.
        case scaleAxesIndependently

        /// Do not scale the image.
        case scaleNone

        /// Scale up or down proportionally to fit.
        case scaleProportionallyUpOrDown
    }

    /// How the image is aligned inside the image view.
    public enum ImageAlignment: Sendable {
        /// Center the image.
        case alignCenter

        /// Align to the top edge.
        case alignTop

        /// Align to the top-left corner.
        case alignTopLeft

        /// Align to the top-right corner.
        case alignTopRight

        /// Align to the left edge.
        case alignLeft

        /// Align to the bottom edge.
        case alignBottom

        /// Align to the bottom-left corner.
        case alignBottomLeft

        /// Align to the bottom-right corner.
        case alignBottomRight

        /// Align to the right edge.
        case alignRight
    }

    /// The frame style drawn around the image view.
    public enum ImageFrameStyle: Sendable {
        /// Draw no special frame.
        case none

        /// Draw a photo-style frame.
        case photo

        /// Draw a gray bezel frame.
        case grayBezel

        /// Draw a groove frame.
        case groove

        /// Draw a button-style frame.
        case button
    }

    /// The displayed image.
    open var image: NSImage? {
        didSet {
            updateNativeDescription()
        }
    }

    /// The scaling mode used for the displayed image.
    open var imageScaling: ImageScaling = .scaleProportionallyDown {
        didSet {
            updateNativeDescription()
        }
    }

    /// The alignment mode used for the displayed image.
    open var imageAlignment: ImageAlignment = .alignCenter {
        didSet {
            updateNativeDescription()
        }
    }

    /// The image view's frame style.
    open var imageFrameStyle: ImageFrameStyle = .none {
        didSet {
            updateNativeDescription()
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
        backend.createImageView(description: imageDescription, imagePath: image?.filePath, frame: frame, parent: parent)
    }

    private var imageDescription: String {
        "\(image?.name ?? "NSImage")\n\(scalingDescription), \(alignmentDescription)"
    }

    private var scalingDescription: String {
        switch imageScaling {
        case .scaleProportionallyDown:
            return "scale down"
        case .scaleAxesIndependently:
            return "scale axes"
        case .scaleNone:
            return "no scale"
        case .scaleProportionallyUpOrDown:
            return "scale fit"
        }
    }

    private var alignmentDescription: String {
        switch imageAlignment {
        case .alignCenter:
            return "center"
        case .alignTop:
            return "top"
        case .alignTopLeft:
            return "top left"
        case .alignTopRight:
            return "top right"
        case .alignLeft:
            return "left"
        case .alignBottom:
            return "bottom"
        case .alignBottomLeft:
            return "bottom left"
        case .alignBottomRight:
            return "bottom right"
        case .alignRight:
            return "right"
        }
    }

    private func updateNativeDescription() {
        guard let nativeHandle else {
            return
        }

        realizedBackend?.setImagePath(image?.filePath, description: imageDescription, for: nativeHandle)
    }
}
