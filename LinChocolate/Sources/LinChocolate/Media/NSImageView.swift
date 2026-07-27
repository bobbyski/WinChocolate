import Foundation

/// AppKit-shaped image view (GtkPicture). Set `image` to display a file-backed
/// `NSImage`; the native picture scales it to fit, preserving aspect ratio.
open class NSImageView: NSControl {

    /// The displayed image (nil clears the view).
    public var image: NSImage? {
        didSet {
            backend.setImagePath(image.flatMap { $0.path }, for: handle)
            applyTint()
        }
    }

    /// How the image scales within the view (AppKit's `NSImageScaling`).
    public enum ImageScaling: Sendable {
        /// Scales the image down to fit, preserving aspect ratio; never enlarges.
        case scaleProportionallyDown
        /// Scales width and height independently to fill the view.
        case scaleAxesIndependently
        /// Does not scale the image.
        case scaleNone
        /// Scales the image up or down to fit, preserving aspect ratio.
        case scaleProportionallyUpOrDown
    }
    /// How the image aligns (AppKit's `NSImageAlignment`).
    public enum ImageAlignment: Sendable {
        /// Center the image in the view.
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

    /// Tint applied to a template image (AppKit's `contentTintColor`): the
    /// artwork is recolored to this while keeping its alpha mask.
    public var contentTintColor: NSColor? {
        didSet { applyTint() }
    }

    /// Pushes the current tint to the backend when the image is a template.
    private func applyTint() {
        backend.setImageTint(contentTintColor, isTemplate: image?.isTemplate ?? false, for: handle)
    }
    /// How the image scales within the view (accepted for API parity).
    public var imageScaling: NSImageScaling = .scaleProportionallyDown
    /// How the image aligns within the view (accepted for API parity).
    public var imageAlignment: NSImageAlignment = .alignCenter

    /// Creates an empty image view.
    public required init(frame: NSRect) {
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createImageView(frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
        // Clicks dispatch through AppKit's responder method, so subclasses that
        // override `mouseDown(with:)` (the demo's click-to-cycle image) work.
        backend.setClickAction(for: handle) { [weak self] x, y in
            guard let self else { return }
            let event = NSEvent()
            event.locationInWindow = NSMakePoint(x, y)
            self.mouseDown(with: event)
        }
    }
}
