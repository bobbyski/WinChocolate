/// A Foundation-compatible run loop.
///
/// On macOS `RunLoop.main` *is* the main thread's event loop, and
/// `NSApplication.run()` drives it. WinFoundation owns the loop itself — timers,
/// input sources, `run(mode:before:)` — in pure Swift, knowing nothing about
/// Win32. The platform's message pump is lent to it through
/// `RunLoopPlatformPump`, which WinChocolate installs at startup (see
/// `Docs/RunLoopDesign.md`). That keeps the dependency arrow pointing down:
/// WinChocolate depends on WinFoundation, never the reverse.
///
/// With no pump installed (a headless contract test), `run(mode:before:)` fires
/// the timers already due and returns rather than blocking; tests drive time
/// deterministically through `fireTimers(forMode:upTo:)`.
public final class RunLoop: @unchecked Sendable {

    /// A mode the loop can run in.
    public struct Mode: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(_ rawValue: String) { self.rawValue = rawValue }

        /// The default mode. Apple's raw value.
        public static let `default` = Mode(rawValue: "kCFRunLoopDefaultMode")
        /// The set of "common" modes; a source added here is serviced in every
        /// mode. Apple's raw value.
        public static let common = Mode(rawValue: "kCFRunLoopCommonModes")
    }

    /// The main thread's run loop.
    public static let main = RunLoop()

    /// The current thread's run loop. WinChocolate is single-threaded on the
    /// UI, so this is `main`; documented as such rather than faked per-thread.
    public static var current: RunLoop { main }

    /// Timers keyed by the mode they were added to.
    private var timersByMode: [String: [Timer]] = [:]
    /// Blocks queued by `perform(_:)`, run at the top of the next iteration.
    private var performQueue: [() -> Void] = []
    /// The platform pump, if one has been installed.
    private weak var platformPump: RunLoopPlatformPump?

    init() {}

    // MARK: - Platform seam

    /// Installs the platform message pump. WinChocolate calls this once at
    /// startup; on a platform with no pump the loop uses its headless path.
    public func installPlatformPump(_ pump: RunLoopPlatformPump) {
        platformPump = pump
    }

    // MARK: - Timers

    /// Adds a timer to the loop in a given mode (AppKit's
    /// `add(_:forMode:)`). A timer in `.common` fires in every mode.
    public func add(_ timer: Timer, forMode mode: Mode) {
        timer.runLoop = self
        timersByMode[mode.rawValue, default: []].append(timer)
        platformPump?.wake()
    }

    /// The earliest fire date among the valid timers serviced in `mode`
    /// (AppKit's `limitDate(forMode:)`), or nil if none.
    public func limitDate(forMode mode: Mode) -> Date? {
        timers(forMode: mode)
            .filter { $0.isValid }
            .map { $0.nextFireDate }
            .min()
    }

    /// The timers serviced when running in `mode`: that mode's own, plus the
    /// always-serviced `.common` timers.
    private func timers(forMode mode: Mode) -> [Timer] {
        var result = timersByMode[mode.rawValue] ?? []
        if mode != .common {
            result += timersByMode[Mode.common.rawValue] ?? []
        }
        return result
    }

    /// Fires every timer in `mode` whose fire date is at or before `now`,
    /// rescheduling repeaters and dropping spent one-shots and invalidated
    /// timers. Returns whether any timer fired.
    ///
    /// The pump-driven `run` calls this with `Date()`; tests pass an explicit
    /// date to advance time without real waiting.
    @discardableResult
    public func fireTimers(forMode mode: Mode, upTo now: Date) -> Bool {
        // Snapshot: a firing block may add or invalidate timers.
        let due = timers(forMode: mode).filter { $0.isValid && $0.nextFireDate <= now }
        for timer in due where timer.isValid {
            timer.fire()
            if timer.repeats, timer.isValid {
                // Advance to the next interval strictly after `now`, so a long
                // stall doesn't fire a burst of catch-up ticks.
                var next = timer.nextFireDate.addingTimeInterval(timer.timeInterval)
                if next <= now {
                    next = now.addingTimeInterval(timer.timeInterval)
                }
                timer.nextFireDate = next
            }
        }
        pruneInvalidTimers()
        return !due.isEmpty
    }

    private func pruneInvalidTimers() {
        for key in timersByMode.keys {
            timersByMode[key]?.removeAll { !$0.isValid }
        }
    }

    // MARK: - perform

    /// Enqueues a block to run at the start of the next loop iteration
    /// (AppKit's `perform(_:)`).
    public func perform(_ block: @escaping () -> Void) {
        performQueue.append(block)
        platformPump?.wake()
    }

    private func drainPerformQueue() -> Bool {
        guard !performQueue.isEmpty else { return false }
        let blocks = performQueue
        performQueue.removeAll()
        for block in blocks { block() }
        return true
    }

    // MARK: - Running

    /// Runs the loop in `mode` until `limit`, returning whether it processed
    /// any input. One iteration: drain `perform` blocks, fire due timers, then
    /// (with a pump) block until the next timer or `limit`.
    @discardableResult
    public func run(mode: Mode, before limit: Date) -> Bool {
        var didWork = false
        while true {
            if drainPerformQueue() { didWork = true }
            let now = Date()
            if fireTimers(forMode: mode, upTo: now) { didWork = true }
            if now >= limit { break }

            let nextTimer = limitDate(forMode: mode)
            // With a pending timer, cap the wait at its fire date; otherwise
            // wait for input up to `limit` (nil pump-timeout = indefinite).
            let wakeAt: Date? = nextTimer.map { min(limit, $0) } ?? (limit == .distantFuture ? nil : limit)
            guard let pump = platformPump else {
                // Headless: nothing will wake us. Fire what's due (done above)
                // and return — tests advance time via `fireTimers`.
                break
            }
            // A false return means the platform asked the loop to stop (WM_QUIT).
            if !pump.waitForEvents(until: wakeAt) { break }
        }
        return didWork
    }

    /// Runs the loop in the default mode until the platform stops it — what
    /// `NSApplication.run()` drives. With a pump this blocks until `WM_QUIT`;
    /// headless it returns immediately after firing due timers.
    public func run() {
        _ = run(mode: .default, before: .distantFuture)
    }
}

/// The platform message pump a `RunLoop` drives. WinFoundation defines the
/// protocol; WinChocolate provides a `MsgWaitForMultipleObjects`-based
/// conformance. This is the seam that lets the run loop pump native events
/// without WinFoundation depending on the Win32 layer.
public protocol RunLoopPlatformPump: AnyObject {
    /// Blocks until a native event arrives or `limit` passes (nil = no timer
    /// pending, wait indefinitely for input), servicing platform messages
    /// before returning. Returns `false` when the platform has asked the loop
    /// to stop (Windows `WM_QUIT`), so `run` can exit.
    func waitForEvents(until limit: Date?) -> Bool
    /// Wakes a blocked `waitForEvents` early — e.g. when a timer or `perform`
    /// block is added from elsewhere.
    func wake()
}
