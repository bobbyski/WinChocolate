import Foundation

/// A backend that records state in memory instead of touching a display.
///
/// It lets the contract tests exercise the whole AppKit-shaped API — window
/// creation, control wiring, actions — with no GTK and no X server, so the
/// tests are hermetic and run anywhere (including CI). The `simulate*` hooks
/// stand in for user input.
///
/// Platform-neutral by construction: this type is a prime candidate to move
/// into the shared core in Phase L6, unchanged.
public final class InMemoryNativeControlBackend: NativeControlBackend {

    /// What kind of control a handle refers to (drives `setText` routing).
    public enum Kind: Equatable { case window, view, button, label }

    private var nextRaw: UInt = 1

    public private(set) var isRunning = false
    public private(set) var kinds: [UInt: Kind] = [:]
    public private(set) var titles: [UInt: String] = [:]
    public private(set) var texts: [UInt: String] = [:]
    public private(set) var frames: [UInt: NSRect] = [:]
    public private(set) var enabledStates: [UInt: Bool] = [:]
    public private(set) var contentViews: [UInt: UInt] = [:]
    public private(set) var subviews: [UInt: [UInt]] = [:]
    public private(set) var visibleWindows: Set<UInt> = []
    private var actions: [UInt: () -> Void] = [:]
    private var windowCloseActions: [UInt: () -> Void] = [:]

    public init() {}

    private func allocate(_ kind: Kind) -> NativeHandle {
        defer { nextRaw += 1 }
        kinds[nextRaw] = kind
        return NativeHandle(rawValue: nextRaw)
    }

    // MARK: Application lifecycle
    public func runApplication() { isRunning = true }
    public func terminateApplication() { isRunning = false }

    // MARK: Windows
    public func createWindow(title: String, frame: NSRect, styleMask: NSWindow.StyleMask) -> NativeHandle {
        let h = allocate(.window)
        titles[h.rawValue] = title
        frames[h.rawValue] = frame
        return h
    }
    public func setContentView(_ view: NativeHandle, for window: NativeHandle) {
        contentViews[window.rawValue] = view.rawValue
    }
    public func showWindow(_ handle: NativeHandle) {
        visibleWindows.insert(handle.rawValue)
    }
    public func setWindowTitle(_ title: String, for handle: NativeHandle) {
        titles[handle.rawValue] = title
    }
    public func registerWindowCloseAction(for handle: NativeHandle, action: @escaping () -> Void) {
        windowCloseActions[handle.rawValue] = action
    }

    // MARK: Views & controls
    public func createView(frame: NSRect) -> NativeHandle {
        let h = allocate(.view); frames[h.rawValue] = frame; return h
    }
    public func createButton(title: String, frame: NSRect) -> NativeHandle {
        let h = allocate(.button)
        titles[h.rawValue] = title
        texts[h.rawValue] = title
        frames[h.rawValue] = frame
        enabledStates[h.rawValue] = true
        return h
    }
    public func createLabel(text: String, frame: NSRect) -> NativeHandle {
        let h = allocate(.label); texts[h.rawValue] = text; frames[h.rawValue] = frame; return h
    }
    public func addSubview(_ child: NativeHandle, to parent: NativeHandle) {
        subviews[parent.rawValue, default: []].append(child.rawValue)
    }

    // MARK: Mutators
    public func setText(_ text: String, for handle: NativeHandle) { texts[handle.rawValue] = text }
    public func setFrame(_ frame: NSRect, for handle: NativeHandle) { frames[handle.rawValue] = frame }
    public func setEnabled(_ isEnabled: Bool, for handle: NativeHandle) { enabledStates[handle.rawValue] = isEnabled }
    public func destroyControl(_ handle: NativeHandle) {
        let r = handle.rawValue
        kinds[r] = nil; titles[r] = nil; texts[r] = nil; frames[r] = nil
        enabledStates[r] = nil; actions[r] = nil
    }

    // MARK: Events
    public func registerAction(for handle: NativeHandle, action: @escaping () -> Void) {
        actions[handle.rawValue] = action
    }

    // MARK: Test hooks (not part of the protocol)
    /// Fires the action registered for a control, as if the user clicked it.
    public func simulateClick(_ handle: NativeHandle) { actions[handle.rawValue]?() }
    /// Fires a window's close action, as if the user closed it.
    public func simulateWindowClose(_ handle: NativeHandle) { windowCloseActions[handle.rawValue]?() }
    /// The text currently recorded for a control.
    public func text(for handle: NativeHandle) -> String? { texts[handle.rawValue] }
    /// Whether a window has been shown.
    public func isVisible(_ handle: NativeHandle) -> Bool { visibleWindows.contains(handle.rawValue) }
    /// Whether a control is enabled.
    public func isEnabled(_ handle: NativeHandle) -> Bool { enabledStates[handle.rawValue] ?? true }
}
