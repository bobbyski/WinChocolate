#if os(Windows)
extension Win32NativeControlBackend {
    func dispatchLifecycleMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        switch message {
        case wmWinChocolateAsync:
            return handleWinChocolateAsyncWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        case wmClose:
            return handleCloseWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        case wmActivateApp:
            return handleActivateAppWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        case wmSettingChange:
            return handleSettingChangeWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        case wmDpiChanged:
            return handleDpiChangedWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        case wmGetMinMaxInfo:
            return handleGetMinMaxInfoWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        case wmInitMenuPopup:
            return handleInitMenuPopupWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        case wmMove:
            return handleMoveWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        case wmSize:
            return handleSizeWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        default:
            return nil
        }
    }

    func handleWinChocolateAsyncWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        runAsyncActions()
        return 0
    }

    func handleCloseWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        // A title-bar close consults the framework first, matching
        // AppKit's windowShouldClose veto; programmatic closes skip this.
        guard let hwnd,
              let handler = windowShouldCloseHandlers[nativeHandle(from: hwnd).rawValue],
              !handler() else {
            return nil
        }

        return 0
    }

    func handleActivateAppWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        // Floating panels with hidesOnDeactivate leave the screen while
        // another application is active and return afterward.
        applicationActivationDidChange(isActive: wParam != 0)
        return nil
    }

    func handleSettingChangeWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        // The user may have flipped the system dark/light theme. Refresh the
        // app's appearance if it follows the system; let DefWindowProc see
        // the message too.
        winHandleSettingChange()
        return nil
    }

    func handleDpiChangedWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        // The window moved to a display with a different DPI (10.7). Adopt
        // the new device scale and take the OS-suggested window rectangle
        // (lParam is a RECT*), which resizes the window and re-runs the
        // framework's layout at the new scale.
        let newDpi = CGFloat((wParam >> 16) & 0xffff)
        if newDpi > 0 {
            winDeviceScale = newDpi / 96.0
            defaultControlFont = nil  // rebuilt at the new scale on demand
        }
        if let hwnd, lParam != 0,
           let suggested = UnsafePointer<RECT>(bitPattern: UInt(bitPattern: lParam)) {
            let rect = suggested.pointee
            _ = winSetWindowPos(hwnd, nil, rect.left, rect.top,
                                rect.right - rect.left, rect.bottom - rect.top,
                                swpNoZOrder | swpNoActivate)
            _ = winRedrawWindow(hwnd, nil, nil, rdwInvalidate | rdwErase | rdwAllChildren)
        }
        return 0
    }

    func handleGetMinMaxInfoWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        // Constrain user resizing to the window's content size limits,
        // converting each content size to the outer window rect.
        guard let hwnd, lParam != 0,
              let info = UnsafeMutablePointer<MINMAXINFO>(bitPattern: UInt(bitPattern: lParam)) else {
            return nil
        }
        let handle = nativeHandle(from: hwnd)
        guard windowHandles.contains(handle) else {
            return nil
        }
        let style = windowStyles[handle.rawValue] ?? 0
        let hasMenu = windowMenuFlags[handle.rawValue] ?? false
        if let minSize = windowMinContentSizes[handle.rawValue] {
            let outer = outerWindowSize(forContentSize: minSize, style: style, hasMenu: hasMenu)
            info.pointee.ptMinTrackSize = POINT(x: outer.width, y: outer.height)
        }
        if let maxSize = windowMaxContentSizes[handle.rawValue] {
            let outer = outerWindowSize(forContentSize: maxSize, style: style, hasMenu: hasMenu)
            info.pointee.ptMaxTrackSize = POINT(x: outer.width, y: outer.height)
        }
        guard windowMinContentSizes[handle.rawValue] != nil || windowMaxContentSizes[handle.rawValue] != nil else {
            return nil
        }
        return 0
    }

    func handleInitMenuPopupWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        // Run AppKit-style validation just before a menu drops down, then
        // rebuild the native items so mutations and dynamic titles show.
        guard let entry = nativeMenuRegistry[wParam] else {
            return nil
        }

        entry.menu.update()
        rebuildNativeMenu(entry.menu, forRegistryKey: wParam)
        return 0
    }

    func handleMoveWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        guard let hwnd else {
            return nil
        }

        let moveHandle = nativeHandle(from: hwnd)
        guard windowHandles.contains(moveHandle), let moveAction = windowMoveActions[moveHandle.rawValue] else {
            return nil
        }

        // WM_MOVE reports the client origin; the window rect gives the
        // frame origin the framework tracks.
        var windowRect = RECT()
        guard winGetWindowRect(hwnd, &windowRect) != 0 else {
            return nil
        }
        moveAction(NSPoint(x: CGFloat(windowRect.left), y: CGFloat(windowRect.top)))
        return nil
    }

    func handleSizeWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        guard let hwnd else {
            return nil
        }

        let handle = nativeHandle(from: hwnd)
        guard windowHandles.contains(handle), let action = windowResizeActions[handle.rawValue] else {
            return nil
        }

        var rectangle = RECT()
        guard winGetClientRect(hwnd, &rectangle) != 0 else {
            return nil
        }

        action(NSSize(width: CGFloat(max(0, rectangle.right - rectangle.left)), height: CGFloat(max(0, rectangle.bottom - rectangle.top))))
        // Force a clean repaint of the whole client area and every child
        // control after relayout. Without this, a drag-resize leaves stale
        // pixels: child controls repaint promptly while the container view's
        // background surface lags, so transparent labels show their (focus-
        // tinted) fill over an unrepainted container.
        _ = winRedrawWindow(hwnd, nil, nil, rdwInvalidate | rdwErase | rdwAllChildren)
        return 0
    }
}
#endif
