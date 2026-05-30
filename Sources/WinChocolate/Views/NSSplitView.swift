/// A container that divides its bounds between child views.
///
/// This first slice keeps the AppKit name and basic divider model while using
/// normal child `NSView` peers. Drag tracking and delegate callbacks are future
/// work, but applications can already compose split layouts and set divider
/// positions in Mac-shaped code.
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

    /// Sets the leading edge of the pane after the given divider.
    open func setPosition(_ position: CGFloat, ofDividerAt dividerIndex: Int) {
        guard dividerIndex >= 0,
              dividerIndex + 1 < subviews.count else {
            return
        }

        let first = subviews[dividerIndex]
        let second = subviews[dividerIndex + 1]
        let thickness = dividerThickness

        if isVertical {
            let clampedPosition = max(0, min(position, bounds.size.width - thickness))
            let secondMaxX = second.frame.origin.x + second.frame.size.width
            first.frame = NSMakeRect(first.frame.origin.x, 0, clampedPosition - first.frame.origin.x, bounds.size.height)
            second.frame = NSMakeRect(clampedPosition + thickness, 0, max(0, secondMaxX - clampedPosition - thickness), bounds.size.height)
        } else {
            let clampedPosition = max(0, min(position, bounds.size.height - thickness))
            let secondMaxY = second.frame.origin.y + second.frame.size.height
            first.frame = NSMakeRect(0, first.frame.origin.y, bounds.size.width, clampedPosition - first.frame.origin.y)
            second.frame = NSMakeRect(0, clampedPosition + thickness, bounds.size.width, max(0, secondMaxY - clampedPosition - thickness))
        }
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
    }
}
