#if os(Windows)
extension Win32NativeControlBackend {
    /// Creates a native static text field child.
    public func createTextField(text: String, frame: NSRect, parent: NativeHandle?, isEditable: Bool, isBordered: Bool) -> NativeHandle {
        let handle = createChildWindow(
            className: isEditable ? "EDIT" : "STATIC",
            text: text,
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: isEditable
                ? wsChild | wsVisible | wsTabStop | (isBordered ? wsBorder : 0) | esAutoHScroll
                : wsChild | wsVisible
        )
        if isEditable {
            subclassControlForTabKey(handle)
        }
        return handle
    }

    /// Creates a native secure text field child.
    public func createSecureTextField(text: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = createChildWindow(
            className: "EDIT",
            text: text,
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: wsChild | wsVisible | wsTabStop | wsBorder | esAutoHScroll | esPassword
        )
        subclassControlForTabKey(handle)
        return handle
    }

    /// Creates a native multiline text view child.
    public func createTextView(text: String, frame: NSRect, parent: NativeHandle?, isEditable: Bool) -> NativeHandle {
        let handle = createChildWindow(
            className: isEditable ? "EDIT" : "STATIC",
            text: text,
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: isEditable
                ? wsChild | wsVisible | wsTabStop | wsBorder | wsVScroll | esMultiline | esAutoVScroll | esWantReturn | esNoHideSel
                : wsChild | wsVisible | wsBorder
        )
        if isEditable {
            subclassControlForTabKey(handle)
        }
        return handle
    }

    /// Registers the action to perform when native text changes.
    public func registerTextChangeAction(for handle: NativeHandle, action: @escaping (String) -> Void) {
        textChangeActions[handle.rawValue] = action
    }

    /// Reads the native edit-control selection with `EM_GETSEL`.
    public func textSelection(for handle: NativeHandle) -> (location: Int, length: Int) {
        guard let hwnd = hwnd(from: handle) else {
            return (0, 0)
        }

        var start: DWORD = 0
        var end: DWORD = 0
        withUnsafeMutablePointer(to: &start) { startPointer in
            withUnsafeMutablePointer(to: &end) { endPointer in
                _ = winSendMessageW(hwnd, emGetSel, UInt(bitPattern: startPointer), Int(bitPattern: endPointer))
            }
        }
        return (Int(start), Int(max(end, start) - start))
    }

    /// Updates the native edit-control selection with `EM_SETSEL` and scrolls
    /// the caret into view with `EM_SCROLLCARET`.
    public func setTextSelection(location: Int, length: Int, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        let start = max(0, location)
        _ = winSendMessageW(hwnd, emSetSel, WPARAM(start), LPARAM(start + max(0, length)))
        _ = winSendMessageW(hwnd, emScrollCaret, 0, 0)
    }

    /// Replaces the selected native edit-control text with `EM_REPLACESEL`.
    ///
    /// The replacement participates in the control's undo buffer (wParam 1).
    public func replaceSelectedText(_ text: String, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        withWideString(text) { wideText in
            _ = winSendMessageW(hwnd, emReplaceSel, 1, Int(bitPattern: wideText))
        }
    }

    /// Updates the native edit-control read-only style with `EM_SETREADONLY`.
    public func setTextEditable(_ isEditable: Bool, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winSendMessageW(hwnd, emSetReadOnly, isEditable ? 0 : 1, 0)
    }

    /// Updates a native control's text color.
    public func setTextColor(_ color: NSColor?, for handle: NativeHandle) {
        if let color {
            textColors[handle.rawValue] = colorRef(from: color)
        } else {
            textColors.removeValue(forKey: handle.rawValue)
        }
        invalidate(handle)
    }

    /// Updates a native control's background color.
    public func setBackgroundColor(_ color: NSColor?, for handle: NativeHandle) {
        if let brush = backgroundBrushes.removeValue(forKey: handle.rawValue) {
            _ = winDeleteObject(brush)
        }

        if let color {
            let colorRef = colorRef(from: color)
            backgroundColors[handle.rawValue] = colorRef
            if let brush = winCreateSolidBrush(colorRef) {
                backgroundBrushes[handle.rawValue] = brush
            }
        } else {
            backgroundColors.removeValue(forKey: handle.rawValue)
        }
        invalidate(handle)
    }

    /// Updates whether a native control paints its own background.
    public func setDrawsBackground(_ drawsBackground: Bool, for handle: NativeHandle) {
        if drawsBackground {
            transparentBackgroundHandles.remove(handle.rawValue)
        } else {
            transparentBackgroundHandles.insert(handle.rawValue)
        }
        invalidate(handle)
    }

    /// Updates a native control's font.
    public func setFont(_ font: NSFont?, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        if let nativeFont = fonts.removeValue(forKey: handle.rawValue) {
            _ = winDeleteObject(nativeFont)
        }

        guard let font else {
            _ = winSendMessageW(hwnd, wmSetFont, 0, 1)
            invalidate(handle)
            return
        }

        let fontHeight = -Int32((font.pointSize * 96.0 / 72.0).rounded())
        let nativeFont = withWideString(font.fontName) { faceName in
            winCreateFontW(
                fontHeight,
                0,
                0,
                0,
                Int32(font.weight.rawValue),
                0,
                0,
                0,
                defaultCharset,
                defaultPrecision,
                defaultPrecision,
                defaultQuality,
                defaultPitchAndFamily,
                faceName
            )
        }

        guard let nativeFont else {
            return
        }

        fonts[handle.rawValue] = nativeFont
        _ = winSendMessageW(hwnd, wmSetFont, UInt(bitPattern: nativeFont), 1)
        invalidate(handle)
    }
}
#endif
