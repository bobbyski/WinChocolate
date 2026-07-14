/// Receives high-level application lifecycle callbacks.
///
/// The method names mirror AppKit delegate hooks so existing application
/// delegates can move toward WinChocolate incrementally.
public protocol NSApplicationDelegate: NSObjectProtocol {
    /// Called immediately before `NSApplication.run()` enters the native loop.
    func applicationWillFinishLaunching(_ notification: NSNotification)

    /// Called after launch preparation has completed.
    func applicationDidFinishLaunching(_ notification: NSNotification)

    /// Called immediately before termination is requested from the backend.
    func applicationWillTerminate(_ notification: NSNotification)
}

public extension NSApplicationDelegate {
    /// Default no-op launch preparation callback.
    func applicationWillFinishLaunching(_ notification: NSNotification) {}

    /// Default no-op launch completion callback.
    func applicationDidFinishLaunching(_ notification: NSNotification) {}

    /// Default no-op termination callback.
    func applicationWillTerminate(_ notification: NSNotification) {}
}
