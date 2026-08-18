// Checkbox, radio button, slider and combo box — the bulk of the catalog.
//
// Four small builders that between them replace 96 of the 147 placeholders,
// because the demo uses these four far more than anything else. Each is the
// real HTML control rather than a drawn imitation, which is the fidelity rule
// this backend was given: real DOM controls where HTML has them.
//
// They share one shape worth stating once, because it is what keeps them small.
// A control is a *box* (positioned, filed under `elements[handle]`) and
// sometimes a distinct *input* inside it. Event handlers write the user's
// choice back into `records` before running the action — so every inherited
// getter (`buttonState(for:)`, `sliderValue(for:)`, `comboBoxText(for:)`)
// keeps returning the right answer without this backend overriding one of
// them. That write-back is the whole trick; skip it and the framework reads
// stale values while the screen looks correct.

#if canImport(JavaScriptKit)

import JavaScriptKit
import SwiftDOM

extension WASMNativeControlBackend {
    /// Positions a control box in its parent's coordinates.
    internal func position(_ element: Element, in frame: NSRect) -> Element {
        element
            .setStyle("position", "absolute")
            .setStyle("box-sizing", "border-box")
            .setStyle("left", "\(frame.origin.x)px")
            .setStyle("top", "\(frame.origin.y)px")
            .setStyle("width", "\(frame.size.width)px")
            .setStyle("height", "\(frame.size.height)px")
    }

    /// Builds a checkbox or radio button: a `<label>` wrapping the real input
    /// and its title, so clicking the text toggles the control as AppKit does.
    ///
    /// Radio buttons are grouped by `name`, and the group is the parent handle.
    /// That matches AppKit, where a radio group is the set of siblings in one
    /// superview — without it the browser treats every radio on the page as one
    /// group and the demo's three alert-style buttons fight the ones on other
    /// pages.
    internal func makeToggle(_ handle: NativeHandle, title: String, frame: NSRect,
                             parent: NativeHandle?, isRadio: Bool) {
        let box = position(Element.label(), in: frame)
            .setStyle("display", "flex")
            .setStyle("align-items", "center")
            .setStyle("gap", "6px")
            .setStyle("font", "13px system-ui, sans-serif")

        let input = Element.input()
        _ = input.setAttribute("type", isRadio ? "radio" : "checkbox")
        if isRadio, let parent {
            _ = input.setAttribute("name", "cx-radio-\(parent.rawValue)")
        }
        _ = box.appendChild(input)

        let span = Element.span()
        span.textContent = title
        _ = box.appendChild(span)

        inputElements[handle] = input
        titleSpans[handle] = span
        register(handle, element: box, parent: parent)
    }

    /// Builds a slider as `<input type=range>`.
    ///
    /// `step` is deliberately fine rather than the default 1: AppKit sliders are
    /// continuous, and the demo's 0–100 slider reporting only integers would be
    /// a substituted behaviour, not a rendering difference.
    internal func makeSlider(_ handle: NativeHandle, value: Double,
                             minValue: Double, maxValue: Double,
                             frame: NSRect, parent: NativeHandle?) {
        let input = position(Element.input(), in: frame)
        _ = input.setAttribute("type", "range")
        applySliderRange(input, minValue: minValue, maxValue: maxValue)
        input.value = "\(value)"
        if frame.size.height > frame.size.width {
            // AppKit picks orientation from the frame; CSS needs telling.
            _ = input.setStyle("writing-mode", "vertical-lr")
                .setStyle("direction", "rtl")
        }
        inputElements[handle] = input
        register(handle, element: input, parent: parent)
    }

    /// Applies a slider's range and a continuous step.
    internal func applySliderRange(_ input: Element, minValue: Double, maxValue: Double) {
        _ = input.setAttribute("min", "\(minValue)")
        _ = input.setAttribute("max", "\(maxValue)")
        let span = maxValue - minValue
        _ = input.setAttribute("step", span > 0 ? "\(span / 1000)" : "any")
    }

    /// Builds a combo box: an editable `<input>` backed by a `<datalist>`.
    ///
    /// This is what an `NSComboBox` actually is — a text field that offers
    /// completions — so the datalist is the faithful mapping, not `<select>`,
    /// which would forbid the typing half.
    internal func makeComboBox(_ handle: NativeHandle, items: [String], text: String,
                               frame: NSRect, parent: NativeHandle?) {
        let box = position(Element.div(), in: frame)
        let listID = "cx-combo-\(handle.rawValue)"

        let input = Element.input()
            .setStyle("box-sizing", "border-box")
            .setStyle("width", "100%")
            .setStyle("height", "100%")
            .setStyle("font", "13px system-ui, sans-serif")
        _ = input.setAttribute("list", listID)
        input.value = text
        _ = box.appendChild(input)

        let list = Element.create("datalist")
        _ = list.setAttribute("id", listID)
        fillComboOptions(list, items: items)
        _ = box.appendChild(list)

        inputElements[handle] = input
        comboLists[handle] = list
        register(handle, element: box, parent: parent)
    }

    /// Fills a datalist with completions.
    internal func fillComboOptions(_ list: Element, items: [String]) {
        for item in items {
            let option = Element.option()
            _ = option.setAttribute("value", item)
            _ = list.appendChild(option)
        }
    }
}

#endif
