/// The methods a popover delegate can implement to observe its lifecycle.
public protocol NSPopoverDelegate: NSObjectProtocol {
    /// Tells the delegate the popover is about to show.
    func popoverWillShow(_ notification: NSNotification)

    /// Tells the delegate the popover has shown.
    func popoverDidShow(_ notification: NSNotification)

    /// Tells the delegate the popover is about to close.
    func popoverWillClose(_ notification: NSNotification)

    /// Tells the delegate the popover has closed.
    func popoverDidClose(_ notification: NSNotification)
}

extension NSPopoverDelegate {
    /// Default no-op so delegates only implement the callbacks they need.
    public func popoverWillShow(_ notification: NSNotification) {}

    /// Default no-op so delegates only implement the callbacks they need.
    public func popoverDidShow(_ notification: NSNotification) {}

    /// Default no-op so delegates only implement the callbacks they need.
    public func popoverWillClose(_ notification: NSNotification) {}

    /// Default no-op so delegates only implement the callbacks they need.
    public func popoverDidClose(_ notification: NSNotification) {}
}

/// A transient popover window.
///
/// This compatibility slice preserves AppKit's `NSPopover` API shape and hosts
/// the popover content in a menu-less `NSPanel`. Transient and semitransient
/// popovers dismiss when the user clicks outside them. The classic backend
/// does not yet draw an arrow, but lifecycle, positioning, dismissal, and a
/// solid background are AppKit-shaped enough for real ports.
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

    /// The edge actually used after off-screen flipping.
    public private(set) var winResolvedEdge: NSRectEdge?

    /// The popover delegate, notified about show/close lifecycle.
    open weak var delegate: NSPopoverDelegate?

    private var panel: NSPanel?

    /// Creates an empty popover.
    public override init() {
        super.init()
    }

    /// Shows the popover relative to a positioning rectangle in a view.
    open func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {
        delegate?.popoverWillShow(notification())

        let panel = existingOrNewPanel()
        let content = contentViewController?.view
        // A solid background keeps the borderless popover from showing stale
        // pixels through its content, a minimal stand-in for popover chrome.
        if let content, content.winBackgroundColor == nil {
            content.winBackgroundColor = .windowBackgroundColor
        }
        panel.contentView = content
        let handle = panel.realizeNativePeer()
        // Flip to the opposite edge if the preferred placement would run off the
        // screen, so the popover stays fully visible.
        let edge = resolvedEdge(
            preferred: preferredEdge,
            positioningRect: positioningRect,
            of: positioningView,
            screenFrame: panel.nativeBackend.primaryScreenFrame()
        )
        winResolvedEdge = edge
        panel.setFrame(frame(relativeTo: positioningRect, of: positioningView, preferredEdge: edge), display: true)
        if animates {
            panel.nativeBackend.fadeWindow(handle, visible: true)
        } else {
            panel.orderFrontRegardless()
        }
        isShown = true

        // Transient popovers dismiss on a click outside their bounds.
        if behavior != .applicationDefined, let handle = panel.nativeHandle {
            panel.nativeBackend.beginOutsideClickDismiss(for: handle) { [weak self] in
                self?.performClose(nil)
            }
        }

        delegate?.popoverDidShow(notification())
    }

    /// Performs the standard close action.
    open func performClose(_ sender: Any?) {
        close()
    }

    /// Closes the popover.
    open func close() {
        guard isShown else {
            return
        }

        delegate?.popoverWillClose(notification())
        panel?.nativeBackend.endOutsideClickDismiss()
        if animates, let panel, let handle = panel.nativeHandle {
            // Fade out before the window is destroyed.
            panel.nativeBackend.fadeWindow(handle, visible: false)
        }
        panel?.close()
        isShown = false
        delegate?.popoverDidClose(notification())
    }

    private func notification() -> NSNotification {
        NSNotification(name: "NSPopoverNotification", object: self)
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

    /// Returns the edge to place the popover on, flipping to the opposite edge
    /// when the preferred placement would extend past the screen.
    private func resolvedEdge(preferred: NSRectEdge, positioningRect: NSRect, of positioningView: NSView, screenFrame: NSRect) -> NSRectEdge {
        let rect = frame(relativeTo: positioningRect, of: positioningView, preferredEdge: preferred)
        let opposite: NSRectEdge
        let clipped: Bool
        switch preferred {
        case .maxY:
            opposite = .minY
            clipped = rect.origin.y + rect.size.height > screenFrame.origin.y + screenFrame.size.height
        case .minY:
            opposite = .maxY
            clipped = rect.origin.y < screenFrame.origin.y
        case .maxX:
            opposite = .minX
            clipped = rect.origin.x + rect.size.width > screenFrame.origin.x + screenFrame.size.width
        case .minX:
            opposite = .maxX
            clipped = rect.origin.x < screenFrame.origin.x
        }
        return clipped ? opposite : preferred
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
