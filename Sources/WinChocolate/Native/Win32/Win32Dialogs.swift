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
        if options.kind == .open && options.canChooseDirectories && !options.canChooseFiles {
            return runFolderDialog(options, owner: owner)
        }

        return runOpenSaveDialog(options, owner: owner)
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
#endif
