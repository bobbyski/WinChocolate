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
