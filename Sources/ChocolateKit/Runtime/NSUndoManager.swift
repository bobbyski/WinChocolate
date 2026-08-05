/// Records reversible operations and replays them for undo and redo.
///
/// This slice covers the target/handler registration form modern AppKit code
/// uses, single-action granularity, action names, and stack limits. Event
/// grouping and selector-based registration are future work. Registrations
/// made while undoing land on the redo stack and vice versa, so a handler
/// that registers its own inverse round-trips automatically.
open class NSUndoManager: NSObject {
    private final class RecordedAction {
        weak var target: AnyObject?
        let handler: (AnyObject) -> Void
        var name: String

        init(target: AnyObject, name: String, handler: @escaping (AnyObject) -> Void) {
            self.target = target
            self.name = name
            self.handler = handler
        }
    }

    private var undoStack: [RecordedAction] = []
    private var redoStack: [RecordedAction] = []
    private var pendingActionName = ""

    /// Whether an undo operation is currently executing.
    public private(set) var isUndoing = false

    /// Whether a redo operation is currently executing.
    public private(set) var isRedoing = false

    /// The maximum number of undo actions kept, or 0 for no limit.
    open var levelsOfUndo = 0

    /// Whether the undo stack has actions to perform.
    open var canUndo: Bool {
        !undoStack.isEmpty
    }

    /// Whether the redo stack has actions to perform.
    open var canRedo: Bool {
        !redoStack.isEmpty
    }

    /// Creates an empty undo manager.
    public override init() {
        super.init()
    }

    /// Registers a reversal handler invoked with the target on undo.
    ///
    /// The target is referenced weakly, matching Foundation: actions whose
    /// target is gone by the time they run are skipped.
    open func registerUndo<TargetType: AnyObject>(withTarget target: TargetType, handler: @escaping (TargetType) -> Void) {
        let action = RecordedAction(target: target, name: pendingActionName) { object in
            if let typed = object as? TargetType {
                handler(typed)
            }
        }

        if isUndoing {
            redoStack.append(action)
        } else {
            if !isRedoing {
                redoStack.removeAll()
            }
            undoStack.append(action)
            if levelsOfUndo > 0 && undoStack.count > levelsOfUndo {
                undoStack.removeFirst(undoStack.count - levelsOfUndo)
            }
        }
    }

    /// Performs the most recently registered undo action.
    open func undo() {
        guard let action = undoStack.popLast() else {
            return
        }

        pendingActionName = action.name
        isUndoing = true
        if let target = action.target {
            action.handler(target)
        }
        isUndoing = false
        pendingActionName = ""
    }

    /// Performs the most recently undone action again.
    open func redo() {
        guard let action = redoStack.popLast() else {
            return
        }

        pendingActionName = action.name
        isRedoing = true
        if let target = action.target {
            action.handler(target)
        }
        isRedoing = false
        pendingActionName = ""
    }

    /// Names the most recent registration for menu titles.
    open func setActionName(_ actionName: String) {
        if isUndoing {
            redoStack.last?.name = actionName
        } else {
            undoStack.last?.name = actionName
        }
    }

    /// The name of the action that `undo()` would perform.
    open var undoActionName: String {
        undoStack.last?.name ?? ""
    }

    /// The name of the action that `redo()` would perform.
    open var redoActionName: String {
        redoStack.last?.name ?? ""
    }

    /// The localized menu title for the pending undo action.
    open var undoMenuItemTitle: String {
        undoActionName.isEmpty ? "Undo" : "Undo \(undoActionName)"
    }

    /// The localized menu title for the pending redo action.
    open var redoMenuItemTitle: String {
        redoActionName.isEmpty ? "Redo" : "Redo \(redoActionName)"
    }

    /// Clears both stacks.
    open func removeAllActions() {
        undoStack.removeAll()
        redoStack.removeAll()
    }

    /// Clears all actions registered against a target.
    open func removeAllActions(withTarget target: AnyObject) {
        undoStack.removeAll { $0.target === target }
        redoStack.removeAll { $0.target === target }
    }
}
