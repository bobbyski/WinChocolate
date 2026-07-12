import Foundation

/// AppKit-shaped image view (GtkPicture). Set `image` to display a file-backed
/// `NSImage`; the native picture scales it to fit, preserving aspect ratio.
public final class NSImageView: NSView {

    /// The displayed image (nil clears the view).
    public var image: NSImage? {
        didSet { backend.setImagePath(image.flatMap { $0.path }, for: handle) }
    }

    /// Creates an empty image view.
    public override init(frame: NSRect) {
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createImageView(frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
    }
}
