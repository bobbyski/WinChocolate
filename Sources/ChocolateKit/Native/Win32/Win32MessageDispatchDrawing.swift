#if os(Windows)
extension Win32NativeControlBackend {
    func dispatchDrawingMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        switch message {
        case wmPaint:
            return handlePaintWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        case wmEraseBackground:
            return handleEraseBackgroundWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        default:
            return nil
        }
    }

    func handlePaintWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        guard let hwnd else {
            return nil
        }

        let handle = nativeHandle(from: hwnd)
        guard customViewHandles.contains(handle.rawValue) else {
            return nil
        }

        drawCustomView(hwnd: hwnd, handle: handle)
        return 0
    }

    func handleEraseBackgroundWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        guard let hwnd else {
            return nil
        }

        let handle = nativeHandle(from: hwnd)
        // Custom views repaint their whole surface through a double-buffered
        // WM_PAINT, so skip the erase to avoid a flash before the blit.
        if transparentBackgroundHandles.contains(handle.rawValue) || customViewHandles.contains(handle.rawValue) {
            return 1
        }
        guard let brush = backgroundBrushes[handle.rawValue] else {
            return nil
        }

        var rectangle = RECT()
        _ = winGetClientRect(hwnd, &rectangle)
        withUnsafePointer(to: rectangle) { rectanglePointer in
            _ = winFillRect(HDC(bitPattern: wParam), rectanglePointer, brush)
        }
        return 1
    }
}
#endif
