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
    private var viewFixeds: [UInt: OpaquePointer] = [:]      // view -> child-hosting GtkFixed
    private var viewDrawAreas: [UInt: OpaquePointer] = [:]   // view -> GtkDrawingArea
    private var drawHandlers: [UInt: (NativeGraphicsContext, Double, Double) -> Void] = [:]
    private var windowBoxes: [UInt: OpaquePointer] = [:]     // window -> vertical GtkBox child
    private var windowContents: [UInt: OpaquePointer] = [:]  // window -> current content widget
    private var windowMenuBars: [UInt: OpaquePointer] = [:]  // window -> GtkPopoverMenuBar
    private var windowToolbars: [UInt: OpaquePointer] = [:]  // window -> toolbar GtkBox
    private var windowToolbarViews: [UInt: [OpaquePointer]] = [:] // window -> embedded view widgets (survive rebuild)
    private var segmentButtons: [UInt: [OpaquePointer]] = [:] // segmented -> its toggle buttons
    private var tokenEntries: [UInt: OpaquePointer] = [:]     // token field -> its entry
    private var tokenChips: [UInt: [OpaquePointer]] = [:]     // token field -> chip buttons
    private var tokenValues: [UInt: [String]] = [:]           // token field -> tokens
    private var tokenActions: [UInt: ([String]) -> Void] = [:]
    private var tableColumnViews: [UInt: OpaquePointer] = [:] // table -> GtkColumnView
    private var tableSelections: [UInt: OpaquePointer] = [:]  // table -> GtkSingleSelection
    private var tableLists: [UInt: OpaquePointer] = [:]       // table -> GtkStringList model
    private var tableRowCounts: [UInt: Int] = [:]
    private var tableColumnCounts: [UInt: Int] = [:]
    private var tableColumnObjects: [UInt: [OpaquePointer]] = [:] // table -> GtkColumnViewColumn list
    private var tableProviders: [UInt: (Int, Int) -> String] = [:]
    private var tableSortActions: [UInt: (Int, Bool) -> Void] = [:]     // (columnIndex, ascending)
    private var tableActivateActions: [UInt: (Int) -> Void] = [:]       // double-click / Enter (row)
    private var collectionLists: [UInt: OpaquePointer] = [:]  // collection -> GtkStringList
    private var collectionItemCounts: [UInt: Int] = [:]
    private var collectionProviders: [UInt: (Int) -> String] = [:]
    private var outlineColumnViews: [UInt: OpaquePointer] = [:]
    private var outlineRootLists: [UInt: OpaquePointer] = [:]
    private var outlineRootCounts: [UInt: Int] = [:]
    private var outlineColumnCounts: [UInt: Int] = [:]
    private var outlineChildCountProviders: [UInt: (String) -> Int] = [:]
    private var outlineCellTextProviders: [UInt: (String, Int) -> String] = [:]
    private var widgetFonts: [UInt: NativeFontSpec] = [:]     // style state per widget
    private var widgetTextColors: [UInt: NSColor] = [:]
    private var materialProviders: [UInt: OpaquePointer] = [:] // material CSS per visual-effect view
    private var widgetStyleProviders: [UInt: OpaquePointer] = [:]  // current CSS provider
    private var menuActionCounter = 0                         // unique GAction names
    private var nonComposited = false                         // display lacks alpha compositing
    private var mainLoop: OpaquePointer?   // GMainLoop* (opaque in the GTK import)

    /// Connects to the display and initializes GTK. Only construct this when a
    /// display is available (the demo/app), never in headless tests.
    public init() {
        gtk_init()
        applyNonCompositedFixups()
        installToolbarStyle()
    }

    /// Display-wide CSS for the Apple-look toolbar (the deliberate Apple
    /// look-and-feel exception, Goal 2): a light gradient strip with a hairline
    /// bottom border and flat, hover-highlighted text buttons.
    private func installToolbarStyle() {
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
            """
        let provider = gtk_css_provider_new()!
        gtk_css_provider_load_from_data(provider, css, gssize(css.utf8.count))
        gtk_style_context_add_provider_for_display(display, OpaquePointer(provider), 600)
    }

    /// Popovers (menus, dropdowns) draw a drop shadow and rounded corners that
    /// need an alpha channel. On a non-composited display (XQuartz over TCP,
    /// Xvfb) that transparent region renders solid black, so flatten popovers
    /// there: no shadow, square corners, a hairline border instead. Composited
    /// displays (real Linux desktops, WSLg) keep the native look.
    private func applyNonCompositedFixups() {
        guard let display = gdk_display_get_default() else { return }
        guard gdk_display_is_composited(display) == 0 else { return }
        nonComposited = true
        let css = """
            popover { margin: 0; padding: 0; border-radius: 0; background: #fafafa; }
            popover > contents { margin: 0; box-shadow: none; border-radius: 0; border: 1px solid rgba(0,0,0,0.25); }
            """
        let provider = gtk_css_provider_new()!
        gtk_css_provider_load_from_data(provider, css, gssize(css.utf8.count))
        // 600 = GTK_STYLE_PROVIDER_PRIORITY_APPLICATION (macro doesn't import).
        gtk_style_context_add_provider_for_display(display, OpaquePointer(provider), 600)
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
    private func asPopover(_ p: OpaquePointer) -> UnsafeMutablePointer<GtkPopover> { .init(p) }
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

    // MARK: Appearance
    /// Toggles GTK's display-wide dark-theme preference. GtkSettings has no
    /// typed setter for this property, and `g_object_set` is C-variadic
    /// (uncallable from Swift), so set it through a GValue.
    public func setAppearanceDark(_ dark: Bool) {
        guard let settings = gtk_settings_get_default() else { return }
        var value = GValue()
        _ = g_value_init(&value, GType(5 << 2))   // G_TYPE_BOOLEAN = 5 << G_TYPE_FUNDAMENTAL_SHIFT
        g_value_set_boolean(&value, gboolean(dark ? 1 : 0))
        g_object_set_property(UnsafeMutablePointer<GObject>(settings),
                              "gtk-application-prefer-dark-theme", &value)
        g_value_unset(&value)
    }

    // MARK: Pasteboard & drag-and-drop
    private var clipboardMirror: String?

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
    public func clipboardString() -> String? { clipboardMirror }

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
    private func installPopoverDismissFallback(on windowWidget: UnsafeMutablePointer<GtkWidget>) {
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
        // Key equivalents become GtkShortcuts on a window-scoped controller.
        let shortcuts = gtk_shortcut_controller_new()!
        gtk_shortcut_controller_set_scope(shortcuts, GTK_SHORTCUT_SCOPE_MANAGED)
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
                if let accel = item.accelerator {
                    let menuItem = g_menu_item_new(item.title, "win.\(name)")!
                    g_menu_item_set_attribute_value(menuItem, "accel", g_variant_new_string(accel))
                    g_menu_append_item(section, menuItem)
                    g_object_unref(UnsafeMutableRawPointer(menuItem))
                    if let trigger = gtk_shortcut_trigger_parse_string(accel) {
                        let shortcut = gtk_shortcut_new(trigger, gtk_named_action_new("win.\(name)"))
                        gtk_shortcut_controller_add_shortcut(shortcuts, shortcut)
                    }
                } else {
                    g_menu_append(section, item.title, "win.\(name)")
                }
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
        gtk_widget_add_controller(asWidget(w), shortcuts)

        // Replace any existing bar, then put the new one at the top of the box.
        if let oldBar = windowMenuBars[window.rawValue] {
            gtk_box_remove(asBox(box), asWidget(oldBar))
        }
        let bar = gtk_popover_menu_bar_new_from_model(asMenuModel(root))!
        gtk_box_prepend(asBox(box), bar)
        windowMenuBars[window.rawValue] = OpaquePointer(bar)
    }
    public func runAlert(message: String, informative: String, buttons: [String], for window: NativeHandle?) -> Int {
        // Composed modal alert: GTK4 removed blocking dialogs (gtk_dialog_run),
        // and its dialog constructors are C-variadic (uncallable from Swift), so
        // AppKit's synchronous `runModal` is built from a modal GtkWindow plus a
        // nested GMainLoop that runs until a button responds.
        let alert = gtk_window_new()!
        // Modal only on composited displays: on XQuartz a modal window that
        // fails to map grabs all input and the app looks hung (seen with the
        // color chooser). Non-modal still blocks `runModal` via the nested
        // loop, but can never input-lock the app.
        if !nonComposited {
            gtk_window_set_modal(asWindow(OpaquePointer(alert)), gboolean(1))
        }
        gtk_window_set_resizable(asWindow(OpaquePointer(alert)), gboolean(0))
        if let window, let parent = widget(window) {
            gtk_window_set_transient_for(asWindow(OpaquePointer(alert)), asWindow(parent))
        }

        let vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 12)!
        gtk_widget_set_margin_top(vbox, 20); gtk_widget_set_margin_bottom(vbox, 16)
        gtk_widget_set_margin_start(vbox, 24); gtk_widget_set_margin_end(vbox, 24)

        let title = gtk_label_new(message)!
        gtk_widget_add_css_class(title, "title-4")   // GTK's built-in heading style
        gtk_box_append(asBox(OpaquePointer(vbox)), title)
        if !informative.isEmpty {
            let detail = gtk_label_new(informative)!
            gtk_box_append(asBox(OpaquePointer(vbox)), detail)
        }

        let loop = g_main_loop_new(nil, gboolean(0))
        let state = AlertState(loop: loop)

        let buttonRow = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8)!
        gtk_widget_set_halign(buttonRow, GTK_ALIGN_END)
        gtk_widget_set_margin_top(buttonRow, 8)
        // AppKit shows the first (default) button rightmost; append in reverse.
        for (index, buttonTitle) in buttons.enumerated().reversed() {
            let button = gtk_button_new_with_label(buttonTitle)!
            let box = AlertButtonBox(index: index, state: state)
            g_signal_connect_data(
                UnsafeMutableRawPointer(button), "clicked",
                unsafeBitCast(gtkAlertButtonTrampoline, to: GCallback.self),
                Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
            gtk_box_append(asBox(OpaquePointer(buttonRow)), button)
        }
        gtk_box_append(asBox(OpaquePointer(vbox)), buttonRow)

        gtk_window_set_child(asWindow(OpaquePointer(alert)), vbox)
        gtk_window_present(asWindow(OpaquePointer(alert)))
        g_main_loop_run(loop)   // blocks until a button quits the nested loop

        gtk_window_destroy(asWindow(OpaquePointer(alert)))
        return state.response
    }
    public func installToolbar(_ items: [NativeToolbarItemSpec], on window: NativeHandle) {
        guard let box = windowBoxes[window.rawValue] else { return }
        // Detach any embedded custom views (page selector, search field, …) from
        // the old bar first so removing it doesn't destroy widgets we still own.
        for view in windowToolbarViews[window.rawValue] ?? [] {
            if gtk_widget_get_parent(asWidget(view)) != nil {
                gtk_widget_unparent(asWidget(view))
            }
        }
        windowToolbarViews[window.rawValue] = []
        if let old = windowToolbars[window.rawValue] {
            gtk_box_remove(asBox(box), asWidget(old))
        }
        let bar = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 4)!
        gtk_widget_add_css_class(bar, "linchocolate-toolbar")
        for item in items {
            if item.isFlexibleSpace {
                let spacer = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
                gtk_widget_set_hexpand(spacer, gboolean(1))
                gtk_box_append(asBox(OpaquePointer(bar)), spacer)
                continue
            }
            // A view-based item (AppKit's NSToolbarItem.view): embed the control
            // widget itself (a pop-up, a search field, …) rather than a button.
            if let viewHandle = item.viewHandle, let viewWidget = widget(viewHandle) {
                if gtk_widget_get_parent(asWidget(viewWidget)) != nil {
                    gtk_widget_unparent(asWidget(viewWidget))
                }
                gtk_widget_set_valign(asWidget(viewWidget), GTK_ALIGN_CENTER)
                gtk_box_append(asBox(OpaquePointer(bar)), asWidget(viewWidget))
                windowToolbarViews[window.rawValue, default: []].append(viewWidget)
                continue
            }
            let button: UnsafeMutablePointer<GtkWidget>
            if let iconName = item.iconName {
                // Icon above label (the classic macOS toolbar item layout).
                button = gtk_button_new()!
                let content = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2)!
                let icon = gtk_image_new_from_icon_name(iconName)!
                gtk_image_set_pixel_size(OpaquePointer(icon), 22)
                gtk_box_append(asBox(OpaquePointer(content)), icon)
                if !item.label.isEmpty {
                    gtk_box_append(asBox(OpaquePointer(content)), gtk_label_new(item.label))
                }
                gtk_button_set_child(asButton(OpaquePointer(button)), content)
            } else {
                button = gtk_button_new_with_label(item.label)!
            }
            if let action = item.action {
                let actionBox = ActionBox(action)
                g_signal_connect_data(
                    UnsafeMutableRawPointer(button), "clicked",
                    unsafeBitCast(gtkActionTrampoline, to: GCallback.self),
                    Unmanaged.passRetained(actionBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
                )
            }
            gtk_box_append(asBox(OpaquePointer(bar)), button)
        }
        // Below the menu bar if present, else at the very top.
        let anchor = windowMenuBars[window.rawValue]
        gtk_box_insert_child_after(asBox(box), bar, anchor.map(asWidget))
        windowToolbars[window.rawValue] = OpaquePointer(bar)
    }
    public func runToolbarCustomization(_ items: [NativeToolbarPaletteItem],
                                        onToggle: @escaping (String, Bool) -> Void,
                                        onClose: @escaping () -> Void,
                                        for window: NativeHandle) {
        let panel = gtk_window_new()!
        gtk_window_set_title(asWindow(OpaquePointer(panel)), "Customize Toolbar")
        gtk_window_set_resizable(asWindow(OpaquePointer(panel)), gboolean(0))
        if let parent = widget(window) {
            gtk_window_set_transient_for(asWindow(OpaquePointer(panel)), asWindow(parent))
        }
        if !nonComposited { gtk_window_set_modal(asWindow(OpaquePointer(panel)), gboolean(1)) }

        let vbox = gtk_box_new(GTK_ORIENTATION_VERTICAL, 8)!
        gtk_widget_set_margin_top(vbox, 20); gtk_widget_set_margin_bottom(vbox, 16)
        gtk_widget_set_margin_start(vbox, 24); gtk_widget_set_margin_end(vbox, 24)
        let heading = gtk_label_new("Toolbar items:")!
        gtk_widget_add_css_class(heading, "title-4")
        gtk_box_append(asBox(OpaquePointer(vbox)), heading)

        for item in items {
            let check = gtk_check_button_new_with_label(item.label)!
            gtk_check_button_set_active(asCheckButton(OpaquePointer(check)), gboolean(item.isInToolbar ? 1 : 0))
            let toggleBox = ToolbarToggleBox(id: item.identifier, action: onToggle)
            g_signal_connect_data(
                UnsafeMutableRawPointer(check), "toggled",
                unsafeBitCast(gtkToolbarToggleTrampoline, to: GCallback.self),
                Unmanaged.passRetained(toggleBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
            gtk_box_append(asBox(OpaquePointer(vbox)), check)
        }

        let done = gtk_button_new_with_label("Done")!
        let doneBox = ActionBox {
            onClose()
            gtk_window_destroy(UnsafeMutablePointer<GtkWindow>(OpaquePointer(panel)))
        }
        g_signal_connect_data(
            UnsafeMutableRawPointer(done), "clicked",
            unsafeBitCast(gtkActionTrampoline, to: GCallback.self),
            Unmanaged.passRetained(doneBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        gtk_box_append(asBox(OpaquePointer(vbox)), done)

        // The window-close (X) also ends the palette session.
        let closeBox = ActionBox { onClose() }
        g_signal_connect_data(
            UnsafeMutableRawPointer(panel), "close-request",
            unsafeBitCast(gtkCloseRequestTrampoline, to: GCallback.self),
            Unmanaged.passRetained(closeBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )

        gtk_window_set_child(asWindow(OpaquePointer(panel)), vbox)
        gtk_window_present(asWindow(OpaquePointer(panel)))
    }
    public func runOpenPanel(directory: String?, for window: NativeHandle?) -> String? {
        runFileDialog(open: true, directory: directory, suggestedName: nil, for: window)
    }
    public func runSavePanel(directory: String?, suggestedName: String?, for window: NativeHandle?) -> String? {
        runFileDialog(open: false, directory: directory, suggestedName: suggestedName, for: window)
    }

    /// GtkFileDialog is async-only; AppKit's `runModal` is synchronous, so the
    /// async completion quits a nested main loop (same pattern as `runAlert`).
    private func runFileDialog(open: Bool, directory: String?, suggestedName: String?, for window: NativeHandle?) -> String? {
        let dialog = gtk_file_dialog_new()!
        if let directory {
            let folder = g_file_new_for_path(directory)!
            gtk_file_dialog_set_initial_folder(dialog, folder)
            g_object_unref(UnsafeMutableRawPointer(folder))
        }
        if let suggestedName {
            gtk_file_dialog_set_initial_name(dialog, suggestedName)
        }
        let parent = window.flatMap { widget($0) }.map { asWindow($0) }
        let loop = g_main_loop_new(nil, gboolean(0))
        let state = FileDialogState(loop: loop, open: open)
        if open {
            gtk_file_dialog_open(dialog, parent, nil,
                unsafeBitCast(fileDialogFinishedCallback, to: GAsyncReadyCallback.self),
                Unmanaged.passRetained(state).toOpaque())
        } else {
            gtk_file_dialog_save(dialog, parent, nil,
                unsafeBitCast(fileDialogFinishedCallback, to: GAsyncReadyCallback.self),
                Unmanaged.passRetained(state).toOpaque())
        }
        g_main_loop_run(loop)   // blocks until the completion callback quits it
        g_object_unref(UnsafeMutableRawPointer(dialog))
        return state.path
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

    // MARK: Popover
    private var popoverParented: Set<UInt> = []
    public func createPopover() -> NativeHandle {
        let pop = gtk_popover_new()!
        gtk_popover_set_autohide(asPopover(OpaquePointer(pop)), gboolean(1))
        if nonComposited { gtk_popover_set_has_arrow(asPopover(OpaquePointer(pop)), gboolean(0)) }
        return allocate(pop, .view, frame: .zero)
    }
    public func setPopoverContent(_ content: NativeHandle, size: NSSize, for popover: NativeHandle) {
        guard let pop = widget(popover), let c = widget(content) else { return }
        gtk_widget_set_size_request(asWidget(c), Int32(size.width), Int32(size.height))
        gtk_popover_set_child(asPopover(pop), asWidget(c))
    }
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
    public func closePopover(_ popover: NativeHandle) {
        guard let pop = widget(popover) else { return }
        gtk_popover_popdown(asPopover(pop))
    }

    // MARK: Views & controls
    public func createView(frame: NSRect) -> NativeHandle {
        // An NSView both draws (AppKit `draw(_:)`) and contains children, so it
        // is a GtkOverlay: a GtkDrawingArea underneath for custom drawing, and
        // a GtkFixed on top for absolute child placement.
        let overlay = gtk_overlay_new()!
        let area = gtk_drawing_area_new()!
        let fixed = gtk_fixed_new()!
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
    private func containerFixed(of raw: UInt) -> OpaquePointer? {
        viewFixeds[raw] ?? widgets[raw]   // pre-overlay fallback: the widget itself
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
        stripPopoverArrows(of: widget)
        return allocate(widget, .popUp, frame: frame)
    }

    /// On non-composited displays a popover's pointing arrow renders as a black
    /// bar (its tail geometry is compiled into GTK — CSS cannot remove it), so
    /// walk `widget`'s children and disable the arrow on any internal popover.
    private func stripPopoverArrows(of widget: UnsafeMutablePointer<GtkWidget>) {
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
    public func createTableView(frame: NSRect) -> NativeHandle {
        // GtkColumnView = selection model over a GListModel + per-column cell
        // factories. The model is a GtkStringList used purely for its item
        // count; cell text comes from the Swift-side provider at bind time.
        let list = gtk_string_list_new(nil)!   // GtkStringList is opaque
        let selection = gtk_single_selection_new(list)!   // GListModel is opaque
        let cv = gtk_column_view_new(selection)!   // GtkSingleSelection is opaque
        let scroller = gtk_scrolled_window_new()!
        gtk_scrolled_window_set_child(OpaquePointer(scroller), cv)
        gtk_widget_set_size_request(scroller, Int32(frame.width), Int32(frame.height))
        let h = allocate(scroller, .table, frame: frame)
        tableColumnViews[h.rawValue] = OpaquePointer(cv)
        tableSelections[h.rawValue] = selection
        tableLists[h.rawValue] = list
        return h
    }
    public func addTableColumn(title: String, to table: NativeHandle) {
        guard let cv = tableColumnViews[table.rawValue] else { return }
        let columnIndex = tableColumnCounts[table.rawValue, default: 0]
        let factory = gtk_signal_list_item_factory_new()!
        g_signal_connect_data(
            UnsafeMutableRawPointer(factory), "setup",
            unsafeBitCast(gtkTableCellSetupTrampoline, to: GCallback.self),
            nil, nil, GConnectFlags(rawValue: 0)
        )
        let box = TableColumnBox(backend: self, table: table.rawValue, column: columnIndex)
        g_signal_connect_data(
            UnsafeMutableRawPointer(factory), "bind",
            unsafeBitCast(gtkTableCellBindTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        let column = gtk_column_view_column_new(title, factory)!   // factory is opaque
        gtk_column_view_column_set_expand(column, gboolean(1))
        gtk_column_view_append_column(cv, column)
        tableColumnObjects[table.rawValue, default: []].append(column)
        tableColumnCounts[table.rawValue] = columnIndex + 1
    }
    public func setTableColumnTitle(_ title: String, columnIndex: Int, for table: NativeHandle) {
        guard let columns = tableColumnObjects[table.rawValue], columnIndex < columns.count else { return }
        gtk_column_view_column_set_title(columns[columnIndex], title)
    }
    public func setColumnSortable(_ columnIndex: Int, for table: NativeHandle) {
        guard let columns = tableColumnObjects[table.rawValue], columnIndex < columns.count else { return }
        // A no-op custom sorter makes the header clickable and drives the view's
        // GtkColumnViewSorter; the actual re-sort happens Swift-side (the model
        // is count-only), so we only need the header click + indicator + signal.
        let sorter = gtk_custom_sorter_new(nil, nil, nil)
        gtk_column_view_column_set_sorter(columns[columnIndex], UnsafeMutablePointer<GtkSorter>(sorter))
    }
    public func setSortChangeAction(for table: NativeHandle, action: @escaping (Int, Bool) -> Void) {
        tableSortActions[table.rawValue] = action
        guard let cv = tableColumnViews[table.rawValue],
              let sorter = gtk_column_view_get_sorter(cv) else { return }
        let box = TableSignalBox(backend: self, table: table.rawValue)
        g_signal_connect_data(
            UnsafeMutableRawPointer(sorter), "changed",
            unsafeBitCast(gtkSorterChangedTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }
    public func setRowActivateAction(for table: NativeHandle, action: @escaping (Int) -> Void) {
        tableActivateActions[table.rawValue] = action
        guard let cv = tableColumnViews[table.rawValue] else { return }
        let box = TableSignalBox(backend: self, table: table.rawValue)
        g_signal_connect_data(
            UnsafeMutableRawPointer(cv), "activate",
            unsafeBitCast(gtkRowActivateTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
    }
    /// Called from the sorter-changed trampoline: maps the primary sort column
    /// back to its index and reports (index, ascending) to the Swift action.
    func handleSorterChanged(table: UInt, sorter: OpaquePointer) {
        guard let columns = tableColumnObjects[table], let action = tableSortActions[table],
              let primary = gtk_column_view_sorter_get_primary_sort_column(sorter) else { return }
        guard let index = columns.firstIndex(of: primary) else { return }
        let ascending = gtk_column_view_sorter_get_primary_sort_order(sorter) == GTK_SORT_ASCENDING
        action(index, ascending)
    }
    /// Called from the row-activate trampoline (double-click / Enter).
    func handleRowActivate(table: UInt, position: Int) {
        tableActivateActions[table]?(position)
    }
    public func setTableRowCount(_ count: Int, for table: NativeHandle) {
        guard let list = tableLists[table.rawValue] else { return }
        // Replace all items: forces every visible cell to re-bind (= reload).
        let old = tableRowCounts[table.rawValue] ?? 0
        var additions: [UnsafePointer<CChar>?] = (0..<count).map { _ in UnsafePointer(strdup("")) }
        additions.append(nil)
        additions.withUnsafeBufferPointer {
            gtk_string_list_splice(list, 0, guint(old), $0.baseAddress)
        }
        for s in additions where s != nil { free(UnsafeMutableRawPointer(mutating: s)) }
        tableRowCounts[table.rawValue] = count
    }
    public func setTableCellProvider(for table: NativeHandle, provider: @escaping (Int, Int) -> String) {
        tableProviders[table.rawValue] = provider
    }
    /// Cell text for the bind trampoline.
    func tableCellText(table: UInt, row: Int, column: Int) -> String {
        tableProviders[table]?(row, column) ?? ""
    }
    public func createCollectionView(frame: NSRect) -> NativeHandle {
        // GtkGridView over the same count-only GtkStringList trick as tables;
        // one factory renders every tile, pulling text from the provider.
        let list = gtk_string_list_new(nil)!
        let selection = gtk_single_selection_new(list)!
        let factory = gtk_signal_list_item_factory_new()!
        g_signal_connect_data(
            UnsafeMutableRawPointer(factory), "setup",
            unsafeBitCast(gtkCollectionTileSetupTrampoline, to: GCallback.self),
            nil, nil, GConnectFlags(rawValue: 0)
        )
        let gv = gtk_grid_view_new(selection, factory)!
        gtk_grid_view_set_min_columns(OpaquePointer(gv), 3)
        gtk_grid_view_set_max_columns(OpaquePointer(gv), 4)
        let scroller = gtk_scrolled_window_new()!
        gtk_scrolled_window_set_child(OpaquePointer(scroller), gv)
        gtk_widget_set_size_request(scroller, Int32(frame.width), Int32(frame.height))
        let h = allocate(scroller, .collection, frame: frame)
        let box = CollectionBox(backend: self, collection: h.rawValue)
        g_signal_connect_data(
            UnsafeMutableRawPointer(factory), "bind",
            unsafeBitCast(gtkCollectionTileBindTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        collectionLists[h.rawValue] = list
        tableSelections[h.rawValue] = selection   // shared selection routing
        return h
    }
    public func setCollectionItemCount(_ count: Int, for collection: NativeHandle) {
        guard let list = collectionLists[collection.rawValue] else { return }
        let old = collectionItemCounts[collection.rawValue] ?? 0
        var additions: [UnsafePointer<CChar>?] = (0..<count).map { _ in UnsafePointer(strdup("")) }
        additions.append(nil)
        additions.withUnsafeBufferPointer {
            gtk_string_list_splice(list, 0, guint(old), $0.baseAddress)
        }
        for s in additions where s != nil { free(UnsafeMutableRawPointer(mutating: s)) }
        collectionItemCounts[collection.rawValue] = count
    }
    public func setCollectionItemProvider(for collection: NativeHandle, provider: @escaping (Int) -> String) {
        collectionProviders[collection.rawValue] = provider
    }
    /// Tile text for the collection bind trampoline.
    func collectionItemText(collection: UInt, index: Int) -> String {
        collectionProviders[collection]?(index) ?? ""
    }
    public func createOutlineView(frame: NSRect) -> NativeHandle {
        // Tree table: GtkTreeListModel over a root GtkStringList of path keys
        // ("0", "1", …); expanding a row asks the create-func for a child list
        // ("0.0", "0.1", …). Cell text resolves paths through the Swift provider.
        let rootList = gtk_string_list_new(nil)!
        let box = OutlineBox(backend: self)
        let tree = gtk_tree_list_model_new(
            rootList, gboolean(0), gboolean(0),   // passthrough: no, autoexpand: no
            outlineCreateChildModelFunc,
            Unmanaged.passRetained(box).toOpaque(), boxDestroyNotify
        )!
        let selection = gtk_single_selection_new(tree)!   // GtkTreeListModel is opaque
        let cv = gtk_column_view_new(selection)!
        let scroller = gtk_scrolled_window_new()!
        gtk_scrolled_window_set_child(OpaquePointer(scroller), cv)
        gtk_widget_set_size_request(scroller, Int32(frame.width), Int32(frame.height))
        let h = allocate(scroller, .outline, frame: frame)
        box.outline = h.rawValue
        outlineColumnViews[h.rawValue] = OpaquePointer(cv)
        outlineRootLists[h.rawValue] = rootList
        tableSelections[h.rawValue] = selection   // shared selection routing
        return h
    }
    public func addOutlineColumn(title: String, to outline: NativeHandle) {
        guard let cv = outlineColumnViews[outline.rawValue] else { return }
        let columnIndex = outlineColumnCounts[outline.rawValue, default: 0]
        let factory = gtk_signal_list_item_factory_new()!
        let setupBox = OutlineColumnBox(backend: self, outline: outline.rawValue, column: columnIndex)
        g_signal_connect_data(
            UnsafeMutableRawPointer(factory), "setup",
            unsafeBitCast(gtkOutlineCellSetupTrampoline, to: GCallback.self),
            Unmanaged.passRetained(setupBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        let bindBox = OutlineColumnBox(backend: self, outline: outline.rawValue, column: columnIndex)
        g_signal_connect_data(
            UnsafeMutableRawPointer(factory), "bind",
            unsafeBitCast(gtkOutlineCellBindTrampoline, to: GCallback.self),
            Unmanaged.passRetained(bindBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        let column = gtk_column_view_column_new(title, factory)!
        gtk_column_view_column_set_expand(column, gboolean(1))
        gtk_column_view_append_column(cv, column)
        outlineColumnCounts[outline.rawValue] = columnIndex + 1
    }
    public func setOutlineRootCount(_ count: Int, for outline: NativeHandle) {
        guard let list = outlineRootLists[outline.rawValue] else { return }
        let old = outlineRootCounts[outline.rawValue] ?? 0
        var additions: [UnsafePointer<CChar>?] = (0..<count).map { UnsafePointer(strdup("\($0)")) }
        additions.append(nil)
        additions.withUnsafeBufferPointer {
            gtk_string_list_splice(list, 0, guint(old), $0.baseAddress)
        }
        for s in additions where s != nil { free(UnsafeMutableRawPointer(mutating: s)) }
        outlineRootCounts[outline.rawValue] = count
    }
    public func setOutlineProviders(
        for outline: NativeHandle,
        childCount: @escaping (String) -> Int,
        cellText: @escaping (String, Int) -> String
    ) {
        outlineChildCountProviders[outline.rawValue] = childCount
        outlineCellTextProviders[outline.rawValue] = cellText
    }
    /// Child count for the tree create-func.
    func outlineChildCount(outline: UInt, path: String) -> Int {
        outlineChildCountProviders[outline]?(path) ?? 0
    }
    /// Cell text for the outline bind trampoline.
    func outlineCellText(outline: UInt, path: String, column: Int) -> String {
        outlineCellTextProviders[outline]?(path, column) ?? ""
    }
    public func createTokenField(tokens: [String], frame: NSRect) -> NativeHandle {
        // Composed control (no GTK peer): [chip][chip]…[entry] in a box.
        // Enter in the entry commits a token; clicking a chip removes it.
        let box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 6)!
        gtk_widget_set_size_request(box, Int32(frame.width), Int32(frame.height))
        let entry = gtk_entry_new()!
        gtk_widget_set_hexpand(entry, gboolean(1))
        gtk_box_append(asBox(OpaquePointer(box)), entry)
        let h = allocate(box, .tokenField, frame: frame)
        tokenEntries[h.rawValue] = OpaquePointer(entry)
        tokenValues[h.rawValue] = tokens
        rebuildTokenChips(for: h)

        let commit = ActionBox { [weak self] in self?.commitTokenEntry(h) }
        g_signal_connect_data(
            UnsafeMutableRawPointer(entry), "activate",
            unsafeBitCast(gtkActionTrampoline, to: GCallback.self),
            Unmanaged.passRetained(commit).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        return h
    }
    public func setTokens(_ tokens: [String], for handle: NativeHandle) {
        tokenValues[handle.rawValue] = tokens
        rebuildTokenChips(for: handle)
    }
    public func setTokensChangeAction(for handle: NativeHandle, action: @escaping ([String]) -> Void) {
        tokenActions[handle.rawValue] = action
    }

    /// Commits the entry's text as a new token (Enter pressed).
    private func commitTokenEntry(_ handle: NativeHandle) {
        guard let entry = tokenEntries[handle.rawValue] else { return }
        let text = String(cString: gtk_editable_get_text(entry)).trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        tokenValues[handle.rawValue, default: []].append(text)
        gtk_editable_set_text(entry, "")
        rebuildTokenChips(for: handle)
        tokenActions[handle.rawValue]?(tokenValues[handle.rawValue] ?? [])
    }

    /// Removes token `index` (its chip was clicked).
    private func removeToken(_ handle: NativeHandle, at index: Int) {
        guard var tokens = tokenValues[handle.rawValue], index < tokens.count else { return }
        tokens.remove(at: index)
        tokenValues[handle.rawValue] = tokens
        rebuildTokenChips(for: handle)
        tokenActions[handle.rawValue]?(tokens)
    }

    /// Recreates the chip buttons to match the current tokens (entry stays last).
    private func rebuildTokenChips(for handle: NativeHandle) {
        guard let boxWidget = widget(handle) else { return }
        for chip in tokenChips[handle.rawValue] ?? [] {
            gtk_box_remove(asBox(boxWidget), asWidget(chip))
        }
        var chips: [OpaquePointer] = []
        var previous: OpaquePointer? = nil
        for (index, token) in (tokenValues[handle.rawValue] ?? []).enumerated() {
            let chip = gtk_button_new_with_label("\(token) ✕")!
            let remove = ActionBox { [weak self] in self?.removeToken(handle, at: index) }
            g_signal_connect_data(
                UnsafeMutableRawPointer(chip), "clicked",
                unsafeBitCast(gtkActionTrampoline, to: GCallback.self),
                Unmanaged.passRetained(remove).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
            gtk_box_insert_child_after(asBox(boxWidget), chip, previous.map(asWidget))
            previous = OpaquePointer(chip)
            chips.append(OpaquePointer(chip))
        }
        tokenChips[handle.rawValue] = chips
    }
    public func createImageView(frame: NSRect) -> NativeHandle {
        let picture = gtk_picture_new()!
        gtk_widget_set_size_request(picture, Int32(frame.width), Int32(frame.height))
        return allocate(picture, .imageView, frame: frame)
    }
    public func setImagePath(_ path: String?, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_picture_set_filename(w, path)   // GtkPicture is opaque; nil clears
    }
    public func createBox(title: String, frame: NSRect) -> NativeHandle {
        let f = gtk_frame_new(title)!
        gtk_widget_set_size_request(f, Int32(frame.width), Int32(frame.height))
        return allocate(f, .box, frame: frame)
    }
    public func createScrollView(frame: NSRect) -> NativeHandle {
        let sw = gtk_scrolled_window_new()!
        gtk_widget_set_size_request(sw, Int32(frame.width), Int32(frame.height))
        // Reserve a permanent gutter for the scrollbar instead of floating it
        // over the content (AppKit's legacy scrollers take space). GTK's overlay
        // scrollbar otherwise draws atop the right edge — and on a non-composited
        // display (XQuartz) that overlay renders as an opaque strip clipping the
        // content rather than the viewport resizing to make room for it.
        gtk_scrolled_window_set_overlay_scrolling(OpaquePointer(sw), gboolean(0))
        return allocate(sw, .scrollView, frame: frame)
    }
    public func setScrollerPolicy(vertical: Bool, horizontal: Bool, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_scrolled_window_set_policy(w,   // GtkScrolledWindow is opaque
            horizontal ? GTK_POLICY_AUTOMATIC : GTK_POLICY_NEVER,
            vertical ? GTK_POLICY_AUTOMATIC : GTK_POLICY_NEVER)
    }
    public func setScrollOffset(x: Double, y: Double, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_adjustment_set_value(gtk_scrolled_window_get_hadjustment(w), x)
        gtk_adjustment_set_value(gtk_scrolled_window_get_vadjustment(w), y)
    }
    public func scrollOffset(for handle: NativeHandle) -> (x: Double, y: Double) {
        guard let w = widget(handle) else { return (0, 0) }
        return (gtk_adjustment_get_value(gtk_scrolled_window_get_hadjustment(w)),
                gtk_adjustment_get_value(gtk_scrolled_window_get_vadjustment(w)))
    }
    public func scrollDocumentSize(for handle: NativeHandle) -> (width: Double, height: Double) {
        guard let w = widget(handle) else { return (0, 0) }
        return (gtk_adjustment_get_upper(gtk_scrolled_window_get_hadjustment(w)),
                gtk_adjustment_get_upper(gtk_scrolled_window_get_vadjustment(w)))
    }
    public func scrollVisibleSize(for handle: NativeHandle) -> (width: Double, height: Double) {
        guard let w = widget(handle) else { return (0, 0) }
        return (gtk_adjustment_get_page_size(gtk_scrolled_window_get_hadjustment(w)),
                gtk_adjustment_get_page_size(gtk_scrolled_window_get_vadjustment(w)))
    }
    public func setScrollChangeAction(for handle: NativeHandle, action: @escaping (Double, Double) -> Void) {
        guard let w = widget(handle),
              let hadj = gtk_scrolled_window_get_hadjustment(w),
              let vadj = gtk_scrolled_window_get_vadjustment(w) else { return }
        let box = ScrollBox(hadj: hadj, vadj: vadj, action: action)
        // Both adjustments drive the same box; retain once per connection.
        for adjustment in [hadj, vadj] {
            g_signal_connect_data(
                UnsafeMutableRawPointer(adjustment), "value-changed",
                unsafeBitCast(gtkScrollChangedTrampoline, to: GCallback.self),
                Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
        }
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
            // Pin the leading pane to the divider position (don't let it grow to
            // its natural width and push the divider right).
            gtk_paned_set_resize_start_child(paned, gboolean(0))
            gtk_paned_set_shrink_start_child(paned, gboolean(0))
        } else {
            gtk_paned_set_end_child(paned, asWidget(p))
            // The trailing pane fills the remaining width but never shrinks below
            // its content — otherwise the pane's box is clipped on the right.
            gtk_paned_set_resize_end_child(paned, gboolean(1))
            gtk_paned_set_shrink_end_child(paned, gboolean(0))
        }
        splitPaneCounts[splitView.rawValue] = count + 1
    }
    public func setDividerPosition(_ position: Double, for splitView: NativeHandle) {
        guard let paned = widget(splitView) else { return }
        gtk_paned_set_position(paned, gint(position))
    }
    public func addSubview(_ child: NativeHandle, to parent: NativeHandle) {
        guard let p = containerFixed(of: parent.rawValue), let c = widget(child) else { return }
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
        if let parentRaw = parents[handle.rawValue], let p = containerFixed(of: parentRaw) {
            let parentHeight = frames[parentRaw]?.height ?? 0
            let y = CoordinateSpace.gtkY(for: frame, parentHeight: parentHeight)
            gtk_fixed_move(asFixed(p), asWidget(w), Double(frame.origin.x), Double(y))
        }
    }
    public func setDrawHandler(for handle: NativeHandle, handler: @escaping (NativeGraphicsContext, Double, Double) -> Void) {
        guard let area = viewDrawAreas[handle.rawValue] else { return }
        drawHandlers[handle.rawValue] = handler
        let box = DrawBox(backend: self, view: handle.rawValue)
        gtk_drawing_area_set_draw_func(
            UnsafeMutablePointer<GtkDrawingArea>(area),
            gtkDrawFunc,
            Unmanaged.passRetained(box).toOpaque(), boxDestroyNotify
        )
    }
    public func setNeedsDisplay(_ handle: NativeHandle) {
        guard let area = viewDrawAreas[handle.rawValue] else { return }
        gtk_widget_queue_draw(asWidget(area))
    }
    /// Dispatches a draw pass to the Swift handler (called by the draw func).
    func dispatchDraw(view: UInt, context: NativeGraphicsContext, width: Double, height: Double) {
        drawHandlers[view]?(context, width, height)
    }
    public func setEnabled(_ isEnabled: Bool, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_widget_set_sensitive(asWidget(w), gboolean(isEnabled ? 1 : 0))
    }
    public func setHidden(_ isHidden: Bool, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_widget_set_visible(asWidget(w), gboolean(isHidden ? 0 : 1))
    }
    public func setStyledText(_ runs: [NativeTextRun], for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        // Attributed text renders via Pango markup on the label.
        var markup = ""
        for run in runs {
            var attributes: [String] = []
            if let color = run.color {
                attributes.append(String(
                    format: "foreground=\"#%02X%02X%02X\"",
                    Int(color.redComponent * 255), Int(color.greenComponent * 255),
                    Int(color.blueComponent * 255)
                ))
            }
            if let font = run.font {
                var description = font.family ?? ""
                if font.bold { description += " Bold" }
                if font.italic { description += " Italic" }
                description += " \(Int(font.size))"
                attributes.append("font_desc=\"\(description.trimmingCharacters(in: .whitespaces))\"")
            }
            let escaped = run.text
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            markup += attributes.isEmpty ? escaped : "<span \(attributes.joined(separator: " "))>\(escaped)</span>"
        }
        gtk_label_set_markup(w, markup)   // GtkLabel is opaque
    }
    public func setFont(_ font: NativeFontSpec, for handle: NativeHandle) {
        widgetFonts[handle.rawValue] = font
        applyWidgetStyle(for: handle)
    }
    public func setTextColor(_ color: NSColor, for handle: NativeHandle) {
        widgetTextColors[handle.rawValue] = color
        applyWidgetStyle(for: handle)
    }

    /// Applies a theme-derived background to an `NSVisualEffectView`. The shade
    /// is expressed against GTK's theme-named colors (`@theme_bg_color`, …), so
    /// it flips automatically when the app switches to dark appearance — no real
    /// blur (XQuartz is non-composited), just a material-shaded surface.
    public func setMaterial(_ material: String, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        let background: String
        switch material {
        case "sidebar", "underWindowBackground": background = "shade(@theme_bg_color, 0.93)"
        case "titlebar", "headerView":           background = "shade(@theme_bg_color, 1.05)"
        case "menu", "popover", "sheet":         background = "@theme_base_color"
        case "hudWindow":                        background = "alpha(@theme_fg_color, 0.55)"
        default:                                 background = "@theme_bg_color"
        }
        let css = "* { background: \(background); }"
        let context = gtk_widget_get_style_context(asWidget(w))
        if let old = materialProviders[handle.rawValue] {
            gtk_style_context_remove_provider(context, old)
        }
        let provider = gtk_css_provider_new()!
        gtk_css_provider_load_from_data(provider, css, gssize(css.utf8.count))
        // 700 sits between the app (600) and per-widget font/color (800) layers.
        gtk_style_context_add_provider(context, OpaquePointer(provider), 700)
        materialProviders[handle.rawValue] = OpaquePointer(provider)
    }

    /// Rebuilds and installs the widget-scoped CSS provider carrying the
    /// control's font and text color (GTK styles text via CSS, not API calls).
    private func applyWidgetStyle(for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        let context = gtk_widget_get_style_context(asWidget(w))

        var declarations: [String] = []
        if let font = widgetFonts[handle.rawValue] {
            if let family = font.family { declarations.append("font-family: \"\(family)\";") }
            declarations.append("font-size: \(Int(font.size))px;")
            if font.bold { declarations.append("font-weight: bold;") }
            if font.italic { declarations.append("font-style: italic;") }
        }
        if let color = widgetTextColors[handle.rawValue] {
            declarations.append(String(
                format: "color: rgba(%d,%d,%d,%.2f);",
                Int(color.redComponent * 255), Int(color.greenComponent * 255),
                Int(color.blueComponent * 255), color.alphaComponent
            ))
        }
        let body = declarations.joined(separator: " ")
        // `* text` reaches text-holding subnodes (GtkTextView, GtkEntry).
        let css = "* { \(body) } * text { \(body) }"

        if let old = widgetStyleProviders[handle.rawValue] {
            gtk_style_context_remove_provider(context, old)
        }
        let provider = gtk_css_provider_new()!
        gtk_css_provider_load_from_data(provider, css, gssize(css.utf8.count))
        // 800 = GTK_STYLE_PROVIDER_PRIORITY_USER (macro doesn't import).
        gtk_style_context_add_provider(context, OpaquePointer(provider), 800)
        widgetStyleProviders[handle.rawValue] = OpaquePointer(provider)
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
        case .table, .outline, .collection:
            guard let selection = tableSelections[handle.rawValue] else { return }
            gtk_single_selection_set_selected(selection, guint(index))
        default:       gtk_drop_down_set_selected(w, guint(index))     // GtkDropDown is opaque
        }
    }
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
        if [.table, .outline, .collection].contains(kinds[handle.rawValue]) {
            guard let selection = tableSelections[handle.rawValue] else { return }
            g_signal_connect_data(
                UnsafeMutableRawPointer(selection), "notify::selected",
                unsafeBitCast(gtkTableSelectionChangedTrampoline, to: GCallback.self),
                Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
            return
        }
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
private final class WidgetBox {
    let widget: UnsafeMutablePointer<GtkWidget>
    init(widget: UnsafeMutablePointer<GtkWidget>) { self.widget = widget }
}
private final class DropBox {
    let onDrop: (String, Double, Double) -> Bool
    init(_ onDrop: @escaping (String, Double, Double) -> Bool) { self.onDrop = onDrop }
}
private final class DragProviderBox {
    let provider: () -> String?
    init(_ provider: @escaping () -> String?) { self.provider = provider }
}
private final class ScrollBox {
    let hadj: UnsafeMutablePointer<GtkAdjustment>
    let vadj: UnsafeMutablePointer<GtkAdjustment>
    let action: (Double, Double) -> Void
    init(hadj: UnsafeMutablePointer<GtkAdjustment>, vadj: UnsafeMutablePointer<GtkAdjustment>, action: @escaping (Double, Double) -> Void) {
        self.hadj = hadj; self.vadj = vadj; self.action = action
    }
}

private final class DrawBox {
    weak var backend: GTKNativeControlBackend?
    let view: UInt
    init(backend: GTKNativeControlBackend, view: UInt) {
        self.backend = backend
        self.view = view
    }
}

/// Cairo-backed graphics context: NSBezierPath ops map 1:1 onto the cairo_t.
final class CairoGraphicsContext: NativeGraphicsContext {
    private let cr: OpaquePointer
    private var fillColor = NSColor.black
    private var strokeColor = NSColor.black
    private var lineWidth = 1.0

    init(cr: OpaquePointer) { self.cr = cr }

    func setFillColor(_ color: NSColor) { fillColor = color }
    func setStrokeColor(_ color: NSColor) { strokeColor = color }
    func setLineWidth(_ width: Double) { lineWidth = width }
    func beginPath() { cairo_new_path(cr) }
    func move(toX x: Double, y: Double) { cairo_move_to(cr, x, y) }
    func line(toX x: Double, y: Double) { cairo_line_to(cr, x, y) }
    func curve(toX x: Double, y: Double, c1x: Double, c1y: Double, c2x: Double, c2y: Double) {
        cairo_curve_to(cr, c1x, c1y, c2x, c2y, x, y)
    }
    func addArc(centerX: Double, centerY: Double, radius: Double, startAngleRadians: Double, endAngleRadians: Double, clockwise: Bool) {
        // AppKit's default (counter-clockwise) maps to cairo_arc: in our
        // y-flipped space that reads counter-clockwise on screen, and — unlike
        // cairo_arc_negative — a full 0…2π sweep stays a full circle instead of
        // normalizing to a zero-length arc.
        if clockwise {
            cairo_arc_negative(cr, centerX, centerY, radius, startAngleRadians, endAngleRadians)
        } else {
            cairo_arc(cr, centerX, centerY, radius, startAngleRadians, endAngleRadians)
        }
    }
    func closePath() { cairo_close_path(cr) }
    func fillPath() {
        cairo_set_source_rgba(cr, Double(fillColor.redComponent), Double(fillColor.greenComponent),
                              Double(fillColor.blueComponent), Double(fillColor.alphaComponent))
        cairo_fill(cr)
    }
    func strokePath() {
        cairo_set_source_rgba(cr, Double(strokeColor.redComponent), Double(strokeColor.greenComponent),
                              Double(strokeColor.blueComponent), Double(strokeColor.alphaComponent))
        cairo_set_line_width(cr, lineWidth)
        cairo_stroke(cr)
    }
    func saveState() { cairo_save(cr) }
    func restoreState() { cairo_restore(cr) }
    func clipToCurrentPath() { cairo_clip(cr) }

    /// Applies the stops to a cairo pattern and fills `rect` with it.
    private func fill(rect: NSRect, pattern: OpaquePointer, stops: [NativeGradientStop]) {
        for stop in stops {
            cairo_pattern_add_color_stop_rgba(pattern, Double(stop.location),
                Double(stop.color.redComponent), Double(stop.color.greenComponent),
                Double(stop.color.blueComponent), Double(stop.color.alphaComponent))
        }
        cairo_set_source(cr, pattern)
        cairo_rectangle(cr, Double(rect.minX), Double(rect.minY), Double(rect.width), Double(rect.height))
        cairo_fill(cr)
        cairo_pattern_destroy(pattern)
    }
    func fillLinearGradient(_ stops: [NativeGradientStop], inRect rect: NSRect, angleDegrees: Double) {
        // Gradient axis through the rect center; half-length spans the rect's
        // projection so 0° fills across the width and 90° up the height.
        let radians = angleDegrees * .pi / 180
        let dx = cos(radians), dy = sin(radians)
        let cx = Double(rect.midX), cy = Double(rect.midY)
        let half = abs(dx) * Double(rect.width) / 2 + abs(dy) * Double(rect.height) / 2
        let pattern = cairo_pattern_create_linear(cx - dx * half, cy - dy * half, cx + dx * half, cy + dy * half)!
        fill(rect: rect, pattern: pattern, stops: stops)
    }
    func fillRadialGradient(_ stops: [NativeGradientStop], inRect rect: NSRect) {
        let cx = Double(rect.midX), cy = Double(rect.midY)
        let radius = max(Double(rect.width), Double(rect.height)) / 2
        let pattern = cairo_pattern_create_radial(cx, cy, 0, cx, cy, radius)!
        fill(rect: rect, pattern: pattern, stops: stops)
    }
}

/// `GtkDrawingAreaDrawFunc` — flips into AppKit's bottom-left space and
/// dispatches to the view's Swift draw handler.
private let gtkDrawFunc: @convention(c) (UnsafeMutablePointer<GtkDrawingArea>?, OpaquePointer?, Int32, Int32, gpointer?) -> Void = { _, cr, width, height, userData in
    guard let cr, let userData else { return }
    let box = Unmanaged<DrawBox>.fromOpaque(userData).takeUnretainedValue()
    cairo_save(cr)
    cairo_translate(cr, 0, Double(height))
    cairo_scale(cr, 1, -1)
    let context = CairoGraphicsContext(cr: cr)
    box.backend?.dispatchDraw(view: box.view, context: context, width: Double(width), height: Double(height))
    cairo_restore(cr)
}

/// Shared state for one modal file-dialog run.
private final class FileDialogState {
    let loop: OpaquePointer?
    let open: Bool          // open vs save (selects the *_finish call)
    var path: String?
    init(loop: OpaquePointer?, open: Bool) { self.loop = loop; self.open = open }
}

/// `GAsyncReadyCallback` for GtkFileDialog open/save — extracts the chosen
/// file's path (nil on cancel) and quits the nested loop.
private let fileDialogFinishedCallback: @convention(c) (UnsafeMutableRawPointer?, OpaquePointer?, gpointer?) -> Void = { source, result, data in
    guard let data else { return }
    let state = Unmanaged<FileDialogState>.fromOpaque(data).takeRetainedValue()
    if let source, let result {
        let file = state.open
            ? gtk_file_dialog_open_finish(OpaquePointer(source), result, nil)
            : gtk_file_dialog_save_finish(OpaquePointer(source), result, nil)
        if let file {
            if let cPath = g_file_get_path(file) {
                state.path = String(cString: cPath)
                g_free(cPath)
            }
            g_object_unref(UnsafeMutableRawPointer(file))
        }
    }
    g_main_loop_quit(state.loop)
}

/// Shared state for one modal alert run: the nested loop and the response.
private final class AlertState {
    let loop: OpaquePointer?
    var response = 0
    init(loop: OpaquePointer?) { self.loop = loop }
}
private final class AlertButtonBox {
    let index: Int
    let state: AlertState
    init(index: Int, state: AlertState) { self.index = index; self.state = state }
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

private final class TableColumnBox {
    weak var backend: GTKNativeControlBackend?
    let table: UInt
    let column: Int
    init(backend: GTKNativeControlBackend, table: UInt, column: Int) {
        self.backend = backend
        self.table = table
        self.column = column
    }
}

private final class OutlineBox {
    weak var backend: GTKNativeControlBackend?
    var outline: UInt = 0   // assigned right after the handle is allocated
    init(backend: GTKNativeControlBackend) { self.backend = backend }
}

/// Carries a customization-palette row's identifier + toggle closure.
private final class ToolbarToggleBox {
    let id: String
    let action: (String, Bool) -> Void
    init(id: String, action: @escaping (String, Bool) -> Void) {
        self.id = id
        self.action = action
    }
}

/// Handler for a customization-palette checkbox `toggled` — reports (id, on).
private let gtkToolbarToggleTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { button, userData in
    guard let button, let userData else { return }
    let active = gtk_check_button_get_active(UnsafeMutablePointer<GtkCheckButton>(OpaquePointer(button))) != 0
    let box = Unmanaged<ToolbarToggleBox>.fromOpaque(userData).takeUnretainedValue()
    box.action(box.id, active)
}

/// Carries a table's identity to the sorter-changed and row-activate handlers.
private final class TableSignalBox {
    weak var backend: GTKNativeControlBackend?
    let table: UInt
    init(backend: GTKNativeControlBackend, table: UInt) {
        self.backend = backend
        self.table = table
    }
}

/// Handler for the column view's `GtkColumnViewSorter::changed` — a header was
/// clicked; report the primary sort column + order to the Swift side.
private let gtkSorterChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, guint, gpointer?) -> Void = { sorter, _, userData in
    guard let sorter, let userData else { return }
    let box = Unmanaged<TableSignalBox>.fromOpaque(userData).takeUnretainedValue()
    box.backend?.handleSorterChanged(table: box.table, sorter: OpaquePointer(sorter))
}

/// Handler for `GtkColumnView::activate` — a row was double-clicked / Entered.
private let gtkRowActivateTrampoline: @convention(c) (UnsafeMutableRawPointer?, guint, gpointer?) -> Void = { _, position, userData in
    guard let userData else { return }
    let box = Unmanaged<TableSignalBox>.fromOpaque(userData).takeUnretainedValue()
    box.backend?.handleRowActivate(table: box.table, position: Int(position))
}
private final class OutlineColumnBox {
    weak var backend: GTKNativeControlBackend?
    let outline: UInt
    let column: Int
    init(backend: GTKNativeControlBackend, outline: UInt, column: Int) {
        self.backend = backend
        self.outline = outline
        self.column = column
    }
}

private final class CollectionBox {
    weak var backend: GTKNativeControlBackend?
    let collection: UInt
    init(backend: GTKNativeControlBackend, collection: UInt) {
        self.backend = backend
        self.collection = collection
    }
}

/// Collection factory `setup` — a centered tile label with breathing room.
private let gtkCollectionTileSetupTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { _, item, _ in
    guard let item else { return }
    let label = gtk_label_new("")!
    gtk_widget_set_margin_start(label, 12); gtk_widget_set_margin_end(label, 12)
    gtk_widget_set_margin_top(label, 16); gtk_widget_set_margin_bottom(label, 16)
    gtk_list_item_set_child(OpaquePointer(item), label)
}

/// Collection factory `bind` — fills the tile from the item provider.
private let gtkCollectionTileBindTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { _, item, userData in
    guard let item, let userData else { return }
    let box = Unmanaged<CollectionBox>.fromOpaque(userData).takeUnretainedValue()
    let index = Int(gtk_list_item_get_position(OpaquePointer(item)))
    guard let child = gtk_list_item_get_child(OpaquePointer(item)) else { return }
    let text = box.backend?.collectionItemText(collection: box.collection, index: index) ?? ""
    gtk_label_set_text(OpaquePointer(child), text)
}

/// `GtkTreeListModel` create-func — returns a child path list, or nil for leaves.
private let outlineCreateChildModelFunc: @convention(c) (gpointer?, gpointer?) -> OpaquePointer? = { item, userData in
    guard let item, let userData else { return nil }
    let box = Unmanaged<OutlineBox>.fromOpaque(userData).takeUnretainedValue()
    let path = String(cString: gtk_string_object_get_string(OpaquePointer(item)))
    let count = box.backend?.outlineChildCount(outline: box.outline, path: path) ?? 0
    guard count > 0 else { return nil }
    let children = gtk_string_list_new(nil)!
    for index in 0..<count {
        gtk_string_list_append(children, "\(path).\(index)")
    }
    return children
}

/// Outline factory `setup` — column 0 gets a tree expander wrapping the label.
private let gtkOutlineCellSetupTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { _, item, userData in
    guard let item, let userData else { return }
    let box = Unmanaged<OutlineColumnBox>.fromOpaque(userData).takeUnretainedValue()
    let label = gtk_label_new("")!
    gtk_label_set_xalign(OpaquePointer(label), 0)
    gtk_widget_set_margin_start(label, 4)
    gtk_widget_set_margin_end(label, 8)
    if box.column == 0 {
        let expander = gtk_tree_expander_new()!
        gtk_tree_expander_set_child(OpaquePointer(expander), label)
        gtk_list_item_set_child(OpaquePointer(item), expander)
    } else {
        gtk_list_item_set_child(OpaquePointer(item), label)
    }
}

/// Outline factory `bind` — unwraps the tree row, wires the expander (col 0),
/// and fills the label from the path-based provider.
private let gtkOutlineCellBindTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { _, item, userData in
    guard let item, let userData else { return }
    let box = Unmanaged<OutlineColumnBox>.fromOpaque(userData).takeUnretainedValue()
    guard let rowObject = gtk_list_item_get_item(OpaquePointer(item)) else { return }
    guard let inner = gtk_tree_list_row_get_item(OpaquePointer(rowObject)) else { return }
    let path = String(cString: gtk_string_object_get_string(OpaquePointer(inner)))
    g_object_unref(inner)   // get_item returns a strong reference
    let text = box.backend?.outlineCellText(outline: box.outline, path: path, column: box.column) ?? ""
    guard let child = gtk_list_item_get_child(OpaquePointer(item)) else { return }
    if box.column == 0 {
        gtk_tree_expander_set_list_row(OpaquePointer(child), OpaquePointer(rowObject))
        if let label = gtk_tree_expander_get_child(OpaquePointer(child)) {
            gtk_label_set_text(OpaquePointer(label), text)
        }
    } else {
        gtk_label_set_text(OpaquePointer(child), text)
    }
}

/// Factory `setup` — gives each cell a left-aligned label.
private let gtkTableCellSetupTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { _, item, _ in
    guard let item else { return }
    let label = gtk_label_new("")!
    gtk_label_set_xalign(OpaquePointer(label), 0)
    gtk_widget_set_margin_start(label, 8)
    gtk_widget_set_margin_end(label, 8)
    gtk_list_item_set_child(OpaquePointer(item), label)
}

/// Factory `bind` — fills the cell's label from the table's cell provider.
private let gtkTableCellBindTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { _, item, userData in
    guard let item, let userData else { return }
    let box = Unmanaged<TableColumnBox>.fromOpaque(userData).takeUnretainedValue()
    let row = Int(gtk_list_item_get_position(OpaquePointer(item)))
    guard let child = gtk_list_item_get_child(OpaquePointer(item)) else { return }
    let text = box.backend?.tableCellText(table: box.table, row: row, column: box.column) ?? ""
    gtk_label_set_text(OpaquePointer(child), text)
}

/// `GtkSingleSelection::notify::selected` — passes the selected row (−1 if none).
private let gtkTableSelectionChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { selection, _, userData in
    guard let selection, let userData else { return }
    let selected = gtk_single_selection_get_selected(OpaquePointer(selection))
    let row = selected == guint.max ? -1 : Int(selected)   // guint.max = GTK_INVALID_LIST_POSITION
    Unmanaged<IntActionBox>.fromOpaque(userData).takeUnretainedValue().action(row)
}

/// Actual popover widget types. Matching must be exact: `GtkPopoverMenuBar`
/// and `GtkPopoverMenuBarItem` contain "Popover" but are NOT popovers, and
/// popping them down trips a Gtk-CRITICAL assertion on every click.
private let popoverTypeNames: Set<String> = ["GtkPopover", "GtkPopoverMenu", "GtkTreePopover"]

/// Menu-bar subtrees the dismissal walk must NOT descend into. The menu bar
/// owns a `GtkPopoverMenu` for the open menu; GTK manages its lifetime (open on
/// click, close on Escape / activation / clicking another top-level item). If
/// our fallback reaches in and pops it down, the menu closes the instant it
/// opens — i.e. menus stop working. So skip these subtrees entirely; the
/// fallback only needs to reach the *standalone* popovers below (dropdown and
/// combo-box lists), which are not inside the menu bar.
private let menuBarTypeNames: Set<String> = ["GtkPopoverMenuBar", "GtkPopoverMenuBarItem"]

/// Recursively pops down any *mapped* standalone popover in `widget`'s subtree
/// (dropdown lists, combo popups), skipping menu-bar menus.
private func popdownVisiblePopovers(under widget: UnsafeMutablePointer<GtkWidget>) {
    var child = gtk_widget_get_first_child(widget)
    while let c = child {
        let typeName = String(cString: g_type_name_from_instance(
            UnsafeMutableRawPointer(c).assumingMemoryBound(to: GTypeInstance.self)))
        if popoverTypeNames.contains(typeName) {
            if gtk_widget_get_mapped(c) != 0 {
                gtk_popover_popdown(UnsafeMutablePointer<GtkPopover>(OpaquePointer(c)))
            }
        } else if !menuBarTypeNames.contains(typeName) {
            popdownVisiblePopovers(under: c)
        }
        child = gtk_widget_get_next_sibling(c)
    }
}

/// Handler for the window's capture-phase `GtkGestureClick::pressed` — the
/// outside-click popover dismissal fallback for non-composited displays. Runs
/// before the click lands, so it dismisses a previously-open popover without
/// ever closing one that this same click is about to open.
private let gtkDismissPopoversTrampoline: @convention(c) (UnsafeMutableRawPointer?, gint, gdouble, gdouble, gpointer?) -> Void = { _, _, _, _, userData in
    guard let userData else { return }
    let box = Unmanaged<WidgetBox>.fromOpaque(userData).takeUnretainedValue()
    popdownVisiblePopovers(under: box.widget)
}

/// Handler for an alert button's `clicked` — records the response and quits the
/// alert's nested main loop, unblocking `runAlert`.
private let gtkAlertButtonTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { _, userData in
    guard let userData else { return }
    let box = Unmanaged<AlertButtonBox>.fromOpaque(userData).takeUnretainedValue()
    box.state.response = box.index
    g_main_loop_quit(box.state.loop)
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
/// Handler for `GtkDropTarget::drop` — extracts the dropped string and flips
/// the drop point into AppKit's bottom-left coordinates. Returns whether the
/// destination accepted the drop.
private let gtkDropTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<GValue>?, Double, Double, gpointer?) -> gboolean = { target, value, x, y, userData in
    guard let value, let userData else { return gboolean(0) }
    let cString = g_value_get_string(value)
    let string = cString.map { String(cString: $0) } ?? ""
    var appKitY = y
    if let target {
        let widget = gtk_event_controller_get_widget(OpaquePointer(target))
        appKitY = Double(gtk_widget_get_height(widget)) - y
    }
    let accepted = Unmanaged<DropBox>.fromOpaque(userData).takeUnretainedValue().onDrop(string, x, appKitY)
    return gboolean(accepted ? 1 : 0)
}

/// Handler for `GtkDragSource::prepare` — wraps the provided string in a
/// `GdkContentProvider` (built from a GValue, since `gdk_content_provider_new_typed`
/// is C-variadic). Returning nil cancels the drag.
private let gtkDragPrepareTrampoline: @convention(c) (UnsafeMutableRawPointer?, Double, Double, gpointer?) -> OpaquePointer? = { _, _, _, userData in
    guard let userData,
          let string = Unmanaged<DragProviderBox>.fromOpaque(userData).takeUnretainedValue().provider()
    else { return nil }
    var value = GValue()
    _ = g_value_init(&value, GType(16 << 2))   // G_TYPE_STRING
    g_value_set_string(&value, string)
    let provider = gdk_content_provider_new_for_value(&value)
    g_value_unset(&value)
    return OpaquePointer(provider)
}

/// Handler for `GtkAdjustment::value-changed` — reads both adjustments' current
/// values (the box carries them) and reports the new `(x, y)` scroll offset.
private let gtkScrollChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { _, userData in
    guard let userData else { return }
    let box = Unmanaged<ScrollBox>.fromOpaque(userData).takeUnretainedValue()
    box.action(gtk_adjustment_get_value(box.hadj), gtk_adjustment_get_value(box.vadj))
}

private let boxRelease: GClosureNotify = { data, _ in
    guard let data else { return }
    Unmanaged<AnyObject>.fromOpaque(data).release()
}

/// Single-argument variant for APIs taking a `GDestroyNotify`.
private let boxDestroyNotify: @convention(c) (gpointer?) -> Void = { data in
    guard let data else { return }
    Unmanaged<AnyObject>.fromOpaque(data).release()
}
#endif
