#if os(Windows)
extension Win32NativeControlBackend {
    /// Registers the action to perform when a native control is activated.
    public func registerAction(for handle: NativeHandle, action: @escaping () -> Void) {
        controlActions[handle.rawValue] = action
    }

    /// Registers the action to perform when a native view receives a mouse-down event.
    public func registerMouseDownAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        mouseDownActions[handle.rawValue] = action
    }

    /// Registers the action to perform when a native view receives a mouse-up event.
    public func registerMouseUpAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        mouseUpActions[handle.rawValue] = action
    }

    /// Registers the action to perform when a native view receives a mouse-moved event.
    public func registerMouseMovedAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        mouseMovedActions[handle.rawValue] = action
    }

    /// Registers the action to perform when a native view receives a mouse-dragged event.
    public func registerMouseDraggedAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        mouseDraggedActions[handle.rawValue] = action
    }

    /// Registers the action to perform when a native view receives a key-down event.
    public func registerKeyDownAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        keyDownActions[handle.rawValue] = action
    }

    /// Registers the action to perform when a native view receives a key-up event.
    public func registerKeyUpAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        keyUpActions[handle.rawValue] = action
    }

    /// Registers the action to perform when a native view receives a right mouse-down event.
    public func registerRightMouseDownAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        rightMouseDownActions[handle.rawValue] = action
    }

    /// Registers the action to perform when a native view receives a right mouse-up event.
    public func registerRightMouseUpAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        rightMouseUpActions[handle.rawValue] = action
    }

    /// Registers the action to perform when a native view receives a tertiary mouse-down event.
    public func registerOtherMouseDownAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        otherMouseDownActions[handle.rawValue] = action
    }

    /// Registers the action to perform when a native view receives a tertiary mouse-up event.
    public func registerOtherMouseUpAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        otherMouseUpActions[handle.rawValue] = action
    }

    /// Registers the handler consulted for menu key equivalents before key-down routing.
    public func registerKeyEquivalentHandler(_ handler: @escaping (NSEvent) -> Bool) {
        keyEquivalentHandler = handler
    }

    /// Makes the named framework cursor the active pointer image.
    public func setCursor(named name: String) {
        activeCursorName = name
        _ = winSetCursor(systemCursor(named: name))
    }

    /// Registers the handler consulted before a title-bar close proceeds.
    public func registerWindowShouldCloseHandler(for handle: NativeHandle, handler: @escaping () -> Bool) {
        windowShouldCloseHandlers[handle.rawValue] = handler
    }

    /// Replaces a native view's hover cursor regions.
    public func setCursorRegions(_ regions: [NativeCursorRegion], for handle: NativeHandle) {
        if regions.isEmpty {
            cursorRegions.removeValue(forKey: handle.rawValue)
        } else {
            cursorRegions[handle.rawValue] = regions
        }
    }

    func systemCursor(named name: String) -> HCURSOR? {
        let identifier: Int
        switch name {
        case "iBeam":
            identifier = idcIBeam
        case "crosshair":
            identifier = idcCrosshair
        case "pointingHand":
            identifier = idcHand
        case "resizeLeftRight":
            identifier = idcSizeWE
        case "resizeUpDown":
            identifier = idcSizeNS
        default:
            identifier = idcArrow
        }
        return winLoadCursorW(nil, systemResourcePointer(identifier))
    }

    /// Registers the action to perform when a native view receives a scroll-wheel event.
    public func registerScrollWheelAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        scrollWheelActions[handle.rawValue] = action
    }

    /// Registers the action that paints custom view content during a native paint pass.
    public func registerDrawAction(for handle: NativeHandle, action: @escaping (NativeDrawingContext, NSRect) -> Void) {
        drawActions[handle.rawValue] = action
    }

    /// Requests a repaint of a native control.
    public func invalidateControl(_ handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winInvalidateRect(hwnd, nil, 1)
    }
}
#endif
