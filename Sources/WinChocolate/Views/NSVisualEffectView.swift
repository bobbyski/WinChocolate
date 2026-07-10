/// A view that requests AppKit-style backdrop material.
///
/// The classic Win32 backend does not render true vibrancy/acrylic yet. This
/// first slice stores the AppKit-shaped material state and maps it to a quiet
/// fallback background color so ports can preserve their view hierarchy.
open class NSVisualEffectView: NSView {
    /// How the visual effect blends with surrounding content.
    public enum BlendingMode: Sendable {
        /// Blend behind the window.
        case behindWindow

        /// Blend within the view hierarchy.
        case withinWindow
    }

    /// The requested material.
    public enum Material: Sendable {
        /// Appearance-selected material.
        case appearanceBased

        /// Light material.
        case light

        /// Dark material.
        case dark

        /// Titlebar material.
        case titlebar

        /// Selection material.
        case selection

        /// Menu material.
        case menu

        /// Popover material.
        case popover

        /// Sidebar material.
        case sidebar

        /// Header material.
        case headerView

        /// Sheet material.
        case sheet

        /// Window background material.
        case windowBackground

        /// Heads-up display material.
        case hudWindow

        /// Full-screen UI material.
        case fullScreenUI

        /// Tool-tip material.
        case toolTip

        /// Content background material.
        case contentBackground

        /// Under-window background material.
        case underWindowBackground

        /// Under-page background material.
        case underPageBackground
    }

    /// Whether the effect is active.
    public enum State: Sendable {
        /// Follow the containing window state.
        case followsWindowActiveState

        /// Always draw active.
        case active

        /// Always draw inactive.
        case inactive
    }

    /// Requested material.
    open var material: Material = .appearanceBased {
        didSet {
            updateFallbackBackground()
        }
    }

    /// Requested blending mode.
    open var blendingMode: BlendingMode = .behindWindow {
        didSet {
            updateFallbackBackground()
        }
    }

    /// Requested active/inactive state.
    open var state: State = .followsWindowActiveState {
        didSet {
            updateFallbackBackground()
        }
    }

    /// Token for the live appearance-change observer, removed on deinit.
    private var winAppearanceObserver: NSObjectProtocol?

    /// Creates a visual effect view.
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        updateFallbackBackground()
        // The material's fallback color is resolved for the current appearance
        // and cached as a brush; re-resolve it when the system theme switches
        // live so the backdrop follows (a plain repaint keeps the old shade).
        winAppearanceObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.winEffectiveAppearanceDidChangeNotification,
            object: nil, queue: nil
        ) { [weak self] _ in
            self?.updateFallbackBackground()
            self?.needsDisplay = true
        }
    }

    deinit {
        if let winAppearanceObserver {
            NotificationCenter.default.removeObserver(winAppearanceObserver)
        }
    }

    /// Visual effect views are decorative containers and skip key-view traversal.
    open override var acceptsFirstResponder: Bool {
        false
    }

    private func updateFallbackBackground() {
        backgroundColor = fallbackColor
    }

    private var fallbackColor: NSColor {
        // Materials resolve through the effective appearance so a dark window
        // gets dark backdrops (a light material under white label text reads
        // as unreadable). `.dark`/`.hudWindow` are always dark; `.light` is
        // always light; the rest track the appearance.
        let dark = effectiveAppearance.winIsDark
        switch material {
        case .dark, .hudWindow:
            return NSColor(calibratedRed: 0.18, green: 0.2, blue: 0.23, alpha: 0.9)
        case .light:
            return NSColor(calibratedRed: 0.94, green: 0.96, blue: 0.98, alpha: 0.9)
        case .selection:
            return dark
                ? NSColor(calibratedRed: 0.15, green: 0.28, blue: 0.42, alpha: 0.85)
                : NSColor(calibratedRed: 0.78, green: 0.88, blue: 1.0, alpha: 0.85)
        case .sidebar, .headerView, .underWindowBackground, .underPageBackground:
            return dark
                ? NSColor(calibratedRed: 0.16, green: 0.17, blue: 0.19, alpha: 0.9)
                : NSColor(calibratedRed: 0.9, green: 0.94, blue: 0.98, alpha: 0.85)
        case .menu, .popover, .sheet, .toolTip:
            return dark
                ? NSColor(calibratedRed: 0.20, green: 0.20, blue: 0.21, alpha: 0.95)
                : NSColor(calibratedRed: 0.96, green: 0.94, blue: 0.9, alpha: 0.9)
        case .appearanceBased, .titlebar, .windowBackground, .fullScreenUI, .contentBackground:
            return dark
                ? NSColor(calibratedRed: 0.13, green: 0.13, blue: 0.14, alpha: 0.9)
                : NSColor(calibratedRed: 0.94, green: 0.96, blue: 0.98, alpha: 0.9)
        }
    }
}
