import Foundation

/// Minimal AppKit-shaped view controller — just enough to host a view (e.g. as
/// an `NSPopover`'s content). The full controller lifecycle is a later item.
open class NSViewController {
    /// The controller's view.
    public var view: NSView

    /// Apple's parameterless initializer; assign `view` afterwards.
    public init() {
        self.view = NSView(frame: .zero)
    }

    /// Creates a controller wrapping an existing view.
    public init(view: NSView) {
        self.view = view
    }
}
