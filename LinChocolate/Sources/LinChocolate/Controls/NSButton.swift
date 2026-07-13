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

    // Look/behavior flags accepted for API parity (GTK buttons style natively).
    public var bezelStyle: NSButtonBezelStyle = .rounded
    public var isBordered: Bool = true
    public var imagePosition: Int = 0
    public var image: NSImage?
    public var keyEquivalent: String = ""

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

    /// Creates a radio button. Group several with `NSButton.group(_:)` so only
    /// one can be selected at a time.
    public init(radioWithTitle title: String, frame: NSRect) {
        self.title = title
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createRadioButton(title: title, frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
        backend.setToggleAction(for: handle) { [weak self] on in
            guard let self else { return }
            self.backingIsOn = on
            if on { self.onAction?(self) }   // radios fire their action on selection
        }
    }

    /// Converts a plain button into a checkbox or radio (AppKit's
    /// `setButtonType(_:)`). Recreates the native control and re-wires its
    /// toggle. Call before adding the button to a view; radios auto-group with
    /// siblings in the same superview.
    public func setButtonType(_ type: NSButtonType) {
        switch type {
        case .switch, .switchButton, .toggle, .onOff, .pushOnPushOff:
            backend.setButtonKind(.checkbox, title: title, for: handle)
            rewireToggle(radio: false)
        case .radio, .radioButton:
            backend.setButtonKind(.radio, title: title, for: handle)
            rewireToggle(radio: true)
        default:
            break   // momentary/push styles stay a plain button
        }
    }

    private func rewireToggle(radio: Bool) {
        backend.setToggleAction(for: handle) { [weak self] on in
            guard let self else { return }
            self.backingIsOn = on
            if !radio || on { self.onAction?(self) }
        }
    }

    /// Groups radio buttons for mutual exclusion. They should share a superview.
    public static func group(_ radios: [NSButton]) {
        guard let backend = radios.first?.backend else { return }
        backend.groupRadioButtons(radios.map(\.handle))
    }

    /// Programmatically performs the button's action.
    public func performClick(_ sender: Any?) {
        onAction?(self)
    }
}
