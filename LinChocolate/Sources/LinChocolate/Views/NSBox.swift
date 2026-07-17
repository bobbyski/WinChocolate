import Foundation

/// AppKit-shaped titled group box (GtkFrame). Install content with
/// `contentView`; the title is drawn by the native frame.
public final class NSBox: NSView {

    /// The box's title.
    private var backingTitle: String

    /// The box's title. Computed over backing storage for the same reason as
    /// `NSButton.title` — initializer assignments must reach the native side.
    public var title: String {
        get { backingTitle }
        set {
            backingTitle = newValue
            backend.setText(newValue, for: handle)
        }
    }

    /// The view framed by the box.
    public var contentView: NSView? {
        didSet {
            guard let contentView else { return }
            backend.setContentView(contentView.handle, for: handle)
        }
    }

    /// Creates a titled box.
    public required convenience init(frame: NSRect) {
        self.init(title: "", frame: frame)
    }

    public init(title: String, frame: NSRect) {
        self.backingTitle = title
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createBox(title: title, frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
    }
}
