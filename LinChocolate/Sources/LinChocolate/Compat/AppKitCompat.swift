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
    public init(rect: NSRect, options: Options, owner: Any?, userInfo: [AnyHashable: Any]?) {
        self.rect = rect
        self.options = options
    }
}

/// AppKit-shaped drag session (stub).
public final class NSDraggingSession {
    public var animatesToStartingPositionsOnCancelOrFail = true
    public var draggingFormation: Int = 0
}

/// AppKit-shaped dragging context (stub).
public enum NSDraggingContext { case outsideApplication, withinApplication }

/// A grid layout container (stub — real grid layout is a later parity item).
public final class NSGridView: NSView {}

/// A stack layout container (stub).
public final class NSStackView: NSView {}

/// Column-navigation control placeholder (`NSBrowser` covers the real one).
public final class NSPathControl: NSView {
    public var url: URL?
}

/// A collection view item view controller (stub).
open class NSCollectionViewItem: NSViewController {
    public convenience init() { self.init(view: NSView(frame: .zero)) }
    open var isSelected: Bool = false
}

/// Collection-view layout stubs.
open class NSCollectionViewLayout { public init() {} }
open class NSCollectionViewFlowLayout: NSCollectionViewLayout {
    public var itemSize: NSSize = NSMakeSize(80, 80)
    public var minimumInteritemSpacing: CGFloat = 8
    public var minimumLineSpacing: CGFloat = 8
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
    public func orderFront(_ sender: Any?) {}
    public func setTarget(_ target: AnyObject?) {}
}

/// Font manager (stub).
public final class NSFontManager {
    nonisolated(unsafe) public static let shared = NSFontManager()
    public func convert(_ font: NSFont) -> NSFont { font }
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
    open func makeWindowControllers() {}
    open func addWindowController(_ windowController: NSWindowController) {}
    open func data(ofType typeName: String) throws -> Data { Data() }
    open func read(from data: Data, ofType typeName: String) throws {}
}
open class NSDocumentController {
    nonisolated(unsafe) public static let shared = NSDocumentController()
    public init() {}
}

/// Printing stub (real support is Phase L13).
public final class NSPrintOperation {
    nonisolated(unsafe) public static var current: NSPrintOperation?
    public init() {}
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
    public func orderOut(_ sender: Any?) {}
}

/// Text finder stub.
public final class NSTextFinder {
    public init() {}
    public weak var client: AnyObject?
    public func performAction(_ op: Int) {}
}

