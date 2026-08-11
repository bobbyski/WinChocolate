#if canImport(CGTK)
import CGTK
import CGTKCompat
import Foundation

extension GTKNativeControlBackend {
    internal func viewTextContent(_ text: String) -> UnsafeMutablePointer<GtkWidget>? {
        let fields = text.components(separatedBy: "\t")
        guard fields.first == "__WinChocolateToolbarItem" else {
            let plain = text.trimmingCharacters(in: .whitespacesAndNewlines)
            // `NSToolbarSeparatorView` marks itself with a bare "separator";
            // it is a drawn bar, not a caption.
            guard !plain.isEmpty, plain != "separator" else { return nil }
            return gtk_label_new(plain)
        }

        let title = fields.count > 1 ? fields[1] : ""
        let imageName = fields.count > 2 ? fields[2] : ""
        let showItem = fields.count > 3 && fields[3] == "1"
        let showLabel = fields.count > 4 && fields[4] == "1"
        let labelBeside = fields.count > 5 && fields[5] == "beside"

        let image: UnsafeMutablePointer<GtkWidget>? = (showItem && !imageName.isEmpty)
            ? (FileManager.default.fileExists(atPath: imageName)
                ? gtk_image_new_from_file(imageName)
                : gtk_image_new_from_icon_name(imageName))
            : nil
        image.map { gtk_image_set_pixel_size(OpaquePointer($0), 18) }
        let label: UnsafeMutablePointer<GtkWidget>? = (showLabel && !title.isEmpty)
            ? gtk_label_new(title) : nil

        switch (image, label) {
        case let (image?, label?):
            let box = gtk_box_new(labelBeside ? GTK_ORIENTATION_HORIZONTAL : GTK_ORIENTATION_VERTICAL, 2)!
            gtk_box_append(asBox(OpaquePointer(box)), image)
            gtk_box_append(asBox(OpaquePointer(box)), label)
            return box
        case let (image?, nil):  return image
        case let (nil, label?):  return label
        default:                 return nil
        }
    }
    /// Updates a control's frame, re-placing it inside its parent and re-placing its children.
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

        // Re-place at the new exact rect within our own parent...
        if let parentRaw = parents[handle.rawValue], let p = containerFixed(of: parentRaw) {
            setExactRect(placement(for: frame, in: parentRaw), on: w)
            gtk_widget_queue_allocate(asWidget(p))
        }
        // ...and re-place our children, whose Y is measured against our height
        // when we are unflipped.
        replaceChildren(of: handle.rawValue)
    }
    /// Attaches a `GtkGestureClick` reporting the press position in the view's coordinates.
    public func setClickAction(for handle: NativeHandle, action: @escaping (Double, Double) -> Void) {
        guard let w = widget(handle) else { return }
        let click = gtk_gesture_click_new()
        let box = ClickBox(action)
        g_signal_connect_data(
            UnsafeMutableRawPointer(click), "pressed",
            unsafeBitCast(gtkViewClickTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        gtk_widget_add_controller(asWidget(w), click)
    }

    /// Attaches motion and click controllers to deliver enter/leave/press events to `handler`.
    public func setMouseHandler(for handle: NativeHandle, _ handler: @escaping (NativeMouseEvent) -> Void) {
        guard let w = widget(handle) else { return }
        let widget = asWidget(w)

        // Enter/leave for hover tracking.
        let motion = gtk_event_controller_motion_new()
        let enterBox = MouseBox(handler)
        g_signal_connect_data(
            UnsafeMutableRawPointer(motion), "enter",
            unsafeBitCast(gtkMotionEnterTrampoline, to: GCallback.self),
            Unmanaged.passRetained(enterBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        let leaveBox = MouseBox(handler)
        g_signal_connect_data(
            UnsafeMutableRawPointer(motion), "leave",
            unsafeBitCast(gtkMotionLeaveTrampoline, to: GCallback.self),
            Unmanaged.passRetained(leaveBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        gtk_widget_add_controller(widget, motion)

        // Left + right press → mouseDown / rightMouseDown.
        for button in [guint(1), guint(3)] {
            let click = gtk_gesture_click_new()
            gtk_gesture_single_set_button(click, button)
            let clickBox = MouseClickBox(handler: handler, rightButton: button == 3)
            g_signal_connect_data(
                UnsafeMutableRawPointer(click), "pressed",
                unsafeBitCast(gtkMousePressTrampoline, to: GCallback.self),
                Unmanaged.passRetained(clickBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
            gtk_widget_add_controller(widget, click)
        }

        // Scroll wheel / trackpad → scrollWheel(with:).
        let scroll = gtk_event_controller_scroll_new(GTK_EVENT_CONTROLLER_SCROLL_BOTH_AXES)
        let scrollBox = MouseBox(handler)
        g_signal_connect_data(
            UnsafeMutableRawPointer(scroll), "scroll",
            unsafeBitCast(gtkScrollTrampoline, to: GCallback.self),
            Unmanaged.passRetained(scrollBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        gtk_widget_add_controller(widget, scroll)
    }

    /// Installs a Cairo draw function on the view's `GtkDrawingArea` that adapts to `NativeGraphicsContext`.
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
    /// Performs the `runPrintOperation` operation.
    public func runPrintOperation(view: NativeHandle, jobTitle: String, parent: NativeHandle?) -> Bool {
        guard drawHandlers[view.rawValue] != nil else { return false }
        let op = gtk_print_operation_new()!
        gtk_print_operation_set_n_pages(op, 1)
        gtk_print_operation_set_job_name(op, jobTitle)
        let frame = frames[view.rawValue] ?? NSMakeRect(0, 0, 320, 180)
        let box = PrintBox(backend: self, view: view.rawValue,
                           width: Double(frame.width), height: Double(frame.height))
        g_signal_connect_data(
            UnsafeMutableRawPointer(op), "draw-page",
            unsafeBitCast(gtkPrintDrawPageTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        // A headless/automation escape hatch: export to PDF instead of showing
        // the (modal, display-bound) print dialog. Keeps CI and the geometry
        // audit from blocking on a dialog while still exercising the render path.
        let result: GtkPrintOperationResult
        if let exportPath = ProcessInfo.processInfo.environment["LINCHOCOLATE_PRINT_EXPORT"], !exportPath.isEmpty {
            gtk_print_operation_set_export_filename(op, exportPath)
            result = gtk_print_operation_run(op, GTK_PRINT_OPERATION_ACTION_EXPORT, nil, nil)
        } else {
            let parentWindow = parent.flatMap { widget($0) }.map { asWindow($0) }
            result = gtk_print_operation_run(op, GTK_PRINT_OPERATION_ACTION_PRINT_DIALOG, parentWindow, nil)
        }
        g_object_unref(UnsafeMutableRawPointer(op))
        return result == GTK_PRINT_OPERATION_RESULT_APPLY
    }
    /// Renders the print page: wraps the print context's Cairo in a graphics
    /// context and runs the view's draw handler at its natural size, top-left.
    func drawPrintPage(view: UInt, printContext: OpaquePointer, width: Double, height: Double) {
        guard let cr = gtk_print_context_get_cairo_context(printContext) else { return }
        // The demo's print view is flipped (top-left origin), matching Cairo's
        // native space, so no axis flip — same as the on-screen flipped path.
        let context = CairoGraphicsContext(cr: cr, flipped: true)
        dispatchDraw(view: view, context: context, width: width, height: height)
    }
    /// Queues a redraw of the view's `GtkDrawingArea`.
    public func setNeedsDisplay(_ handle: NativeHandle) {
        guard let area = viewDrawAreas[handle.rawValue] else { return }
        if paintTrace {
            let ms = Double(g_get_monotonic_time() - paintTraceStart) / 1000.0
            FileHandle.standardError.write(
                Data(String(format: "LCPAINT %8.1fms [invalidate] view=%d\n", ms, Int(handle.rawValue)).utf8))
        }
        gtk_widget_queue_draw(asWidget(area))
    }
    /// Dispatches a draw pass to the Swift handler (called by the draw func).
    func dispatchDraw(view: UInt, context: NativeGraphicsContext, width: Double, height: Double) {
        if paintTrace, let window = contentViewOwners[view] {
            paintTraceFrames[window, default: 0] += 1
            tracePaint(window, "draw#\(paintTraceFrames[window] ?? 0)@\(Int(width))x\(Int(height))")
        }
        drawHandlers[view]?(context, width, height)
        noteContentDraw(view: view, width: width, height: height)
    }
    /// Sets the widget's sensitivity (`gtk_widget_set_sensitive`).
    public func setEnabled(_ isEnabled: Bool, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_widget_set_sensitive(asWidget(w), gboolean(isEnabled ? 1 : 0))
    }
    /// Sets the widget's visibility (`gtk_widget_set_visible`).
    public func setHidden(_ isHidden: Bool, for handle: NativeHandle) {
        guard let w = widget(handle) else { return }
        gtk_widget_set_visible(asWidget(w), gboolean(isHidden ? 0 : 1))
    }
    /// Renders `runs` as Pango markup on a `GtkLabel`.
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
    /// Applies a font to the widget via a display-wide scoped CSS rule.
    public func setFont(_ font: NativeFontSpec, for handle: NativeHandle) {
        widgetFonts[handle.rawValue] = font
        applyWidgetStyle(for: handle)
    }
    /// Applies a foreground text color via a display-wide scoped CSS rule.
    public func setTextColor(_ color: NSColor, for handle: NativeHandle) {
        widgetTextColors[handle.rawValue] = color
        applyWidgetStyle(for: handle)
    }

    /// Applies a theme-derived background to an `NSVisualEffectView`. The shade
    /// is expressed against GTK's theme-named colors (`@theme_bg_color`, …), so
    /// it flips automatically when the app switches to dark appearance — no real
    /// blur (XQuartz is non-composited), just a material-shaded surface.
    public func setMaterial(_ material: String, for handle: NativeHandle) {
        guard widget(handle) != nil else { return }
        let background: String
        switch material {
        case "sidebar", "underWindowBackground": background = "shade(@theme_bg_color, 0.93)"
        case "titlebar", "headerView":           background = "shade(@theme_bg_color, 1.05)"
        case "menu", "popover", "sheet":         background = "@theme_base_color"
        case "hudWindow":                        background = "alpha(@theme_fg_color, 0.55)"
        default:                                 background = "@theme_bg_color"
        }
        // 700 sits between the app (600) and per-widget font/color (800) layers.
        let cls = scopeClass(handle.rawValue)
        setScopedRule(".\(cls), .\(cls) * { background: \(background); }",
                      id: "material", priority: 700, for: handle)
    }

    /// Rebuilds and installs the widget-scoped CSS provider carrying the
    /// control's font and text color (GTK styles text via CSS, not API calls).
    internal func applyWidgetStyle(for handle: NativeHandle) {
        guard widget(handle) != nil else { return }

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
        // `text` reaches text-holding subnodes (GtkTextView, GtkEntry); the
        // `.cls *` arm reproduces the old widget-scoped `*` reach.
        // 800 = GTK_STYLE_PROVIDER_PRIORITY_USER (macro doesn't import).
        let cls = scopeClass(handle.rawValue)
        let rule = ".\(cls), .\(cls) * { \(body) } .\(cls) text, .\(cls) * text { \(body) }"
        setScopedRule(body.isEmpty ? nil : rule, id: "font", priority: 800, for: handle)
    }
    /// Sets a check button's on/off state.
}

#endif
