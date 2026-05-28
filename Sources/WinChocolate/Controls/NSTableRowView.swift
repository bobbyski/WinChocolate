/// View used to represent an AppKit table row.
open class NSTableRowView: NSView {
    /// Whether the row is selected.
    open var isSelected: Bool = false

    /// Whether the row is emphasized as part of the active selection.
    open var isEmphasized: Bool = true

    /// Selection style requested for this row.
    open var selectionHighlightStyle: NSTableView.SelectionHighlightStyle = .regular

    /// Whether the row should draw a separator.
    open var shouldDrawSeparator: Bool = true
}
