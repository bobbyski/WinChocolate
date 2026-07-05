#if os(Windows)
extension Win32NativeControlBackend {
    /// Reads the clipboard's Unicode text, when any.
    public func clipboardString() -> String? {
        guard winIsClipboardFormatAvailable(cfUnicodeText) != 0, winOpenClipboard(nil) != 0 else {
            return nil
        }
        defer {
            _ = winCloseClipboard()
        }

        guard let data = winGetClipboardData(cfUnicodeText), let memory = winGlobalLock(data) else {
            return nil
        }
        defer {
            _ = winGlobalUnlock(data)
        }

        let units = memory.assumingMemoryBound(to: UInt16.self)
        var length = 0
        while units[length] != 0 {
            length += 1
        }
        return String(decoding: UnsafeBufferPointer(start: units, count: length), as: UTF16.self)
    }

    /// Replaces the clipboard contents with Unicode text.
    public func setClipboardString(_ string: String) {
        setClipboardContents(text: string, dataRepresentations: [:])
    }

    /// Replaces the clipboard with several representations at once.
    ///
    /// One open/empty/write/close cycle keeps the representations together
    /// as a single clipboard update.
    public func setClipboardContents(text: String?, dataRepresentations: [String: [UInt8]], filePaths: [String]) {
        guard winOpenClipboard(nil) != 0 else {
            return
        }
        defer {
            _ = winCloseClipboard()
        }

        _ = winEmptyClipboard()

        if let text {
            let units = Array(text.utf16) + [0]
            writeClipboardBytes(units, format: cfUnicodeText)
        }

        for (formatName, bytes) in dataRepresentations {
            let format = withWideString(formatName) { winRegisterClipboardFormatW($0) }
            guard format != 0 else {
                continue
            }
            writeClipboardBytes(bytes, format: format)
        }

        if !filePaths.isEmpty {
            writeClipboardBytes(Self.dropFilesBytes(for: filePaths), format: cfHDrop)
        }
    }

    /// Reads the absolute file paths of a clipboard file list (`CF_HDROP`).
    ///
    /// The `DROPFILES` block is parsed directly: a 20-byte header whose first
    /// field is the offset to a double-NUL-terminated path list, plus a wide
    /// flag. Every modern producer writes wide paths; ANSI lists are skipped.
    public func clipboardFilePaths() -> [String] {
        guard winIsClipboardFormatAvailable(cfHDrop) != 0, winOpenClipboard(nil) != 0 else {
            return []
        }
        defer {
            _ = winCloseClipboard()
        }

        guard let data = winGetClipboardData(cfHDrop), let memory = winGlobalLock(data) else {
            return []
        }
        defer {
            _ = winGlobalUnlock(data)
        }

        let byteCount = Int(winGlobalSize(data))
        guard byteCount > 20 else {
            return []
        }
        let bytes = memory.assumingMemoryBound(to: UInt8.self)
        let offset = Int(bytes[0]) | (Int(bytes[1]) << 8) | (Int(bytes[2]) << 16) | (Int(bytes[3]) << 24)
        let wide = bytes[16] != 0
        guard wide, offset >= 20, offset < byteCount else {
            return []
        }

        var paths: [String] = []
        var units: [UInt16] = []
        var position = offset
        while position + 1 < byteCount {
            let unit = UInt16(bytes[position]) | (UInt16(bytes[position + 1]) << 8)
            position += 2
            if unit == 0 {
                if units.isEmpty {
                    break
                }
                paths.append(String(decoding: units, as: UTF16.self))
                units.removeAll()
            } else {
                units.append(unit)
            }
        }
        return paths
    }

    /// Builds a wide `DROPFILES` block for a file list (also used by the OLE
    /// drag-source data object).
    static func dropFilesBytes(for paths: [String]) -> [UInt8] {
        // Header: pFiles offset (20), drop point (unused), fNC, fWide = 1.
        var bytes: [UInt8] = [
            20, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0,
            0, 0, 0, 0,
            1, 0, 0, 0,
        ]
        for path in paths {
            for unit in path.utf16 {
                bytes.append(UInt8(unit & 0xff))
                bytes.append(UInt8(unit >> 8))
            }
            bytes.append(0)
            bytes.append(0)
        }
        bytes.append(0)
        bytes.append(0)
        return bytes
    }

    /// Reads the bytes of a named clipboard format, when present.
    public func clipboardData(forFormat formatName: String) -> [UInt8]? {
        let format = withWideString(formatName) { winRegisterClipboardFormatW($0) }
        guard format != 0,
              winIsClipboardFormatAvailable(format) != 0,
              winOpenClipboard(nil) != 0 else {
            return nil
        }
        defer {
            _ = winCloseClipboard()
        }

        guard let data = winGetClipboardData(format), let memory = winGlobalLock(data) else {
            return nil
        }
        defer {
            _ = winGlobalUnlock(data)
        }

        let byteCount = Int(winGlobalSize(data))
        guard byteCount > 0 else {
            return []
        }

        let bytes = memory.assumingMemoryBound(to: UInt8.self)
        return Array(UnsafeBufferPointer(start: bytes, count: byteCount))
    }

    /// Returns whether a named clipboard format is currently available.
    public func clipboardHasData(forFormat formatName: String) -> Bool {
        let format = withWideString(formatName) { winRegisterClipboardFormatW($0) }
        return format != 0 && winIsClipboardFormatAvailable(format) != 0
    }

    /// Empties the clipboard.
    public func clearClipboard() {
        guard winOpenClipboard(nil) != 0 else {
            return
        }
        defer {
            _ = winCloseClipboard()
        }

        _ = winEmptyClipboard()
    }

    /// The system clipboard sequence number, which advances on every change
    /// from any application.
    public func clipboardChangeCount() -> Int {
        Int(winGetClipboardSequenceNumber())
    }

    /// Hands one buffer to the open clipboard as a movable global allocation.
    ///
    /// On success the system owns the memory, so it is only freed when the
    /// handoff fails. The clipboard must already be open and emptied.
    private func writeClipboardBytes<Buffer: Collection>(_ buffer: Buffer, format: UINT) where Buffer.Element: FixedWidthInteger {
        let elementSize = MemoryLayout<Buffer.Element>.size
        let byteCount = buffer.count * elementSize
        guard byteCount > 0,
              let memory = winGlobalAlloc(gmemMoveable, UInt(byteCount)),
              let target = winGlobalLock(memory) else {
            return
        }

        Array(buffer).withUnsafeBytes { source in
            target.copyMemory(from: source.baseAddress!, byteCount: byteCount)
        }
        // GlobalAlloc rounds sizes up; zero the slack so text formats like
        // RTF stay NUL-terminated instead of trailing allocation garbage.
        let allocated = Int(winGlobalSize(memory))
        if allocated > byteCount {
            target.advanced(by: byteCount).initializeMemory(as: UInt8.self, repeating: 0, count: allocated - byteCount)
        }
        _ = winGlobalUnlock(memory)

        if winSetClipboardData(format, memory) == nil {
            _ = winGlobalFree(memory)
        }
    }
}
#endif
