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
}

/// AppKit-shaped `NSForm`: a vertical stack of labelled text-entry rows. No GTK
/// peer — it's a composed control (like `NSTokenField`/`NSSegmentedControl`),
/// built from `NSTextField` labels and fields laid out in this view's frame.
/// The legacy grid look is dropped in favor of plain native fields (Goal 2).
public final class NSForm: NSView {

    /// Width of the title column (pixels). Set before adding entries.
    public var titleWidth: Double = 80

    /// Height of each row, including the gap below it.
    public var rowHeight: Double = 30

    /// The rows added so far, top to bottom.
    public private(set) var cells: [NSFormCell] = []

    /// Adds a labelled row and returns its cell. Rows stack from the top.
    @discardableResult
    public func addEntry(_ title: String) -> NSFormCell {
        let index = cells.count
        // AppKit bottom-left coordinates: the first row sits at the top.
        let y = frame.height - Double(index + 1) * rowHeight + (rowHeight - 24)
        let label = NSTextField(labelWithString: title,
                                frame: NSMakeRect(0, y, titleWidth, 24))
        let field = NSTextField(string: "",
                                frame: NSMakeRect(titleWidth + 8, y,
                                                  max(40, frame.width - titleWidth - 8), 24))
        addSubview(label)
        addSubview(field)
        let cell = NSFormCell(titleLabel: label, textField: field)
        cells.append(cell)
        return cell
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
