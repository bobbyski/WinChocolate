extension NSOutlineView {
    func installOutlineReorderBridge() {
        guard winOutlineReorderHandler != nil else {
            winRowReorderHandler = nil
            return
        }
        winRowReorderHandler = { [weak self] fromRows, toIndex in
            self?.handleOutlineReorder(fromRows: fromRows, toIndex: toIndex)
        }
    }

    /// Maps a row-level reorder drop to the outline's item terms: the moved
    /// item, its proposed parent (`nil` = root), and the model child index.
    /// Returns `nil` for invalid drops (out of range, into own subtree).
    func winMapReorderDrop(fromRows: IndexSet, toIndex: Int) -> NSOutlineReorderTarget? {
        guard let fromRow = fromRows.first,
              visibleRows.indices.contains(fromRow) else {
            return nil
        }
        let moved = visibleRows[fromRow]

        // Derive the target parent from the row just above the drop position.
        // Dropping directly under an expanded branch reparents into it; anything
        // else joins the parent of the row above (the root when at the top).
        let targetParent: Any?
        if toIndex <= 0 {
            targetParent = nil
        } else {
            let above = visibleRows[min(toIndex, visibleRows.count) - 1]
            if isExpandable(above.item), isItemExpanded(above.item) {
                targetParent = above.item
            } else {
                targetParent = above.parent
            }
        }

        // Never move an item into itself or its own subtree.
        if let targetParent, isItem(targetParent, descendantOfOrEqualTo: moved.item) {
            return nil
        }

        // The proposed child index is the count of the target parent's visible
        // direct children that sit strictly above the drop position. (All direct
        // children — expanded or collapsed — appear in `visibleRows`, so this is
        // the true model child index.)
        let parentKey = targetParent.map { key(for: $0) }
        let siblingRows = visibleRows.indices.filter { idx in
            visibleRows[idx].parent.map { key(for: $0) } == parentKey
        }
        let targetChildIndex = siblingRows.filter { $0 < toIndex }.count
        return NSOutlineReorderTarget(moved: moved.item, parent: targetParent, childIndex: targetChildIndex)
    }

    func handleOutlineReorder(fromRows: IndexSet, toIndex: Int) {
        guard let handler = winOutlineReorderHandler,
              let target = winMapReorderDrop(fromRows: fromRows, toIndex: toIndex) else {
            return
        }
        handler(target.moved, target.parent, target.childIndex)
        reloadData()
    }

    /// Whether `candidate` is `ancestor` itself or sits within its subtree, by
    /// walking the visible parent chain up from `candidate`.
    func isItem(_ candidate: Any, descendantOfOrEqualTo ancestor: Any) -> Bool {
        let ancestorKey = key(for: ancestor)
        var current: Any? = candidate
        while let node = current {
            if key(for: node) == ancestorKey {
                return true
            }
            let nodeKey = key(for: node)
            current = visibleRows.first { key(for: $0.item) == nodeKey }?.parent
        }
        return false
    }

    func rebuildVisibleRows() {
        visibleRows.removeAll()
        appendChildren(of: nil, level: 0)
    }

    func appendChildren(of item: Any?, level: Int) {
        guard let outlineDataSource else {
            return
        }

        let count = winMainActor { outlineDataSource.outlineView(self, numberOfChildrenOfItem: item) }
        guard count > 0 else {
            return
        }

        for index in 0..<count {
            let child = winMainActor { outlineDataSource.outlineView(self, child: index, ofItem: item) }
            visibleRows.append(OutlineRow(item: child, level: level, parent: item))
            if winMainActor({ outlineDataSource.outlineView(self, isItemExpandable: child) }),
               expandedItemKeys.contains(key(for: child)) {
                appendChildren(of: child, level: level + 1)
            }
        }
    }

    func objectValue(for tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard visibleRows.indices.contains(row) else {
            return nil
        }

        let outlineRow = visibleRows[row]
        let value = winMainActor { outlineDataSource?.outlineView(self, objectValueFor: tableColumn, byItem: outlineRow.item) }
            ?? String(describing: outlineRow.item)

        // Indentation and the disclosure triangle are drawn (see the hooks
        // below), so the first column keeps plain text — unless a caller opts
        // back into legacy text markers via `showsDisclosureText` with the
        // drawn path disabled.
        guard showsDisclosureText, !winUsesViewBasedCells,
              tableColumns.first === tableColumn else {
            return value
        }

        let indent = String(repeating: "  ", count: outlineRow.level)
        let marker: String
        if winMainActor({ outlineDataSource?.outlineView(self, isItemExpandable: outlineRow.item) }) == true {
            marker = isItemExpanded(outlineRow.item) ? "- " : "+ "
        } else {
            marker = "  "
        }

        // Interpolating `value` directly would render "Optional(…)"; describe the
        // wrapped value so the first column shows the data source's own text.
        return "\(indent)\(marker)\(value.map { String(describing: $0) } ?? "")"
    }
}
