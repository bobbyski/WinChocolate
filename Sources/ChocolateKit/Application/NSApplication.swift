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

    /// Posted when the effective appearance changes because the user flipped the
    /// system dark/light theme while the app was running (the app follows the
    /// system — no `appearance` override). Application code that caches
    /// appearance-derived values can observe this to refresh. The framework's
    /// own windows and controls are already re-themed and repainted by the time
    /// this posts.
    public static let winEffectiveAppearanceDidChangeNotification =
        Notification.Name("WinChocolateEffectiveAppearanceDidChange")

    /// Posts `winEffectiveAppearanceDidChangeNotification` (called by the Win32
    /// backend after it refreshes windows for a live system theme switch).
    public func winPostEffectiveAppearanceDidChange() {
        // AppKit-faithful hook first: every view learns its effective appearance
        // changed via `viewDidChangeEffectiveAppearance()`. App code overrides
        // that (as on macOS) rather than observing a Windows-only notification.
        // This always runs on the UI (main) thread — the theme-change message
        // arrives there — so the main-actor fan-out is a statement of fact.
        MainActor.assumeIsolated {
            for window in windows {
                window.contentView?.winPropagateEffectiveAppearanceChange()
            }
        }
        NotificationCenter.default.post(
            name: NSApplication.winEffectiveAppearanceDidChangeNotification,
            object: self
        )
    }

    /// Whether a `.terminateLater` quit is waiting on the delegate's answer.
    internal var winDeferredTerminationPending = false

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

    /// The menu the application keeps its window list in.
    ///
    /// AppKit adds and removes entries here as windows come and go. The
    /// Chocolate backends do not manage the list themselves, so what this
    /// property buys is the same *place* to put it: an app that hands AppKit
    /// its Window menu hands this one the same menu, and the items it puts
    /// there show up in the menu bar unchanged.
    public var windowsMenu: NSMenu?

    /// The menu the application keeps its help entries in.
    public var helpMenu: NSMenu?

    /// The menu the application keeps its services entries in.
    ///
    /// There is no services architecture off Apple, so nothing is inserted
    /// here automatically — the menu shows exactly the items the app puts in
    /// it, rather than disappearing.
    public var servicesMenu: NSMenu?

    /// Creates an application using the default backend for the current platform.
    public override convenience init() {
        self.init(nativeBackend: NSApplication.makeDefaultNativeBackend())
    }

    /// Builds the backend this process should run on.
    ///
    /// Conditional C3 of the sanctioned platform switches: which native backend
    /// fronts the shared core. `canImport(CGTK)` is the same guard the GTK
    /// backend's own files carry, so the branch is live exactly where that
    /// backend compiles. Without the GTK arm, a Linux app fell through to the
    /// *headless test* backend and launched with no GUI at all — the framework
    /// was there, nothing selected it. That is also why every new backend gets
    /// its arm *before* the final `#else`, never after.
    ///
    /// A terminal exists on every desktop OS, so the platform cannot say
    /// whether the user wanted a GUI or a cell grid; `CHOCOLATE_BACKEND` (see
    /// `chocolateBackendRequest()`) answers that, and answering nothing leaves
    /// the platform default untouched.
    static func makeDefaultNativeBackend() -> NativeControlBackend {
        if let requested = chocolateBackendRequest(),
           let backend = makeRequestedNativeBackend(requested) {
            return backend
        }
        #if os(WASI)
        return WASMNativeControlBackend()
        #elseif os(Windows)
        return Win32NativeControlBackend()
        #elseif canImport(CGTK)
        return GTKNativeControlBackend()
        #else
        return InMemoryNativeControlBackend()
        #endif
    }

    /// Builds an explicitly requested backend, or `nil` when this build does not
    /// contain it — in which case the caller falls back to the platform default
    /// rather than dying, and says so.
    private static func makeRequestedNativeBackend(
        _ request: ChocolateBackendRequest
    ) -> NativeControlBackend? {
        switch request {
        case .inmemory:
            return InMemoryNativeControlBackend()
        case .tui:
            #if canImport(TUIKit)
            return TUINativeControlBackend()
            #else
            chocolateBackendWarn("the terminal backend is not compiled into this build; "
                                 + "using the platform default.")
            return nil
            #endif
        case .wasm:
            #if os(WASI)
            return WASMNativeControlBackend()
            #else
            chocolateBackendWarn("the browser backend only exists in a WebAssembly build; "
                                 + "using the platform default.")
            return nil
            #endif
        case .win32:
            #if os(Windows)
            return Win32NativeControlBackend()
            #else
            chocolateBackendWarn("the Win32 backend only exists on Windows; "
                                 + "using the platform default.")
            return nil
            #endif
        case .gtk:
            #if canImport(CGTK)
            return GTKNativeControlBackend()
            #else
            chocolateBackendWarn("the GTK backend is not compiled into this build; "
                                 + "using the platform default.")
            return nil
            #endif
        }
    }

    /// Creates an application with an explicit native backend.
    public init(nativeBackend: NativeControlBackend) {
        self.nativeBackend = nativeBackend
        super.init()
    }

    /// Runs the application lifecycle and native event loop.
    ///
    /// When the backend provides a run-loop pump, the app is driven by
    /// `RunLoop.main.run()` — window messages and Foundation timers share one
    /// loop, as on AppKit. A backend without a pump (the in-memory test
    /// backend) falls back to the bare message loop.
    public func run() {
        delegate?.applicationWillFinishLaunching(notification(named: "NSApplicationWillFinishLaunchingNotification"))
        delegate?.applicationDidFinishLaunching(notification(named: "NSApplicationDidFinishLaunchingNotification"))
        if let pump = nativeBackend.makeRunLoopPump() {
            RunLoop.main.installPlatformPump(pump)
            RunLoop.main.run()
        } else {
            nativeBackend.runApplication()
        }
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
            stoppingModalWindows.remove(ObjectIdentifier(window))
        }
        return ModalResponse(rawValue: nativeBackend.runModal(for: handle))
    }

    /// Windows whose modal session has already been asked to stop, so the two
    /// close routes (`close()` and the backend's destroy callback) cannot stop
    /// the same session twice — the second stop would land on the *enclosing*
    /// session once this one has unwound.
    private var stoppingModalWindows: Set<ObjectIdentifier> = []

    /// Ends the active modal session when its window is closing.
    ///
    /// Both close routes call this: `close()` for a programmatic close, and the
    /// backend's destroy callback for a title-bar close. It matters that the
    /// *core* does this rather than the backend: the Win32 modal loop happens to
    /// also guard on `IsWindow`, so it unwinds on its own, but GTK's does not —
    /// which is where this bug was first seen. Ending the session here makes the
    /// behaviour the same on every backend instead of a Win32 accident.
    internal func windowWillClose(_ window: NSWindow) {
        guard modalWindows.last === window else {
            return
        }

        let identifier = ObjectIdentifier(window)
        guard stoppingModalWindows.insert(identifier).inserted else {
            return
        }
        stopModal(withCode: .cancel)
    }

    /// Stops the current modal event loop with `.stop`.
    public func stopModal() {
        stopModal(withCode: .stop)
    }

    /// Stops the current modal event loop with a response code.
    public func stopModal(withCode code: ModalResponse) {
        nativeBackend.stopModal(withCode: code.rawValue)
    }

    /// How a delegate answers `applicationShouldTerminate(_:)`.
    public enum TerminateReply: UInt, Sendable {
        /// Stop the quit; the application keeps running.
        case terminateCancel = 0

        /// Quit now.
        case terminateNow = 1

        /// Quit once the delegate calls
        /// `reply(toApplicationShouldTerminate:)`.
        case terminateLater = 2
    }

    /// Whether a deferred termination is waiting on the delegate's answer.
    private var winIsAwaitingTerminateReply: Bool {
        get { winDeferredTerminationPending }
        set { winDeferredTerminationPending = newValue }
    }

    /// Answers a `.terminateLater` reply, completing or abandoning the quit.
    public func reply(toApplicationShouldTerminate shouldTerminate: Bool) {
        guard winIsAwaitingTerminateReply else {
            return
        }
        winIsAwaitingTerminateReply = false
        guard shouldTerminate else {
            return
        }
        winPerformTermination()
    }

    /// Terminates the application.
    ///
    /// The order matters and is AppKit's: **unsaved documents are reviewed
    /// first**, then the delegate is asked, and only then does anything shut
    /// down. Reviewing after the delegate said yes would mean a Cancel in the
    /// save prompt could not stop a quit that was already under way.
    public func terminate(_ sender: Any?) {
        // A document-based application gets its save prompts here, without
        // having to implement `applicationShouldTerminate(_:)` at all.
        if let controller = NSDocumentController.winSharedIfCreated, controller.hasEditedDocuments {
            var reviewedAll = false
            let recorder = WinTerminateReviewRecorder { reviewedAll = $0 }
            controller.reviewUnsavedDocuments(
                withAlertTitle: nil,
                cancellable: true,
                delegate: recorder,
                didReviewAll: Selector("documentController:didReviewAll:contextInfo:"),
                contextInfo: nil)
            guard reviewedAll else {
                return
            }
        }

        switch delegate?.applicationShouldTerminate(self) ?? .terminateNow {
        case .terminateCancel:
            return
        case .terminateLater:
            winIsAwaitingTerminateReply = true
            return
        case .terminateNow:
            break
        }

        winPerformTermination()
    }

    /// Tears the application down, once everything has agreed to it.
    private func winPerformTermination() {
        delegate?.applicationWillTerminate(notification(named: "NSApplicationWillTerminateNotification"))
        // The delegate and the notification are the same event told twice,
        // because AppKit tells it twice. Anything that is not the delegate —
        // a preferences store flushing its last write — has only the second.
        NotificationCenter.default.post(name: NSApplication.willTerminateNotification, object: self)
        nativeBackend.terminateApplication()
    }

    // MARK: Action dispatch (Phase 18.1)

    /// Sends an action to a target, matching AppKit's
    /// `sendAction(_:to:from:)`. With an explicit target the action is
    /// performed on it directly (when it responds). With a `nil` target the
    /// action walks AppKit's nil-target chain: the key window's first
    /// responder up its responder chain, then the key window, then the main
    /// window's chain when that is a different window, then the application
    /// itself, and finally the application delegate.
    @discardableResult
    public func sendAction(_ action: Selector, to target: Any?, from sender: Any?) -> Bool {
        if let target {
            guard let object = target as? NSObject else {
                return false
            }

            if let responder = object as? NSResponder {
                // Explicit responder targets still get chain semantics for
                // actions they don't handle themselves, as AppKit does.
                return responder.tryToPerform(action, with: sender)
            }

            guard object.responds(to: action) else {
                return false
            }

            object.perform(action, with: sender)
            return true
        }

        // Nil target: the standard responder chain.
        if let keyWindow {
            let start = keyWindow.firstResponder ?? keyWindow
            if start.tryToPerform(action, with: sender) {
                return true
            }
        }

        if let mainWindow, mainWindow !== keyWindow {
            let start = mainWindow.firstResponder ?? mainWindow
            if start.tryToPerform(action, with: sender) {
                return true
            }
        }

        if responds(to: action) {
            perform(action, with: sender)
            return true
        }

        if let delegateObject = delegate as? NSObject, delegateObject.responds(to: action) {
            delegateObject.perform(action, with: sender)
            return true
        }

        // Last link, as in AppKit: the shared document controller, which is
        // what makes a File menu's `newDocument:` and `openDocument:` work
        // without the application wiring a target to them.
        if let controller = NSDocumentController.winSharedIfCreated,
           controller.responds(to: action) {
            controller.perform(action, with: sender)
            return true
        }

        return false
    }

    /// Returns the object that would receive an action, matching AppKit's
    /// `target(forAction:)` (nil-target resolution without sending).
    ///
    /// This walks the *same* links `sendAction(_:to:from:)` does, including
    /// each responder's supplemental target and the shared document
    /// controller. The two staying in step is what makes menu validation
    /// honest: an item is enabled exactly when clicking it would reach
    /// something.
    public func target(forAction action: Selector) -> Any? {
        if let found = chainTarget(from: keyWindow, for: action) {
            return found
        }

        if let mainWindow, mainWindow !== keyWindow,
           let found = chainTarget(from: mainWindow, for: action) {
            return found
        }

        if responds(to: action) {
            return self
        }

        if let delegateObject = delegate as? NSObject, delegateObject.responds(to: action) {
            return delegateObject
        }

        if let controller = NSDocumentController.winSharedIfCreated,
           controller.responds(to: action) {
            return controller
        }

        return nil
    }

    /// Walks one window's responder chain looking for a handler.
    private func chainTarget(from window: NSWindow?, for action: Selector) -> Any? {
        guard let window else {
            return nil
        }

        var responder: NSResponder? = window.firstResponder ?? window
        while let current = responder {
            if current.responds(to: action) {
                return current
            }
            if let supplemental = current.supplementalTarget(forAction: action, sender: nil) as? NSObject,
               supplemental.responds(to: action) {
                return supplemental
            }
            responder = current.nextResponder
        }
        return nil
    }

    /// Application-level action selectors (the `NSApplication` methods menu
    /// items commonly target), dispatched by name — see `NSObject`'s
    /// selector-dispatch note.
    private static let winApplicationSelectors: [String: (NSApplication, Any?) -> Void] = [
        "terminate:": { application, sender in application.terminate(sender) },
        "orderFrontColorPanel:": { application, sender in application.orderFrontColorPanel(sender) },
        "stopModal": { application, _ in application.stopModal() },
    ]

    /// Reports whether the application implements a built-in or inherited selector.
    public override func responds(to aSelector: Selector?) -> Bool {
        guard let aSelector else {
            return false
        }

        if Self.winApplicationSelectors[aSelector.name] != nil {
            return true
        }

        return super.responds(to: aSelector)
    }

    @discardableResult
    /// Dispatches an application selector through the built-in action table.
    public override func perform(_ aSelector: Selector, with object: Any?) -> Any? {
        if let handler = Self.winApplicationSelectors[aSelector.name] {
            handler(self, object)
            return nil
        }

        return super.perform(aSelector, with: object)
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

    private func notification(named name: String) -> Notification {
        Notification(name: Notification.Name(name), object: self)
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

/// Captures a document controller's "did you review them all?" answer.
///
/// `reviewUnsavedDocuments(...)` reports through a selector, and `terminate(_:)`
/// needs the answer inline to decide whether the quit proceeds. A tiny
/// `NSObject` is the only thing `perform(_:with:)` can deliver to.
internal final class WinTerminateReviewRecorder: NSObject {
    /// Called with the answer.
    private let record: (Bool) -> Void

    /// Creates a recorder reporting through a closure.
    init(record: @escaping (Bool) -> Void) {
        self.record = record
        super.init()
    }

    /// Claims the review-callback selector.
    override func responds(to aSelector: Selector?) -> Bool {
        aSelector?.name == "documentController:didReviewAll:contextInfo:"
            || super.responds(to: aSelector)
    }

    /// Receives the answer, which travels in the callback box.
    @discardableResult
    override func perform(_ aSelector: Selector, with object: Any?) -> Any? {
        guard aSelector.name == "documentController:didReviewAll:contextInfo:" else {
            return super.perform(aSelector, with: object)
        }
        // Anything other than an explicit yes stops the quit: refusing to
        // terminate is the answer that cannot lose the user's work.
        record((object as? NSDocument.CallbackInfo)?.succeeded ?? false)
        return nil
    }
}
