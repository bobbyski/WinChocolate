import Foundation

// AppKit surface used by the shared demo that LinChocolate doesn't yet back
// with a native peer. These are compile-compatibility additions — real
// AppKit-shaped types/protocols so the same source builds against LinChocolate;
// behavior is filled in phase by phase. Grouped here so the gap is visible.

// MARK: - Events

/// AppKit-shaped input event (minimal). Enough for the demo's modifier-key and
/// pointer references; full event routing is a later parity item.
public final class NSEvent {
    public var modifierFlags: NSEventModifierFlags = []
    public var locationInWindow: NSPoint = .zero
    public var clickCount: Int = 1
    public var keyCode: UInt16 = 0
    public var characters: String?
    public var buttonNumber: Int = 0
    public var scrollingDeltaX: CGFloat = 0
    public var scrollingDeltaY: CGFloat = 0
    public var deltaX: CGFloat = 0
    public var deltaY: CGFloat = 0
    public var type: Int = 0
    public init() {}
}

// MARK: - Screen

/// AppKit-shaped screen (stub): one screen covering a default frame.
public final class NSScreen {
    public var frame: NSRect = NSMakeRect(0, 0, 1440, 900)
    public var visibleFrame: NSRect = NSMakeRect(0, 0, 1440, 860)
    nonisolated(unsafe) public static let main: NSScreen? = NSScreen()
    nonisolated(unsafe) public static let screens: [NSScreen] = [NSScreen()]
}

// MARK: - Text styling

/// AppKit-shaped underline style.
public struct NSUnderlineStyle: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let single = NSUnderlineStyle(rawValue: 0x01)
    public static let thick = NSUnderlineStyle(rawValue: 0x02)
    public static let double = NSUnderlineStyle(rawValue: 0x09)
    public static let patternDot = NSUnderlineStyle(rawValue: 0x0100)
}

// MARK: - Immediate-mode drawing helpers

/// Strokes a 1px frame around `rect` with the current stroke color.
public func NSFrameRect(_ rect: NSRect) {
    let path = NSBezierPath(rect: rect)
    path.lineWidth = 1
    path.stroke()
}

/// Strokes a frame of the given width around `rect`.
public func NSFrameRectWithWidth(_ rect: NSRect, _ frameWidth: CGFloat) {
    let path = NSBezierPath(rect: rect)
    path.lineWidth = frameWidth
    path.stroke()
}

/// Fills `rect` with the current fill color.
public func NSRectFill(_ rect: NSRect) {
    NSBezierPath(rect: rect).fill()
}

// MARK: - Delegate / marker protocols

// Empty protocols so the demo's classes can declare conformance and reference
// the types. The framework does not yet dispatch to these delegates (a later
// parity item); the demo's own methods still compile as ordinary members.
public protocol NSWindowDelegate: AnyObject {}
@MainActor
public protocol NSTableViewDelegate: AnyObject {
    /// Selection changed (framework posts after a native selection change).
    func tableViewSelectionDidChange(_ notification: Notification)
    /// View-based cells (accepted; the GTK table renders text natively today).
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView?
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat
}

public extension NSTableViewDelegate {
    @MainActor func tableViewSelectionDidChange(_ notification: Notification) {}
    @MainActor func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? { nil }
    @MainActor func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? { nil }
    @MainActor func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat { 24 }
}
public protocol NSTextFieldDelegate: AnyObject {}
public protocol NSSplitViewDelegate: AnyObject {}
public protocol NSMenuItemValidation: AnyObject {}
public protocol NSDraggingSource: AnyObject {}

// MARK: - Stub types (compile-compatibility; behavior is a later parity item)

/// AppKit-shaped cursor (stub).
public final class NSCursor {
    public init() {}
    nonisolated(unsafe) public static let arrow = NSCursor()
    nonisolated(unsafe) public static let pointingHand = NSCursor()
    nonisolated(unsafe) public static let crosshair = NSCursor()
    public func set() {}
}

/// AppKit-shaped tracking area (stub — holds its rect/options).
public final class NSTrackingArea {
    public struct Options: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let mouseEnteredAndExited = Options(rawValue: 1 << 0)
        public static let mouseMoved = Options(rawValue: 1 << 1)
        public static let activeInKeyWindow = Options(rawValue: 1 << 2)
        public static let activeAlways = Options(rawValue: 1 << 3)
        public static let inVisibleRect = Options(rawValue: 1 << 4)
    }
    public let rect: NSRect
    public let options: Options
    public init(rect: NSRect, options: Options, owner: Any?, userInfo: [AnyHashable: Any]? = nil) {
        self.rect = rect
        self.options = options
    }
}

/// AppKit-shaped drag session (stub).
public final class NSDraggingSession {
    public var animatesToStartingPositionsOnCancelOrFail = true
    public var draggingFormation: Int = 0
    /// WinChocolate's drop-result flag (accepted for parity).
    public var winDropped: Bool = false
}

/// AppKit-shaped dragging context (stub).
public enum NSDraggingContext { case outsideApplication, withinApplication }

/// Cell alignment within an `NSGridView` (AppKit's `NSGridCell.Placement`).
public enum NSGridCellPlacement: Sendable {
    case inherited, none, leading, top, trailing, bottom, center, fill
}
public enum NSGridRowAlignment: Sendable { case inherited, none, firstBaseline, lastBaseline }

/// A grid column (stub — holds the layout hints the demo sets).
public final class NSGridColumn {
    public var xPlacement: NSGridCellPlacement = .inherited
    public var width: CGFloat = -1   // -1 = automatic
    public var isHidden = false
    public var leadingPadding: CGFloat = 0
    public var trailingPadding: CGFloat = 0
}
/// A grid row (stub).
public final class NSGridRow {
    public var yPlacement: NSGridCellPlacement = .inherited
    public var rowAlignment: NSGridRowAlignment = .inherited
    public var height: CGFloat = -1
    public var isHidden = false
    public var topPadding: CGFloat = 0
    public var bottomPadding: CGFloat = 0
}
/// A single grid cell (stub).
public final class NSGridCell {
    public var xPlacement: NSGridCellPlacement = .inherited
    public var yPlacement: NSGridCellPlacement = .inherited
    public var rowAlignment: NSGridRowAlignment = .inherited
    public var contentView: NSView?
    public func mergeWithCells(inHorizontalRange range: NSRange) {}
}

/// A grid layout container. Accepts AppKit's rows-of-views initializer and
/// lays the cells out in rows/columns (column widths honor `NSGridColumn.width`
/// where set, else split the frame evenly; row heights split evenly).
public final class NSGridView: NSView {
    private var columns: [NSGridColumn] = []
    private var rows: [NSGridRow] = []
    private var cellViews: [[NSView]] = []

    public convenience init(views rowViews: [[NSView]]) {
        self.init(frame: NSMakeRect(0, 0, 200, 100))
        let columnCount = rowViews.map(\.count).max() ?? 0
        columns = (0..<columnCount).map { _ in NSGridColumn() }
        rows = rowViews.map { _ in NSGridRow() }
        cellViews = rowViews
        rowViews.flatMap { $0 }.forEach { addSubview($0) }
        layout()
    }
    public var rowSpacing: CGFloat = 6 { didSet { layout() } }
    public var columnSpacing: CGFloat = 6 { didSet { layout() } }

    /// Rows/columns share the frame; a column with an explicit `width` keeps it.
    public override func layout() {
        guard !cellViews.isEmpty, frame.width > 0, frame.height > 0 else { return }
        let rowCount = cellViews.count
        let columnCount = columns.count
        guard columnCount > 0 else { return }
        // Column widths: explicit widths hold; the rest share what remains.
        let explicit = columns.map { $0.width > 0 ? $0.width : -1 }
        let fixedTotal = explicit.filter { $0 > 0 }.reduce(0, +)
        let flexCount = explicit.filter { $0 < 0 }.count
        let gaps = columnSpacing * CGFloat(columnCount - 1)
        let flexShare = flexCount > 0
            ? max(0, (frame.width - gaps - fixedTotal) / CGFloat(flexCount)) : 0
        let widths = explicit.map { $0 > 0 ? $0 : flexShare }
        let rowGaps = rowSpacing * CGFloat(rowCount - 1)
        let rowHeight = max(0, (frame.height - rowGaps) / CGFloat(rowCount))
        var y: CGFloat = 0
        for row in cellViews {
            var x: CGFloat = 0
            for (c, view) in row.enumerated() {
                view.frame = NSMakeRect(x, y, widths[min(c, columnCount - 1)], rowHeight)
                x += widths[min(c, columnCount - 1)] + columnSpacing
            }
            y += rowHeight + rowSpacing
        }
    }
    public var numberOfColumns: Int { columns.count }
    public var numberOfRows: Int { rows.count }
    public func column(at index: Int) -> NSGridColumn {
        while columns.count <= index { columns.append(NSGridColumn()) }
        return columns[index]
    }
    public func row(at index: Int) -> NSGridRow {
        while rows.count <= index { rows.append(NSGridRow()) }
        return rows[index]
    }
    public func cell(atColumnIndex column: Int, rowIndex row: Int) -> NSGridCell { NSGridCell() }
    public func mergeCells(inHorizontalRange h: NSRange, verticalRange v: NSRange) {}
}

/// A stack layout container. Distributes its arranged subviews along the
/// orientation whenever the frame changes or views are added — an equal-share
/// layout (AppKit's `.fillEqually` shape, which is what the demo exercises).
public final class NSStackView: NSView {
    public var distribution: NSStackViewDistribution = .fill { didSet { layout() } }
    public var orientation: NSUserInterfaceLayoutOrientation = .horizontal { didSet { layout() } }
    public var alignment: NSTextAlignment = .center
    public var spacing: CGFloat = 8 { didSet { layout() } }
    public private(set) var arrangedSubviews: [NSView] = []
    public func addArrangedSubview(_ view: NSView) {
        arrangedSubviews.append(view)
        addSubview(view)
        layout()
    }
    public func removeArrangedSubview(_ view: NSView) {
        arrangedSubviews.removeAll { $0 === view }
        layout()
    }
    public func setViews(_ views: [NSView], in gravity: NSStackViewGravity) {
        views.forEach { addArrangedSubview($0) }
    }
    public convenience init(views: [NSView]) {
        self.init(frame: NSMakeRect(0, 0, 200, 40))
        views.forEach { addArrangedSubview($0) }
    }

    /// Equal-share distribution along the orientation, gaps of `spacing`.
    public override func layout() {
        let count = arrangedSubviews.count
        guard count > 0, frame.width > 0, frame.height > 0 else { return }
        let gaps = spacing * CGFloat(count - 1)
        if orientation == .horizontal {
            let share = max(0, (frame.width - gaps) / CGFloat(count))
            for (i, view) in arrangedSubviews.enumerated() {
                view.frame = NSMakeRect(CGFloat(i) * (share + spacing), 0, share, frame.height)
            }
        } else {
            let share = max(0, (frame.height - gaps) / CGFloat(count))
            for (i, view) in arrangedSubviews.enumerated() {
                view.frame = NSMakeRect(0, CGFloat(i) * (share + spacing), frame.width, share)
            }
        }
    }
}

/// One component (segment) of an `NSPathControl`'s path.
public final class NSPathComponentCell {
    public var title: String = ""
    public var url: URL?
    public init(title: String = "", url: URL? = nil) { self.title = title; self.url = url }
}

/// Column-navigation control placeholder (`NSBrowser` covers the real one).
public final class NSPathControl: NSView {
    public var url: URL?
    public var pathStyle: Int = 0
    /// The component the user clicked (Apple's method spelling). The GTK
    /// breadcrumb reports the last-clicked crumb through the backend.
    public func clickedPathComponentCell() -> NSPathComponentCell? {
        lastClickedComponentCell
    }

    var lastClickedComponentCell: NSPathComponentCell?

    /// The control's background fill (real AppKit API on NSPathControl).
    public var backgroundColor: NSColor? {
        didSet { backend.setBackgroundColor(backgroundColor, for: handle) }
    }
    public var pathComponentCells: [NSPathComponentCell] = []
    public var onAction: ((NSPathControl) -> Void)?
    public convenience init(url: URL?, frame: NSRect) {
        self.init(frame: frame)
        self.url = url
    }
}

/// A single dragged item (stub).
public final class NSDraggingItem {
    public init(pasteboardWriter: Any) {}
    public var draggingFrame: NSRect = .zero
}

/// Undo manager (stub — real undo is a later item).
public final class UndoManager {
    public init() {}
    public var canUndo: Bool { false }
    public var canRedo: Bool { false }
    public var undoMenuItemTitle: String { "Undo" }
    public var redoMenuItemTitle: String { "Redo" }
    public func undo() {}
    public func redo() {}
    public func removeAllActions() {}
    public func registerUndo(withTarget target: Any, handler: @escaping (Any) -> Void) {}
}

/// Document change-type (AppKit's `NSDocument.ChangeType`).
public enum NSDocumentChangeType: Int, Sendable {
    case changeDone, changeUndone, changeCleared, changeReadOtherContents, changeAutosaved, changeRedone
}

/// Image frame styles.
public enum NSImageFrameStyle: Sendable { case none, photo, grayBezel, groove, button }

/// A collection view item view controller (stub).
open class NSCollectionViewItem: NSViewController {
    public override convenience init() { self.init(view: NSView(frame: .zero)) }
    open var isSelected: Bool = false
    open var representedObject: Any?
    open var textField: NSTextField?
    open var imageView: NSImageView?
}

/// Collection-view layout stubs.
open class NSCollectionViewLayout { public init() {} }
open class NSCollectionViewFlowLayout: NSCollectionViewLayout {
    public enum ScrollDirection: Sendable { case vertical, horizontal }
    public var itemSize: NSSize = NSMakeSize(80, 80)
    public var minimumInteritemSpacing: CGFloat = 8
    public var minimumLineSpacing: CGFloat = 8
    public var scrollDirection: ScrollDirection = .vertical
    public var headerReferenceSize: NSSize = .zero
    public var footerReferenceSize: NSSize = .zero
    public var sectionInset = NSEdgeInsets()
}
public protocol NSCollectionViewDelegateFlowLayout: NSCollectionViewDelegate {}

/// A table row background view (stub).
open class NSTableRowView: NSView {
    open var isSelected: Bool = false

    /// The row's background fill (real AppKit API on this class).
    open var backgroundColor: NSColor? {
        didSet { backend.setBackgroundColor(backgroundColor, for: handle) }
    }
}

/// The shared color panel (stub — `NSColorWell` covers picking today).
public final class NSColorPanel {
    nonisolated(unsafe) public static let shared = NSColorPanel()
    public var color: NSColor = .white
    public var showsAlpha: Bool = false
    /// WinChocolate's color-change hook (accepted for parity).
    public var winColorDidChange: ((NSColor) -> Void)?
    public func orderFront(_ sender: Any?) {}
    public func makeKeyAndOrderFront(_ sender: Any?) {}
    public func setTarget(_ target: AnyObject?) {}
    public func setAction(_ action: Any?) {}
}

/// Font manager (stub).
public final class NSFontManager {
    nonisolated(unsafe) public static let shared = NSFontManager()
    public func convert(_ font: NSFont) -> NSFont { font }
    public var winFontDidChange: ((NSFont) -> Void)?
    public var target: AnyObject?
    public func orderFrontFontPanel(_ sender: Any?) {}
}

/// Window controller (stub).
open class NSWindowController {
    public var window: NSWindow?
    public init(window: NSWindow?) { self.window = window }
    public init() {}
    open func showWindow(_ sender: Any?) { window?.makeKeyAndOrderFront(sender) }
}

/// Document architecture stubs (real support is Phase L13).
open class NSDocument {
    public init() {}
    public var fileURL: URL?
    open func makeWindowControllers() {}
    open func addWindowController(_ windowController: NSWindowController) {}
    open func data(ofType typeName: String) throws -> Data { Data() }
    open func read(from data: Data, ofType typeName: String) throws {}
    open func updateChangeCount(_ change: NSDocumentChangeType) {}
    open func showWindows() {}
}
open class NSDocumentController {
    nonisolated(unsafe) public static let shared = NSDocumentController()
    public init() {}
    public var winDocumentClass: AnyObject.Type?
    public var documents: [NSDocument] = []
    open func newDocument(_ sender: Any?) {}
    open func openDocument(_ sender: Any?) {}

    /// The `NSDocument` subclass for `typeName` (subclasses override).
    open func documentClass(forType typeName: String) -> AnyClass? { nil }
}

/// Printing stub (real support is Phase L13).
public final class NSPrintOperation {
    nonisolated(unsafe) public static var current: NSPrintOperation?
    public init() {}

    /// Apple's initializer spelling; printing itself is Phase L13.
    public init(view: NSView) {}

    public static func printOperation(with view: NSView) -> NSPrintOperation { NSPrintOperation() }
    public var jobTitle: String = ""
    public var showsPrintPanel: Bool = true
    public func run() -> Bool { false }
}

/// AppKit-shaped `NSPanel` — an auxiliary window (utility/inspector). Subclass
/// of `NSWindow`; the floating/hide-on-deactivate hints are accepted for API
/// parity (native behavior is a later item).
open class NSPanel: NSWindow {
    public var isFloatingPanel = false
    public var hidesOnDeactivate = false
    public var becomesKeyOnlyIfNeeded = false
    public func orderFrontRegardless() { makeKeyAndOrderFront(nil) }
}

/// AppKit-shaped text storage (stub). Accepts the attribute-editing calls the
/// demo makes so rich-text styling round-trips through the source; native
/// attributed rendering is a later parity item.
public final class NSTextStorage {
    public var string: String
    public init(string: String = "") { self.string = string }
    public var length: Int { string.count }
    public func beginEditing() {}
    public func endEditing() {}
    public func addAttribute(_ name: NSAttributedString.Key, value: Any, range: NSRange) {}
    public func addAttributes(_ attrs: [NSAttributedString.Key: Any], range: NSRange) {}
    public func removeAttribute(_ name: NSAttributedString.Key, range: NSRange) {}
    public func setAttributes(_ attrs: [NSAttributedString.Key: Any]?, range: NSRange) {}
    public func replaceCharacters(in range: NSRange, with str: String) {}
}

/// Text finder stub.
public final class NSTextFinder {
    public enum Action: Int, Sendable {
        case showFindInterface, nextMatch, previousMatch, replaceAll, replace
        case replaceAndFind, setSearchString, replaceAllInSelection, selectAll
        case selectAllInSelection, hideFindInterface, showReplaceInterface, hideReplaceInterface
    }
    public init() {}
    public weak var client: AnyObject?
    public func performAction(_ op: NSTextFinder.Action) {}
}



// MARK: - Delegate protocols the shared demo conforms to

/// AppKit's text-view delegate (the slice the demo drives).
public protocol NSTextViewDelegate: AnyObject {
    func textDidChange(_ notification: Notification)
}

public extension NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {}
}

/// AppKit's alert delegate: the help-button hook.
public protocol NSAlertDelegate: AnyObject {
    func alertShowHelp(_ alert: NSAlert) -> Bool
}

public extension NSAlertDelegate {
    func alertShowHelp(_ alert: NSAlert) -> Bool { false }
}

/// AppKit's font-changing responder protocol (10.14+ shape): the font
/// manager's target receives `changeFont(_:)` when the panel's selection
/// changes.
public protocol NSFontChanging: AnyObject {
    func changeFont(_ sender: NSFontManager?)
}

public extension NSFontChanging {
    func changeFont(_ sender: NSFontManager?) {}
}

// MARK: - Font descriptors (Apple's NSFontDescriptor, reduced)

public final class NSFontDescriptor {

    /// Apple's trait mask (the two the demo styles with).
    public struct SymbolicTraits: OptionSet, Sendable {
        public let rawValue: UInt32
        public init(rawValue: UInt32) { self.rawValue = rawValue }
        public static let bold = SymbolicTraits(rawValue: 1 << 1)
        public static let italic = SymbolicTraits(rawValue: 1 << 0)
    }

    public let fontName: String
    public let pointSize: CGFloat
    public let symbolicTraits: SymbolicTraits

    public init(name: String, size: CGFloat) {
        self.fontName = name
        self.pointSize = size
        self.symbolicTraits = []
    }

    init(name: String, size: CGFloat, traits: SymbolicTraits) {
        self.fontName = name
        self.pointSize = size
        self.symbolicTraits = traits
    }

    /// A copy of the descriptor with `traits` applied.
    public func withSymbolicTraits(_ traits: SymbolicTraits) -> NSFontDescriptor {
        NSFontDescriptor(name: fontName, size: pointSize, traits: symbolicTraits.union(traits))
    }
}

public extension NSFont {
    /// The font's descriptor (name, size, and bold/italic traits).
    var fontDescriptor: NSFontDescriptor {
        var traits: NSFontDescriptor.SymbolicTraits = []
        if spec.bold { traits.insert(.bold) }
        if spec.italic { traits.insert(.italic) }
        return NSFontDescriptor(name: fontName, size: pointSize, traits: traits)
    }

    /// Builds a font from a descriptor (size 0 keeps the descriptor's size).
    convenience init?(descriptor: NSFontDescriptor, size: CGFloat) {
        self.init(name: descriptor.fontName,
                  size: size > 0 ? size : descriptor.pointSize,
                  weight: descriptor.symbolicTraits.contains(.bold) ? .bold : .regular,
                  italic: descriptor.symbolicTraits.contains(.italic))
    }
}

// MARK: - Image scaling/alignment (Apple's top-level enum names)

public enum NSImageScaling: Sendable {
    case scaleProportionallyDown, scaleAxesIndependently, scaleNone, scaleProportionallyUpOrDown
}

public enum NSImageAlignment: Sendable {
    case alignCenter, alignTop, alignTopLeft, alignTopRight, alignLeft
    case alignBottom, alignBottomLeft, alignBottomRight, alignRight
}
