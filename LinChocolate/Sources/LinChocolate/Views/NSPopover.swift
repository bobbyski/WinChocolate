import Foundation

/// An edge of a rectangle (AppKit's `NSRectEdge`), used for popover placement.
public enum NSRectEdge: Int {
    /// The left edge (smallest x).
    case minX = 0
    /// The bottom edge (smallest y).
    case minY = 1
    /// The right edge (largest x).
    case maxX = 2
    /// The top edge (largest y).
    case maxY = 3
}

/// AppKit-shaped popover: a transient content surface anchored to a view.
/// Backed by `GtkPopover`. Its content is an `NSViewController`'s view; on a
/// non-composited display (XQuartz) it flattens (no arrow/shadow) like the
/// menu/dropdown popovers, and the outside-click dismissal fallback closes it.
public final class NSPopover {

    /// How the popover dismisses (transient closes on outside interaction).
    public enum Behavior {
        /// Dismissed only by application code.
        case applicationDefined
        /// Dismissed on any outside interaction.
        case transient
        /// Dismissed on outside interaction outside the popover's window.
        case semitransient
    }

    /// The dismissal behavior.
    public var behavior: Behavior = .applicationDefined
    /// The size of the popover's content area.
    public var contentSize: NSSize = NSMakeSize(200, 100)
    /// The controller whose view fills the popover.
    public var contentViewController: NSViewController?
    /// Whether the popover is currently visible.
    public private(set) var isShown = false

    private let backend = NSApplication.shared.nativeBackend
    private var handle: NativeHandle?

    /// Creates a popover with no content.
    public init() {}

    /// Shows the popover anchored to `positioningRect` (in `positioningView`'s
    /// bounds) on the `preferredEdge` side.
    public func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {
        guard let content = contentViewController?.view else { return }
        content.frame = NSMakeRect(0, 0, contentSize.width, contentSize.height)
        let popover = handle ?? backend.createPopover()
        handle = popover
        backend.setPopoverContent(content.handle, size: contentSize, for: popover)
        backend.showPopover(popover, relativeTo: positioningView.handle,
                            rect: positioningRect, edge: preferredEdge.rawValue)
        isShown = true
    }

    /// Closes the popover.
    public func performClose(_ sender: Any?) {
        if let popover = handle { backend.closePopover(popover) }
        isShown = false
    }
}
