/// The singleton application object.
///
/// `NSApplication` coordinates process-level lifecycle, delegate callbacks, and
/// the native Windows event loop. Applications normally use `NSApplication.shared`.
public final class NSApplication: NSObject {
    /// Modal response values returned by dialogs.
    public struct ModalResponse: Equatable, Sendable {
        /// Raw response value.
        public let rawValue: Int

        /// Creates a modal response.
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        /// The dialog was accepted.
        public static let OK = ModalResponse(rawValue: 1)

        /// The dialog was cancelled.
        public static let cancel = ModalResponse(rawValue: 0)

        /// A modal session should stop.
        public static let stop = ModalResponse(rawValue: -1_000)

        /// A modal session was aborted.
        public static let abort = ModalResponse(rawValue: -1_001)

        /// A modal session should continue running.
        public static let `continue` = ModalResponse(rawValue: -1_002)

        /// The first alert button was chosen.
        public static let alertFirstButtonReturn = ModalResponse(rawValue: 1_000)

        /// The second alert button was chosen.
        public static let alertSecondButtonReturn = ModalResponse(rawValue: 1_001)

        /// The third alert button was chosen.
        public static let alertThirdButtonReturn = ModalResponse(rawValue: 1_002)
    }

    /// Shared application instance.
    public static let shared = NSApplication()

    /// The application delegate.
    public weak var delegate: NSApplicationDelegate?

    /// Backend used to create native windows and run the platform event loop.
    public var nativeBackend: NativeControlBackend

    /// Windows known to the application.
    public private(set) var windows: [NSWindow] = []

    /// The window currently receiving key events.
    public private(set) weak var keyWindow: NSWindow?

    /// The application's main document-style window.
    public private(set) weak var mainWindow: NSWindow?

    /// The application's main menu bar.
    public var mainMenu: NSMenu? {
        didSet {
            nativeBackend.installMainMenu(mainMenu)
            nativeBackend.registerKeyEquivalentHandler { [weak self] event in
                self?.mainMenu?.performKeyEquivalent(with: event) ?? false
            }
        }
    }

    /// Creates an application using the default backend for the current platform.
    public override convenience init() {
        #if os(Windows)
        self.init(nativeBackend: Win32NativeControlBackend())
        #else
        self.init(nativeBackend: InMemoryNativeControlBackend())
        #endif
    }

    /// Creates an application with an explicit native backend.
    public init(nativeBackend: NativeControlBackend) {
        self.nativeBackend = nativeBackend
        super.init()
    }

    /// Runs the application lifecycle and native event loop.
    public func run() {
        delegate?.applicationWillFinishLaunching(notification(named: "NSApplicationWillFinishLaunchingNotification"))
        delegate?.applicationDidFinishLaunching(notification(named: "NSApplicationDidFinishLaunchingNotification"))
        nativeBackend.runApplication()
    }

    /// Runs a modal event loop for a window until `stopModal` is called.
    @discardableResult
    public func runModal(for window: NSWindow) -> ModalResponse {
        let handle = window.realizeNativePeer()
        window.makeMain()
        window.makeKey()
        nativeBackend.showWindow(handle)
        return ModalResponse(rawValue: nativeBackend.runModal(for: handle))
    }

    /// Stops the current modal event loop with `.stop`.
    public func stopModal() {
        stopModal(withCode: .stop)
    }

    /// Stops the current modal event loop with a response code.
    public func stopModal(withCode code: ModalResponse) {
        nativeBackend.stopModal(withCode: code.rawValue)
    }

    /// Terminates the application.
    public func terminate(_ sender: Any?) {
        delegate?.applicationWillTerminate(notification(named: "NSApplicationWillTerminateNotification"))
        nativeBackend.terminateApplication()
    }

    /// Records that a window is owned by this application.
    public func addWindowsItem(_ window: NSWindow) {
        guard !windows.contains(where: { $0 === window }) else {
            return
        }

        windows.append(window)
    }

    /// Removes a window from the application window list.
    public func removeWindowsItem(_ window: NSWindow) {
        windows.removeAll { $0 === window }

        if keyWindow === window {
            keyWindow = nil
        }

        if mainWindow === window {
            mainWindow = nil
        }
    }

    /// Makes a window the key window.
    public func makeKeyWindow(_ window: NSWindow) {
        addWindowsItem(window)
        keyWindow = window
    }

    /// Makes a window the main window.
    public func makeMainWindow(_ window: NSWindow) {
        addWindowsItem(window)
        mainWindow = window
    }

    private func notification(named name: String) -> NSNotification {
        NSNotification(name: name, object: self)
    }
}

extension NSApplication: @unchecked Sendable {}

/// AppKit-compatible global application alias.
public let NSApp = NSApplication.shared
