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
        // The content rect is in logical points; size the outer window in
        // device pixels at the display scale (10.7). A no-op at 100%.
        let dpi = winDeviceScale
        let deviceContentSize = NSSize(width: frame.size.width * dpi, height: frame.size.height * dpi)
        let outerSize = outerWindowSize(forContentSize: deviceContentSize, style: style, hasMenu: usesMainMenu)
        let hwnd = withWideString(winChocolateWindowClassName) { className in
            withWideString(title) { windowTitle in
                winCreateWindowExW(
                    extendedStyle,
                    className,
                    windowTitle,
                    style,
                    Int32((frame.origin.x * dpi).rounded()),
                    Int32((frame.origin.y * dpi).rounded()),
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
        configureWindowAppearance(hwnd)

        let handle = nativeHandle(from: hwnd)
        windowHandles.insert(handle)
        windowStyles[handle.rawValue] = style
        windowMenuFlags[handle.rawValue] = usesMainMenu
        if usesMainMenu {
            mainMenuWindowHandles.insert(handle)
        }
        return handle
    }

    private func configureWindowAppearance(_ hwnd: HWND) {
        if NSApplication.shared.effectiveAppearance.winIsDark {
            var enabled: Int32 = 1
            _ = winDwmSetWindowAttribute(
                hwnd, winDWMWAUseImmersiveDarkMode,
                &enabled, DWORD(MemoryLayout<Int32>.size)
            )
            Self.enableDarkMenusIfNeeded()
        }

        guard WinPresentation.selected == .modern else {
            return
        }
        var corner = winDWMWCPRound
        _ = winDwmSetWindowAttribute(
            hwnd, winDWMWAWindowCornerPreference,
            &corner, DWORD(MemoryLayout<Int32>.size)
        )
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
    /// Makes `handle` an owned window of `parent` (AppKit's panel-to-owner
    /// relationship). Win32 expresses ownership as the window's `GWLP_HWNDPARENT`
    /// — for a non-`WS_CHILD` window that sets the *owner*, not a parent, so the
    /// panel stays a top-level window while gaining the owned behaviour:
    /// always above its owner, minimizing and restoring with it, and absent from
    /// the taskbar.
    public func setWindowParent(_ parent: NativeHandle, for handle: NativeHandle) {
        guard let panelHwnd = hwnd(from: handle), let ownerHwnd = hwnd(from: parent), panelHwnd != ownerHwnd else {
            return
        }

        _ = winSetWindowLongPtrW(panelHwnd, gwlpHwndParent, Int(bitPattern: ownerHwnd))
    }

    /// Performs the `setHidesOnDeactivate` operation.
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
        // System metrics are device pixels; report the frame in logical points
        // so window centering/placement stays point-based (10.7).
        NSRect(x: 0, y: 0,
               width: winToPoints(CGFloat(winGetSystemMetrics(smCxScreen))),
               height: winToPoints(CGFloat(winGetSystemMetrics(smCyScreen))))
    }

    /// Enumerates the attached monitors: full frame plus work area, primary first.
    public func screenDescriptions() -> [NativeScreenDescription] {
        final class MonitorCollector {
            var screens: [NativeScreenDescription] = []
            var scale: CGFloat = 1
        }

        let collector = MonitorCollector()
        collector.scale = winDeviceScale  // report monitor frames in points (10.7)
        let context = Unmanaged.passUnretained(collector).toOpaque()
        _ = winEnumDisplayMonitors(nil, nil, { monitor, _, _, data in
            var info = MONITORINFOW()
            info.cbSize = UINT(MemoryLayout<MONITORINFOW>.stride)
            if winGetMonitorInfoW(monitor, &info) != 0 {
                guard let pointer = UnsafeRawPointer(bitPattern: data) else {
                    return 0
                }
                let collector = Unmanaged<MonitorCollector>.fromOpaque(pointer).takeUnretainedValue()
                let s = collector.scale
                let description = NativeScreenDescription(
                    frame: NSRect(
                        x: CGFloat(info.rcMonitor.left) / s,
                        y: CGFloat(info.rcMonitor.top) / s,
                        width: CGFloat(info.rcMonitor.right - info.rcMonitor.left) / s,
                        height: CGFloat(info.rcMonitor.bottom - info.rcMonitor.top) / s
                    ),
                    visibleFrame: NSRect(
                        x: CGFloat(info.rcWork.left) / s,
                        y: CGFloat(info.rcWork.top) / s,
                        width: CGFloat(info.rcWork.right - info.rcWork.left) / s,
                        height: CGFloat(info.rcWork.bottom - info.rcWork.top) / s
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

    /// Enters or exits full-screen: a borderless window covering the display it
    /// is on. There is no Windows title-bar merge (an AppKit-only concept), so
    /// the toolbar strip stays where it is — the honest Windows full screen.
    public func setWindowFullScreen(_ fullScreen: Bool, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        if fullScreen {
            guard fullScreenSavedState[handle.rawValue] == nil else {
                return
            }
            // Save the current style and frame, then strip the caption/resize
            // border and size the window to the monitor's full bounds.
            let style = winGetWindowLongPtrW(hwnd, gwlStyle)
            var savedRect = RECT()
            _ = winGetWindowRect(hwnd, &savedRect)
            fullScreenSavedState[handle.rawValue] = (style, savedRect)

            var info = MONITORINFOW()
            info.cbSize = DWORD(MemoryLayout<MONITORINFOW>.size)
            let monitor = winMonitorFromWindow(hwnd, monitorDefaultToNearest)
            guard winGetMonitorInfoW(monitor, &info) != 0 else {
                fullScreenSavedState[handle.rawValue] = nil
                return
            }

            let stripped = LONG_PTR(UInt(bitPattern: Int(style)) & ~UInt(wsCaption | wsThickFrame | wsBorder))
            _ = winSetWindowLongPtrW(hwnd, gwlStyle, stripped)
            let bounds = info.rcMonitor
            _ = winSetWindowPos(
                hwnd, nil, bounds.left, bounds.top,
                bounds.right - bounds.left, bounds.bottom - bounds.top,
                swpNoZOrder | swpNoActivate | swpFrameChanged
            )
        } else {
            guard let saved = fullScreenSavedState[handle.rawValue] else {
                return
            }
            fullScreenSavedState[handle.rawValue] = nil
            _ = winSetWindowLongPtrW(hwnd, gwlStyle, saved.style)
            let rect = saved.rect
            _ = winSetWindowPos(
                hwnd, nil, rect.left, rect.top,
                rect.right - rect.left, rect.bottom - rect.top,
                swpNoZOrder | swpNoActivate | swpFrameChanged
            )
        }
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
        lastFrameDeviceRects.removeValue(forKey: handle.rawValue)
        richTextHandles.remove(handle.rawValue)
        multilineTextHandles.remove(handle.rawValue)
        windowDragViewHandles.remove(handle.rawValue)
        windowMinContentSizes.removeValue(forKey: handle.rawValue)
        windowMaxContentSizes.removeValue(forKey: handle.rawValue)
        mainMenuWindowHandles.remove(handle)
        clearWindowActions(for: handle)
        clearWindowControlState(for: handle)
        clearAppearance(for: handle)
    }

    private func clearWindowActions(for handle: NativeHandle) {
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
    }

    private func clearWindowControlState(for handle: NativeHandle) {
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
    }
}
#endif
