// Part of the shared demo, split out of main.swift by topic.
//
// Only DECLARATIONS live here. main.swift is Swift's top-level-code file:
// its statements run in written order, and moving one here would turn it
// into a lazily-initialized global that never runs. Declarations have no
// such ordering, so they move freely.

#if canImport(WASMChocolate)
import WASMChocolate
#elseif canImport(LinChocolate)
import LinChocolate
#elseif canImport(WinChocolate)
import WinChocolate
#else
import AppKit
#endif

/// Reads a cell's display string the plain-AppKit way: ask the table's data
/// source for the column/row object value (there is no cell-string accessor
/// on Apple's `NSTableView`).
@MainActor
func demoTableCellString(_ table: NSTableView, column: Int, row: Int) -> String? {
    guard row >= 0, table.tableColumns.indices.contains(column) else {
        return nil
    }

    // Ask through the concrete demo source: the protocol requirement is
    // @objc-optional on Apple, so a generic protocol call spells differently
    // per platform — the concrete method is identical on both.
    let value = (table.dataSource as? DemoTableDataSource)?
        .tableView(table, objectValueFor: table.tableColumns[column], row: row)
    return (value as? String) ?? value.map { String(describing: $0) }
}

@MainActor
func tableRowSummary(_ table: NSTableView, prefix: String) -> String {
    let row = table.clickedRow
    if row >= 0,
       let name = demoTableCellString(table, column: 0, row: row),
       let status = demoTableCellString(table, column: 1, row: row) {
        let column = table.clickedColumn
        if column >= 0, table.tableColumns.indices.contains(column) {
            return "\(prefix): row \(row + 1), \(table.tableColumns[column].title) - \(name) - \(status)"
        }

        return "\(prefix): row \(row + 1) - \(name) - \(status)"
    }

    return "\(prefix): no row"
}

@MainActor
func tableColumnSummary(_ table: NSTableView) -> String? {
    let column = table.clickedColumn
    guard table.clickedRow < 0,
          column >= 0,
          table.tableColumns.indices.contains(column) else {
        return nil
    }

    return "Table column: \(table.tableColumns[column].title)"
}

@MainActor
func selectedTableRowValues(_ table: NSTableView) -> [String]? {
    guard table.selectedRow >= 0 else {
        return nil
    }

    let values = (0..<table.numberOfColumns).map { column in
        demoTableCellString(table, column: column, row: table.selectedRow) ?? ""
    }
    return values.isEmpty ? nil : values
}

@discardableResult
@MainActor
func selectTableRow(matching values: [String], in table: NSTableView) -> Bool {
    for row in 0..<table.numberOfRows {
        let rowValues = (0..<table.numberOfColumns).map { column in
            demoTableCellString(table, column: column, row: row) ?? ""
        }
        if rowValues == values {
            table.selectRowIndexes([row], byExtendingSelection: false)
            table.scrollRowToVisible(row)
            return true
        }
    }

    return false
}

func demoResourcePath(named name: String, ofType type: String = "bmp") -> String {
    Bundle.main.path(forResource: name, ofType: type, inDirectory: "Resources")
        ?? Bundle(path: ".")?.path(forResource: name, ofType: type, inDirectory: "Demo\\DemoApplication\\Resources")
        ?? "Demo\\DemoApplication\\Resources\\\(name).\(type)"
}

/// Writes a 32x32 ICO file at runtime so the demo can exercise icon decoding.
func demoIconResourcePath() -> String {
    let side = 32
    var rows: [UInt8] = []

    // Pixel rows bottom-up in BGRA: a blue disc on a yellow field.
    for y in stride(from: side - 1, through: 0, by: -1) {
        for x in 0..<side {
            let dx = x - side / 2
            let dy = y - side / 2
            if dx * dx + dy * dy <= 144 {
                rows.append(contentsOf: [200, 120, 40, 255])
            } else {
                rows.append(contentsOf: [60, 200, 250, 255])
            }
        }
    }
    let andMask = Array(repeating: UInt8(0), count: side * 4)

    var bytes: [UInt8] = []
    func appendU16(_ value: UInt16) {
        bytes.append(UInt8(value & 0xff))
        bytes.append(UInt8(value >> 8))
    }
    func appendU32(_ value: UInt32) {
        for shift: UInt32 in [0, 8, 16, 24] {
            bytes.append(UInt8((value >> shift) & 0xff))
        }
    }

    // ICONDIR + one ICONDIRENTRY + BITMAPINFOHEADER (double height) + masks.
    appendU16(0)
    appendU16(1)
    appendU16(1)
    bytes.append(UInt8(side))
    bytes.append(UInt8(side))
    bytes.append(0)
    bytes.append(0)
    appendU16(1)
    appendU16(32)
    appendU32(UInt32(40 + rows.count + andMask.count))
    appendU32(22)
    appendU32(40)
    appendU32(UInt32(side))
    appendU32(UInt32(side * 2))
    appendU16(1)
    appendU16(32)
    appendU32(0)
    appendU32(UInt32(rows.count + andMask.count))
    appendU32(0)
    appendU32(0)
    appendU32(0)
    appendU32(0)
    bytes.append(contentsOf: rows)
    bytes.append(contentsOf: andMask)

    let candidates = [
        URL(fileURLWithPath: Bundle.main.bundlePath).appendingPathComponent("WinChocolateIconDemo.ico").path,
        "C:\\AIResearch\\WinChocolate\\Code\\WinChocolate\\.build\\aarch64-unknown-windows-msvc\\debug\\WinChocolateIconDemo.ico",
        "C:\\Users\\bobby\\AppData\\Local\\Temp\\WinChocolateIconDemo.ico"
    ]
    for path in candidates {
        let url = URL(fileURLWithPath: path)
        do {
            try Data(bytes).write(to: url)
            if (try? Data(contentsOf: url))?.isEmpty == false {
                return path
            }
        } catch {
            continue
        }
    }

    return candidates[0]
}
