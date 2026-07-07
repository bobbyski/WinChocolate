#if os(Windows)
/// System theme detection for `NSAppearance` (plan 8.5).
extension Win32NativeControlBackend {
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
