#if os(Windows)
extension Win32NativeControlBackend {
    func dispatchNotificationsMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        switch message {
        case wmNotify:
            return handleNotifyWindowMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
        default:
            return nil
        }
    }

    func handleNotifyWindowMessage(
        hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM
    ) -> LRESULT? {
        guard lParam != 0,
              let header = UnsafeRawPointer(bitPattern: lParam)?.assumingMemoryBound(to: NMHDR.self).pointee else {
            return nil
        }

        switch header.code {
        case dtnDropDown:
            return handleDatePickerDropDownNotification(header: header)
        case hdnItemClickA, hdnItemClickW:
            return handleTableHeaderClickNotification(header: header, lParam: lParam)
        case udnDeltapos:
            return handleStepperDeltaNotification(header: header, lParam: lParam)
        case tcnSelChange:
            return handleTabSelectionNotification(header: header)
        case dtnDateTimeChange:
            return handleDateChangeNotification(header: header)
        case nmCustomDraw:
            return handleTableCustomDrawNotification(header: header, lParam: lParam)
        case lvnEndLabelEditW:
            return handleTableLabelEditNotification(header: header, lParam: lParam)
        default:
            if let result = handleMonthCalendarNotification(header: header) {
                return result
            }
            return handleListViewNotification(header: header, lParam: lParam)
        }
    }

    func handleDatePickerDropDownNotification(
        header: NMHDR
    ) -> LRESULT? {
    if header.code == dtnDropDown,
       let picker = header.hwndFrom {
        let calendar = HWND(bitPattern: winSendMessageW(picker, dtmGetMonthCal, 0, 0))
        if let calendar {
            if NSApplication.shared.effectiveAppearance.winIsDark {
                applyDarkCalendarColorsIfNeeded(calendar)
            }
            // The drop-down popup opens at a default height that clips
            // the calendar's last week row and "Today" footer; grow the
            // popup (the calendar's parent window) to the calendar's
            // own minimum required size.
            var required = RECT()
            let ok = withUnsafeMutablePointer(to: &required) { pointer in
                winSendMessageW(calendar, mcmGetMinReqRect, 0, LPARAM(bitPattern: pointer))
            }
            if ok != 0 {
                let width = Int32(required.right - required.left)
                let height = Int32(required.bottom - required.top)
                _ = winSetWindowPos(calendar, nil, 0, 0, width, height, swpNoMove | swpNoZOrder | swpNoActivate)
                if let popup = winGetParent(calendar) {
                    _ = winSetWindowPos(popup, nil, 0, 0, width, height, swpNoMove | swpNoZOrder | swpNoActivate)
                }
            }
        }
        return nil
    }

    // (The dark list-view header is owner-drawn by subclassing the
    // header window's WM_PAINT — see `drawDarkTableHeader` — because its
    // NM_CUSTOMDRAW is not forwarded to the top-level window here.)
        return nil
    }

    func handleTableHeaderClickNotification(
        header: NMHDR,
        lParam: LPARAM
    ) -> LRESULT? {
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
        // Defer the sort action past this header notification so a
        // reloadData() inside it never mutates the native list
        // mid-notification (classic-backend reentrancy protection).
        dispatchAsync { action() }
        return 0
    }
        return nil
    }

    func handleStepperDeltaNotification(
        header: NMHDR,
        lParam: LPARAM
    ) -> LRESULT? {
    if header.code == udnDeltapos {
        guard let source = header.hwndFrom else {
            return nil
        }

        let handle = nativeHandle(from: source)
        guard stepperRanges[handle.rawValue] != nil else {
            return nil
        }

        // Apply the arrow's delta as one framework increment and fire
        // the registered action; returning 1 blocks the control's own
        // unit step so the framework's increment is the only change.
        if let upDown = UnsafeRawPointer(bitPattern: lParam)?.assumingMemoryBound(to: NMUPDOWN.self).pointee {
            WinDiagnostics.log("stepper.deltaPos pos=\(upDown.iPos) delta=\(upDown.iDelta) action=\(controlActions[handle.rawValue] != nil)")
            updateStepperPosition(position: upDown.iPos, delta: upDown.iDelta, for: handle)
            controlActions[handle.rawValue]?()
        }
        return 1
    }
        return nil
    }

    func handleTabSelectionNotification(
        header: NMHDR
    ) -> LRESULT? {
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
        return nil
    }

    func handleDateChangeNotification(
        header: NMHDR
    ) -> LRESULT? {
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
        return nil
    }

    func handleMonthCalendarNotification(
        header: NMHDR
    ) -> LRESULT? {
    if let source = header.hwndFrom {
        let handle = nativeHandle(from: source)
        if monthCalHandles.contains(handle.rawValue) {
            if let current = datePickerDate(for: handle) {
                let previous = monthCalDates[handle.rawValue]
                if previous.map({ abs(current.timeIntervalSince1970 - $0.timeIntervalSince1970) >= 1 }) ?? true {
                    monthCalDates[handle.rawValue] = current
                    controlActions[handle.rawValue]?()
                }
            }
            return 0
        }
    }

        return nil
    }

    func handleTableCustomDrawNotification(
        header: NMHDR,
        lParam: LPARAM
    ) -> LRESULT? {
    if header.code == nmCustomDraw, let source = header.hwndFrom {
        let handle = nativeHandle(from: source)
        guard tableClickedRows[handle.rawValue] != nil,
              let draw = UnsafeMutableRawPointer(bitPattern: lParam)?.assumingMemoryBound(to: NMLVCUSTOMDRAW.self) else {
            return nil
        }

        switch draw.pointee.nmcd.dwDrawStage {
        case cddsPrePaint:
            return cdrfNotifyItemDraw
        case cddsItemPrePaint:
            let item = draw.pointee.nmcd.dwItemSpec
            let state = winSendMessageW(source, lvmGetItemState, WPARAM(item), LPARAM(lvisSelected))
            if (UINT(truncatingIfNeeded: state) & lvisSelected) != 0, winGetFocus() != source {
                // The themed painter takes its "selected" path for the
                // item and ignores the color pair; strip the selected
                // bit so it paints a plain item with these colors.
                draw.pointee.nmcd.uItemState &= ~cdisSelected
                draw.pointee.clrTextBk = colorRef(from: .unemphasizedSelectedContentBackgroundColor)
                draw.pointee.clrText = colorRef(from: .textColor)
            }
            return cdrfDoDefault
        default:
            return cdrfDoDefault
        }
    }
        return nil
    }

    func handleTableLabelEditNotification(
        header: NMHDR,
        lParam: LPARAM
    ) -> LRESULT? {
    if header.code == lvnEndLabelEditW, let source = header.hwndFrom {
        let handle = nativeHandle(from: source)
        let info = UnsafeRawPointer(bitPattern: lParam)?.assumingMemoryBound(to: NMLVDISPINFOW.self).pointee
        // pszText is nil when the edit was canceled.
        if let info, let textPointer = info.item.pszText {
            var length = 0
            while textPointer[length] != 0 {
                length += 1
            }
            let text = String(decoding: UnsafeBufferPointer(start: textPointer, count: length), as: UTF16.self)
            tableEditActions[handle.rawValue]?(Int(info.item.iItem), 0, text)
            return 1
        }
        return 0
    }
        return nil
    }

    func handleListViewNotification(
        header: NMHDR,
        lParam: LPARAM
    ) -> LRESULT? {
        guard let notification = UnsafeRawPointer(bitPattern: lParam)?.assumingMemoryBound(to: NMLISTVIEW.self).pointee,
              let source = header.hwndFrom else {
            return nil
        }

        let handle = nativeHandle(from: source)
        switch header.code {
        case lvnColumnClick:
            return handleListColumnClick(notification: notification, source: source, handle: handle)
        case nmClick:
            return handleListClick(notification: notification, source: source, handle: handle)
        case nmDblclk:
            return handleListDoubleClick(notification: notification, source: source, handle: handle)
        case lvnItemChanged:
            return handleListSelectionChange(notification: notification, handle: handle)
        default:
            return nil
        }
    }

    func handleListColumnClick(notification: NMLISTVIEW, source: HWND, handle: NativeHandle) -> LRESULT? {
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
        // Defer the sort action past this column-click notification
        // (classic-backend reentrancy protection; see the header case).
        dispatchAsync { action() }
        return 0
    }

    func handleListClick(notification: NMLISTVIEW, source: HWND, handle: NativeHandle) -> LRESULT? {
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
    }

    func handleListDoubleClick(notification: NMLISTVIEW, source: HWND, handle: NativeHandle) -> LRESULT? {
        guard let doubleAction = tableDoubleClickActions[handle.rawValue] else {
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
        doubleAction()
        return 0
    }

    func handleListSelectionChange(notification: NMLISTVIEW, handle: NativeHandle) -> LRESULT? {
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
    }
}
#endif
