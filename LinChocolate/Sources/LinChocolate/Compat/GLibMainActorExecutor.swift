import Foundation
import CGTK
#if canImport(Glibc)
import Glibc
#endif

// Runs Swift concurrency's main-actor work under GTK's main loop.
//
// The demo updates its per-second timer label inside a `Task { @MainActor in … }`
// (real Foundation types the Timer block `@Sendable`, so it can't touch the UI
// globals directly). On Linux, those main-actor jobs land on **libdispatch's
// main queue** — and nothing drains that queue under `g_main_loop_run`, so the
// task never runs and the label sat at "Timer: 0s" forever.
//
// CFRunLoop drains the main queue by calling libdispatch's
// `_dispatch_main_queue_callback_4CF` — the exact hook Apple's platforms use to
// integrate the two. There is no run loop here, so we call it ourselves from a
// short GLib tick. The symbol is SPI, resolved at runtime via `dlsym`; if a
// future toolchain drops it, the timer simply stops ticking (nothing else
// breaks), which the install log surfaces.
//
// Note: the documented `swift_task_enqueueMainExecutor_hook` /
// `swift_task_enqueueGlobal_hook` override points were tried first and are NOT
// consulted for this path on swift 6.0.3/aarch64-linux — draining the dispatch
// main queue is what actually works.

private nonisolated(unsafe) let processHandle = dlopen(nil, RTLD_NOW)

private typealias DrainFn = @convention(c) (UnsafeMutableRawPointer?) -> Void
private nonisolated(unsafe) let dispatchMainDrain: DrainFn? =
    dlsym(processHandle, "_dispatch_main_queue_callback_4CF").map {
        unsafeBitCast($0, to: DrainFn.self)
    }

/// Starts draining libdispatch's main queue from GTK's loop, so
/// `Task { @MainActor }` runs. Idempotent; call once before running the loop.
func installGLibMainActorExecutor() {
    if ProcessInfo.processInfo.environment["LINCHOCOLATE_TIMER_DEBUG"] != nil {
        FileHandle.standardError.write(Data("main-queue drain available=\(dispatchMainDrain != nil)\n".utf8))
    }
    // ~60×/s: fast enough that a 1s timer's task is delivered promptly, cheap
    // when the queue is empty (a single callback that finds nothing to run).
    g_timeout_add(guint(16), { _ in
        dispatchMainDrain?(nil)
        return gboolean(1)   // G_SOURCE_CONTINUE
    }, nil)
}
