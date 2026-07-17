/// View used to represent an AppKit table row.
///
/// In the framework-drawn (view-based) table a delegate can vend one of these
/// per row via `tableView(_:rowViewFor:)`; the table hosts it full-width behind
/// the row's cell views, so it paints the row background and selection band.
///
/// `backgroundColor` is the row's *base* fill (AppKit semantics). The view's
/// effective native fill is selection-aware: when `isSelected`, it shows the
/// selection color instead, matching `NSTableRowView`'s built-in highlight.
open class NSTableRowView: NSView {
    /// Whether the row is selected.
    open var isSelected: Bool = false {
        didSet {
            if isSelected != oldValue { pushFill() }
        }
    }

    /// Whether the row is emphasized as part of the active selection.
    open var isEmphasized: Bool = true {
        didSet {
            if isEmphasized != oldValue { pushFill() }
        }
    }

    /// Selection style requested for this row.
    open var selectionHighlightStyle: NSTableView.SelectionHighlightStyle = .regular {
        didSet {
            pushFill()
        }
    }

    /// Whether the row should draw a separator.
    open var shouldDrawSeparator: Bool = true

    /// The row's base (non-selected) background fill.
    private var baseBackgroundColor: NSColor?

    /// The row's background fill, matching AppKit's
    /// `NSTableRowView.backgroundColor` (this is one of the concrete types
    /// where Apple exposes a background color — plain `NSView` has none).
    /// Reads back the base color the caller set; the live native fill is
    /// selection-aware (see `effectiveFill`).
    open var backgroundColor: NSColor? {
        get {
            baseBackgroundColor
        }
        set {
            baseBackgroundColor = newValue
            pushFill()
        }
    }

    /// The fill actually painted: selection color when selected, else the base.
    private var effectiveFill: NSColor? {
        if isSelected, selectionHighlightStyle != .none {
            return isEmphasized ? .selectedTextBackgroundColor : .unemphasizedSelectedContentBackgroundColor
        }
        return baseBackgroundColor
    }

    /// Pushes the current effective fill to the native peer.
    private func pushFill() {
        guard let nativeHandle else {
            return
        }
        realizedBackend?.setBackgroundColor(effectiveFill, for: nativeHandle)
    }

    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        // `super` filled with the base color via the overridden getter; ensure
        // the selection-aware fill is applied once the peer exists.
        backend.setBackgroundColor(effectiveFill, for: handle)
        return handle
    }
}
