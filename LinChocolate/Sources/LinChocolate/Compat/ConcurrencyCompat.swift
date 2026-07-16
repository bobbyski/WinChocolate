import Foundation

/// Ferries a non-`Sendable` value from a native callback into the `@MainActor`
/// block. Sound here because both ends run on the main thread; the box just
/// satisfies the strict-concurrency checker.
private struct UncheckedSendableBox<T>: @unchecked Sendable {
    let value: T
}

/// LinChocolate's `Timer` — shadows Foundation's for clients that import both,
/// exactly as `NotificationCenter` does (and for the same reason: an extension
/// overload loses to Foundation's primary declaration, the documented
/// divergence). A full type shadow is the only way to intercept the demo's
/// `Timer.scheduledTimer` call, whose closure is `@Sendable`-inferred and so
/// always binds Foundation's overload.
///
/// **Why intercept at all:** Foundation's `Timer` schedules on `RunLoop.main`,
/// which nothing pumps under GTK's `g_main_loop_run` — and swift-corelibs's
/// `RunLoop` is broken for repeating timers anyway (verified on 6.0.3: a
/// repeating timer fires exactly once, then `RunLoop.run` blocks forever). So
/// the timer is driven off GTK's own loop through the backend (`g_timeout`).
///
/// The shared demo uses only `scheduledTimer(withTimeInterval:repeats:block:)`,
/// discarding the result; that is the whole surface implemented here.
@MainActor
public final class Timer {

    fileprivate init() {}

    /// Schedules a (repeating) timer on GTK's main loop. The block runs on the
    /// main thread; the demo hops it to the main actor via `Task { @MainActor }`,
    /// which the GLib main-actor executor hook then delivers.
    @discardableResult
    public static func scheduledTimer(
        withTimeInterval interval: TimeInterval,
        repeats: Bool,
        block: @escaping @MainActor (Timer) -> Void
    ) -> Timer {
        let timer = Timer()
        let box = UncheckedSendableBox(value: timer)
        NSApplication.shared.nativeBackend.scheduleTimer(interval: interval, repeats: repeats) {
            MainActor.assumeIsolated { block(box.value) }
        }
        return timer
    }
}
