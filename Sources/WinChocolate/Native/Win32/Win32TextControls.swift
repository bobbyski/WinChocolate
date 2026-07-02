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
                ? wsChild | wsVisible | wsTabStop | wsBorder | wsVScroll | esMultiline | esAutoVScroll | esWantReturn
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
