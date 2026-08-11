#if canImport(CGTK)
import CGTK
import CGTKCompat
import Foundation

extension GTKNativeControlBackend {
    internal func hostBand(_ band: UnsafeMutablePointer<GtkWidget>, in stack: OpaquePointer) {
        g_object_ref(UnsafeMutableRawPointer(band))
        if gtk_widget_get_parent(band) != nil { gtk_widget_unparent(band) }
        gtk_widget_set_hexpand(band, gboolean(1))
        gtk_widget_set_halign(band, GTK_ALIGN_FILL)
        gtk_box_append(asBox(stack), band)
        g_object_unref(UnsafeMutableRawPointer(band))
    }
    /// One section's GtkFlowBox, wired to report selection in FLAT indices.
    internal func makeCollectionFlow(raw: UInt, base: Int) -> OpaquePointer {
        let flow = gtk_flow_box_new()!
        gtk_flow_box_set_selection_mode(OpaquePointer(flow), GTK_SELECTION_SINGLE)
        gtk_flow_box_set_homogeneous(OpaquePointer(flow), gboolean(0))
        let geometry = collectionFlowGeometry[raw]
            ?? GTKCollectionFlowGeometry(interitem: 8, line: 8, horizontal: false)
        gtk_flow_box_set_column_spacing(OpaquePointer(flow), guint(Swift.max(0, geometry.interitem)))
        gtk_flow_box_set_row_spacing(OpaquePointer(flow), guint(Swift.max(0, geometry.line)))
        gtk_flow_box_set_max_children_per_line(OpaquePointer(flow), 64)
        // AppKit's `.vertical` scroll direction means items flow in ROWS, which
        // is GtkFlowBox's horizontal orientation (and vice versa).
        gtk_orientable_set_orientation(OpaquePointer(flow),
                                       geometry.horizontal ? GTK_ORIENTATION_VERTICAL : GTK_ORIENTATION_HORIZONTAL)
        let box = CollectionBox(backend: self, collection: raw, base: base)
        g_signal_connect_data(
            UnsafeMutableRawPointer(flow), "selected-children-changed",
            unsafeBitCast(gtkFlowSelectionTrampoline, to: GCallback.self),
            Unmanaged.passRetained(box).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        return OpaquePointer(flow)
    }
    /// Fills one section's flow box with items `base ..< base+count`.
    internal func fillCollectionFlow(_ flow: OpaquePointer, raw: UInt, base: Int, count: Int) {
        for offset in 0..<count {
            let index = base + offset
            let content: UnsafeMutablePointer<GtkWidget>
            if let handle = collectionViewProviders[raw]?(index), let widget = widgets[handle.rawValue] {
                // Hold a reference across the move (the toolbar lesson: an
                // unparented GTK4 widget with no other ref is destroyed).
                g_object_ref(UnsafeMutableRawPointer(widget))
                if gtk_widget_get_parent(asWidget(widget)) != nil { gtk_widget_unparent(asWidget(widget)) }
                content = asWidget(widget)
                gtk_flow_box_insert(flow, content, -1)
                g_object_unref(UnsafeMutableRawPointer(widget))
            } else {
                content = gtk_label_new(collectionProviders[raw]?(index) ?? "")!
                gtk_flow_box_insert(flow, content, -1)
            }
            // An item hosting a control (a button) would swallow the click and
            // the flow box would never select the child — so select it from a
            // capture-phase gesture that doesn't claim the event: one click
            // both selects the item and presses its control.
            if let child = gtk_widget_get_parent(content) {
                let click = gtk_gesture_click_new()
                gtk_event_controller_set_propagation_phase(click, GTK_PHASE_CAPTURE)
                let selectBox = FlowChildBox(flow: flow, child: OpaquePointer(child))
                g_signal_connect_data(
                    UnsafeMutableRawPointer(click), "pressed",
                    unsafeBitCast(gtkFlowChildSelectTrampoline, to: GCallback.self),
                    Unmanaged.passRetained(selectBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
                )
                gtk_widget_add_controller(asWidget(OpaquePointer(child)), click)
            }
        }
    }

    /// Reports a flow-box selection as an item index.
    internal func reportCollectionSelection(_ raw: UInt, base: Int) {
        guard !suppressCollectionSelection.contains(raw) else { return }
        guard let entry = collectionSectionFlows[raw]?.first(where: { $0.base == base }) else { return }
        var index = -1
        if let selected = gtk_flow_box_get_selected_children(entry.flow) {
            if let first = selected.pointee.data {
                index = base + Int(gtk_flow_box_child_get_index(first.assumingMemoryBound(to: GtkFlowBoxChild.self)))
            }
            g_list_free(selected)
        }
        guard index >= 0 else { return }   // a deselect from another section's flow
        // Selection is single across the whole collection, as on AppKit: clear
        // every other section's flow box so two sections never look selected.
        suppressCollectionSelection.insert(raw)
        for other in collectionSectionFlows[raw] ?? [] where other.base != base {
            gtk_flow_box_unselect_all(other.flow)
        }
        suppressCollectionSelection.remove(raw)
        collectionSelectionActions[raw]?(index)
    }
    /// Creates a tree table (`GtkColumnView` over a `GtkTreeListModel`) in a scrolled window.
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
    /// Appends a titled column to an outline view (column 0 carries the expand arrows).
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
    /// Replaces the outline's root list to have `count` items (= reload).
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
    /// The `GtkTreeListRow` at a visible outline position, or nil. The outline's
    /// selection model (a `GtkSingleSelection` over the tree list model) is a
    /// GListModel of the flattened, expanded rows.
    internal func outlineTreeRow(atRow row: Int, for outline: NativeHandle) -> OpaquePointer? {
        guard row >= 0, let selection = tableSelections[outline.rawValue] else { return nil }
        guard row < Int(g_list_model_get_n_items(selection)) else { return nil }
        return g_list_model_get_item(selection, guint(row)).map { OpaquePointer($0) }  // caller unrefs
    }
    /// Performs the `outlineVisibleRowCount` operation.
    public func outlineVisibleRowCount(for outline: NativeHandle) -> Int {
        guard let selection = tableSelections[outline.rawValue] else { return 0 }
        return Int(g_list_model_get_n_items(selection))
    }
    /// Performs the `outlineItemPath` operation.
    public func outlineItemPath(atRow row: Int, for outline: NativeHandle) -> String? {
        guard let treeRow = outlineTreeRow(atRow: row, for: outline) else { return nil }
        defer { g_object_unref(UnsafeMutableRawPointer(treeRow)) }
        guard let item = gtk_tree_list_row_get_item(treeRow) else { return nil }
        defer { g_object_unref(item) }
        return String(cString: gtk_string_object_get_string(OpaquePointer(item)))
    }
    /// Performs the `outlineRowDepth` operation.
    public func outlineRowDepth(atRow row: Int, for outline: NativeHandle) -> Int {
        guard let treeRow = outlineTreeRow(atRow: row, for: outline) else { return 0 }
        defer { g_object_unref(UnsafeMutableRawPointer(treeRow)) }
        return Int(gtk_tree_list_row_get_depth(treeRow))
    }
    /// Performs the `outlineIsRowExpanded` operation.
    public func outlineIsRowExpanded(atRow row: Int, for outline: NativeHandle) -> Bool {
        guard let treeRow = outlineTreeRow(atRow: row, for: outline) else { return false }
        defer { g_object_unref(UnsafeMutableRawPointer(treeRow)) }
        return gtk_tree_list_row_get_expanded(treeRow) != 0
    }
    /// Performs the `setOutlineRowExpanded` operation.
    public func setOutlineRowExpanded(_ expanded: Bool, atRow row: Int, for outline: NativeHandle) {
        guard let treeRow = outlineTreeRow(atRow: row, for: outline) else { return }
        defer { g_object_unref(UnsafeMutableRawPointer(treeRow)) }
        gtk_tree_list_row_set_expanded(treeRow, gboolean(expanded ? 1 : 0))
    }
    /// Performs the `selectOutlineRow` operation.
    public func selectOutlineRow(_ row: Int, for outline: NativeHandle) {
        guard let selection = tableSelections[outline.rawValue] else { return }
        gtk_single_selection_set_selected(selection, row < 0 ? guint.max : guint(row))
    }
    /// Records the child-count and cell-text providers used by the tree model and bind trampolines.
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
    /// Creates a token field: a `GtkBox` hosting chip buttons and a trailing `GtkEntry`.
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
    /// Replaces a token field's tokens and rebuilds its chip buttons.
    public func setTokens(_ tokens: [String], for handle: NativeHandle) {
        tokenValues[handle.rawValue] = tokens
        rebuildTokenChips(for: handle)
    }
    /// Registers the tokens-change action for a token field.
    public func setTokensChangeAction(for handle: NativeHandle, action: @escaping ([String]) -> Void) {
        tokenActions[handle.rawValue] = action
    }

    /// Commits the entry's text as a new token (Enter pressed).
    internal func commitTokenEntry(_ handle: NativeHandle) {
        guard let entry = tokenEntries[handle.rawValue] else { return }
        let text = String(cString: gtk_editable_get_text(entry)).trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        tokenValues[handle.rawValue, default: []].append(text)
        gtk_editable_set_text(entry, "")
        rebuildTokenChips(for: handle)
        tokenActions[handle.rawValue]?(tokenValues[handle.rawValue] ?? [])
    }

    /// Removes token `index` (its chip was clicked).
    internal func removeToken(_ handle: NativeHandle, at index: Int) {
        guard var tokens = tokenValues[handle.rawValue], index < tokens.count else { return }
        tokens.remove(at: index)
        tokenValues[handle.rawValue] = tokens
        rebuildTokenChips(for: handle)
        tokenActions[handle.rawValue]?(tokens)
    }

    /// Recreates the chip buttons to match the current tokens (entry stays last).
    internal func rebuildTokenChips(for handle: NativeHandle) {
        guard let boxWidget = widget(handle) else { return }
        for chip in tokenChips[handle.rawValue] ?? [] {
            gtk_box_remove(asBox(boxWidget), asWidget(chip))
        }
        var chips: [OpaquePointer] = []
        var previous: OpaquePointer? = nil
        for (index, token) in (tokenValues[handle.rawValue] ?? []).enumerated() {
            let chip = gtk_button_new_with_label("\(token) ✕")!
            gtk_widget_add_css_class(chip, "linchocolate-token-chip")
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
    /// Creates a `GtkPicture` as the image view.
}

#endif
