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
    ///
    /// The buffer is GMEM_MOVEABLE as SetClipboardData requires; on success
    /// the system owns the memory, so it is only freed when handoff fails.
    public func setClipboardString(_ string: String) {
        guard winOpenClipboard(nil) != 0 else {
            return
        }
        defer {
            _ = winCloseClipboard()
        }

        _ = winEmptyClipboard()

        let units = Array(string.utf16) + [0]
        let byteCount = units.count * MemoryLayout<UInt16>.size
        guard let memory = winGlobalAlloc(gmemMoveable, UInt(byteCount)), let target = winGlobalLock(memory) else {
            return
        }
        units.withUnsafeBytes { buffer in
            target.copyMemory(from: buffer.baseAddress!, byteCount: byteCount)
        }
        _ = winGlobalUnlock(memory)

        if winSetClipboardData(cfUnicodeText, memory) == nil {
            _ = winGlobalFree(memory)
        }
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
}
#endif
