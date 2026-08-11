#if os(Windows)
extension Win32NativeControlBackend {
    func dispatchMenusMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        switch message {
        case wmUAHDrawMenu:
            return handleUAHDrawMenuWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        case wmUAHDrawMenuItem:
            return handleUAHDrawMenuItemWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        case wmNcPaint, wmNcActivate:
            return handleNcPaintWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        default:
            return nil
        }
    }

    func handleUAHDrawMenuWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        // Dark appearance: owner-draw the menu-bar background through the
        // undocumented UAH path (light appearances keep the system draw).
        guard NSApplication.shared.effectiveAppearance.winIsDark,
              let hwnd,
              let menuPointer = UnsafeRawPointer(bitPattern: lParam) else {
            return nil
        }

        let menu = menuPointer.assumingMemoryBound(to: UAHMENU.self).pointee
        var barInfo = MENUBARINFO()
        barInfo.cbSize = DWORD(MemoryLayout<MENUBARINFO>.stride)
        guard winGetMenuBarInfo(hwnd, winObjIdMenu, 0, &barInfo) != 0 else {
            return nil
        }

        // The bar rect arrives in screen coordinates; the UAH DC is a
        // window DC, so shift by the window origin.
        var windowRect = RECT()
        _ = winGetWindowRect(hwnd, &windowRect)
        let barRect = RECT(
            left: barInfo.rcBar.left - windowRect.left,
            top: barInfo.rcBar.top - windowRect.top,
            right: barInfo.rcBar.right - windowRect.left,
            bottom: barInfo.rcBar.bottom - windowRect.top
        )
        if let brush = solidBrush(for: colorRef(from: .windowBackgroundColor)) {
            withUnsafePointer(to: barRect) { rectPointer in
                _ = winFillRect(menu.hdc, rectPointer, brush)
            }
        }
        return 0
    }

    func handleUAHDrawMenuItemWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        // Dark appearance: owner-draw one menu-bar item (fill per state,
        // then the item title).
        guard NSApplication.shared.effectiveAppearance.winIsDark,
              let itemPointer = UnsafeRawPointer(bitPattern: lParam) else {
            return nil
        }

        let item = itemPointer.assumingMemoryBound(to: UAHDRAWMENUITEM.self).pointee
        guard let deviceContext = item.dis.hDC else {
            return nil
        }

        let state = item.dis.itemState
        let highlighted = (state & (odsHotlight | odsSelected)) != 0
        let fill = highlighted
            ? colorRef(from: .controlBackgroundColor)
            : colorRef(from: .windowBackgroundColor)
        var itemRect = item.dis.rcItem
        if let brush = solidBrush(for: fill) {
            withUnsafePointer(to: itemRect) { rectPointer in
                _ = winFillRect(deviceContext, rectPointer, brush)
            }
        }

        var titleBuffer = [UInt16](repeating: 0, count: 256)
        let titleLength = winGetMenuStringW(
            item.um.hmenu, UINT(bitPattern: item.umi.iPosition),
            &titleBuffer, Int32(titleBuffer.count), mfByPosition
        )
        if titleLength > 0 {
            _ = winSetBkMode(deviceContext, transparentBkMode)
            let disabled = (state & (odsGrayed | odsInactive)) != 0
            _ = winSetTextColor(deviceContext, disabled
                ? colorRef(red: 0.55, green: 0.55, blue: 0.55)
                : colorRef(from: .textColor))
            var format = dtCenter | dtVCenter | dtSingleLine
            if (state & odsNoAccel) != 0 {
                format |= dtHidePrefix
            }
            _ = winDrawTextW(deviceContext, titleBuffer, titleLength, &itemRect, format)
        }
        return 0
    }

    func handleNcPaintWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        // Dark appearance with a menu bar: let the system paint the
        // non-client area, then cover the light 1px line it leaves under
        // the owner-drawn bar.
        guard NSApplication.shared.effectiveAppearance.winIsDark,
              let hwnd,
              mainMenuWindowHandles.contains(nativeHandle(from: hwnd)) else {
            return nil
        }

        let result = winDefWindowProcW(hwnd, message, wParam, lParam)
        drawDarkMenuBarBottomLine(hwnd)
        return result
    }
}
#endif
