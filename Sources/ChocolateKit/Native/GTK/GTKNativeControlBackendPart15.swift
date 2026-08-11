#if canImport(CGTK)
import CGTK
import CGTKCompat
import Foundation

internal final class ClickBox {
    let action: (Double, Double) -> Void
    init(_ action: @escaping (Double, Double) -> Void) { self.action = action }
}

/// `GtkGestureClick::pressed` on a plain view (image views) — reports the point.
internal let gtkViewClickTrampoline: @convention(c) (UnsafeMutableRawPointer?, gint, Double, Double, gpointer?) -> Void = { _, _, x, y, userData in
    guard let userData else { return }
    Unmanaged<ClickBox>.fromOpaque(userData).takeUnretainedValue().action(x, y)
}

/// `GtkFlowBox::selected-children-changed` — a collection selection.
internal let gtkFlowSelectionTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { _, userData in
    guard let userData else { return }
    let box = Unmanaged<CollectionBox>.fromOpaque(userData).takeUnretainedValue()
    box.backend?.reportCollectionSelection(box.collection, base: box.base)
}

/// Carries an editable level indicator's backend + handle to its click gesture.
internal final class LevelClickBox {
    weak var backend: GTKNativeControlBackend?
    let raw: UInt
    init(backend: GTKNativeControlBackend, raw: UInt) {
        self.backend = backend
        self.raw = raw
    }
}

/// `GtkDrawingArea` draw func for a rating indicator's stars.
internal let gtkStarDrawFunc: @convention(c) (UnsafeMutablePointer<GtkDrawingArea>?, OpaquePointer?, Int32, Int32, gpointer?) -> Void = { _, cr, width, height, userData in
    guard let cr, let userData else { return }
    let box = Unmanaged<LevelClickBox>.fromOpaque(userData).takeUnretainedValue()
    box.backend?.drawStars(box.raw, cr: cr, width: Double(width), height: Double(height))
}

/// Carries a slider's backend + handle + action, for tick snapping on change.
internal final class SliderValueBox {
    weak var backend: GTKNativeControlBackend?
    let raw: UInt
    let action: (Double) -> Void
    init(backend: GTKNativeControlBackend, raw: UInt, action: @escaping (Double) -> Void) {
        self.backend = backend
        self.raw = raw
        self.action = action
    }
}

/// `GtkRange::value-changed` on a slider — snaps to ticks, then reports.
internal let gtkSliderValueChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { _, userData in
    guard let userData else { return }
    let box = Unmanaged<SliderValueBox>.fromOpaque(userData).takeUnretainedValue()
    box.backend?.reportSliderValue(box.raw, action: box.action)
}

/// Carries a print job's backend + view handle + natural size to the draw-page handler.
internal final class PrintBox {
    weak var backend: GTKNativeControlBackend?
    let view: UInt
    let width: Double
    let height: Double
    init(backend: GTKNativeControlBackend, view: UInt, width: Double, height: Double) {
        self.backend = backend; self.view = view; self.width = width; self.height = height
    }
}

/// `GtkPrintOperation::draw-page` — `void (*)(GtkPrintOperation*, GtkPrintContext*, gint, gpointer)`.
internal let gtkPrintDrawPageTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gint, gpointer?) -> Void = { _, printContext, _, userData in
    guard let printContext, let userData else { return }
    let box = Unmanaged<PrintBox>.fromOpaque(userData).takeUnretainedValue()
    box.backend?.drawPrintPage(view: box.view, printContext: OpaquePointer(printContext),
                               width: box.width, height: box.height)
}

/// Carries a spinner's backend + handle to its draw func and rotation timeout.
internal final class SpinnerDrawBox {
    weak var backend: GTKNativeControlBackend?
    let raw: UInt
    init(backend: GTKNativeControlBackend, raw: UInt) {
        self.backend = backend
        self.raw = raw
    }
}

/// `GtkDrawingArea` draw func for a spinning progress indicator.
internal let gtkSpinnerDrawFunc: @convention(c) (UnsafeMutablePointer<GtkDrawingArea>?, OpaquePointer?, Int32, Int32, gpointer?) -> Void = { _, cr, width, height, userData in
    guard let cr, let userData else { return }
    let box = Unmanaged<SpinnerDrawBox>.fromOpaque(userData).takeUnretainedValue()
    box.backend?.drawSpinner(box.raw, cr: cr, width: Double(width), height: Double(height))
}

/// `GtkGestureClick::pressed` on a rating indicator.
internal let gtkLevelClickTrampoline: @convention(c) (UnsafeMutableRawPointer?, gint, Double, Double, gpointer?) -> Void = { _, _, x, _, userData in
    guard let userData else { return }
    let box = Unmanaged<LevelClickBox>.fromOpaque(userData).takeUnretainedValue()
    box.backend?.reportLevelClick(box.raw, x: x)
}

/// Carries a standalone scroller's backend + handle to its adjustment handler.
internal final class ScrollerBox {
    weak var backend: GTKNativeControlBackend?
    let raw: UInt
    init(backend: GTKNativeControlBackend, raw: UInt) {
        self.backend = backend
        self.raw = raw
    }
}

/// `GtkAdjustment::value-changed` for a standalone scroller.
internal let gtkScrollerChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { _, userData in
    guard let userData else { return }
    let box = Unmanaged<ScrollerBox>.fromOpaque(userData).takeUnretainedValue()
    box.backend?.reportScroller(box.raw)
}

/// Carries a date picker's backend + handle to its cursor/key handlers.
internal final class DateCursorBox {
    weak var backend: GTKNativeControlBackend?
    let raw: UInt
    init(backend: GTKNativeControlBackend, raw: UInt) {
        self.backend = backend
        self.raw = raw
    }
}

/// `GtkEditable::notify::cursor-position` on a compact date field.
internal let gtkDateCursorTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { _, _, userData in
    guard let userData else { return }
    let box = Unmanaged<DateCursorBox>.fromOpaque(userData).takeUnretainedValue()
    box.backend?.reportDateCursor(box.raw)
}

/// `GtkEventControllerKey::key-pressed` on a compact date field.
internal let gtkDateKeyTrampoline: @convention(c) (UnsafeMutableRawPointer?, guint, guint, GdkModifierType, gpointer?) -> gboolean = { _, keyval, _, _, userData in
    guard let userData else { return gboolean(0) }
    let box = Unmanaged<DateCursorBox>.fromOpaque(userData).takeUnretainedValue()
    return gboolean(box.backend?.reportDateKey(box.raw, keyval: keyval) == true ? 1 : 0)
}

/// Carries a drag source's string payload to the `prepare` handler.
internal final class DragPayloadBox {
    let payload: String
    init(_ payload: String) { self.payload = payload }
}

/// Carries a drop target's handler; returns whether the drop was accepted.
internal final class DropHandlerBox {
    let handle: (String, Double, Double) -> Bool
    init(_ handle: @escaping (String, Double, Double) -> Bool) { self.handle = handle }
}

/// Carries the display-mode dropdown and its change handler.
internal final class DropDownBox {
    let dropdown: OpaquePointer
    let onChange: (Int) -> Void
    init(dropdown: OpaquePointer, onChange: @escaping (Int) -> Void) {
        self.dropdown = dropdown
        self.onChange = onChange
    }
}

/// `GtkDragSource::prepare` — builds a string content provider from the box.
internal let gtkPaletteDragPrepareTrampoline: @convention(c) (UnsafeMutableRawPointer?, Double, Double, gpointer?) -> OpaquePointer? = { _, _, _, userData in
    guard let userData else { return nil }
    let box = Unmanaged<DragPayloadBox>.fromOpaque(userData).takeUnretainedValue()
    var value = GValue()
    _ = g_value_init(&value, GType(16 << 2))   // G_TYPE_STRING
    g_value_set_string(&value, box.payload)
    let provider = gdk_content_provider_new_for_value(&value)
    g_value_unset(&value)
    return OpaquePointer(provider)
}

/// `GtkDropTarget::drop` — reads the string payload and dispatches.
internal let gtkPaletteDropTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<GValue>?, Double, Double, gpointer?) -> gboolean = { _, value, x, y, userData in
    guard let value, let userData, let raw = g_value_get_string(value) else { return gboolean(0) }
    let box = Unmanaged<DropHandlerBox>.fromOpaque(userData).takeUnretainedValue()
    return gboolean(box.handle(String(cString: raw), x, y) ? 1 : 0)
}

/// `GtkDropDown::notify::selected` — reports the new index.
internal let gtkDropDownSelectedTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { _, _, userData in
    guard let userData else { return }
    let box = Unmanaged<DropDownBox>.fromOpaque(userData).takeUnretainedValue()
    box.onChange(Int(gtk_drop_down_get_selected(box.dropdown)))
}

/// Palette tiles are GtkToggleButtons: pressed = present in the toolbar.
internal let gtkPaletteTileTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { button, userData in
    guard let button, let userData else { return }
    let active = gtk_toggle_button_get_active(UnsafeMutablePointer<GtkToggleButton>(OpaquePointer(button))) != 0
    let box = Unmanaged<ToolbarToggleBox>.fromOpaque(userData).takeUnretainedValue()
    box.action(box.id, active)
}

internal let gtkToolbarToggleTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { button, userData in
    guard let button, let userData else { return }
    let active = gtk_check_button_get_active(UnsafeMutablePointer<GtkCheckButton>(OpaquePointer(button))) != 0
    let box = Unmanaged<ToolbarToggleBox>.fromOpaque(userData).takeUnretainedValue()
    box.action(box.id, active)
}

/// Carries a table's identity to the sorter-changed and row-activate handlers.
internal final class TableSignalBox {
    weak var backend: GTKNativeControlBackend?
    let table: UInt
    init(backend: GTKNativeControlBackend, table: UInt) {
        self.backend = backend
        self.table = table
    }
}

/// Handler for the column view's `GtkColumnViewSorter::changed` — a header was
/// clicked; report the primary sort column + order to the Swift side.
internal let gtkSorterChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, guint, gpointer?) -> Void = { sorter, _, userData in
    guard let sorter, let userData else { return }
    let box = Unmanaged<TableSignalBox>.fromOpaque(userData).takeUnretainedValue()
    box.backend?.handleSorterChanged(table: box.table, sorter: OpaquePointer(sorter))
}

/// Handler for `GtkColumnView::activate` — a row was double-clicked / Entered.
internal let gtkRowActivateTrampoline: @convention(c) (UnsafeMutableRawPointer?, guint, gpointer?) -> Void = { _, position, userData in
    guard let userData else { return }
    let box = Unmanaged<TableSignalBox>.fromOpaque(userData).takeUnretainedValue()
    box.backend?.handleRowActivate(table: box.table, position: Int(position))
}
internal final class OutlineColumnBox {
    weak var backend: GTKNativeControlBackend?
    let outline: UInt
    let column: Int
    init(backend: GTKNativeControlBackend, outline: UInt, column: Int) {
        self.backend = backend
        self.outline = outline
        self.column = column
    }
}

internal final class CollectionBox {
    weak var backend: GTKNativeControlBackend?
    let collection: UInt
    /// Flat index of this section's first item, for mapping selection back.
    let base: Int
    init(backend: GTKNativeControlBackend, collection: UInt, base: Int = 0) {
        self.backend = backend
        self.collection = collection
        self.base = base
    }
}



/// `GtkTreeListModel` create-func — returns a child path list, or nil for leaves.
internal let outlineCreateChildModelFunc: @convention(c) (gpointer?, gpointer?) -> OpaquePointer? = { item, userData in
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
internal let gtkOutlineCellSetupTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { _, item, userData in
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
internal let gtkOutlineCellBindTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { _, item, userData in
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
internal let gtkTableCellSetupTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { _, item, userData in
    guard let item else { return }
    let box = userData.map { Unmanaged<TableColumnBox>.fromOpaque($0).takeUnretainedValue() }
    if box?.editable == true {
        // A GtkEditableLabel shows text and enters edit mode on double-click —
        // exactly AppKit's editable cell. On commit (Enter / focus-out) the
        // "editing" property drops to false; that is when we push the value back.
        let editable = gtk_editable_label_new("")!
        gtk_widget_set_margin_start(editable, 8)
        gtk_widget_set_margin_end(editable, 8)
        if let box, let backend = box.backend {
            let commit = TableColumnBox(backend: backend, table: box.table, column: box.column, editable: true)
            g_signal_connect_data(
                UnsafeMutableRawPointer(editable), "notify::editing",
                unsafeBitCast(gtkCellEditingChangedTrampoline, to: GCallback.self),
                Unmanaged.passRetained(commit).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
            )
        }
        gtk_list_item_set_child(OpaquePointer(item), editable)
    } else {
        let label = gtk_label_new("")!
        gtk_label_set_xalign(OpaquePointer(label), 0)
        gtk_widget_set_margin_start(label, 8)
        gtk_widget_set_margin_end(label, 8)
        gtk_list_item_set_child(OpaquePointer(item), label)
    }
}

/// Factory `bind` — fills the cell's label from the table's cell provider.
internal let gtkTableCellBindTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { _, item, userData in
    guard let item, let userData else { return }
    let box = Unmanaged<TableColumnBox>.fromOpaque(userData).takeUnretainedValue()
    let row = Int(gtk_list_item_get_position(OpaquePointer(item)))
    guard let child = gtk_list_item_get_child(OpaquePointer(item)) else { return }
    let text = box.backend?.tableCellText(table: box.table, row: row, column: box.column) ?? ""
    if box.editable {
        // Stamp the current row on the reused widget so the commit handler knows
        // which model row it maps to (row+1 so a valid row is never a null pointer).
        g_object_set_data(UnsafeMutableRawPointer(child).assumingMemoryBound(to: GObject.self),
                          "lc-row", UnsafeMutableRawPointer(bitPattern: row + 1))
        gtk_editable_set_text(OpaquePointer(child), text)
    } else {
        gtk_label_set_text(OpaquePointer(child), text)
    }
}
/// `GtkEditableLabel::notify::editing` — on leaving edit mode, push the new text
/// back to the data source (AppKit's `setObjectValue`).
internal let gtkCellEditingChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { label, _, userData in
    guard let label, let userData else { return }
    let box = Unmanaged<TableColumnBox>.fromOpaque(userData).takeUnretainedValue()
    // Only fire once, when editing FINISHES (property went to false).
    guard gtk_editable_label_get_editing(OpaquePointer(label)) == 0 else { return }
    let text = String(cString: gtk_editable_get_text(OpaquePointer(label)))
    let rowData = g_object_get_data(label.assumingMemoryBound(to: GObject.self), "lc-row")
    let row = rowData.map { Int(bitPattern: $0) - 1 } ?? -1
    guard row >= 0 else { return }
    box.backend?.reportCellEdit(table: box.table, row: row, column: box.column, text: text)
}

/// `GtkSingleSelection::notify::selected` — passes the selected row (−1 if none).
internal let gtkTableSelectionChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { selection, _, userData in
    guard let selection, let userData else { return }
    let selected = gtk_single_selection_get_selected(OpaquePointer(selection))
    let row = selected == guint.max ? -1 : Int(selected)   // guint.max = GTK_INVALID_LIST_POSITION
    Unmanaged<IntActionBox>.fromOpaque(userData).takeUnretainedValue().action(row)
}

/// Actual popover widget types. Matching must be exact: `GtkPopoverMenuBar`
/// and `GtkPopoverMenuBarItem` contain "Popover" but are NOT popovers, and
/// popping them down trips a Gtk-CRITICAL assertion on every click.
internal let popoverTypeNames: Set<String> = ["GtkPopover", "GtkPopoverMenu", "GtkTreePopover"]

/// Menu-bar subtrees the dismissal walk must NOT descend into. The menu bar
/// owns a `GtkPopoverMenu` for the open menu; GTK manages its lifetime (open on
/// click, close on Escape / activation / clicking another top-level item). If
/// our fallback reaches in and pops it down, the menu closes the instant it
/// opens — i.e. menus stop working. So skip these subtrees entirely; the
/// fallback only needs to reach the *standalone* popovers below (dropdown and
/// combo-box lists), which are not inside the menu bar.
internal let menuBarTypeNames: Set<String> = ["GtkPopoverMenuBar", "GtkPopoverMenuBarItem"]

/// Recursively pops down any *mapped* standalone popover in `widget`'s subtree
/// (dropdown lists, combo popups), skipping menu-bar menus.
internal func popdownVisiblePopovers(
    under widget: UnsafeMutablePointer<GtkWidget>,
    includingMenuBars: Bool = false
) {
    var child = gtk_widget_get_first_child(widget)
    while let c = child {
        let typeName = String(cString: g_type_name_from_instance(
            UnsafeMutableRawPointer(c).assumingMemoryBound(to: GTypeInstance.self)))
        if popoverTypeNames.contains(typeName) {
            if gtk_widget_get_mapped(c) != 0 {
                gtk_popover_popdown(UnsafeMutablePointer<GtkPopover>(OpaquePointer(c)))
            }
        } else if includingMenuBars || !menuBarTypeNames.contains(typeName) {
            popdownVisiblePopovers(under: c, includingMenuBars: includingMenuBars)
        }
        child = gtk_widget_get_next_sibling(c)
    }
}

/// Handler for the window's capture-phase `GtkGestureClick::pressed` — the
/// outside-click popover dismissal fallback for non-composited displays. Runs
/// before the click lands, so it dismisses a previously-open popover without
/// ever closing one that this same click is about to open.
internal let gtkDismissPopoversTrampoline: @convention(c) (UnsafeMutableRawPointer?, gint, gdouble, gdouble, gpointer?) -> Void = { _, _, _, _, userData in
    guard let userData else { return }
    let box = Unmanaged<WidgetBox>.fromOpaque(userData).takeUnretainedValue()
    popdownVisiblePopovers(under: box.widget)
}

/// Handler for an alert button's `clicked` — records the response and quits the
/// alert's nested main loop, unblocking `runAlert`.
internal let gtkAlertButtonTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { _, userData in
    guard let userData else { return }
    let box = Unmanaged<AlertButtonBox>.fromOpaque(userData).takeUnretainedValue()
    box.state.response = box.index
    g_main_loop_quit(box.state.loop)
}

/// Handler for a segment's `GtkToggleButton::toggled` — fires only when the
/// segment becomes active, passing its index.
internal let gtkSegmentToggledTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { button, userData in
    guard let button, let userData else { return }
    guard gtk_toggle_button_get_active(UnsafeMutablePointer<GtkToggleButton>(OpaquePointer(button))) != 0 else { return }
    let box = Unmanaged<SegmentBox>.fromOpaque(userData).takeUnretainedValue()
    box.action(box.index)
}

/// Handler for `GSimpleAction::activate` — `void (*)(GSimpleAction*, GVariant*,
/// gpointer)`; runs a menu item's action.
internal let gtkMenuActivateTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, gpointer?) -> Void = { _, _, userData in
    guard let userData else { return }
    let box = Unmanaged<MenuActionBox>.fromOpaque(userData).takeUnretainedValue()
    // Close first: an action is allowed to replace content or terminate the
    // application, either of which can invalidate the menu's widget tree.
    popdownVisiblePopovers(under: box.root, includingMenuBars: true)
    box.action()
}

/// Handler for `GtkNotebook::switch-page` — `void (*)(GtkNotebook*, GtkWidget*,
/// guint page_num, gpointer)`; passes the new page index.
internal let gtkSwitchPageTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, guint, gpointer?) -> Void = { _, _, pageNum, userData in
    guard let userData else { return }
    Unmanaged<IntActionBox>.fromOpaque(userData).takeUnretainedValue().action(Int(pageNum))
}

/// Handler for `GtkCalendar::day-selected` — reads the calendar's date.
internal let gtkDaySelectedTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { calendar, userData in
    guard let calendar, let userData else { return }
    guard let gdt = gtk_calendar_get_date(OpaquePointer(calendar)) else { return }
    let date = Date(timeIntervalSince1970: TimeInterval(g_date_time_to_unix(gdt)))
    g_date_time_unref(gdt)
    Unmanaged<DateActionBox>.fromOpaque(userData).takeUnretainedValue().action(date)
}

/// Handler for `GtkColorButton::color-set` — reads the chosen RGBA.
internal let gtkColorSetTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { button, userData in
    guard let button, let userData else { return }
    var rgba = GdkRGBA(red: 0, green: 0, blue: 0, alpha: 0)
    lc_color_chooser_get_rgba(UnsafeMutablePointer<GtkWidget>(OpaquePointer(button)), &rgba)
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
internal let gtkDropTrampoline: @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<GValue>?, Double, Double, gpointer?) -> gboolean = { target, value, x, y, userData in
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
internal let gtkDragPrepareTrampoline: @convention(c) (UnsafeMutableRawPointer?, Double, Double, gpointer?) -> OpaquePointer? = { _, _, _, userData in
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
internal let gtkScrollChangedTrampoline: @convention(c) (UnsafeMutableRawPointer?, gpointer?) -> Void = { _, userData in
    guard let userData else { return }
    let box = Unmanaged<ScrollBox>.fromOpaque(userData).takeUnretainedValue()
    box.action(gtk_adjustment_get_value(box.hadj), gtk_adjustment_get_value(box.vadj))
}

internal let boxRelease: GClosureNotify = { data, _ in
    guard let data else { return }
    Unmanaged<AnyObject>.fromOpaque(data).release()
}

/// Single-argument variant for APIs taking a `GDestroyNotify`.
internal let boxDestroyNotify: @convention(c) (gpointer?) -> Void = { data in
    guard let data else { return }
    Unmanaged<AnyObject>.fromOpaque(data).release()
}
// (guard continues — the GTK helpers below also need CGTK; the #endif is at EOF)

#endif
