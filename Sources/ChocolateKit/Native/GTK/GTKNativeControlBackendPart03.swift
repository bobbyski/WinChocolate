#if canImport(CGTK)
import CGTK
import CGTKCompat
import Foundation

extension GTKNativeControlBackend {
    internal func logZoom(_ phase: String, handle: NativeHandle, content: UnsafeMutablePointer<GtkWidget>,
                         window: UnsafeMutablePointer<GtkWindow>, req: (Int32, Int32)) {
        guard !(ProcessInfo.processInfo.environment["LINCHOCOLATE_ZOOM_DEBUG"] ?? "").isEmpty else { return }
        FileHandle.standardError.write(Data("ZOOM \(phase): monitor req=\(req.0)x\(req.1)\n".utf8))
        let box = ActionBox {
            let cw = gtk_widget_get_width(content), ch = gtk_widget_get_height(content)
            let ww = gtk_widget_get_width(UnsafeMutablePointer<GtkWidget>(OpaquePointer(window)))
            let wh = gtk_widget_get_height(UnsafeMutablePointer<GtkWidget>(OpaquePointer(window)))
            FileHandle.standardError.write(Data("ZOOM alloc: content=\(cw)x\(ch) window=\(ww)x\(wh)\n".utf8))
        }
        g_timeout_add(guint(700), { ud in
            guard let ud else { return gboolean(0) }
            Unmanaged<ActionBox>.fromOpaque(ud).takeUnretainedValue().action()
            return gboolean(0)
        }, Unmanaged.passRetained(box).toOpaque())
    }
    /// The geometry of the primary monitor, for sizing a zoomed window. Falls
    /// back to a generous default when no monitor is enumerable (headless / some
    /// XQuartz setups) so zoom still grows the content.
    internal func monitorWorkArea() -> (Int32, Int32) {
        let fallback: (Int32, Int32) = (1680, 1040)
        guard let display = gdk_display_get_default() else { return fallback }
        let monitors = gdk_display_get_monitors(display)
        guard let raw = g_list_model_get_item(monitors, 0) else { return fallback }
        var geo = GdkRectangle()
        gdk_monitor_get_geometry(OpaquePointer(raw), &geo)
        // GdkMonitor reports DEVICE pixels; windows are sized in logical pixels.
        // On a retina Mac that is a 2x difference — asking for the device size
        // makes the window bigger than the screen, which a WM may refuse outright.
        let scale = Swift.max(1, gdk_monitor_get_scale_factor(OpaquePointer(raw)))
        g_object_unref(raw)
        guard geo.width > 0, geo.height > 0 else { return fallback }
        return (geo.width / scale, geo.height / scale)
    }
    /// Performs the `isWindowZoomed` operation.
    public func isWindowZoomed(_ handle: NativeHandle) -> Bool {
        zoomedWindows.contains(handle.rawValue)
    }
    /// Performs the `miniaturizeWindow` operation.
    public func miniaturizeWindow(_ handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_window_minimize(asWindow(w))
    }

    /// Updates the window's title-bar text.
    public func setWindowTitle(_ title: String, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_window_set_title(asWindow(w), title)
    }
    /// Builds a `GtkPopoverMenuBar` from `menus` and installs it above the content view.
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
                appendMenuItem(item, to: section, group: group, shortcuts: shortcuts, root: asWidget(w))
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

    private func appendMenuItem(
        _ item: NativeMenuItemSpec,
        to section: OpaquePointer,
        group: UnsafeMutablePointer<GSimpleActionGroup>,
        shortcuts: OpaquePointer,
        root: UnsafeMutablePointer<GtkWidget>
    ) {
        menuActionCounter += 1
        let name = "m\(menuActionCounter)"
        if let accelerator = item.accelerator {
            let menuItem = g_menu_item_new(item.title, "win.\(name)")!
            g_menu_item_set_attribute_value(menuItem, "accel", g_variant_new_string(accelerator))
            g_menu_append_item(section, menuItem)
            g_object_unref(UnsafeMutableRawPointer(menuItem))
            if let trigger = gtk_shortcut_trigger_parse_string(accelerator) {
                let shortcut = gtk_shortcut_new(trigger, gtk_named_action_new("win.\(name)"))
                gtk_shortcut_controller_add_shortcut(shortcuts, shortcut)
            }
        } else {
            g_menu_append(section, item.title, "win.\(name)")
        }
        let actionObject = g_simple_action_new(name, nil)!
        if let action = item.action {
            let box = MenuActionBox(root: root, action: action)
            g_signal_connect_data(
                UnsafeMutableRawPointer(actionObject), "activate",
                unsafeBitCast(gtkMenuActivateTrampoline, to: GCallback.self),
                Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
        }
        g_action_map_add_action(OpaquePointer(group), actionObject)
    }
    /// Presents a composed modal alert (modal `GtkWindow` + nested `GMainLoop`) and returns the pressed button's index.
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
        // Closing the alert's window is a dismissal too. Without this the nested
        // loop below runs forever: the app keeps processing events and looks
        // fine, but `terminate` quits the OUTER loop and so Quit silently does
        // nothing. (Alerts are deliberately non-modal on non-composited displays,
        // which gives them a real close button — easy to hit.) Report the last
        // button, AppKit's cancel-ish answer for a dismissed alert.
        let closeBox = AlertButtonBox(index: Swift.max(0, buttons.count - 1), state: state)
        g_signal_connect_data(
            UnsafeMutableRawPointer(alert), "close-request",
            unsafeBitCast(gtkAlertCloseTrampoline, to: GCallback.self),
            Unmanaged.passRetained(closeBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        gtk_window_present(asWindow(OpaquePointer(alert)))
        pushNestedLoop(loop)
        g_main_loop_run(loop)   // blocks until a button (or the close box) quits it
        popNestedLoop()

        gtk_window_destroy(asWindow(OpaquePointer(alert)))
        return state.response
    }
    /// Rebuilds the window's toolbar as a horizontal `GtkBox` styled for the Apple look.
    public func installToolbar(_ items: [NativeToolbarItemSpec], displayMode: NativeToolbarDisplayMode = .iconAndLabel, on window: NativeHandle) {
        guard let box = windowBoxes[window.rawValue] else { return }
        // Detach any embedded custom views (page selector, search field, …) from
        // the old bar first so removing it doesn't destroy widgets we still own.
        // Unparenting drops the bar's reference — which is the ONLY one, so the
        // widget would be destroyed before the rebuilt bar could re-embed it
        // (the disappearing page-selector bug). Hold a reference across the move.
        let detachedViews = detachToolbarViews(from: window)
        windowToolbarViews[window.rawValue] = []
        defer {
            // The rebuilt bar has re-parented (and re-referenced) every view it
            // embeds by the time installToolbar returns; release our hold.
            for view in detachedViews {
                g_object_unref(UnsafeMutableRawPointer(view))
            }
        }
        if let old = windowToolbars[window.rawValue] {
            gtk_box_remove(asBox(box), asWidget(old))
        }
        let bar = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 4)!
        gtk_widget_add_css_class(bar, "linchocolate-toolbar")
        for item in items {
            appendToolbarItem(item, displayMode: displayMode, to: OpaquePointer(bar), window: window)
        }
        // Below the menu bar if present, else at the very top.
        let anchor = windowMenuBars[window.rawValue]
        gtk_box_insert_child_after(asBox(box), bar, anchor.map(asWidget))
        windowToolbars[window.rawValue] = OpaquePointer(bar)
    }

    internal func detachToolbarViews(from window: NativeHandle) -> [OpaquePointer] {
        var detachedViews: [OpaquePointer] = []
        for view in windowToolbarViews[window.rawValue] ?? []
        where gtk_widget_get_parent(asWidget(view)) != nil {
            g_object_ref(UnsafeMutableRawPointer(view))
            detachedViews.append(view)
            gtk_widget_unparent(asWidget(view))
        }
        return detachedViews
    }

    internal func appendToolbarItem(
        _ item: NativeToolbarItemSpec,
        displayMode: NativeToolbarDisplayMode,
        to bar: OpaquePointer,
        window: NativeHandle
    ) {
        if item.isFlexibleSpace {
            let spacer = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
            gtk_widget_set_hexpand(spacer, gboolean(1))
            gtk_box_append(asBox(bar), spacer)
            return
        }
        if item.identifier == "NSToolbarSeparatorItem" {
            let divider = gtk_separator_new(GTK_ORIENTATION_VERTICAL)!
            gtk_widget_set_margin_top(divider, 6)
            gtk_widget_set_margin_bottom(divider, 6)
            gtk_box_append(asBox(bar), divider)
            return
        }
        if item.identifier == "NSToolbarSpaceItem" {
            let gap = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
            gtk_widget_set_size_request(gap, 16, 1)
            gtk_box_append(asBox(bar), gap)
            return
        }
        if let viewHandle = item.viewHandle, let viewWidget = widget(viewHandle) {
            if gtk_widget_get_parent(asWidget(viewWidget)) != nil {
                gtk_widget_unparent(asWidget(viewWidget))
            }
            gtk_widget_set_valign(asWidget(viewWidget), GTK_ALIGN_CENTER)
            gtk_box_append(asBox(bar), asWidget(viewWidget))
            windowToolbarViews[window.rawValue, default: []].append(viewWidget)
            return
        }
        appendToolbarButton(for: item, displayMode: displayMode, to: bar)
    }

    internal func appendToolbarButton(
        for item: NativeToolbarItemSpec,
        displayMode: NativeToolbarDisplayMode,
        to bar: OpaquePointer
    ) {
        let button: UnsafeMutablePointer<GtkWidget>
        if let content = makeToolbarItemContent(item, displayMode: displayMode) {
            button = gtk_button_new()!
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
        gtk_box_append(asBox(bar), button)
    }
    /// Builds a toolbar item's visual content for a display mode: icon over
    /// label (Apple's .iconAndLabel), icon only, or label only. Returns nil
    /// when there is nothing but a plain label to show.
    internal func makeToolbarItemContent(_ item: NativeToolbarItemSpec,
                                        displayMode: NativeToolbarDisplayMode) -> UnsafeMutablePointer<GtkWidget>? {
        var icon: UnsafeMutablePointer<GtkWidget>?
        if displayMode != .labelOnly {
            if let path = item.imagePath {
                icon = makeToolbarImage(path: path, template: item.imageIsTemplate)
            } else if let iconName = item.iconName {
                let themed = gtk_image_new_from_icon_name(iconName)!
                gtk_image_set_pixel_size(OpaquePointer(themed), 22)
                icon = themed
            }
        }
        guard icon != nil || displayMode == .labelOnly else { return nil }
        let content = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2)!
        gtk_widget_set_halign(content, GTK_ALIGN_CENTER)
        if let icon { gtk_box_append(asBox(OpaquePointer(content)), icon) }
        if displayMode != .iconOnly && !item.label.isEmpty {
            gtk_box_append(asBox(OpaquePointer(content)), gtk_label_new(item.label))
        }
        if displayMode == .labelOnly && item.label.isEmpty { return nil }
        return content
    }

    /// Loads a file-backed toolbar icon. Template images are pure-alpha
    /// artwork (the demo's Tabler PNGs are black-on-transparent): recolor every
    /// pixel to the theme foreground, keeping alpha — AppKit's template
    /// semantics, so one shipped image serves both appearances.
}

#endif
