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

    /// Builds a combo box: an editable field, a disclosure arrow, and a list.
    ///
    /// A `<datalist>` was the obvious mapping and the wrong one. It only offers
    /// completions *while the user types* and gives no affordance to open —
    /// clicking an `NSComboBox` did nothing, because there was nothing to
    /// click. AppKit's combo box shows its whole list on demand, so the list is
    /// built explicitly here: the editable half stays a real `<input>`, and the
    /// arrow drops a panel of every item.
    internal func makeComboBox(_ handle: NativeHandle, items: [String], text: String,
                               frame: NSRect, parent: NativeHandle?) {
        let box = position(Element.div(), in: frame)
            .setStyle("display", "flex")
            .setStyle("border", "1px solid #767676")
            .setStyle("border-radius", "4px")
            .setStyle("background", "#ffffff")
            .setStyle("overflow", "visible")

        let input = Element.input()
            .setStyle("box-sizing", "border-box")
            .setStyle("flex", "1")
            .setStyle("min-width", "0")
            .setStyle("height", "100%")
            .setStyle("border", "none")
            .setStyle("outline", "none")
            .setStyle("padding", "0 6px")
            .setStyle("background", "transparent")
            .setStyle("font", "13px system-ui, sans-serif")
        input.value = text
        _ = box.appendChild(input)

        let arrow = Element.div()
            .setStyle("width", "18px")
            .setStyle("display", "flex")
            .setStyle("align-items", "center")
            .setStyle("justify-content", "center")
            .setStyle("cursor", "default")
            .setStyle("color", "#444")
            .setStyle("font", "9px system-ui, sans-serif")
            .setStyle("border-left", "1px solid #d0d0d0")
        arrow.textContent = "▼"
        _ = box.appendChild(arrow)

        // The list floats above later siblings, which are absolutely positioned
        // and would otherwise paint over it.
        let list = Element.div()
            .setStyle("position", "absolute")
            .setStyle("left", "0")
            .setStyle("top", "100%")
            .setStyle("min-width", "100%")
            .setStyle("max-height", "180px")
            .setStyle("overflow-y", "auto")
            .setStyle("background", "#ffffff")
            .setStyle("border", "1px solid #c0c0c0")
            .setStyle("box-shadow", "0 4px 12px rgba(0,0,0,0.18)")
            .setStyle("z-index", "1100")
            .setStyle("display", "none")
        _ = box.appendChild(list)

        inputElements[handle] = input
        comboLists[handle] = list
        register(handle, element: box, parent: parent)
        fillComboOptions(handle, list, items: items)

        listeners[handle, default: []].append(arrow.addEventListener(.click) { [weak self] event in
            event.stopPropagation()
            self?.toggleComboList(handle)
        })
    }

    /// Shows or hides a combo box's list.
    internal func toggleComboList(_ handle: NativeHandle) {
        guard let list = comboLists[handle] else { return }
        let isOpen = list.getStyle("display") == "block"
        _ = list.setStyle("display", isOpen ? "none" : "block")
        guard !isOpen else { return }

        // Dismiss on the next press outside. Capture phase, because a press
        // inside a view stops bubbling before `body` ever sees it.
        _ = DOM.window.setTimeout(milliseconds: 0) { [weak self] in
            guard let self, DOM.isBrowser else { return }
            var token: EventListener?
            token = DOM.document.body.addEventListener(
                .pointerdown, options: EventListenerOptions(capture: true, once: false, passive: false)
            ) { [weak self] event in
                guard let self, let box = self.elements[handle] else { return }
                if let target = event.target, box.contains(target) { return }
                _ = self.comboLists[handle]?.setStyle("display", "none")
                token?.remove()
            }
            if let token { self.listeners[handle, default: []].append(token) }
        }
    }

    /// Fills a combo box's list with one selectable row per item.
    ///
    /// Picking a row writes the choice into `records` before firing the action,
    /// the same contract every other value control here follows — that is what
    /// keeps the inherited `comboBoxText(for:)` correct without overriding it.
    internal func fillComboOptions(_ handle: NativeHandle, _ list: Element, items: [String]) {
        _ = list.removeAllChildren()
        for item in items {
            let row = Element.div()
                .setStyle("padding", "4px 8px")
                .setStyle("cursor", "default")
                .setStyle("font", "13px system-ui, sans-serif")
                .setStyle("white-space", "nowrap")
            row.textContent = item
            listeners[handle, default: []].append(row.addEventListener(.click) { [weak self] event in
                event.stopPropagation()
                guard let self else { return }
                self.inputElements[handle]?.value = item
                self.records[handle]?.text = item
                _ = list.setStyle("display", "none")
                self.actions[handle]?()
            })
            _ = list.appendChild(row)
        }
    }
}

#endif
