/// A Foundation-compatible run-loop timer.
///
/// This is WinFoundation's `Timer` — owned and fired by `RunLoop`, so packages
/// that sit above WinFoundation but below the UI layer (WinCombine) can build
/// `Timer.publish(every:on:in:)` on it without depending on WinChocolate.
///
/// WinChocolate ships its *own* `Timer` (backed directly by the Win32
/// `SetTimer`/`WM_TIMER` path) which apps see when they `import WinChocolate` —
/// the directly-imported module shadows this re-exported one, so the two
/// coexist without ambiguity. They are behaviourally equivalent: both fire
/// their block on the UI thread between event dispatches. Unifying WinChocolate's
/// onto this `RunLoop` timer is a future cleanup, not required for either to
/// work.
///
/// Unlike Apple's `Timer` this is not an `NSObject` subclass — `NSObject` lives
/// a layer up in WinChocolate, and nothing depends on the base class. The
/// scheduling surface matches Foundation's block form.
public final class Timer: @unchecked Sendable {
    /// The firing interval, in seconds.
    public let timeInterval: TimeInterval

    /// Whether the timer is scheduled and will fire.
    public private(set) var isValid = true

    /// The next instant this timer is due to fire (AppKit's `fireDate`).
    public internal(set) var nextFireDate: Date

    /// AppKit's spelling of `nextFireDate`.
    public var fireDate: Date {
        get { nextFireDate }
        set { nextFireDate = newValue }
    }

    /// Context Foundation callers sometimes read back; nil for block timers.
    public var userInfo: Any? { nil }

    let repeats: Bool
    private let block: (Timer) -> Void
    /// The loop that owns this timer, set when it is added.
    weak var runLoop: RunLoop?

    /// Creates an unscheduled timer. Add it to a loop with
    /// `RunLoop.add(_:forMode:)`.
    public init(timeInterval interval: TimeInterval, repeats: Bool, block: @escaping (Timer) -> Void) {
        self.timeInterval = max(0, interval)
        self.repeats = repeats
        self.block = block
        self.nextFireDate = Date(timeIntervalSinceNow: max(0, interval))
    }

    /// Creates a timer and schedules it on the current run loop in the default
    /// mode — Foundation's `scheduledTimer(withTimeInterval:repeats:block:)`.
    @discardableResult
    public static func scheduledTimer(withTimeInterval interval: TimeInterval, repeats: Bool, block: @escaping (Timer) -> Void) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: repeats, block: block)
        RunLoop.current.add(timer, forMode: .default)
        return timer
    }

    /// Fires the timer's block now. A non-repeating timer invalidates after
    /// firing, matching Foundation.
    public func fire() {
        guard isValid else { return }
        block(self)
        if !repeats {
            invalidate()
        }
    }

    /// Stops the timer; the owning loop drops it on its next pass.
    public func invalidate() {
        isValid = false
    }
}
