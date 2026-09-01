/// Receives high-level application lifecycle callbacks.
///
/// The method names mirror AppKit delegate hooks so existing application
/// delegates can move toward WinChocolate incrementally.
public protocol NSApplicationDelegate: NSObjectProtocol {
    /// Called immediately before `NSApplication.run()` enters the native loop.
    func applicationWillFinishLaunching(_ notification: Notification)

    /// Called after launch preparation has completed.
    func applicationDidFinishLaunching(_ notification: Notification)

    /// Called immediately before termination is requested from the backend.
    func applicationWillTerminate(_ notification: Notification)

    /// Asks whether the application may quit.
    ///
    /// Returning `.terminateCancel` stops the quit; `.terminateLater` defers it
    /// until the delegate calls
    /// `NSApplication.reply(toApplicationShouldTerminate:)`.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply

    /// Whether the application should quit once its last window closes.
    ///
    /// False by default, as AppKit's is — a document-based application outlives
    /// its windows.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool
}

/// Adds public behavior to `NSApplicationDelegate`.
public extension NSApplicationDelegate {
    /// Default no-op launch preparation callback.
    func applicationWillFinishLaunching(_ notification: Notification) {}

    /// Default no-op launch completion callback.
    func applicationDidFinishLaunching(_ notification: Notification) {}

    /// Default no-op termination callback.
    func applicationWillTerminate(_ notification: Notification) {}
}

public extension NSApplicationDelegate {
    /// Allows termination by default.
    ///
    /// A document-based application does not need to implement this: the
    /// document controller's unsaved-changes review runs inside
    /// `NSApplication.terminate(_:)` before the delegate is consulted, which is
    /// where AppKit puts it too.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        .terminateNow
    }

    /// Keeps the application running after its last window closes.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
