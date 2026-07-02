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
