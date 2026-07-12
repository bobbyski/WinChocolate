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
        case titlebar
        case menu
        case popover
        case sidebar
        case headerView
        case sheet
        case windowBackground
        case hudWindow
        case contentBackground
        case underWindowBackground
        case selection
        case titlebarAndBar
        case fullScreenUI
    }

    /// Blending mode + active state (accepted for API parity).
    public enum BlendingMode: Sendable { case behindWindow, withinWindow }
    public enum State: Sendable { case followsWindowActiveState, active, inactive }
    public var blendingMode: BlendingMode = .behindWindow
    public var state: State = .followsWindowActiveState

    /// The material shown. Changing it restyles the backdrop.
    public var material: Material {
        didSet { backend.setMaterial(material.rawValue, for: handle) }
    }

    public init(frame: NSRect, material: Material = .contentBackground) {
        self.material = material
        super.init(frame: frame)
        backend.setMaterial(material.rawValue, for: handle)
    }
}
