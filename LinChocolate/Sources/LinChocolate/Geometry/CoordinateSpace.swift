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
}
