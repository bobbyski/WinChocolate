import Foundation

/// One labelled row of an `NSForm`: a title on the left and an editable value
/// field on the right. `stringValue` proxies the field's text.
public final class NSFormCell {
    let titleLabel: NSTextField
    public let textField: NSTextField

    init(titleLabel: NSTextField, textField: NSTextField) {
        self.titleLabel = titleLabel
        self.textField = textField
    }

    /// The row's title text.
    public var title: String {
        get { titleLabel.stringValue }
        set { titleLabel.stringValue = newValue }
    }

    /// The row's editable value.
    public var stringValue: String {
        get { textField.stringValue }
        set { textField.stringValue = newValue }
    }

    /// Width of the title column for this row (Apple keeps title widths on the
    /// cells). Setting it re-lays the row's label and field.
    public var titleWidth: CGFloat {
        get { titleLabel.frame.width }
        set {
            let y = titleLabel.frame.origin.y
            let total = max(titleLabel.frame.width + 8 + textField.frame.width, newValue + 48)
            titleLabel.frame = NSMakeRect(0, y, newValue, 24)
            textField.frame = NSMakeRect(newValue + 8, textField.frame.origin.y,
                                         max(40, total - newValue - 8), 24)
        }
    }
}

/// AppKit-shaped `NSForm`: a vertical stack of labelled text-entry rows. No GTK
/// peer — it's a composed control (like `NSTokenField`/`NSSegmentedControl`),
/// built from `NSTextField` labels and fields laid out in this view's frame.
/// The legacy grid look is dropped in favor of plain native fields (Goal 2).
open class NSForm: NSControl {

    /// Width of the title column (pixels). Set before adding entries.
    public var titleWidth: Double = 80

    /// Height of each row, including the gap below it.
    public var rowHeight: Double = 30

    /// The size of each cell (AppKit's `NSForm.cellSize`, inherited from
    /// `NSMatrix`). The height is the row height; setting it re-lays the rows
    /// already added, so it works whether set before or after `addEntry`.
    public var cellSize: NSSize = NSMakeSize(0, 0) {
        didSet {
            if cellSize.height > 0 { rowHeight = cellSize.height }
            relayoutCells()
        }
    }

    /// Whether the rows' value fields draw the old-style bezel (AppKit's
    /// `NSCell.isBezeled`, set form-wide via the prototype cell).
    public func setBezeled(_ flag: Bool) {
        for cell in cells { cell.textField.isBezeled = flag }
    }

    /// Whether the rows' value fields draw a plain border (`NSCell.isBordered`).
    public func setBordered(_ flag: Bool) {
        for cell in cells { cell.textField.isBordered = flag }
    }

    /// Re-places every cell's label and field at the current `rowHeight`.
    private func relayoutCells() {
        for (index, cell) in cells.enumerated() {
            let y = CoordinateSpace.stackedRowY(index: index, rowHeight: rowHeight,
                                                contentHeight: 24,
                                                containerHeight: frame.height,
                                                isFlipped: isFlipped)
            cell.titleLabel.frame = NSMakeRect(0, y, titleWidth, 24)
            cell.textField.frame = NSMakeRect(titleWidth + 8, y,
                                              max(40, frame.width - titleWidth - 8), 24)
        }
    }

    /// The rows added so far, top to bottom.
    public private(set) var cells: [NSFormCell] = []

    /// Fired when a row's field is submitted (Enter) — AppKit's form action,
    /// carrying the form (read the edited value via `cell(at:)`).
    public var onAction: ((NSForm) -> Void)?

    /// Adds a labelled row and returns its cell. Rows stack from the top.
    @discardableResult
    public func addEntry(_ title: String) -> NSFormCell {
        let index = cells.count
        // Row 0 is topmost either way; `isFlipped` is this form's own answer.
        let y = CoordinateSpace.stackedRowY(index: index, rowHeight: rowHeight,
                                            contentHeight: 24,
                                            containerHeight: frame.height,
                                            isFlipped: isFlipped)
        let label = NSTextField(labelWithString: title,
                                frame: NSMakeRect(0, y, titleWidth, 24))
        let field = NSTextField(string: "",
                                frame: NSMakeRect(titleWidth + 8, y,
                                                  max(40, frame.width - titleWidth - 8), 24))
        field.isEditable = true   // form entries are editable input fields (framed)
        // Submitting any row fires the form's action (AppKit's NSForm behavior).
        field.onAction = { [weak self] _ in
            guard let self else { return }
            self.onAction?(self)
        }
        addSubview(label)
        addSubview(field)
        let cell = NSFormCell(titleLabel: label, textField: field)
        cells.append(cell)
        return cell
    }

    /// The row's cell (AppKit's `cell(at:)`).
    public func cell(at index: Int) -> NSFormCell? {
        cells.indices.contains(index) ? cells[index] : nil
    }

    /// The editable field for a row (AppKit's `cell(at:)`/`textField(at:)`).
    public func textField(at index: Int) -> NSTextField? {
        cells.indices.contains(index) ? cells[index].textField : nil
    }

    /// Sets a row's value.
    public func setStringValue(_ value: String, at index: Int) {
        guard cells.indices.contains(index) else { return }
        cells[index].stringValue = value
    }

    /// Reads a row's value.
    public func stringValue(at index: Int) -> String {
        cells.indices.contains(index) ? cells[index].stringValue : ""
    }
}
