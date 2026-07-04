#if os(Windows)
extension Win32NativeControlBackend {
    func dispatchMessage(hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT? {
        switch message {
        case wmWinChocolateAsync:
            runAsyncActions()
            return 0
        case wmClose:
            // A title-bar close consults the framework first, matching
            // AppKit's windowShouldClose veto; programmatic closes skip this.
            guard let hwnd,
                  let handler = windowShouldCloseHandlers[nativeHandle(from: hwnd).rawValue],
                  !handler() else {
                return nil
            }

            return 0
        case wmActivateApp:
            // Floating panels with hidesOnDeactivate leave the screen while
            // another application is active and return afterward.
            applicationActivationDidChange(isActive: wParam != 0)
            return nil
        case wmGetMinMaxInfo:
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
        case wmInitMenuPopup:
            // Run AppKit-style validation just before a menu drops down, then
            // rebuild the native items so mutations and dynamic titles show.
            guard let entry = nativeMenuRegistry[wParam] else {
                return nil
            }

            entry.menu.update()
            rebuildNativeMenu(entry.menu, forRegistryKey: wParam)
            return 0
        case wmSize:
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
            return 0
        case wmHScroll, wmVScroll:
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

            updateSliderPosition(from: wParam, for: handle)
            guard let action = controlActions[handle.rawValue] else {
                return nil
            }

            action()
            return 0
        case wmKeyDown, wmSysKeyDown:
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
        case wmKeyUp, wmSysKeyUp:
            guard let hwnd, let action = keyUpActions[nativeHandle(from: hwnd).rawValue] else {
                return nil
            }

            action(keyEvent(type: .keyUp, wParam: wParam))
            return 0
        case wmMouseMove:
            guard let hwnd else {
                return nil
            }

            let handle = nativeHandle(from: hwnd)
            if (wParam & mkLButton) != 0, let action = mouseDraggedActions[handle.rawValue] {
                action(NSEvent(type: .leftMouseDragged, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
                return 0
            }

            guard let action = mouseMovedActions[handle.rawValue] else {
                return nil
            }

            action(NSEvent(type: .mouseMoved, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
            return 0
        case wmLButtonDown:
            guard let hwnd, let action = mouseDownActions[nativeHandle(from: hwnd).rawValue] else {
                return nil
            }

            _ = winSetCapture(hwnd)
            _ = winSetFocus(hwnd)
            action(NSEvent(type: .leftMouseDown, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
            return 0
        case wmLButtonUp:
            guard let hwnd, let action = mouseUpActions[nativeHandle(from: hwnd).rawValue] else {
                return nil
            }

            action(NSEvent(type: .leftMouseUp, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
            _ = winReleaseCapture()
            return 0
        case wmLButtonDblClk:
            // CS_DBLCLKS turns the second press of a double-click into this
            // message; deliver it as a mouse-down with a click count of two.
            guard let hwnd, let action = mouseDownActions[nativeHandle(from: hwnd).rawValue] else {
                return nil
            }

            _ = winSetCapture(hwnd)
            _ = winSetFocus(hwnd)
            action(NSEvent(type: .leftMouseDown, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags(), clickCount: 2))
            return 0
        case wmRButtonDown:
            guard let hwnd, let action = rightMouseDownActions[nativeHandle(from: hwnd).rawValue] else {
                return nil
            }

            _ = winSetFocus(hwnd)
            action(NSEvent(type: .rightMouseDown, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
            return 0
        case wmRButtonUp:
            guard let hwnd, let action = rightMouseUpActions[nativeHandle(from: hwnd).rawValue] else {
                return nil
            }

            action(NSEvent(type: .rightMouseUp, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
            return 0
        case wmMButtonDown:
            guard let hwnd, let action = otherMouseDownActions[nativeHandle(from: hwnd).rawValue] else {
                return nil
            }

            _ = winSetFocus(hwnd)
            action(NSEvent(type: .otherMouseDown, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
            return 0
        case wmMButtonUp:
            guard let hwnd, let action = otherMouseUpActions[nativeHandle(from: hwnd).rawValue] else {
                return nil
            }

            action(NSEvent(type: .otherMouseUp, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
            return 0
        case wmSetCursor:
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
        case wmMouseWheel, wmMouseHWheel:
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
        case wmPaint:
            guard let hwnd else {
                return nil
            }

            let handle = nativeHandle(from: hwnd)
            guard customViewHandles.contains(handle.rawValue) else {
                return nil
            }

            drawCustomView(hwnd: hwnd, handle: handle)
            return 0
        case wmEraseBackground:
            guard let hwnd else {
                return nil
            }

            let handle = nativeHandle(from: hwnd)
            if transparentBackgroundHandles.contains(handle.rawValue) {
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
        case wmNotify:
            guard lParam != 0 else {
                return nil
            }

            let header = UnsafeRawPointer(bitPattern: lParam)?.assumingMemoryBound(to: NMHDR.self).pointee
            guard let header else {
                return nil
            }

            if header.code == hdnItemClickA || header.code == hdnItemClickW {
                guard let source = header.hwndFrom,
                      let handle = tableHeaderOwners[UInt(bitPattern: source)],
                      let action = controlActions[handle.rawValue] else {
                    return nil
                }

                let headerNotification = UnsafeRawPointer(bitPattern: lParam)?.assumingMemoryBound(to: NMHEADERW.self).pointee
                let hitColumn = headerHitTestAtCursor(hwnd: source)
                let clickedColumn = hitColumn >= 0 ? hitColumn : Int(headerNotification?.iItem ?? -1)
                guard clickedColumn >= 0 else {
                    return nil
                }

                tableClickedRows[handle.rawValue] = -1
                tableClickedColumns[handle.rawValue] = clickedColumn
                tableSuppressedColumnClicks[handle.rawValue] = clickedColumn
                action()
                return 0
            }

            if header.code == udnDeltapos {
                guard let source = header.hwndFrom else {
                    return nil
                }

                let handle = nativeHandle(from: source)
                guard stepperRanges[handle.rawValue] != nil else {
                    return nil
                }

                return 1
            }

            if header.code == tcnSelChange {
                guard let source = header.hwndFrom else {
                    return nil
                }

                let handle = nativeHandle(from: source)
                guard let action = controlActions[handle.rawValue] else {
                    return nil
                }

                action()
                return 0
            }

            if header.code == dtnDateTimeChange {
                guard let source = header.hwndFrom else {
                    return nil
                }

                let handle = nativeHandle(from: source)
                guard let action = controlActions[handle.rawValue] else {
                    return nil
                }

                action()
                return 0
            }

            let notification = UnsafeRawPointer(bitPattern: lParam)?.assumingMemoryBound(to: NMLISTVIEW.self).pointee
            guard let notification,
                  let source = header.hwndFrom else {
                return nil
            }

            let handle = nativeHandle(from: source)
            switch header.code {
            case lvnColumnClick:
                guard let action = controlActions[handle.rawValue] else {
                    return nil
                }

                let headerHwnd = HWND(bitPattern: winSendMessageW(source, lvmGetHeader, 0, 0))
                if let headerHwnd,
                   tableHeaderOwners[UInt(bitPattern: headerHwnd)] == handle {
                    tableSuppressedColumnClicks.removeValue(forKey: handle.rawValue)
                    return 0
                }

                let hitColumn = headerHitTestAtCursor(hwnd: headerHwnd)
                let clickedColumn = hitColumn >= 0 ? hitColumn : Int(notification.iSubItem)
                if tableSuppressedColumnClicks[handle.rawValue] == clickedColumn {
                    tableSuppressedColumnClicks.removeValue(forKey: handle.rawValue)
                    return 0
                }

                tableClickedRows[handle.rawValue] = -1
                tableClickedColumns[handle.rawValue] = clickedColumn
                action()
                return 0
            case nmClick:
                guard let action = controlActions[handle.rawValue] else {
                    return nil
                }

                let hit = tableHitTest(at: notification.ptAction, hwnd: source)
                let clickedRow = hit.row >= 0 ? hit.row : Int(notification.iItem)
                let clickedColumn = hit.column >= 0 ? hit.column : Int(notification.iSubItem)
                guard clickedRow >= 0 else {
                    return nil
                }

                tableClickedRows[handle.rawValue] = clickedRow
                tableClickedColumns[handle.rawValue] = clickedColumn
                action()
                return 0
            case lvnItemChanged:
                guard notification.iItem >= 0,
                      (notification.uChanged & lvifState) != 0,
                      (notification.uNewState & lvisSelected) != (notification.uOldState & lvisSelected),
                      (notification.uNewState & lvisSelected) != 0,
                      let action = controlActions[handle.rawValue] else {
                    return nil
                }

                tableClickedRows[handle.rawValue] = Int(notification.iItem)
                tableClickedColumns[handle.rawValue] = max(0, tableClickedColumns[handle.rawValue] ?? -1)
                action()
                return 0
            default:
                return nil
            }
        case wmCommand:
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

            if lParam != 0, notificationCode == bnClicked, let action = controlActions[UInt(bitPattern: lParam)] {
                action()
                return 0
            }

            return nil
        case wmCtlColorEdit, wmCtlColorListBox, wmCtlColorStatic, wmCtlColorBtn:
            guard lParam != 0 else {
                return nil
            }

            let rawHandle = UInt(bitPattern: lParam)
            let deviceContext = HDC(bitPattern: wParam)
            if let textColor = textColors[rawHandle] {
                _ = winSetTextColor(deviceContext, textColor)
            }

            // An explicit background color always wins, even on a control that
            // is otherwise transparent, so colored labels keep their fill.
            if let backgroundColor = backgroundColors[rawHandle], let brush = backgroundBrushes[rawHandle] {
                _ = winSetBkColor(deviceContext, backgroundColor)
                return Int(bitPattern: brush)
            }

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
        case wmDestroy:
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
        default:
            return nil
        }
    }

    private func runAsyncActions() {
        let pendingActions = asyncActions
        asyncActions.removeAll()
        for action in pendingActions {
            action()
        }
    }

    func dispatchControlMessage(hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT? {
        switch message {
        case wmMouseMove:
            guard let hwnd else {
                return nil
            }

            let handle = actionHandle(from: hwnd)
            guard !comboBoxHandles.contains(handle.rawValue) else {
                return nil
            }

            if (wParam & mkLButton) != 0, let action = mouseDraggedActions[handle.rawValue] {
                action(NSEvent(type: .leftMouseDragged, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
                return nil
            }

            guard let action = mouseMovedActions[handle.rawValue] else {
                return nil
            }

            action(NSEvent(type: .mouseMoved, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
            return nil
        case wmEraseBackground:
            guard let hwnd else {
                return nil
            }

            let handle = actionHandle(from: hwnd)
            guard groupBoxHandles.contains(handle.rawValue) else {
                return nil
            }

            // Group boxes never paint their interior, and clip-children
            // parents never paint beneath them, so stale sibling pixels
            // (for example a hidden page's drawing) would show through.
            var rectangle = RECT()
            _ = winGetClientRect(hwnd, &rectangle)
            fillRect(rectangle, color: inheritedBackgroundColor(behind: hwnd), deviceContext: HDC(bitPattern: wParam))
            return 1
        case wmTimer:
            // Sweeps subclassed progress bars for indeterminate animation.
            guard let hwnd else {
                return nil
            }

            let handle = actionHandle(from: hwnd)
            guard var position = marqueePositions[handle.rawValue] else {
                return nil
            }

            position = (position + 4) % 104
            marqueePositions[handle.rawValue] = position
            _ = winSendMessageW(hwnd, pbmSetPos, WPARAM(min(position, 100)), 0)
            return 0
        case wmGetDlgCode:
            let original = callOriginalControlProcedure(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
            return original | dlgcWantTab
        case wmSetFocus, wmKillFocus:
            if let hwnd, let action = focusChangeActions[actionHandle(from: hwnd).rawValue] {
                action(message == wmSetFocus)
            }
            return nil
        case wmKeyDown, wmSysKeyDown:
            // Menu key equivalents fire even when a native control has
            // focus, matching AppKit's Cmd-key ordering: the main menu sees
            // the event before the focused view's own key handling. Return
            // and Escape also route here so default/cancel buttons and menu
            // items with those equivalents fire — except inside a multiline
            // text control, which keeps Return for newlines.
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
                  let action = keyDownActions[actionHandle(from: hwnd).rawValue] else {
                return nil
            }

            action(keyEvent(type: .keyDown, wParam: wParam))
            return 0
        case wmKeyUp, wmSysKeyUp:
            guard UInt16(wParam & 0xffff) == UInt16(vkTab),
                  let hwnd,
                  let action = keyUpActions[actionHandle(from: hwnd).rawValue] else {
                return nil
            }

            action(keyEvent(type: .keyUp, wParam: wParam))
            return 0
        case wmLButtonDown:
            guard let hwnd else {
                return nil
            }

            let handle = actionHandle(from: hwnd)
            guard !comboBoxHandles.contains(handle.rawValue) else {
                return nil
            }

            if stepperRanges[handle.rawValue] != nil,
               let action = controlActions[handle.rawValue] {
                updateStepperPosition(fromClickAt: point(from: lParam), hwnd: hwnd, for: handle)
                _ = winSetCapture(hwnd)
                _ = winSetFocus(hwnd)
                action()
                return 0
            }

            // A background click on a movable-by-background view drags the
            // whole window: hand the press to the non-client caption logic.
            if windowDragViewHandles.contains(handle.rawValue), let root = rootWindow(for: hwnd) {
                mouseDownActions[handle.rawValue]?(NSEvent(type: .leftMouseDown, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
                _ = winReleaseCapture()
                _ = winSendMessageW(root, wmNCLButtonDown, WPARAM(htCaption), 0)
                return 0
            }

            guard let action = mouseDownActions[handle.rawValue] else {
                return nil
            }

            // Subclassed native controls own their mouse capture. Taking or
            // releasing capture here cancels the control's own click tracking
            // (a released capture sends WM_CAPTURECHANGED, which makes BUTTON
            // drop its pressed state and never send BN_CLICKED).
            _ = winSetFocus(hwnd)
            action(NSEvent(type: .leftMouseDown, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
            return nil
        case wmLButtonUp:
            guard let hwnd else {
                return nil
            }

            let handle = actionHandle(from: hwnd)
            guard !comboBoxHandles.contains(handle.rawValue),
                  let action = mouseUpActions[handle.rawValue] else {
                return nil
            }

            action(NSEvent(type: .leftMouseUp, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
            return nil
        default:
            return nil
        }
    }

    private func updateSliderPosition(from scrollParameter: WPARAM, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        let range = sliderRanges[handle.rawValue] ?? (0, 1)
        let current = Double(winSendMessageW(hwnd, sbmGetPos, 0, 0))
        let code = scrollParameter & 0xffff
        let thumb = Double((scrollParameter >> 16) & 0xffff)
        let pageStep = max(1, ((range.maxValue - range.minValue) / 10).rounded())
        let nextValue: Double

        switch code {
        case sbLineLeft:
            nextValue = current - 1
        case sbLineRight:
            nextValue = current + 1
        case sbPageLeft:
            nextValue = current - pageStep
        case sbPageRight:
            nextValue = current + pageStep
        case sbThumbPosition, sbThumbTrack:
            nextValue = thumb
        case sbTop:
            nextValue = range.minValue
        case sbBottom:
            nextValue = range.maxValue
        default:
            nextValue = current
        }

        setSliderValue(nextValue, for: handle)
    }

    private func updateScrollViewPosition(from scrollParameter: WPARAM, message: UINT, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle), var metrics = scrollViewMetrics[handle.rawValue] else {
            return
        }

        let isVertical = message == wmVScroll
        let bar = isVertical ? sbVert : sbHorz
        var scrollInfo = SCROLLINFO(cbSize: UINT(MemoryLayout<SCROLLINFO>.size), fMask: sifAll)
        guard withUnsafeMutablePointer(to: &scrollInfo, { pointer in winGetScrollInfo(hwnd, bar, pointer) }) != 0 else {
            return
        }

        let code = scrollParameter & 0xffff
        let current = Double(scrollInfo.nPos)
        let page = max(1, Double(scrollInfo.nPage))
        let line = max(1, page / 10)
        let maximum = max(0, Double(scrollInfo.nMax) - page + 1)
        let nextPosition: Double

        switch code {
        case sbLineLeft:
            nextPosition = current - line
        case sbLineRight:
            nextPosition = current + line
        case sbPageLeft:
            nextPosition = current - page
        case sbPageRight:
            nextPosition = current + page
        case sbThumbPosition, sbThumbTrack:
            nextPosition = Double(scrollInfo.nTrackPos)
        case sbTop:
            nextPosition = 0
        case sbBottom:
            nextPosition = maximum
        default:
            nextPosition = current
        }

        let clampedPosition = min(max(nextPosition, 0), maximum)
        if isVertical {
            metrics.offset = NSPoint(x: metrics.offset.x, y: clampedPosition)
        } else {
            metrics.offset = NSPoint(x: clampedPosition, y: metrics.offset.y)
        }
        scrollViewMetrics[handle.rawValue] = metrics
        updateScrollViewBars(for: handle)
    }

    private func updateStepperPosition(from scrollParameter: WPARAM, for handle: NativeHandle) {
        guard stepperRanges[handle.rawValue] != nil else {
            return
        }

        let range = stepperRanges[handle.rawValue] ?? (0, 100, 1, 0)
        let code = scrollParameter & 0xffff
        let thumb = Double((scrollParameter >> 16) & 0xffff)
        let nextValue: Double

        switch code {
        case sbLineLeft:
            nextValue = range.value + range.increment
        case sbLineRight:
            nextValue = range.value - range.increment
        case sbPageLeft:
            nextValue = range.value + range.increment
        case sbPageRight:
            nextValue = range.value - range.increment
        case sbThumbPosition, sbThumbTrack:
            nextValue = thumb
        case sbTop:
            nextValue = range.maxValue
        case sbBottom:
            nextValue = range.minValue
        default:
            nextValue = range.value
        }

        setStepperValue(nextValue, for: handle)
    }

    private func updateStepperPosition(position: Int32, delta: Int32, for handle: NativeHandle) {
        guard let range = stepperRanges[handle.rawValue], delta != 0 else {
            return
        }

        let direction = delta > 0 ? 1.0 : -1.0
        let nativePosition = Double(position)
        let baseValue = min(max(nativePosition, range.minValue), range.maxValue)
        setStepperValue(baseValue + (direction * range.increment), for: handle)
    }

    private func updateStepperPosition(fromClickAt point: NSPoint, hwnd: HWND, for handle: NativeHandle) {
        guard let range = stepperRanges[handle.rawValue] else {
            return
        }

        var rectangle = RECT()
        let height: Double
        if winGetClientRect(hwnd, &rectangle) != 0 {
            height = Double(max(1, rectangle.bottom - rectangle.top))
        } else {
            height = 1
        }

        let direction = point.y < height / 2 ? 1.0 : -1.0
        setStepperValue(range.value + (direction * range.increment), for: handle)
    }

    private func tableHitTest(at point: POINT, hwnd: HWND?) -> (row: Int, column: Int) {
        guard let hwnd else {
            return (-1, -1)
        }

        var hitTest = LVHITTESTINFO()
        hitTest.pt = point
        withUnsafeMutablePointer(to: &hitTest) { hitTestPointer in
            _ = winSendMessageW(hwnd, lvmSubItemHitTest, 0, Int(bitPattern: hitTestPointer))
        }

        return (Int(hitTest.iItem), Int(hitTest.iSubItem))
    }

    private func headerHitTestAtCursor(hwnd: HWND?) -> Int {
        guard let hwnd else {
            return -1
        }

        var point = POINT()
        guard winGetCursorPos(&point) != 0,
              winScreenToClient(hwnd, &point) != 0 else {
            return -1
        }

        var hitTest = HDHITTESTINFO()
        hitTest.pt = point
        withUnsafeMutablePointer(to: &hitTest) { hitTestPointer in
            _ = winSendMessageW(hwnd, hdmHitTest, 0, Int(bitPattern: hitTestPointer))
        }

        return Int(hitTest.iItem)
    }

    private func subclassChildControl(_ hwnd: HWND, handle: NativeHandle) {
        let replacement = unsafeBitCast(winChocolateControlProcedure as WNDPROC, to: LONG_PTR.self)
        let previous = winSetWindowLongPtrW(hwnd, gwlpWndProc, replacement)
        guard previous != 0 else {
            return
        }

        originalControlProcedures[UInt(bitPattern: hwnd)] = unsafeBitCast(previous, to: WNDPROC.self)
        controlHandleAliases[UInt(bitPattern: hwnd)] = handle
    }

    func subclassControlForTabKey(_ handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        subclassChildControl(hwnd, handle: handle)
    }

    func subclassFirstChildControlForTabKey(_ handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle),
              let child = winGetWindow(hwnd, gwChild) else {
            return
        }

        subclassChildControl(child, handle: handle)
    }

    func callOriginalControlProcedure(hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT {
        guard let hwnd,
              let originalProcedure = originalControlProcedures[UInt(bitPattern: hwnd)] else {
            return winDefWindowProcW(hwnd, message, wParam, lParam)
        }

        return winCallWindowProcW(originalProcedure, hwnd, message, wParam, lParam)
    }

    private func point(from lParam: LPARAM) -> NSPoint {
        let x = Int16(bitPattern: UInt16(lParam & 0xffff))
        let y = Int16(bitPattern: UInt16((lParam >> 16) & 0xffff))
        return NSMakePoint(CGFloat(x), CGFloat(y))
    }

    private func mouseLocation(from lParam: LPARAM, in hwnd: HWND?) -> NSPoint {
        let localPoint = point(from: lParam)
        guard let hwnd else {
            return localPoint
        }

        var screenPoint = POINT(x: Int32(localPoint.x), y: Int32(localPoint.y))
        _ = winClientToScreen(hwnd, &screenPoint)

        if let rootWindow = rootWindow(for: hwnd) {
            _ = winScreenToClient(rootWindow, &screenPoint)
        }

        return NSMakePoint(CGFloat(screenPoint.x), CGFloat(screenPoint.y))
    }

    private func rootWindow(for hwnd: HWND) -> HWND? {
        var candidate: HWND? = hwnd
        while let current = candidate {
            guard let parent = winGetParent(current) else {
                return current
            }
            candidate = parent
        }
        return nil
    }

    private func keyEvent(type: NSEvent.EventType, wParam: WPARAM) -> NSEvent {
        let keyCode = UInt16(wParam & 0xffff)
        let modifierFlags = modifierFlags(forKeyCode: keyCode, eventType: type)
        return NSEvent(
            type: type,
            locationInWindow: NSMakePoint(0, 0),
            keyCode: keyCode,
            characters: characters(forVirtualKey: keyCode, modifierFlags: modifierFlags),
            modifierFlags: modifierFlags
        )
    }

    private func characters(forVirtualKey virtualKey: UInt16, modifierFlags: NSEvent.ModifierFlags) -> String? {
        let shiftIsDown = modifierFlags.contains(.shift)
        switch virtualKey {
        case 0x30...0x39:
            return String(UnicodeScalar(UInt32(virtualKey))!)
        case 0x41...0x5a:
            let scalar = shiftIsDown ? UInt32(virtualKey) : UInt32(virtualKey + 32)
            return String(UnicodeScalar(scalar)!)
        case UInt16(vkSpace):
            return " "
        case UInt16(vkTab):
            return "\t"
        case UInt16(vkReturn):
            return "\n"
        case UInt16(vkEscape):
            return "\u{1b}"
        case UInt16(vkBack):
            return "\u{8}"
        default:
            return nil
        }
    }

    private func modifierFlags(forKeyCode keyCode: UInt16, eventType: NSEvent.EventType) -> NSEvent.ModifierFlags {
        var flags = currentModifierFlags()
        guard let eventFlag = modifierFlag(forVirtualKey: keyCode) else {
            return flags
        }

        switch eventType {
        case .keyDown:
            flags.insert(eventFlag)
        case .keyUp:
            flags.remove(eventFlag)
        default:
            break
        }

        return flags
    }

    private func currentModifierFlags() -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if keyIsDown(vkShift) || keyIsDown(vkLShift) || keyIsDown(vkRShift) {
            flags.insert(.shift)
        }
        if keyIsDown(vkControl) || keyIsDown(vkLControl) || keyIsDown(vkRControl) {
            flags.insert(.control)
        }
        if keyIsDown(vkMenu) || keyIsDown(vkLMenu) || keyIsDown(vkRMenu) {
            flags.insert(.option)
        }
        if keyIsDown(vkLWin) || keyIsDown(vkRWin) {
            flags.insert(.command)
        }
        return flags
    }

    private func modifierFlag(forVirtualKey virtualKey: UInt16) -> NSEvent.ModifierFlags? {
        switch Int32(virtualKey) {
        case vkShift, vkLShift, vkRShift:
            return .shift
        case vkControl, vkLControl, vkRControl:
            return .control
        case vkMenu, vkLMenu, vkRMenu:
            return .option
        case vkLWin, vkRWin:
            return .command
        default:
            return nil
        }
    }

    private func keyIsDown(_ virtualKey: Int32) -> Bool {
        (winGetKeyState(virtualKey) & Int16(bitPattern: 0x8000)) != 0
    }
}
#endif
