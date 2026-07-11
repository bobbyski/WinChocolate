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

    /// A native determinate progress bar (`msctls_progress32`, used by
    /// `NSProgressIndicator` and `NSLevelIndicator`'s continuous capacity) shows
    /// a light themed fill that reads as a bright white slab on a dark surface.
    /// Under dark, de-theme it (so the explicit color messages take effect) and
    /// give it an accent fill on a dark track. A later threshold color
    /// (warning/critical, via `setProgressBarColor`) still overrides the fill.
    func applyDarkProgressColorsIfNeeded(_ hwnd: HWND) {
        guard NSApplication.shared.effectiveAppearance.winIsDark else {
            return
        }
        _ = withWideString("") { empty in
            winSetWindowTheme(hwnd, empty, empty)
        }
        _ = winSendMessageW(hwnd, pbmSetBarColor, 0, LPARAM(colorRef(from: .controlAccentColor)))
        _ = winSendMessageW(hwnd, pbmSetBkColor, 0, LPARAM(colorRef(red: 0.22, green: 0.22, blue: 0.23)))
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

    /// Gives a native list view (`SysListView32`) the dark row background and
    /// light text under a dark appearance. `DarkMode_Explorer` (applied at
    /// creation) themes the selection band and scrollbar but not the row
    /// colors, which the list view exposes through explicit color messages.
    /// The header control is de-themed so its dynamic caption color applies.
    func applyDarkListViewColorsIfNeeded(_ hwnd: HWND) {
        guard NSApplication.shared.effectiveAppearance.winIsDark else {
            return
        }
        let face = colorRef(from: .controlBackgroundColor)
        let text = colorRef(from: .textColor)
        _ = winSendMessageW(hwnd, lvmSetBkColor, 0, LPARAM(face))
        _ = winSendMessageW(hwnd, lvmSetTextBkColor, 0, LPARAM(face))
        _ = winSendMessageW(hwnd, lvmSetTextColor, 0, LPARAM(text))
        if let header = HWND(bitPattern: winSendMessageW(hwnd, lvmGetHeader, 0, 0)) {
            // The undocumented `DarkMode_ItemsView` theme darkens the header
            // background but not its title text (dark-on-dark), and it won't
            // reliably invert even with the process app-mode + AllowDarkMode
            // dance on all Windows builds — so we own the header entirely: the
            // list-view header's NM_CUSTOMDRAW isn't forwarded to us, so we
            // subclass the header window and owner-draw its WM_PAINT.
            let key = UInt(bitPattern: header)
            if !darkTableHeaderHwnds.contains(key), let owner = tableHeaderOwners[key] {
                darkTableHeaderHwnds.insert(key)
                subclassChildControl(header, handle: owner)
            }
            _ = winInvalidateRect(header, nil, 1)
        }
    }

    /// Owner-draws a list-view column header under a dark appearance: each item
    /// gets a dark fill, its title in the dynamic light color, a hairline
    /// column separator, and — for the sorted column — the tracked sort glyph.
    /// (The header is subclassed because its `NM_CUSTOMDRAW` never reaches the
    /// top-level window, and its dark theme leaves the text dark-on-dark.)
    func drawDarkTableHeader(_ hwnd: HWND) {
        var paint = PAINTSTRUCT()
        guard let deviceContext = winBeginPaint(hwnd, &paint) else {
            return
        }
        defer {
            withUnsafePointer(to: paint) { _ = winEndPaint(hwnd, $0) }
        }

        var client = RECT()
        _ = winGetClientRect(hwnd, &client)
        // Dark fill for the whole header (covers past the last column too).
        fillRect(client, color: colorRef(from: .controlBackgroundColor), deviceContext: deviceContext)

        let owner = tableHeaderOwners[UInt(bitPattern: hwnd)]
        let titles = owner.flatMap { tableColumnTitles[$0.rawValue] } ?? []
        let sort = owner.flatMap { tableSortIndicators[$0.rawValue] }
        let separator = colorRef(from: .separatorColor)
        let textColor = colorRef(from: .textColor)

        _ = winSetBkMode(deviceContext, transparentBkMode)
        let font = winSendMessageW(hwnd, wmGetFont, 0, 0)
        let previousFont = font != 0 ? winSelectObject(deviceContext, HFONT(bitPattern: font)) : nil
        _ = winSetTextColor(deviceContext, textColor)

        let count = Int(winSendMessageW(hwnd, hdmGetItemCount, 0, 0))
        for index in 0..<max(count, 0) {
            var itemRect = RECT()
            let ok = withUnsafeMutablePointer(to: &itemRect) {
                winSendMessageW(hwnd, hdmGetItemRect, WPARAM(index), Int(bitPattern: $0))
            }
            guard ok != 0 else {
                continue
            }
            // Column separator hairline on the trailing edge.
            let sepRect = RECT(left: itemRect.right - 1, top: itemRect.top, right: itemRect.right, bottom: itemRect.bottom)
            fillRect(sepRect, color: separator, deviceContext: deviceContext)
            // Title text.
            if titles.indices.contains(index) {
                var textRect = RECT(left: itemRect.left + 6, top: itemRect.top,
                                    right: itemRect.right - 16, bottom: itemRect.bottom)
                let chars = Array(titles[index].utf16)
                _ = winDrawTextW(deviceContext, chars, Int32(chars.count), &textRect, dtSingleLine | dtVCenter | dtEndEllipsis)
            }
            // Sort glyph on the sorted column (tracked; the native flag is unset under dark).
            if let sort, sort.column == index {
                let glyph = sort.ascending ? "\u{25B2}" : "\u{25BC}"
                var arrowRect = RECT(left: itemRect.left, top: itemRect.top, right: itemRect.right - 4, bottom: itemRect.bottom)
                let arrowChars = Array(glyph.utf16)
                _ = winDrawTextW(deviceContext, arrowChars, Int32(arrowChars.count), &arrowRect, dtSingleLine | dtVCenter | dtRight)
            }
        }
        if font != 0 {
            _ = winSelectObject(deviceContext, previousFont ?? nil)
        }
        // Bottom baseline hairline.
        let baseline = RECT(left: client.left, top: client.bottom - 1, right: client.right, bottom: client.bottom)
        fillRect(baseline, color: separator, deviceContext: deviceContext)
    }

    /// Owner-draws a compact date picker's closed field under a dark
    /// appearance: a dark face with a hairline border, the displayed date in
    /// the dynamic light text color, and a drop-down chevron on the trailing
    /// edge. `SysDateTimePick32` has no color API and its `DarkMode_CFD` theme
    /// only darkens the hot/open states, so the resting field needs this.
    func drawDarkDatePickerField(_ hwnd: HWND) {
        var paint = PAINTSTRUCT()
        guard let deviceContext = winBeginPaint(hwnd, &paint) else {
            return
        }
        defer {
            withUnsafePointer(to: paint) { _ = winEndPaint(hwnd, $0) }
        }

        var bounds = RECT()
        _ = winGetClientRect(hwnd, &bounds)
        let width = bounds.right - bounds.left
        let height = bounds.bottom - bounds.top

        // Hairline border, then the dark face inset by one pixel.
        fillRect(bounds, color: colorRef(from: .separatorColor), deviceContext: deviceContext)
        let faceRect = RECT(left: bounds.left + 1, top: bounds.top + 1,
                            right: bounds.right - 1, bottom: bounds.bottom - 1)
        fillRect(faceRect, color: colorRef(from: .controlBackgroundColor), deviceContext: deviceContext)

        // The drop-down chevron column on the trailing edge.
        let chevronWidth: Int32 = 18
        let chevronCenterX = bounds.right - chevronWidth / 2 - 2
        let chevronCenterY = bounds.top + height / 2
        if let pen = winCreatePen(psSolid, 1, colorRef(from: .textColor)) {
            let previousPen = winSelectObject(deviceContext, pen)
            _ = winMoveToEx(deviceContext, chevronCenterX - 3, chevronCenterY - 1, nil)
            _ = winLineTo(deviceContext, chevronCenterX, chevronCenterY + 2)
            _ = winLineTo(deviceContext, chevronCenterX + 4, chevronCenterY - 2)
            _ = winSelectObject(deviceContext, previousPen ?? nil)
            _ = winDeleteObject(pen)
        }

        // The displayed date text, left-aligned and vertically centered.
        var textBuffer = [UInt16](repeating: 0, count: 128)
        let length = winGetWindowTextW(hwnd, &textBuffer, Int32(textBuffer.count))
        if length > 0 {
            _ = winSetBkMode(deviceContext, transparentBkMode)
            _ = winSetTextColor(deviceContext, colorRef(from: .textColor))
            let font = winSendMessageW(hwnd, wmGetFont, 0, 0)
            let previousFont = font != 0 ? winSelectObject(deviceContext, HFONT(bitPattern: font)) : nil
            var textRect = RECT(left: bounds.left + 6, top: bounds.top,
                                right: bounds.right - chevronWidth, bottom: bounds.bottom)
            _ = winDrawTextW(deviceContext, textBuffer, length, &textRect,
                             dtVCenter | dtSingleLine | dtEndEllipsis)
            if font != 0 {
                _ = winSelectObject(deviceContext, previousFont ?? nil)
            }
        }
        _ = width
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
