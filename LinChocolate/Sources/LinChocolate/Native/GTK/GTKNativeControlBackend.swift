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
    // GtkProgressBar and GtkDropDown are opaque in the import — their functions
    // take OpaquePointer directly (no cast helper needed).
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
        return h
    }
    public func setContentView(_ view: NativeHandle, for window: NativeHandle) {
        guard let w = widget(window), let v = widget(view) else { return }
        gtk_window_set_child(asWindow(w), asWidget(v))
    }
    public func showWindow(_ handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_window_present(asWindow(w))
    }
    public func setWindowTitle(_ title: String, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_window_set_title(asWindow(w), title)
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
        default: break
        }
    }
    public func setSelectedIndex(_ index: Int, for handle: NativeHandle) {
        guard let w = widget(handle), index >= 0 else { return }
        gtk_drop_down_set_selected(w, guint(index))   // GtkDropDown is opaque
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
        // A combo emits text changes on its internal entry, not the combo itself.
        let target = (kinds[handle.rawValue] == .comboBox) ? comboEntries[handle.rawValue] : widget(handle)
        guard let w = target else { return }
        let box = StringActionBox(action)
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
        g_signal_connect_data(
            UnsafeMutableRawPointer(w), "value-changed",
            unsafeBitCast(gtkValueChangedTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }
    public func setSelectionChangeAction(for handle: NativeHandle, action: @escaping (Int) -> Void) {
        guard let w = widget(handle) else { return }
        let box = IntActionBox(action)
        // GtkDropDown exposes its selection as the "selected" property.
        g_signal_connect_data(
            UnsafeMutableRawPointer(w), "notify::selected",
            unsafeBitCast(gtkSelectionChangedTrampoline, to: GCallback.self),
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

/// Handler for `GtkDropDown::notify::selected` — a GObject notify handler, so it
/// takes an extra GParamSpec argument before the user data.
private let gtkSelectionChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { dropdown, _, userData in
    guard let dropdown, let userData else { return }
    let index = Int(gtk_drop_down_get_selected(OpaquePointer(dropdown)))
    Unmanaged<IntActionBox>.fromOpaque(userData).takeUnretainedValue().action(index)
}

/// Releases a boxed closure of any box type when GLib tears the connection down.
private let boxRelease: GClosureNotify = { data, _ in
    guard let data else { return }
    Unmanaged<AnyObject>.fromOpaque(data).release()
}
#endif
