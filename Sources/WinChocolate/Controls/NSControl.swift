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

    /// Sends this control's action.
    open func sendAction() {
        onAction?(self)
    }
}
