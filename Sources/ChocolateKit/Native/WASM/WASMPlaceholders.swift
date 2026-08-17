// "Under construction" placeholders for controls the browser backend has not
// built yet (Docs/WASMChocolatePlan.md, phase W6 and the phases after it).
//
// The point is not decoration. `register(_:element:parent:)` attaches a child
// to the element filed under its parent handle, so a `create…` method that
// makes no element does not merely fail to draw itself — every descendant is
// orphaned and the page loses whole sections silently. A control this backend
// cannot render therefore still has to produce *something* that children can be
// appended to. Given that it must exist anyway, it may as well say what it is.
//
// So a placeholder is a real container: hazard-striped, captioned with the
// AppKit class it stands for, and otherwise an ordinary positioned box that
// honours `setFrame`, `setHidden` and `setEnabled` like any other element. That
// is ground rule 4 — degrade visibly, never silently — paying for itself.
//
// Replacing one with a real control is a one-line change in the matching
// override: call the real builder instead of `makePlaceholder`. Nothing else in
// the backend has to move.

#if canImport(JavaScriptKit)

import JavaScriptKit
import SwiftDOM

extension WASMNativeControlBackend {
    /// The AppKit class a backend `kind` most likely came from.
    ///
    /// A fallback only. The exact name arrives later through
    /// `setDebugClassName(_:for:)` — the create call happens first, so the
    /// caption is written from this table and rewritten a moment later. Where
    /// one kind serves several classes (a checkbox and a radio button are both
    /// `NSButton`) the table says so rather than guessing.
    internal static let placeholderClassNames: [String: String] = [
        "box": "NSBox",
        "calendarDatePicker": "NSDatePicker",
        "checkbox": "NSButton (checkbox)",
        "comboBox": "NSComboBox",
        "datePicker": "NSDatePicker",
        "editableTextView": "NSTextView",
        "imageView": "NSImageView",
        "popUpButton": "NSPopUpButton",
        "progressIndicator": "NSProgressIndicator",
        "radioButton": "NSButton (radio)",
        "scroller": "NSScroller",
        "secureTextField": "NSSecureTextField",
        "slider": "NSSlider",
        "stepper": "NSStepper",
        "tabView": "NSTabView",
        "tableView": "NSTableView",
        "textView": "NSTextView",
        "toolbar": "NSToolbar"
    ]

    /// Builds, files and parents an "under construction" box for a handle.
    ///
    /// Returns nothing: the caller already has the handle from `super`, and
    /// every placeholder is reached through `elements[handle]` afterwards
    /// exactly like a real control.
    internal func makePlaceholder(_ handle: NativeHandle, kind: String,
                                  frame: NSRect, parent: NativeHandle?) {
        let name = Self.placeholderClassNames[kind] ?? kind
        let box = Element.div()
            .setStyle("position", "absolute")
            .setStyle("box-sizing", "border-box")
            .setStyle("left", "\(frame.origin.x)px")
            .setStyle("top", "\(frame.origin.y)px")
            .setStyle("width", "\(frame.size.width)px")
            .setStyle("height", "\(frame.size.height)px")
            .setStyle("border", "1px dashed #b06a2c")
            // Diagonal hazard stripes read as "unfinished" at any size — a
            // 16-point checkbox and a 600-point table both look wrong on
            // purpose — and being nearly transparent they never hide a child
            // that is already rendering correctly inside them.
            .setStyle("background",
                      "repeating-linear-gradient(45deg, rgba(255,176,108,.16) 0 6px, transparent 6px 12px)")
        // Deliberately no `overflow: hidden`: children of a placeholder are
        // real controls and must not be clipped by their unfinished parent.

        _ = box.setAttribute("data-cx-placeholder", "1")
        _ = box.setAttribute("data-cx-kind", kind)
        _ = box.setAttribute("data-cx-class", name)
        _ = box.setAttribute("title", "\(name) — under construction (WASM backend)")

        // The caption clips itself rather than the box, so a control too small
        // to show its name still keeps the right shape and size on the page.
        let caption = Element.div()
            .setStyle("position", "absolute")
            .setStyle("left", "2px").setStyle("top", "0")
            .setStyle("max-width", "100%")
            .setStyle("font", "10px/1.2 ui-monospace, monospace")
            .setStyle("color", "#8a4b12")
            .setStyle("white-space", "nowrap")
            .setStyle("overflow", "hidden")
            .setStyle("text-overflow", "ellipsis")
            .setStyle("pointer-events", "none")
        caption.textContent = name
        _ = box.appendChild(caption)

        placeholderCaptions[handle] = caption
        register(handle, element: box, parent: parent)
    }

    /// Rewrites a placeholder's caption once the real class name is known.
    internal func applyDebugClassName(_ name: String, to handle: NativeHandle) {
        guard let caption = placeholderCaptions[handle] else {
            return
        }

        caption.textContent = name
        _ = elements[handle]?.setAttribute("data-cx-class", name)
        _ = elements[handle]?.setAttribute("title", "\(name) — under construction (WASM backend)")
    }

    /// Appends a control's text to its placeholder caption.
    ///
    /// A placeholder that says `NSPopUpButton · "Controls"` is far easier to
    /// find on a page of eleven than one that only says `NSPopUpButton`.
    internal func setPlaceholderText(_ text: String, for handle: NativeHandle) -> Bool {
        guard let caption = placeholderCaptions[handle] else {
            return false
        }

        let name = elements[handle]?.getAttribute("data-cx-class") ?? ""
        caption.textContent = text.isEmpty ? name : "\(name) · \(text)"
        return true
    }
}

#endif
