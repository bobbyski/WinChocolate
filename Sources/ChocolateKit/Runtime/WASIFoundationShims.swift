// Conditional C1, the Foundation seam, third arm: WebAssembly.
//
// The seam has always had two answers — Windows takes WinFoundation because
// that toolchain has no Foundation at all, and Linux/macOS take the platform's.
// WASI is a third case that neither covers: Foundation *is* present, but it is
// the new swift-foundation, which carries the modern Observation-shaped
// `NotificationCenter` (`post(_:subject:)`) rather than AppKit's classic
// `post(name:object:)`, and declares `RunLoop` only to mark it unavailable.
//
// Rather than branch the 200-odd call sites above this line, the module
// declares the classic shapes here. Unqualified lookup prefers a type declared
// in the current module over an imported one, so every `NotificationCenter`,
// `Notification` and `RunLoop` inside ChocolateKit resolves to these on WASI
// and to the platform's everywhere else — which is exactly the property the
// rest of the seam already relies on.
//
// These are honest reimplementations of the slice the core uses, not stubs.
// The one genuine divergence is `RunLoop.run()`, which cannot exist in a
// browser: the page owns the event loop. See `WASMNativeControlBackend`.

#if os(WASI)

/// The slice of `UndoManager` an editor actually drives.
///
/// Foundation's is absent on WASI, and it is not a UI type — it is a stack of
/// closures with a grouping discipline, which is exactly what this is. Undo has
/// to work in a browser for a text editor to be worth shipping there, so this
/// is a real implementation rather than a placeholder.
public final class UndoManager {
    private var undoStack: [[() -> Void]] = []
    private var redoStack: [[() -> Void]] = []
    private var openGroup: [() -> Void]?
    private var isUndoing = false
    private var isRedoing = false

    /// Whether the manager registers new actions.
    public var isUndoRegistrationEnabled = true

    /// How many levels are kept, or 0 for no limit.
    public var levelsOfUndo = 0

    /// Creates an empty manager.
    public init() {}

    /// Whether there is anything to undo.
    public var canUndo: Bool { !undoStack.isEmpty }

    /// Whether there is anything to redo.
    public var canRedo: Bool { !redoStack.isEmpty }

    /// The name of the action `undo()` would perform, for the Edit menu.
    public private(set) var undoActionName: String = ""

    /// The name of the action `redo()` would perform.
    public private(set) var redoActionName: String = ""

    /// Names the action being registered, so the menu can read "Undo Rename".
    public func setActionName(_ name: String) {
        if isUndoing {
            redoActionName = name
        } else {
            undoActionName = name
        }
    }

    /// Registers an undo against a target the manager holds weakly.
    ///
    /// Foundation's shape, and the one callers use — a closure capturing the
    /// target directly would keep a view alive past its window.
    public func registerUndo<Target: AnyObject>(
        withTarget target: Target,
        handler: @escaping (Target) -> Void
    ) {
        registerUndo { [weak target] in
            guard let target else { return }
            handler(target)
        }
    }

    /// Registers a closure that reverses the change just made.
    ///
    /// Registering *during* an undo is how redo is built, which is why the
    /// destination depends on what is running — the same rule Foundation's has.
    public func registerUndo(_ body: @escaping () -> Void) {
        guard isUndoRegistrationEnabled else { return }
        if openGroup != nil {
            openGroup?.append(body)
        } else if isUndoing {
            redoStack.append([body])
        } else {
            undoStack.append([body])
            if !isRedoing { redoStack.removeAll() }
            trim()
        }
    }

    /// Begins a group; every registration until `endUndoGrouping` undoes together.
    public func beginUndoGrouping() {
        openGroup = []
    }

    /// Closes the open group.
    public func endUndoGrouping() {
        guard let group = openGroup else { return }
        openGroup = nil
        guard !group.isEmpty else { return }
        if isUndoing {
            redoStack.append(group)
        } else {
            undoStack.append(group)
            if !isRedoing { redoStack.removeAll() }
            trim()
        }
    }

    /// Undoes the most recent action or group.
    public func undo() {
        guard let group = undoStack.popLast() else { return }
        isUndoing = true
        // Reversed: the closures were registered in the order the changes
        // happened, and undoing them forwards would apply them backwards.
        for body in group.reversed() { body() }
        isUndoing = false
    }

    /// Redoes the most recently undone action or group.
    public func redo() {
        guard let group = redoStack.popLast() else { return }
        isRedoing = true
        for body in group.reversed() { body() }
        isRedoing = false
    }

    /// Discards everything.
    public func removeAllActions() {
        undoStack.removeAll()
        redoStack.removeAll()
        openGroup = nil
    }

    private func trim() {
        guard levelsOfUndo > 0, undoStack.count > levelsOfUndo else { return }
        undoStack.removeFirst(undoStack.count - levelsOfUndo)
    }
}

/// The slice of `Thread` that means anything on a single-threaded page.
///
/// WASI has no threads, so the answer is not "unknown" — it is *yes*, always:
/// there is one thread, everything runs on it, and it is the main one. Code
/// that asserts it is on the main thread is asking a question with a real
/// answer here, and this gives it rather than making the caller branch.
public enum Thread {
    /// Whether the current code is running on the main thread. Always true.
    public static var isMainThread: Bool { true }
}

/// A notification, matching the classic Foundation shape the core posts.
public struct Notification: Sendable {
    /// The name of a notification.
    public struct Name: Hashable, Sendable {
        /// The name's string value.
        public let rawValue: String

        /// Creates a name from its string value.
        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }
    }

    /// The notification's name.
    public let name: Name
    /// The object the notification concerns, if any.
    public nonisolated(unsafe) let object: Any?
    /// Values carried alongside the notification.
    public nonisolated(unsafe) let userInfo: [AnyHashable: Any]?

    /// Creates a notification.
    public init(name: Name, object: Any? = nil, userInfo: [AnyHashable: Any]? = nil) {
        self.name = name
        self.object = object
        self.userInfo = userInfo
    }
}

/// The classic notification dispatch centre.
///
/// Delivery is synchronous and on the caller's context, which is what the core
/// already assumes: a browser page is single-threaded, so every post arrives on
/// the one thread that could have sent it.
public final class NotificationCenter: @unchecked Sendable {
    /// The process-wide centre.
    public static let `default` = NotificationCenter()

    /// The token `addObserver(forName:object:queue:using:)` hands back.
    ///
    /// Held by the observer and passed to `removeObserver`, matching
    /// Foundation's opaque-token contract.
    private final class Observation: NSObjectProtocol {
        let name: Notification.Name?
        let object: AnyObject?
        let handler: (Notification) -> Void

        // Foundation's `addObserver` hands back an `NSObjectProtocol`, and
        // callers store it as one. Returning `Any` instead made every observer
        // property in a consumer fail to type-check, which is a parity break
        // rather than a shim detail.
        func isEqual(_ object: Any?) -> Bool { (object as AnyObject?) === self }
        var hash: Int { ObjectIdentifier(self).hashValue }
        var description: String { "NotificationObservation(\(name?.rawValue ?? "any"))" }

        init(name: Notification.Name?, object: AnyObject?,
             handler: @escaping (Notification) -> Void) {
            self.name = name
            self.object = object
            self.handler = handler
        }
    }

    private var observations: [ObjectIdentifier: Observation] = [:]

    /// Creates an independent centre.
    public init() {}

    /// Registers a block to run when a matching notification is posted.
    ///
    /// `queue` is accepted and ignored: WASI is single-threaded, so there is no
    /// other queue to hop to, and delivering synchronously is both the only
    /// option and the one the core's observers already expect.
    @discardableResult
    public func addObserver(forName name: Notification.Name?,
                            object: Any?,
                            queue: OperationQueue?,
                            using block: @escaping (Notification) -> Void) -> NSObjectProtocol {
        let observation = Observation(name: name, object: object as AnyObject?, handler: block)
        observations[ObjectIdentifier(observation)] = observation
        return observation
    }

    /// Stops delivering to a token returned by `addObserver`.
    public func removeObserver(_ observer: Any) {
        guard let observation = observer as? Observation else { return }
        observations.removeValue(forKey: ObjectIdentifier(observation))
    }

    /// Delivers a notification to every matching observer.
    public func post(name: Notification.Name, object: Any? = nil,
                     userInfo: [AnyHashable: Any]? = nil) {
        post(Notification(name: name, object: object, userInfo: userInfo))
    }

    /// Delivers a prepared notification to every matching observer.
    public func post(_ notification: Notification) {
        // Copied before delivering: an observer may add or remove observers.
        let matching = observations.values.filter { observation in
            if let name = observation.name, name != notification.name { return false }
            if let wanted = observation.object {
                guard let posted = notification.object as AnyObject?,
                      posted === wanted else { return false }
            }
            return true
        }
        for observation in matching {
            observation.handler(notification)
        }
    }
}

/// A queue reference, accepted by `addObserver` for source compatibility.
///
/// WASI has one thread and no run loop to schedule against, so this carries no
/// behaviour — it exists so the core's `queue: nil` arguments compile.
public final class OperationQueue: @unchecked Sendable {
    /// The queue tied to the main thread.
    public static let main = OperationQueue()

    /// Creates a queue.
    public init() {}
}

/// The classic run loop, present so the core compiles, and honest about the
/// fact that a browser page cannot have one.
///
/// A wasm page's event loop belongs to the host: JavaScript calls into the
/// module and the module returns. Nothing can block waiting for events without
/// freezing the tab. `WASMNativeControlBackend` therefore returns `nil` from
/// `makeRunLoopPump()` and implements `runApplication()` as mount-and-return,
/// which is the path `NSApplication.run()` takes when there is no pump — so
/// neither method below is reached in a correctly wired app.
public final class RunLoop: @unchecked Sendable {
    /// The main run loop.
    public static let main = RunLoop()

    /// Creates a run loop.
    public init() {}

    /// A run-loop mode, matching Foundation's shape.
    public struct Mode: Hashable, Sendable {
        /// The mode's string value.
        public let rawValue: String

        /// Creates a mode from its string value.
        public init(_ rawValue: String) {
            self.rawValue = rawValue
        }

        /// The mode a run loop is in when it has nothing special to do.
        public static let `default` = Mode("kCFRunLoopDefaultMode")
        /// The set of modes a source registered as common runs in.
        public static let common = Mode("kCFRunLoopCommonModes")
        /// The mode AppKit runs in while tracking a drag or a menu.
        public static let eventTracking = Mode("NSEventTrackingRunLoopMode")
        /// The mode AppKit runs in while a modal panel is up.
        public static let modalPanel = Mode("NSModalPanelRunLoopMode")
    }

    /// Would run the loop; a browser page cannot.
    ///
    /// Reaching here means something took the pump path on a platform that has
    /// no loop to pump. Say so rather than hanging or silently returning.
    public func run() {
        chocolateBackendWarn("RunLoop.run() has no meaning in a browser — the page owns the "
                             + "event loop. The backend should have returned nil from "
                             + "makeRunLoopPump() and implemented runApplication().")
    }

    /// Schedules a selector-shaped hop to a later turn of the event loop.
    ///
    /// Foundation's spelling takes a target and selector; nothing off Apple has
    /// an Objective-C runtime to send one with, so the block form is what the
    /// framework calls and what this provides. The deferral is real — the work
    /// lands on a later turn of the browser's loop, which is the whole reason
    /// callers reach for it.
    public func perform(_ work: @escaping @Sendable () -> Void) {
        Task { @MainActor in work() }
    }

    // `installPlatformPump` is deliberately absent: `FoundationBridge`'s
    // `extension RunLoop` supplies it for every non-WinFoundation build, and on
    // WASI that extension lands on this class. Its contract — a backend that
    // owns its own loop must not hand over a pump — is exactly right here.
}

#endif
