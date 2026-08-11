#if canImport(CGTK)
import CGTK
import CGTKCompat
import Foundation

extension GTKNativeControlBackend {
    /// Presents an open panel and returns the selected path, or nil on cancellation.
    public func runOpenPanel(directory: String?, for window: NativeHandle?) -> String? {
        runFileDialog(open: true, directory: directory, suggestedName: nil, for: window)
    }
    /// Presents a modal `GtkFileDialog` in save mode and returns the chosen path (nil on cancel).
    public func runSavePanel(directory: String?, suggestedName: String?, for window: NativeHandle?) -> String? {
        runFileDialog(open: false, directory: directory, suggestedName: suggestedName, for: window)
    }

    /// Runs the file chooser through the C compatibility layer so Ubuntu 22.04's
    /// GTK 4.6 can compile without newer `GtkFileDialog` symbols.
    internal func runFileDialog(open: Bool, directory: String?, suggestedName: String?, for window: NativeHandle?) -> String? {
        let parent = window.flatMap { widget($0) }.map { asWindow($0) }
        guard let cPath = lc_run_file_chooser(parent, open ? 1 : 0, directory, suggestedName) else {
            return nil
        }
        defer { g_free(cPath) }
        return String(cString: cPath)
    }
    /// Wires `action` to the window's `close-request` signal.
    public func registerWindowCloseAction(for handle: NativeHandle, action: @escaping () -> Void) {
        guard let w = widget(handle) else { return }
        let raw = handle.rawValue
        let isPrimary = primaryWindows.contains(raw)
        windowCloseActions[raw] = action
        let box = WindowCloseBox(
            shouldClose: { [weak self] in
                self?.windowShouldCloseHandlers[raw]?() != false
            },
            didClose: { [weak self] in
                self?.windowCloseActions[raw]?()
                self?.forgetDestroyedWindow(raw)
                if isPrimary {
                    self?.terminateApplication()
                }
            },
            destroysSurface: true
        )
        g_signal_connect_data(
            UnsafeMutableRawPointer(w), "close-request",
            unsafeBitCast(gtkCloseRequestTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }

    // MARK: Popover
    /// Creates a `GtkPopover` with autohide enabled.
    public func createPopover() -> NativeHandle {
        let pop = gtk_popover_new()!
        gtk_popover_set_autohide(asPopover(OpaquePointer(pop)), gboolean(1))
        if nonComposited { gtk_popover_set_has_arrow(asPopover(OpaquePointer(pop)), gboolean(0)) }
        return allocate(pop, .view, frame: .zero)
    }
    /// Installs `content` as the popover's child and sizes it.
    public func setPopoverContent(_ content: NativeHandle, size: NSSize, for popover: NativeHandle) {
        guard let pop = widget(popover), let c = widget(content) else { return }
        gtk_widget_set_size_request(asWidget(c), Int32(size.width), Int32(size.height))
        gtk_popover_set_child(asPopover(pop), asWidget(c))
    }
    /// Anchors the popover to `view` at `rect` on `edge` and pops it up.
    public func showPopover(_ popover: NativeHandle, relativeTo view: NativeHandle, rect: NSRect, edge: Int) {
        guard let pop = widget(popover), let v = widget(view) else { return }
        if !popoverParented.contains(popover.rawValue) {
            gtk_widget_set_parent(asWidget(pop), asWidget(v))
            popoverParented.insert(popover.rawValue)
        }
        // Flip the AppKit rect into the view's GTK (top-left) coordinates.
        let viewHeight = Double(gtk_widget_get_height(asWidget(v)))
        var pointing = GdkRectangle(x: Int32(rect.minX), y: Int32(viewHeight - Double(rect.maxY)),
                                    width: Int32(rect.width), height: Int32(rect.height))
        gtk_popover_set_pointing_to(asPopover(pop), &pointing)
        // NSRectEdge raw: minX=0, minY=1, maxX=2, maxY=3.
        let position: GtkPositionType = edge == 0 ? GTK_POS_LEFT : edge == 2 ? GTK_POS_RIGHT : GTK_POS_BOTTOM
        gtk_popover_set_position(asPopover(pop), position)
        gtk_popover_popup(asPopover(pop))
    }
    /// Pops the popover down.
    public func closePopover(_ popover: NativeHandle) {
        guard let pop = widget(popover) else { return }
        gtk_popover_popdown(asPopover(pop))
    }

    // MARK: Views & controls
    /// Creates a container view: a `GtkOverlay` with a `GtkDrawingArea` under a `GtkFixed`.
    public func createView(frame: NSRect) -> NativeHandle {
        // An NSView both draws (AppKit `draw(_:)`) and contains children, so it
        // is a GtkOverlay: a GtkDrawingArea underneath for custom drawing, and
        // a GtkFixed on top for absolute child placement.
        let overlay = gtk_overlay_new()!
        let area = gtk_drawing_area_new()!
        let fixed = gtk_fixed_new()!
        // Children are placed at exact AppKit frames, so the fixed's own layout
        // manager (which allocates each child its *minimum* size) is replaced.
        // GtkFixed's put/move API must not be used on it from here on.
        gtk_widget_set_layout_manager(
            fixed, unsafeBitCast(g_object_new_with_properties(linChocolateFixedLayoutType(), 0, nil, nil),
                                 to: UnsafeMutablePointer<GtkLayoutManager>.self)
        )
        gtk_overlay_set_child(OpaquePointer(overlay), area)
        gtk_overlay_add_overlay(OpaquePointer(overlay), fixed)
        // Explicit size + expand: without this the container can collapse to
        // 0×0 and clip its children (the "window shows but controls are blank"
        // symptom seen over XQuartz, where the initial configure can lag).
        gtk_widget_set_size_request(overlay, Int32(frame.width), Int32(frame.height))
        gtk_widget_set_hexpand(overlay, gboolean(1))
        gtk_widget_set_vexpand(overlay, gboolean(1))
        let h = allocate(overlay, .view, frame: frame)
        viewFixeds[h.rawValue] = OpaquePointer(fixed)
        viewDrawAreas[h.rawValue] = OpaquePointer(area)
        return h
    }

    /// The child-hosting GtkFixed of a container view.
    internal func containerFixed(of raw: UInt) -> OpaquePointer? {
        viewFixeds[raw]
    }
    /// Creates a `GtkButton` labelled `title`.
    public func createButton(title: String, frame: NSRect) -> NativeHandle {
        let b = gtk_button_new_with_label(title)!
        gtk_widget_set_size_request(b, Int32(frame.width), Int32(frame.height))
        return allocate(b, .button, frame: frame)
    }
    /// Creates a static `GtkLabel`.
    public func createLabel(text: String, frame: NSRect) -> NativeHandle {
        let l = gtk_label_new(text)!
        gtk_widget_set_size_request(l, Int32(frame.width), Int32(frame.height))
        return allocate(l, .label, frame: frame)
    }
    /// Creates a `GtkEntry` (starts frameless and non-editable, per AppKit's default).
    public func createTextField(text: String, frame: NSRect) -> NativeHandle {
        let e = gtk_entry_new()!
        gtk_editable_set_text(OpaquePointer(e), text)   // GtkEditable is opaque
        // AppKit's `NSTextField(string:)` defaults to non-editable — rendered as a
        // borderless STATIC label on Windows. Match that: start frameless and
        // read-only; `isEditable = true` (setTextEditable) turns it into a field.
        gtk_editable_set_editable(OpaquePointer(e), gboolean(0))
        gtk_entry_set_has_frame(UnsafeMutablePointer<GtkEntry>(OpaquePointer(e)), gboolean(0))
        gtk_widget_add_css_class(e, "linchocolate-label")
        gtk_widget_set_size_request(e, Int32(frame.width), Int32(frame.height))
        return allocate(e, .textField, frame: frame)
    }
    /// Toggles a `GtkEntry` between editable framed and borderless static.
    public func setTextEditable(_ editable: Bool, for handle: NativeHandle) {
        guard let w = widget(handle), kinds[handle.rawValue] == .textField else { return }
        gtk_editable_set_editable(w, gboolean(editable ? 1 : 0))
        gtk_entry_set_has_frame(UnsafeMutablePointer<GtkEntry>(w), gboolean(editable ? 1 : 0))
        if editable {
            gtk_widget_remove_css_class(asWidget(w), "linchocolate-label")
        } else {
            gtk_widget_add_css_class(asWidget(w), "linchocolate-label")
        }
    }
    /// The unique style class that scopes display-wide CSS to one widget.
    internal func scopeClass(_ raw: UInt) -> String { "lc-w\(raw)" }

    /// Installs (or clears, when `body` is nil) one widget-scoped rule at
    /// `priority`, then rebuilds that priority's display-wide provider.
    internal func setScopedRule(_ body: String?, id: String, priority: Int32, for handle: NativeHandle) {
        let raw = handle.rawValue
        if let w = widget(handle) {
            gtk_widget_add_css_class(asWidget(w), scopeClass(raw))
        }
        var rules = scopedRules[priority] ?? [:]
        let key = "\(raw).\(id)"
        if let body, !body.isEmpty { rules[key] = body } else { rules.removeValue(forKey: key) }
        scopedRules[priority] = rules
        guard let display = gdk_display_get_default() else { return }
        let provider: UnsafeMutablePointer<GtkCssProvider>
        if let existing = scopedProviders[priority] {
            provider = existing
        } else {
            provider = gtk_css_provider_new()!
            gtk_style_context_add_provider_for_display(display, OpaquePointer(provider), guint(priority))
            scopedProviders[priority] = provider
        }
        let css = rules.keys.sorted().compactMap { rules[$0] }.joined(separator: "\n")
        lc_css_provider_load(provider, css)
    }

    /// Paints the widget's background via a display-wide scoped CSS rule (nil clears it).
    public func setBackgroundColor(_ color: NSColor?, for handle: NativeHandle) {
        guard widget(handle) != nil else { return }
        guard let color else {
            setScopedRule(nil, id: "bg", priority: 800, for: handle)
            return
        }
        // The widget ONLY — deliberately not `.cls *`. A background does not
        // inherit in CSS, and the per-widget provider this replaced styled just
        // the widget's own node. Painting every descendant put an opaque slab of
        // the field colour behind each child's text — visible as the token chips'
        // labels masking their pill. 800 > the app-wide providers, so this wins.
        let cls = scopeClass(handle.rawValue)
        // `text` subnodes are included because GtkEntry/GtkTextView paint their
        // editable surface there, so a field's background must reach it. `label`
        // is deliberately NOT included — that is what masked the token pills.
        let rule = String(
            format: ".%@, .%@ text { background-color: rgba(%d,%d,%d,%.3f); }", cls, cls,
            Int(color.redComponent * 255), Int(color.greenComponent * 255),
            Int(color.blueComponent * 255), Double(color.alphaComponent)
        )
        setScopedRule(rule, id: "bg", priority: 800, for: handle)
    }
    /// Creates a `GtkPasswordEntry`.
    public func createSecureTextField(text: String, frame: NSRect) -> NativeHandle {
        let e = gtk_password_entry_new()!
        gtk_editable_set_text(OpaquePointer(e), text)
        gtk_widget_set_size_request(e, Int32(frame.width), Int32(frame.height))
        return allocate(e, .secureField, frame: frame)
    }
    /// Creates a `GtkSearchEntry`.
    public func createSearchField(text: String, frame: NSRect) -> NativeHandle {
        let e = gtk_search_entry_new()!
        gtk_editable_set_text(OpaquePointer(e), text)
        gtk_widget_set_size_request(e, Int32(frame.width), Int32(frame.height))
        return allocate(e, .searchField, frame: frame)
    }
    /// Creates an editable `GtkComboBoxText` (with an embedded `GtkEntry`).
    public func createComboBox(items: [String], text: String, frame: NSRect) -> NativeHandle {
        // GtkComboBoxText(-with-entry) is deprecated in GTK4 but remains the
        // direct editable-combo analog; its child GtkEntry (GtkEditable) carries
        // the text get/set and the change signal.
        let combo = lc_combo_box_text_new_with_entry()!
        for item in items { lc_combo_box_text_append_text(combo, item) }
        let entry = lc_combo_box_get_child(combo)
        if let entry { gtk_editable_set_text(OpaquePointer(entry), text) }
        gtk_widget_set_size_request(combo, Int32(frame.width), Int32(frame.height))
        let h = allocate(combo, .comboBox, frame: frame)
        if let entry { comboEntries[h.rawValue] = OpaquePointer(entry) }
        return h
    }
    /// Creates a `GtkCheckButton` used as a checkbox.
    public func createCheckbox(title: String, frame: NSRect) -> NativeHandle {
        let c = gtk_check_button_new_with_label(title)!
        gtk_widget_set_size_request(c, Int32(frame.width), Int32(frame.height))
        return allocate(c, .checkbox, frame: frame)
    }
    /// Creates a `GtkCheckButton` used as a radio (group it via `groupRadioButtons`).
    public func createRadioButton(title: String, frame: NSRect) -> NativeHandle {
        // A radio button is a GtkCheckButton grouped via groupRadioButtons().
        let r = gtk_check_button_new_with_label(title)!
        gtk_widget_set_size_request(r, Int32(frame.width), Int32(frame.height))
        return allocate(r, .radio, frame: frame)
    }
    /// Groups the check-button widgets via `gtk_check_button_set_group` for mutual exclusion.
    public func groupRadioButtons(_ handles: [NativeHandle]) {
        guard let first = handles.first, let lead = widget(first) else { return }
        for handle in handles.dropFirst() {
            guard let w = widget(handle) else { continue }
            gtk_check_button_set_group(asCheckButton(w), asCheckButton(lead))
        }
    }
    /// Creates a horizontal `GtkScale` over `[minValue, maxValue]`.
    public func createSlider(value: Double, minValue: Double, maxValue: Double, frame: NSRect) -> NativeHandle {
        let step = (maxValue - minValue) / 100
        let s = gtk_scale_new_with_range(GTK_ORIENTATION_HORIZONTAL, minValue, maxValue, step == 0 ? 1 : step)!
        gtk_range_set_value(asRange(OpaquePointer(s)), value)
        gtk_widget_set_size_request(s, Int32(frame.width), Int32(frame.height))
        let h = allocate(s, .slider, frame: frame)
        ranges[h.rawValue] = (minValue, maxValue)
        return h
    }
    /// Creates a `GtkProgressBar` over `[minValue, maxValue]`.
    public func createProgressIndicator(value: Double, minValue: Double, maxValue: Double, frame: NSRect) -> NativeHandle {
        let p = gtk_progress_bar_new()!
        gtk_widget_set_size_request(p, Int32(frame.width), Int32(frame.height))
        let h = allocate(p, .progress, frame: frame)
        ranges[h.rawValue] = (minValue, maxValue)
        setDoubleValue(value, for: h)
        return h
    }

    /// Toggles a progress bar between determinate and indeterminate (pulsing) modes.
    public func setProgressIndeterminate(_ indeterminate: Bool, for handle: NativeHandle) {
        if indeterminate { indeterminateProgress.insert(handle.rawValue) }
        else { indeterminateProgress.remove(handle.rawValue); stopProgressPulse(handle.rawValue) }
    }

    /// Swaps between a `GtkProgressBar` (bar) and a custom Cairo spoke-rotator (spinner).
    public func setProgressSpinning(_ spinning: Bool, for handle: NativeHandle) {
        let raw = handle.rawValue
        guard spinning != progressSpinners.contains(raw), let old = widgets[raw] else { return }
        let frame = frames[raw] ?? .zero
        // Style is set before the indicator is added to a page, so the widget
        // has no parent yet; a straight swap is safe (like the date picker).
        if gtk_widget_get_parent(asWidget(old)) != nil { gtk_widget_unparent(asWidget(old)) }
        let new: UnsafeMutablePointer<GtkWidget>
        if spinning {
            // A custom Cairo drawing area, NOT GtkSpinner: GtkSpinner draws
            // NOTHING when stopped, but AppKit's spinning indicator is always
            // visible (the spokes just stop rotating). We draw the spokes
            // ourselves and rotate them via a timeout only while animating.
            let area = gtk_drawing_area_new()!
            spinnerPhase[raw] = 0
            let drawBox = SpinnerDrawBox(backend: self, raw: raw)
            gtk_drawing_area_set_draw_func(
                UnsafeMutablePointer<GtkDrawingArea>(OpaquePointer(area)),
                gtkSpinnerDrawFunc,
                Unmanaged.passRetained(drawBox).toOpaque(), boxDestroyNotify
            )
            new = area
            progressSpinners.insert(raw)
        } else {
            stopSpinnerAnimation(raw)
            new = gtk_progress_bar_new()!
            progressSpinners.remove(raw)
        }
        gtk_widget_set_size_request(new, Int32(frame.width), Int32(frame.height))
        widgets[raw] = OpaquePointer(new)
        g_object_ref_sink(UnsafeMutableRawPointer(old))
        g_object_unref(UnsafeMutableRawPointer(old))
    }

    /// Starts or stops the pulse / spoke-rotation animation of an indeterminate indicator.
}

#endif
