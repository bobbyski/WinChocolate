import Foundation

/// Converts between AppKit's and GTK's view coordinate spaces.
///
/// ```text
///   AppKit: origin bottom-left, +Y up      GTK: origin top-left, +Y down
///
///     ^ +Y                                    +------------------> +X
///     |   +--------+  childMaxY                |   (gtk y = 0 at top)
///     |   | child  |                           |   +--------+
///     |   +--------+  child.origin.y           |   | child  |  gtkY
///     +-----------------> +X                    v   +--------+
/// ```
///
/// A child's top-left Y in GTK is therefore `parentHeight - childMaxY`, where
/// `childMaxY = child.origin.y + child.height`. Kept as a pure, platform-neutral
/// function so the layout math is testable without a display (rules: "layout
/// should be declarative and testable") and reusable by any future backend.
public enum CoordinateSpace {

    /// The GTK (top-left) Y at which to place `childFrame` inside a parent of
    /// height `parentHeight`, flipping AppKit's bottom-left origin.
    public static func gtkY(for childFrame: NSRect, parentHeight: CGFloat) -> CGFloat {
        parentHeight - childFrame.origin.y - childFrame.size.height
    }

    /// The exact rect `childFrame` must occupy inside its parent, in the
    /// parent's GTK (top-left) space. **The single place a child's geometry is
    /// decided** — every backend placement goes through here.
    ///
    /// Size passes through untouched, and that is the point: in AppKit a view
    /// *is* its frame, so the frame is law, not a suggestion. GTK instead
    /// negotiates size (`gtk_widget_set_size_request` is documented as a
    /// *minimum* that "will not cause a widget to be smaller than its natural
    /// size"), which is why controls whose intrinsic minimum exceeds their
    /// AppKit frame used to overflow and collide with their neighbours. The
    /// backend hands this rect to a frame-authoritative layout manager that
    /// allocates exactly it.
    ///
    /// - Parameters:
    ///   - childFrame: the child's AppKit frame, in the parent's coordinates.
    ///   - parentHeight: the parent's height, for the bottom-left flip.
    ///   - parentIsFlipped: whether the parent already uses a top-left origin
    ///     (AppKit's `isFlipped`; Win32/WinChocolate and the shared demo do).
    public static func place(_ childFrame: NSRect,
                             inParentOfHeight parentHeight: CGFloat,
                             parentIsFlipped: Bool) -> NSRect {
        let y = parentIsFlipped
            ? childFrame.origin.y
            : gtkY(for: childFrame, parentHeight: parentHeight)
        return NSMakeRect(childFrame.origin.x, y, childFrame.size.width, childFrame.size.height)
    }

    /// The AppKit Y, in a container's **own** coordinate space, of a
    /// `contentHeight`-tall control in row `index` of rows stacked from the
    /// container's **top** edge.
    ///
    /// Row 0 is topmost under either convention, which is exactly why the flip
    /// cannot be assumed: a flipped container counts *down* from y=0, while an
    /// unflipped one counts *back* from its top edge — and `isFlipped` is
    /// per-view, so a container's answer is its own, not its parent's or the
    /// app-wide default's. Shared by the containers that lay out their own
    /// children (`NSForm`, `NSMatrix`) so the math exists once.
    ///
    /// - Parameters:
    ///   - index: the row, 0 = topmost.
    ///   - rowHeight: the row pitch.
    ///   - spacing: extra gap between rows.
    ///   - contentHeight: the height of the control being placed (it is
    ///     top-aligned in its row, which only matters when unflipped).
    ///   - containerHeight: the container's own height.
    ///   - isFlipped: **the container's own** `isFlipped`.
    public static func stackedRowY(index: Int,
                                   rowHeight: CGFloat,
                                   spacing: CGFloat = 0,
                                   contentHeight: CGFloat,
                                   containerHeight: CGFloat,
                                   isFlipped: Bool) -> CGFloat {
        let fromTop = CGFloat(index) * (rowHeight + spacing)
        return isFlipped ? fromTop : containerHeight - fromTop - contentHeight
    }
}
