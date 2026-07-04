#if os(Windows)
extension Win32NativeControlBackend {
    /// Creates a native push button child.
    public func createButton(title: String, frame: NSRect, parent: NativeHandle?, isBordered: Bool) -> NativeHandle {
        let handle = createChildWindow(
            className: "BUTTON",
            text: title,
            frame: frame,
            parent: parent,
            commandIdentifier: nextCommandID(),
            style: wsChild | wsVisible | wsTabStop | (isBordered ? 0 : bsFlat)
        )
        subclassControlForTabKey(handle)
        return handle
    }

    /// Toggles a push button's flat (square) bezel style.
    public func setButtonBezelFlat(_ flat: Bool, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        var style = winGetWindowLongPtrW(hwnd, gwlStyle)
        if flat {
            style |= LONG_PTR(bsFlat)
        } else {
            style &= ~LONG_PTR(bsFlat)
        }
        _ = winSetWindowLongPtrW(hwnd, gwlStyle, style)
        _ = winInvalidateRect(hwnd, nil, 1)
    }

    /// Creates a native checkbox child.
    public func createCheckbox(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = createChildWindow(
            className: "BUTTON",
            text: title,
            frame: frame,
            parent: parent,
            commandIdentifier: nextCommandID(),
            style: wsChild | wsVisible | wsTabStop | bsAutoCheckBox
        )
        // Checkboxes paint their label area via WM_CTLCOLORSTATIC; making them
        // transparent shows the window color instead of a control-face box.
        transparentBackgroundHandles.insert(handle.rawValue)
        subclassControlForTabKey(handle)
        return handle
    }

    /// Creates a native radio button child.
    public func createRadioButton(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = createChildWindow(
            className: "BUTTON",
            text: title,
            frame: frame,
            parent: parent,
            commandIdentifier: nextCommandID(),
            style: wsChild | wsVisible | wsTabStop | bsAutoRadioButton
        )
        transparentBackgroundHandles.insert(handle.rawValue)
        subclassControlForTabKey(handle)
        return handle
    }

    /// Creates a native box child.
    public func createBox(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = createChildWindow(
            className: "BUTTON",
            text: title,
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: wsChild | wsVisible | bsGroupBox
        )
        groupBoxHandles.insert(handle.rawValue)
        // Subclassed so the box can erase its own interior; see the
        // WM_ERASEBKGND group-box handling in the control dispatch.
        subclassControlForTabKey(handle)
        return handle
    }

    /// Sets a button's image from a file path (nil clears it).
    ///
    /// The bitmap is decoded like image views (BMP via `LoadImageW`, other
    /// formats via GDI+) and attached with `BM_SETIMAGE` after switching the
    /// button to `BS_BITMAP` so the glyph shows.
    public func setButtonImage(imagePath: String?, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        if let bitmap = bitmaps.removeValue(forKey: handle.rawValue) {
            _ = winSendMessageW(hwnd, bmSetImage, WPARAM(imageBitmap), 0)
            _ = winDeleteObject(bitmap)
        }

        guard let imagePath, !imagePath.isEmpty else {
            var style = winGetWindowLongPtrW(hwnd, gwlStyle)
            style &= ~LONG_PTR(bsBitmap)
            _ = winSetWindowLongPtrW(hwnd, gwlStyle, style)
            invalidate(handle)
            return
        }

        let bitmap = withWideString(imagePath) { path in
            winLoadImageW(nil, path, imageBitmap, 0, 0, lrLoadFromFile | lrCreatedDIBSection)
        } ?? Win32GdiPlusImageDecoder.decodeBitmap(fromFile: imagePath)?.bitmap

        guard let bitmap else {
            return
        }

        bitmaps[handle.rawValue] = bitmap
        var style = winGetWindowLongPtrW(hwnd, gwlStyle)
        style |= LONG_PTR(bsBitmap)
        _ = winSetWindowLongPtrW(hwnd, gwlStyle, style)
        _ = winSendMessageW(hwnd, bmSetImage, WPARAM(imageBitmap), LPARAM(bitPattern: bitmap))
        invalidate(handle)
    }

    /// Updates a native button check state.
    public func setButtonState(_ state: NSControl.StateValue, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        let nativeState: WPARAM
        switch state {
        case .off:
            nativeState = bstUnchecked
        case .on:
            nativeState = bstChecked
        case .mixed:
            nativeState = bstIndeterminate
        }

        _ = winSendMessageW(hwnd, bmSetCheck, nativeState, 0)
    }

    /// Reads a native button check state.
    public func buttonState(for handle: NativeHandle) -> NSControl.StateValue {
        guard let hwnd = hwnd(from: handle) else {
            return .off
        }

        let nativeState = winSendMessageW(hwnd, bmGetCheck, 0, 0)
        switch WPARAM(nativeState) {
        case bstChecked:
            return .on
        case bstIndeterminate:
            return .mixed
        default:
            return .off
        }
    }
}
#endif
