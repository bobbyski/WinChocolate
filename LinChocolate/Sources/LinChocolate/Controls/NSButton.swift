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

    /// Called when the button is clicked (push button) or toggled (checkbox).
    public var onAction: ((NSButton) -> Void)?

    private var backingIsOn = false

    /// For checkbox buttons: whether it is checked. Setting it updates the
    /// control; the user's own toggles flow back in via the backend.
    public var isOn: Bool {
        get { backingIsOn }
        set {
            backingIsOn = newValue
            backend.setButtonState(newValue, for: handle)
        }
    }

    /// Creates a titled push button.
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

    /// Creates a checkbox (labelled on/off toggle) that fires `onAction` when toggled.
    public init(checkboxWithTitle title: String, frame: NSRect) {
        self.title = title
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createCheckbox(title: title, frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
        backend.setToggleAction(for: handle) { [weak self] on in
            guard let self else { return }
            self.backingIsOn = on            // sync silently
            self.onAction?(self)
        }
    }

    /// Programmatically performs the button's action.
    public func performClick(_ sender: Any?) {
        onAction?(self)
    }
}
