/// A transient popover window.
///
/// This first compatibility slice preserves AppKit's `NSPopover` API shape and
/// hosts the popover content in a menu-less `NSPanel`. The classic backend does
/// not yet draw an arrow or popover chrome, but lifecycle and positioning are
/// AppKit-shaped enough for early ports.
open class NSPopover: NSObject {
    /// Popover closing behavior.
    public enum Behavior: Sendable {
        /// The app closes the popover explicitly.
        case applicationDefined

        /// The popover closes transiently.
        case transient

        /// The popover closes semitransiently.
        case semitransient
    }

    /// Whether the popover should animate when shown or closed.
    open var animates: Bool = true

    /// The popover behavior.
    open var behavior: Behavior = .applicationDefined

    /// The popover content size.
    open var contentSize: NSSize = NSMakeSize(320, 180)

    /// The controller that owns the popover content view.
    open var contentViewController: NSViewController? {
        didSet {
            panel?.contentView = contentViewController?.view
        }
    }

    /// Whether the popover is currently shown.
    open private(set) var isShown: Bool = false

    private var panel: NSPanel?

    /// Creates an empty popover.
    public override init() {
        super.init()
    }

    /// Shows the popover relative to a positioning rectangle in a view.
    open func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {
        let panel = existingOrNewPanel()
        panel.contentView = contentViewController?.view
        panel.setFrame(frame(relativeTo: positioningRect, of: positioningView, preferredEdge: preferredEdge), display: true)
        panel.orderFrontRegardless()
        isShown = true
    }

    /// Performs the standard close action.
    open func performClose(_ sender: Any?) {
        close()
    }

    /// Closes the popover.
    open func close() {
        panel?.close()
        isShown = false
    }

    private func existingOrNewPanel() -> NSPanel {
        if let panel {
            return panel
        }

        let newPanel = NSPanel(
            contentRect: NSRect(origin: NSZeroPoint, size: contentSize),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        newPanel.title = ""
        newPanel.isFloatingPanel = true
        newPanel.hidesOnDeactivate = behavior != .applicationDefined
        panel = newPanel
        return newPanel
    }

    private func frame(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) -> NSRect {
        let windowPoint = positioningView.convert(positioningRect.origin, to: nil)
        let windowOrigin = positioningView.window?.frame.origin ?? NSZeroPoint
        let base = NSPoint(x: windowOrigin.x + windowPoint.x, y: windowOrigin.y + windowPoint.y)
        let gap: CGFloat = 8

        switch preferredEdge {
        case .minX:
            return NSMakeRect(base.x - contentSize.width - gap, base.y, contentSize.width, contentSize.height)
        case .minY:
            return NSMakeRect(base.x, base.y - contentSize.height - gap, contentSize.width, contentSize.height)
        case .maxX:
            return NSMakeRect(base.x + positioningRect.size.width + gap, base.y, contentSize.width, contentSize.height)
        case .maxY:
            return NSMakeRect(base.x, base.y + positioningRect.size.height + gap, contentSize.width, contentSize.height)
        }
    }
}
