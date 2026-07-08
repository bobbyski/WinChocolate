import Foundation

/// AppKit-shaped push button.
///
/// The public surface follows AppKit's title/action pattern. A native click is
/// routed through the backend's `registerAction(for:)` into `onAction`, so the
/// same app code works whether the backend is GTK or the in-memory test double.
public final class NSButton: NSView {

    /// The button's title.
    public var title: String {
        didSet { backend.setText(title, for: handle) }
    }

    /// Called when the button is clicked.
    public var onAction: ((NSButton) -> Void)?

    /// Creates a titled button.
    public init(title: String, frame: NSRect) {
        self.title = title
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createButton(title: title, frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
        backend.registerAction(for: handle) { [weak self] in
            guard let self else { return }
            self.onAction?(self)
        }
    }

    /// Programmatically performs the button's action.
    public func performClick(_ sender: Any?) {
        onAction?(self)
    }
}
