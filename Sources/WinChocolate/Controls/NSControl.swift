/// Base class for controls that send actions.
///
/// WinChocolate preserves AppKit's `target` and `action` shape while also
/// exposing a Swift closure for Windows-native dispatch that does not depend on
/// Objective-C selector invocation.
open class NSControl: NSView {
    /// A control state value.
    public enum StateValue: Int, Sendable {
        /// Control is off.
        case off = 0

        /// Control is on.
        case on = 1

        /// Control is in a mixed state.
        case mixed = -1
    }

    /// Object intended to receive the action.
    open weak var target: AnyObject?

    /// Selector name intended to be sent to the target.
    open var action: Selector?

    /// Swift-native action invoked by `sendAction()`.
    open var onAction: ((NSControl) -> Void)?

    /// Generic object value used by controls that expose value-like state.
    open var objectValue: Any?

    /// Whether the control should continuously send actions while tracking.
    open var isContinuous: Bool = false

    /// Whether the control accepts user interaction.
    open var isEnabled: Bool = true {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setEnabled(isEnabled, for: nativeHandle)
        }
    }

    /// Enabled controls can participate in keyboard focus.
    open override var acceptsFirstResponder: Bool {
        isEnabled
    }

    /// Sends this control's action.
    open func sendAction() {
        guard isEnabled else {
            return
        }

        onAction?(self)
    }

    /// Controls participate in the standard key-view loop for Tab traversal.
    open override func keyDown(with event: NSEvent) {
        guard event.keyCode == 0x09 else {
            super.keyDown(with: event)
            return
        }

        if event.modifierFlags.contains(.shift) {
            window?.selectPreviousKeyView(nil)
        } else {
            window?.selectNextKeyView(nil)
        }
    }

    /// Ensures the control has a native peer and registers its action bridge.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        backend.setEnabled(isEnabled, for: handle)
        backend.registerAction(for: handle) { [weak self] in
            guard let self else {
                return
            }

            _ = self.window?.makeFirstResponder(self)
            self.sendAction()
        }
        return handle
    }
}
