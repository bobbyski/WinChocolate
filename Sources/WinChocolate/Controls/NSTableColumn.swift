/// A column description for `NSTableView`.
open class NSTableColumn: NSObject {
    /// Stable column identifier.
    open var identifier: NSUserInterfaceItemIdentifier

    /// User-visible column title.
    open var title: String

    /// Preferred column width.
    open var width: CGFloat

    /// Minimum column width.
    open var minWidth: CGFloat

    /// Maximum column width.
    open var maxWidth: CGFloat

    /// Whether the column can be edited by table UI.
    open var isEditable: Bool

    /// Whether the column can be resized by table UI.
    open var resizingMask: UInt

    /// Creates a table column with an identifier.
    public init(identifier: NSUserInterfaceItemIdentifier) {
        self.identifier = identifier
        self.title = identifier.rawValue
        self.width = 100
        self.minWidth = 10
        self.maxWidth = 1_000
        self.isEditable = false
        self.resizingMask = 0
        super.init()
    }
}
