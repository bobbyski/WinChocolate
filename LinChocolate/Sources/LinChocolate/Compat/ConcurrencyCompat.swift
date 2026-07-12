import Foundation

/// Ferries a non-`Sendable` value from the main run loop's delivery closure into
/// the `@MainActor` block. Sound here because both ends run on the main thread;
/// the box just satisfies the strict-concurrency checker.
private struct UncheckedSendableBox<T>: @unchecked Sendable {
    let value: T
}

// The shared demo is single-threaded: every callback fires on the main run
// loop. Real Foundation's Timer/NotificationCenter blocks are `@Sendable`
// (WinFoundation's are not), so under Swift 6's main-actor top level the demo's
// blocks that touch UI globals wouldn't type-check. These @MainActor-block
// overloads bridge that gap — they hop through `MainActor.assumeIsolated`,
// which is sound because the underlying timer/notification is delivered on the
// main run loop. (Tracked with the other AppKit divergences for L15.3.)

public extension Timer {
    @MainActor
    @discardableResult
    static func scheduledTimer(
        withTimeInterval interval: TimeInterval,
        repeats: Bool,
        block: @escaping @MainActor (Timer) -> Void
    ) -> Timer {
        // Typed @Sendable so this call selects Foundation's overload, not this one.
        let bridged: @Sendable (Timer) -> Void = { timer in
            let box = UncheckedSendableBox(value: timer)
            MainActor.assumeIsolated { block(box.value) }
        }
        return scheduledTimer(withTimeInterval: interval, repeats: repeats, block: bridged)
    }
}

public extension NotificationCenter {
    @MainActor
    @discardableResult
    func addObserver(
        forName name: Notification.Name?,
        object obj: Any?,
        queue: OperationQueue?,
        using block: @escaping @MainActor (Notification) -> Void
    ) -> NSObjectProtocol {
        let bridged: @Sendable (Notification) -> Void = { note in
            let box = UncheckedSendableBox(value: note)
            MainActor.assumeIsolated { block(box.value) }
        }
        return addObserver(forName: name, object: obj, queue: queue, using: bridged)
    }
}
