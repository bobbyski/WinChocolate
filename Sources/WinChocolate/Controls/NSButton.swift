/// A push button control.
///
/// `NSButton` maps to the native Windows button control when realized by a
/// backend. The public surface follows AppKit's common title, target, and action
/// workflow.
open class NSButton: NSControl {
    /// Button rendering and behavior type.
    public enum ButtonType: Sendable {
        /// Momentary push button.
        case momentaryPushIn

        /// Toggle checkbox button.
        case switchButton
    }

    /// The button title.
    open var title: String {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setText(title, for: nativeHandle)
        }
    }

    /// Button type.
    open private(set) var buttonType: ButtonType = .momentaryPushIn

    /// Button state for switch-like buttons.
    private var isUpdatingStateFromNative = false

    /// Button state for switch-like buttons.
    open var state: StateValue = .off {
        didSet {
            guard !isUpdatingStateFromNative else {
                return
            }

            guard let nativeHandle else {
                return
            }

            realizedBackend?.setButtonState(state, for: nativeHandle)
        }
    }

    /// Creates a button with a frame.
    public override init(frame frameRect: NSRect) {
        self.title = ""
        super.init(frame: frameRect)
    }

    /// Creates a titled button with a frame.
    public init(title: String, frame frameRect: NSRect) {
        self.title = title
        super.init(frame: frameRect)
    }

    /// Creates the native Windows button peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        switch buttonType {
        case .momentaryPushIn:
            return backend.createButton(title: title, frame: frame, parent: parent)
        case .switchButton:
            return backend.createCheckbox(title: title, frame: frame, parent: parent)
        }
    }

    /// Ensures the button has a native peer and syncs button state.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        backend.setButtonState(state, for: handle)
        backend.registerAction(for: handle) { [weak self, weak backend] in
            guard let self else {
                return
            }

            if self.buttonType == .switchButton, let backend, let nativeHandle = self.nativeHandle {
                self.updateStateFromNative(backend.buttonState(for: nativeHandle))
            }

            self.sendAction()
        }
        return handle
    }

    /// Programmatically performs the button action.
    open func performClick(_ sender: Any?) {
        if buttonType == .switchButton {
            state = state == .on ? .off : .on
        }

        sendAction()
    }

    /// Sets the button type.
    open func setButtonType(_ type: ButtonType) {
        buttonType = type
    }

    private func updateStateFromNative(_ state: StateValue) {
        isUpdatingStateFromNative = true
        self.state = state
        isUpdatingStateFromNative = false
    }
}
