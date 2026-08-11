#if os(Windows)
extension Win32NativeControlBackend {
    func outerWindowSize(forContentSize size: NSSize, style: DWORD, hasMenu: Bool) -> (width: Int32, height: Int32) {
        var rectangle = RECT(left: 0, top: 0, right: Int32(size.width), bottom: Int32(size.height))
        guard winAdjustWindowRectEx(&rectangle, style, hasMenu ? 1 : 0, 0) != 0 else {
            return (Int32(size.width), Int32(size.height))
        }

        return (rectangle.right - rectangle.left, rectangle.bottom - rectangle.top)
    }

    func ensureComInitialized() {
        guard !isComInitialized else {
            return
        }

        _ = winCoInitializeEx(nil, coinitApartmentThreaded)
        isComInitialized = true
    }

    fileprivate static func dispatchMessage(hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT? {
        activeBackend?.dispatchMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
    }

    fileprivate static func dispatchControlMessage(hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT? {
        activeBackend?.dispatchControlMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
    }

    fileprivate static func callOriginalControlProcedure(hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT {
        activeBackend?.callOriginalControlProcedure(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
            ?? winDefWindowProcW(hwnd, message, wParam, lParam)
    }

    func registerWindowClassIfNeeded() {
        guard !isWindowClassRegistered else {
            return
        }

        withWideString(winChocolateWindowClassName) { className in
            var windowClass = WNDCLASSW()
            windowClass.style = csHRedraw | csVRedraw | csDblClks
            windowClass.lpfnWndProc = winChocolateWindowProcedure
            windowClass.hInstance = winGetModuleHandleW(nil)
            windowClass.hCursor = winLoadCursorW(nil, systemResourcePointer(32_512))
            windowClass.hbrBackground = nil
            windowClass.lpszClassName = className

            withUnsafePointer(to: windowClass) { windowClassPointer in
                let atom = winRegisterClassW(windowClassPointer)
                if atom == 0 {
                    print("WinChocolate: RegisterClassW failed with error \(winGetLastError()).")
                }
            }
        }

        isWindowClassRegistered = true
    }

    func registerViewClassIfNeeded() {
        guard !isViewClassRegistered else {
            return
        }

        withWideString(winChocolateViewClassName) { className in
            var windowClass = WNDCLASSW()
            windowClass.style = csHRedraw | csVRedraw | csDblClks
            windowClass.lpfnWndProc = winChocolateWindowProcedure
            windowClass.hInstance = winGetModuleHandleW(nil)
            windowClass.hCursor = winLoadCursorW(nil, systemResourcePointer(32_512))
            // The view surface erases with the dynamic window background so a
            // dark effective appearance yields dark view surfaces (the class
            // registers on first control creation, after the appearance is
            // decided — the same one-way binding as WinPresentation).
            windowClass.hbrBackground = winCreateSolidBrush(colorRef(from: .windowBackgroundColor))
            windowClass.lpszClassName = className

            withUnsafePointer(to: windowClass) { windowClassPointer in
                let atom = winRegisterClassW(windowClassPointer)
                if atom == 0 {
                    print("WinChocolate: RegisterClassW for view failed with error \(winGetLastError()).")
                }
            }
        }

        isViewClassRegistered = true
    }

    func initializeListViewControls() {
        var initControls = INITCOMMONCONTROLSEX()
        initControls.dwSize = DWORD(MemoryLayout<INITCOMMONCONTROLSEX>.size)
        initControls.dwICC = iccListViewClasses
        withUnsafePointer(to: initControls) { pointer in
            _ = winInitCommonControlsEx(pointer)
        }
    }

    func initializeToolbarControls() {
        var initControls = INITCOMMONCONTROLSEX()
        initControls.dwSize = DWORD(MemoryLayout<INITCOMMONCONTROLSEX>.size)
        initControls.dwICC = iccBarClasses
        withUnsafePointer(to: initControls) { pointer in
            _ = winInitCommonControlsEx(pointer)
        }
    }

    func initializeTabControls() {
        var initControls = INITCOMMONCONTROLSEX()
        initControls.dwSize = DWORD(MemoryLayout<INITCOMMONCONTROLSEX>.size)
        initControls.dwICC = iccTabClasses
        withUnsafePointer(to: initControls) { pointer in
            _ = winInitCommonControlsEx(pointer)
        }
    }

    func initializeUpDownControls() {
        var initControls = INITCOMMONCONTROLSEX()
        initControls.dwSize = DWORD(MemoryLayout<INITCOMMONCONTROLSEX>.size)
        initControls.dwICC = iccUpDownClass
        withUnsafePointer(to: initControls) { pointer in
            _ = winInitCommonControlsEx(pointer)
        }
    }

    func initializeProgressControls() {
        var initControls = INITCOMMONCONTROLSEX()
        initControls.dwSize = DWORD(MemoryLayout<INITCOMMONCONTROLSEX>.size)
        initControls.dwICC = iccProgressClass
        withUnsafePointer(to: initControls) { pointer in
            _ = winInitCommonControlsEx(pointer)
        }
    }

    func initializeDateControls() {
        var initControls = INITCOMMONCONTROLSEX()
        initControls.dwSize = DWORD(MemoryLayout<INITCOMMONCONTROLSEX>.size)
        initControls.dwICC = iccDateClasses
        withUnsafePointer(to: initControls) { pointer in
            _ = winInitCommonControlsEx(pointer)
        }
    }

    func frameWidth(for handle: NativeHandle) -> CGFloat {
        guard let hwnd = hwnd(from: handle) else {
            return 240
        }

        var rectangle = RECT()
        guard winGetClientRect(hwnd, &rectangle) != 0 else {
            return 240
        }

        return CGFloat(max(1, rectangle.right - rectangle.left))
    }

    func createChildWindow(
        content: (className: String, text: String),
        frame: NSRect,
        parent: NativeHandle?,
        commandIdentifier: UInt?,
        style: DWORD
    ) -> NativeHandle {
        let (className, text) = content
        guard let parentHwnd = parent.flatMap({ hwnd(from: $0) }) else {
            return NativeHandle(rawValue: 0)
        }

        let menuHandle = commandIdentifier.flatMap { HMENU(bitPattern: Int($0)) }
        // Controls are created in device pixels at the display scale (10.7);
        // a no-op at 100%.
        let childHwnd = withWideString(className) { nativeClassName in
            withWideString(text) { nativeText in
                winCreateWindowExW(
                    0,
                    nativeClassName,
                    nativeText,
                    style,
                    winToDevice(frame.origin.x),
                    winToDevice(frame.origin.y),
                    winToDevice(frame.size.width),
                    winToDevice(frame.size.height),
                    parentHwnd,
                    menuHandle,
                    winGetModuleHandleW(nil),
                    nil
                )
            }
        }

        guard let childHwnd else {
            print("WinChocolate: CreateWindowExW child \(className) failed with error \(winGetLastError()).")
            return NativeHandle(rawValue: 0)
        }

        // Native control classes default to the legacy bitmap system font;
        // give every control the standard UI font unless `setFont` overrides.
        if let font = defaultUIFont() {
            _ = winSendMessageW(childHwnd, wmSetFont, UInt(bitPattern: font), 1)
        }

        // A dark effective appearance opts native controls into the system's
        // dark control themes (the same undocumented-but-stable subclasses
        // Explorer and the common dialogs use). Best-effort: classes without
        // a dark theme part keep their light rendering — tracked in 8.5.
        // Rich edit is excluded: the dark theme dims its text rendering while
        // the control already takes explicit colors (EM_SETBKGNDCOLOR + char
        // formats), which the dark path applies directly.
        if NSApplication.shared.effectiveAppearance.winIsDark,
           !className.uppercased().hasPrefix("RICHEDIT") {
            let theme = className.uppercased() == "COMBOBOX" ? "DarkMode_CFD" : "DarkMode_Explorer"
            _ = withWideString(theme) { themeName in
                winSetWindowTheme(childHwnd, themeName, nil)
            }
        }

        return nativeHandle(from: childHwnd)
    }

    private func defaultUIFont() -> HFONT? {
        if let defaultControlFont {
            return defaultControlFont
        }

        // 12pt at the display scale (10.7) so native control text is crisp at
        // HiDPI; a no-op at 100%.
        let pixelHeight = Int32((12 * winDeviceScale).rounded())
        let font = withWideString("Segoe UI") { faceName in
            winCreateFontW(
                -pixelHeight,
                0,
                0,
                0,
                400,
                0,
                0,
                0,
                defaultCharset,
                defaultPrecision,
                defaultPrecision,
                defaultQuality,
                defaultPitchAndFamily,
                faceName
            )
        }
        defaultControlFont = font
        return font
    }

    func nextCommandID() -> UInt {
        let commandIdentifier = nextCommandIdentifier
        nextCommandIdentifier += 1
        return commandIdentifier
    }

    func solidBrush(for color: DWORD) -> HBRUSH? {
        if let brush = solidBrushCache[color] {
            return brush
        }

        guard let brush = winCreateSolidBrush(color) else {
            return nil
        }

        solidBrushCache[color] = brush
        return brush
    }

    func inheritedBackgroundColor(behind hwnd: HWND?) -> DWORD {
        var ancestor = winGetParent(hwnd)
        while let current = ancestor {
            let rawAncestor = UInt(bitPattern: current)
            if !transparentBackgroundHandles.contains(rawAncestor),
               let color = backgroundColors[rawAncestor] {
                return color
            }
            ancestor = winGetParent(current)
        }
        return colorRef(from: .windowBackgroundColor)
    }

    func controlBackgroundBrush() -> HBRUSH? {
        if let defaultControlBackgroundBrush {
            return defaultControlBackgroundBrush
        }

        let brush = winCreateSolidBrush(colorRef(from: .windowBackgroundColor))
        defaultControlBackgroundBrush = brush
        return brush
    }

    /// Discards the cached control-background brush so it is rebuilt with the
    /// current appearance's window background (used on a live theme switch).
    func winResetCachedControlBackgroundBrush() {
        if let brush = defaultControlBackgroundBrush {
            _ = winDeleteObject(brush)
        }
        defaultControlBackgroundBrush = nil
    }

    func colorRef(from color: NSColor) -> DWORD {
        colorRef(red: color.redComponent, green: color.greenComponent, blue: color.blueComponent)
    }

    func colorRef(red redComponent: CGFloat, green greenComponent: CGFloat, blue blueComponent: CGFloat) -> DWORD {
        let red = DWORD((min(max(redComponent, 0), 1) * 255).rounded()) & 0xff
        let green = DWORD((min(max(greenComponent, 0), 1) * 255).rounded()) & 0xff
        let blue = DWORD((min(max(blueComponent, 0), 1) * 255).rounded()) & 0xff
        return red | (green << 8) | (blue << 16)
    }

    func invalidate(_ handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winInvalidateRect(hwnd, nil, 1)
    }

    func clearAppearance(for handle: NativeHandle) {
        textColors.removeValue(forKey: handle.rawValue)
        backgroundColors.removeValue(forKey: handle.rawValue)
        transparentBackgroundHandles.remove(handle.rawValue)
        if let brush = backgroundBrushes.removeValue(forKey: handle.rawValue) {
            _ = winDeleteObject(brush)
        }
        if let font = fonts.removeValue(forKey: handle.rawValue) {
            _ = winDeleteObject(font)
        }
        if let bitmap = bitmaps.removeValue(forKey: handle.rawValue) {
            if let hwnd = hwnd(from: handle) {
                _ = winSendMessageW(hwnd, stmSetImage, WPARAM(imageBitmap), 0)
            }
            _ = winDeleteObject(bitmap)
        }
    }

    func nativeHandle(from hwnd: HWND) -> NativeHandle {
        NativeHandle(rawValue: UInt(bitPattern: hwnd))
    }

    func actionHandle(from hwnd: HWND) -> NativeHandle {
        controlHandleAliases[UInt(bitPattern: hwnd)] ?? nativeHandle(from: hwnd)
    }

    func hwnd(from handle: NativeHandle) -> HWND? {
        guard handle.rawValue != 0 else {
            return nil
        }

        return HWND(bitPattern: handle.rawValue)
    }
}

private func winChocolateWindowProcedure(
    hwnd: HWND?,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM
) -> LRESULT {
    if let result = Win32NativeControlBackend.dispatchMessage(
        hwnd: hwnd,
        message: message,
        wParam: wParam,
        lParam: lParam
    ) {
        return result
    }

    return winDefWindowProcW(hwnd, message, wParam, lParam)
}

func winChocolateControlProcedure(
    hwnd: HWND?,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM
) -> LRESULT {
    if let result = Win32NativeControlBackend.dispatchControlMessage(
        hwnd: hwnd,
        message: message,
        wParam: wParam,
        lParam: lParam
    ) {
        return result
    }

    return Win32NativeControlBackend.callOriginalControlProcedure(
        hwnd: hwnd,
        message: message,
        wParam: wParam,
        lParam: lParam
    )
}

/// Dispatches thread-timer ticks to the active backend's timer actions.
let runLoopTimerProcedure: @convention(c) (HWND?, UINT, UInt, DWORD) -> Void = { _, _, identifier, _ in
    Win32NativeControlBackend.activeBackend?.timerActions[identifier]?()
}
#endif
