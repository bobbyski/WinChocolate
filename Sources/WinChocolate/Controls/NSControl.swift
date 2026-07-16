/// Base class for controls that send actions.
///
/// `target`/`action` dispatch is real, as in AppKit: `sendAction()` routes the
/// selector through `NSApplication.sendAction(_:to:from:)`, reaching the
/// target's `perform(_:with:)` or walking the responder chain for a nil
/// target (see `NSObject`'s selector-dispatch note).
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

    /// AppKit hangs image placement off `NSControl`; WinChocolate declares
    /// it on `NSButton`, so mirror the AppKit spelling here.
    public typealias ImagePosition = NSButton.ImagePosition

    /// Object intended to receive the action.
    open weak var target: AnyObject?

    /// Selector name intended to be sent to the target.
    open var action: Selector?

    /// Framework-internal action hook used by composed chrome (alert panels,
    /// color/font panels, toolbar internals) whose handlers are closures over
    /// private state. Not API: application code uses real target/action —
    /// the public closure convenience was removed in 18.2.
    var winInternalAction: ((NSControl) -> Void)?

    /// Generic object value used by controls that expose value-like state.
    open var objectValue: Any?

    /// A formatter that converts between `objectValue` and the displayed text.
    ///
    /// Controls that support formatting (currently `NSTextField`) render
    /// `objectValue` through this for display and parse edited text back into
    /// `objectValue` when editing ends.
    open var formatter: Formatter?

    /// Whether the control should continuously send actions while tracking.
    open var isContinuous: Bool = false

    /// Whether the control draws itself in a highlighted state.
    open var isHighlighted: Bool = false

    /// Resizes the control to fit its content, using `sizeThatFits`.
    open func sizeToFit() {
        setFrameSize(sizeThatFits(frame.size))
    }

    /// Returns the size the control would prefer. The base implementation uses
    /// the control's `intrinsicContentSize` on each axis where it has one
    /// (falling back to the current frame extent on an axis reporting
    /// `noIntrinsicMetric`), so any control that reports an intrinsic size is
    /// measured correctly without overriding this.
    open func sizeThatFits(_ size: NSSize) -> NSSize {
        let intrinsic = intrinsicContentSize
        let width = intrinsic.width == NSView.noIntrinsicMetric ? frame.size.width : intrinsic.width
        let height = intrinsic.height == NSView.noIntrinsicMetric ? frame.size.height : intrinsic.height
        return NSSize(width: width, height: height)
    }

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

    // Controls are accessibility elements (leaves assistive technology lands
    // on), and their enabled state tracks `isEnabled`. Concrete controls refine
    // the role/value below.
    open override var winIsIntrinsicAccessibilityElement: Bool { true }
    open override var winIntrinsicAccessibilityEnabled: Bool { isEnabled }

    /// Sends an action to a target through the application, matching AppKit's
    /// `NSControl.sendAction(_:to:)`. A `nil` action returns `false`; a `nil`
    /// target walks the responder chain (see `NSApplication.sendAction`).
    @discardableResult
    open func sendAction(_ theAction: Selector?, to theTarget: Any?) -> Bool {
        guard let theAction else {
            return false
        }

        return NSApplication.shared.sendAction(theAction, to: theTarget, from: self)
    }

    /// Sends this control's action (the backend event bridge's entry point).
    open func sendAction() {
        guard isEnabled else {
            return
        }

        let delivered = sendAction(action, to: target)
        if WinDiagnostics.isEnabled {
            WinDiagnostics.log("control.sendAction \(type(of: self)) action=\(action != nil) delivered=\(delivered)")
        }
        winInternalAction?(self)
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

    /// The control's font, when explicitly set (AppKit declares this on
    /// `NSControl`, so buttons, popups, and fields all take it). `nil` keeps
    /// the standard control font.
    open var font: NSFont? {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setFont(font, for: nativeHandle)
        }
    }

    /// Ensures the control has a native peer and registers its action bridge.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        backend.setEnabled(isEnabled, for: handle)
        if font != nil {
            backend.setFont(font, for: handle)
        }
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
