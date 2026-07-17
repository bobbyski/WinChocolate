import Foundation

/// AppKit-shaped image view (GtkPicture). Set `image` to display a file-backed
/// `NSImage`; the native picture scales it to fit, preserving aspect ratio.
open class NSImageView: NSControl {

    /// The displayed image (nil clears the view).
    public var image: NSImage? {
        didSet { backend.setImagePath(image.flatMap { $0.path }, for: handle) }
    }

    /// How the image scales within the view (AppKit's `NSImageScaling`).
    public enum ImageScaling: Sendable {
        case scaleProportionallyDown, scaleAxesIndependently, scaleNone, scaleProportionallyUpOrDown
    }
    /// How the image aligns (AppKit's `NSImageAlignment`).
    public enum ImageAlignment: Sendable {
        case alignCenter, alignTop, alignTopLeft, alignTopRight, alignLeft, alignBottom
        case alignBottomLeft, alignBottomRight, alignRight
    }

    /// Tint + scaling + alignment (accepted for API parity).
    public var contentTintColor: NSColor?
    public var imageScaling: NSImageScaling = .scaleProportionallyDown
    public var imageAlignment: NSImageAlignment = .alignCenter

    /// Creates an empty image view.
    public required init(frame: NSRect) {
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createImageView(frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
    }
}
