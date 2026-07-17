import Foundation

/// AppKit-shaped two-pane split view (GtkPaned). Add panes with
/// `addArrangedSubview(_:)` (first = leading/top, second = trailing/bottom);
/// the user can drag the native divider, or set it with `setPosition`.
///
/// This slice supports one divider (two panes), which covers the common case;
/// AppKit's n-pane splits can nest.
public final class NSSplitView: NSView {

    /// AppKit semantics: `true` means a **vertical divider** (panes side by side).
    public let isVertical: Bool

    /// The panes, in the order added.
    public private(set) var arrangedSubviews: [NSView] = []

    /// Creates an empty split view.
    public required convenience init(frame: NSRect) {
        self.init(vertical: true, frame: frame)
    }

    public init(vertical: Bool = true, frame: NSRect) {
        self.isVertical = vertical
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createSplitView(vertical: vertical, frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
    }

    /// Adds the next pane. Panes beyond the second are ignored in this slice.
    public func addArrangedSubview(_ view: NSView) {
        arrangedSubviews.append(view)
        adoptSubview(view)
        backend.addSplitPane(view.handle, to: handle)
    }

    /// A split view's panes *are* its subviews, so `addSubview(_:)` adds a pane
    /// — AppKit's original API, and what the demo uses. Without this the panes
    /// took `NSView`'s generic path, which looks for a child area a GtkPaned
    /// doesn't have, and both panes silently never appeared.
    public override func addSubview(_ view: NSView) {
        addArrangedSubview(view)
    }

    /// Moves the divider to `position` (pixels from the leading edge).
    public func setPosition(_ position: Double, ofDividerAt dividerIndex: Int = 0) {
        backend.setDividerPosition(position, for: handle)
    }
}
