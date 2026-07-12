/// Coalesces `needsLayout` marks into one deferred layout pass.
///
/// AppKit defers layout to the end of the current runloop turn; WinChocolate
/// mirrors that by collecting the windows whose views were marked dirty and
/// flushing them from a single one-shot native timer, which the classic
/// backend fires on the UI thread between message dispatches. Marks made
/// during a flush (a `layout()` that resizes children, re-marking them)
/// simply arm the next flush; a pass that changes no frames ends the cycle.
final class NSLayoutPump: @unchecked Sendable {
    /// The application-wide pump.
    static let shared = NSLayoutPump()

    // Windows with dirty subtrees, deduplicated by identity, in mark order.
    private var dirtyWindows: [NSWindow] = []

    // The backend the pending flush timer was scheduled on, when armed.
    // Headless tests swap `NSApplication.shared.nativeBackend` per test, so a
    // timer armed on a previous backend can never fire there; comparing
    // identities re-arms the flush on the current backend instead of stalling.
    private weak var armedBackend: AnyObject?

    /// Registers a window whose content subtree needs layout and arms the
    /// coalesced flush.
    func scheduleLayout(for window: NSWindow) {
        if !dirtyWindows.contains(where: { $0 === window }) {
            dirtyWindows.append(window)
        }

        let backend = NSApplication.shared.nativeBackend
        guard armedBackend !== backend else {
            return
        }

        armedBackend = backend
        Timer.scheduledTimer(withTimeInterval: 0.001, repeats: false) { [weak self] _ in
            self?.flush()
        }
    }

    /// Lays out every dirty window's content subtree now.
    func flush() {
        armedBackend = nil
        let windows = dirtyWindows
        dirtyWindows.removeAll()
        for window in windows {
            window.contentView?.layoutSubtreeIfNeeded()
        }
    }
}
