#if os(Windows)
extension Win32NativeControlBackend {
    /// Runs a native modal alert.
    public func runAlert(_ alert: NSAlert) -> NSApplication.ModalResponse {
        let body = alert.informativeText.isEmpty
            ? alert.messageText
            : "\(alert.messageText)\n\n\(alert.informativeText)"
        let owner = NSApplication.shared.keyWindow?.nativeHandle.flatMap { hwnd(from: $0) }

        let result = withWideString(body) { text in
            withWideString("WinChocolate") { caption in
                winMessageBoxW(owner, text, caption, messageBoxFlags(for: alert))
            }
        }

        if result == idOK || result == idYes {
            return .alertFirstButtonReturn
        }

        return .alertSecondButtonReturn
    }

    /// Runs a native modal file dialog.
    public func runFileDialog(_ options: NativeFileDialogOptions) -> [String]? {
        let owner = NSApplication.shared.keyWindow?.nativeHandle.flatMap { hwnd(from: $0) }
        return withSheetPositioning(anchored: options.anchorFrame != nil, owner: owner) {
            if options.kind == .open && options.canChooseDirectories && !options.canChooseFiles {
                return runFolderDialog(options, owner: owner)
            }

            return runOpenSaveDialog(options, owner: owner)
        }
    }

    /// Positions the next dialog under the owner's title area like a sheet.
    ///
    /// OS-owned common dialogs place themselves, and hosting them through a
    /// hook template downgrades the modern Explorer style. A thread-local CBT
    /// hook keeps the modern dialog and moves it on first activation instead.
    private func withSheetPositioning<Result>(anchored: Bool, owner: HWND?, _ body: () -> Result) -> Result {
        guard anchored, let owner else {
            return body()
        }

        Self.pendingSheetOwner = owner
        let hook = winSetWindowsHookExW(whCbt, sheetPositioningHookProcedure, nil, winGetCurrentThreadId())
        defer {
            if let hook {
                _ = winUnhookWindowsHookEx(hook)
            }
            Self.pendingSheetOwner = nil
            if Self.sheetPinTimer != 0 {
                _ = winKillTimer(nil, Self.sheetPinTimer)
                Self.sheetPinTimer = 0
            }
            Self.sheetDialog = nil
            Self.sheetDialogOwner = nil
        }
        return body()
    }

    private func runOpenSaveDialog(_ options: NativeFileDialogOptions, owner: HWND?) -> [String]? {
        let bufferLength = 32_768
        var fileBuffer = Array(repeating: UInt16(0), count: bufferLength)
        for (index, unit) in options.fileName.utf16.prefix(1_024).enumerated() {
            fileBuffer[index] = unit
        }

        var flags: DWORD = ofnExplorer | ofnHideReadOnly | ofnNoChangeDir | ofnPathMustExist
        switch options.kind {
        case .open:
            flags |= ofnFileMustExist
            if options.allowsMultipleSelection {
                flags |= ofnAllowMultiSelect
            }
        case .save:
            flags |= ofnOverwritePrompt
        }
        if options.showsHiddenFiles {
            flags |= ofnForceShowHidden
        }

        let filter = fileDialogFilter(for: options)
        let defaultExtension = options.kind == .save ? options.fileTypes.first : nil

        var succeeded = false
        fileBuffer.withUnsafeMutableBufferPointer { filePointer in
            withOptionalWideString(filter) { filterPointer in
                withOptionalWideString(options.title.isEmpty ? nil : options.title) { titlePointer in
                    withOptionalWideString(options.directoryPath) { directoryPointer in
                        withOptionalWideString(defaultExtension) { extensionPointer in
                            var descriptor = OPENFILENAMEW()
                            descriptor.lStructSize = DWORD(MemoryLayout<OPENFILENAMEW>.size)
                            descriptor.hwndOwner = owner
                            descriptor.lpstrFilter = filterPointer
                            descriptor.nFilterIndex = filterPointer == nil ? 0 : 1
                            descriptor.lpstrFile = filePointer.baseAddress
                            descriptor.nMaxFile = DWORD(bufferLength)
                            descriptor.lpstrInitialDir = directoryPointer
                            descriptor.lpstrTitle = titlePointer
                            descriptor.flags = flags
                            descriptor.lpstrDefExt = extensionPointer
                            let result = options.kind == .save
                                ? winGetSaveFileNameW(&descriptor)
                                : winGetOpenFileNameW(&descriptor)
                            succeeded = result != 0
                        }
                    }
                }
            }
        }

        guard succeeded else {
            return nil
        }

        return parseFileDialogBuffer(
            fileBuffer,
            allowsMultipleSelection: options.kind == .open && options.allowsMultipleSelection
        )
    }

    private func runFolderDialog(_ options: NativeFileDialogOptions, owner: HWND?) -> [String]? {
        ensureComInitialized()

        let title = options.title.isEmpty ? options.prompt : options.title
        var displayName = Array(repeating: UInt16(0), count: 1_024)
        var itemIDList: UnsafeMutableRawPointer?
        displayName.withUnsafeMutableBufferPointer { displayPointer in
            withOptionalWideString(title.isEmpty ? nil : title) { titlePointer in
                var browseInfo = BROWSEINFOW()
                browseInfo.hwndOwner = owner
                browseInfo.pszDisplayName = displayPointer.baseAddress
                browseInfo.lpszTitle = titlePointer
                browseInfo.ulFlags = bifReturnOnlyFSDirs | bifNewDialogStyle
                itemIDList = winSHBrowseForFolderW(&browseInfo)
            }
        }

        guard let itemIDList else {
            return nil
        }
        defer {
            winCoTaskMemFree(itemIDList)
        }

        var pathBuffer = Array(repeating: UInt16(0), count: 1_024)
        let copied = pathBuffer.withUnsafeMutableBufferPointer { pathPointer in
            winSHGetPathFromIDListW(itemIDList, pathPointer.baseAddress)
        }
        guard copied != 0 else {
            return nil
        }

        let length = pathBuffer.firstIndex(of: 0) ?? pathBuffer.count
        return [String(decoding: pathBuffer.prefix(length), as: UTF16.self)]
    }

    private func fileDialogFilter(for options: NativeFileDialogOptions) -> String? {
        var entries: [String] = []
        if !options.fileTypes.isEmpty {
            let patterns = options.fileTypes.map { "*.\($0)" }.joined(separator: ";")
            let names = options.fileTypes.map { $0.uppercased() }.joined(separator: ", ")
            entries.append("\(names) Files (\(patterns))\0\(patterns)")
        }
        if options.fileTypes.isEmpty || options.allowsOtherFileTypes {
            entries.append("All Files (*.*)\0*.*")
        }

        guard !entries.isEmpty else {
            return nil
        }

        // Win32 filter strings are NUL-delimited pairs ending in a double NUL;
        // `withWideString` appends the final terminator.
        return entries.joined(separator: "\0") + "\0"
    }

    private func parseFileDialogBuffer(_ buffer: [UInt16], allowsMultipleSelection: Bool) -> [String]? {
        var segments: [String] = []
        var current: [UInt16] = []
        for unit in buffer {
            if unit == 0 {
                if current.isEmpty {
                    break
                }
                segments.append(String(decoding: current, as: UTF16.self))
                current.removeAll()
            } else {
                current.append(unit)
            }
        }

        guard let first = segments.first else {
            return nil
        }

        // Multi-select buffers hold the directory followed by bare file names;
        // a single selection is one full path.
        guard allowsMultipleSelection, segments.count > 1 else {
            return [first]
        }

        let directory = first.hasSuffix("\\") ? String(first.dropLast()) : first
        return segments.dropFirst().map { "\(directory)\\\($0)" }
    }

    /// Runs the native `ChooseColorW` modal color chooser.
    public func runColorChooser(initialColor: NSColor) -> NSColor? {
        let owner = NSApplication.shared.keyWindow?.nativeHandle.flatMap { hwnd(from: $0) }

        var chosen: DWORD?
        colorChooserCustomColors.withUnsafeMutableBufferPointer { customColors in
            var descriptor = CHOOSECOLORW()
            descriptor.lStructSize = DWORD(MemoryLayout<CHOOSECOLORW>.size)
            descriptor.hwndOwner = owner
            descriptor.rgbResult = colorRef(from: initialColor)
            descriptor.lpCustColors = customColors.baseAddress
            descriptor.Flags = ccRGBInit | ccFullOpen
            if winChooseColorW(&descriptor) != 0 {
                chosen = descriptor.rgbResult
            }
        }

        guard let chosen else {
            return nil
        }

        return NSColor(
            calibratedRed: CGFloat(chosen & 0xff) / 255,
            green: CGFloat((chosen >> 8) & 0xff) / 255,
            blue: CGFloat((chosen >> 16) & 0xff) / 255,
            alpha: 1
        )
    }

    /// Returns the installed font family names sorted for display.
    ///
    /// Enumerated once over the screen device context and cached; vertical
    /// families (`@`-prefixed) are skipped because AppKit has no equivalent.
    public func fontFamilyNames() -> [String] {
        if let cachedFontFamilyNames {
            return cachedFontFamilyNames
        }

        guard let deviceContext = winGetDC(nil) else {
            return []
        }
        defer {
            _ = winReleaseDC(nil, deviceContext)
        }

        Self.enumeratedFontFamilies.removeAll()
        var logFont = LOGFONTW()
        logFont.lfCharSet = UInt8(defaultCharset)
        _ = winEnumFontFamiliesExW(deviceContext, &logFont, fontFamilyEnumerationProcedure, 0, 0)

        let names = Self.enumeratedFontFamilies.sorted()
        cachedFontFamilyNames = names
        return names
    }

    /// Runs the native `ChooseFontW` modal font chooser.
    public func runFontChooser(initialFont: NSFont?) -> NSFont? {
        let owner = NSApplication.shared.keyWindow?.nativeHandle.flatMap { hwnd(from: $0) }
        let seed = initialFont ?? NSFont.systemFont(ofSize: 13)

        var logFont = LOGFONTW()
        // Negative heights request character heights in device pixels at the
        // classic 96 DPI baseline, matching how the backend realizes fonts.
        logFont.lfHeight = -Int32((seed.pointSize * 96 / 72).rounded())
        logFont.lfWeight = Int32(seed.weight.rawValue)
        withUnsafeMutableBytes(of: &logFont.lfFaceName) { raw in
            let faceName = raw.bindMemory(to: UInt16.self)
            for (index, unit) in seed.fontName.utf16.prefix(31).enumerated() {
                faceName[index] = unit
            }
        }

        var succeeded = false
        withUnsafeMutablePointer(to: &logFont) { logFontPointer in
            var descriptor = CHOOSEFONTW()
            // Windows validates sizeof(CHOOSEFONTW) == 104, which includes
            // the trailing alignment padding that `size` (100) excludes.
            descriptor.lStructSize = DWORD(MemoryLayout<CHOOSEFONTW>.stride)
            descriptor.hwndOwner = owner
            descriptor.lpLogFont = logFontPointer
            descriptor.Flags = cfScreenFonts | cfInitToLogFontStruct
            succeeded = winChooseFontW(&descriptor) != 0
        }

        guard succeeded else {
            return nil
        }

        var name = ""
        withUnsafeBytes(of: logFont.lfFaceName) { raw in
            let faceName = raw.bindMemory(to: UInt16.self)
            let length = faceName.firstIndex(of: 0) ?? faceName.count
            name = String(decoding: faceName.prefix(length), as: UTF16.self)
        }
        if name.isEmpty {
            name = seed.fontName
        }

        let pointSize = CGFloat(abs(logFont.lfHeight)) * 72 / 96
        let weight: NSFont.Weight = logFont.lfWeight >= 600 ? .bold : .regular
        return NSFont(name: name, size: pointSize > 0 ? pointSize : seed.pointSize, weight: weight)
    }

    private func messageBoxFlags(for alert: NSAlert) -> UINT {
        let buttonFlags: UINT
        switch alert.buttonTitles.count {
        case 0, 1:
            buttonFlags = mbOK
        case 2:
            buttonFlags = mbOKCancel
        default:
            buttonFlags = mbYesNo
        }

        let iconFlags: UINT
        switch alert.alertStyle {
        case .informational:
            iconFlags = mbIconInformation
        case .warning:
            iconFlags = mbIconWarning
        case .critical:
            iconFlags = mbIconError
        }

        return buttonFlags | iconFlags
    }
}

extension Win32NativeControlBackend {
    /// Family names collected by the C enumeration callback, which cannot capture state.
    nonisolated(unsafe) static var enumeratedFontFamilies: Set<String> = []
    /// Owner window consumed by the CBT hook while a positioned dialog opens.
    nonisolated(unsafe) static var pendingSheetOwner: HWND?
    /// Dialog being pinned under its owner while it finishes opening.
    nonisolated(unsafe) static var sheetDialog: HWND?
    /// Owner the pinned dialog attaches to.
    nonisolated(unsafe) static var sheetDialogOwner: HWND?
    /// Thread timer that re-applies the sheet placement.
    nonisolated(unsafe) static var sheetPinTimer: UInt = 0
    /// Remaining timer ticks before the pin is released.
    nonisolated(unsafe) static var sheetPinTicksRemaining = 0
}

/// Collects one enumerated font family name, skipping vertical families.
private let fontFamilyEnumerationProcedure: @convention(c) (UnsafeRawPointer?, UnsafeRawPointer?, DWORD, LPARAM) -> Int32 = { logFontPointer, _, _, _ in
    guard let logFontPointer else {
        return 1
    }

    let logFont = logFontPointer.loadUnaligned(as: LOGFONTW.self)
    var name = ""
    withUnsafeBytes(of: logFont.lfFaceName) { raw in
        let faceName = raw.bindMemory(to: UInt16.self)
        let length = faceName.firstIndex(of: 0) ?? faceName.count
        name = String(decoding: faceName.prefix(length), as: UTF16.self)
    }
    if !name.isEmpty && !name.hasPrefix("@") {
        Win32NativeControlBackend.enumeratedFontFamilies.insert(name)
    }
    return 1
}

/// Places a dialog under its owner's title area like a sheet.
///
/// Positions come from the owner's on-screen rect rather than the framework
/// anchor frame, so logical-point versus device-pixel differences cannot skew
/// the placement.
private func positionSheetDialog(_ dialog: HWND, under owner: HWND) {
    var ownerRect = RECT()
    var dialogRect = RECT()
    guard winGetWindowRect(owner, &ownerRect) != 0, winGetWindowRect(dialog, &dialogRect) != 0 else {
        return
    }

    let ownerWidth = ownerRect.right - ownerRect.left
    let dialogWidth = dialogRect.right - dialogRect.left
    var contentOrigin = POINT()
    _ = winClientToScreen(owner, &contentOrigin)
    let x = ownerRect.left + max((ownerWidth - dialogWidth) / 2, 0)
    let y = contentOrigin.y
    if dialogRect.left != x || dialogRect.top != y {
        _ = winSetWindowPos(dialog, nil, x, y, 0, 0, swpNoSize | swpNoActivate)
    }
}

/// Re-applies sheet placement while the common dialog finishes opening.
///
/// The Explorer-style dialog restores its remembered placement after
/// activation, overriding a single move from the CBT hook. Pinning for a few
/// ticks lets the sheet position win without a template hook.
private let sheetPositioningTimerProcedure: @convention(c) (HWND?, UINT, UInt, DWORD) -> Void = { _, _, identifier, _ in
    typealias Backend = Win32NativeControlBackend
    if let dialog = Backend.sheetDialog, let owner = Backend.sheetDialogOwner, Backend.sheetPinTicksRemaining > 0 {
        positionSheetDialog(dialog, under: owner)
        Backend.sheetPinTicksRemaining -= 1
    } else {
        Backend.sheetPinTicksRemaining = 0
    }

    if Backend.sheetPinTicksRemaining <= 0 {
        _ = winKillTimer(nil, identifier)
        Backend.sheetPinTimer = 0
        Backend.sheetDialog = nil
        Backend.sheetDialogOwner = nil
    }
}

/// Starts pinning the activating common dialog under the pending owner.
private let sheetPositioningHookProcedure: @convention(c) (Int32, WPARAM, LPARAM) -> LRESULT = { code, wParam, lParam in
    if code == hcbtActivate,
       let owner = Win32NativeControlBackend.pendingSheetOwner,
       let dialog = HWND(bitPattern: wParam),
       dialog != owner {
        Win32NativeControlBackend.pendingSheetOwner = nil
        positionSheetDialog(dialog, under: owner)
        Win32NativeControlBackend.sheetDialog = dialog
        Win32NativeControlBackend.sheetDialogOwner = owner
        Win32NativeControlBackend.sheetPinTicksRemaining = 10
        Win32NativeControlBackend.sheetPinTimer = winSetTimerWithProcedure(nil, 0, 16, sheetPositioningTimerProcedure)
    }
    return winCallNextHookEx(nil, code, wParam, lParam)
}
#endif
