#if canImport(CGTK)
import CGTK
import CGTKCompat
import Foundation

extension GTKNativeControlBackend {
    public func setButtonState(_ on: Bool, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_check_button_set_active(asCheckButton(w), gboolean(on ? 1 : 0))
    }
    /// Updates a slider/progress/stepper/level's numeric value, dispatched by kind.
    public func setDoubleValue(_ value: Double, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        switch kinds[handle.rawValue] {
        case .slider:
            gtk_range_set_value(asRange(w), value)
        case .progress:
            guard !indeterminateProgress.contains(handle.rawValue) else { break }
            let (lo, hi) = ranges[handle.rawValue] ?? (0, 1)
            let fraction = hi > lo ? (value - lo) / (hi - lo) : 0
            gtk_progress_bar_set_fraction(w, min(1, max(0, fraction)))   // GtkProgressBar is opaque
        case .stepper:
            // Arrows only — nothing to display; the value lives in the app's
            // own field, exactly as AppKit's NSStepper works.
            stepperValues[handle.rawValue] = value
        case .level:
            levelValues[handle.rawValue] = value
            buildLevelContent(handle.rawValue)
        default: break
        }
    }
    /// Sets the selected index for pop-ups, tabs, segments, tables, outlines, and collections.
    public func setSelectedIndex(_ index: Int, for handle: NativeHandle) {
        guard let w = widget(handle), index >= 0 else { return }
        switch kinds[handle.rawValue] {
        case .tabView: gtk_notebook_set_current_page(w, gint(index))   // GtkNotebook is opaque
        case .segmented:
            guard let buttons = segmentButtons[handle.rawValue], index < buttons.count else { return }
            gtk_toggle_button_set_active(asToggle(buttons[index]), gboolean(1))
        case .table, .outline, .collection:
            guard let selection = tableSelections[handle.rawValue] else { return }
            gtk_single_selection_set_selected(selection, guint(index))
        default:       gtk_drop_down_set_selected(w, guint(index))     // GtkDropDown is opaque
        }
    }
    /// Reorients a `GtkScale` slider (AppKit's vertical minimum is at the bottom, so the range is inverted).
    /// Performs the `setSliderTickMarks` operation.
    public func setSliderTickMarks(count: Int, snapsToTicks: Bool, for handle: NativeHandle) {
        guard let w = widget(handle), kinds[handle.rawValue] == .slider else { return }
        let scale = UnsafeMutablePointer<GtkScale>(w)
        gtk_scale_clear_marks(scale)
        sliderSnapTicks[handle.rawValue] = nil
        guard count >= 2, let (lo, hi) = ranges[handle.rawValue], hi > lo else { return }
        // GtkScale draws a mark per position, the direct analog of AppKit's
        // evenly spaced tick marks. Position BOTTOM is GTK's "trailing side",
        // which is the right of a vertical scale and below a horizontal one —
        // where AppKit puts them by default.
        for index in 0..<count {
            let value = lo + (hi - lo) * Double(index) / Double(count - 1)
            gtk_scale_add_mark(scale, value, GTK_POS_BOTTOM, nil)
        }
        if snapsToTicks { sliderSnapTicks[handle.rawValue] = count }
    }
    /// Rounds a slider's value to its nearest tick, for
    /// `allowsTickMarkValuesOnly`. Returns the snapped value.
    func snapSliderValue(_ raw: UInt, _ value: Double) -> Double {
        guard let count = sliderSnapTicks[raw], count >= 2,
              let (lo, hi) = ranges[raw], hi > lo else { return value }
        let step = (hi - lo) / Double(count - 1)
        return lo + (step * ((value - lo) / step).rounded())
    }
    /// Performs the `setSliderVertical` operation.
    public func setSliderVertical(_ vertical: Bool, for handle: NativeHandle) {
        guard let w = widget(handle), kinds[handle.rawValue] == .slider else { return }
        gtk_orientable_set_orientation(
            w, vertical ? GTK_ORIENTATION_VERTICAL : GTK_ORIENTATION_HORIZONTAL)
        // AppKit's vertical slider puts the minimum at the bottom; GtkScale's
        // vertical default puts it at the top, so invert to match.
        gtk_range_set_inverted(asRange(w), gboolean(vertical ? 1 : 0))
    }
    /// Replaces the drop-down's model with a fresh `GtkStringList` and selects `selectedIndex`.
    public func setPopUpItems(_ titles: [String], selectedIndex: Int, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        // Rebuild the drop-down's model from a fresh GtkStringList.
        let list = gtk_string_list_new(nil)!
        for title in titles { gtk_string_list_append(list, title) }
        gtk_drop_down_set_model(w, list)
        if selectedIndex >= 0, selectedIndex < titles.count {
            gtk_drop_down_set_selected(w, guint(selectedIndex))
        }
    }
    /// Updates the graphical picker's `GtkCalendar` (compact text is set separately via `setDatePickerText`).
    public func setDateValue(_ date: Date, for handle: NativeHandle) {
        let raw = handle.rawValue
        dateValues[raw] = date
        guard widget(handle) != nil else { return }
        // GtkCalendar navigates via a GDateTime; unix-local keeps Date exact.
        guard let gdt = g_date_time_new_from_unix_local(gint64(date.timeIntervalSince1970)) else { return }
        if graphicalDatePickers.contains(raw), let calendar = graphicalCalendars[raw] {
            // Selecting a day re-emits day-selected; that is us, not the user.
            suppressCalendarReport.insert(raw)
            gtk_calendar_select_day(calendar, gdt)
            suppressCalendarReport.remove(raw)
        }
        // The compact style's (and clockAndCalendar's time row's) text arrives
        // through setDatePickerText: formatting
        // needs the locale, calendar and element flags, which are AppKit's to
        // decide, not the backend's.
        g_date_time_unref(gdt)
    }
    /// Sets a `GtkColorButton`'s color via `GtkColorChooser`.
    public func setColor(_ color: NSColor, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        var rgba = GdkRGBA(
            red: Float(color.redComponent), green: Float(color.greenComponent),
            blue: Float(color.blueComponent), alpha: Float(color.alphaComponent)
        )
        lc_color_chooser_set_rgba(asWidget(w), &rgba)
    }
    /// Destroys the widget (windows only) and forgets its bookkeeping.
    public func destroyControl(_ handle: NativeHandle) {
        let r = handle.rawValue
        if kinds[r] == .window, let w = widgets[r] {
            gtk_window_destroy(asWindow(w))
        }
        forgetDestroyedWindow(r)
    }

    /// Drops bookkeeping for a GtkWindow whose native surface is already gone.
    internal func forgetDestroyedWindow(_ raw: UInt) {
        primaryWindows.remove(raw)
        windowBoxes[raw] = nil
        windowContents[raw] = nil
        windowMenuBars[raw] = nil
        windowToolbars[raw] = nil
        windowToolbarViews[raw] = nil
        presentedWindows.remove(raw)
        windowCloseActions[raw] = nil
        windowShouldCloseHandlers[raw] = nil
        actionSignalHandlers[raw] = nil
        widgets[raw] = nil
        kinds[raw] = nil
        frames[raw] = nil
        parents[raw] = nil
    }

    // MARK: Events
    /// Wires the widget's `clicked` signal to `action`.
    public func registerAction(for handle: NativeHandle, action: @escaping () -> Void) {
        // AppKit puts target/action on `NSControl`, so the shared core registers
        // one for EVERY control — label, slider, progress bar and all. GTK has
        // no such universal signal: "clicked" belongs to GtkButton alone, and
        // connecting it to a GtkDropDown or GtkLabel logs
        // `signal 'clicked' is invalid for instance …` and then walks off the
        // end of the signal table. So each kind gets the signal it actually
        // has, and kinds with no activation signal get none.
        if registerComboAction(for: handle, action: action) { return }
        if registerSelectionAction(for: handle, action: action) { return }
        if registerValueAction(for: handle, action: action) { return }
        if registerClickAction(for: handle, action: action) { return }
        guard let signal = directActionSignal(for: handle) else { return }
        guard let w = widget(handle) else { return }
        connectActionSignal(signal, widget: w, handle: handle, action: action)
    }

    internal func directActionSignal(for handle: NativeHandle) -> String? {
        switch kinds[handle.rawValue] {
        case .button: return "clicked"
        case .checkbox, .radio: return "toggled"
        case .textField, .secureField, .searchField: return "activate"
        case .slider: return "value-changed"
        default: return nil
        }
    }

    internal func registerComboAction(for handle: NativeHandle, action: @escaping () -> Void) -> Bool {
        guard kinds[handle.rawValue] == .comboBox, let entry = comboEntries[handle.rawValue] else { return false }
        connectActionSignal("activate", widget: entry, handle: handle, action: action)
        return true
    }

    internal func registerSelectionAction(for handle: NativeHandle, action: @escaping () -> Void) -> Bool {
        switch kinds[handle.rawValue] {
        case .popUp, .segmented, .tabView:
            setSelectionChangeAction(for: handle) { _ in action() }
        case .table, .outline, .collection:
            setSelectionChangeAction(for: handle) { [weak self] row in
                self?.coreSeam.tableSelection[handle.rawValue] = row >= 0 ? [row] : []
                self?.coreSeam.tableClickedRow[handle.rawValue] = row
                action()
            }
        default: return false
        }
        return true
    }

    internal func registerValueAction(for handle: NativeHandle, action: @escaping () -> Void) -> Bool {
        switch kinds[handle.rawValue] {
        case .datePicker: setDateChangeAction(for: handle) { _ in action() }
        case .stepper: setValueChangeAction(for: handle) { _ in action() }
        case .level: setLevelChangeAction(for: handle) { _ in action() }
        case .colorWell: setColorChangeAction(for: handle) { _ in action() }
        case .tokenField: setTokensChangeAction(for: handle) { _ in action() }
        case .scroller: setScrollerAction(for: handle) { _ in action() }
        default: return false
        }
        return true
    }

    internal func registerClickAction(for handle: NativeHandle, action: @escaping () -> Void) -> Bool {
        switch kinds[handle.rawValue] {
        case .label, .imageView, .view, .box:
            setClickAction(for: handle) { _, _ in action() }
            return true
        default: return false
        }
    }

    internal func connectActionSignal(
        _ signal: String,
        widget: OpaquePointer,
        handle: NativeHandle,
        action: @escaping () -> Void
    ) {
        if let previous = actionSignalHandlers[handle.rawValue] {
            g_signal_handler_disconnect(UnsafeMutableRawPointer(previous.widget), previous.id)
        }
        let box = ActionBox(action)
        let handlerID = g_signal_connect_data(
            UnsafeMutableRawPointer(widget), signal,
            unsafeBitCast(gtkActionTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        actionSignalHandlers[handle.rawValue] = (widget, handlerID)
    }
    /// Wires a `GtkEntry`'s `activate` signal (Enter pressed) to `action`.
    public func setSubmitAction(for handle: NativeHandle, action: @escaping () -> Void) {
        guard let w = widget(handle) else { return }
        // GtkEntry emits "activate" on Enter — AppKit's text-field action.
        let box = ActionBox(action)
        g_signal_connect_data(
            UnsafeMutableRawPointer(w), "activate",
            unsafeBitCast(gtkActionTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }

    /// Wires text-change signals (text buffer `changed` or editable `changed`, depending on kind) to `action`.
    public func setTextChangeAction(for handle: NativeHandle, action: @escaping (String) -> Void) {
        let box = StringActionBox(action)
        // A text view's changes come from its GtkTextBuffer, which reads back
        // differently from a GtkEditable, so it uses its own trampoline.
        if kinds[handle.rawValue] == .textView, let w = widget(handle) {
            let buffer = gtk_text_view_get_buffer(asTextView(w))
            g_signal_connect_data(
                UnsafeMutableRawPointer(buffer), "changed",
                unsafeBitCast(gtkTextBufferChangedTrampoline, to: GCallback.self),
                Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
            return
        }
        // "changed" is GtkEditable's. A label has no editable text, and the
        // core asks every text-ish control for change notifications, so only
        // the kinds that really are editable get connected.
        switch kinds[handle.rawValue] {
        case .textField, .secureField, .searchField, .comboBox, .tokenField:
            break
        default:
            return
        }
        // A combo emits text changes on its internal entry, not the combo itself.
        let target = (kinds[handle.rawValue] == .comboBox) ? comboEntries[handle.rawValue] : widget(handle)
        guard let w = target else { return }
        g_signal_connect_data(
            UnsafeMutableRawPointer(w), "changed",
            unsafeBitCast(gtkTextChangedTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }
    /// Wires a check button's `toggled` signal to `action`, passing the new active state.
    public func setToggleAction(for handle: NativeHandle, action: @escaping (Bool) -> Void) {
        guard let w = widget(handle) else { return }
        let box = BoolActionBox(action)
        g_signal_connect_data(
            UnsafeMutableRawPointer(w), "toggled",
            unsafeBitCast(gtkToggledTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }
    /// Wires a slider/level's `value-changed` signal to `action`, or records it for the stepper.
    public func setValueChangeAction(for handle: NativeHandle, action: @escaping (Double) -> Void) {
        guard let w = widget(handle) else { return }
        let box = DoubleActionBox(action)
        // A stepper is our own arrow buttons, not a GtkRange, so it has no
        // "value-changed" to connect to: `stepStepper` reports directly.
        if kinds[handle.rawValue] == .stepper {
            valueChangeActions[handle.rawValue] = action
            return
        }
        if kinds[handle.rawValue] == .slider {
            // A slider may snap to its tick marks, which means rewriting the
            // value before reporting it — that needs the backend and handle, so
            // it gets its own box and trampoline.
            let sliderBox = SliderValueBox(backend: self, raw: handle.rawValue, action: action)
            g_signal_connect_data(
                UnsafeMutableRawPointer(w), "value-changed",
                unsafeBitCast(gtkSliderValueChangedTrampoline, to: GCallback.self),
                Unmanaged.passRetained(sliderBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
            return
        }
        let trampoline = gtkValueChangedTrampoline
        g_signal_connect_data(
            UnsafeMutableRawPointer(w), "value-changed",
            unsafeBitCast(trampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }
    /// Reports a slider's new value, snapping it to the tick marks first when
    /// `allowsTickMarkValuesOnly` is set (AppKit snaps the knob itself, so the
    /// control is moved too — guarded against the re-entrant value-changed).
    internal func reportSliderValue(_ raw: UInt, action: (Double) -> Void) {
        guard !suppressSliderReport.contains(raw), let w = widgets[raw] else { return }
        let value = gtk_range_get_value(asRange(w))
        let snapped = snapSliderValue(raw, value)
        if snapped != value {
            suppressSliderReport.insert(raw)
            gtk_range_set_value(asRange(w), snapped)
            suppressSliderReport.remove(raw)
        }
        action(snapped)
    }
    /// Wires selection-change signals for pop-ups, tabs, tables, outlines, segments, and collections.
}

#endif
