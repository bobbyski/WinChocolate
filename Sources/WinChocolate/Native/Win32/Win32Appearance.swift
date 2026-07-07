#if os(Windows)
/// System theme detection and dark-menu opt-in for `NSAppearance` (plan 8.5).
extension Win32NativeControlBackend {
    nonisolated(unsafe) private static var darkMenusEnabled = false

    /// Opts the process's popup menus (menu-bar dropdowns, context menus)
    /// into the system dark menu theme. Windows exposes this only through
    /// unnamed uxtheme exports — ordinal 135 `SetPreferredAppMode` (2 =
    /// ForceDark) and ordinal 136 `FlushMenuThemes` — the same calls Explorer
    /// makes; on builds without them this quietly does nothing. The menu-bar
    /// strip itself is not themed by this (it needs owner-draw, a tracked
    /// 8.5 tail). Called from backend startup when the effective appearance
    /// is dark; idempotent.
    static func enableDarkMenusIfNeeded() {
        guard !darkMenusEnabled else {
            return
        }
        darkMenusEnabled = true

        let uxtheme = withWideString("uxtheme.dll") { winLoadLibraryW($0) }
        guard let uxtheme else {
            return
        }
        typealias SetPreferredAppModeFn = @convention(c) (Int32) -> Int32
        typealias FlushMenuThemesFn = @convention(c) () -> Void
        let setModeOrdinal = UnsafePointer<CChar>(bitPattern: 135)
        let flushOrdinal = UnsafePointer<CChar>(bitPattern: 136)
        if let setMode = winGetProcAddress(uxtheme, setModeOrdinal) {
            _ = unsafeBitCast(setMode, to: SetPreferredAppModeFn.self)(2)
        }
        if let flush = winGetProcAddress(uxtheme, flushOrdinal) {
            unsafeBitCast(flush, to: FlushMenuThemesFn.self)()
        }
    }
    /// Paints over the light 1px line the non-client paint leaves between the
    /// owner-drawn dark menu bar and the client area (the same cover-up every
    /// dark-menu implementation does; see the UAH cases in the dispatch).
    func drawDarkMenuBarBottomLine(_ hwnd: HWND) {
        var clientRect = RECT()
        guard winGetClientRect(hwnd, &clientRect) != 0 else {
            return
        }
        // Client top in window coordinates: map the client origin to screen,
        // then shift by the window origin.
        _ = winMapWindowPoints(hwnd, nil, &clientRect, 2)
        var windowRect = RECT()
        _ = winGetWindowRect(hwnd, &windowRect)
        let line = RECT(
            left: clientRect.left - windowRect.left,
            top: clientRect.top - windowRect.top - 1,
            right: clientRect.right - windowRect.left,
            bottom: clientRect.top - windowRect.top
        )
        guard let windowContext = winGetWindowDC(hwnd) else {
            return
        }
        defer { _ = winReleaseDC(hwnd, windowContext) }
        if let brush = solidBrush(for: colorRef(from: .windowBackgroundColor)) {
            withUnsafePointer(to: line) { linePointer in
                _ = winFillRect(windowContext, linePointer, brush)
            }
        }
    }

    /// `SysMonthCal32` has no dark visual-styles part; under a dark effective
    /// appearance the calendar is de-themed (explicit colors only apply to an
    /// unthemed month-calendar) and given the dynamic dark palette via
    /// `MCM_SETCOLOR`. One of 8.5's "classes without dark theme parts".
    func applyDarkCalendarColorsIfNeeded(_ hwnd: HWND) {
        guard NSApplication.shared.effectiveAppearance.winIsDark else {
            return
        }
        _ = withWideString("") { empty in
            winSetWindowTheme(hwnd, empty, empty)
        }
        let background = LPARAM(colorRef(from: .windowBackgroundColor))
        let face = LPARAM(colorRef(from: .controlBackgroundColor))
        let text = LPARAM(colorRef(from: .textColor))
        let trailing = LPARAM(colorRef(red: 0.5, green: 0.5, blue: 0.5))
        _ = winSendMessageW(hwnd, mcmSetColor, WPARAM(mcscBackground), background)
        _ = winSendMessageW(hwnd, mcmSetColor, WPARAM(mcscMonthBk), face)
        _ = winSendMessageW(hwnd, mcmSetColor, WPARAM(mcscText), text)
        _ = winSendMessageW(hwnd, mcmSetColor, WPARAM(mcscTitleBk), background)
        _ = winSendMessageW(hwnd, mcmSetColor, WPARAM(mcscTitleText), text)
        _ = winSendMessageW(hwnd, mcmSetColor, WPARAM(mcscTrailingText), trailing)
    }

    /// Applies the dark calendar palette to a `SysDateTimePick32`'s drop-down
    /// month calendar (`DTM_SETMCCOLOR` takes the same color parts).
    func applyDarkDropDownCalendarColorsIfNeeded(_ hwnd: HWND) {
        guard NSApplication.shared.effectiveAppearance.winIsDark else {
            return
        }
        let background = LPARAM(colorRef(from: .windowBackgroundColor))
        let face = LPARAM(colorRef(from: .controlBackgroundColor))
        let text = LPARAM(colorRef(from: .textColor))
        _ = winSendMessageW(hwnd, dtmSetMCColor, WPARAM(mcscBackground), background)
        _ = winSendMessageW(hwnd, dtmSetMCColor, WPARAM(mcscMonthBk), face)
        _ = winSendMessageW(hwnd, dtmSetMCColor, WPARAM(mcscText), text)
        _ = winSendMessageW(hwnd, dtmSetMCColor, WPARAM(mcscTitleBk), background)
        _ = winSendMessageW(hwnd, dtmSetMCColor, WPARAM(mcscTitleText), text)
    }

    /// The user's Windows accent color from the DWM colorization key
    /// (`AccentColor`, stored ABGR), or `nil` when the value is absent.
    public func systemAccentColor() -> NSColor? {
        let subKey = Array("Software\\Microsoft\\Windows\\DWM".utf16) + [0]
        let valueName = Array("AccentColor".utf16) + [0]
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = winRegGetValueW(
            winHKEYCurrentUser, subKey, valueName,
            winRRFRtRegDword, nil, &value, &size
        )
        guard status == 0 else {
            return nil
        }
        return NSColor(
            calibratedRed: CGFloat(value & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat((value >> 16) & 0xFF) / 255,
            alpha: 1
        )
    }

    /// Whether Windows "dark mode for applications" is on: the Personalize
    /// key's `AppsUseLightTheme` DWORD is 0. A missing value (older systems)
    /// reads as the light theme.
    public func systemPrefersDarkAppearance() -> Bool {
        let subKey = Array("Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize".utf16) + [0]
        let valueName = Array("AppsUseLightTheme".utf16) + [0]
        var value: UInt32 = 1
        var size = UInt32(MemoryLayout<UInt32>.size)
        let status = winRegGetValueW(
            winHKEYCurrentUser, subKey, valueName,
            winRRFRtRegDword, nil, &value, &size
        )
        return status == 0 && value == 0
    }
}
#endif
