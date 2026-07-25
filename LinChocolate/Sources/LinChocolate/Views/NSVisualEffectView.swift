import Foundation

/// AppKit-shaped material backdrop. On macOS this blurs what's behind it; over
/// GTK (and especially non-composited XQuartz, where there is no real blur) it
/// renders as a theme-aware tinted background whose shade tracks the current
/// appearance — so a sidebar reads as a sidebar in both light and dark mode.
///
/// It's a normal `NSView`, so it hosts subviews and custom drawing as usual;
/// only its background differs.
public final class NSVisualEffectView: NSView {

    /// The material (semantic surface) this backdrop represents. Each maps to a
    /// theme-derived background shade in the GTK backend.
    public enum Material: String, Sendable {
        /// A titlebar background.
        case titlebar
        /// A menu background.
        case menu
        /// A popover background.
        case popover
        /// A sidebar background.
        case sidebar
        /// A header-view background.
        case headerView
        /// A modal sheet background.
        case sheet
        /// A window background.
        case windowBackground
        /// A HUD-window background.
        case hudWindow
        /// A generic content background.
        case contentBackground
        /// The area behind a window.
        case underWindowBackground
        /// A selection highlight.
        case selection
        /// A combined titlebar + toolbar background.
        case titlebarAndBar
        /// A full-screen chrome background.
        case fullScreenUI
    }

    /// Blending mode + active state (accepted for API parity).
    public enum BlendingMode: Sendable {
        /// Blend with content behind the window.
        case behindWindow
        /// Blend with sibling views within the window.
        case withinWindow
    }
    /// The activation state of the effect.
    public enum State: Sendable {
        /// Track the window's active state.
        case followsWindowActiveState
        /// Always active.
        case active
        /// Always inactive.
        case inactive
    }
    /// The blending mode (accepted for API parity).
    public var blendingMode: BlendingMode = .behindWindow
    /// The activation state (accepted for API parity).
    public var state: State = .followsWindowActiveState

    /// The material shown. Changing it restyles the backdrop.
    public var material: Material {
        didSet { backend.setMaterial(material.rawValue, for: handle) }
    }

    /// Creates a visual effect view with the default (content background) material.
    public required convenience init(frame: NSRect) {
        self.init(frame: frame, material: .contentBackground)
    }

    /// Creates a visual effect view with the given material.
    public init(frame: NSRect, material: Material = .contentBackground) {
        self.material = material
        super.init(frame: frame)
        backend.setMaterial(material.rawValue, for: handle)
    }
}
