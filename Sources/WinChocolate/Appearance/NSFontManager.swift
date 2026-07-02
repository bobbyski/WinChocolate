/// The shared font conversion manager.
///
/// This first slice keeps AppKit's `NSFontManager` entry points for tracking
/// the selected font and ordering the font panel front. The classic Windows
/// backend presents the native modal font chooser, so
/// `orderFrontFontPanel(_:)` runs synchronously and applies a confirmed pick
/// before returning.
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

    /// The object that receives `changeFont` conversions, stored for AppKit
    /// API compatibility.
    open weak var target: AnyObject?

    /// Called after the user picks a font in the panel.
    ///
    /// AppKit notifies through the `changeFont(_:)` responder convention; this
    /// Windows-only closure is the framework's first-slice notification.
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

    /// Orders the shared font panel front, seeded with the selected font.
    ///
    /// A confirmed pick updates `selectedFont` and fires `winFontDidChange`.
    open func orderFrontFontPanel(_ sender: Any?) {
        let panel = NSFontPanel.shared
        if let selectedFont {
            panel.setPanelFont(selectedFont, isMultiple: isMultiple)
        }
        panel.winFontDidChange = { [weak self] font in
            guard let self else {
                return
            }

            self.selectedFont = font
            self.winFontDidChange?(font)
        }
        panel.makeKeyAndOrderFront(sender)
    }
}
