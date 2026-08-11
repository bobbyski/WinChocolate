#if canImport(CGTK)
import CGTK
import CGTKCompat
import Foundation

// MARK: - GObject signal glue
//
// GTK signal handlers must be bare C function pointers, so the Swift closure is
// boxed and passed as `user_data`; a destroy-notify releases the box when the
// signal is disconnected. These live at file scope because @convention(c)
// closures cannot capture context.

internal final class ActionBox {
    let action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
}
internal final class MenuActionBox {
    let root: UnsafeMutablePointer<GtkWidget>
    let action: () -> Void
    init(root: UnsafeMutablePointer<GtkWidget>, action: @escaping () -> Void) {
        self.root = root
        self.action = action
    }
}
internal final class WindowCloseBox {
    let shouldClose: () -> Bool
    let didClose: () -> Void
    let destroysSurface: Bool
    init(shouldClose: @escaping () -> Bool, didClose: @escaping () -> Void,
         destroysSurface: Bool = false) {
        self.shouldClose = shouldClose
        self.didClose = didClose
        self.destroysSurface = destroysSurface
    }
}
internal final class DeferredLoopQuitBox {
    let loop: OpaquePointer
    init(loop: OpaquePointer) { self.loop = loop }
}
internal final class StringActionBox {
    let action: (String) -> Void
    init(_ action: @escaping (String) -> Void) { self.action = action }
}
internal final class BoolActionBox {
    let action: (Bool) -> Void
    init(_ action: @escaping (Bool) -> Void) { self.action = action }
}
internal final class DoubleActionBox {
    let action: (Double) -> Void
    init(_ action: @escaping (Double) -> Void) { self.action = action }
}
internal final class IntActionBox {
    let action: (Int) -> Void
    init(_ action: @escaping (Int) -> Void) { self.action = action }
}
internal final class DateActionBox {
    let action: (Date) -> Void
    init(_ action: @escaping (Date) -> Void) { self.action = action }
}
internal final class SegmentBox {
    let index: Int
    let action: (Int) -> Void
    init(index: Int, action: @escaping (Int) -> Void) { self.index = index; self.action = action }
}
internal final class WidgetBox {
    let widget: UnsafeMutablePointer<GtkWidget>
    init(widget: UnsafeMutablePointer<GtkWidget>) { self.widget = widget }
}
internal final class DropBox {
    let onDrop: (String, Double, Double) -> Bool
    init(_ onDrop: @escaping (String, Double, Double) -> Bool) { self.onDrop = onDrop }
}
internal final class DragProviderBox {
    let provider: () -> String?
    init(_ provider: @escaping () -> String?) { self.provider = provider }
}
internal final class ScrollBox {
    let hadj: UnsafeMutablePointer<GtkAdjustment>
    let vadj: UnsafeMutablePointer<GtkAdjustment>
    let action: (Double, Double) -> Void
    init(hadj: UnsafeMutablePointer<GtkAdjustment>, vadj: UnsafeMutablePointer<GtkAdjustment>, action: @escaping (Double, Double) -> Void) {
        self.hadj = hadj; self.vadj = vadj; self.action = action
    }
}

internal final class DrawBox {
    weak var backend: GTKNativeControlBackend?
    let view: UInt
    init(backend: GTKNativeControlBackend, view: UInt) {
        self.backend = backend
        self.view = view
    }
}

/// Cairo-backed graphics context: NSBezierPath ops map 1:1 onto the cairo_t.
final class CairoGraphicsContext: NativeGraphicsContext {
    internal let cr: OpaquePointer
    /// Whether drawing happens in a top-left (y-down) space; affects arc winding.
    internal let flipped: Bool
    internal var fillColor = NSColor.black
    internal var strokeColor = NSColor.black
    internal var lineWidth = 1.0

    init(cr: OpaquePointer, flipped: Bool = false) { self.cr = cr; self.flipped = flipped }

    func setFillColor(_ color: NSColor) { fillColor = color }
    func setStrokeColor(_ color: NSColor) { strokeColor = color }
    func setLineWidth(_ width: Double) { lineWidth = width }
    func beginPath() { cairo_new_path(cr) }
    func move(toX x: Double, y: Double) { cairo_move_to(cr, x, y) }
    func line(toX x: Double, y: Double) { cairo_line_to(cr, x, y) }
    func curve(_ curve: NativeBezierCurve) {
        cairo_curve_to(
            cr,
            curve.controlPoint1.x,
            curve.controlPoint1.y,
            curve.controlPoint2.x,
            curve.controlPoint2.y,
            curve.endpoint.x,
            curve.endpoint.y
        )
    }
    func addArc(_ arc: NativeArc) {
        // `cairo_arc` sweeps by increasing angle: counter-clockwise on screen in
        // a y-up (unflipped, axis-scaled) space, but clockwise in a y-down
        // (flipped/top-left) space. Pick the sweep so the visual winding matches
        // the requested `clockwise`, and prefer `cairo_arc` for a given winding
        // since a full 0…2π sweep stays a circle (cairo_arc_negative collapses it).
        let useForwardSweep = flipped ? arc.clockwise : !arc.clockwise
        if useForwardSweep {
            cairo_arc(
                cr,
                arc.center.x,
                arc.center.y,
                arc.radius,
                arc.startAngleRadians,
                arc.endAngleRadians
            )
        } else {
            cairo_arc_negative(
                cr,
                arc.center.x,
                arc.center.y,
                arc.radius,
                arc.startAngleRadians,
                arc.endAngleRadians
            )
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

    func drawText(_ text: String, at point: NSPoint, font: NativeFontSpec?, color: NSColor) {
        cairo_save(cr)
        cairo_select_font_face(cr, font?.family ?? "Sans",
                               (font?.italic ?? false) ? CAIRO_FONT_SLANT_ITALIC : CAIRO_FONT_SLANT_NORMAL,
                               (font?.bold ?? false) ? CAIRO_FONT_WEIGHT_BOLD : CAIRO_FONT_WEIGHT_NORMAL)
        cairo_set_font_size(cr, font?.size ?? 13)
        cairo_set_source_rgba(cr, Double(color.redComponent), Double(color.greenComponent),
                              Double(color.blueComponent), Double(color.alphaComponent))
        // AppKit's draw(at:) places the text's TOP-left at the point; cairo's
        // baseline sits at the pen, so drop by the font ascent.
        var extents = cairo_font_extents_t()
        cairo_font_extents(cr, &extents)
        cairo_move_to(cr, Double(point.x), Double(point.y) + extents.ascent)
        cairo_show_text(cr, text)
        cairo_new_path(cr)   // show_text leaves the text path pending
        cairo_restore(cr)
    }

    func drawImage(atPath path: String, inRect rect: NSRect) {
        guard rect.width > 0, rect.height > 0,
              let pixbuf = gdk_pixbuf_new_from_file_at_scale(
                path, Int32(rect.width), Int32(rect.height), gboolean(0), nil) else { return }
        cairo_save(cr)
        gdk_cairo_set_source_pixbuf(cr, pixbuf, Double(rect.minX), Double(rect.minY))
        cairo_rectangle(cr, Double(rect.minX), Double(rect.minY), Double(rect.width), Double(rect.height))
        cairo_fill(cr)
        cairo_restore(cr)
        g_object_unref(UnsafeMutableRawPointer(pixbuf))
    }

    /// Applies the stops to a cairo pattern and fills `rect` with it.
    internal func fill(rect: NSRect, pattern: OpaquePointer, stops: [NativeGradientStop]) {
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
internal let gtkDrawFunc: @convention(c) (UnsafeMutablePointer<GtkDrawingArea>?, OpaquePointer?, Int32, Int32, gpointer?) -> Void = { _, cr, width, height, userData in
    guard let cr, let userData else { return }
    let box = Unmanaged<DrawBox>.fromOpaque(userData).takeUnretainedValue()
    cairo_save(cr)
    // A flipped view (top-left origin, e.g. the WinChocolate demo) draws in
    // GTK's native space directly; an unflipped AppKit view (bottom-left, +Y up)
    // needs the axis flip.
    let flipped = box.backend?.isViewFlipped(box.view) ?? false
    // `NSScrollView.magnification` grew this view's allocation by `zoom`; we
    // apply the same factor to Cairo so the Swift draw code still authors in
    // its natural coordinate space.
    let zoom = box.backend?.viewMagnification(box.view) ?? 1
    let context = CairoGraphicsContext(cr: cr, flipped: flipped)
    if !flipped {
        cairo_translate(cr, 0, Double(height))
        cairo_scale(cr, 1, -1)
    }
    if zoom != 1 { cairo_scale(cr, zoom, zoom) }
    box.backend?.dispatchDraw(view: box.view, context: context,
                              width: Double(width) / zoom, height: Double(height) / zoom)
    cairo_restore(cr)
}

/// Shared state for one modal file-dialog run.
internal final class FileDialogState {
    let loop: OpaquePointer?
    let open: Bool          // open vs save (selects the *_finish call)
    var path: String?
    init(loop: OpaquePointer?, open: Bool) { self.loop = loop; self.open = open }
}

/// `GAsyncReadyCallback` for GtkFileDialog open/save — extracts the chosen
/// file's path (nil on cancel) and quits the nested loop.
internal let fileDialogFinishedCallback: @convention(c) (UnsafeMutableRawPointer?, OpaquePointer?, gpointer?) -> Void = { source, result, data in
    _ = source
    _ = result
    guard let data else { return }
    let state = Unmanaged<FileDialogState>.fromOpaque(data).takeRetainedValue()
    g_main_loop_quit(state.loop)
}

/// Shared state for one modal alert run: the nested loop and the response.
internal final class AlertState {
    let loop: OpaquePointer?
    var response = 0
    init(loop: OpaquePointer?) { self.loop = loop }
}
/// `GtkWindow::close-request` on an alert — treat closing as a dismissal so the
/// nested loop ends and `runAlert` returns.
///
/// Returns TRUE (handled), which STOPS GTK's default close. That matters:
/// `runAlert` destroys the alert itself once its loop ends, so letting GTK also
/// destroy it here means the window is destroyed twice — an X error that takes
/// the whole app down.
internal let gtkAlertCloseTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> gboolean = { _, userData in
    guard let userData else { return gboolean(0) }
    let box = Unmanaged<AlertButtonBox>.fromOpaque(userData).takeUnretainedValue()
    box.state.response = box.index
    if let loop = box.state.loop, g_main_loop_is_running(loop) != 0 {
        g_main_loop_quit(loop)
    }
    return gboolean(1)
}

internal final class AlertButtonBox {
    let index: Int
    let state: AlertState
    init(index: Int, state: AlertState) { self.index = index; self.state = state }
}
internal final class ColorActionBox {
    let action: (NSColor) -> Void
    init(_ action: @escaping (NSColor) -> Void) { self.action = action }
}

/// Handler for `GtkButton::clicked` — `void (*)(GtkButton*, gpointer)`.
internal let gtkActionTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { _, userData in
    guard let userData else { return }
    Unmanaged<ActionBox>.fromOpaque(userData).takeUnretainedValue().action()
}

/// Handles a title-bar close while preserving reusable GTK child widgets.
internal let gtkCloseRequestTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> gboolean = { window, userData in
    guard let window, let userData else { return gboolean(1) }
    let box = Unmanaged<WindowCloseBox>.fromOpaque(userData).takeUnretainedValue()
    guard box.shouldClose() else { return gboolean(1) }
    if box.destroysSurface {
        gtk_window_destroy(UnsafeMutablePointer<GtkWindow>(OpaquePointer(window)))
        box.didClose()
    } else {
        gtk_widget_set_visible(UnsafeMutablePointer<GtkWidget>(OpaquePointer(window)), gboolean(0))
    }
    // TRUE: either the delegate vetoed the request or we hid the window and
    // notified the shared lifecycle. GTK must not destroy reusable children.
    return gboolean(1)
}

/// Handler for `GtkEditable::changed` — reads the new text off the widget.
internal let gtkTextChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { editable, userData in
    guard let editable, let userData else { return }
    let cText = gtk_editable_get_text(OpaquePointer(editable))
    let text = cText.map { String(cString: $0) } ?? ""
    Unmanaged<StringActionBox>.fromOpaque(userData).takeUnretainedValue().action(text)
}

/// Handler for `GtkCheckButton::toggled` — reads the new active state.
internal let gtkToggledTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { button, userData in
    guard let button, let userData else { return }
    let active = gtk_check_button_get_active(UnsafeMutablePointer<GtkCheckButton>(OpaquePointer(button))) != 0
    Unmanaged<BoolActionBox>.fromOpaque(userData).takeUnretainedValue().action(active)
}

/// Handler for `GtkRange::value-changed` — reads the new slider value.
internal let gtkValueChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { range, userData in
    guard let range, let userData else { return }
    let value = gtk_range_get_value(UnsafeMutablePointer<GtkRange>(OpaquePointer(range)))
    Unmanaged<DoubleActionBox>.fromOpaque(userData).takeUnretainedValue().action(value)
}

/// Handler for `GtkSpinButton::value-changed` — reads the spin button's value.
internal let gtkSpinValueChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { spin, userData in
    guard let spin, let userData else { return }
    let value = gtk_spin_button_get_value(OpaquePointer(spin))
    Unmanaged<DoubleActionBox>.fromOpaque(userData).takeUnretainedValue().action(value)
}

/// Handler for `GtkTextBuffer::changed` — reads the whole buffer text.
internal let gtkTextBufferChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { buffer, userData in
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
internal let gtkSelectionChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { dropdown, _, userData in
    guard let dropdown, let userData else { return }
    let index = Int(gtk_drop_down_get_selected(OpaquePointer(dropdown)))
    popdownVisiblePopovers(under: UnsafeMutablePointer<GtkWidget>(OpaquePointer(dropdown)))
    Unmanaged<IntActionBox>.fromOpaque(userData).takeUnretainedValue().action(index)
}

internal final class TableColumnBox {
    weak var backend: GTKNativeControlBackend?
    let table: UInt
    let column: Int
    let editable: Bool
    init(backend: GTKNativeControlBackend, table: UInt, column: Int, editable: Bool = false) {
        self.backend = backend
        self.table = table
        self.column = column
        self.editable = editable
    }
}

internal final class OutlineBox {
    weak var backend: GTKNativeControlBackend?
    var outline: UInt = 0   // assigned right after the handle is allocated
    init(backend: GTKNativeControlBackend) { self.backend = backend }
}

/// Carries a customization-palette row's identifier + toggle closure.
internal final class ToolbarToggleBox {
    let id: String
    let action: (String, Bool) -> Void
    init(id: String, action: @escaping (String, Bool) -> Void) {
        self.id = id
        self.action = action
    }
}

/// Handler for a customization-palette checkbox `toggled` — reports (id, on).
/// Carries a repeating timer's block to its g_timeout callback.
internal final class TimerBox {
    let block: () -> Void
    let repeats: Bool
    init(block: @escaping () -> Void, repeats: Bool) {
        self.block = block
        self.repeats = repeats
    }
}

/// Carries a flow-box child to its capture-phase select-on-click gesture.
internal final class FlowChildBox {
    let flow: OpaquePointer
    let child: OpaquePointer
    init(flow: OpaquePointer, child: OpaquePointer) {
        self.flow = flow
        self.child = child
    }
}

/// Capture-phase `pressed` on a flow-box child: select it, let the event
/// continue to the hosted control.
internal let gtkFlowChildSelectTrampoline: @convention(c) (UnsafeMutableRawPointer?, gint, Double, Double, gpointer?) -> Void = { _, _, _, _, userData in
    guard let userData else { return }
    let box = Unmanaged<FlowChildBox>.fromOpaque(userData).takeUnretainedValue()
    gtk_flow_box_select_child(box.flow, UnsafeMutablePointer<GtkFlowBoxChild>(box.child))
}

/// Carries a custom view's mouse-event handler.
internal final class MouseBox {
    let handler: (NativeMouseEvent) -> Void
    init(_ handler: @escaping (NativeMouseEvent) -> Void) { self.handler = handler }
}
internal final class MouseClickBox {
    let handler: (NativeMouseEvent) -> Void
    let rightButton: Bool
    init(handler: @escaping (NativeMouseEvent) -> Void, rightButton: Bool) {
        self.handler = handler
        self.rightButton = rightButton
    }
}

/// `GtkEventControllerMotion::enter` — pointer entered the view.
internal let gtkMotionEnterTrampoline: @convention(c) (UnsafeMutableRawPointer?, Double, Double, gpointer?) -> Void = { _, x, y, userData in
    guard let userData else { return }
    Unmanaged<MouseBox>.fromOpaque(userData).takeUnretainedValue().handler(.entered(x: x, y: y))
}
/// `GtkEventControllerMotion::leave` — pointer left the view.
internal let gtkMotionLeaveTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { _, userData in
    guard let userData else { return }
    Unmanaged<MouseBox>.fromOpaque(userData).takeUnretainedValue().handler(.exited)
}
/// `GtkGestureClick::pressed` on a custom view — n_press is the click count.
internal let gtkMousePressTrampoline: @convention(c) (UnsafeMutableRawPointer?, gint, Double, Double, gpointer?) -> Void = { _, nPress, x, y, userData in
    guard let userData else { return }
    let box = Unmanaged<MouseClickBox>.fromOpaque(userData).takeUnretainedValue()
    box.handler(.down(x: x, y: y, clickCount: Int(nPress), rightButton: box.rightButton))
}
/// `GtkEventControllerScroll::scroll` — dy>0 means scroll down in GTK, which is
/// AppKit's negative `scrollingDeltaY`, so flip the sign. Returns FALSE (event
/// NOT consumed): this controller sits on EVERY custom view, including the
/// document views inside NSScrollViews, so consuming here would kill scroll-view
/// panning app-wide. A view that reacts to the wheel (the demo's canvas) still
/// gets its callback; letting the event propagate just also lets an enclosing
/// scroller scroll, which is AppKit's behavior for a non-overriding view.
internal let gtkScrollTrampoline: @convention(c) (UnsafeMutableRawPointer?, Double, Double, gpointer?) -> gboolean = { _, dx, dy, userData in
    guard let userData else { return gboolean(0) }
    Unmanaged<MouseBox>.fromOpaque(userData).takeUnretainedValue().handler(.scroll(deltaX: -dx, deltaY: -dy))
    return gboolean(0)
}

/// Carries a view's click action to its gesture handler.

#endif
