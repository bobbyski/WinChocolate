// Toolbar item chrome.
//
// A toolbar item's view does not arrive as a toolbar item. It arrives as a
// plain view whose *text* is a tab-separated descriptor the framework writes
// through `setText`:
//
//     __WinChocolateToolbarItem \t title \t imagePath \t showImage \t showLabel
//                               \t labelPosition \t tintRGBA
//
// Win32 parses it in `Win32ToolbarRendering`, GTK in `GTKNativeControlBackendPart11`,
// and a backend that does not parse it renders the descriptor as literal text —
// which is exactly what the top of the demo window showed until this landed.
// It is an internal protocol between the core and its backends, not a caption.

#if canImport(JavaScriptKit)

import JavaScriptKit
import SwiftDOM

extension WASMNativeControlBackend {
    /// The marker that identifies a toolbar-item descriptor.
    internal static let toolbarItemMarker = "__WinChocolateToolbarItem"

    /// Renders a toolbar item descriptor into an element, or reports that the
    /// text was not one.
    internal func applyToolbarItemText(_ text: String, for handle: NativeHandle) -> Bool {
        let fields = text.components(separatedBy: "\t")
        guard fields.first == Self.toolbarItemMarker, let element = elements[handle] else {
            return false
        }

        let title = fields.count > 1 ? fields[1] : ""
        let imagePath = fields.count > 2 ? fields[2] : ""
        let showImage = fields.count > 3 && fields[3] == "1"
        let showLabel = fields.count > 4 && fields[4] == "1"
        let labelBeside = fields.count > 5 && fields[5] == "beside"
        let tint = fields.count > 6 ? fields[6] : ""

        _ = element.removeAllChildren()
        _ = element
            .setStyle("display", "flex")
            .setStyle("flex-direction", labelBeside ? "row" : "column")
            .setStyle("align-items", "center")
            .setStyle("justify-content", "center")
            .setStyle("gap", "2px")
            .setStyle("font", "11px system-ui, sans-serif")
            .setStyle("cursor", "default")
            .setStyle("user-select", "none")

        if showImage, !imagePath.isEmpty {
            let image = Element.create("img")
                .setStyle("width", "18px")
                .setStyle("height", "18px")
                .setStyle("object-fit", "contain")
            applyImagePath(image, path: imagePath)
            // A template image is tinted to contrast with the strip, which the
            // core has already decided; a CSS filter is the only way to recolour
            // an <img> without decoding it.
            if !tint.isEmpty {
                _ = image.setStyle("filter", Self.tintFilter(tint))
            }
            _ = element.appendChild(image)
        }

        if showLabel, !title.isEmpty {
            let label = Element.div().setStyle("white-space", "nowrap")
            label.textContent = title
            _ = element.appendChild(label)
        }
        return true
    }

    /// Renders a customization-palette tile, or reports that the text was not one.
    ///
    /// `NSToolbarCustomizationTile` is the toolbar's *second* text-as-descriptor
    /// protocol: a plain view whose text is `"title\nimageName"`. No backend
    /// special-cases it, so GTK shows the image name as a second line of text
    /// too — the palette in the demo reads `Open` / `/Resources/ToolbarOpen.png`
    /// instead of an icon above a label.
    ///
    /// Distinguishing it from a genuine two-line caption is safe rather than
    /// clever: a real multi-line caption is an `NSTextField`, which arrives as
    /// kind `textField`. Only a bare `view` carrying exactly two lines is a
    /// tile, which is the same reasoning the toolbar-item marker relies on.
    internal func applyToolbarTileText(_ text: String, for handle: NativeHandle) -> Bool {
        guard records[handle]?.kind == "view", let element = elements[handle] else {
            return false
        }

        let lines = text.components(separatedBy: "\n")
        guard lines.count == 2, !lines[0].isEmpty, !lines[1].isEmpty else {
            return false
        }

        _ = element.removeAllChildren()
        _ = element
            .setStyle("display", "flex")
            .setStyle("flex-direction", "column")
            .setStyle("align-items", "center")
            .setStyle("justify-content", "center")
            .setStyle("gap", "3px")
            .setStyle("font", "11px system-ui, sans-serif")
            .setStyle("text-align", "center")

        // The second line names an image: a file path for the demo's own icons,
        // or a symbolic name the framework picked for a built-in item.
        if lines[1].contains("/") || lines[1].contains("\\") {
            let image = Element.create("img")
                .setStyle("width", "20px").setStyle("height", "20px")
                .setStyle("object-fit", "contain")
            applyImagePath(image, path: lines[1])
            _ = element.appendChild(image)
        }

        let label = Element.div().setStyle("white-space", "nowrap")
        label.textContent = lines[0]
        _ = element.appendChild(label)
        return true
    }

    /// Pops a context menu at a point on the desktop.
    ///
    /// Returns `nil`, always, and that is not a shortcut: the protocol wants the
    /// chosen item back *synchronously*, and a page cannot block waiting for a
    /// click. GTK returns nil here for the same reason. Activation does not
    /// depend on the return value — each row calls `item.performAction()`
    /// directly, which is the same path the menu bar uses — so a right-click
    /// menu works fully even though the caller learns nothing from the result.
    internal func presentContextMenu(_ menu: NSMenu, at point: NSPoint) -> NSMenuItem? {
        guard let desktop else { return nil }
        dismissContextMenu()

        let sheet = Element.div()
            .setStyle("position", "absolute")
            .setStyle("left", "\(point.x)px")
            .setStyle("top", "\(point.y)px")
            .setStyle("min-width", "180px")
            .setStyle("padding", "4px 0")
            .setStyle("background", "#f6f6f6")
            .setStyle("border", "1px solid #c0c0c0")
            .setStyle("border-radius", "6px")
            .setStyle("box-shadow", "0 4px 14px rgba(0,0,0,0.22)")
            .setStyle("font", "13px system-ui, sans-serif")
            .setStyle("z-index", "1200")
            .setStyle("user-select", "none")

        for item in menu.items where !item.isHidden {
            _ = sheet.appendChild(makeContextRow(for: item))
        }
        _ = desktop.appendChild(sheet)
        contextMenuElement = sheet

        // Dismiss on a press *outside* the menu. The outside test is essential,
        // not defensive: `pointerdown` precedes `click`, so dismissing on any
        // press tears the row out of the document before its own click can land
        // and every item silently does nothing. Registered a turn later so the
        // press that opened the menu does not immediately close it.
        _ = DOM.window.setTimeout(milliseconds: 0) { [weak self] in
            guard let self else { return }
            self.contextMenuListeners.append(
                DOM.document.body.addEventListener(.pointerdown) { [weak self] event in
                    guard let self, let sheet = self.contextMenuElement else { return }
                    if let target = event.target, sheet.contains(target) { return }
                    self.dismissContextMenu()
                })
        }
        return nil
    }

    /// One row of a context menu.
    private func makeContextRow(for item: NSMenuItem) -> Element {
        if item.isSeparatorItem {
            return Element.div()
                .setStyle("height", "1px")
                .setStyle("margin", "4px 0")
                .setStyle("background", "#d0d0d0")
        }

        let row = Element.div()
            .setStyle("padding", "4px 14px")
            .setStyle("cursor", "default")
            .setStyle("color", item.isEnabled ? "#111" : "#999")
        // A checked item needs the tick to occupy space even when off, or the
        // rows jitter as the state changes.
        row.textContent = (item.state == .on ? "✓ " : "\u{2007} ") + item.title

        guard item.isEnabled else { return row }
        contextMenuListeners.append(row.addEventListener(.click) { [weak self] event in
            event.stopPropagation()
            self?.dismissContextMenu()
            _ = item.performAction()
        })
        return row
    }

    /// Takes down the open context menu, if any.
    internal func dismissContextMenu() {
        _ = contextMenuElement?.remove()
        contextMenuElement = nil
        contextMenuListeners.forEach { $0.remove() }
        contextMenuListeners.removeAll()
    }

    /// A CSS filter approximating a template tint.
    ///
    /// Deliberately coarse: the descriptor carries an RGBA the core computed
    /// for contrast, and all that has to survive is *light glyph on a dark
    /// strip* versus *dark glyph on a light one*. Reproducing an arbitrary hue
    /// needs a real recolour, which is a canvas job and not worth it for icons
    /// the framework only ever tints toward black or white.
    internal static func tintFilter(_ rgba: String) -> String {
        let parts = rgba.split(separator: ",").compactMap { Double($0) }
        guard parts.count >= 3 else { return "" }
        let luminance = 0.299 * parts[0] + 0.587 * parts[1] + 0.114 * parts[2]
        return luminance > 0.5 ? "brightness(0) invert(1)" : "brightness(0)"
    }
}

#endif
