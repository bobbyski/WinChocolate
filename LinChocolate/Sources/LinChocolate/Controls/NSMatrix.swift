import Foundation

/// Minimal `NSButtonCell` — the prototype an `NSMatrix` clones for each cell.
/// Only the title is used in this slice.
public final class NSButtonCell {
    public var title: String
    public init(title: String) { self.title = title }

    /// Apple's cell initializer spelling.
    public convenience init(textCell: String) { self.init(title: textCell) }
}

/// AppKit-shaped `NSMatrix`: a grid of button cells. No GTK peer — a composed
/// control built from `NSButton`s laid out in a rows×columns grid. Selecting a
/// cell updates `selectedRow`/`selectedColumn` and fires `onAction`.
open class NSMatrix: NSControl {

    /// The matrix tracking mode (accepted for API parity; all modes render as a
    /// clickable button grid in this slice).
    public enum Mode {
        case trackModeMatrix, highlightModeMatrix, radioModeMatrix, listModeMatrix
    }

    public let mode: Mode
    private let rows: Int
    private let columns: Int
    private var cellButtons: [[NSButton]] = []

    /// Size of each cell. Setting it re-lays out the grid.
    public var cellSize = NSMakeSize(100, 24) { didSet { layoutCells() } }
    /// Spacing between cells. Setting it re-lays out the grid.
    public var intercellSpacing = NSMakeSize(4, 4) { didSet { layoutCells() } }

    public private(set) var selectedRow = -1
    public private(set) var selectedColumn = -1

    /// Fired when the user selects a cell.
    public var onAction: ((NSMatrix) -> Void)?

    /// Creates an empty matrix, as AppKit's `init(frame:)` does — no rows, no
    /// columns, default tracking mode. Cells arrive via the designated
    /// initializer below.
    public required convenience init(frame: NSRect) {
        self.init(frame: frame, mode: .trackModeMatrix, prototype: NSButtonCell(title: ""),
                  numberOfRows: 0, numberOfColumns: 0)
    }

    public init(frame: NSRect, mode: Mode, prototype: NSButtonCell,
                numberOfRows: Int, numberOfColumns: Int) {
        self.mode = mode
        self.rows = numberOfRows
        self.columns = numberOfColumns
        super.init(frame: frame)

        for r in 0..<numberOfRows {
            var rowButtons: [NSButton] = []
            for c in 0..<numberOfColumns {
                let button = NSButton(title: prototype.title, frame: .zero)
                button.onAction = { [weak self] _ in
                    guard let self else { return }
                    self.selectCell(atRow: r, column: c)
                    self.onAction?(self)
                    self.sendAction()
                }
                addSubview(button)
                rowButtons.append(button)
            }
            cellButtons.append(rowButtons)
        }
        layoutCells()
    }

    /// The button backing the cell at `(row, column)`, if any.
    public func button(atRow row: Int, column: Int) -> NSButton? {
        guard cellButtons.indices.contains(row), cellButtons[row].indices.contains(column) else { return nil }
        return cellButtons[row][column]
    }

    /// Selects a cell without firing the action.
    public func selectCell(atRow row: Int, column: Int) {
        guard cellButtons.indices.contains(row),
              cellButtons[row].indices.contains(column) else { return }
        selectedRow = row
        selectedColumn = column
    }

    /// Positions every cell in a rows×columns grid (AppKit bottom-left: row 0 at top).
    private func layoutCells() {
        let cw = cellSize.width, ch = cellSize.height
        let hs = intercellSpacing.width, vs = intercellSpacing.height
        for r in 0..<rows {
            for c in 0..<columns {
                let x = Double(c) * (cw + hs)
                // Row 0 is topmost either way; `isFlipped` is this matrix's own.
                let y = CoordinateSpace.stackedRowY(index: r, rowHeight: ch, spacing: vs,
                                                    contentHeight: ch,
                                                    containerHeight: frame.height,
                                                    isFlipped: isFlipped)
                cellButtons[r][c].frame = NSMakeRect(x, y, cw, ch)
            }
        }
    }
}
