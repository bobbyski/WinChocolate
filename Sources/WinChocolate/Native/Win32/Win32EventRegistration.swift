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
}
#endif
