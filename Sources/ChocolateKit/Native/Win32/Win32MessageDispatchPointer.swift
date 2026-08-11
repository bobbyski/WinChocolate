#if os(Windows)
extension Win32NativeControlBackend {
    func dispatchPointerMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        dispatchPrimaryPointerMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
            ?? dispatchSecondaryPointerMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
    }

    private func dispatchPrimaryPointerMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        switch message {
        case wmMouseMove:
            return handleMouseMoveWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        case wmMouseLeave:
            return handleMouseLeaveWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        case wmLButtonDown:
            return handleLButtonDownWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        case wmLButtonUp:
            return handleLButtonUpWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        case wmLButtonDblClk:
            return handleLButtonDblClkWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        default:
            return nil
        }
    }

    private func dispatchSecondaryPointerMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        switch message {
        case wmRButtonDown:
            return handleRButtonDownWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        case wmRButtonUp:
            return handleRButtonUpWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        case wmMButtonDown:
            return handleMButtonDownWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        case wmMButtonUp:
            return handleMButtonUpWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        case wmSetCursor:
            return handleSetCursorWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        case wmMouseWheel, wmMouseHWheel:
            return handleMouseWheelWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        default:
            return nil
        }
    }

    func handleMouseMoveWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        guard let hwnd else {
            return nil
        }

        let handle = nativeHandle(from: hwnd)
        if mouseLeftActions[handle.rawValue] != nil {
            requestMouseLeaveNotification(for: hwnd)
        }
        if (wParam & mkLButton) != 0, let action = mouseDraggedActions[handle.rawValue] {
            action(NSEvent(type: .leftMouseDragged, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
            return 0
        }

        guard let action = mouseMovedActions[handle.rawValue] else {
            return nil
        }

        action(NSEvent(type: .mouseMoved, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
        return 0
    }

    func handleMouseLeaveWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        guard let hwnd else {
            return nil
        }

        mouseLeftActions[nativeHandle(from: hwnd).rawValue]?()
        return 0
    }

    func handleLButtonDownWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        guard let hwnd, let action = mouseDownActions[nativeHandle(from: hwnd).rawValue] else {
            return nil
        }

        _ = winSetCapture(hwnd)
        _ = winSetFocus(hwnd)
        action(NSEvent(type: .leftMouseDown, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
        return 0
    }

    func handleLButtonUpWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        guard let hwnd else {
            return nil
        }

        // Release the capture taken on button-down FIRST and unconditionally.
        // Doing it only after a registered handler was found leaked the
        // capture for any window without a mouse-up action: the mouse stayed
        // captured after the button came up, so every later click and drag
        // went to that window and the app looked hung.
        _ = winReleaseCapture()
        guard let action = mouseUpActions[nativeHandle(from: hwnd).rawValue] else {
            return nil
        }

        action(NSEvent(type: .leftMouseUp, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
        return 0
    }

    func handleLButtonDblClkWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        // CS_DBLCLKS turns the second press of a double-click into this
        // message; deliver it as a mouse-down with a click count of two.
        guard let hwnd, let action = mouseDownActions[nativeHandle(from: hwnd).rawValue] else {
            return nil
        }

        _ = winSetCapture(hwnd)
        _ = winSetFocus(hwnd)
        action(NSEvent(type: .leftMouseDown, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags(), clickCount: 2))
        return 0
    }

    func handleRButtonDownWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        guard let hwnd, let action = rightMouseDownActions[nativeHandle(from: hwnd).rawValue] else {
            return nil
        }

        _ = winSetFocus(hwnd)
        action(NSEvent(type: .rightMouseDown, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
        return 0
    }

    func handleRButtonUpWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        guard let hwnd, let action = rightMouseUpActions[nativeHandle(from: hwnd).rawValue] else {
            return nil
        }

        action(NSEvent(type: .rightMouseUp, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
        return 0
    }

    func handleMButtonDownWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        guard let hwnd, let action = otherMouseDownActions[nativeHandle(from: hwnd).rawValue] else {
            return nil
        }

        _ = winSetFocus(hwnd)
        action(NSEvent(type: .otherMouseDown, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
        return 0
    }

    func handleMButtonUpWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        guard let hwnd, let action = otherMouseUpActions[nativeHandle(from: hwnd).rawValue] else {
            return nil
        }

        action(NSEvent(type: .otherMouseUp, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
        return 0
    }

    func handleSetCursorWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        guard (lParam & 0xffff) == htClient, let hwnd else {
            return nil
        }

        // Cursor regions resolve per hover position, so views can show
        // different cursors over different rectangles (cursor rects).
        if let regions = cursorRegions[nativeHandle(from: hwnd).rawValue] {
            var screenPoint = POINT()
            _ = winGetCursorPos(&screenPoint)
            _ = winScreenToClient(hwnd, &screenPoint)
            let local = NSMakePoint(CGFloat(screenPoint.x), CGFloat(screenPoint.y))
            let name = regions.first { NSPointInRect(local, $0.rect) }?.cursorName ?? "arrow"
            _ = winSetCursor(systemCursor(named: name))
            return 1
        }

        // A framework cursor replaces the class arrow inside the client
        // area only; the non-client frame keeps the system cursor.
        guard let cursorName = activeCursorName, cursorName != "arrow" else {
            return nil
        }

        _ = winSetCursor(systemCursor(named: cursorName))
        return 1
    }

    func handleMouseWheelWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        // The wheel message goes to the focused window; deliver it to the
        // view under the cursor, matching AppKit's scroll routing. When
        // the cursor sits over a native child without a wheel handler
        // (an EDIT inside a document, say), walk up to the nearest
        // ancestor that scrolls.
        let screenPoint = POINT(x: Int32(lParam & 0xffff), y: Int32((lParam >> 16) & 0xffff))
        let wheelDelta = Int16(truncatingIfNeeded: Int32((wParam >> 16) & 0xffff))
        var target = winWindowFromPoint(screenPoint)
        var action: ((NSEvent) -> Void)?
        while let candidate = target {
            if let found = scrollWheelActions[nativeHandle(from: candidate).rawValue] {
                action = found
                break
            }
            target = winGetParent(candidate)
        }
        guard let action, let target else {
            return nil
        }

        var clientPoint = screenPoint
        if let rootWindow = rootWindow(for: target) {
            _ = winScreenToClient(rootWindow, &clientPoint)
        }
        // Horizontal wheel: positive tilts right, which reveals content
        // further right, so it maps to a negative AppKit deltaX.
        let lines = CGFloat(wheelDelta) / 120
        action(NSEvent(
            type: .scrollWheel,
            locationInWindow: NSMakePoint(CGFloat(clientPoint.x), CGFloat(clientPoint.y)),
            modifierFlags: currentModifierFlags(),
            scrollingDeltaX: message == wmMouseHWheel ? -lines : 0,
            scrollingDeltaY: message == wmMouseHWheel ? 0 : lines
        ))
        return 0
    }
}
#endif
