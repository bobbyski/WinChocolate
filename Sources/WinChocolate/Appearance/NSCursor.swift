/// A pointer image managed through AppKit's cursor stack.
///
/// WinChocolate cursors are identified by an internal name that the native
/// backend maps to the equivalent system cursor. `set()` replaces the cursor
/// on top of the stack while `push()`/`pop()` nest temporary cursors, matching
/// AppKit's stack semantics.
open class NSCursor: NSObject {
    /// The framework cursor name handed to the native backend.
    let cursorName: String

    nonisolated(unsafe) private static var stack: [NSCursor] = []

    /// The default arrow cursor.
    public static let arrow = NSCursor(named: "arrow")

    /// The text-insertion I-beam cursor.
    public static let iBeam = NSCursor(named: "iBeam")

    /// The crosshair cursor.
    public static let crosshair = NSCursor(named: "crosshair")

    /// The pointing-hand link cursor.
    public static let pointingHand = NSCursor(named: "pointingHand")

    /// The horizontal-resize cursor.
    public static let resizeLeftRight = NSCursor(named: "resizeLeftRight")

    /// The vertical-resize cursor.
    public static let resizeUpDown = NSCursor(named: "resizeUpDown")

    /// The cursor on top of the cursor stack.
    public static var current: NSCursor {
        stack.last ?? .arrow
    }

    /// Creates a cursor carrying a framework cursor name.
    init(named name: String) {
        cursorName = name
        super.init()
    }

    /// Makes this cursor current by replacing the top of the cursor stack.
    open func set() {
        if Self.stack.isEmpty {
            Self.stack.append(self)
        } else {
            Self.stack[Self.stack.count - 1] = self
        }
        Self.applyCurrentCursor()
    }

    /// Pushes this cursor onto the cursor stack and makes it current.
    open func push() {
        Self.stack.append(self)
        Self.applyCurrentCursor()
    }

    /// Pops the top cursor off the stack, restoring the previous cursor.
    open class func pop() {
        guard !stack.isEmpty else {
            return
        }

        stack.removeLast()
        applyCurrentCursor()
    }

    private static func applyCurrentCursor() {
        NSApplication.shared.nativeBackend.setCursor(named: current.cursorName)
    }
}

extension NSCursor: @unchecked Sendable {}
