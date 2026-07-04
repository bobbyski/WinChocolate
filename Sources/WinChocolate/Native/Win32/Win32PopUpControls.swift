#if os(Windows)
extension Win32NativeControlBackend {
    /// Creates a native pop-up button child.
    public func createPopUpButton(items: [String], selectedIndex: Int, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let nativeFrame = NSRect(
            x: frame.origin.x,
            y: frame.origin.y,
            width: frame.size.width,
            height: max(frame.size.height, 160)
        )
        let handle = createChildWindow(
            className: "COMBOBOX",
            text: "",
            frame: nativeFrame,
            parent: parent,
            commandIdentifier: nextCommandID(),
            style: wsChild | wsVisible | wsTabStop | wsVScroll | cbsDropdownList
        )
        subclassControlForTabKey(handle)
        comboBoxHandles.insert(handle.rawValue)
        comboBoxDropdownHeights[handle.rawValue] = 160
        setPopUpButtonItems(items, selectedIndex: selectedIndex, for: handle)
        return handle
    }

    /// Creates a native editable combo-box child.
    public func createComboBox(items: [String], text: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let nativeFrame = NSRect(
            x: frame.origin.x,
            y: frame.origin.y,
            width: frame.size.width,
            height: max(frame.size.height, 128)
        )
        let handle = createChildWindow(
            className: "COMBOBOX",
            text: text,
            frame: nativeFrame,
            parent: parent,
            commandIdentifier: nil,
            style: wsChild | wsVisible | wsTabStop | wsVScroll | cbsDropdown
        )
        subclassControlForTabKey(handle)
        subclassFirstChildControlForTabKey(handle)
        comboBoxHandles.insert(handle.rawValue)
        comboBoxDropdownHeights[handle.rawValue] = 128
        setComboBoxItems(items, text: text, for: handle)
        return handle
    }

    /// Replaces native pop-up button items.
    public func setPopUpButtonItems(_ items: [String], selectedIndex: Int, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winSendMessageW(hwnd, cbResetContent, 0, 0)
        for item in items {
            withWideString(item) { title in
                _ = winSendMessageW(hwnd, cbAddString, 0, Int(bitPattern: title))
            }
        }
        setPopUpButtonSelectedIndex(selectedIndex, for: handle)
    }

    /// Updates native pop-up button selection.
    public func setPopUpButtonSelectedIndex(_ selectedIndex: Int, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        let nativeIndex = selectedIndex < 0 ? WPARAM.max : WPARAM(selectedIndex)
        _ = winSendMessageW(hwnd, cbSetCurSel, nativeIndex, 0)
    }

    /// Reads native pop-up button selection.
    public func popUpButtonSelectedIndex(for handle: NativeHandle) -> Int {
        guard let hwnd = hwnd(from: handle) else {
            return -1
        }

        return Int(winSendMessageW(hwnd, cbGetCurSel, 0, 0))
    }

    /// Replaces native combo-box items.
    public func setComboBoxItems(_ items: [String], text: String, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winSendMessageW(hwnd, cbResetContent, 0, 0)
        for item in items {
            withWideString(item) { title in
                _ = winSendMessageW(hwnd, cbAddString, 0, Int(bitPattern: title))
            }
        }
        setText(text, for: handle)
    }

    /// Sets how many items a combo box shows before the list scrolls.
    ///
    /// The dropdown height is part of the combo's window height, so a taller
    /// window shows more list rows; the edit portion keeps its system height.
    public func setComboBoxVisibleItems(_ count: Int, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle), count > 0 else {
            return
        }

        let itemHeight = 16
        let editHeight = 24
        let dropdownHeight = CGFloat(editHeight + count * itemHeight + 4)
        comboBoxDropdownHeights[handle.rawValue] = dropdownHeight

        var rect = RECT()
        guard winGetWindowRect(hwnd, &rect) != 0 else {
            return
        }
        _ = winSetWindowPos(hwnd, nil, 0, 0, rect.right - rect.left, Int32(dropdownHeight), swpNoMove | swpNoZOrder | swpNoActivate)
    }

    /// Reads native combo-box text.
    public func comboBoxText(for handle: NativeHandle) -> String {
        guard let hwnd = hwnd(from: handle) else {
            return ""
        }

        return text(from: hwnd)
    }
}
#endif
