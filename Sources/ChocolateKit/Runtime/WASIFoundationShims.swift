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
    private final class Observation {
        let name: Notification.Name?
        let object: AnyObject?
        let handler: (Notification) -> Void

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
                            using block: @escaping (Notification) -> Void) -> Any {
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

    /// Would run the loop; a browser page cannot.
    ///
    /// Reaching here means something took the pump path on a platform that has
    /// no loop to pump. Say so rather than hanging or silently returning.
    public func run() {
        chocolateBackendWarn("RunLoop.run() has no meaning in a browser — the page owns the "
                             + "event loop. The backend should have returned nil from "
                             + "makeRunLoopPump() and implemented runApplication().")
    }

    // `installPlatformPump` is deliberately absent: `FoundationBridge`'s
    // `extension RunLoop` supplies it for every non-WinFoundation build, and on
    // WASI that extension lands on this class. Its contract — a backend that
    // owns its own loop must not hand over a pump — is exactly right here.
}

#endif
