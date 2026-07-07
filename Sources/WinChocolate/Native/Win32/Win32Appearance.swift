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
