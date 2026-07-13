// Win32Tooltips.swift
// Native tooltip bubbles via a shared tooltips_class32 host (plan 10.5).
//
// AppKit's `NSView.toolTip` flows through the backend's `setToolTip`. Here that
// call registers (or updates) the control on a single shared tooltip control:
// a `tooltips_class32` window that Windows drives on hover. Tools are attached
// with `TTF_IDISHWND | TTF_SUBCLASS`, so the tooltip control subclasses the
// target and shows the bubble automatically — no message pumping on our side.

// Tooltip control window styles.
private let winTTS_ALWAYSTIP: DWORD = 0x01
private let winTTS_NOPREFIX: DWORD = 0x02
private let winWS_POPUP: DWORD = 0x8000_0000
private let winCW_USEDEFAULT: Int32 = Int32(bitPattern: 0x8000_0000)

// Tooltip messages (WM_USER + n) and tool flags.
private let winTTM_ADDTOOLW: UINT = 0x0400 + 50
private let winTTM_DELTOOLW: UINT = 0x0400 + 51
private let winTTM_UPDATETIPTEXTW: UINT = 0x0400 + 57
private let winTTF_IDISHWND: UINT = 0x0001
private let winTTF_SUBCLASS: UINT = 0x0010

// TOOLINFOW field offsets on 64-bit Windows (natural alignment). The struct is
// { UINT cbSize; UINT uFlags; HWND hwnd; UINT_PTR uId; RECT rect; HINSTANCE
//   hinst; LPWSTR lpszText; LPARAM lParam; void *lpReserved; }.
private let winTOOLINFO_size = 72
private let winTOOLINFO_offFlags = 4
private let winTOOLINFO_offHwnd = 8
private let winTOOLINFO_offUId = 16
private let winTOOLINFO_offText = 48

extension Win32NativeControlBackend {
    /// Lazily creates the shared tooltip host window, parented to the control's
    /// top-level window so it can serve tools across the app.
    private func ensureTooltipWindow(ownedBy owner: HWND?) -> HWND? {
        if let tooltipWindow { return tooltipWindow }
        let created = withWideString("tooltips_class32") { className in
            winCreateWindowExW(
                0, className, nil,
                winTTS_ALWAYSTIP | winTTS_NOPREFIX | winWS_POPUP,
                winCW_USEDEFAULT, winCW_USEDEFAULT, winCW_USEDEFAULT, winCW_USEDEFAULT,
                owner, nil, winGetModuleHandleW(nil), nil)
        }
        tooltipWindow = created
        return created
    }

    /// Registers, updates, or removes the native tooltip for a control.
    func applyNativeToolTip(_ toolTip: String?, forControl controlHwnd: HWND) {
        let key = UInt(bitPattern: controlHwnd)
        // Removal.
        guard let text = toolTip, !text.isEmpty else {
            if tooltipRegisteredControls.contains(key), let tip = tooltipWindow {
                withToolInfo(owner: winGetParent(controlHwnd) ?? controlHwnd, control: controlHwnd, text: nil) { infoPtr in
                    _ = winSendMessageW(tip, winTTM_DELTOOLW, 0, Int(bitPattern: infoPtr))
                }
                tooltipRegisteredControls.remove(key)
            }
            return
        }
        let owner = winGetParent(controlHwnd) ?? controlHwnd
        guard let tip = ensureTooltipWindow(ownedBy: owner) else { return }
        let alreadyRegistered = tooltipRegisteredControls.contains(key)
        withToolInfo(owner: owner, control: controlHwnd, text: text) { infoPtr in
            let lParam = Int(bitPattern: infoPtr)
            let message = alreadyRegistered ? winTTM_UPDATETIPTEXTW : winTTM_ADDTOOLW
            _ = winSendMessageW(tip, message, 0, lParam)
        }
        tooltipRegisteredControls.insert(key)
    }

    /// Builds a TOOLINFOW in a temporary buffer and runs `body` with a pointer
    /// to it. The wide text (if any) stays alive for the duration of the call.
    private func withToolInfo(owner: HWND?, control: HWND, text: String?,
                              _ body: (UnsafeMutableRawPointer) -> Void) {
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: winTOOLINFO_size, alignment: 8)
        defer { buffer.deallocate() }
        // Zero the struct, then fill the fields we use.
        buffer.initializeMemory(as: UInt8.self, repeating: 0, count: winTOOLINFO_size)
        buffer.storeBytes(of: UInt32(winTOOLINFO_size), toByteOffset: 0, as: UInt32.self)
        buffer.storeBytes(of: winTTF_IDISHWND | winTTF_SUBCLASS, toByteOffset: winTOOLINFO_offFlags, as: UInt32.self)
        buffer.storeBytes(of: owner, toByteOffset: winTOOLINFO_offHwnd, as: HWND?.self)
        buffer.storeBytes(of: UInt(bitPattern: control), toByteOffset: winTOOLINFO_offUId, as: UInt.self)

        if let text {
            withWideString(text) { wide in
                buffer.storeBytes(of: UnsafeMutableRawPointer(mutating: wide),
                                  toByteOffset: winTOOLINFO_offText, as: UnsafeMutableRawPointer?.self)
                body(buffer)
            }
        } else {
            body(buffer)
        }
    }
}
