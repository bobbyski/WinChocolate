#if os(Windows)
extension Win32NativeControlBackend {
    /// Registers a native window close action.
    public func registerWindowCloseAction(for handle: NativeHandle, action: @escaping () -> Void) {
        windowCloseActions[handle.rawValue] = action
    }

    /// Registers the action to perform when a native top-level window resizes.
    public func registerWindowResizeAction(for handle: NativeHandle, action: @escaping (NSSize) -> Void) {
        windowResizeActions[handle.rawValue] = action
    }

    /// Destroys a native child control.
    public func destroyControl(_ handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winDestroyWindow(hwnd)
        controlActions.removeValue(forKey: handle.rawValue)
        contentScales.removeValue(forKey: handle.rawValue)
        lastFrameDeviceRects.removeValue(forKey: handle.rawValue)
        richTextHandles.remove(handle.rawValue)
        multilineTextHandles.remove(handle.rawValue)
        windowDragViewHandles.remove(handle.rawValue)
        textChangeActions.removeValue(forKey: handle.rawValue)
        focusChangeActions.removeValue(forKey: handle.rawValue)
        mouseDownActions.removeValue(forKey: handle.rawValue)
        mouseUpActions.removeValue(forKey: handle.rawValue)
        mouseMovedActions.removeValue(forKey: handle.rawValue)
        mouseDraggedActions.removeValue(forKey: handle.rawValue)
        rightMouseDownActions.removeValue(forKey: handle.rawValue)
        rightMouseUpActions.removeValue(forKey: handle.rawValue)
        otherMouseDownActions.removeValue(forKey: handle.rawValue)
        otherMouseUpActions.removeValue(forKey: handle.rawValue)
        scrollWheelActions.removeValue(forKey: handle.rawValue)
        cursorRegions.removeValue(forKey: handle.rawValue)
        drawActions.removeValue(forKey: handle.rawValue)
        marqueePositions.removeValue(forKey: handle.rawValue)
        keyDownActions.removeValue(forKey: handle.rawValue)
        keyUpActions.removeValue(forKey: handle.rawValue)
        toolbarActions.removeValue(forKey: handle.rawValue)
        originalControlProcedures.removeValue(forKey: handle.rawValue)
        controlHandleAliases = controlHandleAliases.filter { $0.value != handle }
        tableColumnTitles.removeValue(forKey: handle.rawValue)
        tableHeaderOwners = tableHeaderOwners.filter { $0.value != handle }
        tableSuppressedColumnClicks.removeValue(forKey: handle.rawValue)
        tableClickedRows.removeValue(forKey: handle.rawValue)
        tableClickedColumns.removeValue(forKey: handle.rawValue)
        sliderRanges.removeValue(forKey: handle.rawValue)
        trackbarHandles.remove(handle.rawValue)
        scrollViewMetrics.removeValue(forKey: handle.rawValue)
        stepperRanges.removeValue(forKey: handle.rawValue)
        groupBoxHandles.remove(handle.rawValue)
        customViewHandles.remove(handle.rawValue)
        transparentBackgroundHandles.remove(handle.rawValue)
        clearAppearance(for: handle)
    }

    /// Updates the visible text for a native control.
    public func setText(_ text: String, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        withWideString(text) { value in
            _ = winSetWindowTextW(hwnd, value)
        }
        // WM_SETTEXT resets a rich edit's character formatting to the default
        // (black); restore the control's chosen or appearance-derived color.
        if richTextHandles.contains(handle.rawValue) {
            applyRichEditTextColor(hwnd, handle: handle)
        }
        invalidate(handle)
    }

    /// Updates the native frame for a window or control.
    public func setFrame(_ frame: NSRect, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        // All incoming frames are in logical points; convert to device pixels
        // at the display scale (10.7). A no-op at 100% (scale 1).
        let dpi = winDeviceScale

        // Top-level frames are content-area sizes; grow to the outer rect so
        // the client area matches, mirroring the creation path.
        if setTopLevelFrame(frame, handle: handle, hwnd: hwnd, scale: dpi) {
            return
        }

        // Child controls occupy their logical frame times the device scale
        // (10.7 DPI) and any per-view magnification (3.3); custom-view drawing
        // scales through a matching world transform during paint.
        let scale = dpi * (contentScales[handle.rawValue] ?? 1)
        let scaledFrame = scale == 1 ? frame : NSRect(
            x: frame.origin.x * scale,
            y: frame.origin.y * scale,
            width: frame.size.width * scale,
            height: frame.size.height * scale
        )

        let rect = WinDeviceRect(
            x: Int32(scaledFrame.origin.x),
            y: Int32(scaledFrame.origin.y),
            width: Int32(scaledFrame.size.width),
            height: Int32(max(scaledFrame.size.height, comboBoxDropdownHeights[handle.rawValue] ?? scaledFrame.size.height))
        )
        // Skip the native move (and its repaint) when the control is already at
        // this exact device rect — the duplicate-update flicker guard.
        let previous = lastFrameDeviceRects[handle.rawValue]
        guard previous.map({ $0 != rect }) ?? true else {
            return
        }
        lastFrameDeviceRects[handle.rawValue] = rect

        let sizeChanged = previous.map { $0.width != rect.width || $0.height != rect.height } ?? true
        if sizeChanged {
            // A resize genuinely changes content extent, so repaint the control.
            _ = winMoveWindow(hwnd, rect.x, rect.y, rect.width, rect.height, 1)
            // A shrinking custom view can uncover siblings behind it; repaint
            // the area it vacated so no stale pixels remain.
            if customViewHandles.contains(handle.rawValue), let parent = winGetParent(hwnd) {
                _ = winRedrawWindow(parent, nil, nil, rdwInvalidate | rdwErase | rdwAllChildren)
            }
        } else {
            // A pure move (the scroll/reposition hot path): SetWindowPos copies
            // the window's existing pixels to the new position and invalidates
            // only the genuinely-new regions (the strip scrolled into view and
            // the area vacated on the parent). This replaces
            // MoveWindow(bRepaint: true) — which repainted the *entire* (often
            // large) window every step — and the blanket parent+all-children
            // redraw that erased and repainted the whole scroll area each notch.
            // The result is smooth, minimal-repaint scrolling.
            _ = winSetWindowPos(hwnd, nil, rect.x, rect.y, 0, 0, swpNoSize | swpNoZOrder | swpNoActivate)
        }
    }

    private func setTopLevelFrame(_ frame: NSRect, handle: NativeHandle, hwnd: HWND, scale: CGFloat) -> Bool {
        guard windowHandles.contains(handle), let style = windowStyles[handle.rawValue] else { return false }
        let contentSize = NSSize(width: frame.size.width * scale, height: frame.size.height * scale)
        let outerSize = outerWindowSize(
            forContentSize: contentSize,
            style: style,
            hasMenu: windowMenuFlags[handle.rawValue] ?? false
        )
        let rect = WinDeviceRect(
            x: Int32((frame.origin.x * scale).rounded()),
            y: Int32((frame.origin.y * scale).rounded()),
            width: outerSize.width,
            height: outerSize.height
        )
        let previous = lastFrameDeviceRects[handle.rawValue]
        guard previous.map({ $0 != rect }) ?? true else { return true }
        lastFrameDeviceRects[handle.rawValue] = rect
        let sizeChanged = previous.map { $0.width != rect.width || $0.height != rect.height } ?? true
        if sizeChanged {
            _ = winMoveWindow(hwnd, rect.x, rect.y, rect.width, rect.height, 1)
        } else {
            _ = winSetWindowPos(hwnd, nil, rect.x, rect.y, 0, 0, swpNoSize | swpNoZOrder | swpNoActivate)
        }
        return true
    }

    /// Updates the content scale applied to a custom-drawn view.
    public func setContentScale(_ scale: CGFloat, for handle: NativeHandle) {
        if scale == 1 {
            contentScales.removeValue(forKey: handle.rawValue)
        } else {
            contentScales[handle.rawValue] = scale
        }
        invalidateControl(handle)
    }

    /// Raises a native child control above sibling controls.
    public func raiseControl(_ handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winSetWindowPos(hwnd, nil, 0, 0, 0, 0, swpNoMove | swpNoSize | swpNoActivate | swpShowWindow)
        _ = winInvalidateRect(hwnd, nil, 1)
        _ = winUpdateWindow(hwnd)
        if let parent = winGetParent(hwnd) {
            _ = winInvalidateRect(parent, nil, 0)
            _ = winUpdateWindow(parent)
        }
    }

    /// Updates whether a native control is hidden.
    public func setHidden(_ isHidden: Bool, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winShowWindow(hwnd, isHidden ? swHide : swShow)
        _ = winInvalidateRect(hwnd, nil, 1)
        _ = winUpdateWindow(hwnd)
        if let parent = winGetParent(hwnd) {
            // Redraw sibling children too: hiding an overlapping child (such
            // as a drag preview) otherwise leaves stale pixels on them.
            _ = winRedrawWindow(parent, nil, nil, rdwInvalidate | rdwErase | rdwAllChildren | rdwUpdateNow)
        }
    }

    /// Updates whether a native control is enabled.
    public func setEnabled(_ isEnabled: Bool, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winEnableWindow(hwnd, isEnabled ? 1 : 0)
    }

    /// Moves native keyboard focus to a control.
    public func focusControl(_ handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winSetFocus(hwnd)
    }

    /// Updates native tooltip text, backed by a shared tooltips_class32 host
    /// so hovering the control shows the AppKit `toolTip` as a native bubble.
    public func setToolTip(_ toolTip: String?, for handle: NativeHandle) {
        guard let controlHwnd = hwnd(from: handle) else { return }
        applyNativeToolTip(toolTip, forControl: controlHwnd)
    }

    func createNativeMenu(from menu: NSMenu?) -> HMENU? {
        guard let menu else {
            return nil
        }

        let nativeMenu = winCreateMenu()
        appendItems(of: menu, to: nativeMenu)
        return nativeMenu
    }

    private func createNativePopupMenu(from menu: NSMenu) -> HMENU? {
        let nativeMenu = winCreatePopupMenu()
        appendItems(of: menu, to: nativeMenu)
        return nativeMenu
    }

    private func appendItems(of menu: NSMenu, to nativeMenu: HMENU?) {
        var registryEntries: [(identifier: UInt, item: NSMenuItem)] = []
        for item in menu.items {
            guard !item.isHidden else {
                continue
            }

            if let submenu = item.submenu, let nativeSubmenu = createNativePopupMenu(from: submenu) {
                withWideString(item.title) { title in
                    _ = winAppendMenuW(nativeMenu, mfPopup | menuStateFlags(for: item), UInt(bitPattern: nativeSubmenu), title)
                }
                continue
            }

            if item.isSeparatorItem {
                _ = winAppendMenuW(nativeMenu, mfSeparator, 0, nil)
                continue
            }

            let commandIdentifier = nextCommandID()
            commandActions[commandIdentifier] = { [weak item] in
                _ = item?.performAction()
            }
            registryEntries.append((commandIdentifier, item))

            withWideString(menuItemDisplayTitle(for: item)) { title in
                _ = winAppendMenuW(nativeMenu, mfString | menuStateFlags(for: item), commandIdentifier, title)
            }
        }

        // Registered so WM_INITMENUPOPUP can rebuild and validate this menu
        // just before it displays.
        if let nativeMenu {
            nativeMenuRegistry[UInt(bitPattern: nativeMenu)] = (menu, registryEntries)
        }
    }

    /// The native item title, including right-aligned accelerator text.
    private func menuItemDisplayTitle(for item: NSMenuItem) -> String {
        guard !item.keyEquivalent.isEmpty else {
            return item.title
        }

        var accelerator = "Ctrl+"
        if item.keyEquivalentModifierMask.contains(.shift) {
            accelerator += "Shift+"
        }
        if item.keyEquivalentModifierMask.contains(.option) {
            accelerator += "Alt+"
        }
        accelerator += item.keyEquivalent.uppercased()
        return "\(item.title)\t\(accelerator)"
    }

    /// Rebuilds a native popup's items from its menu just before display.
    ///
    /// Menus can gain, lose, or retitle items at any time (dynamic titles,
    /// recent-file lists), so WM_INITMENUPOPUP replaces the native items
    /// wholesale instead of only syncing enabled/checked state.
    func rebuildNativeMenu(_ menu: NSMenu, forRegistryKey nativeMenuKey: UInt) {
        guard let nativeMenu = HMENU(bitPattern: nativeMenuKey) else {
            return
        }

        if let previous = nativeMenuRegistry[nativeMenuKey] {
            for entry in previous.entries {
                commandActions.removeValue(forKey: entry.identifier)
            }
        }

        let count = winGetMenuItemCount(nativeMenu)
        for index in stride(from: count - 1, through: 0, by: -1) {
            if let submenu = winGetSubMenu(nativeMenu, index) {
                purgeMenuRegistry(for: submenu)
            }
            _ = winDeleteMenu(nativeMenu, UINT(index), mfByPosition)
        }

        appendItems(of: menu, to: nativeMenu)
    }

    /// Forgets registry and command entries for a native submenu tree.
    private func purgeMenuRegistry(for nativeMenu: HMENU) {
        let count = winGetMenuItemCount(nativeMenu)
        for index in 0..<max(count, 0) {
            if let submenu = winGetSubMenu(nativeMenu, index) {
                purgeMenuRegistry(for: submenu)
            }
        }

        guard let entry = nativeMenuRegistry.removeValue(forKey: UInt(bitPattern: nativeMenu)) else {
            return
        }
        for registered in entry.entries {
            commandActions.removeValue(forKey: registered.identifier)
        }
    }

    private func menuStateFlags(for item: NSMenuItem) -> UINT {
        var flags: UINT = item.isEnabled ? 0 : mfGrayed
        if item.state == .on {
            flags |= mfChecked
        }
        return flags
    }

    /// Runs a native context menu at a screen point, returning the performed item.
    public func runContextMenu(_ menu: NSMenu, atScreenPoint point: NSPoint) -> NSMenuItem? {
        menu.update()
        // TrackPopupMenu needs an owner window for its message routing; any
        // framework window works because TPM_RETURNCMD skips WM_COMMAND.
        guard let owner = (mainMenuWindowHandles.first ?? windowHandles.first).flatMap({ hwnd(from: $0) }),
              let nativeMenu = winCreatePopupMenu() else {
            return nil
        }

        var itemsByCommand: [UInt: NSMenuItem] = [:]
        appendContextMenuItems(menu.items, to: nativeMenu, itemsByCommand: &itemsByCommand)
        defer {
            _ = winDestroyMenu(nativeMenu)
        }

        let selectedCommand = winTrackPopupMenu(
            nativeMenu,
            tpmReturnCmd | tpmLeftAlign,
            Int32(point.x),
            Int32(point.y),
            0,
            owner,
            nil
        )
        guard selectedCommand > 0, let item = itemsByCommand[UInt(selectedCommand)] else {
            return nil
        }

        _ = item.performAction()
        return item
    }

    private func appendContextMenuItems(_ items: [NSMenuItem], to nativeMenu: HMENU, itemsByCommand: inout [UInt: NSMenuItem]) {
        for item in items {
            guard !item.isHidden else {
                continue
            }

            if let submenu = item.submenu, let nativeSubmenu = winCreatePopupMenu() {
                appendContextMenuItems(submenu.items, to: nativeSubmenu, itemsByCommand: &itemsByCommand)
                withWideString(item.title) { title in
                    _ = winAppendMenuW(nativeMenu, mfPopup | menuStateFlags(for: item), UInt(bitPattern: nativeSubmenu), title)
                }
                continue
            }

            if item.isSeparatorItem {
                _ = winAppendMenuW(nativeMenu, mfSeparator, 0, nil)
                continue
            }

            // Context selections come back through TPM_RETURNCMD instead of
            // WM_COMMAND, so ids map to items locally rather than through
            // the backend's commandActions table.
            let commandIdentifier = nextCommandID()
            itemsByCommand[commandIdentifier] = item
            withWideString(item.title) { title in
                _ = winAppendMenuW(nativeMenu, mfString | menuStateFlags(for: item), commandIdentifier, title)
            }
        }
    }

    func windowStyle(from styleMask: NSWindow.StyleMask) -> DWORD {
        // WS_OVERLAPPED always draws a caption, so borderless windows
        // (sheets, popovers) need the popup style with a plain border.
        var style = styleMask.contains(.titled) ? wsOverlapped : wsPopup | wsBorder

        if styleMask.contains(.titled) {
            style |= wsCaption | wsSysMenu
        }

        if styleMask.contains(.closable) {
            style |= wsSysMenu
        }

        if styleMask.contains(.miniaturizable) {
            style |= wsMinimizeBox
        }

        if styleMask.contains(.resizable) {
            style |= wsThickFrame | wsMaximizeBox
        }

        return style | wsClipChildren
    }

    func text(from hwnd: HWND?) -> String {
        let length = Int(winGetWindowTextLengthW(hwnd))
        var buffer = Array(repeating: UInt16(0), count: length + 1)
        let maximumCount = Int32(buffer.count)
        let copiedCount = buffer.withUnsafeMutableBufferPointer { pointer in
            winGetWindowTextW(hwnd, pointer.baseAddress, maximumCount)
        }
        return String(decoding: buffer.prefix(Int(copiedCount)), as: UTF16.self)
    }
}
#endif
