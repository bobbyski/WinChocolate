#if canImport(CGTK)
import CGTK
import CGTKCompat
import Foundation

extension GTKNativeControlBackend {
    public func createColorWell(color: NSColor, frame: NSRect) -> NativeHandle {
        // GtkColorButton (via the GtkColorChooser interface) is deprecated in
        // GTK 4.10 like GtkComboBoxText, but remains the direct color-well
        // analog; the non-deprecated GtkColorDialogButton is async-only.
        let cb = lc_color_button_new()!
        // Non-modal: a modal chooser grabs all input, and if the dialog fails to
        // map (seen over XQuartz) the whole app looks hung and cannot be closed.
        lc_color_button_set_modal(cb, gboolean(0))
        gtk_widget_set_size_request(cb, Int32(frame.width), Int32(frame.height))
        let h = allocate(cb, .colorWell, frame: frame)
        setColor(color, for: h)
        return h
    }
    /// Creates a `GtkNotebook` as the tab-view container.
    public func createTabView(frame: NSRect) -> NativeHandle {
        let nb = gtk_notebook_new()!
        gtk_widget_set_size_request(nb, Int32(frame.width), Int32(frame.height))
        gtk_widget_set_hexpand(nb, gboolean(1))
        gtk_widget_set_vexpand(nb, gboolean(1))
        return allocate(nb, .tabView, frame: frame)
    }
    /// Appends a page to a `GtkNotebook`, labelled `label`.
    public func addTabPage(_ page: NativeHandle, label: String, to tabView: NativeHandle) {
        guard let nb = widget(tabView), let p = widget(page) else { return }
        let tabLabel = gtk_label_new(label)
        gtk_notebook_append_page(nb, asWidget(p), tabLabel)   // GtkNotebook is opaque
    }
    /// Creates a segmented control as a linked row of `GtkToggleButton`s.
    public func createSegmentedControl(labels: [String], frame: NSRect) -> NativeHandle {
        // Composed control: linked GtkToggleButtons in a horizontal box — the
        // native GTK idiom for a segmented switcher ("linked" style class).
        let box = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0)!
        gtk_widget_add_css_class(box, "linked")
        gtk_widget_add_css_class(box, "linchocolate-segmented")
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
    /// Creates a table as a `GtkColumnView` inside a `GtkScrolledWindow`.
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
    /// Appends a titled `GtkColumnViewColumn` with a signal-driven cell factory.
    public func addTableColumn(title: String, editable: Bool, to table: NativeHandle) {
        guard let cv = tableColumnViews[table.rawValue] else { return }
        let columnIndex = tableColumnCounts[table.rawValue, default: 0]
        if editable { editableTableColumns[table.rawValue, default: []].insert(columnIndex) }
        let factory = gtk_signal_list_item_factory_new()!
        let setupBox = TableColumnBox(backend: self, table: table.rawValue, column: columnIndex, editable: editable)
        g_signal_connect_data(
            UnsafeMutableRawPointer(factory), "setup",
            unsafeBitCast(gtkTableCellSetupTrampoline, to: GCallback.self),
            Unmanaged.passRetained(setupBox).toOpaque(), boxRelease, GConnectFlags(rawValue: 0)
        )
        let box = TableColumnBox(backend: self, table: table.rawValue, column: columnIndex, editable: editable)
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
    /// Renames an existing table column via `gtk_column_view_column_set_title`.
    public func setTableColumnTitle(_ title: String, columnIndex: Int, for table: NativeHandle) {
        guard let columns = tableColumnObjects[table.rawValue], columnIndex < columns.count else { return }
        gtk_column_view_column_set_title(columns[columnIndex], title)
    }
    /// Marks a column sortable via a placeholder `GtkCustomSorter` (real sort is Swift-side).
    public func setColumnSortable(_ columnIndex: Int, for table: NativeHandle) {
        guard let columns = tableColumnObjects[table.rawValue], columnIndex < columns.count else { return }
        // A no-op custom sorter makes the header clickable and drives the view's
        // GtkColumnViewSorter; the actual re-sort happens Swift-side (the model
        // is count-only), so we only need the header click + indicator + signal.
        let sorter = gtk_custom_sorter_new(nil, nil, nil)
        gtk_column_view_column_set_sorter(columns[columnIndex], UnsafeMutablePointer<GtkSorter>(sorter))
    }
    /// Wires the column-view's sorter `changed` signal to `action`, passing `(columnIndex, ascending)`.
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
    /// Brings `row` into view via `gtk_column_view_scroll_to` without changing focus/selection.
    public func scrollTableRowToVisible(_ row: Int, for table: NativeHandle) {
        guard row >= 0, let cv = tableColumnViews[table.rawValue],
              row < (tableRowCounts[table.rawValue] ?? 0) else { return }
        // GTK_LIST_SCROLL_NONE: bring the row into view but leave focus and
        // selection alone — AppKit's scrollRowToVisible does not select.
        _ = cv
    }
    /// Wires the column-view's `activate` signal (double-click / Enter) to `action`.
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
        _ = sorter
        guard let action = tableSortActions[table] else { return }
        action(0, true)
    }
    /// Called from the row-activate trampoline (double-click / Enter).
    func handleRowActivate(table: UInt, position: Int) {
        tableActivateActions[table]?(position)
    }
    /// Replaces all items in the underlying `GtkStringList`, forcing every visible cell to re-bind.
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
    /// Records the cell-text provider used by the column bind trampoline.
    public func setTableCellCommitAction(for handle: NativeHandle, _ handler: @escaping (Int, Int, String) -> Void) {
        tableCommitActions[handle.rawValue] = handler
    }
    /// Called from the editable-cell commit trampoline.
    func reportCellEdit(table: UInt, row: Int, column: Int, text: String) {
        tableCommitActions[table]?(row, column, text)
    }
    /// Performs the `setTableCellProvider` operation.
    public func setTableCellProvider(for table: NativeHandle, provider: @escaping (Int, Int) -> String) {
        tableProviders[table.rawValue] = provider
    }
    /// Cell text for the bind trampoline.
    func tableCellText(table: UInt, row: Int, column: Int) -> String {
        tableProviders[table]?(row, column) ?? ""
    }
    /// Creates a collection view as a `GtkFlowBox` inside a `GtkScrolledWindow`.
    public func createCollectionView(frame: NSRect) -> NativeHandle {
        // A GtkFlowBox hosting each item's REAL widget — Apple's collection
        // hosts each NSCollectionViewItem's view (the demo's items are push
        // buttons), so a text-tile grid was never going to look like the Mac.
        // The flow box wraps children by width, like NSCollectionViewFlowLayout.
        // A vertical GtkBox of section blocks; each block is an optional header
        // band, a GtkFlowBox of that section's items, and an optional footer
        // band. One flow box per section is what gives AppKit's sectioned flow
        // layout its full-width bands — a single flow box cannot break a line
        // for a header.
        let stack = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0)!
        gtk_widget_add_css_class(stack, "linchocolate-collection")
        let scroller = gtk_scrolled_window_new()!
        gtk_scrolled_window_set_child(OpaquePointer(scroller), stack)
        gtk_widget_set_size_request(scroller, Int32(frame.width), Int32(frame.height))
        let h = allocate(scroller, .collection, frame: frame)
        collectionStacks[h.rawValue] = OpaquePointer(stack)
        return h
    }
    /// Sets the item count and rebuilds (= reload). A collection with no
    /// declared sections is one unsectioned run of items.
    public func setCollectionItemCount(_ count: Int, for collection: NativeHandle) {
        let raw = collection.rawValue
        collectionItemCounts[raw] = count
        collectionSectionSpecs[raw] = [NativeCollectionSection(itemCount: count)]
        rebuildCollectionChildren(raw)
    }
    /// Performs the `setCollectionFlow` operation.
    public func setCollectionFlow(interitemSpacing: Double, lineSpacing: Double, horizontal: Bool,
                                  for collection: NativeHandle) {
        // Stored only — `setCollectionSections` does the rebuild, so a reload
        // rebuilds once rather than twice.
        collectionFlowGeometry[collection.rawValue] = GTKCollectionFlowGeometry(
            interitem: interitemSpacing,
            line: lineSpacing,
            horizontal: horizontal
        )
    }
    /// Performs the `setCollectionSections` operation.
    public func setCollectionSections(_ sections: [NativeCollectionSection], for collection: NativeHandle) {
        let raw = collection.rawValue
        collectionSectionSpecs[raw] = sections
        collectionItemCounts[raw] = sections.reduce(0) { $0 + $1.itemCount }
        rebuildCollectionChildren(raw)
    }
    /// Records the text provider used when no item-view provider supplies a widget.
    public func setCollectionItemProvider(for collection: NativeHandle, provider: @escaping (Int) -> String) {
        collectionProviders[collection.rawValue] = provider
    }
    /// Records the item-view provider used to host each item's real widget.
    public func setCollectionItemViewProvider(for collection: NativeHandle, provider: @escaping (Int) -> NativeHandle?) {
        collectionViewProviders[collection.rawValue] = provider
    }

    /// (Re)fills the flow box: each item contributes its real widget when the
    /// view provider has one, else a text label from the text provider.
    internal func rebuildCollectionChildren(_ raw: UInt) {
        guard let stack = collectionStacks[raw] else { return }
        suppressCollectionSelection.insert(raw)
        // Tear the previous blocks down WITHOUT destroying anything we merely
        // host. Item and band widgets belong to their Swift views; a GTK widget
        // whose last reference is its parent dies the moment it is unparented,
        // so removing a section's flow box took its buttons with it and the next
        // rebuild had nothing left to re-host (the items vanished on reload).
        // Hold a reference across the move and drop it once re-parented.
        var rescued: [UnsafeMutableRawPointer] = []
        let previousFlows = collectionSectionFlows[raw] ?? []
        while let child = gtk_widget_get_first_child(asWidget(stack)) {
            if let entry = previousFlows.first(where: { asWidget($0.flow) == child }) {
                // A section flow box: rescue each hosted item, then drop the box.
                while let flowChild = gtk_widget_get_first_child(asWidget(entry.flow)) {
                    if let hosted = gtk_widget_get_first_child(flowChild) {
                        g_object_ref(UnsafeMutableRawPointer(hosted))
                        rescued.append(UnsafeMutableRawPointer(hosted))
                        gtk_flow_box_remove(entry.flow, hosted)
                    } else {
                        gtk_flow_box_remove(entry.flow, flowChild)
                    }
                }
            } else {
                // A header/footer band.
                g_object_ref(UnsafeMutableRawPointer(child))
                rescued.append(UnsafeMutableRawPointer(child))
            }
            gtk_box_remove(asBox(stack), child)
        }
        defer { for widget in rescued { g_object_unref(widget) } }
        collectionSectionFlows[raw] = []
        collectionFlows[raw] = nil
        // AppKit's `.horizontal` scroll direction lays the SECTIONS out left to
        // right, each one's items flowing top-to-bottom in columns. `.vertical`
        // stacks the sections. Match that by re-orienting the section stack.
        let horizontal = collectionFlowGeometry[raw]?.horizontal ?? false
        gtk_orientable_set_orientation(stack, horizontal ? GTK_ORIENTATION_HORIZONTAL
                                                         : GTK_ORIENTATION_VERTICAL)
        let sections = collectionSectionSpecs[raw] ?? [NativeCollectionSection(itemCount: collectionItemCounts[raw] ?? 0)]
        var base = 0
        for section in sections {
            if let header = section.header, let hw = widgets[header.rawValue] {
                hostBand(asWidget(hw), in: stack)
            }
            let flow = makeCollectionFlow(raw: raw, base: base)
            gtk_box_append(asBox(stack), asWidget(flow))
            collectionSectionFlows[raw, default: []].append((flow: flow, base: base))
            if collectionFlows[raw] == nil { collectionFlows[raw] = flow }
            fillCollectionFlow(flow, raw: raw, base: base, count: section.itemCount)
            base += section.itemCount
            if let footer = section.footer, let fw = widgets[footer.rawValue] {
                hostBand(asWidget(fw), in: stack)
            }
        }
        suppressCollectionSelection.remove(raw)
    }
    /// Appends a full-width header/footer band, re-parenting it safely.
}

#endif
