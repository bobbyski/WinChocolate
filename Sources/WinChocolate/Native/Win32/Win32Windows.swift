#if os(Windows)
extension Win32NativeControlBackend {
    /// Installs the native application menu bar.
    public func installMainMenu(_ menu: NSMenu?) {
        mainMenu = menu
        nativeMenuRegistry.removeAll()

        for windowHandle in mainMenuWindowHandles {
            guard let hwnd = hwnd(from: windowHandle) else {
                continue
            }

            _ = winSetMenu(hwnd, createNativeMenu(from: menu))
            _ = winDrawMenuBar(hwnd)
        }
    }

    /// Creates a native top-level window.
    public func createWindow(title: String, frame: NSRect, styleMask: NSWindow.StyleMask, usesMainMenu: Bool) -> NativeHandle {
        registerWindowClassIfNeeded()

        // AppKit's contentRect describes the content area; grow the native
        // rect so the client area matches the requested size exactly.
        let style = windowStyle(from: styleMask)
        let outerSize = outerWindowSize(forContentSize: frame.size, style: style, hasMenu: usesMainMenu)
        let hwnd = withWideString(winChocolateWindowClassName) { className in
            withWideString(title) { windowTitle in
                winCreateWindowExW(
                    0,
                    className,
                    windowTitle,
                    style,
                    Int32(frame.origin.x),
                    Int32(frame.origin.y),
                    outerSize.width,
                    outerSize.height,
                    nil,
                    usesMainMenu ? createNativeMenu(from: mainMenu) : nil,
                    winGetModuleHandleW(nil),
                    nil
                )
            }
        }

        guard let hwnd else {
            print("WinChocolate: CreateWindowExW failed with error \(winGetLastError()).")
            return NativeHandle(rawValue: 0)
        }

        let handle = nativeHandle(from: hwnd)
        windowHandles.insert(handle)
        windowStyles[handle.rawValue] = style
        windowMenuFlags[handle.rawValue] = usesMainMenu
        if usesMainMenu {
            mainMenuWindowHandles.insert(handle)
        }
        return handle
    }

    /// Shows a native window.
    public func showWindow(_ handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winShowWindow(hwnd, swShow)
        _ = winUpdateWindow(hwnd)
    }

    /// Closes a native window.
    public func closeWindow(_ handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winDestroyWindow(hwnd)
        windowHandles.remove(handle)
        windowStyles.removeValue(forKey: handle.rawValue)
        windowMenuFlags.removeValue(forKey: handle.rawValue)
        mainMenuWindowHandles.remove(handle)
        controlActions.removeValue(forKey: handle.rawValue)
        textChangeActions.removeValue(forKey: handle.rawValue)
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
        windowCloseActions.removeValue(forKey: handle.rawValue)
        windowResizeActions.removeValue(forKey: handle.rawValue)
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
        comboBoxHandles.remove(handle.rawValue)
        comboBoxDropdownHeights.removeValue(forKey: handle.rawValue)
        groupBoxHandles.remove(handle.rawValue)
        customViewHandles.remove(handle.rawValue)
        transparentBackgroundHandles.remove(handle.rawValue)
        clearAppearance(for: handle)
    }

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
        textChangeActions.removeValue(forKey: handle.rawValue)
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
        invalidate(handle)
    }

    /// Updates the native frame for a window or control.
    public func setFrame(_ frame: NSRect, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        // Top-level frames are content-area sizes; grow to the outer rect so
        // the client area matches, mirroring the creation path.
        if windowHandles.contains(handle), let style = windowStyles[handle.rawValue] {
            let outerSize = outerWindowSize(
                forContentSize: frame.size,
                style: style,
                hasMenu: windowMenuFlags[handle.rawValue] ?? false
            )
            _ = winMoveWindow(hwnd, Int32(frame.origin.x), Int32(frame.origin.y), outerSize.width, outerSize.height, 1)
            return
        }

        _ = winMoveWindow(
            hwnd,
            Int32(frame.origin.x),
            Int32(frame.origin.y),
            Int32(frame.size.width),
            Int32(max(frame.size.height, comboBoxDropdownHeights[handle.rawValue] ?? frame.size.height)),
            1
        )

        // Custom views can overlap sibling children (drag previews); moving
        // them must repaint the trail they leave across those siblings.
        if customViewHandles.contains(handle.rawValue), let parent = winGetParent(hwnd) {
            _ = winRedrawWindow(parent, nil, nil, rdwInvalidate | rdwErase | rdwAllChildren)
        }
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

    /// Updates native tooltip text.
    public func setToolTip(_ toolTip: String?, for handle: NativeHandle) {
        // Stored at the backend boundary for now; native tooltips will be backed
        // by tooltips_class32 when the control wrapper is added.
    }

    private func createNativeMenu(from menu: NSMenu?) -> HMENU? {
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

            withWideString(item.title) { title in
                _ = winAppendMenuW(nativeMenu, mfString | menuStateFlags(for: item), commandIdentifier, title)
            }
        }

        // Registered so WM_INITMENUPOPUP can run AppKit-style validation and
        // sync enabled/checked state just before this menu displays.
        if let nativeMenu {
            nativeMenuRegistry[UInt(bitPattern: nativeMenu)] = (menu, registryEntries)
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

    private func windowStyle(from styleMask: NSWindow.StyleMask) -> DWORD {
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
