/// A column description for `NSTableView`.
open class NSTableColumn: NSObject {
    /// Column resizing behavior flags.
    public struct ResizingOptions: OptionSet, Sendable {
        /// Raw option value.
        public let rawValue: UInt

        /// Creates resizing options from a raw value.
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// User resizing is allowed.
        public static let userResizingMask = ResizingOptions(rawValue: 1 << 0)

        /// Autoresizing is allowed.
        public static let autoresizingMask = ResizingOptions(rawValue: 1 << 1)
    }

    /// Stable column identifier.
    open var identifier: NSUserInterfaceItemIdentifier

    /// User-visible column title.
    open var title: String {
        get {
            headerCell.stringValue
        }
        set {
            headerCell.stringValue = newValue
        }
    }

    /// Preferred column width.
    open var width: CGFloat

    /// Minimum column width.
    open var minWidth: CGFloat

    /// Maximum column width.
    open var maxWidth: CGFloat

    /// Whether the column can be edited by table UI.
    open var isEditable: Bool

    /// Whether the column can be resized by table UI.
    open var resizingMask: ResizingOptions

    /// Header cell used to display the column title.
    open var headerCell: NSCell

    /// Data cell used by legacy cell-based table code.
    open var dataCell: NSCell?

    /// Sort descriptor used when a user clicks this column header.
    open var sortDescriptorPrototype: NSSortDescriptor?

    /// Creates a table column with an identifier.
    public init(identifier: NSUserInterfaceItemIdentifier) {
        self.identifier = identifier
        self.width = 100
        self.minWidth = 10
        self.maxWidth = 1_000
        self.isEditable = false
        self.resizingMask = [.userResizingMask, .autoresizingMask]
        self.headerCell = NSTextFieldCell(textCell: identifier.rawValue)
        self.dataCell = NSTextFieldCell()
        self.sortDescriptorPrototype = nil
        super.init()
    }

    /// Sets the data cell for this column.
    open func setDataCell(_ cell: NSCell?) {
        dataCell = cell
    }
}
