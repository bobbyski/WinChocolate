import Foundation

/// AppKit-shaped application object. Owns the native backend and drives the
/// platform event loop. Applications normally use `NSApplication.shared`.
///
/// The default backend is the in-memory one so headless code and tests never
/// need a display; GUI apps assign a real backend explicitly, e.g.:
///
/// ```swift
/// NSApplication.shared.nativeBackend = GTKNativeControlBackend()
/// ```
///
/// (This mirrors WinChocolate, whose non-Windows default is likewise in-memory
/// and whose Windows default is the Win32 backend.)
public final class NSApplication {

    /// The shared application instance.
    ///
    /// `nonisolated(unsafe)`: LinChocolate is a main-thread UI framework (like
    /// AppKit), so this shared singleton is accessed from one thread. The
    /// annotation opts out of Swift 6's Sendable check for that contract;
    /// formal main-actor isolation is a later hardening item.
    nonisolated(unsafe) public static let shared = NSApplication()

    /// Backend used to create native controls and run the platform event loop.
    public var nativeBackend: NativeControlBackend

    /// Creates an application using the default (in-memory) backend.
    public convenience init() {
        self.init(nativeBackend: InMemoryNativeControlBackend())
    }

    /// Creates an application with an explicit native backend.
    public init(nativeBackend: NativeControlBackend) {
        self.nativeBackend = nativeBackend
    }

    /// Runs the platform event loop until the application terminates.
    public func run() {
        nativeBackend.runApplication()
    }

    /// Stops the event loop and terminates the application.
    public func terminate(_ sender: Any?) {
        nativeBackend.terminateApplication()
    }
}

/// The shared application, matching AppKit's global.
nonisolated(unsafe) public let NSApp = NSApplication.shared
