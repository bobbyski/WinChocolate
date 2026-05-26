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

    /// The application's main menu bar.
    public var mainMenu: NSMenu? {
        didSet {
            nativeBackend.installMainMenu(mainMenu)
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

    /// Terminates the application.
    public func terminate(_ sender: Any?) {
        delegate?.applicationWillTerminate(notification(named: "NSApplicationWillTerminateNotification"))
        nativeBackend.terminateApplication()
    }

    private func notification(named name: String) -> NSNotification {
        NSNotification(name: name, object: self)
    }
}

extension NSApplication: @unchecked Sendable {}
