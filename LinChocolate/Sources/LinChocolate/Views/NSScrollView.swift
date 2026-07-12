import Foundation

/// AppKit-shaped scroll container (GtkScrolledWindow). Set `documentView` to a
/// view larger than the scroll view's frame and the native container provides
/// the scrollbars and scrolling.
public final class NSScrollView: NSView {

    /// The scrolled content.
    public var documentView: NSView? {
        didSet {
            guard let documentView else { return }
            backend.setContentView(documentView.handle, for: handle)
        }
    }

    /// Creates an empty scroll view.
    public override init(frame: NSRect) {
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createScrollView(frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
    }
}
