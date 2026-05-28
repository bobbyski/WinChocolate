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
private typealias LONG_PTR = Int
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

private struct INITCOMMONCONTROLSEX {
    var dwSize: DWORD = 0
    var dwICC: DWORD = 0
}

private struct NMHDR {
    var hwndFrom: HWND?
    var idFrom: UInt = 0
    var code: UINT = 0
}

private struct NMLISTVIEW {
    var hdr: NMHDR = NMHDR()
    var iItem: Int32 = 0
    var iSubItem: Int32 = 0
    var uNewState: UINT = 0
    var uOldState: UINT = 0
    var uChanged: UINT = 0
    var ptAction: POINT = POINT()
    var lParam: LPARAM = 0
}

private struct NMHEADERW {
    var hdr: NMHDR = NMHDR()
    var iItem: Int32 = 0
    var iButton: Int32 = 0
    var pItem: UnsafeMutableRawPointer?
}

private struct HDHITTESTINFO {
    var pt: POINT = POINT()
    var flags: UINT = 0
    var iItem: Int32 = 0
}

private struct LVCOLUMNW {
    var mask: UINT = 0
    var fmt: Int32 = 0
    var cx: Int32 = 0
    var pszText: UnsafeMutablePointer<UInt16>?
    var cchTextMax: Int32 = 0
    var iSubItem: Int32 = 0
    var iImage: Int32 = 0
    var iOrder: Int32 = 0
    var cxMin: Int32 = 0
    var cxDefault: Int32 = 0
    var cxIdeal: Int32 = 0
}

private struct LVITEMW {
    var mask: UINT = 0
    var iItem: Int32 = 0
    var iSubItem: Int32 = 0
    var state: UINT = 0
    var stateMask: UINT = 0
    var pszText: UnsafeMutablePointer<UInt16>?
    var cchTextMax: Int32 = 0
    var iImage: Int32 = 0
    var lParam: LPARAM = 0
    var iIndent: Int32 = 0
    var iGroupId: Int32 = 0
    var cColumns: UINT = 0
    var puColumns: UnsafeMutablePointer<UINT>?
    var piColFmt: UnsafeMutablePointer<Int32>?
    var iGroup: Int32 = 0
}

private struct LVHITTESTINFO {
    var pt: POINT = POINT()
    var flags: UINT = 0
    var iItem: Int32 = 0
    var iSubItem: Int32 = 0
    var iGroup: Int32 = 0
}

@_silgen_name("InitCommonControlsEx")
private func winInitCommonControlsEx(_ initControls: UnsafePointer<INITCOMMONCONTROLSEX>) -> Int32

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

@_silgen_name("CallWindowProcW")
private func winCallWindowProcW(_ previousProcedure: WNDPROC?, _ hwnd: HWND?, _ message: UINT, _ wParam: WPARAM, _ lParam: LPARAM) -> LRESULT

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

@_silgen_name("GetKeyState")
private func winGetKeyState(_ virtualKey: Int32) -> Int16

@_silgen_name("GetCursorPos")
private func winGetCursorPos(_ point: UnsafeMutablePointer<POINT>?) -> Int32

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

@_silgen_name("ScreenToClient")
private func winScreenToClient(_ hwnd: HWND?, _ point: UnsafeMutablePointer<POINT>?) -> Int32

@_silgen_name("SetTextColor")
private func winSetTextColor(_ deviceContext: HDC?, _ color: DWORD) -> DWORD

@_silgen_name("SetFocus")
private func winSetFocus(_ hwnd: HWND?) -> HWND?

@_silgen_name("SetWindowLongPtrW")
private func winSetWindowLongPtrW(_ hwnd: HWND?, _ index: Int32, _ newLong: LONG_PTR) -> LONG_PTR

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
private let mfGrayed: UINT = 0x0001
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
private let wmNotify: UINT = 0x004e
private let wmEraseBackground: UINT = 0x0014
private let wmSetFont: UINT = 0x0030
private let wmCommand: UINT = 0x0111
private let wmCtlColorEdit: UINT = 0x0133
private let wmCtlColorStatic: UINT = 0x0138
private let wmKeyDown: UINT = 0x0100
private let wmKeyUp: UINT = 0x0101
private let wmSysKeyDown: UINT = 0x0104
private let wmSysKeyUp: UINT = 0x0105
private let wmGetDlgCode: UINT = 0x0087
private let wmMouseMove: UINT = 0x0200
private let wmLButtonDown: UINT = 0x0201
private let wmLButtonUp: UINT = 0x0202
private let bmGetCheck: UINT = 0x00f0
private let bmSetCheck: UINT = 0x00f1
private let cbAddString: UINT = 0x0143
private let cbGetCurSel: UINT = 0x0147
private let cbResetContent: UINT = 0x014b
private let cbSetCurSel: UINT = 0x014e
private let lbAddString: UINT = 0x0180
private let lbSetCurSel: UINT = 0x0186
private let lbGetCurSel: UINT = 0x0188
private let lbResetContent: UINT = 0x0184
private let hdmFirst: UINT = 0x1200
private let hdmHitTest: UINT = hdmFirst + 6
private let lvmFirst: UINT = 0x1000
private let lvmDeleteAllItems: UINT = lvmFirst + 9
private let lvmGetNextItem: UINT = lvmFirst + 12
private let lvmGetHeader: UINT = lvmFirst + 31
private let lvmSetItemState: UINT = lvmFirst + 43
private let lvmSubItemHitTest: UINT = lvmFirst + 57
private let lvmInsertItemW: UINT = lvmFirst + 77
private let lvmInsertColumnW: UINT = lvmFirst + 97
private let lvmSetItemTextW: UINT = lvmFirst + 116
private let lvmSetExtendedListViewStyle: UINT = lvmFirst + 54
private let enChange: UInt = 0x0300
private let lbnSelChange: UInt = 1
private let nmClick: UINT = 0xfffffffe
private let lvnItemChanged: UINT = 0xffffff9b
private let lvnColumnClick: UINT = 0xffffff94
private let hdnItemClickA: UINT = 0xfffffed2
private let hdnItemClickW: UINT = 0xfffffebe
private let bnClicked: UInt = 0
private let cbnSelChange: UInt = 1
private let iccListViewClasses: DWORD = 0x00000001
private let bstUnchecked: WPARAM = 0
private let bstChecked: WPARAM = 1
private let bstIndeterminate: WPARAM = 2
private let defaultCharset: DWORD = 1
private let defaultPrecision: DWORD = 0
private let defaultQuality: DWORD = 0
private let defaultPitchAndFamily: DWORD = 0
private let vkBack: Int32 = 0x08
private let vkTab: Int32 = 0x09
private let vkReturn: Int32 = 0x0d
private let vkShift: Int32 = 0x10
private let vkControl: Int32 = 0x11
private let vkMenu: Int32 = 0x12
private let vkEscape: Int32 = 0x1b
private let vkSpace: Int32 = 0x20
private let vkLWin: Int32 = 0x5b
private let vkRWin: Int32 = 0x5c
private let vkLShift: Int32 = 0xa0
private let vkRShift: Int32 = 0xa1
private let vkLControl: Int32 = 0xa2
private let vkRControl: Int32 = 0xa3
private let vkLMenu: Int32 = 0xa4
private let vkRMenu: Int32 = 0xa5
private let gwlpWndProc: Int32 = -4
private let dlgcWantTab: LRESULT = 0x0002
private let idOK: Int32 = 1
private let idYes: Int32 = 6
private let wsOverlapped: DWORD = 0x00000000
private let wsCaption: DWORD = 0x00c00000
private let wsSysMenu: DWORD = 0x00080000
private let wsThickFrame: DWORD = 0x00040000
private let wsMinimizeBox: DWORD = 0x00020000
private let wsMaximizeBox: DWORD = 0x00010000
private let wsTabStop: DWORD = 0x00010000
private let wsVisible: DWORD = 0x10000000
private let wsVScroll: DWORD = 0x00200000
private let wsHScroll: DWORD = 0x00100000
private let wsChild: DWORD = 0x40000000
private let wsClipChildren: DWORD = 0x02000000
private let wsBorder: DWORD = 0x00800000
private let esAutoHScroll: DWORD = 0x0080
private let lbsNotify: DWORD = 0x0001
private let lvsReport: DWORD = 0x0001
private let lvsSingleSel: DWORD = 0x0004
private let lvsShowSelAlways: DWORD = 0x0008
private let lvsExGridLines: DWORD = 0x00000001
private let lvsExFullRowSelect: DWORD = 0x00000020
private let lvifText: UINT = 0x0001
private let lvifState: UINT = 0x0008
private let lvcfWidth: UINT = 0x0002
private let lvcfText: UINT = 0x0004
private let lvcfSubItem: UINT = 0x0008
private let lvisFocused: UINT = 0x0001
private let lvisSelected: UINT = 0x0002
private let lvniSelected: WPARAM = 0x0002
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
    private var mouseDownActions: [UInt: (NSEvent) -> Void] = [:]
    private var mouseUpActions: [UInt: (NSEvent) -> Void] = [:]
    private var mouseMovedActions: [UInt: (NSEvent) -> Void] = [:]
    private var keyDownActions: [UInt: (NSEvent) -> Void] = [:]
    private var keyUpActions: [UInt: (NSEvent) -> Void] = [:]
    private var originalControlProcedures: [UInt: WNDPROC] = [:]
    private var commandActions: [UInt: () -> Void] = [:]
    private var tableColumnTitles: [UInt: [String]] = [:]
    private var tableHeaderOwners: [UInt: NativeHandle] = [:]
    private var tableClickedRows: [UInt: Int] = [:]
    private var tableClickedColumns: [UInt: Int] = [:]
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
        mouseDownActions.removeValue(forKey: handle.rawValue)
        mouseUpActions.removeValue(forKey: handle.rawValue)
        mouseMovedActions.removeValue(forKey: handle.rawValue)
        keyDownActions.removeValue(forKey: handle.rawValue)
        keyUpActions.removeValue(forKey: handle.rawValue)
        originalControlProcedures.removeValue(forKey: handle.rawValue)
        tableColumnTitles.removeValue(forKey: handle.rawValue)
        tableHeaderOwners = tableHeaderOwners.filter { $0.value != handle }
        tableClickedRows.removeValue(forKey: handle.rawValue)
        tableClickedColumns.removeValue(forKey: handle.rawValue)
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
        mouseDownActions.removeValue(forKey: handle.rawValue)
        mouseUpActions.removeValue(forKey: handle.rawValue)
        mouseMovedActions.removeValue(forKey: handle.rawValue)
        keyDownActions.removeValue(forKey: handle.rawValue)
        keyUpActions.removeValue(forKey: handle.rawValue)
        originalControlProcedures.removeValue(forKey: handle.rawValue)
        tableColumnTitles.removeValue(forKey: handle.rawValue)
        tableHeaderOwners = tableHeaderOwners.filter { $0.value != handle }
        tableClickedRows.removeValue(forKey: handle.rawValue)
        tableClickedColumns.removeValue(forKey: handle.rawValue)
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
        let handle = createChildWindow(
            className: "BUTTON",
            text: title,
            frame: frame,
            parent: parent,
            commandIdentifier: nextCommandID(),
            style: wsChild | wsVisible | wsTabStop
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
        let handle = createChildWindow(
            className: isEditable ? "EDIT" : "STATIC",
            text: text,
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: isEditable
                ? wsChild | wsVisible | wsTabStop | wsBorder | esAutoHScroll
                : wsChild | wsVisible
        )
        if isEditable {
            subclassControlForTabKey(handle)
        }
        return handle
    }

    /// Creates a native pop-up button child.
    public func createPopUpButton(items: [String], selectedIndex: Int, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = createChildWindow(
            className: "COMBOBOX",
            text: "",
            frame: frame,
            parent: parent,
            commandIdentifier: nextCommandID(),
            style: wsChild | wsVisible | wsTabStop | wsVScroll | cbsDropdownList
        )
        subclassControlForTabKey(handle)
        setPopUpButtonItems(items, selectedIndex: selectedIndex, for: handle)
        return handle
    }

    /// Creates a native scroll-view child.
    public func createScrollView(frame: NSRect, parent: NativeHandle?, hasVerticalScroller: Bool, hasHorizontalScroller: Bool) -> NativeHandle {
        registerViewClassIfNeeded()
        var style = wsChild | wsVisible | wsClipChildren | wsBorder
        if hasVerticalScroller {
            style |= wsVScroll
        }
        if hasHorizontalScroller {
            style |= wsHScroll
        }

        return createChildWindow(
            className: winChocolateViewClassName,
            text: "",
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: style
        )
    }

    /// Creates a native table-view child.
    public func createTableView(columns: [String], rows: [[String]], selectedRow: Int, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        initializeListViewControls()
        let handle = createChildWindow(
            className: "SysListView32",
            text: "",
            frame: frame,
            parent: parent,
            commandIdentifier: nextCommandID(),
            style: wsChild | wsVisible | wsTabStop | wsBorder | wsVScroll | lvsReport | lvsSingleSel | lvsShowSelAlways
        )
        subclassControlForTabKey(handle)
        tableColumnTitles[handle.rawValue] = columns
        tableClickedRows[handle.rawValue] = -1
        tableClickedColumns[handle.rawValue] = -1
        installTableColumns(columns, for: handle)
        if let hwnd = hwnd(from: handle) {
            _ = winSendMessageW(hwnd, lvmSetExtendedListViewStyle, 0, LPARAM(lvsExFullRowSelect | lvsExGridLines))
            if let headerHwnd = HWND(bitPattern: winSendMessageW(hwnd, lvmGetHeader, 0, 0)) {
                tableHeaderOwners[UInt(bitPattern: headerHwnd)] = handle
            }
        }
        setTableRows(rows, selectedRow: selectedRow, for: handle)
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

    /// Moves native keyboard focus to a control.
    public func focusControl(_ handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winSetFocus(hwnd)
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

    /// Replaces native table rows.
    public func setTableRows(_ rows: [[String]], selectedRow: Int, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winSendMessageW(hwnd, lvmDeleteAllItems, 0, 0)
        for (rowIndex, row) in rows.enumerated() {
            let firstValue = row.first ?? ""
            withWideString(firstValue) { title in
                var item = LVITEMW()
                item.mask = lvifText
                item.iItem = Int32(rowIndex)
                item.iSubItem = 0
                item.pszText = UnsafeMutablePointer(mutating: title)
                withUnsafePointer(to: item) { itemPointer in
                    _ = winSendMessageW(hwnd, lvmInsertItemW, 0, Int(bitPattern: itemPointer))
                }
            }

            if row.count > 1 {
                for columnIndex in 1..<row.count {
                    setTableCellText(row[columnIndex], row: rowIndex, column: columnIndex, hwnd: hwnd)
                }
            }
        }
        setTableSelectedRow(selectedRow, for: handle)
    }

    /// Updates native table selection.
    public func setTableSelectedRow(_ selectedRow: Int, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        tableClickedColumns[handle.rawValue] = -1
        tableClickedRows[handle.rawValue] = -1
        let selectedState = lvisSelected | lvisFocused
        var clearItem = LVITEMW()
        clearItem.stateMask = selectedState
        clearItem.state = 0
        withUnsafePointer(to: clearItem) { itemPointer in
            _ = winSendMessageW(hwnd, lvmSetItemState, WPARAM.max, Int(bitPattern: itemPointer))
        }

        guard selectedRow >= 0 else {
            return
        }

        var item = LVITEMW()
        item.stateMask = selectedState
        item.state = selectedState
        withUnsafePointer(to: item) { itemPointer in
            _ = winSendMessageW(hwnd, lvmSetItemState, WPARAM(selectedRow), Int(bitPattern: itemPointer))
        }
    }

    /// Reads native table selection.
    public func tableSelectedRow(for handle: NativeHandle) -> Int {
        guard let hwnd = hwnd(from: handle) else {
            return -1
        }

        return Int(winSendMessageW(hwnd, lvmGetNextItem, WPARAM.max, LPARAM(lvniSelected)))
    }

    /// Reads the most recent native table row activation.
    public func tableClickedRow(for handle: NativeHandle) -> Int {
        tableClickedRows[handle.rawValue] ?? -1
    }

    /// Reads the most recent native table column activation.
    public func tableClickedColumn(for handle: NativeHandle) -> Int {
        tableClickedColumns[handle.rawValue] ?? -1
    }

    /// Registers the action to perform when a native control is activated.
    public func registerAction(for handle: NativeHandle, action: @escaping () -> Void) {
        controlActions[handle.rawValue] = action
    }

    /// Registers the action to perform when native text changes.
    public func registerTextChangeAction(for handle: NativeHandle, action: @escaping (String) -> Void) {
        textChangeActions[handle.rawValue] = action
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

    /// Registers the action to perform when a native view receives a key-down event.
    public func registerKeyDownAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        keyDownActions[handle.rawValue] = action
    }

    /// Registers the action to perform when a native view receives a key-up event.
    public func registerKeyUpAction(for handle: NativeHandle, action: @escaping (NSEvent) -> Void) {
        keyUpActions[handle.rawValue] = action
    }

    /// Runs a native modal alert.
    public func runAlert(_ alert: NSAlert) -> NSApplication.ModalResponse {
        let body = alert.informativeText.isEmpty
            ? alert.messageText
            : "\(alert.messageText)\n\n\(alert.informativeText)"
        let owner = NSApplication.shared.keyWindow?.nativeHandle.flatMap { hwnd(from: $0) }

        let result = withWideString(body) { text in
            withWideString("WinChocolate") { caption in
                winMessageBoxW(owner, text, caption, messageBoxFlags(for: alert))
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

    fileprivate static func dispatchControlMessage(hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT? {
        activeBackend?.dispatchControlMessage(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
    }

    fileprivate static func callOriginalControlProcedure(hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT {
        activeBackend?.callOriginalControlProcedure(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
            ?? winDefWindowProcW(hwnd, message, wParam, lParam)
    }

    private func dispatchMessage(hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT? {
        switch message {
        case wmKeyDown, wmSysKeyDown:
            guard let hwnd, let action = keyDownActions[nativeHandle(from: hwnd).rawValue] else {
                return nil
            }

            action(keyEvent(type: .keyDown, wParam: wParam))
            return 0
        case wmKeyUp, wmSysKeyUp:
            guard let hwnd, let action = keyUpActions[nativeHandle(from: hwnd).rawValue] else {
                return nil
            }

            action(keyEvent(type: .keyUp, wParam: wParam))
            return 0
        case wmMouseMove:
            guard let hwnd, let action = mouseMovedActions[nativeHandle(from: hwnd).rawValue] else {
                return nil
            }

            action(NSEvent(type: .mouseMoved, locationInWindow: point(from: lParam), modifierFlags: currentModifierFlags()))
            return 0
        case wmLButtonDown:
            guard let hwnd, let action = mouseDownActions[nativeHandle(from: hwnd).rawValue] else {
                return nil
            }

            _ = winSetFocus(hwnd)
            action(NSEvent(type: .leftMouseDown, locationInWindow: point(from: lParam), modifierFlags: currentModifierFlags()))
            return 0
        case wmLButtonUp:
            guard let hwnd, let action = mouseUpActions[nativeHandle(from: hwnd).rawValue] else {
                return nil
            }

            action(NSEvent(type: .leftMouseUp, locationInWindow: point(from: lParam), modifierFlags: currentModifierFlags()))
            return 0
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
        case wmNotify:
            guard lParam != 0 else {
                return nil
            }

            let header = UnsafeRawPointer(bitPattern: lParam)?.assumingMemoryBound(to: NMHDR.self).pointee
            guard let header else {
                return nil
            }

            if header.code == hdnItemClickA || header.code == hdnItemClickW {
                guard let source = header.hwndFrom,
                      let handle = tableHeaderOwners[UInt(bitPattern: source)],
                      let action = controlActions[handle.rawValue] else {
                    return nil
                }

                let headerNotification = UnsafeRawPointer(bitPattern: lParam)?.assumingMemoryBound(to: NMHEADERW.self).pointee
                let hitColumn = headerHitTestAtCursor(hwnd: source)
                let clickedColumn = hitColumn >= 0 ? hitColumn : Int(headerNotification?.iItem ?? -1)
                guard clickedColumn >= 0 else {
                    return nil
                }

                tableClickedRows[handle.rawValue] = -1
                tableClickedColumns[handle.rawValue] = clickedColumn
                action()
                return 0
            }

            let notification = UnsafeRawPointer(bitPattern: lParam)?.assumingMemoryBound(to: NMLISTVIEW.self).pointee
            guard let notification,
                  let source = header.hwndFrom else {
                return nil
            }

            let handle = nativeHandle(from: source)
            switch header.code {
            case lvnColumnClick:
                guard let action = controlActions[handle.rawValue] else {
                    return nil
                }

                let headerHwnd = HWND(bitPattern: winSendMessageW(source, lvmGetHeader, 0, 0))
                let hitColumn = headerHitTestAtCursor(hwnd: headerHwnd)
                tableClickedRows[handle.rawValue] = -1
                tableClickedColumns[handle.rawValue] = hitColumn >= 0 ? hitColumn : Int(notification.iSubItem)
                action()
                return 0
            case nmClick:
                guard let action = controlActions[handle.rawValue] else {
                    return nil
                }

                let hit = tableHitTest(at: notification.ptAction, hwnd: source)
                let clickedRow = hit.row >= 0 ? hit.row : Int(notification.iItem)
                let clickedColumn = hit.column >= 0 ? hit.column : Int(notification.iSubItem)
                guard clickedRow >= 0 else {
                    return nil
                }

                tableClickedRows[handle.rawValue] = clickedRow
                tableClickedColumns[handle.rawValue] = clickedColumn
                action()
                return 0
            case lvnItemChanged:
                guard notification.iItem >= 0,
                      (notification.uChanged & lvifState) != 0,
                      (notification.uNewState & lvisSelected) != (notification.uOldState & lvisSelected),
                      (notification.uNewState & lvisSelected) != 0,
                      let action = controlActions[handle.rawValue] else {
                    return nil
                }

                tableClickedRows[handle.rawValue] = Int(notification.iItem)
                tableClickedColumns[handle.rawValue] = max(0, tableClickedColumns[handle.rawValue] ?? -1)
                action()
                return 0
            default:
                return nil
            }
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

            if lParam != 0, notificationCode == lbnSelChange, let action = controlActions[UInt(bitPattern: lParam)] {
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

    private func dispatchControlMessage(hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT? {
        switch message {
        case wmGetDlgCode:
            let original = callOriginalControlProcedure(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
            return original | dlgcWantTab
        case wmKeyDown, wmSysKeyDown:
            guard UInt16(wParam & 0xffff) == UInt16(vkTab),
                  let hwnd,
                  let action = keyDownActions[nativeHandle(from: hwnd).rawValue] else {
                return nil
            }

            action(keyEvent(type: .keyDown, wParam: wParam))
            return 0
        case wmKeyUp, wmSysKeyUp:
            guard UInt16(wParam & 0xffff) == UInt16(vkTab),
                  let hwnd,
                  let action = keyUpActions[nativeHandle(from: hwnd).rawValue] else {
                return nil
            }

            action(keyEvent(type: .keyUp, wParam: wParam))
            return 0
        case wmLButtonDown:
            guard let hwnd,
                  let action = mouseDownActions[nativeHandle(from: hwnd).rawValue] else {
                return nil
            }

            _ = winSetFocus(hwnd)
            action(NSEvent(type: .leftMouseDown, locationInWindow: point(from: lParam), modifierFlags: currentModifierFlags()))
            return nil
        case wmLButtonUp:
            guard let hwnd,
                  let action = mouseUpActions[nativeHandle(from: hwnd).rawValue] else {
                return nil
            }

            action(NSEvent(type: .leftMouseUp, locationInWindow: point(from: lParam), modifierFlags: currentModifierFlags()))
            return nil
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

    private func initializeListViewControls() {
        var initControls = INITCOMMONCONTROLSEX()
        initControls.dwSize = DWORD(MemoryLayout<INITCOMMONCONTROLSEX>.size)
        initControls.dwICC = iccListViewClasses
        withUnsafePointer(to: initControls) { pointer in
            _ = winInitCommonControlsEx(pointer)
        }
    }

    private func installTableColumns(_ columns: [String], for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        let fallbackWidth = max(80, Int32(frameWidth(for: handle) / CGFloat(max(columns.count, 1))))
        for (index, titleText) in columns.enumerated() {
            withWideString(titleText.isEmpty ? "Column \(index + 1)" : titleText) { title in
                var column = LVCOLUMNW()
                column.mask = lvcfText | lvcfWidth | lvcfSubItem
                column.cx = fallbackWidth
                column.pszText = UnsafeMutablePointer(mutating: title)
                column.iSubItem = Int32(index)
                withUnsafePointer(to: column) { columnPointer in
                    _ = winSendMessageW(hwnd, lvmInsertColumnW, WPARAM(index), Int(bitPattern: columnPointer))
                }
            }
        }
    }

    private func setTableCellText(_ text: String, row: Int, column: Int, hwnd: HWND?) {
        withWideString(text) { title in
            var item = LVITEMW()
            item.iItem = Int32(row)
            item.iSubItem = Int32(column)
            item.pszText = UnsafeMutablePointer(mutating: title)
            withUnsafePointer(to: item) { itemPointer in
                _ = winSendMessageW(hwnd, lvmSetItemTextW, WPARAM(row), Int(bitPattern: itemPointer))
            }
        }
    }

    private func tableHitTest(at point: POINT, hwnd: HWND?) -> (row: Int, column: Int) {
        guard let hwnd else {
            return (-1, -1)
        }

        var hitTest = LVHITTESTINFO()
        hitTest.pt = point
        withUnsafeMutablePointer(to: &hitTest) { hitTestPointer in
            _ = winSendMessageW(hwnd, lvmSubItemHitTest, 0, Int(bitPattern: hitTestPointer))
        }

        return (Int(hitTest.iItem), Int(hitTest.iSubItem))
    }

    private func headerHitTestAtCursor(hwnd: HWND?) -> Int {
        guard let hwnd else {
            return -1
        }

        var point = POINT()
        guard winGetCursorPos(&point) != 0,
              winScreenToClient(hwnd, &point) != 0 else {
            return -1
        }

        var hitTest = HDHITTESTINFO()
        hitTest.pt = point
        withUnsafeMutablePointer(to: &hitTest) { hitTestPointer in
            _ = winSendMessageW(hwnd, hdmHitTest, 0, Int(bitPattern: hitTestPointer))
        }

        return Int(hitTest.iItem)
    }

    private func frameWidth(for handle: NativeHandle) -> CGFloat {
        guard let hwnd = hwnd(from: handle) else {
            return 240
        }

        var rectangle = RECT()
        guard winGetClientRect(hwnd, &rectangle) != 0 else {
            return 240
        }

        return CGFloat(max(1, rectangle.right - rectangle.left))
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

    private func subclassChildControl(_ hwnd: HWND, handle: NativeHandle) {
        let replacement = unsafeBitCast(winChocolateControlProcedure as WNDPROC, to: LONG_PTR.self)
        let previous = winSetWindowLongPtrW(hwnd, gwlpWndProc, replacement)
        guard previous != 0 else {
            return
        }

        originalControlProcedures[handle.rawValue] = unsafeBitCast(previous, to: WNDPROC.self)
    }

    private func subclassControlForTabKey(_ handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        subclassChildControl(hwnd, handle: handle)
    }

    private func callOriginalControlProcedure(hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT {
        guard let hwnd,
              let originalProcedure = originalControlProcedures[nativeHandle(from: hwnd).rawValue] else {
            return winDefWindowProcW(hwnd, message, wParam, lParam)
        }

        return winCallWindowProcW(originalProcedure, hwnd, message, wParam, lParam)
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
            guard !item.isHidden else {
                continue
            }

            if let submenu = item.submenu, let nativeSubmenu = createNativePopupMenu(from: submenu) {
                withWideString(item.title) { title in
                    _ = winAppendMenuW(nativeMenu, mfPopup | menuStateFlags(for: item), UInt(bitPattern: nativeSubmenu), title)
                }
                continue
            }

            if item.isSeparatorItem {
                _ = winAppendMenuW(nativeMenu, mfSeparator, 0, nil)
                continue
            }

            let commandIdentifier = nextCommandID()
            commandActions[commandIdentifier] = { [weak item] in
                _ = item?.performAction()
            }

            withWideString(item.title) { title in
                _ = winAppendMenuW(nativeMenu, mfString | menuStateFlags(for: item), commandIdentifier, title)
            }
        }
    }

    private func menuStateFlags(for item: NSMenuItem) -> UINT {
        item.isEnabled ? 0 : mfGrayed
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

    private func point(from lParam: LPARAM) -> NSPoint {
        let x = Int16(bitPattern: UInt16(lParam & 0xffff))
        let y = Int16(bitPattern: UInt16((lParam >> 16) & 0xffff))
        return NSMakePoint(CGFloat(x), CGFloat(y))
    }

    private func keyEvent(type: NSEvent.EventType, wParam: WPARAM) -> NSEvent {
        let keyCode = UInt16(wParam & 0xffff)
        let modifierFlags = modifierFlags(forKeyCode: keyCode, eventType: type)
        return NSEvent(
            type: type,
            locationInWindow: NSMakePoint(0, 0),
            keyCode: keyCode,
            characters: characters(forVirtualKey: keyCode, modifierFlags: modifierFlags),
            modifierFlags: modifierFlags
        )
    }

    private func characters(forVirtualKey virtualKey: UInt16, modifierFlags: NSEvent.ModifierFlags) -> String? {
        let shiftIsDown = modifierFlags.contains(.shift)
        switch virtualKey {
        case 0x30...0x39:
            return String(UnicodeScalar(UInt32(virtualKey))!)
        case 0x41...0x5a:
            let scalar = shiftIsDown ? UInt32(virtualKey) : UInt32(virtualKey + 32)
            return String(UnicodeScalar(scalar)!)
        case UInt16(vkSpace):
            return " "
        case UInt16(vkTab):
            return "\t"
        case UInt16(vkReturn):
            return "\n"
        case UInt16(vkEscape):
            return "\u{1b}"
        case UInt16(vkBack):
            return "\u{8}"
        default:
            return nil
        }
    }

    private func modifierFlags(forKeyCode keyCode: UInt16, eventType: NSEvent.EventType) -> NSEvent.ModifierFlags {
        var flags = currentModifierFlags()
        guard let eventFlag = modifierFlag(forVirtualKey: keyCode) else {
            return flags
        }

        switch eventType {
        case .keyDown:
            flags.insert(eventFlag)
        case .keyUp:
            flags.remove(eventFlag)
        default:
            break
        }

        return flags
    }

    private func currentModifierFlags() -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if keyIsDown(vkShift) || keyIsDown(vkLShift) || keyIsDown(vkRShift) {
            flags.insert(.shift)
        }
        if keyIsDown(vkControl) || keyIsDown(vkLControl) || keyIsDown(vkRControl) {
            flags.insert(.control)
        }
        if keyIsDown(vkMenu) || keyIsDown(vkLMenu) || keyIsDown(vkRMenu) {
            flags.insert(.option)
        }
        if keyIsDown(vkLWin) || keyIsDown(vkRWin) {
            flags.insert(.command)
        }
        return flags
    }

    private func modifierFlag(forVirtualKey virtualKey: UInt16) -> NSEvent.ModifierFlags? {
        switch Int32(virtualKey) {
        case vkShift, vkLShift, vkRShift:
            return .shift
        case vkControl, vkLControl, vkRControl:
            return .control
        case vkMenu, vkLMenu, vkRMenu:
            return .option
        case vkLWin, vkRWin:
            return .command
        default:
            return nil
        }
    }

    private func keyIsDown(_ virtualKey: Int32) -> Bool {
        (winGetKeyState(virtualKey) & Int16(bitPattern: 0x8000)) != 0
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

private func winChocolateControlProcedure(
    hwnd: HWND?,
    message: UINT,
    wParam: WPARAM,
    lParam: LPARAM
) -> LRESULT {
    if let result = Win32NativeControlBackend.dispatchControlMessage(
        hwnd: hwnd,
        message: message,
        wParam: wParam,
        lParam: lParam
    ) {
        return result
    }

    return Win32NativeControlBackend.callOriginalControlProcedure(
        hwnd: hwnd,
        message: message,
        wParam: wParam,
        lParam: lParam
    )
}
#endif
