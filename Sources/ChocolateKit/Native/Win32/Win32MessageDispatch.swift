#if os(Windows)
extension Win32NativeControlBackend {
    struct ScrollPositionContext {
        let current: Double
        let line: Double
        let page: Double
        let thumb: Double
        let maximum: Double
    }

    func dispatchMessage(hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT? {
        if [wmWinChocolateAsync, wmClose, wmActivateApp, wmSettingChange, wmDpiChanged, wmGetMinMaxInfo, wmInitMenuPopup, wmMove, wmSize].contains(message) {
            return dispatchLifecycleMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        }
        if [wmHScroll, wmVScroll, wmKeyDown, wmSysKeyDown, wmKeyUp, wmSysKeyUp].contains(message) {
            return dispatchScrollingAndKeysMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        }
        if [wmMouseMove, wmMouseLeave, wmLButtonDown, wmLButtonUp, wmLButtonDblClk, wmRButtonDown, wmRButtonUp, wmMButtonDown, wmMButtonUp, wmSetCursor, wmMouseWheel, wmMouseHWheel].contains(message) {
            return dispatchPointerMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        }
        if [wmPaint, wmEraseBackground].contains(message) {
            return dispatchDrawingMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        }
        if [wmNotify].contains(message) {
            return dispatchNotificationsMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        }
        if [wmCommand, wmCtlColorEdit, wmCtlColorListBox, wmCtlColorStatic, wmCtlColorBtn].contains(message) {
            return dispatchCommandsAndColorsMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        }
        if [wmUAHDrawMenu, wmUAHDrawMenuItem, wmNcPaint, wmNcActivate].contains(message) {
            return dispatchMenusMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        }
        if [wmDestroy].contains(message) {
            return dispatchDestructionMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        }
        return nil
    }

    func runAsyncActions() {
        let pendingActions = asyncActions
        asyncActions.removeAll()
        for action in pendingActions {
            action()
        }
    }

    func dispatchControlMessage(hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT? {
        if [wmMouseMove, wmMouseLeave, wmLButtonDown, wmLButtonUp].contains(message) {
            return dispatchControlPointerMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        }
        if [wmPaint, wmEraseBackground, wmTimer].contains(message) {
            return dispatchControlDrawingMessage(hwnd: hwnd, message: message, wParam: wParam)
        }
        if [wmGetDlgCode, wmSetFocus, wmKillFocus, wmKeyDown, wmSysKeyDown, wmKeyUp, wmSysKeyUp].contains(message) {
            return dispatchControlKeyboardMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        }
        return nil
    }

    func dispatchControlPointerMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        switch message {
        case wmMouseMove: return handleControlMouseMove(hwnd: hwnd, wParam: wParam, lParam: lParam)
        case wmMouseLeave: return handleControlMouseLeave(hwnd: hwnd)
        case wmLButtonDown: return handleControlButtonDown(hwnd: hwnd, lParam: lParam)
        case wmLButtonUp: return handleControlButtonUp(hwnd: hwnd, lParam: lParam)
        default: return nil
        }
    }

    func dispatchControlDrawingMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM
    ) -> LRESULT? {
        switch message {
        case wmPaint: return handleControlPaint(hwnd: hwnd)
        case wmEraseBackground: return handleControlEraseBackground(hwnd: hwnd, wParam: wParam)
        case wmTimer: return handleControlTimer(hwnd: hwnd)
        default: return nil
        }
    }

    func dispatchControlKeyboardMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        switch message {
        case wmGetDlgCode:
            return callOriginalControlProcedure(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam) | dlgcWantTab
        case wmSetFocus, wmKillFocus:
            if let hwnd {
                let handle = actionHandle(from: hwnd)
                focusChangeActions[handle.rawValue]?(message == wmSetFocus)
                if darkDatePickerFieldHandles.contains(handle.rawValue) {
                    _ = winInvalidateRect(hwnd, nil, 1)
                }
            }
            return nil
        case wmKeyDown, wmSysKeyDown:
            return handleControlKeyDown(hwnd: hwnd, wParam: wParam)
        case wmKeyUp, wmSysKeyUp:
            return handleControlKeyUp(hwnd: hwnd, wParam: wParam)
        default:
            return nil
        }
    }

    func handleControlMouseMove(hwnd: HWND?, wParam: WPARAM, lParam: LPARAM) -> LRESULT? {
        guard let hwnd else { return nil }
        let handle = actionHandle(from: hwnd)
        if mouseLeftActions[handle.rawValue] != nil {
            requestMouseLeaveNotification(for: hwnd)
        }
        if editableLevelHandles.contains(handle.rawValue) {
            if (wParam & mkLButton) != 0 {
                applyLevelIndicatorClick(x: Int(point(from: lParam).x), for: handle)
                controlActions[handle.rawValue]?()
            }
            return nil
        }
        guard !comboBoxHandles.contains(handle.rawValue) else { return nil }
        if (wParam & mkLButton) != 0, let action = mouseDraggedActions[handle.rawValue] {
            action(NSEvent(
                type: .leftMouseDragged,
                locationInWindow: mouseLocation(from: lParam, in: hwnd),
                modifierFlags: currentModifierFlags()
            ))
            return nil
        }
        guard let action = mouseMovedActions[handle.rawValue] else { return nil }
        action(NSEvent(
            type: .mouseMoved,
            locationInWindow: mouseLocation(from: lParam, in: hwnd),
            modifierFlags: currentModifierFlags()
        ))
        return nil
    }

    func handleControlMouseLeave(hwnd: HWND?) -> LRESULT? {
        guard let hwnd else { return nil }
        mouseLeftActions[actionHandle(from: hwnd).rawValue]?()
        return nil
    }

    func handleControlPaint(hwnd: HWND?) -> LRESULT? {
        guard let hwnd else { return nil }
        if darkTableHeaderHwnds.contains(UInt(bitPattern: hwnd)) {
            guard NSApplication.shared.effectiveAppearance.winIsDark else { return nil }
            drawDarkTableHeader(hwnd)
            return 0
        }
        guard darkDatePickerFieldHandles.contains(actionHandle(from: hwnd).rawValue),
              winGetFocus() != hwnd else { return nil }
        drawDarkDatePickerField(hwnd)
        return 0
    }

    func handleControlEraseBackground(hwnd: HWND?, wParam: WPARAM) -> LRESULT? {
        guard let hwnd else { return nil }
        if darkTableHeaderHwnds.contains(UInt(bitPattern: hwnd)),
           NSApplication.shared.effectiveAppearance.winIsDark {
            return 1
        }
        let handle = actionHandle(from: hwnd)
        if darkDatePickerFieldHandles.contains(handle.rawValue), winGetFocus() != hwnd { return 1 }
        guard groupBoxHandles.contains(handle.rawValue) else { return nil }
        var rectangle = RECT()
        _ = winGetClientRect(hwnd, &rectangle)
        fillRect(rectangle, color: inheritedBackgroundColor(behind: hwnd), deviceContext: HDC(bitPattern: wParam))
        return 1
    }

    func handleControlTimer(hwnd: HWND?) -> LRESULT? {
        guard let hwnd else { return nil }
        let handle = actionHandle(from: hwnd)
        guard var position = marqueePositions[handle.rawValue] else { return nil }
        position = (position + 4) % 104
        marqueePositions[handle.rawValue] = position
        _ = winSendMessageW(hwnd, pbmSetPos, WPARAM(min(position, 100)), 0)
        return 0
    }

    func handleControlKeyDown(hwnd: HWND?, wParam: WPARAM) -> LRESULT? {
        if let keyEquivalentHandler {
            let virtualKey = UInt16(wParam & 0xffff)
            let isDefaultOrCancel = (virtualKey == UInt16(vkReturn) || virtualKey == UInt16(vkEscape))
                && !(hwnd.map { multilineTextHandles.contains(actionHandle(from: $0).rawValue) } ?? false)
            if (currentModifierFlags().contains(.control) || isDefaultOrCancel),
               keyEquivalentHandler(keyEvent(type: .keyDown, wParam: wParam)) {
                return 0
            }
        }
        guard UInt16(wParam & 0xffff) == UInt16(vkTab),
              let hwnd,
              let action = keyDownActions[actionHandle(from: hwnd).rawValue] else { return nil }
        action(keyEvent(type: .keyDown, wParam: wParam))
        return 0
    }

    func handleControlKeyUp(hwnd: HWND?, wParam: WPARAM) -> LRESULT? {
        guard UInt16(wParam & 0xffff) == UInt16(vkTab),
              let hwnd,
              let action = keyUpActions[actionHandle(from: hwnd).rawValue] else { return nil }
        action(keyEvent(type: .keyUp, wParam: wParam))
        return 0
    }

    func handleControlButtonDown(hwnd: HWND?, lParam: LPARAM) -> LRESULT? {
        guard let hwnd else { return nil }
        let handle = actionHandle(from: hwnd)
        guard !comboBoxHandles.contains(handle.rawValue) else { return nil }
        if editableLevelHandles.contains(handle.rawValue) {
            applyLevelIndicatorClick(x: Int(point(from: lParam).x), for: handle)
            _ = winSetCapture(hwnd)
            controlActions[handle.rawValue]?()
            return 0
        }
        if stepperRanges[handle.rawValue] != nil, let action = controlActions[handle.rawValue] {
            updateStepperPosition(fromClickAt: point(from: lParam), hwnd: hwnd, for: handle)
            _ = winSetCapture(hwnd)
            _ = winSetFocus(hwnd)
            action()
            return 0
        }
        if windowDragViewHandles.contains(handle.rawValue), let root = rootWindow(for: hwnd) {
            mouseDownActions[handle.rawValue]?(NSEvent(
                type: .leftMouseDown,
                locationInWindow: mouseLocation(from: lParam, in: hwnd),
                modifierFlags: currentModifierFlags()
            ))
            _ = winReleaseCapture()
            _ = winSendMessageW(root, wmNCLButtonDown, WPARAM(htCaption), 0)
            return 0
        }
        guard let action = mouseDownActions[handle.rawValue] else { return nil }
        _ = winSetFocus(hwnd)
        action(NSEvent(
            type: .leftMouseDown,
            locationInWindow: mouseLocation(from: lParam, in: hwnd),
            modifierFlags: currentModifierFlags()
        ))
        return nil
    }

    func handleControlButtonUp(hwnd: HWND?, lParam: LPARAM) -> LRESULT? {
        guard let hwnd else { return nil }
        let handle = actionHandle(from: hwnd)
        if editableLevelHandles.contains(handle.rawValue) {
            _ = winReleaseCapture()
            return 0
        }
        guard !comboBoxHandles.contains(handle.rawValue),
              let action = mouseUpActions[handle.rawValue] else { return nil }
        action(NSEvent(
            type: .leftMouseUp,
            locationInWindow: mouseLocation(from: lParam, in: hwnd),
            modifierFlags: currentModifierFlags()
        ))
        return nil
    }
}
#endif
