// Colour, font, alignment and tooltip — the properties every control shares.
//
// Cheap in lines and disproportionate in effect: these six methods are what
// turn eleven pages of black-on-white text into the demo as it is meant to
// look, and they apply to real controls and placeholders alike because both are
// ordinary positioned elements filed under `elements[handle]`.

#if canImport(JavaScriptKit)

import JavaScriptKit
import SwiftDOM

extension WASMNativeControlBackend {
    /// A CSS colour for an `NSColor`.
    ///
    /// `rgba()` rather than a hex string because AppKit colours carry alpha and
    /// the demo leans on it — half the page backgrounds are translucent tints
    /// over the window's own colour.
    internal static func cssColor(_ color: NSColor) -> String {
        let red = Int((color.redComponent * 255).rounded())
        let green = Int((color.greenComponent * 255).rounded())
        let blue = Int((color.blueComponent * 255).rounded())
        return "rgba(\(red), \(green), \(blue), \(color.alphaComponent))"
    }

    /// A CSS `font` shorthand for an `NSFont`.
    ///
    /// `NSFont.Weight`'s raw values are the Windows `LOGFONT` scale (100–900),
    /// which is the same nine-step scale CSS `font-weight` uses, so the weight
    /// carries across exactly rather than collapsing to bold/not-bold.
    internal static func cssFont(_ font: NSFont) -> String {
        let style = font.italic ? "italic " : ""
        // The system font has no real family name to hand a browser; let the
        // platform pick, which is what `.systemFont` means in the first place.
        let family = font.fontName.hasPrefix(".")
            ? "system-ui, sans-serif"
            : "\"\(font.fontName)\", system-ui, sans-serif"
        return "\(style)\(font.weight.rawValue) \(font.pointSize)px \(family)"
    }

    /// The CSS keyword for a text alignment.
    ///
    /// `.natural` maps to `start`, which is what "natural" means: the leading
    /// edge for the current writing direction, not a hardcoded left.
    internal static func cssTextAlign(_ alignment: NSTextAlignment) -> String {
        switch alignment {
        case .left: return "left"
        case .right: return "right"
        case .center: return "center"
        case .justified: return "justify"
        default: return "start"
        }
    }

    /// The flex `justify-content` matching a text alignment.
    ///
    /// Labels are flex rows so their text sits vertically centred like a native
    /// field's, and in a flex row the horizontal position is `justify-content`,
    /// not `text-align`.
    internal static func cssJustify(_ alignment: NSTextAlignment) -> String {
        switch alignment {
        case .right: return "flex-end"
        case .center: return "center"
        default: return "flex-start"
        }
    }

    /// Fills a `<select>` with options and selects one.
    internal func fillPopUpOptions(_ select: Element, items: [String], selectedIndex: Int) {
        for item in items {
            let option = Element.option()
            option.textContent = item
            _ = option.setAttribute("value", item)
            _ = select.appendChild(option)
        }
        if items.indices.contains(selectedIndex) {
            select.value = items[selectedIndex]
        }
    }
}

#endif
