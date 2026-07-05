/// The methods a split view delegate uses to respond to pane resizing.
public protocol NSSplitViewDelegate: AnyObject {
    /// Tells the delegate that pane frames changed.
    func splitViewDidResizeSubviews(_ notification: NSNotification)
}

extension NSSplitViewDelegate {
    /// Default no-op so delegates only implement the callbacks they need.
    public func splitViewDidResizeSubviews(_ notification: NSNotification) {}
}

/// A container that divides its bounds between child views.
///
/// Panes are normal child `NSView` peers separated by divider gaps owned by
/// the split view itself. Dividers track mouse drags, show the resize
/// cursor, and draw a classic center line; the delegate hears about resizes.
open class NSSplitView: NSView {
    /// Visual style for dividers between split panes.
    public enum DividerStyle: Sendable {
        /// A thicker classic divider.
        case thick

        /// A thinner divider.
        case thin

        /// A pane splitter style.
        case paneSplitter
    }

    /// Whether panes are arranged side by side.
    open var isVertical: Bool = true {
        didSet {
            adjustSubviews()
        }
    }

    /// The divider's visual style.
    open var dividerStyle: DividerStyle = .thick {
        didSet {
            adjustSubviews()
        }
    }

    /// Posted to the delegate when pane frames change.
    public static let didResizeSubviewsNotification = "NSSplitViewDidResizeSubviewsNotification"

    /// The split view delegate, notified when panes resize.
    open weak var delegate: NSSplitViewDelegate?

    /// The divider currently tracking a mouse drag.
    private var draggingDividerIndex: Int?

    /// Split views are containers and do not accept keyboard focus by default.
    open override var acceptsFirstResponder: Bool {
        false
    }

    /// The current divider thickness.
    open var dividerThickness: CGFloat {
        switch dividerStyle {
        case .thick:
            return 8
        case .thin:
            return 4
        case .paneSplitter:
            return 6
        }
    }

    /// Adds a child pane and recalculates pane frames.
    open override func addSubview(_ view: NSView) {
        super.addSubview(view)
        adjustSubviews()
    }

    /// Adds a child pane and recalculates pane frames.
    open override func addSubview(_ view: NSView, positioned place: NSWindow.OrderingMode, relativeTo otherView: NSView?) {
        super.addSubview(view, positioned: place, relativeTo: otherView)
        adjustSubviews()
    }

    /// Replaces a child pane and recalculates pane frames.
    open override func replaceSubview(_ oldView: NSView, with newView: NSView) {
        super.replaceSubview(oldView, with: newView)
        adjustSubviews()
    }

    /// Sets the leading edge of the divider, resizing its two panes.
    ///
    /// The position clamps between the neighboring panes so neither pane
    /// goes negative. The delegate hears about the resize.
    open func setPosition(_ position: CGFloat, ofDividerAt dividerIndex: Int) {
        guard dividerIndex >= 0,
              dividerIndex + 1 < subviews.count else {
            return
        }

        let first = subviews[dividerIndex]
        let second = subviews[dividerIndex + 1]
        let thickness = dividerThickness

        if isVertical {
            let secondMaxX = second.frame.origin.x + second.frame.size.width
            let clampedPosition = max(first.frame.origin.x, min(position, secondMaxX - thickness))
            first.frame = NSMakeRect(first.frame.origin.x, 0, clampedPosition - first.frame.origin.x, bounds.size.height)
            second.frame = NSMakeRect(clampedPosition + thickness, 0, max(0, secondMaxX - clampedPosition - thickness), bounds.size.height)
        } else {
            let secondMaxY = second.frame.origin.y + second.frame.size.height
            let clampedPosition = max(first.frame.origin.y, min(position, secondMaxY - thickness))
            first.frame = NSMakeRect(0, first.frame.origin.y, bounds.size.width, clampedPosition - first.frame.origin.y)
            second.frame = NSMakeRect(0, clampedPosition + thickness, bounds.size.width, max(0, secondMaxY - clampedPosition - thickness))
        }

        needsDisplay = true
        updateCursorRegions()
        delegate?.splitViewDidResizeSubviews(NSNotification(name: Self.didResizeSubviewsNotification, object: self))
    }

    /// Recalculates child pane frames to evenly fill the split view.
    open func adjustSubviews() {
        guard !subviews.isEmpty else {
            return
        }

        let count = CGFloat(subviews.count)
        let totalDividerThickness = dividerThickness * max(0, count - 1)

        if isVertical {
            let paneWidth = max(0, (bounds.size.width - totalDividerThickness) / count)
            var x: CGFloat = 0
            for subview in subviews {
                subview.frame = NSMakeRect(x, 0, paneWidth, bounds.size.height)
                x += paneWidth + dividerThickness
            }
        } else {
            let paneHeight = max(0, (bounds.size.height - totalDividerThickness) / count)
            var y: CGFloat = 0
            for subview in subviews {
                subview.frame = NSMakeRect(0, y, bounds.size.width, paneHeight)
                y += paneHeight + dividerThickness
            }
        }

        needsDisplay = true
        updateCursorRegions()
    }

    // MARK: - Divider geometry

    /// The rectangle of the divider following a pane index.
    private func dividerRect(at index: Int) -> NSRect? {
        guard index >= 0, index + 1 < subviews.count else {
            return nil
        }

        let first = subviews[index]
        let second = subviews[index + 1]
        if isVertical {
            let leading = first.frame.origin.x + first.frame.size.width
            return NSMakeRect(leading, 0, second.frame.origin.x - leading, bounds.size.height)
        }
        let leading = first.frame.origin.y + first.frame.size.height
        return NSMakeRect(0, leading, bounds.size.width, second.frame.origin.y - leading)
    }

    /// The index of the divider containing a point, if any.
    private func dividerIndex(at point: NSPoint) -> Int? {
        for index in 0..<max(0, subviews.count - 1) {
            if let rect = dividerRect(at: index), NSPointInRect(point, rect) {
                return index
            }
        }
        return nil
    }

    // MARK: - Divider tracking

    /// Starts a divider drag when the press lands in a divider gap.
    open override func mouseDown(with event: NSEvent) {
        if let index = dividerIndex(at: convert(event.locationInWindow, from: nil)) {
            draggingDividerIndex = index
            return
        }
        super.mouseDown(with: event)
    }

    /// Moves the tracked divider with the drag.
    open override func mouseDragged(with event: NSEvent) {
        guard let index = draggingDividerIndex else {
            super.mouseDragged(with: event)
            return
        }

        let location = convert(event.locationInWindow, from: nil)
        let offset = dividerThickness / 2
        setPosition((isVertical ? location.x : location.y) - offset, ofDividerAt: index)
    }

    /// Ends the divider drag.
    open override func mouseUp(with event: NSEvent) {
        if draggingDividerIndex != nil {
            draggingDividerIndex = nil
            return
        }
        super.mouseUp(with: event)
    }

    /// Publishes divider gaps as resize-cursor rectangles.
    open override func resetCursorRects() {
        for index in 0..<max(0, subviews.count - 1) {
            if let rect = dividerRect(at: index) {
                addCursorRect(rect, cursor: isVertical ? .resizeLeftRight : .resizeUpDown)
            }
        }
    }

    // MARK: - Divider drawing

    /// Draws all dividers.
    open override func draw(_ dirtyRect: NSRect) {
        for index in 0..<max(0, subviews.count - 1) {
            if let rect = dividerRect(at: index), rect.size.width > 0, rect.size.height > 0 {
                drawDivider(in: rect)
            }
        }
    }

    /// Draws one divider: a classic center line inside the gap.
    open func drawDivider(in rect: NSRect) {
        NSColor(calibratedRed: 0.63, green: 0.63, blue: 0.63, alpha: 1).setFill()
        if isVertical {
            NSRectFill(NSMakeRect(rect.origin.x + rect.size.width / 2 - 0.5, rect.origin.y + 2, 1, max(0, rect.size.height - 4)))
        } else {
            NSRectFill(NSMakeRect(rect.origin.x + 2, rect.origin.y + rect.size.height / 2 - 0.5, max(0, rect.size.width - 4), 1))
        }
    }
}
