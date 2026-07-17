import Foundation

/// AppKit's control base class. Controls sit between `NSView` and their
/// concrete class exactly as on Apple, and dispatch user changes through the
/// REAL `target`/`action` pair: a native change calls `sendAction()`, which
/// performs `action` on `target` via LinChocolate's selector dispatch
/// (`NSObject.perform(_:with:)`) — the same shape the ObjC runtime gives the
/// demo on macOS, and WinFoundation gives it on Windows.
open class NSControl: NSView {

    /// The action message's receiver. Weak, as on Apple.
    open weak var target: AnyObject?

    /// The action sent to `target` when the control's value changes.
    open var action: Selector?

    /// Whether the control accepts input (AppKit keeps this on NSControl,
    /// not NSView).
    open var isEnabled: Bool = true {
        didSet { backend.setEnabled(isEnabled, for: handle) }
    }

    /// Whether the control sends its action continuously while the user is
    /// still interacting (sliders dragging, fields typing).
    open var isContinuous: Bool = false

    /// Sends `action` to `target`. Concrete controls call this from their
    /// native change callbacks; app code may also invoke it directly, as on
    /// Apple.
    @discardableResult
    open func sendAction() -> Bool {
        guard let action, let target = target as? NSObject else {
            return false
        }

        _ = target.perform(action, with: self)
        return true
    }
}
