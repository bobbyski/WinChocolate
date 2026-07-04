#if os(Windows)
extension Win32NativeControlBackend {
    /// Hook watching for clicks outside a transient popover.
    nonisolated(unsafe) static var outsideClickHook: UnsafeMutableRawPointer?
    /// The window whose outside clicks dismiss it.
    nonisolated(unsafe) static var outsideClickWindow: HWND?
    /// The dismiss action fired on an outside click.
    nonisolated(unsafe) static var outsideClickDismiss: (() -> Void)?

    /// Starts a thread mouse hook that dismisses a window on an outside click.
    public func beginOutsideClickDismiss(for handle: NativeHandle, onDismiss: @escaping () -> Void) {
        endOutsideClickDismiss()
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        Self.outsideClickWindow = hwnd
        Self.outsideClickDismiss = onDismiss
        Self.outsideClickHook = winSetWindowsHookExW(whMouse, outsideClickHookProcedure, nil, winGetCurrentThreadId())
    }

    /// Removes the outside-click dismiss hook.
    public func endOutsideClickDismiss() {
        if let hook = Self.outsideClickHook {
            _ = winUnhookWindowsHookEx(hook)
        }
        Self.outsideClickHook = nil
        Self.outsideClickWindow = nil
        Self.outsideClickDismiss = nil
    }
}

/// Whether a window is a target window or one of its descendants.
private func isWindow(_ candidate: HWND?, orDescendantOf ancestor: HWND) -> Bool {
    var current = candidate
    while let window = current {
        if window == ancestor {
            return true
        }
        current = winGetParent(window)
    }
    return false
}

/// Fires the dismiss action when a button press lands outside the watched window.
///
/// The dismiss runs through `dispatchAsync` so the popover is not destroyed
/// while still inside the hook callback.
private let outsideClickHookProcedure: @convention(c) (Int32, WPARAM, LPARAM) -> LRESULT = { code, wParam, lParam in
    typealias Backend = Win32NativeControlBackend
    if code >= 0, let popover = Backend.outsideClickWindow {
        let message = UINT(truncatingIfNeeded: wParam)
        if message == wmLButtonDown || message == wmRButtonDown || message == wmMButtonDown || message == wmNCLButtonDown {
            var point = POINT()
            if winGetCursorPos(&point) != 0, !isWindow(winWindowFromPoint(point), orDescendantOf: popover) {
                let dismiss = Backend.outsideClickDismiss
                Backend.activeBackend?.dispatchAsync {
                    dismiss?()
                }
            }
        }
    }
    return winCallNextHookEx(nil, code, wParam, lParam)
}
#endif
