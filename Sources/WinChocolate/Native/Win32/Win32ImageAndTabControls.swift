#if os(Windows)
extension Win32NativeControlBackend {
    /// Creates a native image-view child.
    public func createImageView(description: String, imagePath: String?, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = createChildWindow(
            className: "STATIC",
            text: description,
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: wsChild | wsVisible | wsBorder | ssNotify | (imagePath == nil ? 0 : ssBitmap | ssCenterImage)
        )
        subclassControlForTabKey(handle)
        setImagePath(imagePath, description: description, for: handle)
        return handle
    }

    /// Creates a native tab-view child.
    public func createTabView(items: [String], selectedIndex: Int, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        initializeTabControls()
        let handle = createChildWindow(
            className: "SysTabControl32",
            text: "",
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: wsChild | wsVisible | wsTabStop
        )
        subclassControlForTabKey(handle)
        setTabViewItems(items, selectedIndex: selectedIndex, for: handle)
        return handle
    }

    /// Updates a native image-view bitmap source.
    public func setImagePath(_ imagePath: String?, description: String, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        if let bitmap = bitmaps.removeValue(forKey: handle.rawValue) {
            _ = winSendMessageW(hwnd, stmSetImage, WPARAM(imageBitmap), 0)
            _ = winDeleteObject(bitmap)
        }

        guard let imagePath, !imagePath.isEmpty else {
            setText(description, for: handle)
            return
        }

        // BMP files keep the fast LoadImageW path; other formats (PNG, JPEG,
        // GIF, ...) fall back to GDI+ decoding into an equivalent HBITMAP.
        let bitmap = withWideString(imagePath) { path in
            winLoadImageW(nil, path, imageBitmap, 0, 0, lrLoadFromFile | lrCreatedDIBSection)
        } ?? Win32GdiPlusImageDecoder.decodeBitmap(fromFile: imagePath)?.bitmap

        guard let bitmap else {
            setText(description, for: handle)
            return
        }

        bitmaps[handle.rawValue] = bitmap
        _ = winSendMessageW(hwnd, stmSetImage, WPARAM(imageBitmap), LPARAM(bitPattern: bitmap))
        invalidate(handle)
    }

    /// Replaces native tab-view items.
    public func setTabViewItems(_ items: [String], selectedIndex: Int, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winSendMessageW(hwnd, tcmDeleteAllItems, 0, 0)
        for (index, title) in items.enumerated() {
            withWideString(title) { wideTitle in
                var item = TCITEMW()
                item.mask = tciText
                item.pszText = UnsafeMutablePointer(mutating: wideTitle)
                withUnsafePointer(to: item) { itemPointer in
                    _ = winSendMessageW(hwnd, tcmInsertItemW, WPARAM(index), Int(bitPattern: itemPointer))
                }
            }
        }
        setTabViewSelectedIndex(selectedIndex, for: handle)
    }

    /// Updates native tab-view selection.
    public func setTabViewSelectedIndex(_ selectedIndex: Int, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winSendMessageW(hwnd, tcmSetCurSel, WPARAM(selectedIndex), 0)
    }

    /// Reads native tab-view selection.
    public func tabViewSelectedIndex(for handle: NativeHandle) -> Int {
        guard let hwnd = hwnd(from: handle) else {
            return -1
        }

        return Int(winSendMessageW(hwnd, tcmGetCurSel, 0, 0))
    }
}
#endif
