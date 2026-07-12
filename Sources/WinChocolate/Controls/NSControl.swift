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

    /// AppKit hangs image placement off `NSControl`; WinChocolate declares
    /// it on `NSButton`, so mirror the AppKit spelling here.
    public typealias ImagePosition = NSButton.ImagePosition

    /// Object intended to receive the action.
    open weak var target: AnyObject?

    /// Selector name intended to be sent to the target.
    open var action: Selector?

    /// Swift-native action invoked by `sendAction()`.
    open var onAction: ((NSControl) -> Void)?

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

    /// Resizes the control to fit its content. The base control keeps its frame;
    /// subclasses with measurable content override this.
    open func sizeToFit() {}

    /// Returns the size the control would prefer for the given size. The base
    /// implementation returns the current frame size; subclasses refine it.
    open func sizeThatFits(_ size: NSSize) -> NSSize {
        frame.size
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
