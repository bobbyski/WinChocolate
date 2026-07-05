/// Controller object that owns a view.
///
/// This first slice keeps AppKit's `NSViewController` name and common `view`
/// ownership shape so controls such as `NSPopover` can accept controller-backed
/// content.
open class NSViewController: NSResponder {
    /// The controller's root view.
    open var view: NSView

    /// Creates a view controller with an empty root view.
    public override convenience init() {
        self.init(view: NSView(frame: NSZeroRect))
    }

    /// Creates a view controller with an explicit root view.
    public init(view: NSView) {
        self.view = view
        super.init()
        self.view.nextResponder = self
    }
}
