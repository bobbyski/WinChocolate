/// Framework-drawn (view-based) table rendering for `NSTableView`.
///
/// A native `SysListView32` can't host arbitrary per-cell views, so when the
/// delegate vends cell views the table realizes a plain custom-drawn peer: it
/// draws the header, grid, and selection itself, and hosts the delegate's cell
/// views as real child subviews positioned in a column/row grid. This is the
/// same custom-draw approach used for the level indicator and token chips,
/// scaled to a table. (First slice: no vertical scrolling yet — rows beyond
/// the frame are clipped; scrolling is a follow-up.)
/// The drawn table's per-presentation style tokens. The classic skin matches
/// the native `SysListView32` look (gray header slab, bold titles, visible
/// dividers); the modern skin matches themed Windows list views (flat header on
/// the body background, regular-weight titles, hairline rules). Everything the
/// drawn chrome paints routes through these tokens so the two presentations
/// stay complete alternatives rather than scattered branches.
struct WinDrawnTableStyle {
    let headerFill: NSColor
    let headerBaseline: NSColor
    let headerDivider: NSColor
    let headerTitleFont: NSFont
    let headerTitleColor: NSColor
    let sortArrowColor: NSColor
    let gridColor: NSColor
    let bodyFill: NSColor
    let alternatingRowFill: NSColor
    let cellTextColor: NSColor

    static var current: WinDrawnTableStyle {
        if NSApplication.shared.effectiveAppearance.winIsDark {
            return dark
        }
        return WinPresentation.selected == .modern ? modern : classic
    }

    static let classic = WinDrawnTableStyle(
        headerFill: NSColor(white: 0.93, alpha: 1),
        headerBaseline: NSColor(white: 0.75, alpha: 1),
        headerDivider: NSColor(white: 0.80, alpha: 1),
        headerTitleFont: NSFont.boldSystemFont(ofSize: 12),
        headerTitleColor: NSColor(white: 0.25, alpha: 1),
        sortArrowColor: NSColor(white: 0.4, alpha: 1),
        gridColor: NSColor(white: 0.85, alpha: 1),
        bodyFill: .white,
        alternatingRowFill: NSColor(white: 0.96, alpha: 1),
        cellTextColor: NSColor(white: 0.1, alpha: 1)
    )

    static let modern = WinDrawnTableStyle(
        headerFill: .white,
        headerBaseline: NSColor(white: 0.88, alpha: 1),
        headerDivider: NSColor(white: 0.92, alpha: 1),
        headerTitleFont: NSFont.systemFont(ofSize: 12),
        headerTitleColor: NSColor(white: 0.35, alpha: 1),
        sortArrowColor: NSColor(white: 0.45, alpha: 1),
        gridColor: NSColor(white: 0.92, alpha: 1),
        bodyFill: .white,
        alternatingRowFill: NSColor(white: 0.96, alpha: 1),
        cellTextColor: NSColor(white: 0.1, alpha: 1)
    )

    /// The dark skin (one skin serves both presentations; a dark *classic*
    /// look has no Windows precedent to imitate).
    static let dark = WinDrawnTableStyle(
        headerFill: NSColor(white: 0.16, alpha: 1),
        headerBaseline: NSColor(white: 0.30, alpha: 1),
        headerDivider: NSColor(white: 0.26, alpha: 1),
        headerTitleFont: NSFont.systemFont(ofSize: 12),
        headerTitleColor: NSColor(white: 0.80, alpha: 1),
        sortArrowColor: NSColor(white: 0.65, alpha: 1),
        gridColor: NSColor(white: 0.26, alpha: 1),
        bodyFill: NSColor(white: 0.14, alpha: 1),
        alternatingRowFill: NSColor(white: 0.17, alpha: 1),
        cellTextColor: NSColor(white: 0.88, alpha: 1)
    )
}

/// Commits the drawn table's in-place edit overlay when its field ends editing
/// (focus loss / Enter), then tears the overlay down.
public final class WinDrawnCellEditor: NSObject, NSTextFieldDelegate {
    weak var table: NSTableView?
    /// Performs the `controlTextDidEndEditing` operation.
    public func controlTextDidEndEditing(_ obj: Notification) {
        table?.winCommitDrawnEdit()
    }

    /// Intercepts the field editor's Tab/Backtab so editing commits and moves
    /// to the next/previous editable cell instead of letting Windows move focus
    /// off the field — AppKit's `control(_:textView:doCommandBy:)` contract.
    public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard let table else { return false }
        switch commandSelector {
        case "insertTab:":
            return table.winAdvanceDrawnEdit(reversed: false)
        case "insertBacktab:":
            return table.winAdvanceDrawnEdit(reversed: true)
        default:
            return false
        }
    }
}

/// The non-scrolling header strip for a framework-drawn table hosted in a
/// scroll view. It draws the table's column header and routes header clicks to
/// sorting, staying pinned while the body scrolls beneath it.
public final class WinDrawnHeaderStrip: NSView {
    weak var table: NSTableView?

    /// Draws the framework-rendered table cell contents.
    public override func draw(_ dirtyRect: NSRect) {
        table?.winDrawHeaderBar(width: frame.size.width)
    }

    /// Begins selection or editing for the pressed table cell.
    public override func mouseDown(with event: NSEvent) {
        guard let table else {
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        table.winHeaderMouseDown(atX: point.x)
    }

    /// Updates table interaction while the pointer is dragged.
    public override func mouseDragged(with event: NSEvent) {
        guard let table else {
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        table.winHeaderMouseDragged(toX: point.x)
    }

    /// Completes the active table-cell interaction.
    public override func mouseUp(with event: NSEvent) {
        guard let table else {
            return
        }
        let point = convert(event.locationInWindow, from: nil)
        table.winHeaderMouseUp(atX: point.x)
    }
}
