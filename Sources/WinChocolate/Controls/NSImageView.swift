/// A simple image value.
///
/// This is an initial placeholder for AppKit's `NSImage`. It records a name so
/// API ports can preserve image-view wiring before bitmap decoding is added.
open class NSImage: NSObject {
    /// The type used to name images, matching AppKit's `NSImage.Name`.
    public typealias Name = String

    /// Image name or identifier.
    open var name: String?

    /// Filesystem path for file-backed images.
    open var filePath: String?

    /// Raw image data when the image was loaded from data or a file URL.
    open var data: Data?

    /// Accessibility description associated with a named system image.
    open var accessibilityDescription: String?

    /// The image's logical size, in points.
    open var size: NSSize = .zero

    /// Whether the image is a template (tinted to match the context).
    open var isTemplate: Bool = false

    /// Creates an image with an optional name.
    public init(named name: String? = nil) {
        self.name = name
        self.filePath = nil
        self.data = nil
        self.accessibilityDescription = nil
        super.init()
    }

    /// Creates an empty image with the given size.
    public init(size: NSSize) {
        self.name = nil
        self.filePath = nil
        self.data = nil
        self.accessibilityDescription = nil
        self.size = size
        super.init()
    }

    /// Sets the image's name, returning whether it was accepted.
    @discardableResult
    open func setName(_ string: NSImage.Name?) -> Bool {
        self.name = string
        return true
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

    /// Draws the image scaled into a rectangle of the current graphics context.
    ///
    /// First slice: only file-backed images draw; named and data-backed images
    /// are a no-op until in-memory bitmap decoding lands.
    open func draw(in rect: NSRect) {
        guard let filePath, let context = NSGraphicsContext.current else {
            return
        }

        context.nativeContext.drawImage(atPath: filePath, in: rect)
    }

    /// Draws the image into a rectangle, ignoring the source crop, compositing
    /// operation, and fraction (a first source-compatible slice that delegates
    /// to `draw(in:)`).
    open func draw(in rect: NSRect, from fromRect: NSRect, operation: NSCompositingOperation, fraction: CGFloat) {
        draw(in: rect)
    }

    /// Draws the image at a point, sizing the destination from the source
    /// rectangle (or the image size when the source is empty).
    open func draw(at point: NSPoint, from fromRect: NSRect, operation: NSCompositingOperation, fraction: CGFloat) {
        let destSize = fromRect.size == .zero ? size : fromRect.size
        draw(in: NSRect(origin: point, size: destSize))
    }
}

/// Compositing operations used when drawing images, matching AppKit's
/// `NSCompositingOperation`. WinChocolate's first drawing slice honors only
/// `sourceOver`; the cases exist so call sites compile.
public enum NSCompositingOperation: Int, Sendable {
    case clear = 0
    case copy = 1
    case sourceOver = 2
    case sourceIn = 3
    case sourceOut = 4
    case sourceAtop = 5
    case destinationOver = 6
    case destinationIn = 7
    case destinationOut = 8
    case destinationAtop = 9
    case xor = 10
    case plusDarker = 11
    case plusLighter = 12
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
