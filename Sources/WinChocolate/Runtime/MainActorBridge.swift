/// Bridges the framework's nonisolated internals onto the main actor for
/// delegate and data-source dispatch.
///
/// WinChocolate's delegate protocols are `@MainActor` (matching AppKit's
/// Swift annotations), while the control classes themselves are nonisolated.
/// Every control callback runs on the Win32 UI thread — the main thread —
/// so re-entering the actor is always factually sound; the unsafe bindings
/// only carry non-Sendable values across the static isolation boundary.
func winMainActor<T>(_ body: @MainActor () -> T) -> T {
    nonisolated(unsafe) var result: T?
    nonisolated(unsafe) let body = body
    MainActor.assumeIsolated {
        result = body()
    }
    // assumeIsolated runs the body synchronously, so the box is always set.
    return result!
}
