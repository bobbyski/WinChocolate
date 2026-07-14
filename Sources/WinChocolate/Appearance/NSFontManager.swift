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

    /// A font trait that can be added to or removed from a font.
    public struct FontTraitMask: OptionSet, Sendable {
        /// Raw option value.
        public let rawValue: UInt

        /// Creates a trait mask from a raw value.
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// The italic trait.
        public static let italic = FontTraitMask(rawValue: 1 << 0)

        /// The bold trait.
        public static let bold = FontTraitMask(rawValue: 1 << 1)

        /// The unbold (regular-weight) trait.
        public static let unbold = FontTraitMask(rawValue: 1 << 2)

        /// The unitalic (upright) trait.
        public static let unitalic = FontTraitMask(rawValue: 1 << 3)
    }

    /// Returns a copy of a font with a trait added or removed.
    ///
    /// Adding `.bold`/`.italic` sets that trait; `.unbold`/`.unitalic` clears
    /// it, matching AppKit's toggle-by-mask conversion.
    open func convert(_ font: NSFont, toHaveTrait trait: FontTraitMask) -> NSFont {
        var result = font
        if trait.contains(.bold) {
            result = result.withWeight(.bold)
        }
        if trait.contains(.unbold) {
            result = result.withWeight(.regular)
        }
        if trait.contains(.italic) {
            result = result.withItalic(true)
        }
        if trait.contains(.unitalic) {
            result = result.withItalic(false)
        }
        return result
    }

    /// Returns the traits currently set on a font.
    open func traits(of font: NSFont) -> FontTraitMask {
        var traits: FontTraitMask = []
        if font.weight.isBold {
            traits.insert(.bold)
        }
        if font.italic {
            traits.insert(.italic)
        }
        return traits
    }

    /// Returns a font's weight on AppKit's 0-15 coarse scale.
    open func weight(of font: NSFont) -> Int {
        // Map the 100-900 LOGFONT scale onto AppKit's 1-14 range.
        max(1, min(14, font.weight.rawValue / 65))
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
    /// Updates the tracked selection and sends `changeFont(_:)` to the
    /// target or down the active responder chain, as AppKit does.
    func panelFontDidChange(_ font: NSFont) {
        selectedFont = font

        let responder = (target as? NSResponder)
            ?? NSApplication.shared.panelActionWindow?.firstResponder
            ?? NSApplication.shared.panelActionWindow
        responder?.changeFont(self)
    }
}
