#if canImport(CGTK)
import CGTK
import CGTKCompat
import Foundation

extension GTKNativeControlBackend {

    // MARK: System

    /// Runs a block on the next main-loop iteration.
    public func dispatchAsync(_ action: @escaping () -> Void) {
        scheduleTimer(interval: 0, repeats: false, action)
    }

    /// Schedules a repeating native timer, returning a token to cancel it with.
    ///
    /// Scheduled directly on the GLib loop — NOT through `scheduleTimer`, which
    /// hands back no source id. The first version went through it, so the token
    /// mapped to nothing and `cancelNativeTimer` silently cancelled nothing.
    /// With `NSLayoutPump` arming a 1ms one-shot `Timer` on every layout mark,
    /// each mark minted an immortal 1ms repeating GLib timer: ~1,900 fires/s
    /// sitting idle, another ~1,000/s after every click — the "everything takes
    /// a second" sluggishness. The core's contract is repeat-until-cancelled
    /// (`Timer.fire()` invalidates one-shots itself), so cancellation is the
    /// whole mechanism and has to actually work.
    public func scheduleNativeTimer(intervalMilliseconds: Int,
                                    action: @escaping () -> Void) -> UInt {
        let token = coreSeam.nextTimerID
        coreSeam.nextTimerID += 1
        var action = action
        if paintTrace {
            let original = action
            let every = Double(intervalMilliseconds) / 1000.0
            let start = paintTraceStart
            action = {
                let ms = Double(g_get_monotonic_time() - start) / 1000.0
                FileHandle.standardError.write(
                    Data(String(format: "LCPAINT %8.1fms [timer] every=%.2fs\n", ms, every).utf8))
                original()
            }
        }
        let box = ActionBox(action)
        let source = g_timeout_add_full(
            G_PRIORITY_DEFAULT, guint(max(1, intervalMilliseconds)),
            { userData in
                guard let userData else { return gboolean(0) }
                Unmanaged<ActionBox>.fromOpaque(userData).takeUnretainedValue().action()
                return gboolean(1)   // repeat until cancelNativeTimer removes us
            },
            Unmanaged.passRetained(box).toOpaque(),
            { userData in   // GDestroyNotify: source removed -> release the box
                guard let userData else { return }
                Unmanaged<ActionBox>.fromOpaque(userData).release()
            }
        )
        coreSeam.timers[token] = source
        return token
    }

    /// Cancels a native timer.
    public func cancelNativeTimer(_ identifier: UInt) {
        if let source = coreSeam.timers.removeValue(forKey: identifier) {
            g_source_remove(source)
        }
    }

    /// Whether the desktop asks for a dark appearance.
    public func systemPrefersDarkAppearance() -> Bool {
        guard let settings = gtk_settings_get_default() else { return false }
        // `g_object_get` is a C variadic, which Swift cannot call, so read the
        // property through the GValue API instead.
        var value = GValue()
        g_value_init(&value, g_type_from_name("gboolean"))
        defer { g_value_unset(&value) }
        g_object_get_property(UnsafeMutablePointer<GObject>(settings),
                              "gtk-application-prefer-dark-theme", &value)
        return g_value_get_boolean(&value) != 0
    }

    /// The desktop accent color. Neither GTK nor freedesktop exposes one, so
    /// the framework's own default stands in (nil = "no system accent").
    public func systemAccentColor() -> NSColor? { nil }

    /// Sets the pointer cursor by framework name.
    public func setCursor(named name: String) {}

    /// Sets per-rectangle hover cursors. GTK sets a cursor per widget, not per
    /// sub-rectangle, so the first region's cursor covers the whole view.
    public func setCursorRegions(_ regions: [NativeCursorRegion], for handle: NativeHandle) {
        guard let w = widget(handle), let first = regions.first else { return }
        gtk_widget_set_cursor_from_name(asWidget(w), first.cursorName)
    }

    /// Every installed font family.
    public func fontFamilyNames() -> [String] {
        guard let map = pango_cairo_font_map_get_default() else { return [] }
        var families: UnsafeMutablePointer<UnsafeMutablePointer<PangoFontFamily>?>?
        var count: Int32 = 0
        pango_font_map_list_families(map, &families, &count)
        defer { g_free(families) }
        var names: [String] = []
        for index in 0..<Int(count) {
            guard let family = families?[index],
                  let name = pango_font_family_get_name(family) else { continue }
            names.append(String(cString: name))
        }
        return names.sorted()
    }

    /// Measures a single line of text.
    public func measureText(_ text: String, font: NativeFontSpec) -> NSSize {
        measure(text, font: font, wrappingAt: nil)
    }

    /// Measures text wrapped to a maximum width.
    public func measureText(_ text: String, font: NativeFontSpec, wrappingAt maxWidth: CGFloat) -> NSSize {
        measure(text, font: font, wrappingAt: maxWidth)
    }

    /// Lays `text` out in Pango and returns its pixel size.
    internal func measure(_ text: String, font: NativeFontSpec, wrappingAt maxWidth: CGFloat?) -> NSSize {
        if coreSeam.measuringLabel == nil {
            let label = gtk_label_new(nil)
            g_object_ref_sink(label)
            coreSeam.measuringLabel = OpaquePointer(label)
        }
        guard let label = coreSeam.measuringLabel,
              let layout = gtk_widget_create_pango_layout(asWidget(label), text) else {
            return NSSize(width: 0, height: 0)
        }
        defer { g_object_unref(UnsafeMutableRawPointer(layout)) }
        let description = pango_font_description_new()
        defer { pango_font_description_free(description) }
        pango_font_description_set_family(description, font.family ?? "Sans")
        pango_font_description_set_absolute_size(description, font.size * Double(PANGO_SCALE))
        pango_font_description_set_weight(description, font.bold ? PANGO_WEIGHT_BOLD : PANGO_WEIGHT_NORMAL)
        if font.italic { pango_font_description_set_style(description, PANGO_STYLE_ITALIC) }
        pango_layout_set_font_description(layout, description)
        if let maxWidth {
            pango_layout_set_width(layout, Int32(maxWidth) * PANGO_SCALE)
            pango_layout_set_wrap(layout, PANGO_WRAP_WORD_CHAR)
        }
        var width: Int32 = 0, height: Int32 = 0
        pango_layout_get_pixel_size(layout, &width, &height)
        return NSSize(width: CGFloat(width), height: CGFloat(height))
    }

    // MARK: Clipboard

    /// Empties the clipboard.
    public func clearClipboard() {
        setClipboardString("")
        coreSeam.clipboardChangeCount += 1
    }

    /// How many times the clipboard has changed.
    public func clipboardChangeCount() -> Int { coreSeam.clipboardChangeCount }

    /// Whether the clipboard holds a format. GTK's clipboard is read
    /// asynchronously, so only the text the app itself wrote is known here.
    public func clipboardHasData(forFormat formatName: String) -> Bool {
        formatName.contains("text") && clipboardString() != nil
    }

    /// The clipboard's bytes for a format.
    public func clipboardData(forFormat formatName: String) -> [UInt8]? {
        guard clipboardHasData(forFormat: formatName), let text = clipboardString() else {
            return nil
        }
        return Array(text.utf8)
    }

    /// File paths on the clipboard.
    public func clipboardFilePaths() -> [String] { [] }

    // MARK: Color panel

    /// Runs the color panel.
    ///
    /// On GTK the color well *is* the chooser — `GtkColorButton` opens the
    /// desktop's own color dialog when clicked, which is how the demo's color
    /// well works. A standalone panel with no well to anchor it has nothing to
    /// open here, so `NSColorPanel.orderFront` alone shows nothing.
    public func runColorChooser(initialColor: NSColor) -> NSColor? { nil }

    // MARK: Scroll geometry

    /// The scroll view's current content offset.
    public func scrollViewContentOffset(for handle: NativeHandle) -> NSPoint {
        let offset = scrollOffset(for: handle)
        return NSPoint(x: CGFloat(offset.x), y: CGFloat(offset.y))
    }

    /// Scrolls the content to an offset.
    public func setScrollViewContentOffset(_ offset: NSPoint, for handle: NativeHandle) {
        setScrollOffset(x: Double(offset.x), y: Double(offset.y), for: handle)
    }

    /// Sets the scrollable content size and which scrollers show.
    ///
    /// GTK derives the scrollable extent from the child widget's own size
    /// request rather than being told it, so the content size arrives with the
    /// document view; only the scroller policy is set here.
    public func setScrollViewContentSize(_ contentSize: NSSize, viewportSize: NSSize,
                                         hasVerticalScroller: Bool,
                                         hasHorizontalScroller: Bool,
                                         for handle: NativeHandle) {
        setScrollerPolicy(vertical: hasVerticalScroller, horizontal: hasHorizontalScroller,
                          for: handle)
    }

    /// Sets a standalone scroller's value and knob size.
    public func setScrollerValue(_ value: Double, knobProportion: Double,
                                 for handle: NativeHandle) {
        setScrollerGeometry(value: value, knobProportion: knobProportion, for: handle)
    }

    /// Writes the pasteboard's contents.
    ///
    /// GDK's clipboard carries typed content providers; this seam mirrors the
    /// text flavor, which is what the demo's copy/paste path uses. Binary
    /// representations and file lists are not offered to other applications.
    public func setClipboardContents(text: String?, dataRepresentations: [String: [UInt8]],
                                     filePaths: [String]) {
        setClipboardString(text ?? "")
        coreSeam.clipboardChangeCount += 1
    }
}

/// The core's path-batch drawing context, drawn through GTK's Cairo one.
///
/// `NativeDrawingContext` hands over whole paths (`fillPath(segments, color)`);
/// `NativeGraphicsContext` is immediate-mode (`beginPath`, `move`, `fillPath`).
/// Replaying a segment list onto the immediate-mode calls is the whole job.
final class GTKCoreDrawingContext: NativeDrawingContext {
    internal let context: NativeGraphicsContext

    init(_ context: NativeGraphicsContext) {
        self.context = context
    }

    internal func replay(_ segments: [NativePathSegment]) {
        context.beginPath()
        for segment in segments {
            switch segment {
            case let .move(point):
                context.move(toX: Double(point.x), y: Double(point.y))
            case let .line(point):
                context.line(toX: Double(point.x), y: Double(point.y))
            case let .curve(to, control1, control2):
                context.curve(NativeBezierCurve(
                    endpoint: to,
                    controlPoint1: control1,
                    controlPoint2: control2
                ))
            case .close:
                context.closePath()
            }
        }
    }

    func fillPath(_ segments: [NativePathSegment], color: NSColor) {
        replay(segments)
        context.setFillColor(color)
        context.fillPath()
    }

    func strokePath(_ segments: [NativePathSegment], color: NSColor, lineWidth: CGFloat) {
        replay(segments)
        context.setStrokeColor(color)
        context.setLineWidth(Double(lineWidth))
        context.strokePath()
    }

    func drawText(_ text: String, at point: NSPoint, color: NSColor, font: NativeFontSpec) {
        context.drawText(text, at: point,
                         font: font,
                         color: color)
    }

    func drawImage(atPath path: String, in rect: NSRect, tint: NSColor?) {
        context.drawImage(atPath: path, inRect: rect)
    }

    func drawLinearGradient(_ stops: [NativeGradientStop], in rect: NSRect, angle: CGFloat) {
        context.fillLinearGradient(stops, inRect: rect, angleDegrees: Double(angle))
    }

    func clip(to segments: [NativePathSegment]) {
        replay(segments)
        context.clipToCurrentPath()
    }

    func saveState() { context.saveState() }

    func restoreState() { context.restoreState() }
}

#endif  // canImport(CGTK)
