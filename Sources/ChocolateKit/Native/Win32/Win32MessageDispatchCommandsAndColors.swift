#if os(Windows)
extension Win32NativeControlBackend {
    func dispatchCommandsAndColorsMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        switch message {
        case wmCommand:
            return handleCommandWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        case wmCtlColorEdit, wmCtlColorListBox, wmCtlColorStatic, wmCtlColorBtn:
            return handleCtlColorEditWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        default:
            return nil
        }
    }

    func handleCommandWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        let commandIdentifier = UInt(wParam & 0xffff)
        let notificationCode = UInt((wParam >> 16) & 0xffff)

        if let action = commandActions[commandIdentifier] {
            action()
            return 0
        }

        if lParam != 0, notificationCode == enChange, let action = textChangeActions[UInt(bitPattern: lParam)] {
            action(text(from: HWND(bitPattern: lParam)))
            return 0
        }

        if lParam != 0, notificationCode == cbnEditChange, let action = textChangeActions[UInt(bitPattern: lParam)] {
            action(text(from: HWND(bitPattern: lParam)))
            return 0
        }

        if lParam != 0, notificationCode == cbnSelChange, let action = controlActions[UInt(bitPattern: lParam)] {
            action()
            return 0
        }

        if lParam != 0, notificationCode == lbnSelChange, let action = controlActions[UInt(bitPattern: lParam)] {
            action()
            return 0
        }

        if lParam != 0, notificationCode == bnClicked {
            let rawHandle = UInt(bitPattern: lParam)
            // STN_CLICKED shares BN_CLICKED's code. An image-view static
            // routes the click through the mouse-event actions — AppKit
            // image views never fire an action on click, and subclasses
            // override `mouseDown(with:)` (the documented AppKit way to
            // make an image clickable).
            if imageViewHandles.contains(rawHandle) {
                let staticHwnd = HWND(bitPattern: lParam)
                var cursor = POINT()
                _ = winGetCursorPos(&cursor)
                _ = winScreenToClient(staticHwnd, &cursor)
                let location = NSMakePoint(CGFloat(cursor.x), CGFloat(cursor.y))
                mouseDownActions[rawHandle]?(NSEvent(type: .leftMouseDown, locationInWindow: location, modifierFlags: currentModifierFlags()))
                mouseUpActions[rawHandle]?(NSEvent(type: .leftMouseUp, locationInWindow: location, modifierFlags: currentModifierFlags()))
                return 0
            }

            if let action = controlActions[rawHandle] {
                action()
                return 0
            }
        }

        return nil
    }

    func handleCtlColorEditWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        guard lParam != 0 else {
            return nil
        }

        let rawHandle = UInt(bitPattern: lParam)
        let deviceContext = HDC(bitPattern: wParam)
        if let textColor = textColors[rawHandle] {
            _ = winSetTextColor(deviceContext, textColor)
        } else if NSApplication.shared.effectiveAppearance.winIsDark {
            // Dark appearance: the DC's default text color is black, so
            // controls without an explicit color get the dynamic default.
            _ = winSetTextColor(deviceContext, colorRef(from: .textColor))
        }

        // An explicit background color always wins, even on a control that
        // is otherwise transparent, so colored labels keep their fill.
        if let backgroundColor = backgroundColors[rawHandle], let brush = backgroundBrushes[rawHandle] {
            _ = winSetBkColor(deviceContext, backgroundColor)
            return Int(bitPattern: brush)
        }

        // Dark appearance: editable faces (edit fields, list boxes) get
        // the dark control background unless the app chose colors above.
        if NSApplication.shared.effectiveAppearance.winIsDark,
           message == wmCtlColorEdit || message == wmCtlColorListBox,
           !transparentBackgroundHandles.contains(rawHandle) {
            let face = colorRef(from: .controlBackgroundColor)
            _ = winSetBkColor(deviceContext, face)
            if let brush = solidBrush(for: face) {
                return Int(bitPattern: brush)
            }
        }

        return controlColorBrush(rawHandle: rawHandle, deviceContext: deviceContext)
    }

    func controlColorBrush(rawHandle: UInt, deviceContext: HDC?) -> LRESULT? {
        if transparentBackgroundHandles.contains(rawHandle) {
            _ = winSetBkMode(deviceContext, transparentBkMode)
            // Erase with the effective parent color instead of skipping the
            // erase: a NULL brush leaves stale pixels behind when sibling
            // views (such as drag previews) move across the control.
            let background = inheritedBackgroundColor(behind: HWND(bitPattern: rawHandle))
            _ = winSetBkColor(deviceContext, background)
            if let brush = solidBrush(for: background) {
                return Int(bitPattern: brush)
            }
            return 1
        }

        if groupBoxHandles.contains(rawHandle) {
            let backgroundColor = colorRef(from: .windowBackgroundColor)
            _ = winSetBkColor(deviceContext, backgroundColor)
            _ = winSetBkMode(deviceContext, transparentBkMode)
            if let brush = controlBackgroundBrush() {
                return Int(bitPattern: brush)
            }
            return nil
        }

        if let textColor = textColors[rawHandle] {
            _ = winSetTextColor(deviceContext, textColor)
        }
        if let backgroundColor = backgroundColors[rawHandle] {
            _ = winSetBkColor(deviceContext, backgroundColor)
        }
        if let brush = backgroundBrushes[rawHandle] {
            return Int(bitPattern: brush)
        }
        return nil
    }
}
#endif
