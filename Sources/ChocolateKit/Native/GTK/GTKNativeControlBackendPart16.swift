#if canImport(CGTK)
import CGTK
import CGTKCompat
import Foundation

// MARK: - Frame-authoritative layout

/// The key under which a child's exact GTK rect is stashed on the widget, so
/// the layout manager's C callbacks can read it without touching Swift state.
internal let linChocolateFrameKey = "linchocolate-frame"

/// Records `rect` (parent-relative, GTK top-left) as `child`'s exact allocation.
func setExactRect(_ rect: NSRect, on child: OpaquePointer) {
    let box = g_malloc(gsize(MemoryLayout<graphene_rect_t>.size)).assumingMemoryBound(to: graphene_rect_t.self)
    box.pointee = graphene_rect_t(
        origin: graphene_point_t(x: Float(rect.origin.x), y: Float(rect.origin.y)),
        size: graphene_size_t(width: Float(rect.size.width), height: Float(rect.size.height))
    )
    g_object_set_data_full(UnsafeMutablePointer<GObject>(child), linChocolateFrameKey, box, { g_free($0) })
}

/// The exact rect recorded for `child`, or nil when it is laid out natively.
internal func exactRect(of child: UnsafeMutablePointer<GtkWidget>) -> UnsafeMutablePointer<graphene_rect_t>? {
    g_object_get_data(UnsafeMutablePointer<GObject>(OpaquePointer(child)), linChocolateFrameKey)?
        .assumingMemoryBound(to: graphene_rect_t.self)
}

/// `GtkLayoutManagerClass.measure` — the container's size is the extent of its
/// children's frames (AppKit containers don't negotiate; they're told a frame).
internal let lcLayoutMeasure: @convention(c) (
    UnsafeMutablePointer<GtkLayoutManager>?, UnsafeMutablePointer<GtkWidget>?,
    GtkOrientation, gint,
    UnsafeMutablePointer<gint>?, UnsafeMutablePointer<gint>?,
    UnsafeMutablePointer<gint>?, UnsafeMutablePointer<gint>?
) -> Void = { _, widget, orientation, _, minimum, natural, _, _ in
    var extent: Float = 0
    var child = gtk_widget_get_first_child(widget)
    while let current = child {
        if gtk_widget_should_layout(current) != 0, let rect = exactRect(of: current) {
            let edge = orientation == GTK_ORIENTATION_HORIZONTAL
                ? rect.pointee.origin.x + rect.pointee.size.width
                : rect.pointee.origin.y + rect.pointee.size.height
            extent = max(extent, edge)
        }
        child = gtk_widget_get_next_sibling(current)
    }
    minimum?.pointee = gint(extent)
    natural?.pointee = gint(extent)
}

/// `GtkLayoutManagerClass.allocate` — every child gets exactly its AppKit
/// frame, at its AppKit position. No negotiation: this is what makes a frame
/// mean the same thing on GTK as it does on AppKit.
internal let lcLayoutAllocate: @convention(c) (
    UnsafeMutablePointer<GtkLayoutManager>?, UnsafeMutablePointer<GtkWidget>?,
    gint, gint, gint
) -> Void = { _, widget, _, _, _ in
    var child = gtk_widget_get_first_child(widget)
    while let current = child {
        defer { child = gtk_widget_get_next_sibling(current) }
        guard gtk_widget_should_layout(current) != 0, let rect = exactRect(of: current) else { continue }
        let width = gint(rect.pointee.size.width)
        let height = gint(rect.pointee.size.height)
        // GTK requires a measure before an allocate, even when the result is
        // ignored: it caches the request and warns loudly without it.
        gtk_widget_measure(current, GTK_ORIENTATION_HORIZONTAL, -1, nil, nil, nil, nil)
        gtk_widget_measure(current, GTK_ORIENTATION_VERTICAL, width, nil, nil, nil, nil)
        var origin = graphene_point_t(x: rect.pointee.origin.x, y: rect.pointee.origin.y)
        gtk_widget_allocate(current, width, height, -1, gsk_transform_translate(nil, &origin))
    }
}

internal let lcLayoutClassInit: @convention(c) (gpointer?, gpointer?) -> Void = { klass, _ in
    guard let klass else { return }
    let layoutClass = klass.assumingMemoryBound(to: GtkLayoutManagerClass.self)
    layoutClass.pointee.measure = lcLayoutMeasure
    layoutClass.pointee.allocate = lcLayoutAllocate
}

nonisolated(unsafe) internal var lcLayoutTypeStorage: GType = 0

/// The GType of LinChocolate's frame-authoritative layout manager.
func linChocolateFixedLayoutType() -> GType {
    if lcLayoutTypeStorage != 0 { return lcLayoutTypeStorage }
    var info = GTypeInfo()
    info.class_size = guint16(MemoryLayout<GtkLayoutManagerClass>.size)
    info.class_init = lcLayoutClassInit
    info.instance_size = guint16(MemoryLayout<GtkLayoutManager>.size)
    lcLayoutTypeStorage = g_type_register_static(
        gtk_layout_manager_get_type(), "LinChocolateFixedLayout", &info, GTypeFlags(rawValue: 0)
    )
    return lcLayoutTypeStorage
}

/// Carries a paint-trace subscription: which window, and which event fired.
internal final class PaintTraceBox {
    weak var backend: GTKNativeControlBackend?
    let raw: UInt
    let event: String
    init(backend: GTKNativeControlBackend, raw: UInt, event: String) {
        self.backend = backend
        self.raw = raw
        self.event = event
    }
}

/// Any traced signal — widget lifecycle or frame-clock cycle.
internal let gtkPaintTraceTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { _, userData in
    guard let userData else { return }
    let box = Unmanaged<PaintTraceBox>.fromOpaque(userData).takeUnretainedValue()
    box.backend?.tracePaint(box.raw, box.event)
}

#endif
