#if canImport(CGTK)
import CGTK
import CGTKCompat
import Foundation

extension GTKNativeControlBackend {
    internal func installToolbarStyle() {
        guard let display = gdk_display_get_default() else { return }
        // Colors are expressed against GTK's theme-named colors (not literals)
        // so the strip tracks the app appearance: a subtle light gradient in
        // Aqua, a subtle dark one in Dark Aqua — matching macOS, whose toolbar
        // also follows the system appearance. Hover/active and the hairline use
        // the foreground color at low alpha, which reads correctly in both.
        let css = """
            .linchocolate-toolbar {
                padding: 5px 8px;
                background: linear-gradient(to bottom, shade(@theme_bg_color, 1.06), shade(@theme_bg_color, 0.98));
                border-bottom: 1px solid alpha(@theme_fg_color, 0.18);
            }
            .linchocolate-toolbar button {
                background: none; border: none; box-shadow: none;
                padding: 3px 12px; border-radius: 6px;
            }
            .linchocolate-toolbar button:hover { background: alpha(@theme_fg_color, 0.10); }
            .linchocolate-toolbar button:active { background: alpha(@theme_fg_color, 0.18); }
            .linchocolate-palette-tile {
                background: alpha(@theme_fg_color, 0.04);
                border: 1px solid alpha(@theme_fg_color, 0.12);
                border-radius: 8px; box-shadow: none; padding: 4px;
            }
            .linchocolate-palette-tile:hover { background: alpha(@theme_fg_color, 0.09); }
            .linchocolate-palette-tile:checked {
                background: alpha(@theme_selected_bg_color, 0.22);
                border-color: alpha(@theme_selected_bg_color, 0.65);
            }
            """
        guard let provider = gtk_css_provider_new() else { return }
        lc_css_provider_load(provider, css)
        gtk_style_context_add_provider_for_display(display, OpaquePointer(provider), 600)
    }

    /// Popovers (menus, dropdowns) draw a drop shadow and rounded corners that
    /// need an alpha channel. On a non-composited display (XQuartz over TCP,
    /// Xvfb) that transparent region renders solid black, so flatten popovers
    /// there: no shadow, square corners, a hairline border instead. Composited
    /// displays (real Linux desktops, WSLg) keep the native look.
    internal func applyNonCompositedFixups() {
        guard let display = gdk_display_get_default() else { return }
        guard gdk_display_is_composited(display) == 0 else { return }
        nonComposited = true
        let css = """
            popover { margin: 0; padding: 0; border-radius: 0; background: #fafafa; }
            popover > contents { margin: 0; box-shadow: none; border-radius: 0; border: 1px solid rgba(0,0,0,0.25); }
            """
        guard let provider = gtk_css_provider_new() else { return }
        lc_css_provider_load(provider, css)
        // 600 = GTK_STYLE_PROVIDER_PRIORITY_APPLICATION (macro doesn't import).
        gtk_style_context_add_provider_for_display(display, OpaquePointer(provider), 600)
    }

    // MARK: Handle bookkeeping
    internal func allocate(_ widget: UnsafeMutablePointer<GtkWidget>, _ kind: InMemoryNativeControlBackend.Kind, frame: NSRect) -> NativeHandle {
        defer { nextRaw += 1 }
        widgets[nextRaw] = OpaquePointer(widget)
        kinds[nextRaw] = kind
        frames[nextRaw] = frame
        return NativeHandle(rawValue: nextRaw)
    }
    internal func widget(_ h: NativeHandle) -> OpaquePointer? { widgets[h.rawValue] }

    // MARK: Pointer upcasts (stand-ins for GTK_*() macros)
    internal func asWidget(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkWidget> { .init(p) }
    internal func asWindow(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkWindow> { .init(p) }
    internal func asFixed(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkFixed> { .init(p) }
    internal func asButton(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkButton> { .init(p) }
    internal func asCheckButton(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkCheckButton> { .init(p) }
    internal func asToggleButton(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkToggleButton> { .init(p) }
    internal func asGrid(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkGrid> { .init(p) }
    internal func asRange(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkRange> { .init(p) }
    internal func asTextView(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkTextView> { .init(p) }
    internal func asTextBuffer(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkTextBuffer> { .init(p) }
    internal func asFrame(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkFrame> { .init(p) }
    internal func asBox(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkBox> { .init(p) }
    internal func asToggle(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkToggleButton> { .init(p) }
    internal func asPopover(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkPopover> { .init(p) }
    internal func asMenuModel(_ p: OpaquePointer) -> UnsafeMutablePointer<GMenuModel> { .init(p) }
    // GtkProgressBar, GtkDropDown, GtkLevelBar and GtkSpinButton are opaque in the
    // import — their functions take OpaquePointer directly. GtkTextBuffer is nominal.
    // NOTE: GtkLabel, GtkEditable, and GMainLoop are opaque in the GTK4 Swift
    // import (no nominal type), so their functions take/return OpaquePointer.
    // GtkWindow/GtkButton/GtkCheckButton/GtkFixed do import as nominal types.

    // MARK: Application lifecycle
    /// Installs the main-actor executor and runs a `GMainLoop` until `terminateApplication` quits it.
    public func runApplication() {
        // Route Task { @MainActor } onto GTK's loop, or those jobs never run
        // (nothing else pumps Swift's main-actor executor under g_main_loop_run).
        installGLibMainActorExecutor()
        guard let loop = g_main_loop_new(nil, gboolean(0)) else { return }
        mainLoop = loop
        g_main_loop_run(loop)
    }
    /// Quits every running `GMainLoop` — the app's, plus any nested loop a
    /// modal is spinning. Quitting only the outer loop leaves a modal's loop
    /// running and the app never exits, which is what made Quit look dead after
    /// an alert was dismissed by closing its window.
    public func terminateApplication() {
        for loop in nestedLoops.reversed() { g_main_loop_quit(loop) }
        nestedLoops.removeAll()
        stoppingNestedLoops.removeAll()
        guard let loop = mainLoop else { return }
        g_main_loop_quit(loop)
    }

    /// Nested modal loops are tracked innermost last.
    /// Records a modal's loop so `terminateApplication` can end it.
    func pushNestedLoop(_ loop: OpaquePointer?) {
        if let loop { nestedLoops.append(loop) }
    }
    /// Drops the innermost modal loop once it has finished.
    func popNestedLoop() {
        if let loop = nestedLoops.popLast() {
            stoppingNestedLoops.remove(loop)
        }
    }

    /// Schedules `block` on GTK's main loop via `g_timeout_add`.
    public func scheduleTimer(interval: Double, repeats: Bool, _ block: @escaping () -> Void) {
        var block = block
        if paintTrace {
            let original = block
            let every = interval
            let start = paintTraceStart
            block = {
                let ms = Double(g_get_monotonic_time() - start) / 1000.0
                FileHandle.standardError.write(
                    Data(String(format: "LCPAINT %8.1fms [timer] every=%.2fs\n", ms, every).utf8))
                original()
            }
        }
        // Foundation's Timer lands on RunLoop.main, which is (a) never pumped
        // under g_main_loop_run and (b) broken for repeating timers on
        // swift-corelibs-foundation 6.0.3 anyway (RunLoop.run fires a repeating
        // timer exactly once, then blocks). So drive it off GTK's own loop.
        let box = TimerBox(block: block, repeats: repeats)
        g_timeout_add(guint(max(1, interval * 1000)), { userData in
            guard let userData else { return gboolean(0) }
            let box = Unmanaged<TimerBox>.fromOpaque(userData).takeUnretainedValue()
            box.block()
            if box.repeats { return gboolean(1) }        // G_SOURCE_CONTINUE
            Unmanaged<TimerBox>.fromOpaque(userData).release()
            return gboolean(0)                           // G_SOURCE_REMOVE
        }, Unmanaged.passRetained(box).toOpaque())
    }

    // MARK: Appearance
    /// Toggles GTK's display-wide dark-theme preference. GtkSettings has no
    /// typed setter for this property, and `g_object_set` is C-variadic
    /// (uncallable from Swift), so set it through a GValue.
    public func setAppearanceDark(_ dark: Bool) {
        prefersDarkAppearance = dark
        guard let settings = gtk_settings_get_default() else { return }
        var value = GValue()
        _ = g_value_init(&value, GType(5 << 2))   // G_TYPE_BOOLEAN = 5 << G_TYPE_FUNDAMENTAL_SHIFT
        g_value_set_boolean(&value, gboolean(dark ? 1 : 0))
        g_object_set_property(UnsafeMutablePointer<GObject>(settings),
                              "gtk-application-prefer-dark-theme", &value)
        g_value_unset(&value)
    }

    // MARK: Pasteboard & drag-and-drop

    /// Copies `string` to the GDK default clipboard (and caches it locally).
    public func setClipboardString(_ string: String) {
        clipboardMirror = string
        guard let display = gdk_display_get_default() else { return }
        let clipboard = gdk_display_get_clipboard(display)
        var value = GValue()
        _ = g_value_init(&value, GType(16 << 2))   // G_TYPE_STRING
        g_value_set_string(&value, string)
        gdk_clipboard_set_value(clipboard, &value)
        g_value_unset(&value)
    }

    // System-clipboard reads are async in GTK4; return the last value we set.
    // Inbound cross-app paste is a later parity item.
    /// Returns the last string written to the clipboard by this process.
    public func clipboardString() -> String? { clipboardMirror }

    /// Attaches a `GtkDropTarget` accepting strings; delivers drops via `onDrop`.
    public func registerDropTarget(for handle: NativeHandle, types: [String], onDrop: @escaping (String, Double, Double) -> Bool) {
        guard let w = widget(handle) else { return }
        // String drops only in this slice (G_TYPE_STRING); copy is enough.
        let target = gtk_drop_target_new(GType(16 << 2), GDK_ACTION_COPY)
        let box = DropBox(onDrop)
        g_signal_connect_data(
            UnsafeMutableRawPointer(target), "drop",
            unsafeBitCast(gtkDropTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        gtk_widget_add_controller(asWidget(w), target)
    }

    /// Attaches a `GtkDragSource` whose payload is the string produced by `provider`.
    public func registerDragSource(for handle: NativeHandle, provider: @escaping () -> String?) {
        guard let w = widget(handle) else { return }
        let source = gtk_drag_source_new()
        let box = DragProviderBox(provider)
        g_signal_connect_data(
            UnsafeMutableRawPointer(source), "prepare",
            unsafeBitCast(gtkDragPrepareTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        gtk_widget_add_controller(asWidget(w), source)
    }

    // MARK: Windows
    /// Creates a `GtkWindow` sized to `frame`, hosting a vertical `GtkBox` for the menu bar + content view.
    public func createWindow(title: String, frame: NSRect, styleMask: NSWindow.StyleMask) -> NativeHandle {
        let win = gtk_window_new()!
        let h = allocate(win, .window, frame: frame)
        let p = widget(h)!
        gtk_window_set_title(asWindow(p), title)
        // Honour the style mask instead of accepting and ignoring it: a window
        // with no title bar must not be decorated, and one that cannot be closed
        // must not offer a close button. Telling the WM this up front avoids it
        // decorating the window and then being corrected.
        gtk_window_set_decorated(asWindow(p), gboolean(styleMask.contains(.titled) ? 1 : 0))
        gtk_window_set_deletable(asWindow(p), gboolean(styleMask.contains(.closable) ? 1 : 0))
        // Deliberately NO `gtk_window_set_default_size` here. `frame` is AppKit's
        // CONTENT rect, while the GTK window also holds the menu bar and toolbar,
        // so a default size of the content alone is too short: the window maps at
        // that size and then has to grow to its natural size, and under a real
        // window manager that second sizing is a visible map-then-repaint. The
        // content view carries its own size request, so GTK's natural size is
        // already content + chrome — exactly the window AppKit's contentRect
        // describes — and it gets there in one step.
        // The window's real child is a vertical box: [menu bar?][content view].
        // This keeps a slot for `installMenuBar` above the AppKit content view.
        let box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        gtk_window_set_child(asWindow(p), box)
        windowBoxes[h.rawValue] = OpaquePointer(box)
        installPopoverDismissFallback(on: asWidget(p))
        return h
    }

    /// Popovers normally dismiss on outside click via a pointer grab, but that
    /// grab does not take effect on non-composited X11 (XQuartz), leaving open
    /// popovers stuck. Fallback: a capture-phase click handler on the window
    /// that pops down any *other* open popover before the click lands. Clicks
    /// inside a popover are on its own surface and never reach this handler, so
    /// item activation is unaffected.
    ///
    /// We deliberately do NOT dismiss on `notify::is-active`: opening an
    /// autohide popover briefly deactivates the toplevel window (the popover
    /// grabs its own surface), and reacting to that would pop the popover down
    /// the instant it opens — which broke the combo-box dropdown and `NSPopover`.
    internal func installPopoverDismissFallback(on windowWidget: UnsafeMutablePointer<GtkWidget>) {
        guard nonComposited else { return }
        let gesture = gtk_gesture_click_new()!
        // GtkEventController is opaque; the gesture pointer doubles as one.
        gtk_event_controller_set_propagation_phase(gesture, GTK_PHASE_CAPTURE)
        let box = WidgetBox(widget: windowWidget)
        g_signal_connect_data(
            UnsafeMutableRawPointer(gesture), "pressed",
            unsafeBitCast(gtkDismissPopoversTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        gtk_widget_add_controller(windowWidget, gesture)
    }
    /// Installs `view` as the window's (or box/scroll-view's) content, routed by kind.
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
            contentViewOwners[view.rawValue] = window.rawValue
        }
    }
    /// Emits one paint-trace line for `raw`: elapsed ms, the window's own size,
    /// its content view's allocation, and the GTK frame counter.
    internal func tracePaint(_ raw: UInt, _ event: String) {
        guard paintTrace, let w = widgets[raw] else { return }
        let ms = Double(g_get_monotonic_time() - paintTraceStart) / 1000.0
        let widget = asWidget(w)
        let ww = gtk_widget_get_width(widget), wh = gtk_widget_get_height(widget)
        var content = "content=none"
        if let c = windowContents[raw] {
            content = "content=\(gtk_widget_get_width(asWidget(c)))x\(gtk_widget_get_height(asWidget(c)))"
        }
        var frame = ""
        if let clock = gtk_widget_get_frame_clock(widget) {
            frame = " frame=\(gdk_frame_clock_get_frame_counter(clock))"
        }
        // The GdkSurface is what the X server actually shows. GTK's allocation
        // (win=) is only computed on the frame clock, so it reads 0 before the
        // first cycle even when the real window is already the right size — the
        // two together separate "bookkeeping not filled in yet" from "the window
        // on screen is genuinely the wrong size".
        var surface = " surface=none"
        if let native = gtk_widget_get_native(widget), let s = gtk_native_get_surface(native) {
            surface = " surface=\(gdk_surface_get_width(s))x\(gdk_surface_get_height(s))"
        }
        // Flag the two signatures that matter: a size change (re-layout) versus a
        // repeat at the same size (damage/expose).
        var note = ""
        if let last = paintTraceLastSize[raw], last != (ww, wh) {
            note = "  ← SIZE CHANGED \(last.0)x\(last.1) → \(ww)x\(wh)"
        }
        paintTraceLastSize[raw] = (ww, wh)
        let title = gtk_window_get_title(asWindow(w)).map { String(cString: $0) } ?? "?"
        // The number this whole investigation turns on: how long the window sat
        // on screen before anything was painted into it. Reported once, in
        // plain sight, so nobody has to subtract timestamps by hand.
        if event == "map" { paintTraceMapped[raw] = g_get_monotonic_time() }
        if event.hasPrefix("draw#1"), !paintTraceReported.contains(raw),
           let mapped = paintTraceMapped[raw] {
            paintTraceReported.insert(raw)
            let delay = Double(g_get_monotonic_time() - mapped) / 1000.0
            FileHandle.standardError.write(
                Data(String(format: "LCPAINT ======== [%@] FIRST FRAME %.1f ms after map ========\n",
                            title as NSString, delay).utf8))
        }
        FileHandle.standardError.write(
            Data(String(format: "LCPAINT %8.1fms [%@] %-12@ win=%dx%d %@%@%@\n",
                        ms, title as NSString, event as NSString, Int(ww), Int(wh),
                        (content + surface) as NSString, frame as NSString, note as NSString).utf8))
    }

    /// Hooks the window's lifecycle and its frame clock so every paint cycle is
    /// visible. Installed once, at first present, when tracing is on.
}

#endif
