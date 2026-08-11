#if os(Windows)
extension Win32NativeControlBackend {
    func dispatchScrollingAndKeysMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        switch message {
        case wmHScroll, wmVScroll:
            return handleHScrollWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        case wmKeyDown, wmSysKeyDown:
            return handleKeyDownWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        case wmKeyUp, wmSysKeyUp:
            return handleKeyUpWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        default:
            return nil
        }
    }

    func handleHScrollWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        guard lParam != 0, let scrollHwnd = HWND(bitPattern: lParam) else {
            guard let hwnd else {
                return nil
            }

            let handle = nativeHandle(from: hwnd)
            guard scrollViewMetrics[handle.rawValue] != nil else {
                return nil
            }

            updateScrollViewPosition(from: wParam, message: message, for: handle)
            controlActions[handle.rawValue]?()
            return 0
        }

        let handle = nativeHandle(from: scrollHwnd)
        guard stepperRanges[handle.rawValue] == nil else {
            return 0
        }

        // Trackbars manage their own thumb position; only the value
        // change needs to reach the framework action.
        if trackbarHandles.contains(handle.rawValue) {
            controlActions[handle.rawValue]?()
            return 0
        }

        // Record which part a standalone scroller reported so
        // NSScroller.hitPart reflects the actual gesture.
        if scrollerHandles.contains(handle.rawValue) {
            scrollerParts[handle.rawValue] = scrollerPart(fromScrollCode: UInt(wParam & 0xffff))
        }

        updateSliderPosition(from: wParam, for: handle)
        guard let action = controlActions[handle.rawValue] else {
            return nil
        }

        action()
        return 0
    }

    func handleKeyDownWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        // Menu key equivalents win over view key routing, matching the
        // AppKit ordering where the main menu sees Cmd-key events first.
        if let keyEquivalentHandler, currentModifierFlags().contains(.control),
           keyEquivalentHandler(keyEvent(type: .keyDown, wParam: wParam)) {
            return 0
        }

        guard let hwnd, let action = keyDownActions[nativeHandle(from: hwnd).rawValue] else {
            return nil
        }

        action(keyEvent(type: .keyDown, wParam: wParam))
        return 0
    }

    func handleKeyUpWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        guard let hwnd, let action = keyUpActions[nativeHandle(from: hwnd).rawValue] else {
            return nil
        }

        action(keyEvent(type: .keyUp, wParam: wParam))
        return 0
    }
}
#endif
