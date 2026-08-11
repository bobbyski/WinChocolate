#if os(Windows)
extension Win32NativeControlBackend {
    func dispatchDestructionMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        switch message {
        case wmDestroy:
            return handleDestroyWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        default:
            return nil
        }
    }

    func handleDestroyWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        if let hwnd {
            let handle = nativeHandle(from: hwnd)
            guard windowHandles.contains(handle) else {
                return 0
            }

            windowHandles.remove(handle)
            windowStyles.removeValue(forKey: handle.rawValue)
            windowMenuFlags.removeValue(forKey: handle.rawValue)
            mainMenuWindowHandles.remove(handle)
            windowResizeActions.removeValue(forKey: handle.rawValue)
            windowShouldCloseHandlers.removeValue(forKey: handle.rawValue)
            windowCloseActions.removeValue(forKey: handle.rawValue)?()

            // Quit once the last top-level window closes, so closing a
            // secondary document window leaves the app running.
            if windowHandles.isEmpty {
                winPostQuitMessage(0)
            }
        }
        return 0
    }
}
#endif
