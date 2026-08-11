#if canImport(CGTK)
import CGTK
import CGTKCompat
import Foundation

extension GTKNativeControlBackend {
    internal func makeToolbarImage(path: String, template: Bool) -> UnsafeMutablePointer<GtkWidget>? {
        guard let pixbuf = gdk_pixbuf_new_from_file(path, nil) else { return nil }
        if template, gdk_pixbuf_get_has_alpha(pixbuf) != 0, gdk_pixbuf_get_n_channels(pixbuf) == 4 {
            let foreground = prefersDarkAppearance
                ? GTKRGB(red: 238, green: 238, blue: 236)
                : GTKRGB(red: 46, green: 52, blue: 54)
            let width = Int(gdk_pixbuf_get_width(pixbuf))
            let height = Int(gdk_pixbuf_get_height(pixbuf))
            let stride = Int(gdk_pixbuf_get_rowstride(pixbuf))
            if let pixels = gdk_pixbuf_get_pixels(pixbuf) {
                for y in 0..<height {
                    for x in 0..<width {
                        let p = pixels + y * stride + x * 4
                        p[0] = foreground.red
                        p[1] = foreground.green
                        p[2] = foreground.blue
                    }
                }
            }
        }
        guard let texture = gdk_texture_new_for_pixbuf(pixbuf) else { return nil }
        let image = gtk_image_new_from_paintable(texture)!
        gtk_image_set_pixel_size(OpaquePointer(image), 22)
        return image
    }

    /// The open customization panel's live widgets, for in-place refresh.
    internal struct CustomizationPanelState {
        var panel: OpaquePointer
        var stripHolder: OpaquePointer
        var paletteHolder: OpaquePointer
        var handlers: NativeToolbarCustomizationHandlers
        var displayModeIndex: Int
    }
    /// Presents the toolbar customization panel as a modal `GtkWindow` with duplicate strip, palette, and default set.
    public func runToolbarCustomization(_ session: NativeToolbarCustomizationSession,
                                        handlers: NativeToolbarCustomizationHandlers,
                                        for window: NativeHandle) {
        let panel = gtk_window_new()!
        gtk_window_set_title(asWindow(OpaquePointer(panel)), "Customize Toolbar")
        gtk_window_set_resizable(asWindow(OpaquePointer(panel)), gboolean(0))
        if let parent = widget(window) {
            gtk_window_set_transient_for(asWindow(OpaquePointer(panel)), asWindow(parent))
        }
        if !nonComposited { gtk_window_set_modal(asWindow(OpaquePointer(panel)), gboolean(1)) }

        let widgets = makeCustomizationWidgets(for: session)
        let vbox = widgets.content
        appendCustomizationBottomRow(
            to: vbox,
            panel: panel,
            displayModeIndex: session.displayModeIndex,
            handlers: handlers
        )

        // Dropping a strip item on the panel body (not the strip) removes it —
        // Apple's drag-off-the-toolbar gesture.
        addDropTarget(to: vbox) { [weak self] payload, _, _ in
            guard let self, self.customizationState != nil else { return false }
            if payload.hasPrefix("strip:"), let index = Int(payload.dropFirst(6)) {
                self.customizationState?.handlers.onRemove(index)
                return true
            }
            return false
        }

        // The window-close (X) also ends the session.
        let closeBox = WindowCloseBox(
            shouldClose: { true },
            didClose: { [weak self] in
                self?.customizationState = nil
                handlers.onClose()
            },
            destroysSurface: true
        )
        g_signal_connect_data(
            UnsafeMutableRawPointer(panel), "close-request",
            unsafeBitCast(gtkCloseRequestTrampoline, to: GCallback.self),
            Unmanaged.passRetained(closeBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )

        gtk_window_set_child(asWindow(OpaquePointer(panel)), vbox)
        customizationState = CustomizationPanelState(panel: OpaquePointer(panel),
                                                     stripHolder: OpaquePointer(widgets.stripHolder),
                                                     paletteHolder: OpaquePointer(widgets.paletteHolder),
                                                     handlers: handlers,
                                                     displayModeIndex: session.displayModeIndex)
        rebuildCustomizationContent(session)
        gtk_window_present(asWindow(OpaquePointer(panel)))
    }

    internal func makeCustomizationWidgets(
        for session: NativeToolbarCustomizationSession
    ) -> GTKCustomizationWidgets {
        let content = gtk_box_new(GTK_ORIENTATION_VERTICAL, 12)!
        gtk_widget_set_margin_top(content, 16)
        gtk_widget_set_margin_bottom(content, 14)
        gtk_widget_set_margin_start(content, 20)
        gtk_widget_set_margin_end(content, 20)
        gtk_widget_add_css_class(content, "linchocolate-palette")
        let stripHolder = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        gtk_box_append(asBox(OpaquePointer(content)), stripHolder)
        let heading = gtk_label_new("Drag your favorite items into the toolbar…")!
        gtk_widget_set_halign(heading, GTK_ALIGN_START)
        gtk_box_append(asBox(OpaquePointer(content)), heading)
        let paletteHolder = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        gtk_box_append(asBox(OpaquePointer(content)), paletteHolder)
        let defaultHeading = gtk_label_new("… or drag the default set into the toolbar.")!
        gtk_widget_set_halign(defaultHeading, GTK_ALIGN_START)
        gtk_box_append(asBox(OpaquePointer(content)), defaultHeading)
        let defaultBar = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 4)!
        gtk_widget_add_css_class(defaultBar, "linchocolate-toolbar")
        for item in session.defaultSet {
            let tile = makeStripTileWidget(spec(for: item), displayMode: .iconAndLabel)
            gtk_widget_set_sensitive(tile, gboolean(0))
            gtk_box_append(asBox(OpaquePointer(defaultBar)), tile)
        }
        addDragSource(to: defaultBar, payload: "default")
        gtk_box_append(asBox(OpaquePointer(content)), defaultBar)
        return GTKCustomizationWidgets(
            content: content,
            stripHolder: stripHolder,
            paletteHolder: paletteHolder
        )
    }

    internal func appendCustomizationBottomRow(
        to content: UnsafeMutablePointer<GtkWidget>,
        panel: UnsafeMutablePointer<GtkWidget>,
        displayModeIndex: Int,
        handlers: NativeToolbarCustomizationHandlers
    ) {
        let bottom = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8)!
        gtk_box_append(asBox(OpaquePointer(bottom)), gtk_label_new("Show"))
        let modeNames = ["Icon and Text", "Icon Only", "Text Only"]
        var modeStrings: [UnsafePointer<CChar>?] = modeNames.map {
            UnsafePointer(strdup($0))
        }
        modeStrings.append(nil)
        let dropdown = modeStrings.withUnsafeMutableBufferPointer {
            gtk_drop_down_new_from_strings($0.baseAddress)!
        }
        gtk_drop_down_set_selected(OpaquePointer(dropdown), guint(displayModeIndex))
        let modeBox = DropDownBox(dropdown: OpaquePointer(dropdown)) { [weak self] index in
            guard let self, self.customizationState != nil else { return }
            handlers.onDisplayMode(index)
        }
        g_signal_connect_data(
            UnsafeMutableRawPointer(dropdown), "notify::selected",
            unsafeBitCast(gtkDropDownSelectedTrampoline, to: GCallback.self),
            Unmanaged.passRetained(modeBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        gtk_box_append(asBox(OpaquePointer(bottom)), dropdown)
        let spacer = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
        gtk_widget_set_hexpand(spacer, gboolean(1))
        gtk_box_append(asBox(OpaquePointer(bottom)), spacer)
        let done = gtk_button_new_with_label("Done")!
        gtk_widget_add_css_class(done, "suggested-action")
        let doneBox = ActionBox { [weak self] in
            self?.customizationState = nil
            handlers.onClose()
            gtk_window_destroy(UnsafeMutablePointer<GtkWindow>(OpaquePointer(panel)))
        }
        g_signal_connect_data(
            UnsafeMutableRawPointer(done), "clicked",
            unsafeBitCast(gtkActionTrampoline, to: GCallback.self),
            Unmanaged.passRetained(doneBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        gtk_box_append(asBox(OpaquePointer(bottom)), done)
        gtk_box_append(asBox(OpaquePointer(content)), bottom)
    }

    /// Refreshes the open customization panel's strip and palette in place.
    public func updateToolbarCustomization(_ session: NativeToolbarCustomizationSession) {
        guard customizationState != nil else { return }
        customizationState?.displayModeIndex = session.displayModeIndex
        rebuildCustomizationContent(session)
    }

    /// (Re)fills the strip duplicate and palette grid from the session.
    internal func rebuildCustomizationContent(_ session: NativeToolbarCustomizationSession) {
        guard let state = customizationState else { return }
        rebuildCustomizationStrip(session, state: state)
        rebuildCustomizationPalette(session, state: state)
    }

    internal func rebuildCustomizationStrip(
        _ session: NativeToolbarCustomizationSession,
        state: CustomizationPanelState
    ) {
        while let child = gtk_widget_get_first_child(asWidget(state.stripHolder)) {
            gtk_box_remove(asBox(state.stripHolder), child)
        }
        let strip = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 4)!
        gtk_widget_add_css_class(strip, "linchocolate-toolbar")
        gtk_widget_set_size_request(strip, 660, 52)
        let displayMode: NativeToolbarDisplayMode = [.iconAndLabel, .iconOnly, .labelOnly][min(max(state.displayModeIndex, 0), 2)]
        for (index, item) in session.strip.enumerated() {
            let tile = makeStripTileWidget(item, displayMode: displayMode)
            addDragSource(to: tile, payload: "strip:\(index)")
            gtk_box_append(asBox(OpaquePointer(strip)), tile)
        }
        addDropTarget(to: strip) { [weak self] payload, x, _ in
            guard let self, let state = self.customizationState else { return false }
            let index = self.stripInsertionIndex(in: OpaquePointer(strip), x: x)
            if payload == "default" {
                state.handlers.onResetToDefault()
                return true
            }
            if payload.hasPrefix("new:") {
                state.handlers.onInsert(String(payload.dropFirst(4)), index)
                return true
            }
            if payload.hasPrefix("strip:"), let from = Int(payload.dropFirst(6)) {
                state.handlers.onMove(from, index)
                return true
            }
            return false
        }
        gtk_box_append(asBox(state.stripHolder), strip)
    }

    internal func rebuildCustomizationPalette(
        _ session: NativeToolbarCustomizationSession,
        state: CustomizationPanelState
    ) {
        while let child = gtk_widget_get_first_child(asWidget(state.paletteHolder)) {
            gtk_box_remove(asBox(state.paletteHolder), child)
        }
        let columns = 4
        let grid = gtk_grid_new()!
        gtk_grid_set_row_spacing(asGrid(OpaquePointer(grid)), 8)
        gtk_grid_set_column_spacing(asGrid(OpaquePointer(grid)), 8)
        let multiInstance: Set<String> = ["NSToolbarSeparatorItem", "NSToolbarSpaceItem", "NSToolbarFlexibleSpaceItem"]
        for (index, item) in session.palette.enumerated() {
            let tile = gtk_box_new(GTK_ORIENTATION_VERTICAL, 3)!
            gtk_widget_add_css_class(tile, "linchocolate-palette-tile")
            gtk_widget_set_size_request(tile, 120, 56)
            let content = makeStripTileWidget(spec(for: item), displayMode: .iconAndLabel)
            gtk_widget_set_valign(content, GTK_ALIGN_CENTER)
            gtk_widget_set_vexpand(content, gboolean(1))
            gtk_widget_set_halign(content, GTK_ALIGN_CENTER)
            gtk_box_append(asBox(OpaquePointer(tile)), content)
            if item.isInToolbar && !multiInstance.contains(item.identifier) {
                gtk_widget_set_sensitive(tile, gboolean(0))   // dimmed, as on Apple
            } else {
                addDragSource(to: tile, payload: "new:\(item.identifier)")
            }
            gtk_grid_attach(asGrid(OpaquePointer(grid)), tile,
                            gint(index % columns), gint(index / columns), 1, 1)
        }
        gtk_box_append(asBox(state.paletteHolder), grid)
    }

    /// A palette entry rendered as an item spec (for the shared tile builder).
    internal func spec(for item: NativeToolbarPaletteItem) -> NativeToolbarItemSpec {
        NativeToolbarItemSpec(imagePath: item.imagePath, imageIsTemplate: item.imageIsTemplate,
                              identifier: item.identifier, label: item.label,
                              iconName: item.iconName)
    }

    /// A strip/palette tile: the item content in a flat button-look box.
    internal func makeStripTileWidget(_ item: NativeToolbarItemSpec,
                                     displayMode: NativeToolbarDisplayMode) -> UnsafeMutablePointer<GtkWidget> {
        if item.identifier == "NSToolbarSeparatorItem" {
            let divider = gtk_separator_new(GTK_ORIENTATION_VERTICAL)!
            gtk_widget_set_margin_top(divider, 6); gtk_widget_set_margin_bottom(divider, 6)
            return divider
        }
        if item.identifier == "NSToolbarFlexibleSpaceItem" || item.identifier == "NSToolbarSpaceItem" {
            let label = gtk_label_new(item.identifier == "NSToolbarSpaceItem" ? "Space" : "Flexible Space")!
            gtk_widget_add_css_class(label, "dim-label")
            return label
        }
        if let content = makeToolbarItemContent(item, displayMode: displayMode) {
            return content
        }
        return gtk_label_new(item.label)!
    }

    /// The insertion index for a drop at `x` over the strip: before the first
    /// tile whose midpoint is right of the pointer.
    internal func stripInsertionIndex(in strip: OpaquePointer, x: Double) -> Int {
        var index = 0
        var child = gtk_widget_get_first_child(asWidget(strip))
        var edge = 0.0
        while let current = child {
            let width = Double(gtk_widget_get_width(current))
            if x < edge + width / 2 { return index }
            edge += width + 4
            index += 1
            child = gtk_widget_get_next_sibling(current)
        }
        return index
    }

    /// Attaches a string drag source carrying `payload`.
    internal func addDragSource(to widget: UnsafeMutablePointer<GtkWidget>, payload: String) {
        let source = gtk_drag_source_new()
        gtk_drag_source_set_actions(source, GDK_ACTION_COPY)
        let box = DragPayloadBox(payload)
        g_signal_connect_data(
            UnsafeMutableRawPointer(source), "prepare",
            unsafeBitCast(gtkPaletteDragPrepareTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        gtk_widget_add_controller(widget, source)
    }

    /// Attaches a string drop target; `handle` reports whether the drop landed.
    internal func addDropTarget(to widget: UnsafeMutablePointer<GtkWidget>,
                               handle: @escaping (String, Double, Double) -> Bool) {
        let target = gtk_drop_target_new(GType(16 << 2), GDK_ACTION_COPY)
        let box = DropHandlerBox(handle)
        g_signal_connect_data(
            UnsafeMutableRawPointer(target), "drop",
            unsafeBitCast(gtkPaletteDropTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        gtk_widget_add_controller(widget, target)
    }

    /// Presents a modal `GtkFileDialog` in open mode and returns the chosen path (nil on cancel).
}

#endif
