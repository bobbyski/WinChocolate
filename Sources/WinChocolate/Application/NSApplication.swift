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

    /// The application-wide appearance override backing `appearance`
    /// (see NSAppearance.swift); `nil` follows the system theme.
    var winAppearanceOverride: NSAppearance?

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
                // The key window's view hierarchy sees Cmd-key events before
                // the main menu, matching AppKit's dispatch order.
                if self?.keyWindow?.performKeyEquivalent(with: event) == true {
                    return true
                }
                return self?.mainMenu?.performKeyEquivalent(with: event) ?? false
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

    /// Windows currently running modal sessions, outermost first.
    private var modalWindows: [NSWindow] = []

    /// Runs a modal event loop for a window until `stopModal` is called.
    @discardableResult
    public func runModal(for window: NSWindow) -> ModalResponse {
        let handle = window.realizeNativePeer()
        window.makeMain()
        window.makeKey()
        nativeBackend.showWindow(handle)
        modalWindows.append(window)
        defer {
            modalWindows.removeLast()
        }
        return ModalResponse(rawValue: nativeBackend.runModal(for: handle))
    }

    /// Ends the active modal session when its window is closing.
    ///
    /// Title-bar closes reach the window directly; without this, the nested
    /// modal loop would keep running with no window to dismiss it.
    internal func windowWillClose(_ window: NSWindow) {
        if modalWindows.last === window {
            stopModal(withCode: .cancel)
        }
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

    /// Shows the shared color panel.
    public func orderFrontColorPanel(_ sender: Any?) {
        NSColorPanel.shared.makeKeyAndOrderFront(sender)
    }

    /// The window whose responder chain receives panel actions.
    ///
    /// Floating panels send `changeFont(_:)`/`changeColor(_:)` while they are
    /// key, so the chain starts at the key window unless a panel is key, in
    /// which case the main window's chain receives the action.
    var panelActionWindow: NSWindow? {
        if let keyWindow, !(keyWindow is NSPanel) {
            return keyWindow
        }

        return mainWindow
    }

    private func notification(named name: String) -> NSNotification {
        NSNotification(name: name, object: self)
    }
}

extension NSApplication: @unchecked Sendable {}

/// AppKit-compatible global application alias.
public let NSApp = NSApplication.shared

/// Starts the application: wires the delegate (if given) and runs the shared
/// `NSApplication`'s lifecycle and native event loop. The AppKit-shaped entry
/// point for `@main` apps (a `SwiftUI`-style `App.main()` or an
/// `NSApplicationDelegate` `main()` can call this instead of hand-rolling
/// `NSApplication.shared` + `run()`). Returns 0 like AppKit's variant.
///
/// There is no `Info.plist` principal-class lookup here (Windows has no such
/// bundle), so the delegate is passed explicitly rather than read from the
/// bundle; a `nil` delegate runs the app with whatever delegate is already
/// set on `NSApplication.shared`.
@discardableResult
public func NSApplicationMain(delegate: NSApplicationDelegate? = nil) -> Int32 {
    let application = NSApplication.shared
    if let delegate {
        application.delegate = delegate
    }
    application.run()
    return 0
}
