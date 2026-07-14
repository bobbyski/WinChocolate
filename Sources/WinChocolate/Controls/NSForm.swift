/// A legacy AppKit form cell.
///
/// `NSFormCell` keeps the title/value shape used by old Cocoa forms. The visual
/// controls are owned by `NSForm` and mirror this cell's state.
open class NSFormCell: NSTextFieldCell {
    /// Label shown before the editable entry.
    open var title: String

    /// Width reserved for the title column.
    open var titleWidth: CGFloat = 96

    /// Creates a form cell with a title.
    public init(title: String) {
        self.title = title
        super.init(textCell: "")
        self.isEditable = true
        self.isSelectable = true
    }

    /// Creates an empty form cell.
    public override init() {
        self.title = ""
        super.init()
        self.isEditable = true
        self.isSelectable = true
    }

    /// Creates a form cell with value text.
    public override init(textCell string: String) {
        self.title = ""
        super.init(textCell: string)
        self.isEditable = true
        self.isSelectable = true
    }
}

/// A legacy row-oriented form control.
///
/// This first slice composes labels and editable text fields. It preserves the
/// common AppKit source shape for old Cocoa code while relying on existing
/// `NSTextField` peers for native Windows behavior.
open class NSForm: NSControl {
    private struct Row {
        var cell: NSFormCell
        var label: NSTextField
        var field: NSTextField
    }

    private var rows: [Row] = []

    /// Height of each form row.
    open var rowHeight: CGFloat = 30 {
        didSet {
            layoutRows()
        }
    }

    /// Width reserved for labels.
    open var titleWidth: CGFloat = 96 {
        didSet {
            for index in rows.indices {
                rows[index].cell.titleWidth = titleWidth
            }
            layoutRows()
        }
    }

    /// Number of entries in the form.
    open var numberOfRows: Int {
        rows.count
    }

    /// Creates a form with a frame.
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    /// Forms are containers; their editable child fields take focus.
    open override var acceptsFirstResponder: Bool {
        false
    }

    /// Adds an entry and returns its cell.
    @discardableResult
    open func addEntry(_ title: String) -> NSFormCell {
        insertEntry(title, at: rows.count)
    }

    /// Inserts an entry at an index and returns its cell.
    @discardableResult
    open func insertEntry(_ title: String, at index: Int) -> NSFormCell {
        let cell = NSFormCell(title: title)
        cell.titleWidth = titleWidth
        let label = NSTextField.label(withString: title)
        let field = NSTextField.textField(withString: cell.stringValue)
        field.winInternalTextChanged = { [weak cell] field in
            cell?.stringValue = field.stringValue
        }

        let row = Row(cell: cell, label: label, field: field)
        let clampedIndex = max(0, min(index, rows.count))
        rows.insert(row, at: clampedIndex)
        addSubview(label)
        addSubview(field)
        layoutRows()
        return cell
    }

    /// Removes the entry at an index.
    open func removeEntry(at index: Int) {
        guard rows.indices.contains(index) else {
            return
        }

        let row = rows.remove(at: index)
        row.label.removeFromSuperview()
        row.field.removeFromSuperview()
        layoutRows()
    }

    /// Returns the cell at a row.
    open func cell(at index: Int) -> NSFormCell? {
        guard rows.indices.contains(index) else {
            return nil
        }

        return rows[index].cell
    }

    /// Returns the row index for a cell, or `-1` when it is not in the form.
    open func index(of cell: NSFormCell) -> Int {
        rows.firstIndex { $0.cell === cell } ?? -1
    }

    /// Returns the editable text field for a row.
    open func textField(at index: Int) -> NSTextField? {
        guard rows.indices.contains(index) else {
            return nil
        }

        return rows[index].field
    }

    /// Updates an entry's label.
    open func setTitle(_ title: String, at index: Int) {
        guard rows.indices.contains(index) else {
            return
        }

        rows[index].cell.title = title
        rows[index].label.stringValue = title
    }

    /// Updates an entry's value.
    open func setStringValue(_ value: String, at index: Int) {
        guard rows.indices.contains(index) else {
            return
        }

        rows[index].cell.stringValue = value
        rows[index].field.stringValue = value
    }

    private func layoutRows() {
        for (index, row) in rows.enumerated() {
            let y = CGFloat(index) * rowHeight
            row.label.frame = NSMakeRect(0, y + 3, titleWidth, 24)
            row.field.frame = NSMakeRect(titleWidth + 8, y, max(0, frame.size.width - titleWidth - 8), 28)
        }
    }
}
