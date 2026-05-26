/// Base class for controls that send actions.
///
/// WinChocolate preserves AppKit's `target` and `action` shape while also
/// exposing a Swift closure for Windows-native dispatch that does not depend on
/// Objective-C selector invocation.
open class NSControl: NSView {
    /// Object intended to receive the action.
    open weak var target: AnyObject?

    /// Selector name intended to be sent to the target.
    open var action: Selector?

    /// Swift-native action invoked by `sendAction()`.
    open var onAction: ((NSControl) -> Void)?

    /// Whether the control accepts user interaction.
    open var isEnabled: Bool = true {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setEnabled(isEnabled, for: nativeHandle)
        }
    }

    /// Sends this control's action.
    open func sendAction() {
        guard isEnabled else {
            return
        }

        onAction?(self)
    }

    /// Ensures the control has a native peer and registers its action bridge.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        backend.setEnabled(isEnabled, for: handle)
        backend.registerAction(for: handle) { [weak self] in
            self?.sendAction()
        }
        return handle
    }
}
