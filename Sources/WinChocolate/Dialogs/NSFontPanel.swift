/// The shared font panel.
///
/// This first slice keeps AppKit's `NSFontPanel` surface — a shared singleton
/// seeded through `setPanelFont(_:isMultiple:)` and presented with
/// `makeKeyAndOrderFront(_:)` — while the classic Windows backend presents the
/// native modal `ChooseFontW` chooser instead of a floating panel.
/// `makeKeyAndOrderFront(_:)` therefore runs synchronously and returns after
/// the user confirms or cancels the chooser.
open class NSFontPanel: NSObject {
    nonisolated(unsafe) private static let sharedPanel = NSFontPanel()

    /// The shared font panel instance.
    open class var shared: NSFontPanel {
        sharedPanel
    }

    /// The font most recently seeded or chosen in the panel, when any.
    ///
    /// AppKit exposes the selection through `NSFontManager`; this win-prefixed
    /// accessor is the panel's first-slice storage.
    open var winSelectedFont: NSFont?

    /// Whether the panel represents a multiple-font selection.
    open private(set) var winIsMultiple = false

    /// Called after the user picks a font in the chooser.
    ///
    /// AppKit notifies through the `changeFont(_:)` responder convention; this
    /// Windows-only closure is the framework's first-slice notification.
    open var winFontDidChange: ((NSFont) -> Void)?

    /// Creates a font panel.
    public override init() {
        super.init()
    }

    /// Seeds the panel with the font it should display.
    open func setPanelFont(_ fontObj: NSFont, isMultiple flag: Bool) {
        winSelectedFont = fontObj
        winIsMultiple = flag
    }

    /// Presents the font chooser.
    ///
    /// The classic backend runs the native modal chooser seeded with
    /// `winSelectedFont`; a confirmed pick updates `winSelectedFont` and fires
    /// `winFontDidChange`, while a cancel leaves the panel state untouched.
    open func makeKeyAndOrderFront(_ sender: Any?) {
        guard let chosen = NSApplication.shared.nativeBackend.runFontChooser(initialFont: winSelectedFont) else {
            return
        }

        winSelectedFont = chosen
        winFontDidChange?(chosen)
    }
}
