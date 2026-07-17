import Foundation

/// LinChocolate's `NotificationCenter` — shadows Foundation's for clients that
/// import both, exactly as WinFoundation's does on Windows.
///
/// Why: real Foundation types the `addObserver(forName:…using:)` block
/// `@Sendable`, so the shared demo's main-actor observer bodies cannot
/// type-check against it under Swift 6 (extension overloads lose to
/// Foundation's primary declaration — the documented divergence). Everything
/// LinChocolate delivers arrives on the main run loop, so this center takes
/// `@MainActor` blocks and the framework posts through it on the main thread.
@MainActor
public final class NotificationCenter {

    /// One registered observer.
    final class Observer {
        let name: Notification.Name?
        let block: @MainActor (Notification) -> Void

        init(name: Notification.Name?, block: @escaping @MainActor (Notification) -> Void) {
            self.name = name
            self.block = block
        }
    }

    public static let `default` = NotificationCenter()

    private var observers: [Observer] = []

    /// Registers a main-actor observer block. `object` and `queue` are
    /// accepted for Apple's shape; delivery is always the main run loop.
    @discardableResult
    public func addObserver(forName name: Notification.Name?, object: Any?,
                            queue: OperationQueue?,
                            using block: @escaping @MainActor (Notification) -> Void) -> AnyObject {
        let observer = Observer(name: name, block: block)
        observers.append(observer)
        return observer
    }

    public func removeObserver(_ observer: Any) {
        observers.removeAll { $0 === observer as AnyObject }
    }

    /// Delivers `name` to every matching observer. Framework-internal posts
    /// happen on the main thread (GTK's main loop), matching the delivery
    /// contract the observers were registered under.
    public func post(name: Notification.Name, object: Any?) {
        let note = Notification(name: name, object: object)
        for observer in observers where observer.name == nil || observer.name == name {
            observer.block(note)
        }
    }
}
