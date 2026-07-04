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
    public func setClipboardContents(text: String?, dataRepresentations: [String: [UInt8]]) {
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
