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
