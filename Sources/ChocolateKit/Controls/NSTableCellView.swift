/// View-based table cell container.
open class NSTableCellView: NSView {
    /// Generic object value represented by this cell view.
    open var objectValue: Any?

    /// Optional text field commonly used by AppKit table cell views.
    open var textField: NSTextField? {
        didSet {
            oldValue?.removeFromSuperview()
            guard let textField else {
                return
            }

            addSubview(textField)
        }
    }
}
