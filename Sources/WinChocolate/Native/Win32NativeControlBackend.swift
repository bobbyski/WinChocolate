#if os(Windows)
private typealias HWND = UnsafeMutableRawPointer
private typealias HMENU = UnsafeMutableRawPointer
private typealias HINSTANCE = UnsafeMutableRawPointer
private typealias HBRUSH = UnsafeMutableRawPointer
private typealias HCURSOR = UnsafeMutableRawPointer
private typealias UINT = UInt32
private typealias DWORD = UInt32
private typealias WPARAM = UInt
private typealias LPARAM = Int
private typealias LRESULT = Int
private typealias WNDPROC = @convention(c) (HWND?, UINT, WPARAM, LPARAM) -> LRESULT

private struct POINT {
    var x: Int32 = 0
    var y: Int32 = 0
}

private struct MSG {
    var hwnd: HWND?
    var message: UINT = 0
    var wParam: WPARAM = 0
    var lParam: LPARAM = 0
    var time: DWORD = 0
    var pt: POINT = POINT()
}

private struct WNDCLASSW {
    var style: UINT = 0
    var lpfnWndProc: WNDPROC?
    var cbClsExtra: Int32 = 0
    var cbWndExtra: Int32 = 0
    var hInstance: HINSTANCE?
    var hIcon: UnsafeMutableRawPointer?
    var hCursor: HCURSOR?
    var hbrBackground: HBRUSH?
    var lpszMenuName: UnsafePointer<UInt16>?
    var lpszClassName: UnsafePointer<UInt16>?
}

@_silgen_name("AppendMenuW")
private func winAppendMenuW(_ menu: HMENU?, _ flags: UINT, _ identifier: UInt, _ title: UnsafePointer<UInt16>?) -> Int32

@_silgen_name("CreateMenu")
private func winCreateMenu() -> HMENU?

@_silgen_name("CreatePopupMenu")
private func winCreatePopupMenu() -> HMENU?

@_silgen_name("CreateWindowExW")
private func winCreateWindowExW(
    _ extendedStyle: DWORD,
    _ className: UnsafePointer<UInt16>?,
    _ windowName: UnsafePointer<UInt16>?,
    _ style: DWORD,
    _ x: Int32,
    _ y: Int32,
    _ width: Int32,
    _ height: Int32,
    _ parent: HWND?,
    _ menu: HMENU?,
    _ instance: HINSTANCE?,
    _ parameter: UnsafeMutableRawPointer?
) -> HWND?

@_silgen_name("DefWindowProcW")
private func winDefWindowProcW(_ hwnd: HWND?, _ message: UINT, _ wParam: WPARAM, _ lParam: LPARAM) -> LRESULT

@_silgen_name("DestroyWindow")
private func winDestroyWindow(_ hwnd: HWND?) -> Int32

@_silgen_name("DispatchMessageW")
private func winDispatchMessageW(_ message: UnsafePointer<MSG>) -> LRESULT

@_silgen_name("DrawMenuBar")
private func winDrawMenuBar(_ hwnd: HWND?) -> Int32

@_silgen_name("GetMessageW")
private func winGetMessageW(_ message: UnsafeMutablePointer<MSG>, _ hwnd: HWND?, _ minimumMessage: UINT, _ maximumMessage: UINT) -> Int32

@_silgen_name("GetModuleHandleW")
private func winGetModuleHandleW(_ moduleName: UnsafePointer<UInt16>?) -> HINSTANCE?

@_silgen_name("GetLastError")
private func winGetLastError() -> DWORD

@_silgen_name("LoadCursorW")
private func winLoadCursorW(_ instance: HINSTANCE?, _ cursorName: UnsafePointer<UInt16>?) -> HCURSOR?

@_silgen_name("PostQuitMessage")
private func winPostQuitMessage(_ exitCode: Int32)

@_silgen_name("RegisterClassW")
private func winRegisterClassW(_ windowClass: UnsafePointer<WNDCLASSW>) -> UInt16

@_silgen_name("SetMenu")
private func winSetMenu(_ hwnd: HWND?, _ menu: HMENU?) -> Int32

@_silgen_name("SetWindowTextW")
private func winSetWindowTextW(_ hwnd: HWND?, _ text: UnsafePointer<UInt16>?) -> Int32

@_silgen_name("ShowWindow")
private func winShowWindow(_ hwnd: HWND?, _ commandShow: Int32) -> Int32

@_silgen_name("TranslateMessage")
private func winTranslateMessage(_ message: UnsafePointer<MSG>) -> Int32

@_silgen_name("UpdateWindow")
private func winUpdateWindow(_ hwnd: HWND?) -> Int32

private let winChocolateWindowClassName = "WinChocolateWindow"

private let csVRedraw: UINT = 0x0001
private let csHRedraw: UINT = 0x0002
private let mfString: UINT = 0x0000
private let mfPopup: UINT = 0x0010
private let mfSeparator: UINT = 0x0800
private let swShow: Int32 = 5
private let wmDestroy: UINT = 0x0002
private let wmCommand: UINT = 0x0111
private let wsOverlapped: DWORD = 0x00000000
private let wsCaption: DWORD = 0x00c00000
private let wsSysMenu: DWORD = 0x00080000
private let wsThickFrame: DWORD = 0x00040000
private let wsMinimizeBox: DWORD = 0x00020000
private let wsMaximizeBox: DWORD = 0x00010000
private let wsVisible: DWORD = 0x10000000
private let wsChild: DWORD = 0x40000000

/// Win32 implementation of WinChocolate's native backend.
///
/// This backend owns the first native milestone: top-level windows, a menu bar,
/// push buttons, static text fields, and `WM_COMMAND` dispatch for actions.
public final class Win32NativeControlBackend: NativeControlBackend {
    nonisolated(unsafe) private static weak var activeBackend: Win32NativeControlBackend?

    private var isWindowClassRegistered = false
    private var mainMenu: NSMenu?
    private var windowHandles: [NativeHandle] = []
    private var controlActions: [UInt: () -> Void] = [:]
    private var commandActions: [UInt: () -> Void] = [:]
    private var nextCommandIdentifier: UInt = 1_000

    /// Creates a Win32 backend.
    public init() {
        Self.activeBackend = self
    }

    /// Starts the native Windows event loop.
    public func runApplication() {
        var message = MSG()
        while winGetMessageW(&message, nil, 0, 0) > 0 {
            withUnsafePointer(to: message) { messagePointer in
                _ = winTranslateMessage(messagePointer)
                _ = winDispatchMessageW(messagePointer)
            }
        }
    }

    /// Requests native application termination.
    public func terminateApplication() {
        winPostQuitMessage(0)
    }

    /// Installs the native application menu bar.
    public func installMainMenu(_ menu: NSMenu?) {
        mainMenu = menu

        for windowHandle in windowHandles {
            guard let hwnd = hwnd(from: windowHandle) else {
                continue
            }

            _ = winSetMenu(hwnd, createNativeMenu(from: menu))
            _ = winDrawMenuBar(hwnd)
        }
    }

    /// Creates a native top-level window.
    public func createWindow(title: String, frame: NSRect, styleMask: NSWindow.StyleMask) -> NativeHandle {
        registerWindowClassIfNeeded()

        let hwnd = withWideString(winChocolateWindowClassName) { className in
            withWideString(title) { windowTitle in
                winCreateWindowExW(
                    0,
                    className,
                    windowTitle,
                    windowStyle(from: styleMask),
                    Int32(frame.origin.x),
                    Int32(frame.origin.y),
                    Int32(frame.size.width),
                    Int32(frame.size.height),
                    nil,
                    createNativeMenu(from: mainMenu),
                    winGetModuleHandleW(nil),
                    nil
                )
            }
        }

        guard let hwnd else {
            print("WinChocolate: CreateWindowExW failed with error \(winGetLastError()).")
            return NativeHandle(rawValue: 0)
        }

        let handle = nativeHandle(from: hwnd)
        windowHandles.append(handle)
        return handle
    }

    /// Shows a native window.
    public func showWindow(_ handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winShowWindow(hwnd, swShow)
        _ = winUpdateWindow(hwnd)
    }

    /// Closes a native window.
    public func closeWindow(_ handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winDestroyWindow(hwnd)
        windowHandles.removeAll { $0 == handle }
    }

    /// Creates a native view child.
    public func createView(frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        createChildWindow(className: "STATIC", text: "", frame: frame, parent: parent, commandIdentifier: nil)
    }

    /// Creates a native push button child.
    public func createButton(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        createChildWindow(
            className: "BUTTON",
            text: title,
            frame: frame,
            parent: parent,
            commandIdentifier: nextCommandID()
        )
    }

    /// Creates a native static text field child.
    public func createTextField(text: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        createChildWindow(className: "STATIC", text: text, frame: frame, parent: parent, commandIdentifier: nil)
    }

    /// Updates the visible text for a native control.
    public func setText(_ text: String, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        withWideString(text) { value in
            _ = winSetWindowTextW(hwnd, value)
        }
    }

    /// Registers the action to perform when a native control is activated.
    public func registerAction(for handle: NativeHandle, action: @escaping () -> Void) {
        controlActions[handle.rawValue] = action
    }

    fileprivate static func dispatchMessage(message: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT? {
        activeBackend?.dispatchMessage(message: message, wParam: wParam, lParam: lParam)
    }

    private func dispatchMessage(message: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT? {
        switch message {
        case wmCommand:
            let commandIdentifier = UInt(wParam & 0xffff)

            if let action = commandActions[commandIdentifier] {
                action()
                return 0
            }

            if lParam != 0, let action = controlActions[UInt(bitPattern: lParam)] {
                action()
                return 0
            }

            return nil
        case wmDestroy:
            winPostQuitMessage(0)
            return 0
        default:
            return nil
        }
    }

    private func registerWindowClassIfNeeded() {
        guard !isWindowClassRegistered else {
            return
        }

        withWideString(winChocolateWindowClassName) { className in
            var windowClass = WNDCLASSW()
            windowClass.style = csHRedraw | csVRedraw
            windowClass.lpfnWndProc = winChocolateWindowProcedure
            windowClass.hInstance = winGetModuleHandleW(nil)
            windowClass.hCursor = winLoadCursorW(nil, systemResourcePointer(32_512))
            windowClass.hbrBackground = HBRUSH(bitPattern: 6)
            windowClass.lpszClassName = className

            withUnsafePointer(to: windowClass) { windowClassPointer in
                let atom = winRegisterClassW(windowClassPointer)
                if atom == 0 {
                    print("WinChocolate: RegisterClassW failed with error \(winGetLastError()).")
                }
            }
        }

        isWindowClassRegistered = true
    }

    private func createChildWindow(
        className: String,
        text: String,
        frame: NSRect,
        parent: NativeHandle?,
        commandIdentifier: UInt?
    ) -> NativeHandle {
        guard let parentHwnd = parent.flatMap({ hwnd(from: $0) }) else {
            return NativeHandle(rawValue: 0)
        }

        let menuHandle = commandIdentifier.flatMap { HMENU(bitPattern: Int($0)) }
        let childHwnd = withWideString(className) { nativeClassName in
            withWideString(text) { nativeText in
                winCreateWindowExW(
                    0,
                    nativeClassName,
                    nativeText,
                    wsChild | wsVisible,
                    Int32(frame.origin.x),
                    Int32(frame.origin.y),
                    Int32(frame.size.width),
                    Int32(frame.size.height),
                    parentHwnd,
                    menuHandle,
                    winGetModuleHandleW(nil),
                    nil
                )
            }
        }

        guard let childHwnd else {
            print("WinChocolate: CreateWindowExW child \(className) failed with error \(winGetLastError()).")
            return NativeHandle(rawValue: 0)
        }

        return nativeHandle(from: childHwnd)
    }

    private func createNativeMenu(from menu: NSMenu?) -> HMENU? {
        guard let menu else {
            return nil
        }

        let nativeMenu = winCreateMenu()
        appendItems(menu.items, to: nativeMenu)
        return nativeMenu
    }

    private func createNativePopupMenu(from menu: NSMenu) -> HMENU? {
        let nativeMenu = winCreatePopupMenu()
        appendItems(menu.items, to: nativeMenu)
        return nativeMenu
    }

    private func appendItems(_ items: [NSMenuItem], to nativeMenu: HMENU?) {
        for item in items {
            if let submenu = item.submenu, let nativeSubmenu = createNativePopupMenu(from: submenu) {
                withWideString(item.title) { title in
                    _ = winAppendMenuW(nativeMenu, mfPopup, UInt(bitPattern: nativeSubmenu), title)
                }
                continue
            }

            if item.title.isEmpty {
                _ = winAppendMenuW(nativeMenu, mfSeparator, 0, nil)
                continue
            }

            let commandIdentifier = nextCommandID()
            commandActions[commandIdentifier] = { [weak item] in
                _ = item?.performAction()
            }

            withWideString(item.title) { title in
                _ = winAppendMenuW(nativeMenu, mfString, commandIdentifier, title)
            }
        }
    }

    private func nextCommandID() -> UInt {
        let commandIdentifier = nextCommandIdentifier
        nextCommandIdentifier += 1
        return commandIdentifier
    }

    private func windowStyle(from styleMask: NSWindow.StyleMask) -> DWORD {
        var style = wsOverlapped

        if styleMask.contains(.titled) {
            style |= wsCaption | wsSysMenu
        }

        if styleMask.contains(.closable) {
            style |= wsSysMenu
        }

        if styleMask.contains(.miniaturizable) {
            style |= wsMinimizeBox
        }

        if styleMask.contains(.resizable) {
            style |= wsThickFrame | wsMaximizeBox
        }

        return style | wsVisible
    }

    private func nativeHandle(from hwnd: HWND) -> NativeHandle {
        NativeHandle(rawValue: UInt(bitPattern: hwnd))
    }

    private func hwnd(from handle: NativeHandle) -> HWND? {
        guard handle.rawValue != 0 else {
            return nil
        }

        return HWND(bitPattern: Int(handle.rawValue))
    }
}

private func withWideString<Result>(_ string: String, _ body: (UnsafePointer<UInt16>?) -> Result) -> Result {
    var wideString = Array(string.utf16)
    wideString.append(0)
    return wideString.withUnsafeBufferPointer { buffer in
        body(buffer.baseAddress)
    }
}

private func systemResourcePointer(_ identifier: Int) -> UnsafePointer<UInt16>? {
    UnsafePointer<UInt16>(bitPattern: identifier)
}

private func winChocolateWindowProcedure(
    hwnd: HWND?,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM
) -> LRESULT {
    if let result = Win32NativeControlBackend.dispatchMessage(
        message: message,
        wParam: wParam,
        lParam: lParam
    ) {
        return result
    }

    return winDefWindowProcW(hwnd, message, wParam, lParam)
}
#endif
