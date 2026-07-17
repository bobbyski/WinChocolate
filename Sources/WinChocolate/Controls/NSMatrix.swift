/// Legacy button cell used by `NSMatrix`.
open class NSButtonCell: NSCell {
    /// Visible cell title.
    open var title: String

    /// Current button state.
    open var state: NSControl.StateValue

    /// Creates an empty button cell.
    public override init() {
        self.title = ""
        self.state = .off
        super.init()
    }

    /// Creates a button cell with a title.
    package init(title: String) {
        self.title = title
        self.state = .off
        super.init(textCell: title)
    }

    /// Creates a button cell with text.
    public override init(textCell string: String) {
        self.title = string
        self.state = .off
        super.init(textCell: string)
    }
}

/// A legacy AppKit matrix control.
///
/// This compatibility slice composes native-backed `NSButton` children while
/// preserving the old row/column and cell-selection shape.
open class NSMatrix: NSControl {
    /// Matrix selection and tracking mode.
    public enum Mode: Sendable {
        case radioModeMatrix
        case highlightModeMatrix
        case listModeMatrix
        case trackModeMatrix
    }

    private struct Entry {
        var cell: NSButtonCell
        var button: NSButton
    }

    private var entries: [Entry] = []

    /// Matrix behavior mode.
    open var mode: Mode {
        didSet {
            syncButtonTypes()
        }
    }

    /// Size assigned to each cell.
    open var cellSize: NSSize {
        didSet {
            layoutCells()
        }
    }

    /// Space between cells.
    open var intercellSpacing: NSSize {
        didSet {
            layoutCells()
        }
    }

    /// Number of rows.
    public private(set) var numberOfRows: Int

    /// Number of columns.
    public private(set) var numberOfColumns: Int

    /// Selected row, or `-1`.
    public private(set) var selectedRow: Int = -1

    /// Selected column, or `-1`.
    public private(set) var selectedColumn: Int = -1

    /// Creates an empty matrix.
    public required init(frame frameRect: NSRect) {
        self.mode = .radioModeMatrix
        self.cellSize = NSMakeSize(96, 28)
        self.intercellSpacing = NSMakeSize(8, 6)
        self.numberOfRows = 0
        self.numberOfColumns = 0
        super.init(frame: frameRect)
    }

    /// Creates a matrix with a prototype cell.
    public init(frame frameRect: NSRect, mode: Mode, prototype: NSCell?, numberOfRows rows: Int, numberOfColumns columns: Int) {
        self.mode = mode
        self.cellSize = NSMakeSize(96, 28)
        self.intercellSpacing = NSMakeSize(8, 6)
        self.numberOfRows = max(0, rows)
        self.numberOfColumns = max(0, columns)
        super.init(frame: frameRect)
        buildCells(prototype: prototype)
    }

    /// Matrix containers do not take focus; their child buttons do.
    open override var acceptsFirstResponder: Bool {
        false
    }

    /// Returns a cell at row/column.
    open func cell(atRow row: Int, column: Int) -> NSCell? {
        guard let index = flatIndex(row: row, column: column) else {
            return nil
        }

        return entries[index].cell
    }

    /// Returns the selected cell.
    open func selectedCell() -> NSCell? {
        guard let index = flatIndex(row: selectedRow, column: selectedColumn) else {
            return nil
        }

        return entries[index].cell
    }

    /// Selects the cell at row/column.
    open func selectCell(atRow row: Int, column: Int) {
        guard let selectedIndex = flatIndex(row: row, column: column) else {
            return
        }

        for index in entries.indices {
            entries[index].cell.state = index == selectedIndex ? .on : .off
            entries[index].button.state = entries[index].cell.state
        }
        selectedRow = row
        selectedColumn = column
    }

    /// Clears the selected cell.
    open func deselectSelectedCell() {
        for index in entries.indices {
            entries[index].cell.state = .off
            entries[index].button.state = .off
        }
        selectedRow = -1
        selectedColumn = -1
    }

    /// Puts a cell in the matrix.
    open func putCell(_ cell: NSCell, atRow row: Int, column: Int) {
        guard let index = flatIndex(row: row, column: column) else {
            return
        }

        let buttonCell = (cell as? NSButtonCell) ?? NSButtonCell(title: cell.stringValue)
        entries[index].cell = buttonCell
        entries[index].button.title = buttonCell.title
        entries[index].button.state = buttonCell.state
    }

    /// Returns the composed visual button. Not API (18.7): AppKit's `NSMatrix`
    /// is cell-drawn and vends no button views — `package` for the composed
    /// implementation and the suite.
    package func button(atRow row: Int, column: Int) -> NSButton? {
        guard let index = flatIndex(row: row, column: column) else {
            return nil
        }

        return entries[index].button
    }

    /// On Apple, Tab enters the matrix and moves through its cells. The
    /// composed implementation interposes its buttons into the key loop the
    /// same way `NSForm` does: `nextKeyView` keeps Apple's read-back
    /// semantics while the focus walk enters via the first button and leaves
    /// from the last.
    open override var nextKeyView: NSView? {
        get {
            super.nextKeyView
        }
        set {
            super.nextKeyView = newValue
            refreshKeyViewLoop()
        }
    }

    override var winEffectiveNextKeyView: NSView? {
        entries.first?.button ?? super.winEffectiveNextKeyView
    }

    override var winShouldDescendInKeyLoop: Bool {
        false
    }

    private func refreshKeyViewLoop() {
        for (index, entry) in entries.enumerated() {
            entry.button.nextKeyView = index + 1 < entries.count ? entries[index + 1].button : super.nextKeyView
        }
        entries.first?.button.winPreviousKeyView = self
    }

    private func buildCells(prototype: NSCell?) {
        entries.removeAll()
        for row in 0..<numberOfRows {
            for column in 0..<numberOfColumns {
                let title = prototype?.stringValue.isEmpty == false
                    ? "\(prototype?.stringValue ?? "") \(row + 1),\(column + 1)"
                    : "Cell \(row + 1),\(column + 1)"
                let cell = NSButtonCell(title: title)
                let button = NSButton(title: title, frame: NSZeroRect)
                entries.append(Entry(cell: cell, button: button))
                addSubview(button)
            }
        }
        syncButtonTypes()
        wireActions()
        layoutCells()
        refreshKeyViewLoop()
    }

    private func syncButtonTypes() {
        for entry in entries {
            switch mode {
            case .radioModeMatrix:
                entry.button.setButtonType(.radio)
            case .highlightModeMatrix, .listModeMatrix:
                entry.button.setButtonType(.switch)
            case .trackModeMatrix:
                entry.button.setButtonType(.momentaryPushIn)
            }
        }
    }

    private func wireActions() {
        for index in entries.indices {
            entries[index].button.winInternalAction = { [weak self] _ in
                guard let self else {
                    return
                }

                let row = index / max(1, self.numberOfColumns)
                let column = index % max(1, self.numberOfColumns)
                self.selectCell(atRow: row, column: column)
                self.sendAction()
            }
        }
    }

    private func layoutCells() {
        for row in 0..<numberOfRows {
            for column in 0..<numberOfColumns {
                guard let index = flatIndex(row: row, column: column) else {
                    continue
                }

                let x = CGFloat(column) * (cellSize.width + intercellSpacing.width)
                let y = CGFloat(row) * (cellSize.height + intercellSpacing.height)
                entries[index].button.frame = NSMakeRect(x, y, cellSize.width, cellSize.height)
            }
        }
    }

    private func flatIndex(row: Int, column: Int) -> Int? {
        guard row >= 0,
              column >= 0,
              row < numberOfRows,
              column < numberOfColumns else {
            return nil
        }

        return row * numberOfColumns + column
    }
}
