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
        var extendedStyle: DWORD = styleMask.contains(.utilityWindow) ? wsExToolWindow : 0
        if styleMask.contains(.nonactivatingPanel) {
            // A non-activating panel takes no key focus when shown.
            extendedStyle |= wsExNoActivate
        }
        let outerSize = outerWindowSize(forContentSize: frame.size, style: style, hasMenu: usesMainMenu)
        let hwnd = withWideString(winChocolateWindowClassName) { className in
            withWideString(title) { windowTitle in
                winCreateWindowExW(
                    extendedStyle,
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

        // A dark effective appearance gets the dark (immersive) title bar and
        // opts the process's popup menus into the system dark menu theme.
        // Resolved at creation, like every appearance-derived visual.
        if NSApplication.shared.effectiveAppearance.winIsDark {
            var enabled: Int32 = 1
            _ = winDwmSetWindowAttribute(
                hwnd, winDWMWAUseImmersiveDarkMode,
                &enabled, DWORD(MemoryLayout<Int32>.size)
            )
            Self.enableDarkMenusIfNeeded()
        }

        // The modern presentation asks Windows 11 for Fluent rounded corners
        // on every top-level window — framed windows already have them, and
        // this extends the look to borderless framework popups (popovers,
        // panels). A quiet no-op on Windows 10.
        if WinPresentation.selected == .modern {
            var corner = winDWMWCPRound
            _ = winDwmSetWindowAttribute(
                hwnd, winDWMWAWindowCornerPreference,
                &corner, DWORD(MemoryLayout<Int32>.size)
            )
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

    /// Updates a native top-level window's z-ordering level.
    ///
    /// Floating levels present tool-window chrome (no taskbar button) and pin
    /// the window to the topmost band so it stays above the application's
    /// normal windows; `.normal` returns it to the regular band.
    public func setWindowLevel(_ level: NSWindow.Level, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        let isFloating = level.rawValue > NSWindow.Level.normal.rawValue
        var extendedStyle = winGetWindowLongPtrW(hwnd, gwlExStyle)
        if isFloating {
            extendedStyle |= LONG_PTR(wsExToolWindow)
        } else {
            extendedStyle &= ~LONG_PTR(wsExToolWindow)
        }
        _ = winSetWindowLongPtrW(hwnd, gwlExStyle, extendedStyle)
        _ = winSetWindowPos(
            hwnd,
            isFloating ? hwndTopmost : hwndNoTopmost,
            0,
            0,
            0,
            0,
            swpNoMove | swpNoSize | swpNoActivate | swpFrameChanged
        )
    }

    /// Constrains a top-level window's content size during user resizing.
    public func setWindowContentSizeLimits(minSize: NSSize?, maxSize: NSSize?, for handle: NativeHandle) {
        if let minSize {
            windowMinContentSizes[handle.rawValue] = minSize
        } else {
            windowMinContentSizes.removeValue(forKey: handle.rawValue)
        }
        if let maxSize {
            windowMaxContentSizes[handle.rawValue] = maxSize
        } else {
            windowMaxContentSizes.removeValue(forKey: handle.rawValue)
        }
    }

    /// Updates whether a native window hides while the application is inactive.
    public func setHidesOnDeactivate(_ hidesOnDeactivate: Bool, for handle: NativeHandle) {
        if hidesOnDeactivate {
            hidesOnDeactivateHandles.insert(handle.rawValue)
        } else {
            hidesOnDeactivateHandles.remove(handle.rawValue)
            deactivateHiddenHandles.remove(handle.rawValue)
        }
    }

    /// Hides and restores hide-on-deactivate windows as the app activation changes.
    ///
    /// WM_ACTIVATEAPP arrives on every top-level window; the visibility check
    /// makes repeated sweeps idempotent so only windows this deactivation hid
    /// are restored on the next activation.
    func applicationActivationDidChange(isActive: Bool) {
        if isActive {
            for rawHandle in deactivateHiddenHandles {
                guard let hwnd = hwnd(from: NativeHandle(rawValue: rawHandle)) else {
                    continue
                }
                _ = winShowWindow(hwnd, swShowNoActivate)
            }
            deactivateHiddenHandles.removeAll()
            return
        }

        for rawHandle in hidesOnDeactivateHandles {
            guard let hwnd = hwnd(from: NativeHandle(rawValue: rawHandle)), winIsWindowVisible(hwnd) != 0 else {
                continue
            }
            _ = winShowWindow(hwnd, swHide)
            deactivateHiddenHandles.insert(rawHandle)
        }
    }

    /// Shows a native window.
    public func showWindow(_ handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winShowWindow(hwnd, swShow)
        _ = winUpdateWindow(hwnd)
    }

    /// The primary monitor's pixel frame.
    public func primaryScreenFrame() -> NSRect {
        NSRect(x: 0, y: 0, width: CGFloat(winGetSystemMetrics(smCxScreen)), height: CGFloat(winGetSystemMetrics(smCyScreen)))
    }

    /// Enumerates the attached monitors: full frame plus work area, primary first.
    public func screenDescriptions() -> [NativeScreenDescription] {
        final class MonitorCollector {
            var screens: [NativeScreenDescription] = []
        }

        let collector = MonitorCollector()
        let context = Unmanaged.passUnretained(collector).toOpaque()
        _ = winEnumDisplayMonitors(nil, nil, { monitor, _, _, data in
            var info = MONITORINFOW()
            info.cbSize = UINT(MemoryLayout<MONITORINFOW>.stride)
            if winGetMonitorInfoW(monitor, &info) != 0 {
                let collector = Unmanaged<MonitorCollector>.fromOpaque(UnsafeRawPointer(bitPattern: data)!).takeUnretainedValue()
                let description = NativeScreenDescription(
                    frame: NSRect(
                        x: CGFloat(info.rcMonitor.left),
                        y: CGFloat(info.rcMonitor.top),
                        width: CGFloat(info.rcMonitor.right - info.rcMonitor.left),
                        height: CGFloat(info.rcMonitor.bottom - info.rcMonitor.top)
                    ),
                    visibleFrame: NSRect(
                        x: CGFloat(info.rcWork.left),
                        y: CGFloat(info.rcWork.top),
                        width: CGFloat(info.rcWork.right - info.rcWork.left),
                        height: CGFloat(info.rcWork.bottom - info.rcWork.top)
                    )
                )
                // MONITORINFOF_PRIMARY: keep the primary display first.
                if info.dwFlags & 1 != 0 {
                    collector.screens.insert(description, at: 0)
                } else {
                    collector.screens.append(description)
                }
            }
            return 1
        }, LPARAM(Int(bitPattern: context)))

        if collector.screens.isEmpty {
            let frame = primaryScreenFrame()
            return [NativeScreenDescription(frame: frame, visibleFrame: frame)]
        }
        return collector.screens
    }

    /// Minimizes or restores a native window.
    public func setWindowMinimized(_ minimized: Bool, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }
        _ = winShowWindow(hwnd, minimized ? swMinimize : swRestore)
    }

    /// Toggles a native window between maximized and normal.
    public func toggleWindowZoom(_ handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }
        _ = winShowWindow(hwnd, winIsZoomed(hwnd) != 0 ? swRestore : swMaximize)
    }

    /// Moves a native window to the bottom of the z-order.
    public func orderWindowBack(_ handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }
        _ = winSetWindowPos(hwnd, hwndBottom, 0, 0, 0, 0, swpNoMove | swpNoSize | swpNoActivate)
    }

    /// Whether a native window is shown and not minimized.
    public func isWindowVisible(_ handle: NativeHandle) -> Bool {
        guard let hwnd = hwnd(from: handle) else {
            return false
        }
        return winIsWindowVisible(hwnd) != 0 && winIsIconic(hwnd) == 0
    }

    /// Whether a native window is minimized.
    public func isWindowMinimized(_ handle: NativeHandle) -> Bool {
        guard let hwnd = hwnd(from: handle) else {
            return false
        }
        return winIsIconic(hwnd) != 0
    }

    /// Whether a native window is maximized.
    public func isWindowZoomed(_ handle: NativeHandle) -> Bool {
        guard let hwnd = hwnd(from: handle) else {
            return false
        }
        return winIsZoomed(hwnd) != 0
    }

    /// Registers the action invoked when a native window moves.
    public func registerWindowMoveAction(for handle: NativeHandle, action: @escaping (NSPoint) -> Void) {
        windowMoveActions[handle.rawValue] = action
    }

    /// Reflects hidden standard title-bar buttons onto the native caption.
    public func setWindowButtonsHidden(closeHidden: Bool, minimizeHidden: Bool, zoomHidden: Bool, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        var style = winGetWindowLongPtrW(hwnd, gwlStyle)
        if minimizeHidden {
            style &= ~LONG_PTR(wsMinimizeBox)
        } else {
            style |= LONG_PTR(wsMinimizeBox)
        }
        if zoomHidden {
            style &= ~LONG_PTR(wsMaximizeBox)
        } else {
            style |= LONG_PTR(wsMaximizeBox)
        }
        _ = winSetWindowLongPtrW(hwnd, gwlStyle, style)

        // The close (X) can't be individually hidden on the classic caption, so
        // disable the system-menu close command instead (grays the X).
        if let systemMenu = winGetSystemMenu(hwnd, 0) {
            _ = winEnableMenuItem(systemMenu, scClose, mfByCommand | (closeHidden ? mfGrayed : mfEnabled))
        }
        _ = winSetWindowPos(hwnd, nil, 0, 0, 0, 0, swpNoMove | swpNoSize | swpNoZOrder | swpNoActivate | swpFrameChanged)
    }

    /// Shows or hides a native window with a short alpha-blend fade.
    public func fadeWindow(_ handle: NativeHandle, visible: Bool) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        let flags = visible ? awBlend : (awBlend | awHide)
        if winAnimateWindow(hwnd, 140, flags) == 0 {
            // Fall back to an unanimated show/hide if the animation is refused.
            _ = winShowWindow(hwnd, visible ? swShow : swHide)
        }
        if visible {
            _ = winUpdateWindow(hwnd)
        }
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
        hidesOnDeactivateHandles.remove(handle.rawValue)
        deactivateHiddenHandles.remove(handle.rawValue)
        contentScales.removeValue(forKey: handle.rawValue)
        richTextHandles.remove(handle.rawValue)
        multilineTextHandles.remove(handle.rawValue)
        windowDragViewHandles.remove(handle.rawValue)
        windowMinContentSizes.removeValue(forKey: handle.rawValue)
        windowMaxContentSizes.removeValue(forKey: handle.rawValue)
        mainMenuWindowHandles.remove(handle)
        controlActions.removeValue(forKey: handle.rawValue)
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
        windowCloseActions.removeValue(forKey: handle.rawValue)
        windowShouldCloseHandlers.removeValue(forKey: handle.rawValue)
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
        contentScales.removeValue(forKey: handle.rawValue)
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

        // Magnified custom views occupy their logical frame times the
        // content scale on screen; drawing scales through a matching
        // world transform during paint.
        var scaledFrame = frame
        if let scale = contentScales[handle.rawValue], scale != 1 {
            scaledFrame = NSRect(
                x: frame.origin.x * scale,
                y: frame.origin.y * scale,
                width: frame.size.width * scale,
                height: frame.size.height * scale
            )
        }

        _ = winMoveWindow(
            hwnd,
            Int32(scaledFrame.origin.x),
            Int32(scaledFrame.origin.y),
            Int32(scaledFrame.size.width),
            Int32(max(scaledFrame.size.height, comboBoxDropdownHeights[handle.rawValue] ?? scaledFrame.size.height)),
            1
        )

        // Custom views can overlap sibling children (drag previews); moving
        // them must repaint the trail they leave across those siblings.
        if customViewHandles.contains(handle.rawValue), let parent = winGetParent(hwnd) {
            _ = winRedrawWindow(parent, nil, nil, rdwInvalidate | rdwErase | rdwAllChildren)
        }
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
