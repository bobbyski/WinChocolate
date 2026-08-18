// `NSTableView` as a real `<table>`.
//
// The last band in the catalog. A table is the one control where the browser's
// native element is *more* capable than the drawing this framework does
// elsewhere: rows, columns, headers and a scrolling body are exactly what
// `<table>` inside an `overflow: auto` box already is, so almost none of this
// is layout work — it is wiring selection and sorting back into `records` so
// the inherited getters keep answering correctly.

#if canImport(JavaScriptKit)

import JavaScriptKit
import SwiftDOM

extension WASMNativeControlBackend {
    /// Builds a scrolling table with a sticky header row.
    internal func makeTableView(_ handle: NativeHandle, columns: [String],
                                columnWidths: [CGFloat], content: NativeTableContent,
                                frame: NSRect, parent: NativeHandle?) {
        let viewport = position(Element.div(), in: frame)
            .setStyle("overflow", "auto")
            .setStyle("background", "#ffffff")
            .setStyle("border", "1px solid #c0c0c0")

        let table = Element.create("table")
            .setStyle("width", "100%")
            .setStyle("border-collapse", "collapse")
            .setStyle("font", "13px system-ui, sans-serif")
        _ = viewport.appendChild(table)

        let head = Element.create("thead")
        _ = table.appendChild(head)
        let body = Element.create("tbody")
        _ = table.appendChild(body)

        tableBodies[handle] = body
        tableHeads[handle] = head
        register(handle, element: viewport, parent: parent)

        rebuildTableHeader(handle, columns: columns, columnWidths: columnWidths)
        rebuildTableRows(handle, rows: content.rows, selectedRow: content.selectedRow)
    }

    /// Rebuilds the header row, wiring each header to the sort action.
    internal func rebuildTableHeader(_ handle: NativeHandle, columns: [String],
                                     columnWidths: [CGFloat]) {
        guard let head = tableHeads[handle] else { return }
        _ = head.removeAllChildren()

        let row = Element.create("tr")
        var cells: [Element] = []
        for (index, title) in columns.enumerated() {
            let cell = Element.create("th")
                .setStyle("position", "sticky")
                .setStyle("top", "0")
                .setStyle("background", "#f0f0f0")
                .setStyle("border-bottom", "1px solid #c0c0c0")
                .setStyle("padding", "4px 8px")
                .setStyle("text-align", "left")
                .setStyle("font-weight", "600")
                .setStyle("cursor", "default")
                .setStyle("white-space", "nowrap")
            if columnWidths.indices.contains(index) {
                _ = cell.setStyle("width", "\(columnWidths[index])px")
            }
            cell.textContent = title
            // A header click is a *column* click with no row — that pairing is
            // how the framework tells "sort by this column" apart from "select
            // this row", so both halves have to be written before firing.
            listeners[handle, default: []].append(cell.addEventListener(.click) { [weak self] _ in
                guard let self else { return }
                self.records[handle]?.tableClickedColumn = index
                self.records[handle]?.tableClickedRow = -1
                self.actions[handle]?()
            })
            _ = row.appendChild(cell)
            cells.append(cell)
        }
        _ = head.appendChild(row)
        tableHeaderCells[handle] = cells
        applyStoredSortIndicator(handle)
    }

    /// Rebuilds every row.
    internal func rebuildTableRows(_ handle: NativeHandle, rows: [[String]], selectedRow: Int) {
        guard let body = tableBodies[handle] else { return }
        _ = body.removeAllChildren()

        var built: [Element] = []
        for (rowIndex, values) in rows.enumerated() {
            let row = Element.create("tr")
                .setStyle("cursor", "default")
            for value in values {
                let cell = Element.create("td")
                    .setStyle("padding", "3px 8px")
                    .setStyle("border-bottom", "1px solid #ededed")
                    .setStyle("white-space", "nowrap")
                cell.textContent = value
                _ = row.appendChild(cell)
            }
            listeners[handle, default: []].append(row.addEventListener(.click) { [weak self] _ in
                guard let self else { return }
                self.records[handle]?.tableSelectedRow = rowIndex
                self.records[handle]?.tableClickedRow = rowIndex
                self.records[handle]?.tableClickedColumn = -1
                self.tableSelectedRowSets[handle] = [rowIndex]
                self.highlightTableSelection(handle)
                self.actions[handle]?()
            })
            _ = body.appendChild(row)
            built.append(row)
        }
        tableRows[handle] = built
        highlightTableSelection(handle)
    }

    /// Paints the selection band on the selected rows.
    internal func highlightTableSelection(_ handle: NativeHandle) {
        guard let rows = tableRows[handle] else { return }
        let selected = Set(tableSelectedRowSets[handle]
            ?? (records[handle]?.tableSelectedRow).map { $0 >= 0 ? [$0] : [] } ?? [])
        for (index, row) in rows.enumerated() {
            let isSelected = selected.contains(index)
            _ = row
                .setStyle("background", isSelected ? "#0a64c8" : "")
                .setStyle("color", isSelected ? "#ffffff" : "")
        }
    }

    /// Updates one cell without rebuilding the table.
    internal func setTableCell(_ text: String, row: Int, column: Int, for handle: NativeHandle) {
        guard let rows = tableRows[handle], rows.indices.contains(row) else { return }
        let cells = rows[row].children
        guard cells.indices.contains(column) else { return }
        cells[column].textContent = text
    }

    /// Draws the sort arrow on a column header.
    internal func applySortIndicator(column: Int, ascending: Bool, for handle: NativeHandle) {
        guard let cells = tableHeaderCells[handle] else { return }
        let columns = records[handle]?.tableColumns ?? []
        for (index, cell) in cells.enumerated() {
            let title = columns.indices.contains(index) ? columns[index] : ""
            cell.textContent = index == column
                ? "\(title) \(ascending ? "▲" : "▼")"
                : title
        }
    }

    /// Reapplies whatever sort indicator was recorded, after a header rebuild.
    private func applyStoredSortIndicator(_ handle: NativeHandle) {
        guard let indicator = tableSortIndicators[handle] else { return }
        applySortIndicator(column: indicator.column, ascending: indicator.ascending, for: handle)
    }

    /// Scrolls a row into view.
    internal func scrollTableRow(_ row: Int, for handle: NativeHandle) {
        guard let rows = tableRows[handle], rows.indices.contains(row) else { return }
        _ = rows[row].rawValue.scrollIntoView?(JSObject.global.Object.function!.new())
    }
}

#endif
