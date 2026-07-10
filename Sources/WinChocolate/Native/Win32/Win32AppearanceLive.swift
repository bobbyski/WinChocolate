#if os(Windows)
/// Live system dark/light switching (plan 8.5).
///
/// Windows broadcasts `WM_SETTINGCHANGE` when the user flips the system theme.
/// When the application follows the system (no `NSApp`/`NSWindow` appearance
/// override — the `--light`/`--dark` demo flags set one, and it wins), this
/// re-applies the new effective appearance to every live window: the immersive
/// title bar, the popup-menu theme, each native child control's dark/light
/// theme, and a full repaint so the framework-drawn views re-resolve their
/// dynamic colors. It then posts an app-level notification so application code
/// (which may cache colors) can refresh too.
extension Win32NativeControlBackend {
    /// The last system dark preference we broadcast a change for, so a burst of
    /// `WM_SETTINGCHANGE` messages (one per top-level window, and for unrelated
    /// settings) collapses into a single refresh.
    nonisolated(unsafe) private static var lastKnownSystemDark: Bool?

    /// Handles a `WM_SETTINGCHANGE`: refreshes appearance only when the system
    /// dark preference actually changed and the app isn't pinned to an override.
    func winHandleSettingChange() {
        // An explicit app/window appearance override pins the look — the system
        // theme is ignored, matching AppKit's `NSApp.appearance`.
        guard NSApplication.shared.winAppearanceOverride == nil else {
            return
        }

        let systemDark = systemPrefersDarkAppearance()
        guard systemDark != Self.lastKnownSystemDark else {
            return
        }
        Self.lastKnownSystemDark = systemDark

        winRefreshAllWindowsAppearance(dark: systemDark)
        NSApplication.shared.winPostEffectiveAppearanceDidChange()
    }

    /// Re-applies `dark`/light chrome + control theming to every top-level
    /// window and repaints them.
    func winRefreshAllWindowsAppearance(dark: Bool) {
        setPreferredMenuAppMode(dark: dark)

        // The top-level window-class background brush and the cached
        // control-background brush were built once at launch. Framework views
        // are transparent unless given an explicit background, so they show the
        // window's class brush — rebuild it (and the control brush) for the new
        // surface color, or the content stays the old shade under a repaint.
        if let anyWindow = windowHandles.first.flatMap({ hwnd(from: $0) }),
           let newBrush = winCreateSolidBrush(colorRef(from: .windowBackgroundColor)) {
            let previous = winSetClassLongPtrW(anyWindow, gclpHbrBackground, LONG_PTR(Int(bitPattern: newBrush)))
            if previous != 0, let oldBrush = HBRUSH(bitPattern: UInt(bitPattern: previous)) {
                _ = winDeleteObject(oldBrush)
            }
        }
        winResetCachedControlBackgroundBrush()

        for handle in windowHandles {
            guard let hwnd = hwnd(from: handle) else {
                continue
            }
            var immersive: Int32 = dark ? 1 : 0
            _ = winDwmSetWindowAttribute(
                hwnd, winDWMWAUseImmersiveDarkMode,
                &immersive, DWORD(MemoryLayout<Int32>.size)
            )
            refreshChildTree(hwnd, dark: dark)
            // Repaint the frame and the whole child tree; framework-drawn views
            // re-resolve their dynamic colors on the repaint.
            _ = winRedrawWindow(hwnd, nil, nil, rdwInvalidate | rdwErase | rdwAllChildren | rdwFrame)
        }
    }

    /// Sets the process popup-menu theme to dark (ForceDark) or light
    /// (ForceLight) and flushes, so menus follow a live switch.
    private func setPreferredMenuAppMode(dark: Bool) {
        let uxtheme = withWideString("uxtheme.dll") { winLoadLibraryW($0) }
        guard let uxtheme else {
            return
        }
        typealias SetPreferredAppModeFn = @convention(c) (Int32) -> Int32
        typealias FlushMenuThemesFn = @convention(c) () -> Void
        if let setMode = winGetProcAddress(uxtheme, UnsafePointer<CChar>(bitPattern: 135)) {
            // PreferredAppMode: 2 = ForceDark, 3 = ForceLight.
            _ = unsafeBitCast(setMode, to: SetPreferredAppModeFn.self)(dark ? 2 : 3)
        }
        if let flush = winGetProcAddress(uxtheme, UnsafePointer<CChar>(bitPattern: 136)) {
            unsafeBitCast(flush, to: FlushMenuThemesFn.self)()
        }
    }

    /// Recursively re-themes a window's native children for the appearance.
    private func refreshChildTree(_ parent: HWND, dark: Bool) {
        var child = winGetWindow(parent, gwChild)
        while let current = child {
            applyChildAppearance(current, dark: dark)
            refreshChildTree(current, dark: dark)
            child = winGetWindow(current, gwHwndNext)
        }
    }

    /// Re-applies the dark/light theme (and any explicit colors) to one control.
    private func applyChildAppearance(_ hwnd: HWND, dark: Bool) {
        let className = classNameOf(hwnd).uppercased()

        // Rich edit ignores WM_CTLCOLOR and the dark subclass dims its glyphs,
        // so it takes explicit background + character colors either way: dynamic
        // control background, and its explicit text color (else the dynamic
        // label color, which is black under light / white under dark).
        if className.hasPrefix("RICHEDIT") {
            let handle = nativeHandle(from: hwnd)
            _ = winSendMessageW(hwnd, emSetBkgndColor, 0, LPARAM(colorRef(from: .controlBackgroundColor)))
            let textRef = richEditTextColors[handle.rawValue] ?? colorRef(from: .textColor)
            var format = CHARFORMATW()
            format.cbSize = UINT(MemoryLayout<CHARFORMATW>.stride)
            format.dwMask = cfmColor
            format.crTextColor = textRef
            withUnsafePointer(to: &format) { pointer in
                _ = winSendMessageW(hwnd, emSetCharFormat, scfAll, Int(bitPattern: pointer))
            }
            _ = winInvalidateRect(hwnd, nil, 1)
            return
        }

        // Flip the control's visual-styles theme: the dark subclasses Explorer
        // and the common dialogs use, or the standard Explorer theme for light.
        let theme: String
        if dark {
            theme = className == "COMBOBOX" ? "DarkMode_CFD" : "DarkMode_Explorer"
        } else {
            theme = "Explorer"
        }
        _ = withWideString(theme) { winSetWindowTheme(hwnd, $0, nil) }

        // Controls whose row/fill colors come through explicit messages need
        // them re-applied (dark) or handed back to the theme (light).
        switch className {
        case "SYSLISTVIEW32":
            if dark {
                applyDarkListViewColorsIfNeeded(hwnd)
            } else {
                _ = winSendMessageW(hwnd, lvmSetBkColor, 0, LPARAM(colorRef(from: .controlBackgroundColor)))
                _ = winSendMessageW(hwnd, lvmSetTextColor, 0, LPARAM(colorRef(from: .textColor)))
                _ = winSendMessageW(hwnd, lvmSetTextBkColor, 0, LPARAM(colorRef(from: .controlBackgroundColor)))
            }
        case "MSCTLS_PROGRESS32":
            if dark {
                applyDarkProgressColorsIfNeeded(hwnd)
            } else {
                // Hand the bar back to the (light) theme.
                _ = winSendMessageW(hwnd, pbmSetBarColor, 0, LPARAM(clrDefault))
                _ = winSendMessageW(hwnd, pbmSetBkColor, 0, LPARAM(clrDefault))
            }
        case "SYSMONTHCAL32":
            // The calendar takes explicit colors only when de-themed (dark);
            // for light the Explorer theme above restores its native look.
            if dark {
                applyDarkCalendarColorsIfNeeded(hwnd)
            }
        default:
            break
        }

        _ = winInvalidateRect(hwnd, nil, 1)
    }

    /// Reads a window's class name.
    private func classNameOf(_ hwnd: HWND) -> String {
        var buffer = [UInt16](repeating: 0, count: 64)
        let count = winGetClassNameW(hwnd, &buffer, Int32(buffer.count))
        guard count > 0 else {
            return ""
        }
        return String(decoding: buffer[0..<Int(count)], as: UTF16.self)
    }
}
#endif
