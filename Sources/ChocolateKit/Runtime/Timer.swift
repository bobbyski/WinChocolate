/// A run-loop timer driven by the native message loop.
///
/// This slice covers Foundation's block-based scheduling form, which is what
/// ported applications reach for most. Timers fire on the UI thread between
/// message dispatches (the classic backend rides `SetTimer`), so firing
/// blocks may touch views directly. Selector-based scheduling and manual
/// run-loop placement are future work.
open class Timer: NSObject {
    /// The timer's firing interval in seconds.
    public let timeInterval: TimeInterval

    /// Whether the timer is scheduled and will fire.
    public private(set) var isValid = true

    /// Custom context AppKit code sometimes reads back; always nil for
    /// block-scheduled timers, matching Foundation.
    open var userInfo: Any? {
        nil
    }

    private let repeats: Bool
    private let block: (Timer) -> Void
    private var nativeIdentifier: UInt?

    private init(interval: TimeInterval, repeats: Bool, block: @escaping (Timer) -> Void) {
        self.timeInterval = interval
        self.repeats = repeats
        self.block = block
        super.init()
    }

    /// Schedules a timer that calls a block on the UI thread.
    ///
    /// The native scheduling retains the timer until it is invalidated,
    /// matching Foundation's run-loop ownership, so callers may discard the
    /// returned reference.
    @discardableResult
    open class func scheduledTimer(withTimeInterval interval: TimeInterval, repeats: Bool, block: @escaping (Timer) -> Void) -> Timer {
        let timer = Timer(interval: interval, repeats: repeats, block: block)
        timer.nativeIdentifier = NSApplication.shared.nativeBackend.scheduleNativeTimer(
            intervalMilliseconds: Int(max(1, (interval * 1000).rounded()))
        ) {
            timer.fire()
        }
        return timer
    }

    /// Runs the timer's block immediately.
    ///
    /// Non-repeating timers invalidate after firing, like Foundation.
    open func fire() {
        guard isValid else {
            return
        }

        block(self)
        if !repeats {
            invalidate()
        }
    }

    /// Stops the timer and releases its native scheduling.
    open func invalidate() {
        guard isValid else {
            return
        }

        isValid = false
        if let nativeIdentifier {
            NSApplication.shared.nativeBackend.cancelNativeTimer(nativeIdentifier)
        }
        nativeIdentifier = nil
    }
}
