#if os(Windows)
extension Win32NativeControlBackend {
    /// Creates a native static text field child.
    ///
    /// A multi-line editable field wraps text with a scrolling `EDIT`
    /// (`ES_MULTILINE`) instead of the single-line auto-h-scroll style.
    public func createTextField(text: String, frame: NSRect, parent: NativeHandle?, isEditable: Bool, isBordered: Bool, isMultiline: Bool) -> NativeHandle {
        let editStyle: DWORD = isMultiline
            ? esMultiline | esAutoVScroll | esWantReturn | wsVScroll
            : esAutoHScroll
        let handle = createChildWindow(
            className: isEditable ? "EDIT" : "STATIC",
            text: text,
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: isEditable
                ? wsChild | wsVisible | wsTabStop | (isBordered ? wsBorder : 0) | editStyle
                : wsChild | wsVisible
        )
        if isEditable {
            subclassControlForTabKey(handle)
            if isMultiline {
                // Multi-line edits keep Return for newlines, so default-button
                // key routing skips them.
                multilineTextHandles.insert(handle.rawValue)
            }
        }
        return handle
    }

    /// Applies (or removes) a sunken client-edge bezel on a text field.
    public func setTextFieldBezeled(_ bezeled: Bool, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        var exStyle = winGetWindowLongPtrW(hwnd, gwlExStyle)
        if bezeled {
            exStyle |= LONG_PTR(wsExClientEdge)
        } else {
            exStyle &= ~LONG_PTR(wsExClientEdge)
        }
        _ = winSetWindowLongPtrW(hwnd, gwlExStyle, exStyle)
        _ = winSetWindowPos(hwnd, nil, 0, 0, 0, 0, swpNoMove | swpNoSize | swpNoZOrder | swpNoActivate | swpFrameChanged)
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
    ///
    /// Rich text views use the modern rich-edit control (`RICHEDIT50W` from
    /// Msftedit.dll) so per-range character formatting works; plain views
    /// keep the classic multiline `EDIT`.
    public func createTextView(text: String, frame: NSRect, parent: NativeHandle?, isEditable: Bool, isRichText: Bool) -> NativeHandle {
        let editStyle = wsChild | wsVisible | wsTabStop | wsBorder | wsVScroll | esMultiline | esAutoVScroll | esWantReturn | esNoHideSel
        var className = isEditable ? "EDIT" : "STATIC"
        if isRichText {
            Self.loadRichEditLibraryIfNeeded()
            className = "RICHEDIT50W"
        }

        let handle = createChildWindow(
            className: className,
            text: text,
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: isEditable || isRichText ? editStyle : wsChild | wsVisible | wsBorder
        )
        if isEditable || isRichText {
            // Multiline edits keep Return for newlines, so the default-button
            // key-equivalent routing skips them.
            multilineTextHandles.insert(handle.rawValue)
        }
        if isRichText {
            richTextHandles.insert(handle.rawValue)
            if let hwnd = hwnd(from: handle) {
                // Rich edit only sends EN_CHANGE when asked.
                _ = winSendMessageW(hwnd, emSetEventMask, 0, enmChange)
                if !isEditable {
                    _ = winSendMessageW(hwnd, emSetReadOnly, 1, 0)
                }
            }
        }
        if isEditable || isRichText {
            subclassControlForTabKey(handle)
        }
        return handle
    }

    /// Loads the rich-edit window classes once per process.
    private static func loadRichEditLibraryIfNeeded() {
        guard !isRichEditLibraryLoaded else {
            return
        }

        isRichEditLibraryLoaded = true
        withWideString("Msftedit.dll") { name in
            _ = winLoadLibraryW(name)
        }
    }

    /// Applies character formatting to a text range of a rich text view.
    ///
    /// The range is selected, formatted with `EM_SETCHARFORMAT`, and the
    /// user's selection restored, so callers can format without disturbing
    /// editing state.
    public func setTextRangeFormat(font: NSFont?, color: NSColor?, underline: Bool?, strikethrough: Bool?, location: Int, length: Int, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle), font != nil || color != nil || underline != nil || strikethrough != nil else {
            return
        }

        let savedSelection = textSelection(for: handle)
        let start = max(0, location)
        _ = winSendMessageW(hwnd, emSetSel, WPARAM(start), LPARAM(start + max(0, length)))

        var format = CHARFORMATW()
        format.cbSize = UINT(MemoryLayout<CHARFORMATW>.stride)
        if let font {
            format.dwMask |= cfmFace | cfmSize | cfmBold | cfmItalic
            // Rich edit character heights are in twips (1/20 point).
            format.yHeight = Int32((font.pointSize * 20).rounded())
            if font.weight.isBold {
                format.dwEffects |= cfeBold
            }
            if font.italic {
                format.dwEffects |= cfeItalic
            }
            withUnsafeMutableBytes(of: &format.szFaceName) { raw in
                let faceName = raw.bindMemory(to: UInt16.self)
                for (index, unit) in font.fontName.utf16.prefix(31).enumerated() {
                    faceName[index] = unit
                }
            }
        }
        if let color {
            format.dwMask |= cfmColor
            format.crTextColor = colorRef(from: color)
        }
        if let underline {
            format.dwMask |= cfmUnderline
            if underline {
                format.dwEffects |= cfeUnderline
            }
        }
        if let strikethrough {
            format.dwMask |= cfmStrikeOut
            if strikethrough {
                format.dwEffects |= cfeStrikeOut
            }
        }
        withUnsafePointer(to: &format) { pointer in
            _ = winSendMessageW(hwnd, emSetCharFormat, scfSelection, Int(bitPattern: pointer))
        }

        _ = winSendMessageW(hwnd, emSetSel, WPARAM(savedSelection.location), LPARAM(savedSelection.location + savedSelection.length))
    }

    /// Registers the action to perform when native text changes.
    public func registerTextChangeAction(for handle: NativeHandle, action: @escaping (String) -> Void) {
        textChangeActions[handle.rawValue] = action
    }

    /// Sets the cue-banner placeholder shown while an edit field is empty.
    public func setTextPlaceholder(_ placeholder: String?, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        // wParam 1 keeps the cue visible even while the field has focus,
        // matching AppKit's placeholder behavior.
        withWideString(placeholder ?? "") { text in
            _ = winSendMessageW(hwnd, emSetCueBanner, 1, Int(bitPattern: text))
        }
    }

    /// Sets the horizontal text alignment of an edit field.
    public func setTextAlignment(_ alignment: NSTextAlignment, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        var style = winGetWindowLongPtrW(hwnd, gwlStyle)
        style &= ~LONG_PTR(esCenter | esRight)
        switch alignment {
        case .center:
            style |= LONG_PTR(esCenter)
        case .right:
            style |= LONG_PTR(esRight)
        case .left, .natural:
            break
        }
        _ = winSetWindowLongPtrW(hwnd, gwlStyle, style)
        _ = winInvalidateRect(hwnd, nil, 1)
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
        // Rich edit ignores WM_CTLCOLOR; its whole-control color is a
        // character format applied to all text.
        if richTextHandles.contains(handle.rawValue), let hwnd = hwnd(from: handle), let color {
            var format = CHARFORMATW()
            format.cbSize = UINT(MemoryLayout<CHARFORMATW>.stride)
            format.dwMask = cfmColor
            format.crTextColor = colorRef(from: color)
            withUnsafePointer(to: &format) { pointer in
                _ = winSendMessageW(hwnd, emSetCharFormat, scfAll, Int(bitPattern: pointer))
            }
            return
        }

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
                font.italic ? 1 : 0,
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

    /// Measures a single-line text run with the real font metrics.
    public func measureText(_ text: String, fontName: String, fontSize: CGFloat, weight: Int, italic: Bool) -> NSSize {
        guard let deviceContext = winGetDC(nil) else {
            return NSMakeSize(0, 0)
        }
        defer {
            _ = winReleaseDC(nil, deviceContext)
        }

        // Points convert to pixels at 96 DPI, matching setFont rendering.
        let font = withWideString(fontName) { faceName in
            winCreateFontW(
                -Int32(max((fontSize * 96.0 / 72.0).rounded(), 1)),
                0,
                0,
                0,
                Int32(weight),
                italic ? 1 : 0,
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
        guard let font else {
            return NSMakeSize(0, 0)
        }
        defer {
            _ = winDeleteObject(font)
        }

        let previousFont = winSelectObject(deviceContext, font)
        var size = SIZE()
        let characters = Array(text.utf16)
        characters.withUnsafeBufferPointer { buffer in
            _ = winGetTextExtentPoint32W(deviceContext, buffer.baseAddress, Int32(buffer.count), &size)
        }
        _ = winSelectObject(deviceContext, previousFont ?? nil)
        return NSMakeSize(CGFloat(size.cx), CGFloat(size.cy))
    }
}
#endif
