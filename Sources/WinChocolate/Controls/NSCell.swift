/// Base cell object used by legacy AppKit controls.
///
/// WinChocolate keeps this small for now so table columns can expose familiar
/// `headerCell` and `dataCell` properties while newer view-based table work is
/// layered in later.
open class NSCell: NSObject {
    /// Generic cell value.
    open var objectValue: Any?

    /// String representation of the cell value.
    open var stringValue: String {
        get {
            objectValue.map { String(describing: $0) } ?? ""
        }
        set {
            objectValue = newValue
        }
    }

    /// Whether the cell can be edited.
    open var isEditable: Bool

    /// Whether the cell can be selected.
    open var isSelectable: Bool

    /// Whether the cell is enabled.
    open var isEnabled: Bool

    /// Creates an empty cell.
    public override init() {
        self.objectValue = nil
        self.isEditable = false
        self.isSelectable = false
        self.isEnabled = true
        super.init()
    }

    /// Creates a cell with text.
    public init(textCell string: String) {
        self.objectValue = string
        self.isEditable = false
        self.isSelectable = false
        self.isEnabled = true
        super.init()
    }
}

/// Text cell used by table columns.
open class NSTextFieldCell: NSCell {
    /// Creates a text cell.
    public override init() {
        super.init()
    }

    /// Creates a text cell with initial text.
    public override init(textCell string: String) {
        super.init(textCell: string)
    }
}
