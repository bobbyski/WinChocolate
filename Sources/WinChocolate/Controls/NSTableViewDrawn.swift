/// Framework-drawn (view-based) table rendering for `NSTableView`.
///
/// A native `SysListView32` can't host arbitrary per-cell views, so when the
/// delegate vends cell views the table realizes a plain custom-drawn peer: it
/// draws the header, grid, and selection itself, and hosts the delegate's cell
/// views as real child subviews positioned in a column/row grid. This is the
/// same custom-draw approach used for the level indicator and token chips,
/// scaled to a table. (First slice: no vertical scrolling yet — rows beyond
/// the frame are clipped; scrolling is a follow-up.)
extension NSTableView {
    /// Whether the table should draw itself and host view-based cells.
    var winShouldUseDrawnCells: Bool {
        guard winUsesViewBasedCells, numberOfRows > 0, !tableColumns.isEmpty, let delegate else {
            return false
        }
        return delegate.tableView(self, viewFor: tableColumns[0], row: 0) != nil
    }

    /// Whether the drawn table hides its header (all columns untitled).
    var winHeaderHidden: Bool {
        tableColumns.allSatisfy { $0.title.isEmpty }
    }

    /// The header row height (0 when the header is hidden).
    var winHeaderHeight: CGFloat {
        winHeaderHidden ? 0 : winDrawnHeaderHeight
    }

    /// The x origin of a drawn column, from cumulative column widths.
    func winColumnX(_ column: Int) -> CGFloat {
        tableColumns.prefix(column).reduce(0) { $0 + max(20, $1.width) }
    }

    /// The cell rectangle for a row and column in the drawn table.
    func winCellRect(row: Int, column: Int) -> NSRect {
        NSRect(
            x: winColumnX(column),
            y: winHeaderHeight + CGFloat(row) * winDrawnRowHeight,
            width: column < tableColumns.count ? max(20, tableColumns[column].width) : 0,
            height: winDrawnRowHeight
        )
    }

    /// The row at a y-coordinate in the drawn table, or `-1` above the rows.
    func winRowAtY(_ y: CGFloat) -> Int {
        guard y >= winHeaderHeight else {
            return -1
        }
        let row = Int((y - winHeaderHeight) / winDrawnRowHeight)
        return row < numberOfRows ? row : -1
    }

    /// Rebuilds the hosted cell views for the drawn table.
    func winRebuildHostedViews() {
        guard winIsDrawn else {
            return
        }
        for view in winHostedCellViews {
            view.removeFromSuperview()
        }
        winHostedCellViews.removeAll()

        for row in 0..<numberOfRows {
            for column in tableColumns.indices {
                guard let cellView = delegate?.tableView(self, viewFor: tableColumns[column], row: row) else {
                    continue
                }
                // Inset the cell view slightly so grid lines/selection show.
                var frame = winCellRect(row: row, column: column)
                frame = frame.insetBy(dx: 1, dy: 1)
                cellView.frame = frame
                addSubview(cellView)
                winHostedCellViews.append(cellView)
            }
        }
    }

    /// Draws the drawn table's header, alternating rows, selection, and grid.
    func winDrawTable(_ dirtyRect: NSRect) {
        let width = frame.size.width

        // Background.
        NSColor.white.setFill()
        NSBezierPath(rect: bounds).fill()

        // Alternating row backgrounds and selection highlight.
        for row in 0..<numberOfRows {
            let rowRect = NSRect(x: 0, y: winHeaderHeight + CGFloat(row) * winDrawnRowHeight, width: width, height: winDrawnRowHeight)
            if selectedRowIndexes.contains(row) {
                NSColor.selectedTextBackgroundColor.setFill()
                NSBezierPath(rect: rowRect).fill()
            } else if usesAlternatingRowBackgroundColors, row % 2 == 1 {
                NSColor(white: 0.96, alpha: 1).setFill()
                NSBezierPath(rect: rowRect).fill()
            }
        }

        // Grid lines.
        NSColor(white: 0.85, alpha: 1).setStroke()
        if gridStyleMask.contains(.solidHorizontalGridLineMask) {
            for row in 0...numberOfRows {
                let y = winHeaderHeight + CGFloat(row) * winDrawnRowHeight
                let line = NSBezierPath()
                line.move(to: NSMakePoint(0, y))
                line.line(to: NSMakePoint(width, y))
                line.stroke()
            }
        }
        if gridStyleMask.contains(.solidVerticalGridLineMask) {
            for column in tableColumns.indices {
                let x = winColumnX(column)
                let line = NSBezierPath()
                line.move(to: NSMakePoint(x, winHeaderHeight))
                line.line(to: NSMakePoint(x, winHeaderHeight + CGFloat(numberOfRows) * winDrawnRowHeight))
                line.stroke()
            }
        }

        // Header row.
        if !winHeaderHidden {
            let headerRect = NSRect(x: 0, y: 0, width: width, height: winDrawnHeaderHeight)
            NSColor(white: 0.93, alpha: 1).setFill()
            NSBezierPath(rect: headerRect).fill()
            NSColor(white: 0.75, alpha: 1).setStroke()
            let base = NSBezierPath()
            base.move(to: NSMakePoint(0, winDrawnHeaderHeight))
            base.line(to: NSMakePoint(width, winDrawnHeaderHeight))
            base.stroke()

            for column in tableColumns.indices {
                let title = tableColumns[column].title
                title.draw(at: NSMakePoint(winColumnX(column) + 5, 5), withAttributes: [
                    .font: NSFont.boldSystemFont(ofSize: 12),
                    .foregroundColor: NSColor(white: 0.25, alpha: 1),
                ])
                // Sort indicator arrow.
                if let sort = sortDescriptors.first,
                   sort.key == tableColumns[column].sortDescriptorPrototype?.key {
                    let arrowX = winColumnX(column) + max(20, tableColumns[column].width) - 14
                    (sort.ascending ? "▲" : "▼").draw(at: NSMakePoint(arrowX, 6), withAttributes: [
                        .font: NSFont.systemFont(ofSize: 8),
                        .foregroundColor: NSColor(white: 0.4, alpha: 1),
                    ])
                }
            }
        }
    }

    /// Handles a click in the drawn table: selects the hit row, or sorts on a
    /// header click.
    func winDrawnMouseDown(_ event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        _ = window?.makeFirstResponder(self)

        // Header click → sort by the hit column.
        if !winHeaderHidden, point.y < winDrawnHeaderHeight {
            let column = winColumnAtX(point.x)
            if column >= 0, let sort = sortUsingDescriptorPrototype(forColumn: column) {
                _ = sort
                needsDisplay = true
            }
            return
        }

        let row = winRowAtY(point.y)
        guard row >= 0 else {
            return
        }
        let extend = allowsMultipleSelection && (event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.command))
        if extend, selectedRowIndexes.contains(row) {
            deselectRow(row)
        } else {
            selectRowIndexes([row], byExtendingSelection: extend)
        }
        needsDisplay = true
        sendAction()
    }

    /// The column at an x-coordinate, or `-1`.
    private func winColumnAtX(_ x: CGFloat) -> Int {
        for column in tableColumns.indices {
            let start = winColumnX(column)
            let end = start + max(20, tableColumns[column].width)
            if x >= start, x < end {
                return column
            }
        }
        return -1
    }
}
