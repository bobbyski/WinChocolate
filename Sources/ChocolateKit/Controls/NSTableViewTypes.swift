extension NSTableView {
    /// Grid-line drawing options.
    public struct GridLineStyle: OptionSet, Sendable {
        /// Raw option value.
        public let rawValue: UInt

        /// Creates grid-line options from a raw value.
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// Horizontal grid lines.
        public static let solidHorizontalGridLineMask = GridLineStyle(rawValue: 1 << 0)

        /// Vertical grid lines.
        public static let solidVerticalGridLineMask = GridLineStyle(rawValue: 1 << 1)
    }


    /// Where a drop lands relative to a row, matching AppKit's
    /// `NSTableView.DropOperation`: `.on` targets the row itself, `.above`
    /// inserts between rows (the row-reorder form).
    public enum DropOperation: Int, Sendable {
        case on = 0
        case above = 1
    }


    /// Selection highlight style.
    public enum SelectionHighlightStyle: Int, Sendable {
        /// No visible highlight.
        case none = -1

        /// Regular table selection highlight.
        case regular = 0

        /// Source-list style selection highlight.
        case sourceList = 1
    }


    /// Column autoresizing style.
    public enum ColumnAutoresizingStyle: Sendable {
        /// No automatic column resizing.
        case noColumnAutoresizing

        /// Uniformly resize columns.
        case uniformColumnAutoresizingStyle

        /// Resize the last column.
        case lastColumnOnlyAutoresizingStyle
    }
}
