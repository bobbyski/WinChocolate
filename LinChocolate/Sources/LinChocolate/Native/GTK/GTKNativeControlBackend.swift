#if canImport(CGTK)
import CGTK
import Foundation

/// Linux backend: maps the AppKit-shaped seam onto native GTK4 widgets.
///
/// ```text
///   NSWindow             ->  GtkWindow (its child is the content view's GtkFixed)
///   NSView               ->  GtkFixed  (absolute child placement, like AppKit)
///   NSButton             ->  GtkButton
///   NSTextField (label)  ->  GtkLabel
/// ```
///
/// GTK is C/GObject. The `as*` helpers stand in for GTK's upcast macros
/// (`GTK_WINDOW()`, `GTK_BUTTON()`, …), which don't survive the C→Swift import;
/// every GObject begins with a `GTypeInstance`, so the reinterpret is safe.
///
/// The event loop uses a plain `GMainLoop` (not `GtkApplication`) so the
/// create-window-then-run ordering matches AppKit's, instead of GTK's
/// activate-callback model.
public final class GTKNativeControlBackend: NativeControlBackend {

    private var nextRaw: UInt = 1
    private var widgets: [UInt: OpaquePointer] = [:]   // handle -> GtkWidget*
    private var kinds: [UInt: InMemoryNativeControlBackend.Kind] = [:]
    private var frames: [UInt: NSRect] = [:]
    private var parents: [UInt: UInt] = [:]   // child -> parent, for repositioning
    private var ranges: [UInt: (min: Double, max: Double)] = [:]   // slider/progress
    private var comboEntries: [UInt: OpaquePointer] = [:]   // combo -> its GtkEntry child
    private var splitPaneCounts: [UInt: Int] = [:]           // paned -> panes added
    private var windowBoxes: [UInt: OpaquePointer] = [:]     // window -> vertical GtkBox child
    private var windowContents: [UInt: OpaquePointer] = [:]  // window -> current content widget
    private var windowMenuBars: [UInt: OpaquePointer] = [:]  // window -> GtkPopoverMenuBar
    private var segmentButtons: [UInt: [OpaquePointer]] = [:] // segmented -> its toggle buttons
    private var menuActionCounter = 0                         // unique GAction names
    private var mainLoop: OpaquePointer?   // GMainLoop* (opaque in the GTK import)

    /// Connects to the display and initializes GTK. Only construct this when a
    /// display is available (the demo/app), never in headless tests.
    public init() {
        gtk_init()
    }

    // MARK: Handle bookkeeping
    private func allocate(_ widget: UnsafeMutablePointer<GtkWidget>, _ kind: InMemoryNativeControlBackend.Kind, frame: NSRect) -> NativeHandle {
        defer { nextRaw += 1 }
        widgets[nextRaw] = OpaquePointer(widget)
        kinds[nextRaw] = kind
        frames[nextRaw] = frame
        return NativeHandle(rawValue: nextRaw)
    }
    private func widget(_ h: NativeHandle) -> OpaquePointer? { widgets[h.rawValue] }

    // MARK: Pointer upcasts (stand-ins for GTK_*() macros)
    private func asWidget(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkWidget> { .init(p) }
    private func asWindow(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkWindow> { .init(p) }
    private func asFixed(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkFixed> { .init(p) }
    private func asButton(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkButton> { .init(p) }
    private func asCheckButton(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkCheckButton> { .init(p) }
    private func asRange(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkRange> { .init(p) }
    private func asTextView(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkTextView> { .init(p) }
    private func asTextBuffer(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkTextBuffer> { .init(p) }
    private func asFrame(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkFrame> { .init(p) }
    private func asBox(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkBox> { .init(p) }
    private func asToggle(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkToggleButton> { .init(p) }
    private func asMenuModel(_ p: OpaquePointer) -> UnsafeMutablePointer<GMenuModel> { .init(p) }
    // GtkProgressBar, GtkDropDown, GtkLevelBar and GtkSpinButton are opaque in the
    // import — their functions take OpaquePointer directly. GtkTextBuffer is nominal.
    // NOTE: GtkLabel, GtkEditable, and GMainLoop are opaque in the GTK4 Swift
    // import (no nominal type), so their functions take/return OpaquePointer.
    // GtkWindow/GtkButton/GtkCheckButton/GtkFixed do import as nominal types.

    // MARK: Application lifecycle
    public func runApplication() {
        let loop = g_main_loop_new(nil, gboolean(0))   // OpaquePointer!
        mainLoop = loop
        g_main_loop_run(loop)
    }
    public func terminateApplication() {
        guard let loop = mainLoop else { return }
        g_main_loop_quit(loop)
    }

    // MARK: Windows
    public func createWindow(title: String, frame: NSRect, styleMask: NSWindow.StyleMask) -> NativeHandle {
        let win = gtk_window_new()!
        let h = allocate(win, .window, frame: frame)
        let p = widget(h)!
        gtk_window_set_title(asWindow(p), title)
        gtk_window_set_default_size(asWindow(p), Int32(frame.width), Int32(frame.height))
        // The window's real child is a vertical box: [menu bar?][content view].
        // This keeps a slot for `installMenuBar` above the AppKit content view.
        let box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        gtk_window_set_child(asWindow(p), box)
        windowBoxes[h.rawValue] = OpaquePointer(box)
        return h
    }
    public func setContentView(_ view: NativeHandle, for window: NativeHandle) {
        guard let w = widget(window), let v = widget(view) else { return }
        switch kinds[window.rawValue] {
        case .box:        gtk_frame_set_child(asFrame(w), asWidget(v))
        case .scrollView: gtk_scrolled_window_set_child(w, asWidget(v))   // GtkScrolledWindow is opaque
        default:
            guard let box = windowBoxes[window.rawValue] else { return }
            if let old = windowContents[window.rawValue] {
                gtk_box_remove(asBox(box), asWidget(old))
            }
            gtk_box_append(asBox(box), asWidget(v))
            windowContents[window.rawValue] = v
        }
    }
    public func showWindow(_ handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_window_present(asWindow(w))
    }
    public func setWindowTitle(_ title: String, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_window_set_title(asWindow(w), title)
    }
    public func installMenuBar(_ menus: [NativeMenuSpec], on window: NativeHandle) {
        guard let w = widget(window), let box = windowBoxes[window.rawValue] else { return }

        // Build the GMenu model and a matching action group. Item actions are
        // GSimpleActions named "m<N>" in the window-scoped "win" group;
        // separators become GMenu section boundaries.
        let root = g_menu_new()!
        let group = g_simple_action_group_new()!
        for menu in menus {
            let submenu = g_menu_new()!
            var section = g_menu_new()!
            for item in menu.items {
                if item.isSeparator {
                    g_menu_append_section(submenu, nil, asMenuModel(section))
                    section = g_menu_new()!
                    continue
                }
                menuActionCounter += 1
                let name = "m\(menuActionCounter)"
                g_menu_append(section, item.title, "win.\(name)")
                let gaction = g_simple_action_new(name, nil)!
                if let action = item.action {
                    let box = ActionBox(action)
                    g_signal_connect_data(
                        UnsafeMutableRawPointer(gaction), "activate",
                        unsafeBitCast(gtkMenuActivateTrampoline, to: GCallback.self),
                        Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
                    )
                }
                g_action_map_add_action(OpaquePointer(group), gaction)
            }
            g_menu_append_section(submenu, nil, asMenuModel(section))
            g_menu_append_submenu(root, menu.title, asMenuModel(submenu))
        }
        gtk_widget_insert_action_group(asWidget(w), "win", OpaquePointer(group))

        // Replace any existing bar, then put the new one at the top of the box.
        if let oldBar = windowMenuBars[window.rawValue] {
            gtk_box_remove(asBox(box), asWidget(oldBar))
        }
        let bar = gtk_popover_menu_bar_new_from_model(asMenuModel(root))!
        gtk_box_prepend(asBox(box), bar)
        windowMenuBars[window.rawValue] = OpaquePointer(bar)
    }
    public func registerWindowCloseAction(for handle: NativeHandle, action: @escaping () -> Void) {
        guard let w = widget(handle) else { return }
        let box = ActionBox(action)
        g_signal_connect_data(
            UnsafeMutableRawPointer(w), "close-request",
            unsafeBitCast(gtkCloseRequestTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }

    // MARK: Views & controls
    public func createView(frame: NSRect) -> NativeHandle {
        let fixed = gtk_fixed_new()!
        // Give the container an explicit size and let it expand to fill its
        // parent. Without this the GtkFixed can collapse to 0×0 and clip all of
        // its children — the "window shows but controls are blank" symptom seen
        // over XQuartz (where the initial surface configure can lag).
        gtk_widget_set_size_request(fixed, Int32(frame.width), Int32(frame.height))
        gtk_widget_set_hexpand(fixed, gboolean(1))
        gtk_widget_set_vexpand(fixed, gboolean(1))
        return allocate(fixed, .view, frame: frame)
    }
    public func createButton(title: String, frame: NSRect) -> NativeHandle {
        let b = gtk_button_new_with_label(title)!
        gtk_widget_set_size_request(b, Int32(frame.width), Int32(frame.height))
        return allocate(b, .button, frame: frame)
    }
    public func createLabel(text: String, frame: NSRect) -> NativeHandle {
        let l = gtk_label_new(text)!
        gtk_widget_set_size_request(l, Int32(frame.width), Int32(frame.height))
        return allocate(l, .label, frame: frame)
    }
    public func createTextField(text: String, frame: NSRect) -> NativeHandle {
        let e = gtk_entry_new()!
        gtk_editable_set_text(OpaquePointer(e), text)   // GtkEditable is opaque
        gtk_widget_set_size_request(e, Int32(frame.width), Int32(frame.height))
        return allocate(e, .textField, frame: frame)
    }
    public func createSecureTextField(text: String, frame: NSRect) -> NativeHandle {
        let e = gtk_password_entry_new()!
        gtk_editable_set_text(OpaquePointer(e), text)
        gtk_widget_set_size_request(e, Int32(frame.width), Int32(frame.height))
        return allocate(e, .secureField, frame: frame)
    }
    public func createSearchField(text: String, frame: NSRect) -> NativeHandle {
        let e = gtk_search_entry_new()!
        gtk_editable_set_text(OpaquePointer(e), text)
        gtk_widget_set_size_request(e, Int32(frame.width), Int32(frame.height))
        return allocate(e, .searchField, frame: frame)
    }
    public func createComboBox(items: [String], text: String, frame: NSRect) -> NativeHandle {
        // GtkComboBoxText(-with-entry) is deprecated in GTK4 but remains the
        // direct editable-combo analog; its child GtkEntry (GtkEditable) carries
        // the text get/set and the change signal.
        let combo = gtk_combo_box_text_new_with_entry()!
        for item in items { gtk_combo_box_text_append_text(OpaquePointer(combo), item) }
        // GtkComboBoxText is opaque in the import but GtkComboBox is nominal.
        let entry = gtk_combo_box_get_child(UnsafeMutablePointer<GtkComboBox>(OpaquePointer(combo)))
        if let entry { gtk_editable_set_text(OpaquePointer(entry), text) }
        gtk_widget_set_size_request(combo, Int32(frame.width), Int32(frame.height))
        let h = allocate(combo, .comboBox, frame: frame)
        if let entry { comboEntries[h.rawValue] = OpaquePointer(entry) }
        return h
    }
    public func createCheckbox(title: String, frame: NSRect) -> NativeHandle {
        let c = gtk_check_button_new_with_label(title)!
        gtk_widget_set_size_request(c, Int32(frame.width), Int32(frame.height))
        return allocate(c, .checkbox, frame: frame)
    }
    public func createRadioButton(title: String, frame: NSRect) -> NativeHandle {
        // A radio button is a GtkCheckButton grouped via groupRadioButtons().
        let r = gtk_check_button_new_with_label(title)!
        gtk_widget_set_size_request(r, Int32(frame.width), Int32(frame.height))
        return allocate(r, .radio, frame: frame)
    }
    public func groupRadioButtons(_ handles: [NativeHandle]) {
        guard let first = handles.first, let lead = widget(first) else { return }
        for handle in handles.dropFirst() {
            guard let w = widget(handle) else { continue }
            gtk_check_button_set_group(asCheckButton(w), asCheckButton(lead))
        }
    }
    public func createSlider(value: Double, minValue: Double, maxValue: Double, frame: NSRect) -> NativeHandle {
        let step = (maxValue - minValue) / 100
        let s = gtk_scale_new_with_range(GTK_ORIENTATION_HORIZONTAL, minValue, maxValue, step == 0 ? 1 : step)!
        gtk_range_set_value(asRange(OpaquePointer(s)), value)
        gtk_widget_set_size_request(s, Int32(frame.width), Int32(frame.height))
        let h = allocate(s, .slider, frame: frame)
        ranges[h.rawValue] = (minValue, maxValue)
        return h
    }
    public func createProgressIndicator(value: Double, minValue: Double, maxValue: Double, frame: NSRect) -> NativeHandle {
        let p = gtk_progress_bar_new()!
        gtk_widget_set_size_request(p, Int32(frame.width), Int32(frame.height))
        let h = allocate(p, .progress, frame: frame)
        ranges[h.rawValue] = (minValue, maxValue)
        setDoubleValue(value, for: h)
        return h
    }
    public func createPopUpButton(items: [String], selectedIndex: Int, frame: NSRect) -> NativeHandle {
        // gtk_drop_down_new_from_strings takes a NULL-terminated C string array;
        // it copies the strings, so the temporaries are freed right after.
        var cStrings: [UnsafePointer<CChar>?] = items.map { UnsafePointer(strdup($0)) }
        cStrings.append(nil)
        let widget = cStrings.withUnsafeBufferPointer { gtk_drop_down_new_from_strings($0.baseAddress) }!
        for s in cStrings where s != nil { free(UnsafeMutableRawPointer(mutating: s)) }
        if selectedIndex >= 0 { gtk_drop_down_set_selected(OpaquePointer(widget), guint(selectedIndex)) }
        gtk_widget_set_size_request(widget, Int32(frame.width), Int32(frame.height))
        return allocate(widget, .popUp, frame: frame)
    }
    public func createStepper(value: Double, minValue: Double, maxValue: Double, stepSize: Double, frame: NSRect) -> NativeHandle {
        let sb = gtk_spin_button_new_with_range(minValue, maxValue, stepSize == 0 ? 1 : stepSize)!
        gtk_spin_button_set_value(OpaquePointer(sb), value)   // GtkSpinButton is opaque
        gtk_widget_set_size_request(sb, Int32(frame.width), Int32(frame.height))
        let h = allocate(sb, .stepper, frame: frame)
        ranges[h.rawValue] = (minValue, maxValue)
        return h
    }
    public func createLevelIndicator(value: Double, minValue: Double, maxValue: Double, frame: NSRect) -> NativeHandle {
        let lb = gtk_level_bar_new_for_interval(minValue, maxValue)!
        gtk_level_bar_set_value(OpaquePointer(lb), value)   // GtkLevelBar is opaque
        gtk_widget_set_size_request(lb, Int32(frame.width), Int32(frame.height))
        let h = allocate(lb, .level, frame: frame)
        ranges[h.rawValue] = (minValue, maxValue)
        return h
    }
    public func createTextView(text: String, frame: NSRect) -> NativeHandle {
        let tv = gtk_text_view_new()!
        let buffer = gtk_text_view_get_buffer(asTextView(OpaquePointer(tv)))
        gtk_text_buffer_set_text(buffer, text, -1)   // GtkTextBuffer is opaque
        gtk_widget_set_size_request(tv, Int32(frame.width), Int32(frame.height))
        return allocate(tv, .textView, frame: frame)
    }
    public func createDatePicker(date: Date, frame: NSRect) -> NativeHandle {
        let cal = gtk_calendar_new()!
        gtk_widget_set_size_request(cal, Int32(frame.width), Int32(frame.height))
        let h = allocate(cal, .datePicker, frame: frame)
        setDateValue(date, for: h)
        return h
    }
    public func createColorWell(color: NSColor, frame: NSRect) -> NativeHandle {
        // GtkColorButton (via the GtkColorChooser interface) is deprecated in
        // GTK 4.10 like GtkComboBoxText, but remains the direct color-well
        // analog; the non-deprecated GtkColorDialogButton is async-only.
        let cb = gtk_color_button_new()!
        // Non-modal: a modal chooser grabs all input, and if the dialog fails to
        // map (seen over XQuartz) the whole app looks hung and cannot be closed.
        gtk_color_button_set_modal(OpaquePointer(cb), gboolean(0))
        gtk_widget_set_size_request(cb, Int32(frame.width), Int32(frame.height))
        let h = allocate(cb, .colorWell, frame: frame)
        setColor(color, for: h)
        return h
    }
    public func createTabView(frame: NSRect) -> NativeHandle {
        let nb = gtk_notebook_new()!
        gtk_widget_set_size_request(nb, Int32(frame.width), Int32(frame.height))
        gtk_widget_set_hexpand(nb, gboolean(1))
        gtk_widget_set_vexpand(nb, gboolean(1))
        return allocate(nb, .tabView, frame: frame)
    }
    public func addTabPage(_ page: NativeHandle, label: String, to tabView: NativeHandle) {
        guard let nb = widget(tabView), let p = widget(page) else { return }
        let tabLabel = gtk_label_new(label)
        gtk_notebook_append_page(nb, asWidget(p), tabLabel)   // GtkNotebook is opaque
    }
    public func createSegmentedControl(labels: [String], frame: NSRect) -> NativeHandle {
        // Composed control: linked GtkToggleButtons in a horizontal box — the
        // native GTK idiom for a segmented switcher ("linked" style class).
        let box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
        gtk_widget_add_css_class(box, "linked")
        gtk_widget_set_size_request(box, Int32(frame.width), Int32(frame.height))
        let h = allocate(box, .segmented, frame: frame)

        var buttons: [OpaquePointer] = []
        for label in labels {
            let tb = gtk_toggle_button_new_with_label(label)!
            if let first = buttons.first {
                gtk_toggle_button_set_group(asToggle(OpaquePointer(tb)), asToggle(first))
            }
            gtk_box_append(asBox(OpaquePointer(box)), tb)
            buttons.append(OpaquePointer(tb))
        }
        segmentButtons[h.rawValue] = buttons
        return h
    }
    public func createBox(title: String, frame: NSRect) -> NativeHandle {
        let f = gtk_frame_new(title)!
        gtk_widget_set_size_request(f, Int32(frame.width), Int32(frame.height))
        return allocate(f, .box, frame: frame)
    }
    public func createScrollView(frame: NSRect) -> NativeHandle {
        let sw = gtk_scrolled_window_new()!
        gtk_widget_set_size_request(sw, Int32(frame.width), Int32(frame.height))
        return allocate(sw, .scrollView, frame: frame)
    }
    public func createSplitView(vertical: Bool, frame: NSRect) -> NativeHandle {
        // AppKit "vertical" = vertical divider = panes side by side, which is
        // GTK's *horizontal* orientation.
        let orientation = vertical ? GTK_ORIENTATION_HORIZONTAL : GTK_ORIENTATION_VERTICAL
        let paned = gtk_paned_new(orientation)!
        gtk_widget_set_size_request(paned, Int32(frame.width), Int32(frame.height))
        return allocate(paned, .splitView, frame: frame)
    }
    public func addSplitPane(_ pane: NativeHandle, to splitView: NativeHandle) {
        guard let paned = widget(splitView), let p = widget(pane) else { return }
        let count = splitPaneCounts[splitView.rawValue, default: 0]
        if count == 0 {
            gtk_paned_set_start_child(paned, asWidget(p))   // GtkPaned is opaque
        } else {
            gtk_paned_set_end_child(paned, asWidget(p))
        }
        splitPaneCounts[splitView.rawValue] = count + 1
    }
    public func setDividerPosition(_ position: Double, for splitView: NativeHandle) {
        guard let paned = widget(splitView) else { return }
        gtk_paned_set_position(paned, gint(position))
    }
    public func addSubview(_ child: NativeHandle, to parent: NativeHandle) {
        guard let p = widget(parent), let c = widget(child) else { return }
        parents[child.rawValue] = parent.rawValue
        let childFrame = frames[child.rawValue] ?? .zero
        // Flip AppKit's bottom-left origin to GTK's top-left for placement.
        let parentHeight = frames[parent.rawValue]?.height ?? 0
        let y = CoordinateSpace.gtkY(for: childFrame, parentHeight: parentHeight)
        gtk_fixed_put(asFixed(p), asWidget(c), Double(childFrame.origin.x), Double(y))
    }

    // MARK: Mutators
    public func setText(_ text: String, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        switch kinds[handle.rawValue] {
        case .button:    gtk_button_set_label(asButton(w), text)
        case .label:     gtk_label_set_text(w, text)          // GtkLabel is opaque
        case .textField, .secureField, .searchField: gtk_editable_set_text(w, text)
        case .comboBox:  if let e = comboEntries[handle.rawValue] { gtk_editable_set_text(e, text) }
        case .checkbox, .radio: gtk_check_button_set_label(asCheckButton(w), text)
        case .textView:  gtk_text_buffer_set_text(gtk_text_view_get_buffer(asTextView(w)), text, -1)
        case .box:       gtk_frame_set_label(asFrame(w), text)
        case .window:    gtk_window_set_title(asWindow(w), text)
        default: break
        }
    }
    public func setFrame(_ frame: NSRect, for handle: NativeHandle) {
        frames[handle.rawValue] = frame
        guard let w = widget(handle) else { return }

        if kinds[handle.rawValue] == .window {
            // GTK4 delegates live window sizing to the compositor; set the
            // default so an unmapped window opens at the requested size.
            gtk_window_set_default_size(asWindow(w), Int32(frame.width), Int32(frame.height))
            return
        }

        gtk_widget_set_size_request(asWidget(w), Int32(frame.width), Int32(frame.height))

        // If placed in a parent GtkFixed, move to the new (flipped) position.
        if let parentRaw = parents[handle.rawValue], let p = widgets[parentRaw] {
            let parentHeight = frames[parentRaw]?.height ?? 0
            let y = CoordinateSpace.gtkY(for: frame, parentHeight: parentHeight)
            gtk_fixed_move(asFixed(p), asWidget(w), Double(frame.origin.x), Double(y))
        }
    }
    public func setEnabled(_ isEnabled: Bool, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_widget_set_sensitive(asWidget(w), gboolean(isEnabled ? 1 : 0))
    }
    public func setButtonState(_ on: Bool, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_check_button_set_active(asCheckButton(w), gboolean(on ? 1 : 0))
    }
    public func setDoubleValue(_ value: Double, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        switch kinds[handle.rawValue] {
        case .slider:
            gtk_range_set_value(asRange(w), value)
        case .progress:
            let (lo, hi) = ranges[handle.rawValue] ?? (0, 1)
            let fraction = hi > lo ? (value - lo) / (hi - lo) : 0
            gtk_progress_bar_set_fraction(w, min(1, max(0, fraction)))   // GtkProgressBar is opaque
        case .stepper:
            gtk_spin_button_set_value(w, value)   // GtkSpinButton is opaque
        case .level:
            gtk_level_bar_set_value(w, value)   // GtkLevelBar is opaque
        default: break
        }
    }
    public func setSelectedIndex(_ index: Int, for handle: NativeHandle) {
        guard let w = widget(handle), index >= 0 else { return }
        switch kinds[handle.rawValue] {
        case .tabView: gtk_notebook_set_current_page(w, gint(index))   // GtkNotebook is opaque
        case .segmented:
            guard let buttons = segmentButtons[handle.rawValue], index < buttons.count else { return }
            gtk_toggle_button_set_active(asToggle(buttons[index]), gboolean(1))
        default:       gtk_drop_down_set_selected(w, guint(index))     // GtkDropDown is opaque
        }
    }
    public func setDateValue(_ date: Date, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        // GtkCalendar navigates via a GDateTime; unix-local keeps Date exact.
        guard let gdt = g_date_time_new_from_unix_local(gint64(date.timeIntervalSince1970)) else { return }
        gtk_calendar_select_day(w, gdt)   // GtkCalendar is opaque
        g_date_time_unref(gdt)
    }
    public func setColor(_ color: NSColor, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        var rgba = GdkRGBA(
            red: Float(color.redComponent), green: Float(color.greenComponent),
            blue: Float(color.blueComponent), alpha: Float(color.alphaComponent)
        )
        gtk_color_chooser_set_rgba(w, &rgba)   // GtkColorChooser is opaque
    }
    public func destroyControl(_ handle: NativeHandle) {
        let r = handle.rawValue
        if kinds[r] == .window, let w = widgets[r] {
            gtk_window_destroy(asWindow(w))
        }
        widgets[r] = nil; kinds[r] = nil; frames[r] = nil; parents[r] = nil
    }

    // MARK: Events
    public func registerAction(for handle: NativeHandle, action: @escaping () -> Void) {
        guard let w = widget(handle) else { return }
        let box = ActionBox(action)
        g_signal_connect_data(
            UnsafeMutableRawPointer(w), "clicked",
            unsafeBitCast(gtkActionTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }
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
        // A combo emits text changes on its internal entry, not the combo itself.
        let target = (kinds[handle.rawValue] == .comboBox) ? comboEntries[handle.rawValue] : widget(handle)
        guard let w = target else { return }
        g_signal_connect_data(
            UnsafeMutableRawPointer(w), "changed",
            unsafeBitCast(gtkTextChangedTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }
    public func setToggleAction(for handle: NativeHandle, action: @escaping (Bool) -> Void) {
        guard let w = widget(handle) else { return }
        let box = BoolActionBox(action)
        g_signal_connect_data(
            UnsafeMutableRawPointer(w), "toggled",
            unsafeBitCast(gtkToggledTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }
    public func setValueChangeAction(for handle: NativeHandle, action: @escaping (Double) -> Void) {
        guard let w = widget(handle) else { return }
        let box = DoubleActionBox(action)
        // Both GtkScale (via GtkRange) and GtkSpinButton emit "value-changed", but
        // the value is read from different getters, so pick the right trampoline.
        let trampoline = kinds[handle.rawValue] == .stepper
            ? gtkSpinValueChangedTrampoline : gtkValueChangedTrampoline
        g_signal_connect_data(
            UnsafeMutableRawPointer(w), "value-changed",
            unsafeBitCast(trampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }
    public func setSelectionChangeAction(for handle: NativeHandle, action: @escaping (Int) -> Void) {
        guard let w = widget(handle) else { return }
        let box = IntActionBox(action)
        if kinds[handle.rawValue] == .segmented {
            // One "toggled" hookup per segment; each box carries its index and
            // only fires on activation (the deactivating peer stays quiet).
            for (index, button) in (segmentButtons[handle.rawValue] ?? []).enumerated() {
                let segmentBox = SegmentBox(index: index, action: action)
                g_signal_connect_data(
                    UnsafeMutableRawPointer(button), "toggled",
                    unsafeBitCast(gtkSegmentToggledTrampoline, to: GCallback.self),
                    Unmanaged.passRetained(segmentBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
                )
            }
            return
        }
        if kinds[handle.rawValue] == .tabView {
            // GtkNotebook reports tab changes via "switch-page" (page index arg).
            g_signal_connect_data(
                UnsafeMutableRawPointer(w), "switch-page",
                unsafeBitCast(gtkSwitchPageTrampoline, to: GCallback.self),
                Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
            return
        }
        // GtkDropDown exposes its selection as the "selected" property.
        g_signal_connect_data(
            UnsafeMutableRawPointer(w), "notify::selected",
            unsafeBitCast(gtkSelectionChangedTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }
    public func setDateChangeAction(for handle: NativeHandle, action: @escaping (Date) -> Void) {
        guard let w = widget(handle) else { return }
        let box = DateActionBox(action)
        g_signal_connect_data(
            UnsafeMutableRawPointer(w), "day-selected",
            unsafeBitCast(gtkDaySelectedTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }
    public func setColorChangeAction(for handle: NativeHandle, action: @escaping (NSColor) -> Void) {
        guard let w = widget(handle) else { return }
        let box = ColorActionBox(action)
        g_signal_connect_data(
            UnsafeMutableRawPointer(w), "color-set",
            unsafeBitCast(gtkColorSetTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }
}

// MARK: - GObject signal glue
//
// GTK signal handlers must be bare C function pointers, so the Swift closure is
// boxed and passed as `user_data`; a destroy-notify releases the box when the
// signal is disconnected. These live at file scope because @convention(c)
// closures cannot capture context.

private final class ActionBox {
    let action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
}
private final class StringActionBox {
    let action: (String) -> Void
    init(_ action: @escaping (String) -> Void) { self.action = action }
}
private final class BoolActionBox {
    let action: (Bool) -> Void
    init(_ action: @escaping (Bool) -> Void) { self.action = action }
}
private final class DoubleActionBox {
    let action: (Double) -> Void
    init(_ action: @escaping (Double) -> Void) { self.action = action }
}
private final class IntActionBox {
    let action: (Int) -> Void
    init(_ action: @escaping (Int) -> Void) { self.action = action }
}
private final class DateActionBox {
    let action: (Date) -> Void
    init(_ action: @escaping (Date) -> Void) { self.action = action }
}
private final class SegmentBox {
    let index: Int
    let action: (Int) -> Void
    init(index: Int, action: @escaping (Int) -> Void) { self.index = index; self.action = action }
}
private final class ColorActionBox {
    let action: (NSColor) -> Void
    init(_ action: @escaping (NSColor) -> Void) { self.action = action }
}

/// Handler for `GtkButton::clicked` — `void (*)(GtkButton*, gpointer)`.
private let gtkActionTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { _, userData in
    guard let userData else { return }
    Unmanaged<ActionBox>.fromOpaque(userData).takeUnretainedValue().action()
}

/// Handler for `GtkWindow::close-request` — returns gboolean (false = allow close).
private let gtkCloseRequestTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> gboolean = { _, userData in
    if let userData {
        Unmanaged<ActionBox>.fromOpaque(userData).takeUnretainedValue().action()
    }
    return gboolean(0)
}

/// Handler for `GtkEditable::changed` — reads the new text off the widget.
private let gtkTextChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { editable, userData in
    guard let editable, let userData else { return }
    let cText = gtk_editable_get_text(OpaquePointer(editable))
    let text = cText.map { String(cString: $0) } ?? ""
    Unmanaged<StringActionBox>.fromOpaque(userData).takeUnretainedValue().action(text)
}

/// Handler for `GtkCheckButton::toggled` — reads the new active state.
private let gtkToggledTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { button, userData in
    guard let button, let userData else { return }
    let active = gtk_check_button_get_active(UnsafeMutablePointer<GtkCheckButton>(OpaquePointer(button))) != 0
    Unmanaged<BoolActionBox>.fromOpaque(userData).takeUnretainedValue().action(active)
}

/// Handler for `GtkRange::value-changed` — reads the new slider value.
private let gtkValueChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { range, userData in
    guard let range, let userData else { return }
    let value = gtk_range_get_value(UnsafeMutablePointer<GtkRange>(OpaquePointer(range)))
    Unmanaged<DoubleActionBox>.fromOpaque(userData).takeUnretainedValue().action(value)
}

/// Handler for `GtkSpinButton::value-changed` — reads the spin button's value.
private let gtkSpinValueChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { spin, userData in
    guard let spin, let userData else { return }
    let value = gtk_spin_button_get_value(OpaquePointer(spin))
    Unmanaged<DoubleActionBox>.fromOpaque(userData).takeUnretainedValue().action(value)
}

/// Handler for `GtkTextBuffer::changed` — reads the whole buffer text.
private let gtkTextBufferChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { buffer, userData in
    guard let buffer, let userData else { return }
    var start = GtkTextIter()
    var end = GtkTextIter()
    let buf = UnsafeMutablePointer<GtkTextBuffer>(OpaquePointer(buffer))   // GtkTextBuffer is nominal
    gtk_text_buffer_get_bounds(buf, &start, &end)
    let cText = gtk_text_buffer_get_text(buf, &start, &end, gboolean(0))
    let text = cText.map { String(cString: $0) } ?? ""
    if let cText { g_free(cText) }
    Unmanaged<StringActionBox>.fromOpaque(userData).takeUnretainedValue().action(text)
}

/// Handler for `GtkDropDown::notify::selected` — a GObject notify handler, so it
/// takes an extra GParamSpec argument before the user data.
private let gtkSelectionChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { dropdown, _, userData in
    guard let dropdown, let userData else { return }
    let index = Int(gtk_drop_down_get_selected(OpaquePointer(dropdown)))
    Unmanaged<IntActionBox>.fromOpaque(userData).takeUnretainedValue().action(index)
}

/// Handler for a segment's `GtkToggleButton::toggled` — fires only when the
/// segment becomes active, passing its index.
private let gtkSegmentToggledTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { button, userData in
    guard let button, let userData else { return }
    guard gtk_toggle_button_get_active(UnsafeMutablePointer<GtkToggleButton>(OpaquePointer(button))) != 0 else { return }
    let box = Unmanaged<SegmentBox>.fromOpaque(userData).takeUnretainedValue()
    box.action(box.index)
}

/// Handler for `GSimpleAction::activate` — `void (*)(GSimpleAction*, GVariant*,
/// gpointer)`; runs a menu item's action.
private let gtkMenuActivateTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { _, _, userData in
    guard let userData else { return }
    Unmanaged<ActionBox>.fromOpaque(userData).takeUnretainedValue().action()
}

/// Handler for `GtkNotebook::switch-page` — `void (*)(GtkNotebook*, GtkWidget*,
/// guint page_num, gpointer)`; passes the new page index.
private let gtkSwitchPageTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, guint, gpointer?) -> Void = { _, _, pageNum, userData in
    guard let userData else { return }
    Unmanaged<IntActionBox>.fromOpaque(userData).takeUnretainedValue().action(Int(pageNum))
}

/// Handler for `GtkCalendar::day-selected` — reads the calendar's date.
private let gtkDaySelectedTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { calendar, userData in
    guard let calendar, let userData else { return }
    guard let gdt = gtk_calendar_get_date(OpaquePointer(calendar)) else { return }
    let date = Date(timeIntervalSince1970: TimeInterval(g_date_time_to_unix(gdt)))
    g_date_time_unref(gdt)
    Unmanaged<DateActionBox>.fromOpaque(userData).takeUnretainedValue().action(date)
}

/// Handler for `GtkColorButton::color-set` — reads the chosen RGBA.
private let gtkColorSetTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { button, userData in
    guard let button, let userData else { return }
    var rgba = GdkRGBA(red: 0, green: 0, blue: 0, alpha: 0)
    gtk_color_chooser_get_rgba(OpaquePointer(button), &rgba)
    let color = NSColor(
        red: CGFloat(rgba.red), green: CGFloat(rgba.green),
        blue: CGFloat(rgba.blue), alpha: CGFloat(rgba.alpha)
    )
    Unmanaged<ColorActionBox>.fromOpaque(userData).takeUnretainedValue().action(color)
}

/// Releases a boxed closure of any box type when GLib tears the connection down.
private let boxRelease: GClosureNotify = { data, _ in
    guard let data else { return }
    Unmanaged<AnyObject>.fromOpaque(data).release()
}
#endif
