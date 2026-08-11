#if canImport(CGTK)
import CGTK
import CGTKCompat
import Foundation

extension GTKNativeControlBackend {
    internal func attachLevelClickGesture(_ raw: UInt, to box: OpaquePointer) {
        guard levelEditable.contains(raw), !levelClickGestures.contains(raw) else { return }
        let click = gtk_gesture_click_new()
        let clickBox = LevelClickBox(backend: self, raw: raw)
        g_signal_connect_data(
            UnsafeMutableRawPointer(click), "pressed",
            unsafeBitCast(gtkLevelClickTrampoline, to: GCallback.self),
            Unmanaged.passRetained(clickBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        gtk_widget_add_controller(asWidget(box), click)
        levelClickGestures.insert(raw)
    }

    /// Draws the rating's stars: filled up to the value, outlined beyond it.
    /// Advances the spinner's bright spoke and redraws. Returns whether the
    /// timeout should keep firing (`G_SOURCE_CONTINUE`).
    internal func tickSpinner(_ raw: UInt) -> Bool {
        guard spinnerAnimating.contains(raw), let w = widgets[raw] else { return false }
        spinnerPhase[raw] = (spinnerPhase[raw] ?? 0) + 1
        gtk_widget_queue_draw(asWidget(w))
        return true
    }

    /// Stops the rotation timeout; the spokes stay drawn at their current phase
    /// (AppKit's spinner stays visible when stopped — it just holds still).
    internal func stopSpinnerAnimation(_ raw: UInt) {
        spinnerAnimating.remove(raw)
        if let id = spinnerSources.removeValue(forKey: raw) { g_source_remove(id) }
    }

    /// Draws an AppKit-style spinning indicator: spokes radiating from the
    /// centre, the one at the current phase brightest and the rest fading
    /// behind it. Always drawn (visible whether or not it is animating).
    internal func drawSpinner(_ raw: UInt, cr: OpaquePointer, width: Double, height: Double) {
        guard width > 0, height > 0 else { return }
        let spokes = 12
        let cx = width / 2, cy = height / 2
        let radius = Swift.min(width, height) / 2
        let inner = radius * 0.42
        let outer = radius * 0.92
        let phase = ((spinnerPhase[raw] ?? 0) % spokes + spokes) % spokes
        cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND)
        cairo_set_line_width(cr, Swift.max(1.5, radius * 0.22))
        for i in 0..<spokes {
            // Distance behind the bright head, 0 (brightest) … spokes-1 (faintest).
            let behind = Double((phase - i + spokes) % spokes)
            let alpha = 0.15 + 0.85 * (1 - behind / Double(spokes))
            let angle = -Double.pi / 2 + Double(i) / Double(spokes) * 2 * Double.pi
            cairo_set_source_rgba(cr, 0.45, 0.45, 0.45, alpha)
            cairo_move_to(cr, cx + inner * cos(angle), cy + inner * sin(angle))
            cairo_line_to(cr, cx + outer * cos(angle), cy + outer * sin(angle))
            cairo_stroke(cr)
        }
    }

    internal func drawStars(_ raw: UInt, cr: OpaquePointer, width: Double, height: Double) {
        let (lo, hi) = ranges[raw] ?? (0, 5)
        let stars = Int((hi - lo).rounded())
        guard stars > 0, width > 0, height > 0 else { return }
        let value = levelValues[raw] ?? 0
        let slot = width / Double(stars)
        let radius = Swift.min(slot, height) * 0.42
        // AppKit's rating star is a fixed mid-gray in BOTH appearances (probed:
        // ~0.5, not appearance-inverted). The old 0.85 made dark-mode stars
        // near-white — nothing like the Mac's grey stars.
        let tone = 0.5
        for index in 0..<stars {
            appendStarPath(cr: cr, centreX: slot * (Double(index) + 0.5), centreY: height / 2, radius: radius)
            cairo_set_source_rgb(cr, tone, tone, tone)
            if Double(index) < (value - lo) {
                cairo_fill(cr)
            } else {
                cairo_set_line_width(cr, 1.2)
                cairo_stroke(cr)
            }
        }
    }

    /// A five-pointed star, outer points alternating with inner ones.
    internal func appendStarPath(cr: OpaquePointer, centreX: Double, centreY: Double, radius: Double) {
        for point in 0..<10 {
            let r = point % 2 == 0 ? radius : radius * 0.42
            let angle = -Double.pi / 2 + Double(point) * Double.pi / 5
            let x = centreX + r * cos(angle)
            let y = centreY + r * sin(angle)
            if point == 0 { cairo_move_to(cr, x, y) } else { cairo_line_to(cr, x, y) }
        }
        cairo_close_path(cr)
    }

    /// Reports the star a click landed on, as a level (AppKit sets the rating to
    /// the clicked star).
    internal func reportLevelClick(_ raw: UInt, x: Double) {
        guard levelEditable.contains(raw), let frame = frames[raw], frame.width > 0 else { return }
        let (lo, hi) = ranges[raw] ?? (0, 1)
        let value: Double
        if levelStyles[raw] == NativeLevelIndicatorStyle.rating {
            // A rating snaps to the star clicked.
            let stars = Int((hi - lo).rounded())
            guard stars > 0 else { return }
            let index = Swift.min(stars - 1, Swift.max(0, Int(x / (frame.width / Double(stars)))))
            value = lo + Double(index) + 1
        } else {
            // A capacity bar takes the level at the point clicked.
            value = lo + Swift.min(1, Swift.max(0, x / frame.width)) * (hi - lo)
        }
        levelValues[raw] = value
        buildLevelContent(raw)
        levelChangeActions[raw]?(value)
    }
    /// Creates a multi-line `GtkTextView` initialised with `text`.
    public func createTextView(text: String, frame: NSRect) -> NativeHandle {
        let tv = gtk_text_view_new()!
        let buffer = gtk_text_view_get_buffer(asTextView(OpaquePointer(tv)))
        gtk_text_buffer_set_text(buffer, text, -1)   // GtkTextBuffer is opaque
        gtk_widget_set_size_request(tv, Int32(frame.width), Int32(frame.height))
        return allocate(tv, .textView, frame: frame)
    }
    /// Creates the compact (.textFieldAndStepper) date picker: a `GtkEntry` and stacked stepper arrows in a `GtkBox`.
    public func createDatePicker(date: Date, frame: NSRect) -> NativeHandle {
        // AppKit's default style is .textFieldAndStepper — a compact field *with
        // a stepper*, not a full month grid. clockAndCalendar swaps in a
        // GtkCalendar via setDatePickerGraphical.
        guard let box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0) else {
            preconditionFailure("GTK failed to create a date-picker container")
        }
        let h = allocate(box, .datePicker, frame: frame)
        buildCompactDatePicker(raw: h.rawValue, frame: frame)
        setDateValue(date, for: h)
        return h
    }

    /// Fills a compact (.textFieldAndStepper) picker's box: the field, plus the
    /// stepper the style is named after. GTK has no date-field widget, so the
    /// stepper is a pair of arrows driving the value directly.
    internal func buildCompactDatePicker(raw: UInt, frame: NSRect) {
        guard let box = widgets[raw] else { return }
        while let child = gtk_widget_get_first_child(asWidget(box)) { gtk_widget_unparent(child) }
        gtk_widget_add_css_class(asWidget(box), "linked")
        gtk_box_append(asBox(box), makeDateEntryRow(raw: raw))
        gtk_widget_set_size_request(asWidget(box), Int32(frame.width), Int32(frame.height))
    }

    /// A date/time entry field plus the stacked stepper — the editable part of
    /// both `.textFieldAndStepper` (the whole control) and `.clockAndCalendar`
    /// (the time row beneath the calendar). The entry is stored in
    /// `datePickerEntries[raw]`, so the framework drives its text and selection
    /// through the same seam either way.
    internal func makeDateEntryRow(raw: UInt) -> UnsafeMutablePointer<GtkWidget> {
        let row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
        gtk_widget_add_css_class(row, "linked")

        let entry = gtk_entry_new()!
        gtk_widget_set_hexpand(entry, gboolean(1))
        // Not editable — the framework owns the text — but focusable, so typed
        // digits reach the selected element.
        gtk_editable_set_editable(OpaquePointer(entry), gboolean(0))
        gtk_widget_set_focusable(entry, gboolean(1))
        gtk_widget_set_can_focus(entry, gboolean(1))
        gtk_box_append(asBox(OpaquePointer(row)), entry)
        datePickerEntries[raw] = OpaquePointer(entry)

        // A click moves the cursor; that is how AppKit picks the element to edit.
        let cursorBox = DateCursorBox(backend: self, raw: raw)
        g_signal_connect_data(
            UnsafeMutableRawPointer(entry), "notify::cursor-position",
            unsafeBitCast(gtkDateCursorTrampoline, to: GCallback.self),
            Unmanaged.passRetained(cursorBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        let keys = gtk_event_controller_key_new()
        gtk_event_controller_set_propagation_phase(keys, GTK_PHASE_CAPTURE)
        let keyBox = DateCursorBox(backend: self, raw: raw)
        g_signal_connect_data(
            UnsafeMutableRawPointer(keys), "key-pressed",
            unsafeBitCast(gtkDateKeyTrampoline, to: GCallback.self),
            Unmanaged.passRetained(keyBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        gtk_widget_add_controller(entry, keys)

        // The same stacked arrows NSStepper uses; it reports only a direction —
        // which element moves is the framework's call (it tracks the selection).
        let arrows = makeStepperArrows { [weak self] direction in
            self?.dateStepActions[raw]?(direction)
        }
        gtk_box_append(asBox(OpaquePointer(row)), arrows)
        return row
    }

    /// Records the selectable date range (clamping is the framework's job).
    public func setDateRange(min: Date?, max: Date?, for handle: NativeHandle) {
        // Recorded for parity; the framework does the authoritative clamping
        // (minDate/maxDate are AppKit semantics, not GTK's).
        dateRanges[handle.rawValue] = (min, max)
    }

    /// Sets the compact field's rendered text, suppressing the resulting cursor callback.
    public func setDatePickerText(_ text: String, for handle: NativeHandle) {
        guard let entry = datePickerEntries[handle.rawValue] else { return }
        guard String(cString: gtk_editable_get_text(entry)) != text else { return }
        suppressCursorReport.insert(handle.rawValue)
        gtk_editable_set_text(entry, text)
        suppressCursorReport.remove(handle.rawValue)
    }

    /// Highlights the selected element in the compact field.
    public func setDatePickerSelection(location: Int, length: Int, for handle: NativeHandle) {
        guard let entry = datePickerEntries[handle.rawValue] else { return }
        // Selecting moves the cursor, which would re-enter the cursor handler
        // and fight the framework for the selection.
        suppressCursorReport.insert(handle.rawValue)
        gtk_editable_select_region(entry, gint(location), gint(location + length))
        suppressCursorReport.remove(handle.rawValue)
    }

    /// Registers the stepper-direction action for a date picker.
    public func setDateStepAction(for handle: NativeHandle, action: @escaping (Int) -> Void) {
        dateStepActions[handle.rawValue] = action
    }

    /// Registers the click-position action for a compact date picker.
    public func setDatePickerCursorAction(for handle: NativeHandle, action: @escaping (Int) -> Void) {
        dateCursorActions[handle.rawValue] = action
    }

    /// Registers the left/right-arrow action for a compact date picker.
    public func setDatePickerMoveAction(for handle: NativeHandle, action: @escaping (Int) -> Void) {
        dateMoveActions[handle.rawValue] = action
    }

    /// Registers the character-typed action for a compact date picker.
    public func setDatePickerTypeAction(for handle: NativeHandle, action: @escaping (String) -> Void) {
        dateTypeActions[handle.rawValue] = action
    }

    /// Reports a click's character offset so the framework can select that
    /// element. Ignored while we are the ones moving the cursor.
    internal func reportDateCursor(_ raw: UInt) {
        if ProcessInfo.processInfo.environment["LINCHOCOLATE_DATE_DEBUG"] != nil {
            let pos = datePickerEntries[raw].map { Int(gtk_editable_get_position($0)) } ?? -1
            let suppressed = suppressCursorReport.contains(raw)
            FileHandle.standardError.write(Data("cursor-notify pos=\(pos) suppressed=\(suppressed)\n".utf8))
        }
        guard !suppressCursorReport.contains(raw), let entry = datePickerEntries[raw] else { return }
        dateCursorActions[raw]?(Int(gtk_editable_get_position(entry)))
    }

    /// AppKit's keyboard for a date field: left/right move the selected
    /// element, up/down step it, and digits (or "a"/"p") *type* into it.
    ///
    /// Returning true stops the key here. That matters: this controller runs in
    /// the capture phase, so left/right would otherwise reach the entry's
    /// GtkText and move its cursor, fighting the framework for the selection.
    internal func reportDateKey(_ raw: UInt, keyval: guint) -> Bool {
        switch keyval {
        case guint(GDK_KEY_Left):  dateMoveActions[raw]?(-1); return true
        case guint(GDK_KEY_Right): dateMoveActions[raw]?(1);  return true
        case guint(GDK_KEY_Up):    dateStepActions[raw]?(1);  return true
        case guint(GDK_KEY_Down):  dateStepActions[raw]?(-1); return true
        default: break
        }
        let unicode = gdk_keyval_to_unicode(keyval)
        guard unicode != 0, let scalar = Unicode.Scalar(unicode) else { return false }
        let character = Character(scalar)
        guard character.isNumber || character.lowercased() == "a" || character.lowercased() == "p" else {
            return false
        }
        dateTypeActions[raw]?(String(character))
        return true
    }

    /// Swaps the widget for a new button/check button matching `kind`, preserving frame.
    public func setButtonKind(_ kind: NativeButtonKind, title: String, for handle: NativeHandle) {
        let raw = handle.rawValue
        guard let old = widgets[raw] else { return }
        let frame = frames[raw] ?? .zero
        if gtk_widget_get_parent(asWidget(old)) != nil { gtk_widget_unparent(asWidget(old)) }
        let new: UnsafeMutablePointer<GtkWidget>
        switch kind {
        case .push:     new = gtk_button_new_with_label(title)!;       kinds[raw] = .button
        case .checkbox: new = gtk_check_button_new_with_label(title)!; kinds[raw] = .checkbox
        case .radio:    new = gtk_check_button_new_with_label(title)!; kinds[raw] = .radio
        }
        gtk_widget_set_size_request(new, Int32(frame.width), Int32(frame.height))
        widgets[raw] = OpaquePointer(new)
        g_object_ref_sink(UnsafeMutableRawPointer(old))
        g_object_unref(UnsafeMutableRawPointer(old))
    }
    /// Swaps between the compact stepper picker and a graphical `GtkCalendar` (with time row).
    public func setDatePickerGraphical(_ graphical: Bool, for handle: NativeHandle) {
        let raw = handle.rawValue
        guard graphical != graphicalDatePickers.contains(raw), let old = widgets[raw] else { return }
        let frame = frames[raw] ?? .zero
        if gtk_widget_get_parent(asWidget(old)) != nil { gtk_widget_unparent(asWidget(old)) }
        let new: UnsafeMutablePointer<GtkWidget>
        if graphical {
            // AppKit's .clockAndCalendar shows a month grid AND a time editor
            // (an analog clock on macOS). Here: the calendar for the date, and a
            // compact time field with a stepper below it — the same type-to-edit
            // field the .textFieldAndStepper style uses, so the time can be
            // typed or stepped, which is the functionality that was missing.
            let column = gtk_box_new(GTK_ORIENTATION_VERTICAL, 4)!
            let calendar = gtk_calendar_new()!
            gtk_widget_set_vexpand(calendar, gboolean(1))
            gtk_box_append(asBox(OpaquePointer(column)), calendar)
            graphicalCalendars[raw] = OpaquePointer(calendar)

            let timeRow = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
            gtk_widget_set_halign(timeRow, GTK_ALIGN_CENTER)
            gtk_box_append(asBox(OpaquePointer(timeRow)), makeDateEntryRow(raw: raw))
            gtk_box_append(asBox(OpaquePointer(column)), timeRow)

            new = column
            graphicalDatePickers.insert(raw)
            gtk_widget_set_size_request(new, Int32(frame.width), Int32(frame.height))
            widgets[raw] = OpaquePointer(new)
        } else {
            new = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
            graphicalDatePickers.remove(raw)
            graphicalCalendars[raw] = nil
            widgets[raw] = OpaquePointer(new)
            buildCompactDatePicker(raw: raw, frame: frame)   // field *and* stepper
        }
        // Free the discarded (still-floating, unparented) widget.
        g_object_ref_sink(UnsafeMutableRawPointer(old))
        g_object_unref(UnsafeMutableRawPointer(old))
        // The swap replaced the widget, so re-apply the value and re-attach the
        // change action — both were bound to the widget we just discarded.
        if let date = dateValues[raw] { setDateValue(date, for: handle) }
        if let action = dateChangeActions[raw] { attachDateChangeAction(action, to: handle) }
    }
    /// Creates a `GtkColorButton` (via `GtkColorChooser`) initialised to `color`.
}

#endif
