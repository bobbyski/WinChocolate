import Foundation

/// Minimal AppKit-shaped view controller — just enough to host a view (e.g. as
/// an `NSPopover`'s content). The full controller lifecycle is a later item.
open class NSViewController {
    public var view: NSView

    public init(view: NSView) {
        self.view = view
    }
}
