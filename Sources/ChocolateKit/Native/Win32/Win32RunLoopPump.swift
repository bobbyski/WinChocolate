#if os(Windows)
import WinFoundation

/// The Win32 half of the run loop: it lends `RunLoop.main` (in WinFoundation) a
/// message pump without WinFoundation ever naming Win32. `RunLoop` calls
/// `waitForEvents` each iteration; this blocks with `MsgWaitForMultipleObjects`
/// until the next timer's fire date or fresh input, then drains the queue with
/// `PeekMessage`/`TranslateMessage`/`DispatchMessage` — the same dispatch the
/// old bare `GetMessage` loop did, so window messages (including the
/// `SetTimer`-backed `WM_TIMER` that WinChocolate's own `Timer` still rides)
/// keep flowing.
final class Win32RunLoopPump: RunLoopPlatformPump {
    /// The UI thread, captured at construction so `wake()` can post to it.
    private let threadIdentifier: DWORD

    init() {
        threadIdentifier = winGetCurrentThreadId()
    }

    func waitForEvents(until limit: Date?) -> Bool {
        // Block until input arrives or the next timer is due. A nil limit means
        // no timer is pending, so wait indefinitely for input.
        let timeout = Win32RunLoopPump.timeoutMilliseconds(until: limit)
        _ = winMsgWaitForMultipleObjects(0, nil, 0, timeout, qsAllInput)

        // Drain every queued message. WM_QUIT ends the loop.
        var message = MSG()
        while winPeekMessageW(&message, nil, 0, 0, pmRemove) != 0 {
            if message.message == wmQuit {
                return false
            }
            withUnsafePointer(to: message) { pointer in
                _ = winTranslateMessage(pointer)
                _ = winDispatchMessageW(pointer)
            }
        }
        return true
    }

    func wake() {
        // Post a no-op message so a blocked wait returns and the loop can pick
        // up a just-added timer or `perform` block. Single-threaded today, but
        // correct if a background thread ever schedules onto the main loop.
        _ = winPostThreadMessageW(threadIdentifier, wmNull, 0, 0)
    }

    /// The `MsgWaitForMultipleObjects` timeout for a fire date: 0 if already
    /// due, `INFINITE` if none, else the whole milliseconds until then.
    private static func timeoutMilliseconds(until limit: Date?) -> DWORD {
        guard let limit else {
            return infiniteTimeout
        }
        let seconds = limit.timeIntervalSinceNow
        if seconds <= 0 {
            return 0
        }
        let milliseconds = (seconds * 1000).rounded(.up)
        // Clamp below INFINITE so a far-future date never means "wait forever".
        return DWORD(min(milliseconds, Double(infiniteTimeout - 1)))
    }
}
#endif
