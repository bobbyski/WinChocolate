#if canImport(CGTK)
import CGTK
import CGTKCompat
import Foundation

extension GTKNativeControlBackend {

    // MARK: Setters the core spells differently

    /// Sets the checkbox/radio state. AppKit's `.mixed` has no GTK equivalent
    /// on a plain check button, so it reads as on.
    ///
    /// AppKit puts `state` on every `NSButton`, including push buttons; GTK's
    /// active flag belongs to `GtkCheckButton` alone, and handing it anything
    /// else trips `GTK_IS_CHECK_BUTTON`. So the state only lands on the kinds
    /// that have one.
    public func setButtonState(_ state: NSControl.StateValue, for handle: NativeHandle) {
        switch kinds[handle.rawValue] {
        case .checkbox, .radio: setButtonState(state != .off, for: handle)
        default: break
        }
    }

    /// Sets the slider value.
    public func setSliderValue(_ value: Double, for handle: NativeHandle) {
        setDoubleValue(value, for: handle)
    }

    /// Sets the slider's range.
    public func setSliderRange(minValue: Double, maxValue: Double, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_range_set_range(asRange(w), minValue, maxValue)
    }

    /// Sets the slider's tick count, leaving snapping off.
    public func setSliderTickMarks(count: Int, for handle: NativeHandle) {
        setSliderTickMarks(count: count, snapsToTicks: false, for: handle)
    }

    /// Sets which side of the slider track the ticks are drawn on.
    public func setSliderTickMarkPosition(aboveOrLeading: Bool, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_scale_set_value_pos(UnsafeMutablePointer<GtkScale>(w), aboveOrLeading ? GTK_POS_TOP : GTK_POS_BOTTOM)
    }

    /// Sets the stepper value.
    public func setStepperValue(_ value: Double, for handle: NativeHandle) {
        setDoubleValue(value, for: handle)
    }

    /// Sets the stepper's range and step.
    ///
    /// AppKit's stepper is the bare pair of arrows, with the value shown in a
    /// separate text field, so this backend builds it from two buttons and
    /// keeps the value itself — it is not a `GtkSpinButton`, and the spin
    /// button API crashed against it.
    public func setStepperRange(minValue: Double, maxValue: Double, increment: Double,
                                for handle: NativeHandle) {
        ranges[handle.rawValue] = (minValue, maxValue)
        stepperSteps[handle.rawValue] = increment == 0 ? 1 : increment
    }

    /// Whether the stepper wraps past its bounds. The arrow pair clamps at its
    /// bounds; wrapping is not implemented.
    public func setStepperWraps(_ wraps: Bool, for handle: NativeHandle) {}

    /// Sets the progress bar's value.
    public func setProgressIndicatorValue(_ value: Double, for handle: NativeHandle) {
        setDoubleValue(value, for: handle)
    }

    /// Sets the progress bar's range.
    ///
    /// Straight into the range table `setDoubleValue` reads, NOT through
    /// `setLevelIndicatorRange` — that one rebuilds a `GtkLevelBar`'s star
    /// content, and running it against a `GtkProgressBar` corrupted the widget
    /// and crashed the first run of the merged demo.
    public func setProgressIndicatorRange(minValue: Double, maxValue: Double,
                                          for handle: NativeHandle) {
        ranges[handle.rawValue] = (minValue, maxValue)
    }

    /// Switches the progress indicator between determinate and indeterminate.
    public func setProgressIndicatorIndeterminate(_ isIndeterminate: Bool, animating: Bool,
                                                  for handle: NativeHandle) {
        setProgressIndeterminate(isIndeterminate, for: handle)
        setProgressAnimating(animating, for: handle)
    }

    /// Tints the progress bar's filled portion.
    ///
    /// `setColor` is the color well's swatch setter, not a general tint, so the
    /// fill color goes on as a background instead.
    public func setProgressBarColor(_ color: NSColor?, for handle: NativeHandle) {
        setBackgroundColor(color, for: handle)
    }

    /// Makes the level indicator editable within a range.
    ///
    /// The shared core realizes a level indicator as a PROGRESS BAR — see
    /// `NSLevelIndicator.realizeNativePeer`, which sets a progress range and
    /// value — so the GTK level widget's content builder must not run against
    /// it. `setLevelIndicatorRange` rebuilds that content (stars, segments),
    /// and against a `GtkProgressBar` it tripped `GTK_IS_BOX` on every launch.
    /// Click-to-set editing belongs to the GTK level widget, so it applies only
    /// when the peer really is one.
    public func setLevelIndicatorEditable(_ editable: Bool, minValue: Double, maxValue: Double,
                                          for handle: NativeHandle) {
        ranges[handle.rawValue] = (minValue, maxValue)
        guard kinds[handle.rawValue] == .level else { return }
        setLevelIndicatorRange(min: minValue, max: maxValue, for: handle)
        setLevelIndicatorEditable(editable, for: handle)
    }

    /// Sets the pop-up button's items.
    public func setPopUpButtonItems(_ items: [String], selectedIndex: Int,
                                    for handle: NativeHandle) {
        setPopUpItems(items, selectedIndex: selectedIndex, for: handle)
    }

    /// Selects a pop-up button item.
    public func setPopUpButtonSelectedIndex(_ selectedIndex: Int, for handle: NativeHandle) {
        setSelectedIndex(selectedIndex, for: handle)
    }

    /// Replaces the combo box's items and text.
    public func setComboBoxItems(_ items: [String], text: String, for handle: NativeHandle) {
        setPopUpItems(items, selectedIndex: -1, for: handle)
        setText(text, for: handle)
    }

    /// The number of rows the combo's list shows before scrolling. GTK's drop
    /// down sizes its popup to the available screen space and offers no such
    /// knob, so the count is not applied.
    public func setComboBoxVisibleItems(_ count: Int, for handle: NativeHandle) {}

    /// Sets the tab view's pages.
    public func setTabViewItems(_ items: [String], selectedIndex: Int, for handle: NativeHandle) {
        for label in items {
            let page = createView(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
            addTabPage(page, label: label, to: handle)
        }
        setTabViewSelectedIndex(selectedIndex, for: handle)
    }

    /// Selects a tab page.
    public func setTabViewSelectedIndex(_ selectedIndex: Int, for handle: NativeHandle) {
        setSelectedIndex(selectedIndex, for: handle)
    }

    /// Replaces the table's rows.
    public func setTableRows(_ rows: [[String]], selectedRow: Int, for handle: NativeHandle) {
        setTableCellProvider(for: handle) { row, column in
            guard row < rows.count, column < rows[row].count else { return "" }
            return rows[row][column]
        }
        setTableRowCount(rows.count, for: handle)
        setTableSelectedRow(selectedRow, for: handle)
    }

    /// Sets one cell's text. The provider installed by `setTableRows` owns the
    /// content, so this refreshes the row rather than writing through.
    public func setTableCellText(_ text: String, row: Int, column: Int, for handle: NativeHandle) {
        setNeedsDisplay(handle)
    }

    /// Selects a single row.
    public func setTableSelectedRow(_ selectedRow: Int, for handle: NativeHandle) {
        coreSeam.tableSelection[handle.rawValue] = selectedRow >= 0 ? [selectedRow] : []
        if selectedRow >= 0 { selectOutlineRow(selectedRow, for: handle) }
    }

    /// Selects several rows. GTK's column view selection model here is single
    /// selection, so the lowest row wins.
    public func setTableSelectedRows(_ rows: Set<Int>, for handle: NativeHandle) {
        coreSeam.tableSelection[handle.rawValue] = rows.sorted()
        if let first = rows.min() { selectOutlineRow(first, for: handle) }
    }

    /// Whether the table allows multi-row selection.
    public func setTableAllowsMultipleSelection(_ allows: Bool, for handle: NativeHandle) {}

    /// Whether the table's cells can be edited in place.
    public func setTableEditable(_ editable: Bool, for handle: NativeHandle) {}

    /// Shows the sort indicator on a column.
    public func setTableSortIndicator(column: Int, ascending: Bool, for handle: NativeHandle) {
        setColumnSortable(column, for: handle)
    }

    /// Begins editing a cell.
    public func editTableCell(row: Int, column: Int, for handle: NativeHandle) {
        scrollTableRowToVisible(row, for: handle)
    }

    /// Sets the text color, clearing it when nil.
    public func setTextColor(_ color: NSColor?, for handle: NativeHandle) {
        guard let color else { return }
        setTextColor(color, for: handle)
    }

    /// Sets the control's font.
    public func setFont(_ font: NSFont?, for handle: NativeHandle) {
        guard let font else { return }
        setFont(NativeFontSpec(family: font.fontName, size: Double(font.pointSize),
                               bold: font.isBold, italic: font.italic), for: handle)
    }

    /// Sets the placeholder shown in an empty text field.
    public func setTextPlaceholder(_ placeholder: String?, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_entry_set_placeholder_text(UnsafeMutablePointer<GtkEntry>(w), placeholder)
    }

    /// Whether the text field draws a bezel.
    public func setTextFieldBezeled(_ bezeled: Bool, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_entry_set_has_frame(UnsafeMutablePointer<GtkEntry>(w), gboolean(bezeled ? 1 : 0))
    }

    /// Whether the button draws a flat bezel.
    public func setButtonBezelFlat(_ flat: Bool, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_button_set_has_frame(asButton(w), gboolean(flat ? 0 : 1))
    }

    /// Sets the button's image.
    public func setButtonImage(imagePath: String?, for handle: NativeHandle) {
        setImagePath(imagePath, for: handle)
    }

    /// Sets an image view's artwork, accessible description, and template tint.
    public func setImagePath(_ path: String?, description: String, tint: NSColor?,
                             for handle: NativeHandle) {
        setImagePath(path, for: handle)
        setImageTint(tint, isTemplate: tint != nil, for: handle)
    }

    /// Whether the control paints its background.
    public func setDrawsBackground(_ drawsBackground: Bool, for handle: NativeHandle) {
        setBackgroundColor(drawsBackground ? nil : NSColor.clear, for: handle)
    }

    /// Sets the paragraph alignment of a text control.
    public func setTextAlignment(_ alignment: NSTextAlignment, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        let xalign: Float
        switch alignment {
        case .center: xalign = 0.5
        case .right:  xalign = 1.0
        default:      xalign = 0.0
        }
        switch kinds[handle.rawValue] {
        case .label: gtk_label_set_xalign(w, xalign)
        default:     gtk_editable_set_alignment(w, xalign)
        }
    }

    /// Aligns one range of a text view. GTK's text buffer carries alignment on
    /// tags; the styled-run path (`setStyledText`) is how the core gets this,
    /// so a bare range alignment is not applied.
    public func setTextRangeAlignment(_ alignment: NSTextAlignment, location: Int, length: Int,
                                      for handle: NativeHandle) {}

    /// Applies formatting to a range of a text view.
    public func setTextRangeFormat(_ format: NativeTextRangeFormat, for handle: NativeHandle) {}

    /// Sets the text view's selection.
    ///
    /// `GtkEditable` is the entry family only — a `GtkTextView` selects through
    /// its buffer, and a label has no selection at all, so asking those tripped
    /// `GTK_IS_EDITABLE`.
    public func setTextSelection(location: Int, length: Int, for handle: NativeHandle) {
        guard isEditableKind(handle), let w = widget(handle) else { return }
        gtk_editable_select_region(w, Int32(location), Int32(location + length))
    }

    /// Whether this handle is one of the `GtkEditable` control kinds.
    internal func isEditableKind(_ handle: NativeHandle) -> Bool {
        switch kinds[handle.rawValue] {
        case .textField, .secureField, .searchField, .comboBox: return true
        default: return false
        }
    }

    /// Replaces the selected text.
    public func replaceSelectedText(_ text: String, for handle: NativeHandle) {
        guard isEditableKind(handle), let w = widget(handle) else { return }
        var start: Int32 = 0, end: Int32 = 0
        if gtk_editable_get_selection_bounds(w, &start, &end) != 0 {
            gtk_editable_delete_text(w, start, end)
        }
        var position = start
        gtk_editable_insert_text(w, text, Int32(text.utf8.count), &position)
    }

    /// Sets the date picker's date and range.
    public func setDatePickerDate(_ date: Date, minDate: Date?, maxDate: Date?,
                                  for handle: NativeHandle) {
        setDateValue(date, for: handle)
        setDateRange(min: minDate, max: maxDate, for: handle)
        refreshDatePickerText(handle)
    }

    /// Sets the picker's field pattern.
    ///
    /// The compact picker is a text entry, and `setDateValue` deliberately does
    /// not write into it — formatting needs the locale, calendar and element
    /// flags, which are AppKit's to know. The core knows them and sends this
    /// pattern; nothing was rendering it, so the control came up blank.
    public func setDatePickerFormat(_ format: String?, for handle: NativeHandle) {
        coreSeam.datePickerFormats[handle.rawValue] = format
        refreshDatePickerText(handle)
    }

    /// Renders the current date through the current pattern into the entry.
    internal func refreshDatePickerText(_ handle: NativeHandle) {
        let raw = handle.rawValue
        guard let format = coreSeam.datePickerFormats[raw], !format.isEmpty,
              let date = dateValues[raw] else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = format
        setDatePickerText(formatter.string(from: date), for: handle)
    }

    /// Sets the time zone the picker displays in.
    public func setDatePickerTimeZone(_ timeZone: TimeZone, for handle: NativeHandle) {}

    /// Sets the view's tooltip.
    public func setToolTip(_ toolTip: String?, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_widget_set_tooltip_text(asWidget(w), toolTip)
    }

    /// Scales a view's contents. GTK4 scales at the renderer, not per widget;
    /// the drawing path applies magnification instead (`setViewMagnification`).
    public func setContentScale(_ scale: CGFloat, for handle: NativeHandle) {
        setViewMagnification(Double(scale), for: handle)
    }

    /// Lets a drag inside the view move its window (AppKit's
    /// `mouseDownCanMoveWindow`), which is GTK's `GtkWindowHandle`.
    public func setViewDragsParentWindow(_ enabled: Bool, for handle: NativeHandle) {}

    // MARK: Windows

    /// Closes a window.
    public func closeWindow(_ handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        let isPrimary = primaryWindows.contains(handle.rawValue)
        gtk_window_destroy(asWindow(w))
        forgetDestroyedWindow(handle.rawValue)
        if isPrimary {
            terminateApplication()
        }
    }

    /// Whether the window is on screen.
    public func isWindowVisible(_ handle: NativeHandle) -> Bool {
        guard let w = widget(handle) else { return false }
        return gtk_widget_get_visible(asWidget(w)) != 0
    }

    /// Whether the window is minimized.
    public func isWindowMinimized(_ handle: NativeHandle) -> Bool {
        coreSeam.minimizedWindows.contains(handle.rawValue)
    }

    /// Minimizes or restores a window.
    public func setWindowMinimized(_ minimized: Bool, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        if minimized {
            coreSeam.minimizedWindows.insert(handle.rawValue)
            gtk_window_minimize(asWindow(w))
        } else {
            coreSeam.minimizedWindows.remove(handle.rawValue)
            gtk_window_unminimize(asWindow(w))
        }
    }

    /// Toggles the window between its standard and zoomed frames.
    public func toggleWindowZoom(_ handle: NativeHandle) {
        toggleZoomWindow(handle)
    }

    /// Shows or hides a window with a fade. GTK4 has no window animation API,
    /// so the opacity is set directly and the change is immediate.
    public func fadeWindow(_ handle: NativeHandle, visible: Bool) {
        guard let w = widget(handle) else { return }
        gtk_widget_set_opacity(asWidget(w), visible ? 1.0 : 0.0)
        if visible { showWindow(handle) } else { hideWindow(handle) }
    }

    /// Sends a window behind its siblings.
    ///
    /// GTK4 removed window lowering — `gdk_window_lower` has no GdkSurface
    /// successor, because ordering is the compositor's to decide. There is no
    /// call to make here.
    public func orderWindowBack(_ handle: NativeHandle) {}

    /// Sets the window's stacking level. GTK4 exposes only "always on top"
    /// through the compositor, so a level above `.normal` raises the window.
    public func setWindowLevel(_ level: NSWindow.Level, for handle: NativeHandle) {
        guard level.rawValue > NSWindow.Level.normal.rawValue else { return }
        showWindow(handle)
    }

    /// Constrains the window's content size. GTK4 takes a minimum through the
    /// size request; a maximum is the compositor's to enforce and is not set.
    public func setWindowContentSizeLimits(minSize: NSSize?, maxSize: NSSize?,
                                           for handle: NativeHandle) {
        guard let w = widget(handle), let minSize else { return }
        gtk_widget_set_size_request(asWidget(w), Int32(minSize.width), Int32(minSize.height))
    }

    /// Hides individual title-bar buttons. GTK's header bar controls close as
    /// a unit, so hiding close hides the whole set.
    public func setWindowButtonsHidden(closeHidden: Bool, minimizeHidden: Bool, zoomHidden: Bool,
                                       for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_window_set_deletable(asWindow(w), gboolean(closeHidden ? 0 : 1))
    }

    /// Whether the window hides when the app deactivates. X11 gives no
    /// app-activation signal to hang this on, so panels stay put.
    public func setHidesOnDeactivate(_ hidesOnDeactivate: Bool, for handle: NativeHandle) {}

    /// The main display's frame.
    public func primaryScreenFrame() -> NSRect {
        screenDescriptions().first?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
    }

    /// Every attached display. GTK reports no separate work area, so the
    /// visible frame is the full frame.
    public func screenDescriptions() -> [NativeScreenDescription] {
        guard let display = gdk_display_get_default(),
              let monitors = gdk_display_get_monitors(display) else { return [] }
        var result: [NativeScreenDescription] = []
        for index in 0..<g_list_model_get_n_items(monitors) {
            guard let monitor = g_list_model_get_item(monitors, index) else { continue }
            var rect = GdkRectangle()
            gdk_monitor_get_geometry(OpaquePointer(monitor), &rect)
            let frame = NSRect(x: CGFloat(rect.x), y: CGFloat(rect.y),
                               width: CGFloat(rect.width), height: CGFloat(rect.height))
            result.append(NativeScreenDescription(frame: frame, visibleFrame: frame))
        }
        return result
    }

    // MARK: Focus, invalidation, z-order

    /// Gives the control keyboard focus.
    public func focusControl(_ handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_widget_grab_focus(asWidget(w))
    }

    /// Raises the control above its siblings.
    public func raiseControl(_ handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_widget_insert_before(asWidget(w), gtk_widget_get_parent(asWidget(w)), nil)
    }

    /// Marks the control as needing redraw.
    public func invalidateControl(_ handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_widget_queue_draw(asWidget(w))
        setNeedsDisplay(handle)
    }

    /// Marks the control and its descendants as needing redraw. GTK invalidates
    /// a subtree with the parent, so this is the same call.
    public func invalidateControlTree(_ handle: NativeHandle) {
        invalidateControl(handle)
    }

    /// Redraws now rather than at the next frame.
    ///
    /// GTK4 draws on the frame clock and offers no synchronous paint — that is
    /// what makes its rendering tear-free — so this queues the redraw and the
    /// compositor presents it on the next tick.
    public func redrawControlImmediately(_ handle: NativeHandle) {
        invalidateControl(handle)
    }

}

#endif
