/// The shared color panel.
///
/// This first slice keeps AppKit's `NSColorPanel` surface — a shared singleton
/// with a current `color`, target/action storage, and
/// `makeKeyAndOrderFront(_:)` — while the classic Windows backend presents the
/// native modal `ChooseColorW` chooser instead of a floating panel.
/// `makeKeyAndOrderFront(_:)` therefore runs synchronously and returns after
/// the user confirms or cancels the chooser.
open class NSColorPanel: NSObject {
    nonisolated(unsafe) private static let sharedPanel = NSColorPanel()

    /// The shared color panel instance.
    open class var shared: NSColorPanel {
        sharedPanel
    }

    /// The currently selected color.
    ///
    /// Setting the color also updates the attached active color well.
    open var color: NSColor = .white {
        didSet {
            winActiveColorWell?.color = color
        }
    }

    /// The color well the panel currently feeds, when any.
    weak var winActiveColorWell: NSColorWell?

    /// The stored action target, kept for AppKit API compatibility.
    open private(set) weak var winTarget: AnyObject?

    /// The stored action selector name, kept for AppKit API compatibility.
    open private(set) var winAction: String?

    /// Called after the user picks a color in the chooser.
    ///
    /// AppKit notifies through target/action; this Windows-only closure is the
    /// framework's first-slice change notification.
    open var winColorDidChange: ((NSColor) -> Void)?

    /// Creates a color panel.
    public override init() {
        super.init()
    }

    /// Stores the target notified about color changes.
    open func setTarget(_ target: AnyObject?) {
        winTarget = target
    }

    /// Stores the action selector name sent on color changes.
    open func setAction(_ action: String?) {
        winAction = action
    }

    /// Presents the color chooser.
    ///
    /// The classic backend runs the native modal chooser seeded with `color`;
    /// a confirmed pick updates `color` and fires `winColorDidChange`, while a
    /// cancel leaves the panel state untouched.
    open func makeKeyAndOrderFront(_ sender: Any?) {
        guard let chosen = NSApplication.shared.nativeBackend.runColorChooser(initialColor: color) else {
            return
        }

        color = chosen
        winColorDidChange?(chosen)
    }
}
