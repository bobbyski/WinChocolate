/// A legacy AppKit form cell.
///
/// `NSFormCell` keeps the title/value shape used by old Cocoa forms. The visual
/// controls are owned by `NSForm` and mirror this cell's state.
open class NSFormCell: NSTextFieldCell {
    /// Label shown before the editable entry.
    open var title: String

    /// Lets the owning form relayout when the title column width changes.
    var winInternalTitleWidthChanged: (() -> Void)?

    /// Lets the owning form mirror programmatic value changes into its
    /// composed field — on Apple the cell IS the entry, so assigning
    /// `stringValue` updates the display; the composed implementation keeps
    /// that contract here.
    var winInternalValueChanged: ((String) -> Void)?

    open override var stringValue: String {
        get {
            super.stringValue
        }
        set {
            super.stringValue = newValue
            winInternalValueChanged?(newValue)
        }
    }

    /// Width reserved for the title column (Apple's `NSFormCell` accessor).
    open var titleWidth: CGFloat = 96 {
        didSet {
            winInternalTitleWidthChanged?()
        }
    }

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

    /// Default width for new entries' title columns. Not API (18.7): Apple's
    /// `NSForm` has no form-level title width — each `NSFormCell.titleWidth`
    /// owns its own (which the layout reads) — `package` for the suite.
    package var titleWidth: CGFloat = 96 {
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
        field.winInternalTextChanged = { [weak self, weak cell] field in
            if let cell, cell.stringValue != field.stringValue {
                cell.stringValue = field.stringValue
            }
            // Apple's continuous controls send their action while editing.
            if let self, self.isContinuous {
                self.sendAction()
            }
        }
        cell.winInternalValueChanged = { [weak field] value in
            if let field, field.stringValue != value {
                field.stringValue = value
            }
        }
        cell.winInternalTitleWidthChanged = { [weak self] in
            self?.layoutRows()
        }

        let row = Row(cell: cell, label: label, field: field)
        let clampedIndex = max(0, min(index, rows.count))
        rows.insert(row, at: clampedIndex)
        addSubview(label)
        addSubview(field)
        layoutRows()
        refreshKeyViewLoop()
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
        refreshKeyViewLoop()
    }

    /// On Apple, Tab moves through the form's entries. The composed
    /// implementation gets the same behavior by interposing its fields into
    /// the key loop: the public `nextKeyView` keeps Apple's semantics (returns
    /// what was set), while the window's focus walk enters via the first
    /// field and leaves from the last.
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
        rows.first?.field ?? super.winEffectiveNextKeyView
    }

    override var winShouldDescendInKeyLoop: Bool {
        false
    }

    private func refreshKeyViewLoop() {
        for (index, row) in rows.enumerated() {
            row.field.nextKeyView = index + 1 < rows.count ? rows[index + 1].field : super.nextKeyView
        }
        rows.first?.field.winPreviousKeyView = self
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

    /// Returns the form cell for a row, matching Apple's `cell(atIndex:)`
    /// accessor shape (AppKit's deprecated `NSForm` is cell-based).
    open func cell(atIndex index: Int) -> NSFormCell? {
        guard rows.indices.contains(index) else {
            return nil
        }

        return rows[index].cell
    }

    /// Returns the editable text field for a row. Not API (18.7): AppKit's
    /// `NSForm` is cell-drawn and vends no field views — `package` for the
    /// composed implementation and the suite.
    package func textField(at index: Int) -> NSTextField? {
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
    package func setStringValue(_ value: String, at index: Int) {
        guard rows.indices.contains(index) else {
            return
        }

        rows[index].cell.stringValue = value
        rows[index].field.stringValue = value
    }

    private func layoutRows() {
        for (index, row) in rows.enumerated() {
            let y = CGFloat(index) * rowHeight
            let width = row.cell.titleWidth
            row.label.frame = NSMakeRect(0, y + 3, width, 24)
            row.field.frame = NSMakeRect(width + 8, y, max(0, frame.size.width - width - 8), 28)
        }
    }
}
