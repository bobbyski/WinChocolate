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
public protocol NSTableViewDelegate: AnyObject {}
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

/// A grid layout container (stub — real grid layout is a later parity item).
/// Accepts AppKit's rows-of-views initializer; children are added flat for now.
public final class NSGridView: NSView {
    private var columns: [NSGridColumn] = []
    private var rows: [NSGridRow] = []

    public convenience init(views rowViews: [[NSView]]) {
        self.init(frame: NSMakeRect(0, 0, 200, 100))
        let columnCount = rowViews.map(\.count).max() ?? 0
        columns = (0..<columnCount).map { _ in NSGridColumn() }
        rows = rowViews.map { _ in NSGridRow() }
        rowViews.flatMap { $0 }.forEach { addSubview($0) }
    }
    public var rowSpacing: CGFloat = 6
    public var columnSpacing: CGFloat = 6
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

/// A stack layout container (stub — accepts the layout hints; native layout
/// via the existing container is a later item).
public final class NSStackView: NSView {
    public var distribution: NSStackViewDistribution = .fill
    public var orientation: NSUserInterfaceLayoutOrientation = .horizontal
    public var alignment: NSTextAlignment = .center
    public var spacing: CGFloat = 8
    public private(set) var arrangedSubviews: [NSView] = []
    public func addArrangedSubview(_ view: NSView) { arrangedSubviews.append(view); addSubview(view) }
    public func removeArrangedSubview(_ view: NSView) { arrangedSubviews.removeAll { $0 === view } }
    public func setViews(_ views: [NSView], in gravity: NSStackViewGravity) {
        views.forEach { addArrangedSubview($0) }
    }
    public convenience init(views: [NSView]) {
        self.init(frame: NSMakeRect(0, 0, 200, 40))
        views.forEach { addArrangedSubview($0) }
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
    public var clickedPathComponentCell: NSPathComponentCell? { nil }
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
    public convenience init() { self.init(view: NSView(frame: .zero)) }
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
public protocol NSCollectionViewDelegateFlowLayout: AnyObject {}

/// A table row background view (stub).
open class NSTableRowView: NSView {
    open var isSelected: Bool = false
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
}

/// Printing stub (real support is Phase L13).
public final class NSPrintOperation {
    nonisolated(unsafe) public static var current: NSPrintOperation?
    public init() {}
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

