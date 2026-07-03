/// The shared font conversion manager.
///
/// The manager tracks the selected font and fronts the shared floating font
/// panel. Panel selections apply live: the manager updates `selectedFont`,
/// sends `changeFont(_:)` along the responder chain (or to `target` when
/// set), and fires `winFontDidChange`. Responders apply the change by
/// calling `convert(_:)` on their current font, matching AppKit's contract.
open class NSFontManager: NSObject {
    nonisolated(unsafe) private static let sharedManager = NSFontManager()

    /// The shared font manager instance.
    open class var shared: NSFontManager {
        sharedManager
    }

    /// The font of the current selection, when any.
    open var selectedFont: NSFont?

    /// Whether the current selection spans multiple fonts.
    open private(set) var isMultiple = false

    /// The object that receives `changeFont(_:)` instead of the responder
    /// chain, when set.
    open weak var target: AnyObject?

    /// Called after the user picks a font in the panel.
    ///
    /// Fired alongside the `changeFont(_:)` responder-chain action.
    open var winFontDidChange: ((NSFont) -> Void)?

    /// Creates a font manager.
    public override init() {
        super.init()
    }

    /// Records the font of the current selection.
    open func setSelectedFont(_ fontObj: NSFont, isMultiple flag: Bool) {
        selectedFont = fontObj
        isMultiple = flag
        NSFontPanel.shared.setPanelFont(fontObj, isMultiple: flag)
    }

    /// Returns a font converted to the panel's current selection.
    ///
    /// Responders call this from `changeFont(_:)` to apply the panel pick,
    /// matching AppKit's conversion entry point. Without a panel selection
    /// the font passes through unchanged.
    open func convert(_ font: NSFont) -> NSFont {
        selectedFont ?? font
    }

    /// Orders the shared floating font panel front, seeded with the selected font.
    open func orderFrontFontPanel(_ sender: Any?) {
        let panel = NSFontPanel.shared
        if let selectedFont {
            panel.setPanelFont(selectedFont, isMultiple: isMultiple)
        }
        panel.makeKeyAndOrderFront(sender)
    }

    /// Applies a live font panel selection.
    ///
    /// Updates the tracked selection, fires the change closure, and sends
    /// `changeFont(_:)` to the target or down the active responder chain.
    func panelFontDidChange(_ font: NSFont) {
        selectedFont = font
        winFontDidChange?(font)

        let responder = (target as? NSResponder)
            ?? NSApplication.shared.panelActionWindow?.firstResponder
            ?? NSApplication.shared.panelActionWindow
        responder?.changeFont(self)
    }
}
