#if canImport(CGTK)
import CGTK
import CGTKCompat
import Foundation

extension GTKNativeControlBackend {
    public func setProgressAnimating(_ animating: Bool, for handle: NativeHandle) {
        let raw = handle.rawValue
        if progressSpinners.contains(raw) {
            if animating {
                spinnerAnimating.insert(raw)
                guard spinnerSources[raw] == nil else { return }
                // ~12.5 fps advances the bright spoke → a full turn every ~1s.
                let box = SpinnerDrawBox(backend: self, raw: raw)
                let id = g_timeout_add(guint(80), { userData in
                    guard let userData else { return gboolean(0) }
                    let box = Unmanaged<SpinnerDrawBox>.fromOpaque(userData).takeUnretainedValue()
                    return gboolean(box.backend?.tickSpinner(box.raw) == true ? 1 : 0)
                }, Unmanaged.passRetained(box).toOpaque())
                spinnerSources[raw] = id
            } else {
                stopSpinnerAnimation(raw)
            }
            return
        }
        // Only an indeterminate bar animates — AppKit's `startAnimation` on a
        // determinate bar is a no-op.
        guard animating, indeterminateProgress.contains(raw) else { stopProgressPulse(raw); return }
        guard progressPulseSources[raw] == nil, let w = widgets[raw] else { return }
        gtk_progress_bar_set_pulse_step(w, 0.12)
        gtk_progress_bar_pulse(w)
        // GtkProgressBar's "pulse" moves a block back and forth — the GTK
        // analog of AppKit's barber-pole indeterminate bar. ~25×/s reads as a
        // brisk barber-pole (AppKit's is fast).
        let box = ActionBox { [weak self] in
            guard let self, let w = self.widgets[raw] else { return }
            gtk_progress_bar_pulse(w)
        }
        let id = g_timeout_add(guint(40), { userData in
            guard let userData else { return gboolean(0) }
            Unmanaged<ActionBox>.fromOpaque(userData).takeUnretainedValue().action()
            return gboolean(1)   // keep pulsing
        }, Unmanaged.passRetained(box).toOpaque())
        progressPulseSources[raw] = id
    }

    internal func stopProgressPulse(_ raw: UInt) {
        if let id = progressPulseSources.removeValue(forKey: raw) {
            g_source_remove(id)
            if let w = widgets[raw] { gtk_progress_bar_set_fraction(w, 0) }
        }
    }
    /// Creates a `GtkDropDown` populated from `items`.
    public func createPopUpButton(items: [String], selectedIndex: Int, frame: NSRect) -> NativeHandle {
        // gtk_drop_down_new_from_strings takes a NULL-terminated C string array;
        // it copies the strings, so the temporaries are freed right after.
        var cStrings: [UnsafePointer<CChar>?] = items.map { UnsafePointer(strdup($0)) }
        cStrings.append(nil)
        let widget = cStrings.withUnsafeBufferPointer { gtk_drop_down_new_from_strings($0.baseAddress) }!
        for s in cStrings where s != nil { free(UnsafeMutableRawPointer(mutating: s)) }
        if selectedIndex >= 0 { gtk_drop_down_set_selected(OpaquePointer(widget), guint(selectedIndex)) }
        gtk_widget_set_size_request(widget, Int32(frame.width), Int32(frame.height))
        stripPopoverArrows(of: widget)
        return allocate(widget, .popUp, frame: frame)
    }

    /// On non-composited displays a popover's pointing arrow renders as a black
    /// bar (its tail geometry is compiled into GTK — CSS cannot remove it), so
    /// walk `widget`'s children and disable the arrow on any internal popover.
    internal func stripPopoverArrows(of widget: UnsafeMutablePointer<GtkWidget>) {
        guard nonComposited else { return }
        var child = gtk_widget_get_first_child(widget)
        while let c = child {
            let typeName = String(cString: g_type_name_from_instance(
                UnsafeMutableRawPointer(c).assumingMemoryBound(to: GTypeInstance.self)))
            if typeName == "GtkPopover" {
                gtk_popover_set_has_arrow(UnsafeMutablePointer<GtkPopover>(OpaquePointer(c)), gboolean(0))
            }
            child = gtk_widget_get_next_sibling(c)
        }
    }
    /// AppKit's stepper: two arrow buttons **stacked, up above down** — the
    /// control Apple actually draws. Shared by `NSStepper` and
    /// `NSDatePicker`'s `.textFieldAndStepper` field, so there is one stepper.
    ///
    /// Built from buttons rather than a GtkSpinButton on purpose: a spin button
    /// bundles a text entry, which forces a ~120px minimum (it overran and
    /// covered its own value label), stacks its buttons side by side, and can't
    /// be talked out of either.
    internal func makeStepperArrows(onStep: @escaping (Int) -> Void) -> UnsafeMutablePointer<GtkWidget> {
        let arrows = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        gtk_widget_add_css_class(arrows, "linked")
        gtk_widget_add_css_class(arrows, "linchocolate-stepper")
        for (icon, direction) in [("pan-up-symbolic", 1), ("pan-down-symbolic", -1)] {
            let button = gtk_button_new_from_icon_name(icon)!
            gtk_widget_set_vexpand(button, gboolean(1))
            let action = ActionBox { onStep(direction) }
            g_signal_connect_data(
                UnsafeMutableRawPointer(button), "clicked",
                unsafeBitCast(gtkActionTrampoline, to: GCallback.self),
                Unmanaged.passRetained(action).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
            gtk_box_append(asBox(OpaquePointer(arrows)), button)
        }
        return arrows
    }

    /// Steps a stepper's value by one increment, clamped to its range, and
    /// reports it — AppKit's NSStepper increments and sends its action.
    internal func stepStepper(_ raw: UInt, by direction: Int) {
        guard let current = stepperValues[raw] else { return }
        let step = stepperSteps[raw] ?? 1
        let (lo, hi) = ranges[raw] ?? (0, 100)
        let stepped = Swift.min(Swift.max(current + Double(direction) * step, lo), hi)
        guard stepped != current else { return }
        stepperValues[raw] = stepped
        valueChangeActions[raw]?(stepped)
    }

    /// Creates a stepper as a stacked pair of arrow `GtkButton`s over `[minValue, maxValue]`.
    public func createStepper(value: Double, minValue: Double, maxValue: Double, stepSize: Double, frame: NSRect) -> NativeHandle {
        // The arrows' handler needs the handle, which `allocate` only hands back
        // after the widget exists; the closure captures `raw` by reference and
        // cannot run before then (it takes a click).
        var raw: UInt = 0
        let arrows = makeStepperArrows { [weak self] direction in
            self?.stepStepper(raw, by: direction)
        }
        gtk_widget_set_size_request(arrows, Int32(frame.width), Int32(frame.height))
        let h = allocate(arrows, .stepper, frame: frame)
        raw = h.rawValue
        ranges[raw] = (minValue, maxValue)
        stepperSteps[raw] = stepSize == 0 ? 1 : stepSize
        stepperValues[raw] = value
        return h
    }
    /// A standalone GtkScrollbar. `NSScroller` used directly (not as an
    /// NSScrollView's bar) previously fell through to `NSView`'s initializer and
    /// became an empty container — it simply never appeared.
    public func createScroller(vertical: Bool, frame: NSRect) -> NativeHandle {
        // AppKit's value/knobProportion are both 0...1 fractions. A GtkAdjustment
        // instead runs its value over [lower, upper - page_size], so with
        // upper = 1 and page_size = knobProportion the knob length is the
        // proportion and the value spans [0, 1 - proportion]; see scrollerValue().
        let adjustment = gtk_adjustment_new(0, 0, 1, 0.05, 0.25, 0.25)
        let bar = gtk_scrollbar_new(vertical ? GTK_ORIENTATION_VERTICAL : GTK_ORIENTATION_HORIZONTAL,
                                    adjustment)!
        gtk_widget_set_size_request(bar, Int32(frame.width), Int32(frame.height))
        // AppKit's NSScroller starts disabled — verified by probing real AppKit
        // (isEnabled == false, usableParts == .noScrollerParts) — so nothing is
        // draggable until the app enables it.
        gtk_widget_set_sensitive(bar, gboolean(0))
        let h = allocate(bar, .scroller, frame: frame)
        scrollerAdjustments[h.rawValue] = adjustment
        return h
    }

    /// The AppKit 0...1 value for a scroller's current adjustment.
    internal func scrollerValue(_ raw: UInt) -> Double {
        guard let adjustment = scrollerAdjustments[raw] else { return 0 }
        let span = gtk_adjustment_get_upper(adjustment) - gtk_adjustment_get_page_size(adjustment)
        return span > 0 ? gtk_adjustment_get_value(adjustment) / span : 0
    }

    /// Sets a standalone scroller's `GtkAdjustment` to represent `(value, knobProportion)` in AppKit's 0...1 space.
    public func setScrollerGeometry(value: Double, knobProportion: Double, for handle: NativeHandle) {
        guard let adjustment = scrollerAdjustments[handle.rawValue] else { return }
        let proportion = Swift.min(1, Swift.max(0, knobProportion))
        // Setting the adjustment emits value-changed; that is us, not the user.
        suppressScrollerReport.insert(handle.rawValue)
        gtk_adjustment_set_page_size(adjustment, proportion)
        gtk_adjustment_set_upper(adjustment, 1)
        gtk_adjustment_set_value(adjustment, Swift.min(1, Swift.max(0, value)) * (1 - proportion))
        suppressScrollerReport.remove(handle.rawValue)
    }

    /// Wires user drags of a standalone scroller to `action`, ignoring programmatic changes.
    public func setScrollerAction(for handle: NativeHandle, action: @escaping (Double) -> Void) {
        guard let adjustment = scrollerAdjustments[handle.rawValue] else { return }
        scrollerActions[handle.rawValue] = action
        let box = ScrollerBox(backend: self, raw: handle.rawValue)
        g_signal_connect_data(
            UnsafeMutableRawPointer(adjustment), "value-changed",
            unsafeBitCast(gtkScrollerChangedTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }

    /// Reports a *user* drag. Programmatic geometry changes are suppressed, the
    /// same trap the date field hit: GTK can't tell us who moved the value.
    internal func reportScroller(_ raw: UInt) {
        guard !suppressScrollerReport.contains(raw) else { return }
        scrollerActions[raw]?(scrollerValue(raw))
    }

    /// Creates a level-indicator container whose content is rebuilt to match the current style.
    public func createLevelIndicator(value: Double, minValue: Double, maxValue: Double, frame: NSRect) -> NativeHandle {
        // A container, because the style decides the content: a capacity bar, or
        // a row of stars for .rating. AppKit's NSLevelIndicator is one control
        // that renders either.
        let box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
        gtk_widget_set_size_request(box, Int32(frame.width), Int32(frame.height))
        let h = allocate(box, .level, frame: frame)
        ranges[h.rawValue] = (minValue, maxValue)
        levelValues[h.rawValue] = value
        buildLevelContent(h.rawValue)
        return h
    }

    /// Sets the level-indicator style raw value and rebuilds its content.
    public func setLevelIndicatorStyle(_ rawValue: Int, for handle: NativeHandle) {
        levelStyles[handle.rawValue] = rawValue
        buildLevelContent(handle.rawValue)
    }

    /// Toggles whether the user can set the level by clicking, and rebuilds gestures.
    public func setLevelIndicatorEditable(_ editable: Bool, for handle: NativeHandle) {
        let raw = handle.rawValue
        guard levelEditable.contains(raw) != editable else { return }
        if editable { levelEditable.insert(raw) } else { levelEditable.remove(raw) }
        buildLevelContent(raw)
    }

    /// Sets the indicator's numeric range and rebuilds (for `.rating`, the span is the star count).
    public func setLevelIndicatorRange(min: Double, max: Double, for handle: NativeHandle) {
        ranges[handle.rawValue] = (min, max)
        buildLevelContent(handle.rawValue)      // the span is the star count
    }

    /// Sets the warning and critical thresholds and rebuilds the coloured fill.
    public func setLevelThresholds(warning: Double, critical: Double, for handle: NativeHandle) {
        levelThresholds[handle.rawValue] = (warning, critical)
        buildLevelContent(handle.rawValue)
    }

    /// Registers the level-change action fired by user interaction with an editable indicator.
    public func setLevelChangeAction(for handle: NativeHandle, action: @escaping (Double) -> Void) {
        levelChangeActions[handle.rawValue] = action
    }

    /// Renders a level indicator for its current style: a row of stars for
    /// `.rating` (3), otherwise a capacity bar that turns warning/critical
    /// coloured past its thresholds, as AppKit's does.
    internal func buildLevelContent(_ raw: UInt) {
        guard let box = widgets[raw] else { return }
        while let child = gtk_widget_get_first_child(asWidget(box)) { gtk_widget_unparent(child) }
        let (lo, hi) = ranges[raw] ?? (0, 1)
        let value = levelValues[raw] ?? 0

        if levelStyles[raw] == NativeLevelIndicatorStyle.rating {
            guard Int((hi - lo).rounded()) > 0 else { return }
            // Stars are drawn, not taken from the icon theme: "starred-symbolic"
            // is absent on plenty of systems (it is not in this container's
            // Adwaita at all, and rendered as broken-image placeholders), and a
            // rating control should not change shape with the user's theme —
            // AppKit draws its own.
            let area = gtk_drawing_area_new()!
            gtk_widget_set_hexpand(area, gboolean(1))
            gtk_widget_set_vexpand(area, gboolean(1))
            let drawBox = LevelClickBox(backend: self, raw: raw)
            gtk_drawing_area_set_draw_func(
                UnsafeMutablePointer<GtkDrawingArea>(OpaquePointer(area)),
                gtkStarDrawFunc,
                Unmanaged.passRetained(drawBox).toOpaque(), boxDestroyNotify
            )
            gtk_box_append(asBox(box), area)
            attachLevelClickGesture(raw, to: box)
            return
        }

        let bar = gtk_progress_bar_new()!
        gtk_widget_set_hexpand(bar, gboolean(1))
        gtk_widget_set_valign(bar, GTK_ALIGN_CENTER)
        let span = hi - lo
        gtk_progress_bar_set_fraction(OpaquePointer(bar), span > 0 ? Swift.min(1, Swift.max(0, (value - lo) / span)) : 0)
        // AppKit tints the fill once the level reaches warningValue, and again
        // at criticalValue.
        if let thresholds = levelThresholds[raw] {
            if thresholds.critical > 0 && value >= thresholds.critical {
                gtk_widget_add_css_class(bar, "linchocolate-level-critical")
            } else if thresholds.warning > 0 && value >= thresholds.warning {
                gtk_widget_add_css_class(bar, "linchocolate-level-warning")
            }
        }
        gtk_box_append(asBox(box), bar)
        attachLevelClickGesture(raw, to: box)
    }

    /// An editable indicator takes clicks in **any** style: AppKit lets you set
    /// a capacity bar's level by clicking it, not just a rating's stars.
}

#endif
