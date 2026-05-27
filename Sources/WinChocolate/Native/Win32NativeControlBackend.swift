#if os(Windows)
private typealias HWND = UnsafeMutableRawPointer
private typealias HMENU = UnsafeMutableRawPointer
private typealias HINSTANCE = UnsafeMutableRawPointer
private typealias HBRUSH = UnsafeMutableRawPointer
private typealias HCURSOR = UnsafeMutableRawPointer
private typealias HDC = UnsafeMutableRawPointer
private typealias HFONT = UnsafeMutableRawPointer
private typealias HGDIOBJ = UnsafeMutableRawPointer
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

private struct RECT {
    var left: Int32 = 0
    var top: Int32 = 0
    var right: Int32 = 0
    var bottom: Int32 = 0
}

@_silgen_name("AppendMenuW")
private func winAppendMenuW(_ menu: HMENU?, _ flags: UINT, _ identifier: UInt, _ title: UnsafePointer<UInt16>?) -> Int32

@_silgen_name("CreateMenu")
private func winCreateMenu() -> HMENU?

@_silgen_name("CreatePopupMenu")
private func winCreatePopupMenu() -> HMENU?

@_silgen_name("CreateSolidBrush")
private func winCreateSolidBrush(_ color: DWORD) -> HBRUSH?

@_silgen_name("CreateFontW")
private func winCreateFontW(
    _ height: Int32,
    _ width: Int32,
    _ escapement: Int32,
    _ orientation: Int32,
    _ weight: Int32,
    _ italic: DWORD,
    _ underline: DWORD,
    _ strikeOut: DWORD,
    _ charSet: DWORD,
    _ outputPrecision: DWORD,
    _ clipPrecision: DWORD,
    _ quality: DWORD,
    _ pitchAndFamily: DWORD,
    _ faceName: UnsafePointer<UInt16>?
) -> HFONT?

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

@_silgen_name("SendMessageW")
private func winSendMessageW(_ hwnd: HWND?, _ message: UINT, _ wParam: WPARAM, _ lParam: LPARAM) -> LRESULT

@_silgen_name("DefWindowProcW")
private func winDefWindowProcW(_ hwnd: HWND?, _ message: UINT, _ wParam: WPARAM, _ lParam: LPARAM) -> LRESULT

@_silgen_name("DestroyWindow")
private func winDestroyWindow(_ hwnd: HWND?) -> Int32

@_silgen_name("DeleteObject")
private func winDeleteObject(_ object: HGDIOBJ?) -> Int32

@_silgen_name("EnableWindow")
private func winEnableWindow(_ hwnd: HWND?, _ enable: Int32) -> Int32

@_silgen_name("DispatchMessageW")
private func winDispatchMessageW(_ message: UnsafePointer<MSG>) -> LRESULT

@_silgen_name("DrawMenuBar")
private func winDrawMenuBar(_ hwnd: HWND?) -> Int32

@_silgen_name("FillRect")
private func winFillRect(_ deviceContext: HDC?, _ rectangle: UnsafePointer<RECT>?, _ brush: HBRUSH?) -> Int32

@_silgen_name("GetClientRect")
private func winGetClientRect(_ hwnd: HWND?, _ rectangle: UnsafeMutablePointer<RECT>?) -> Int32

@_silgen_name("GetMessageW")
private func winGetMessageW(_ message: UnsafeMutablePointer<MSG>, _ hwnd: HWND?, _ minimumMessage: UINT, _ maximumMessage: UINT) -> Int32

@_silgen_name("GetModuleHandleW")
private func winGetModuleHandleW(_ moduleName: UnsafePointer<UInt16>?) -> HINSTANCE?

@_silgen_name("GetLastError")
private func winGetLastError() -> DWORD

@_silgen_name("GetWindowTextLengthW")
private func winGetWindowTextLengthW(_ hwnd: HWND?) -> Int32

@_silgen_name("GetWindowTextW")
private func winGetWindowTextW(_ hwnd: HWND?, _ text: UnsafeMutablePointer<UInt16>?, _ maximumCount: Int32) -> Int32

@_silgen_name("InvalidateRect")
private func winInvalidateRect(_ hwnd: HWND?, _ rectangle: UnsafePointer<RECT>?, _ erase: Int32) -> Int32

@_silgen_name("LoadCursorW")
private func winLoadCursorW(_ instance: HINSTANCE?, _ cursorName: UnsafePointer<UInt16>?) -> HCURSOR?

@_silgen_name("MoveWindow")
private func winMoveWindow(
    _ hwnd: HWND?,
    _ x: Int32,
    _ y: Int32,
    _ width: Int32,
    _ height: Int32,
    _ repaint: Int32
) -> Int32

@_silgen_name("MessageBoxW")
private func winMessageBoxW(
    _ hwnd: HWND?,
    _ text: UnsafePointer<UInt16>?,
    _ caption: UnsafePointer<UInt16>?,
    _ type: UINT
) -> Int32

@_silgen_name("PostQuitMessage")
private func winPostQuitMessage(_ exitCode: Int32)

@_silgen_name("RegisterClassW")
private func winRegisterClassW(_ windowClass: UnsafePointer<WNDCLASSW>) -> UInt16

@_silgen_name("SetMenu")
private func winSetMenu(_ hwnd: HWND?, _ menu: HMENU?) -> Int32

@_silgen_name("SetBkColor")
private func winSetBkColor(_ deviceContext: HDC?, _ color: DWORD) -> DWORD

@_silgen_name("SetTextColor")
private func winSetTextColor(_ deviceContext: HDC?, _ color: DWORD) -> DWORD

@_silgen_name("SetWindowTextW")
private func winSetWindowTextW(_ hwnd: HWND?, _ text: UnsafePointer<UInt16>?) -> Int32

@_silgen_name("ShowWindow")
private func winShowWindow(_ hwnd: HWND?, _ commandShow: Int32) -> Int32

@_silgen_name("TranslateMessage")
private func winTranslateMessage(_ message: UnsafePointer<MSG>) -> Int32

@_silgen_name("UpdateWindow")
private func winUpdateWindow(_ hwnd: HWND?) -> Int32

private let winChocolateWindowClassName = "WinChocolateWindow"
private let winChocolateViewClassName = "WinChocolateView"

private let csVRedraw: UINT = 0x0001
private let csHRedraw: UINT = 0x0002
private let mfString: UINT = 0x0000
private let mfPopup: UINT = 0x0010
private let mfSeparator: UINT = 0x0800
private let mbOK: UINT = 0x00000000
private let mbOKCancel: UINT = 0x00000001
private let mbYesNo: UINT = 0x00000004
private let mbIconInformation: UINT = 0x00000040
private let mbIconWarning: UINT = 0x00000030
private let mbIconError: UINT = 0x00000010
private let swShow: Int32 = 5
private let swHide: Int32 = 0
private let wmDestroy: UINT = 0x0002
private let wmEraseBackground: UINT = 0x0014
private let wmSetFont: UINT = 0x0030
private let wmCommand: UINT = 0x0111
private let wmCtlColorEdit: UINT = 0x0133
private let wmCtlColorStatic: UINT = 0x0138
private let bmGetCheck: UINT = 0x00f0
private let bmSetCheck: UINT = 0x00f1
private let cbAddString: UINT = 0x0143
private let cbGetCurSel: UINT = 0x0147
private let cbResetContent: UINT = 0x014b
private let cbSetCurSel: UINT = 0x014e
private let enChange: UInt = 0x0300
private let bnClicked: UInt = 0
private let cbnSelChange: UInt = 1
private let bstUnchecked: WPARAM = 0
private let bstChecked: WPARAM = 1
private let bstIndeterminate: WPARAM = 2
private let defaultCharset: DWORD = 1
private let defaultPrecision: DWORD = 0
private let defaultQuality: DWORD = 0
private let defaultPitchAndFamily: DWORD = 0
private let idOK: Int32 = 1
private let idYes: Int32 = 6
private let wsOverlapped: DWORD = 0x00000000
private let wsCaption: DWORD = 0x00c00000
private let wsSysMenu: DWORD = 0x00080000
private let wsThickFrame: DWORD = 0x00040000
private let wsMinimizeBox: DWORD = 0x00020000
private let wsMaximizeBox: DWORD = 0x00010000
private let wsVisible: DWORD = 0x10000000
private let wsVScroll: DWORD = 0x00200000
private let wsChild: DWORD = 0x40000000
private let wsClipChildren: DWORD = 0x02000000
private let wsBorder: DWORD = 0x00800000
private let esAutoHScroll: DWORD = 0x0080
private let bsAutoCheckBox: DWORD = 0x00000003
private let bsAutoRadioButton: DWORD = 0x00000009
private let bsGroupBox: DWORD = 0x00000007
private let cbsDropdownList: DWORD = 0x0003

/// Win32 implementation of WinChocolate's native backend.
///
/// This backend owns the first native milestone: top-level windows, a menu bar,
/// push buttons, static text fields, and `WM_COMMAND` dispatch for actions.
public final class Win32NativeControlBackend: NativeControlBackend {
    nonisolated(unsafe) private static weak var activeBackend: Win32NativeControlBackend?

    private var isWindowClassRegistered = false
    private var isViewClassRegistered = false
    private var mainMenu: NSMenu?
    private var windowHandles: Set<NativeHandle> = []
    private var controlActions: [UInt: () -> Void] = [:]
    private var textChangeActions: [UInt: (String) -> Void] = [:]
    private var commandActions: [UInt: () -> Void] = [:]
    private var textColors: [UInt: DWORD] = [:]
    private var backgroundColors: [UInt: DWORD] = [:]
    private var backgroundBrushes: [UInt: HBRUSH] = [:]
    private var fonts: [UInt: HFONT] = [:]
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
        windowHandles.insert(handle)
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
        windowHandles.remove(handle)
        controlActions.removeValue(forKey: handle.rawValue)
        textChangeActions.removeValue(forKey: handle.rawValue)
        clearAppearance(for: handle)
    }

    /// Destroys a native child control.
    public func destroyControl(_ handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winDestroyWindow(hwnd)
        controlActions.removeValue(forKey: handle.rawValue)
        textChangeActions.removeValue(forKey: handle.rawValue)
        clearAppearance(for: handle)
    }

    /// Creates a native view child.
    public func createView(frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        registerViewClassIfNeeded()
        return createChildWindow(
            className: winChocolateViewClassName,
            text: "",
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: wsChild | wsVisible | wsClipChildren
        )
    }

    /// Creates a native push button child.
    public func createButton(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        createChildWindow(
            className: "BUTTON",
            text: title,
            frame: frame,
            parent: parent,
            commandIdentifier: nextCommandID(),
            style: wsChild | wsVisible
        )
    }

    /// Creates a native checkbox child.
    public func createCheckbox(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        createChildWindow(
            className: "BUTTON",
            text: title,
            frame: frame,
            parent: parent,
            commandIdentifier: nextCommandID(),
            style: wsChild | wsVisible | bsAutoCheckBox
        )
    }

    /// Creates a native radio button child.
    public func createRadioButton(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        createChildWindow(
            className: "BUTTON",
            text: title,
            frame: frame,
            parent: parent,
            commandIdentifier: nextCommandID(),
            style: wsChild | wsVisible | bsAutoRadioButton
        )
    }

    /// Creates a native box child.
    public func createBox(title: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        createChildWindow(
            className: "BUTTON",
            text: title,
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: wsChild | wsVisible | bsGroupBox
        )
    }

    /// Creates a native static text field child.
    public func createTextField(text: String, frame: NSRect, parent: NativeHandle?, isEditable: Bool) -> NativeHandle {
        createChildWindow(
            className: isEditable ? "EDIT" : "STATIC",
            text: text,
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: isEditable
                ? wsChild | wsVisible | wsBorder | esAutoHScroll
                : wsChild | wsVisible
        )
    }

    /// Creates a native pop-up button child.
    public func createPopUpButton(items: [String], selectedIndex: Int, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = createChildWindow(
            className: "COMBOBOX",
            text: "",
            frame: frame,
            parent: parent,
            commandIdentifier: nextCommandID(),
            style: wsChild | wsVisible | wsVScroll | cbsDropdownList
        )
        setPopUpButtonItems(items, selectedIndex: selectedIndex, for: handle)
        return handle
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

    /// Updates the native frame for a window or control.
    public func setFrame(_ frame: NSRect, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winMoveWindow(
            hwnd,
            Int32(frame.origin.x),
            Int32(frame.origin.y),
            Int32(frame.size.width),
            Int32(frame.size.height),
            1
        )
    }

    /// Updates whether a native control is hidden.
    public func setHidden(_ isHidden: Bool, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winShowWindow(hwnd, isHidden ? swHide : swShow)
    }

    /// Updates whether a native control is enabled.
    public func setEnabled(_ isEnabled: Bool, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winEnableWindow(hwnd, isEnabled ? 1 : 0)
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

    /// Registers the action to perform when a native control is activated.
    public func registerAction(for handle: NativeHandle, action: @escaping () -> Void) {
        controlActions[handle.rawValue] = action
    }

    /// Registers the action to perform when native text changes.
    public func registerTextChangeAction(for handle: NativeHandle, action: @escaping (String) -> Void) {
        textChangeActions[handle.rawValue] = action
    }

    /// Runs a native modal alert.
    public func runAlert(_ alert: NSAlert) -> NSApplication.ModalResponse {
        let body = alert.informativeText.isEmpty
            ? alert.messageText
            : "\(alert.messageText)\n\n\(alert.informativeText)"

        let result = withWideString(body) { text in
            withWideString("WinChocolate") { caption in
                winMessageBoxW(nil, text, caption, messageBoxFlags(for: alert))
            }
        }

        if result == idOK || result == idYes {
            return .alertFirstButtonReturn
        }

        return .alertSecondButtonReturn
    }

    fileprivate static func dispatchMessage(hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT? {
        activeBackend?.dispatchMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
    }

    private func dispatchMessage(hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT? {
        switch message {
        case wmEraseBackground:
            guard let hwnd else {
                return nil
            }

            let handle = nativeHandle(from: hwnd)
            guard let brush = backgroundBrushes[handle.rawValue] else {
                return nil
            }

            var rectangle = RECT()
            _ = winGetClientRect(hwnd, &rectangle)
            withUnsafePointer(to: rectangle) { rectanglePointer in
                _ = winFillRect(HDC(bitPattern: Int(wParam)), rectanglePointer, brush)
            }
            return 1
        case wmCommand:
            let commandIdentifier = UInt(wParam & 0xffff)
            let notificationCode = UInt((wParam >> 16) & 0xffff)

            if let action = commandActions[commandIdentifier] {
                action()
                return 0
            }

            if lParam != 0, notificationCode == enChange, let action = textChangeActions[UInt(bitPattern: lParam)] {
                action(text(from: HWND(bitPattern: lParam)))
                return 0
            }

            if lParam != 0, notificationCode == cbnSelChange, let action = controlActions[UInt(bitPattern: lParam)] {
                action()
                return 0
            }

            if lParam != 0, notificationCode == bnClicked, let action = controlActions[UInt(bitPattern: lParam)] {
                action()
                return 0
            }

            return nil
        case wmCtlColorEdit, wmCtlColorStatic:
            guard lParam != 0 else {
                return nil
            }

            let rawHandle = UInt(bitPattern: lParam)
            let deviceContext = HDC(bitPattern: Int(wParam))
            if let textColor = textColors[rawHandle] {
                _ = winSetTextColor(deviceContext, textColor)
            }
            if let backgroundColor = backgroundColors[rawHandle] {
                _ = winSetBkColor(deviceContext, backgroundColor)
            }
            if let brush = backgroundBrushes[rawHandle] {
                return Int(bitPattern: brush)
            }
            return nil
        case wmDestroy:
            if let hwnd, windowHandles.contains(nativeHandle(from: hwnd)) {
                winPostQuitMessage(0)
            }
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

    private func registerViewClassIfNeeded() {
        guard !isViewClassRegistered else {
            return
        }

        withWideString(winChocolateViewClassName) { className in
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
                    print("WinChocolate: RegisterClassW for view failed with error \(winGetLastError()).")
                }
            }
        }

        isViewClassRegistered = true
    }

    private func createChildWindow(
        className: String,
        text: String,
        frame: NSRect,
        parent: NativeHandle?,
        commandIdentifier: UInt?,
        style: DWORD
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
                    style,
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

    private func messageBoxFlags(for alert: NSAlert) -> UINT {
        let buttonFlags: UINT
        switch alert.buttonTitles.count {
        case 0, 1:
            buttonFlags = mbOK
        case 2:
            buttonFlags = mbOKCancel
        default:
            buttonFlags = mbYesNo
        }

        let iconFlags: UINT
        switch alert.alertStyle {
        case .informational:
            iconFlags = mbIconInformation
        case .warning:
            iconFlags = mbIconWarning
        case .critical:
            iconFlags = mbIconError
        }

        return buttonFlags | iconFlags
    }

    private func text(from hwnd: HWND?) -> String {
        let length = Int(winGetWindowTextLengthW(hwnd))
        var buffer = Array(repeating: UInt16(0), count: length + 1)
        let maximumCount = Int32(buffer.count)
        let copiedCount = buffer.withUnsafeMutableBufferPointer { pointer in
            winGetWindowTextW(hwnd, pointer.baseAddress, maximumCount)
        }
        return String(decoding: buffer.prefix(Int(copiedCount)), as: UTF16.self)
    }

    private func colorRef(from color: NSColor) -> DWORD {
        let red = DWORD(color.redComponent * 255) & 0xff
        let green = DWORD(color.greenComponent * 255) & 0xff
        let blue = DWORD(color.blueComponent * 255) & 0xff
        return red | (green << 8) | (blue << 16)
    }

    private func invalidate(_ handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winInvalidateRect(hwnd, nil, 1)
    }

    private func clearAppearance(for handle: NativeHandle) {
        textColors.removeValue(forKey: handle.rawValue)
        backgroundColors.removeValue(forKey: handle.rawValue)
        if let brush = backgroundBrushes.removeValue(forKey: handle.rawValue) {
            _ = winDeleteObject(brush)
        }
        if let font = fonts.removeValue(forKey: handle.rawValue) {
            _ = winDeleteObject(font)
        }
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
        hwnd: hwnd,
        message: message,
        wParam: wParam,
        lParam: lParam
    ) {
        return result
    }

    return winDefWindowProcW(hwnd, message, wParam, lParam)
}
#endif
