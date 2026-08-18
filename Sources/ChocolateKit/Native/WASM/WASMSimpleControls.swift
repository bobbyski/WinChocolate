// The short tail: progress, secure field, text view, box, stepper, image view,
// scroller and date picker.
//
// Same shape as `WASMValueControls`: build the real HTML element, keep the
// interactive one in `inputElements` when it differs from the positioned box,
// and write the user's choice back into `records` before firing the action so
// the inherited getters stay correct.

#if canImport(JavaScriptKit)

import JavaScriptKit
import SwiftDOM

extension WASMNativeControlBackend {
    /// Builds a determinate `<progress>`.
    ///
    /// The indeterminate case is a `<progress>` with no `value`, which is
    /// exactly how HTML spells "busy, length unknown" — the browser animates it
    /// for free and it matches AppKit's spinning style closely enough to be a
    /// rendering difference rather than a substituted behaviour.
    internal func makeProgressIndicator(_ handle: NativeHandle, value: Double,
                                        minValue: Double, maxValue: Double,
                                        frame: NSRect, parent: NativeHandle?) {
        let bar = position(Element.create("progress"), in: frame)
        applyProgress(bar, value: value, minValue: minValue, maxValue: maxValue)
        inputElements[handle] = bar
        register(handle, element: bar, parent: parent)
    }

    /// Applies a progress bar's range and value in HTML's 0…max terms.
    internal func applyProgress(_ bar: Element, value: Double,
                                minValue: Double, maxValue: Double) {
        let span = maxValue - minValue
        guard span > 0 else {
            _ = bar.removeAttribute("value")
            return
        }

        _ = bar.setAttribute("max", "\(span)")
        _ = bar.setAttribute("value", "\(min(max(value - minValue, 0), span))")
    }

    /// Builds a password field.
    internal func makeSecureField(_ handle: NativeHandle, text: String,
                                  frame: NSRect, parent: NativeHandle?) {
        let input = position(Element.input(), in: frame)
            .setStyle("font", "13px system-ui, sans-serif")
        _ = input.setAttribute("type", "password")
        input.value = text
        inputElements[handle] = input
        register(handle, element: input, parent: parent)
    }

    /// Builds a multi-line text view.
    internal func makeTextView(_ handle: NativeHandle, text: String, isEditable: Bool,
                               frame: NSRect, parent: NativeHandle?) {
        let area = position(Element.create("textarea"), in: frame)
            .setStyle("font", "13px system-ui, sans-serif")
            .setStyle("resize", "none")
        area.value = text
        if !isEditable {
            _ = area.setAttribute("readonly", "readonly")
        }
        inputElements[handle] = area
        register(handle, element: area, parent: parent)
    }

    /// Builds a titled group box.
    ///
    /// A `<fieldset>` with a `<legend>` is the semantic match for `NSBox`, and
    /// it stays a container — the box's children are real controls positioned
    /// inside it, and clipping or replacing them would lose whole sections.
    internal func makeBox(_ handle: NativeHandle, title: String,
                          frame: NSRect, parent: NativeHandle?) {
        let box = position(Element.create("fieldset"), in: frame)
            .setStyle("border", "1px solid #c0c0c0")
            .setStyle("border-radius", "4px")
            .setStyle("margin", "0")
            .setStyle("padding", "0")
            .setStyle("font", "13px system-ui, sans-serif")
        let legend = Element.create("legend")
            .setStyle("padding", "0 4px")
        legend.textContent = title
        _ = box.appendChild(legend)
        titleSpans[handle] = legend
        register(handle, element: box, parent: parent)
    }

    /// Builds a stepper: the up/down pair, and nothing else.
    ///
    /// `NSStepper` is only the arrows — the field beside it in the demo is a
    /// separate `NSTextField`. `<input type=number>` would draw its own field
    /// and give the page two, so the arrows are built directly.
    internal func makeStepper(_ handle: NativeHandle,
                              configuration: NativeStepperConfiguration,
                              frame: NSRect, parent: NativeHandle?) {
        let box = position(Element.div(), in: frame)
            .setStyle("display", "flex")
            .setStyle("flex-direction", "column")

        let up = makeStepperArrow("▲")
        let down = makeStepperArrow("▼")
        _ = box.appendChild(up)
        _ = box.appendChild(down)

        stepperArrows[handle] = (up: up, down: down)
        register(handle, element: box, parent: parent)
    }

    private func makeStepperArrow(_ glyph: String) -> Element {
        let button = Element.button()
            .setStyle("flex", "1")
            .setStyle("padding", "0")
            .setStyle("font", "8px system-ui, sans-serif")
            .setStyle("line-height", "1")
            .setStyle("cursor", "default")
        button.textContent = glyph
        return button
    }

    /// Builds an image view.
    internal func makeImageView(_ handle: NativeHandle, imagePath: String?, description: String,
                                frame: NSRect, parent: NativeHandle?) {
        let image = position(Element.create("img"), in: frame)
            .setStyle("object-fit", "contain")
        _ = image.setAttribute("alt", description)
        applyImagePath(image, path: imagePath)
        inputElements[handle] = image
        register(handle, element: image, parent: parent)
    }

    /// Points an `<img>` at a framework image path.
    ///
    /// The framework's path addresses the WASI filesystem the demo reads
    /// through `Bundle`; the browser cannot fetch that, but the same bytes are
    /// served next to the page, so the file name is the bridge. Windows-shaped
    /// separators are honoured because the demo's own fallback produces them.
    internal func applyImagePath(_ image: Element, path: String?) {
        guard let path, !path.isEmpty else {
            _ = image.removeAttribute("src")
            return
        }

        let name = path.split(whereSeparator: { $0 == "/" || $0 == "\\" }).last.map(String.init) ?? path
        _ = image.setAttribute("src", "Resources/\(Self.repairingTruncatedExtension(name))")
    }

    /// Restores an extension that WASI's `Bundle` truncated.
    ///
    /// Measured, not guessed: the demo asks for `WinChocolateArtworkDemo` of
    /// type `bmp`, and swift-corelibs-foundation's
    /// `Bundle.path(forResource:ofType:inDirectory:)` hands back
    /// `/Resources/WinChocolateArtworkDemo.bm` — the last character of the
    /// extension is gone, and the path is returned without the file existing,
    /// so the lookup does not even fail loudly. The demo is frozen and Bundle is
    /// upstream, so the repair happens here, at the boundary where the broken
    /// value arrives, against the small set of extensions this demo ships.
    ///
    /// Deliberately narrow: only a *proper prefix* of a known extension is
    /// completed, so a genuine `.bm` file would still be requested as `.bm`.
    internal static func repairingTruncatedExtension(_ name: String) -> String {
        let known = ["bmp", "png", "ico", "jpg", "jpeg", "gif", "svg", "xib"]
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else {
            return name
        }

        let stem = String(name[name.startIndex..<dot])
        let ext = String(name[name.index(after: dot)...]).lowercased()
        guard !ext.isEmpty, !known.contains(ext),
              let completed = known.first(where: { $0.hasPrefix(ext) && $0 != ext }) else {
            return name
        }

        return "\(stem).\(completed)"
    }

    /// Builds a tab view: a strip of tab buttons over a content pane.
    ///
    /// The pane is a separate element registered in `tabContents`, so children
    /// added to the tab view land *inside* it rather than on top of the strip —
    /// the same arrangement a window uses for its client area.
    internal func makeTabView(_ handle: NativeHandle, items: [String], selectedIndex: Int,
                              frame: NSRect, parent: NativeHandle?) {
        let box = position(Element.div(), in: frame)
            .setStyle("display", "flex")
            .setStyle("flex-direction", "column")
            .setStyle("border", "1px solid #c0c0c0")
            .setStyle("border-radius", "4px")
            .setStyle("font", "13px system-ui, sans-serif")

        let strip = Element.div()
            .setStyle("display", "flex")
            .setStyle("gap", "2px")
            .setStyle("padding", "4px 4px 0 4px")
            .setStyle("background", "#f0f0f0")
            .setStyle("border-bottom", "1px solid #c0c0c0")
        _ = box.appendChild(strip)

        let content = Element.div()
            .setStyle("position", "relative")
            .setStyle("flex", "1")
            .setStyle("overflow", "hidden")
        _ = box.appendChild(content)

        tabStrips[handle] = strip
        tabContents[handle] = content
        register(handle, element: box, parent: parent)
        rebuildTabStrip(handle, items: items, selectedIndex: selectedIndex)
    }

    /// Rebuilds a tab view's buttons and reapplies the selection.
    internal func rebuildTabStrip(_ handle: NativeHandle, items: [String], selectedIndex: Int) {
        guard let strip = tabStrips[handle] else { return }
        _ = strip.removeAllChildren()

        var buttons: [Element] = []
        for (index, title) in items.enumerated() {
            let tab = Element.button()
                .setStyle("padding", "4px 12px")
                .setStyle("border", "1px solid #c0c0c0")
                .setStyle("border-bottom", "none")
                .setStyle("border-radius", "4px 4px 0 0")
                .setStyle("font", "13px system-ui, sans-serif")
                .setStyle("cursor", "default")
            tab.textContent = title
            listeners[handle, default: []].append(tab.addEventListener(.click) { [weak self] _ in
                guard let self else { return }
                // Write the choice back before firing, exactly as the value
                // controls do, so the inherited getter stays correct.
                self.records[handle]?.tabViewSelectedIndex = index
                self.highlightTab(index, for: handle)
                self.actions[handle]?()
            })
            _ = strip.appendChild(tab)
            buttons.append(tab)
        }
        tabButtons[handle] = buttons
        highlightTab(selectedIndex, for: handle)
    }

    /// Draws which tab is current.
    internal func highlightTab(_ selectedIndex: Int, for handle: NativeHandle) {
        guard let buttons = tabButtons[handle] else { return }
        for (index, tab) in buttons.enumerated() {
            let isSelected = index == selectedIndex
            _ = tab
                .setStyle("background", isSelected ? "#ffffff" : "#e4e4e4")
                .setStyle("font-weight", isSelected ? "600" : "400")
        }
    }

    /// Builds a scroller as a range input in the requested orientation.
    internal func makeScroller(_ handle: NativeHandle, value: Double, isVertical: Bool,
                               frame: NSRect, parent: NativeHandle?) {
        let input = position(Element.input(), in: frame)
        _ = input.setAttribute("type", "range")
        applySliderRange(input, minValue: 0, maxValue: 1)
        input.value = "\(value)"
        if isVertical {
            _ = input.setStyle("writing-mode", "vertical-lr").setStyle("direction", "rtl")
        }
        inputElements[handle] = input
        register(handle, element: input, parent: parent)
    }

    /// Builds a date picker as `<input type=datetime-local>`.
    internal func makeDatePicker(_ handle: NativeHandle,
                                 configuration: NativeDatePickerConfiguration,
                                 frame: NSRect, parent: NativeHandle?) {
        let input = position(Element.input(), in: frame)
            .setStyle("font", "13px system-ui, sans-serif")
        _ = input.setAttribute("type", "datetime-local")
        if let minDate = configuration.minDate {
            _ = input.setAttribute("min", Self.localDateTimeString(minDate))
        }
        if let maxDate = configuration.maxDate {
            _ = input.setAttribute("max", Self.localDateTimeString(maxDate))
        }
        input.value = Self.localDateTimeString(configuration.date)
        inputElements[handle] = input
        register(handle, element: input, parent: parent)
    }

    /// Formats a date as `yyyy-MM-ddTHH:mm`, the only format the control takes.
    ///
    /// Computed rather than formatted: `DateFormatter` drags a large slice of
    /// ICU into a wasm binary that is already 78 MB, and the civil-date
    /// conversion is a dozen lines of arithmetic that cannot vary by locale —
    /// which is what this control wants, since the format is fixed by HTML.
    /// Howard Hinnant's `civil_from_days`, in Swift.
    internal static func localDateTimeString(_ date: Date) -> String {
        let total = Int(date.timeIntervalSince1970.rounded(.down))
        var days = total / 86_400
        var secondsOfDay = total % 86_400
        if secondsOfDay < 0 {
            secondsOfDay += 86_400
            days -= 1
        }

        let shifted = days + 719_468
        let era = (shifted >= 0 ? shifted : shifted - 146_096) / 146_097
        let dayOfEra = shifted - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1_460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let monthPrime = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * monthPrime + 2) / 5 + 1
        let month = monthPrime + (monthPrime < 10 ? 3 : -9)
        let year = yearOfEra + era * 400 + (month <= 2 ? 1 : 0)

        func pad(_ value: Int, _ width: Int) -> String {
            let text = String(value)
            return text.count >= width ? text : String(repeating: "0", count: width - text.count) + text
        }

        return "\(pad(year, 4))-\(pad(month, 2))-\(pad(day, 2))T"
            + "\(pad(secondsOfDay / 3_600, 2)):\(pad(secondsOfDay % 3_600 / 60, 2))"
    }
}

#endif
