#if os(Windows)
private typealias HWND = UnsafeMutableRawPointer
private typealias HMENU = UnsafeMutableRawPointer
private typealias HINSTANCE = UnsafeMutableRawPointer
private typealias HBRUSH = UnsafeMutableRawPointer
private typealias HCURSOR = UnsafeMutableRawPointer
private typealias HDC = UnsafeMutableRawPointer
private typealias HFONT = UnsafeMutableRawPointer
private typealias HGDIOBJ = UnsafeMutableRawPointer
private typealias HBITMAP = UnsafeMutableRawPointer
private typealias HIMAGELIST = UnsafeMutableRawPointer
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

private struct PAINTSTRUCT {
    var hdc: HDC?
    var fErase: Int32 = 0
    var rcPaint: RECT = RECT()
    var fRestore: Int32 = 0
    var fIncUpdate: Int32 = 0
    var rgbReserved: (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    ) = (
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    )
}

private struct INITCOMMONCONTROLSEX {
    var dwSize: DWORD = 0
    var dwICC: DWORD = 0
}

private struct SYSTEMTIME {
    var wYear: UInt16 = 0
    var wMonth: UInt16 = 0
    var wDayOfWeek: UInt16 = 0
    var wDay: UInt16 = 0
    var wHour: UInt16 = 0
    var wMinute: UInt16 = 0
    var wSecond: UInt16 = 0
    var wMilliseconds: UInt16 = 0
}

private struct SCROLLINFO {
    var cbSize: UINT = UINT(MemoryLayout<SCROLLINFO>.size)
    var fMask: UINT = 0
    var nMin: Int32 = 0
    var nMax: Int32 = 0
    var nPage: UINT = 0
    var nPos: Int32 = 0
    var nTrackPos: Int32 = 0
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

private struct NMUPDOWN {
    var hdr: NMHDR = NMHDR()
    var iPos: Int32 = 0
    var iDelta: Int32 = 0
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

private struct TCITEMW {
    var mask: UINT = 0
    var dwState: DWORD = 0
    var dwStateMask: DWORD = 0
    var pszText: UnsafeMutablePointer<UInt16>?
    var cchTextMax: Int32 = 0
    var iImage: Int32 = 0
    var lParam: LPARAM = 0
}

private struct TBBUTTON {
    var iBitmap: Int32 = 0
    var idCommand: Int32 = 0
    var fsState: UInt8 = 0
    var fsStyle: UInt8 = 0
    var bReserved0: UInt8 = 0
    var bReserved1: UInt8 = 0
    var dwData: UInt = 0
    var iString: Int = 0
}

private struct TBBUTTONINFOW {
    var cbSize: UINT = 0
    var dwMask: DWORD = 0
    var idCommand: Int32 = 0
    var iImage: Int32 = 0
    var fsState: UInt8 = 0
    var fsStyle: UInt8 = 0
    var cx: UInt16 = 0
    var lParam: LPARAM = 0
    var pszText: UnsafeMutablePointer<UInt16>?
    var cchText: Int32 = 0
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

@_silgen_name("SetScrollInfo")
private func winSetScrollInfo(_ hwnd: HWND?, _ bar: Int32, _ scrollInfo: UnsafePointer<SCROLLINFO>, _ redraw: Int32) -> Int32

@_silgen_name("GetScrollInfo")
private func winGetScrollInfo(_ hwnd: HWND?, _ bar: Int32, _ scrollInfo: UnsafeMutablePointer<SCROLLINFO>) -> Int32

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

@_silgen_name("ClientToScreen")
private func winClientToScreen(_ hwnd: HWND?, _ point: UnsafeMutablePointer<POINT>?) -> Int32

@_silgen_name("BeginPaint")
private func winBeginPaint(_ hwnd: HWND?, _ paint: UnsafeMutablePointer<PAINTSTRUCT>?) -> HDC?

@_silgen_name("EndPaint")
private func winEndPaint(_ hwnd: HWND?, _ paint: UnsafePointer<PAINTSTRUCT>?) -> Int32

@_silgen_name("DrawTextW")
private func winDrawTextW(_ deviceContext: HDC?, _ text: UnsafePointer<UInt16>?, _ count: Int32, _ rectangle: UnsafeMutablePointer<RECT>?, _ format: UINT) -> Int32

@_silgen_name("ImageList_Draw")
private func winImageListDraw(_ imageList: HIMAGELIST?, _ index: Int32, _ deviceContext: HDC?, _ x: Int32, _ y: Int32, _ style: UINT) -> Int32

@_silgen_name("FillRect")
private func winFillRect(_ deviceContext: HDC?, _ rectangle: UnsafePointer<RECT>?, _ brush: HBRUSH?) -> Int32

@_silgen_name("GetClientRect")
private func winGetClientRect(_ hwnd: HWND?, _ rectangle: UnsafeMutablePointer<RECT>?) -> Int32

@_silgen_name("GetMessageW")
private func winGetMessageW(_ message: UnsafeMutablePointer<MSG>, _ hwnd: HWND?, _ minimumMessage: UINT, _ maximumMessage: UINT) -> Int32

@_silgen_name("GetParent")
private func winGetParent(_ hwnd: HWND?) -> HWND?

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

@_silgen_name("GetWindow")
private func winGetWindow(_ hwnd: HWND?, _ command: UINT) -> HWND?

@_silgen_name("IsWindow")
private func winIsWindow(_ hwnd: HWND?) -> Int32

@_silgen_name("InvalidateRect")
private func winInvalidateRect(_ hwnd: HWND?, _ rectangle: UnsafePointer<RECT>?, _ erase: Int32) -> Int32

@_silgen_name("LoadCursorW")
private func winLoadCursorW(_ instance: HINSTANCE?, _ cursorName: UnsafePointer<UInt16>?) -> HCURSOR?

@_silgen_name("LoadImageW")
private func winLoadImageW(
    _ instance: HINSTANCE?,
    _ name: UnsafePointer<UInt16>?,
    _ type: UINT,
    _ width: Int32,
    _ height: Int32,
    _ loadFlags: UINT
) -> UnsafeMutableRawPointer?

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

@_silgen_name("PostMessageW")
private func winPostMessageW(_ hwnd: HWND?, _ message: UINT, _ wParam: WPARAM, _ lParam: LPARAM) -> Int32

@_silgen_name("RegisterClassW")
private func winRegisterClassW(_ windowClass: UnsafePointer<WNDCLASSW>) -> UInt16

@_silgen_name("SetMenu")
private func winSetMenu(_ hwnd: HWND?, _ menu: HMENU?) -> Int32

@_silgen_name("SetBkColor")
private func winSetBkColor(_ deviceContext: HDC?, _ color: DWORD) -> DWORD

@_silgen_name("SetBkMode")
private func winSetBkMode(_ deviceContext: HDC?, _ backgroundMode: Int32) -> Int32

@_silgen_name("ScreenToClient")
private func winScreenToClient(_ hwnd: HWND?, _ point: UnsafeMutablePointer<POINT>?) -> Int32

@_silgen_name("SetCapture")
private func winSetCapture(_ hwnd: HWND?) -> HWND?

@_silgen_name("ReleaseCapture")
private func winReleaseCapture() -> Int32

@_silgen_name("SetTextColor")
private func winSetTextColor(_ deviceContext: HDC?, _ color: DWORD) -> DWORD

@_silgen_name("SetFocus")
private func winSetFocus(_ hwnd: HWND?) -> HWND?

@_silgen_name("SetWindowLongPtrW")
private func winSetWindowLongPtrW(_ hwnd: HWND?, _ index: Int32, _ newLong: LONG_PTR) -> LONG_PTR

@_silgen_name("SetWindowPos")
private func winSetWindowPos(
    _ hwnd: HWND?,
    _ insertAfter: HWND?,
    _ x: Int32,
    _ y: Int32,
    _ width: Int32,
    _ height: Int32,
    _ flags: UINT
) -> Int32

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
private let swpNoActivate: UINT = 0x0010
private let swpShowWindow: UINT = 0x0040
private let wmDestroy: UINT = 0x0002
private let wmSize: UINT = 0x0005
private let wmNotify: UINT = 0x004e
private let wmPaint: UINT = 0x000f
private let wmEraseBackground: UINT = 0x0014
private let wmSetFont: UINT = 0x0030
private let wmCommand: UINT = 0x0111
private let wmUser: UINT = 0x0400
private let stmSetImage: UINT = 0x0172
private let wmHScroll: UINT = 0x0114
private let wmVScroll: UINT = 0x0115
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
private let mkLButton: WPARAM = 0x0001
private let transparentBkMode: Int32 = 1
private let dtCenter: UINT = 0x00000001
private let dtVCenter: UINT = 0x00000004
private let dtSingleLine: UINT = 0x00000020
private let dtEndEllipsis: UINT = 0x00008000
private let wmApp: UINT = 0x8000
private let wmWinChocolateAsync: UINT = wmApp + 1
private let bmGetCheck: UINT = 0x00f0
private let bmSetCheck: UINT = 0x00f1
private let cbAddString: UINT = 0x0143
private let cbGetCurSel: UINT = 0x0147
private let cbResetContent: UINT = 0x014b
private let cbSetCurSel: UINT = 0x014e
private let cbShowDropDown: UINT = 0x014f
private let sbmSetPos: UINT = 0x00e0
private let sbmGetPos: UINT = 0x00e1
private let sbmSetRange: UINT = 0x00e2
private let sbmSetScrollInfo: UINT = 0x00e9
private let sbmGetScrollInfo: UINT = 0x00ea
private let pbmSetRange32: UINT = 0x0406
private let pbmSetPos: UINT = 0x0402
private let udmSetRange32: UINT = 0x046f
private let udmSetPos32: UINT = 0x0471
private let lbAddString: UINT = 0x0180
private let lbSetCurSel: UINT = 0x0186
private let lbGetCurSel: UINT = 0x0188
private let lbResetContent: UINT = 0x0184
private let hdmFirst: UINT = 0x1200
private let hdmHitTest: UINT = hdmFirst + 6
private let lvmFirst: UINT = 0x1000
private let lvmDeleteAllItems: UINT = lvmFirst + 9
private let lvmGetNextItem: UINT = lvmFirst + 12
private let lvmEnsureVisible: UINT = lvmFirst + 19
private let lvmGetHeader: UINT = lvmFirst + 31
private let lvmSetItemState: UINT = lvmFirst + 43
private let lvmSubItemHitTest: UINT = lvmFirst + 57
private let lvmInsertItemW: UINT = lvmFirst + 77
private let lvmInsertColumnW: UINT = lvmFirst + 97
private let lvmSetItemTextW: UINT = lvmFirst + 116
private let lvmSetExtendedListViewStyle: UINT = lvmFirst + 54
private let tcmFirst: UINT = 0x1300
private let tcmGetCurSel: UINT = tcmFirst + 11
private let tcmSetCurSel: UINT = tcmFirst + 12
private let tcmDeleteAllItems: UINT = tcmFirst + 9
private let tcmInsertItemW: UINT = tcmFirst + 62
private let tbAddButtonsW: UINT = wmUser + 68
private let tbAddStringW: UINT = wmUser + 77
private let tbAutosize: UINT = wmUser + 33
private let tbButtonCount: UINT = wmUser + 24
private let tbButtonStructSize: UINT = wmUser + 30
private let tbDeleteButton: UINT = wmUser + 22
private let tbGetImageList: UINT = wmUser + 49
private let tbGetItemRect: UINT = wmUser + 29
private let tbLoadImages: UINT = wmUser + 50
private let tbSetButtonInfoW: UINT = wmUser + 64
private let enChange: UInt = 0x0300
private let lbnSelChange: UInt = 1
private let nmClick: UINT = 0xfffffffe
private let lvnItemChanged: UINT = 0xffffff9b
private let lvnColumnClick: UINT = 0xffffff94
private let hdnItemClickA: UINT = 0xfffffed2
private let hdnItemClickW: UINT = 0xfffffebe
private let udnDeltapos: UINT = 0xfffffd2e
private let tcnSelChange: UINT = 0xffffffc9
private let dtnDateTimeChange: UINT = 0xfffffd09
private let bnClicked: UInt = 0
private let cbnSelChange: UInt = 1
private let cbnEditChange: UInt = 5
private let iccListViewClasses: DWORD = 0x00000001
private let iccBarClasses: DWORD = 0x00000004
private let iccTabClasses: DWORD = 0x00000008
private let iccUpDownClass: DWORD = 0x00000010
private let iccProgressClass: DWORD = 0x00000020
private let iccDateClasses: DWORD = 0x00000100
private let dtmFirst: UINT = 0x1000
private let dtmGetSystemTime: UINT = dtmFirst + 1
private let dtmSetSystemTime: UINT = dtmFirst + 2
private let gdtValid: WPARAM = 0
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
private let gwChild: UINT = 5
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
private let esMultiline: DWORD = 0x0004
private let esPassword: DWORD = 0x0020
private let esAutoVScroll: DWORD = 0x0040
private let esAutoHScroll: DWORD = 0x0080
private let esWantReturn: DWORD = 0x1000
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
private let bsFlat: DWORD = 0x00008000
private let ssWhiteRect: DWORD = 0x00000006
private let tbStateEnabled: UInt8 = 0x04
private let tbStyleButton: UInt8 = 0x00
private let tbStyleSep: UInt8 = 0x01
private let tbifSize: DWORD = 0x00000040
private let btnsAutosize: UInt8 = 0x10
private let btnsShowText: UInt8 = 0x40
private let iImageNone: Int32 = -2
private let iStringNone: Int = -1
private let idbStdSmallColor: WPARAM = 0
private let hinstCommctrl: LPARAM = -1
private let stdFileNew: Int32 = 0
private let stdFileOpen: Int32 = 1
private let stdFileSave: Int32 = 2
private let stdPrint: Int32 = 6
private let stdProperties: Int32 = 10
private let stdHelp: Int32 = 11
private let ildNormal: UINT = 0x00000000
private let toolbarClassName = "ToolbarWindow32"
private let tbStyleFlat: DWORD = 0x00000800
private let tbStyleList: DWORD = 0x00001000
private let tbStyleTooltips: DWORD = 0x00000100
private let ccsNoResize: DWORD = 0x00000004
private let ccsNoDivider: DWORD = 0x00000040
private let ssNotify: DWORD = 0x00000100
private let ssBitmap: DWORD = 0x0000000e
private let ssCenterImage: DWORD = 0x00000200
private let cbsDropdown: DWORD = 0x0002
private let cbsDropdownList: DWORD = 0x0003
private let tciText: UINT = 0x0001
private let sbsHorz: DWORD = 0x0000
private let sbsVert: DWORD = 0x0001
private let sbHorz: Int32 = 0
private let sbVert: Int32 = 1
private let sifRange: UINT = 0x0001
private let sifPage: UINT = 0x0002
private let sifPos: UINT = 0x0004
private let sifTrackPos: UINT = 0x0010
private let sifAll: UINT = sifRange | sifPage | sifPos | sifTrackPos
private let udsArrowKeys: DWORD = 0x0020
private let sbLineLeft: UInt = 0
private let sbLineRight: UInt = 1
private let sbPageLeft: UInt = 2
private let sbPageRight: UInt = 3
private let sbThumbPosition: UInt = 4
private let sbThumbTrack: UInt = 5
private let sbTop: UInt = 6
private let sbBottom: UInt = 7
private let imageBitmap: UINT = 0
private let lrLoadFromFile: UINT = 0x00000010
private let lrCreatedDIBSection: UINT = 0x00002000

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
    private var mainMenuWindowHandles: Set<NativeHandle> = []
    private var controlActions: [UInt: () -> Void] = [:]
    private var textChangeActions: [UInt: (String) -> Void] = [:]
    private var mouseDownActions: [UInt: (NSEvent) -> Void] = [:]
    private var mouseUpActions: [UInt: (NSEvent) -> Void] = [:]
    private var mouseMovedActions: [UInt: (NSEvent) -> Void] = [:]
    private var mouseDraggedActions: [UInt: (NSEvent) -> Void] = [:]
    private var keyDownActions: [UInt: (NSEvent) -> Void] = [:]
    private var keyUpActions: [UInt: (NSEvent) -> Void] = [:]
    private var windowCloseActions: [UInt: () -> Void] = [:]
    private var windowResizeActions: [UInt: (NSSize) -> Void] = [:]
    private var originalControlProcedures: [UInt: WNDPROC] = [:]
    private var controlHandleAliases: [UInt: NativeHandle] = [:]
    private var commandActions: [UInt: () -> Void] = [:]
    private var asyncActions: [() -> Void] = []
    private var toolbarActions: [UInt: (String) -> Void] = [:]
    private var toolbarCommandIdentifiers: [UInt: [UInt]] = [:]
    private var toolbarFlexibleCoverHandles: [UInt: [NativeHandle]] = [:]
    private var tableColumnTitles: [UInt: [String]] = [:]
    private var tableHeaderOwners: [UInt: NativeHandle] = [:]
    private var tableSuppressedColumnClicks: [UInt: Int] = [:]
    private var tableClickedRows: [UInt: Int] = [:]
    private var tableClickedColumns: [UInt: Int] = [:]
    private var sliderRanges: [UInt: (minValue: Double, maxValue: Double)] = [:]
    private var scrollViewMetrics: [UInt: (contentSize: NSSize, viewportSize: NSSize, hasVerticalScroller: Bool, hasHorizontalScroller: Bool, offset: NSPoint)] = [:]
    private var stepperRanges: [UInt: (minValue: Double, maxValue: Double, increment: Double, value: Double)] = [:]
    private var customViewHandles: Set<UInt> = []
    private var textColors: [UInt: DWORD] = [:]
    private var backgroundColors: [UInt: DWORD] = [:]
    private var backgroundBrushes: [UInt: HBRUSH] = [:]
    private var fonts: [UInt: HFONT] = [:]
    private var bitmaps: [UInt: HBITMAP] = [:]
    private var standardToolbarImageOwner: HWND?
    private var standardToolbarImageList: HIMAGELIST?
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

    /// Schedules work after the current native message dispatch returns.
    public func dispatchAsync(_ action: @escaping () -> Void) {
        asyncActions.append(action)
        let targetWindow = windowHandles.first.flatMap { hwnd(from: $0) }
        _ = winPostMessageW(targetWindow, wmWinChocolateAsync, 0, 0)
    }

    /// Installs the native application menu bar.
    public func installMainMenu(_ menu: NSMenu?) {
        mainMenu = menu

        for windowHandle in mainMenuWindowHandles {
            guard let hwnd = hwnd(from: windowHandle) else {
                continue
            }

            _ = winSetMenu(hwnd, createNativeMenu(from: menu))
            _ = winDrawMenuBar(hwnd)
        }
    }

    /// Creates a native top-level window.
    public func createWindow(title: String, frame: NSRect, styleMask: NSWindow.StyleMask, usesMainMenu: Bool) -> NativeHandle {
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
                    usesMainMenu ? createNativeMenu(from: mainMenu) : nil,
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
        if usesMainMenu {
            mainMenuWindowHandles.insert(handle)
        }
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
        mainMenuWindowHandles.remove(handle)
        controlActions.removeValue(forKey: handle.rawValue)
        textChangeActions.removeValue(forKey: handle.rawValue)
        mouseDownActions.removeValue(forKey: handle.rawValue)
        mouseUpActions.removeValue(forKey: handle.rawValue)
        mouseMovedActions.removeValue(forKey: handle.rawValue)
        mouseDraggedActions.removeValue(forKey: handle.rawValue)
        keyDownActions.removeValue(forKey: handle.rawValue)
        keyUpActions.removeValue(forKey: handle.rawValue)
        windowCloseActions.removeValue(forKey: handle.rawValue)
        windowResizeActions.removeValue(forKey: handle.rawValue)
        clearToolbarCommands(for: handle)
        clearToolbarFlexibleCovers(for: handle)
        toolbarActions.removeValue(forKey: handle.rawValue)
        originalControlProcedures.removeValue(forKey: handle.rawValue)
        controlHandleAliases = controlHandleAliases.filter { $0.value != handle }
        tableColumnTitles.removeValue(forKey: handle.rawValue)
        tableHeaderOwners = tableHeaderOwners.filter { $0.value != handle }
        tableSuppressedColumnClicks.removeValue(forKey: handle.rawValue)
        tableClickedRows.removeValue(forKey: handle.rawValue)
        tableClickedColumns.removeValue(forKey: handle.rawValue)
        sliderRanges.removeValue(forKey: handle.rawValue)
        scrollViewMetrics.removeValue(forKey: handle.rawValue)
        stepperRanges.removeValue(forKey: handle.rawValue)
        customViewHandles.remove(handle.rawValue)
        clearAppearance(for: handle)
    }

    /// Registers a native window close action.
    public func registerWindowCloseAction(for handle: NativeHandle, action: @escaping () -> Void) {
        windowCloseActions[handle.rawValue] = action
    }

    /// Registers the action to perform when a native top-level window resizes.
    public func registerWindowResizeAction(for handle: NativeHandle, action: @escaping (NSSize) -> Void) {
        windowResizeActions[handle.rawValue] = action
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
        mouseDraggedActions.removeValue(forKey: handle.rawValue)
        keyDownActions.removeValue(forKey: handle.rawValue)
        keyUpActions.removeValue(forKey: handle.rawValue)
        clearToolbarCommands(for: handle)
        clearToolbarFlexibleCovers(for: handle)
        toolbarActions.removeValue(forKey: handle.rawValue)
        originalControlProcedures.removeValue(forKey: handle.rawValue)
        controlHandleAliases = controlHandleAliases.filter { $0.value != handle }
        tableColumnTitles.removeValue(forKey: handle.rawValue)
        tableHeaderOwners = tableHeaderOwners.filter { $0.value != handle }
        tableSuppressedColumnClicks.removeValue(forKey: handle.rawValue)
        tableClickedRows.removeValue(forKey: handle.rawValue)
        tableClickedColumns.removeValue(forKey: handle.rawValue)
        sliderRanges.removeValue(forKey: handle.rawValue)
        scrollViewMetrics.removeValue(forKey: handle.rawValue)
        stepperRanges.removeValue(forKey: handle.rawValue)
        customViewHandles.remove(handle.rawValue)
        clearAppearance(for: handle)
    }

    /// Creates a native view child.
    public func createView(frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        registerViewClassIfNeeded()
        let handle = createChildWindow(
            className: winChocolateViewClassName,
            text: "",
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: wsChild | wsVisible | wsClipChildren
        )
        customViewHandles.insert(handle.rawValue)
        return handle
    }

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

    /// Creates a native secure text field child.
    public func createSecureTextField(text: String, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = createChildWindow(
            className: "EDIT",
            text: text,
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: wsChild | wsVisible | wsTabStop | wsBorder | esAutoHScroll | esPassword
        )
        subclassControlForTabKey(handle)
        return handle
    }

    /// Creates a native multiline text view child.
    public func createTextView(text: String, frame: NSRect, parent: NativeHandle?, isEditable: Bool) -> NativeHandle {
        let handle = createChildWindow(
            className: isEditable ? "EDIT" : "STATIC",
            text: text,
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: isEditable
                ? wsChild | wsVisible | wsTabStop | wsBorder | wsVScroll | esMultiline | esAutoVScroll | esWantReturn
                : wsChild | wsVisible | wsBorder
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
        setComboBoxItems(items, text: text, for: handle)
        return handle
    }

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

    /// Creates a native toolbar child.
    public func createToolbar(items: [NativeToolbarItem], frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        initializeToolbarControls()
        let handle = createChildWindow(
            className: toolbarClassName,
            text: "",
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: wsChild | wsVisible | wsTabStop | tbStyleFlat | tbStyleTooltips | ccsNoResize | ccsNoDivider
        )
        guard let hwnd = hwnd(from: handle) else {
            return handle
        }

        _ = winSendMessageW(hwnd, tbButtonStructSize, WPARAM(MemoryLayout<TBBUTTON>.size), 0)
        _ = winSendMessageW(hwnd, tbLoadImages, idbStdSmallColor, hinstCommctrl)
        setToolbarItems(items, for: handle)
        return handle
    }

    /// Replaces native toolbar items.
    public func setToolbarItems(_ items: [NativeToolbarItem], for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        clearToolbarButtons(hwnd: hwnd)
        clearToolbarCommands(for: handle)
        clearToolbarFlexibleCovers(for: handle)
        let flexibleButtonIndexes = installToolbarItems(items, hwnd: hwnd, handle: handle)
        _ = winSendMessageW(hwnd, tbAutosize, 0, 0)
        installToolbarFlexibleCovers(at: flexibleButtonIndexes, hwnd: hwnd, handle: handle)
    }

    /// Registers a native toolbar action.
    public func registerToolbarAction(for handle: NativeHandle, action: @escaping (String) -> Void) {
        toolbarActions[handle.rawValue] = action
    }

    /// Creates a native slider child.
    public func createSlider(value: Double, minValue: Double, maxValue: Double, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = createChildWindow(
            className: "SCROLLBAR",
            text: "",
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: wsChild | wsVisible | wsTabStop | sbsHorz
        )
        subclassControlForTabKey(handle)
        setSliderRange(minValue: minValue, maxValue: maxValue, for: handle)
        setSliderValue(value, for: handle)
        return handle
    }

    /// Creates a native progress-indicator child.
    public func createProgressIndicator(value: Double, minValue: Double, maxValue: Double, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        initializeProgressControls()
        let handle = createChildWindow(
            className: "msctls_progress32",
            text: "",
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: wsChild | wsVisible
        )
        setProgressIndicatorRange(minValue: minValue, maxValue: maxValue, for: handle)
        setProgressIndicatorValue(value, for: handle)
        return handle
    }

    /// Creates a native scroller child.
    public func createScroller(value: Double, knobProportion: Double, isVertical: Bool, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        let handle = createChildWindow(
            className: "SCROLLBAR",
            text: "",
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: wsChild | wsVisible | (isVertical ? sbsVert : sbsHorz)
        )
        setSliderRange(minValue: 0, maxValue: 100, for: handle)
        setScrollerValue(value, knobProportion: knobProportion, for: handle)
        return handle
    }

    /// Creates a native stepper child.
    public func createStepper(value: Double, minValue: Double, maxValue: Double, increment: Double, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        initializeUpDownControls()
        let handle = createChildWindow(
            className: "msctls_updown32",
            text: "",
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: wsChild | wsVisible | wsTabStop | udsArrowKeys
        )
        subclassControlForTabKey(handle)
        setStepperRange(minValue: minValue, maxValue: maxValue, increment: increment, for: handle)
        setStepperValue(value, for: handle)
        return handle
    }

    /// Creates a native date-picker child.
    public func createDatePicker(date: Date, minDate: Date?, maxDate: Date?, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        initializeDateControls()
        let handle = createChildWindow(
            className: "SysDateTimePick32",
            text: "",
            frame: frame,
            parent: parent,
            commandIdentifier: nil,
            style: wsChild | wsVisible | wsTabStop
        )
        subclassControlForTabKey(handle)
        setDatePickerDate(date, minDate: minDate, maxDate: maxDate, for: handle)
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

    /// Updates native scroll-view document and viewport geometry.
    public func setScrollViewContentSize(_ contentSize: NSSize, viewportSize: NSSize, hasVerticalScroller: Bool, hasHorizontalScroller: Bool, for handle: NativeHandle) {
        scrollViewMetrics[handle.rawValue] = (
            contentSize,
            viewportSize,
            hasVerticalScroller,
            hasHorizontalScroller,
            scrollViewMetrics[handle.rawValue]?.offset ?? NSZeroPoint
        )
        updateScrollViewBars(for: handle)
    }

    /// Updates the native scroll-view visible document origin.
    public func setScrollViewContentOffset(_ offset: NSPoint, for handle: NativeHandle) {
        guard var metrics = scrollViewMetrics[handle.rawValue] else {
            return
        }

        let maxX = max(0, metrics.contentSize.width - metrics.viewportSize.width)
        let maxY = max(0, metrics.contentSize.height - metrics.viewportSize.height)
        metrics.offset = NSPoint(
            x: min(max(offset.x, 0), maxX),
            y: min(max(offset.y, 0), maxY)
        )
        scrollViewMetrics[handle.rawValue] = metrics
        updateScrollViewBars(for: handle)
    }

    /// Reads the native scroll-view visible document origin.
    public func scrollViewContentOffset(for handle: NativeHandle) -> NSPoint {
        scrollViewMetrics[handle.rawValue]?.offset ?? NSZeroPoint
    }

    /// Creates a native table-view child.
    public func createTableView(columns: [String], rows: [[String]], selectedRow: Int, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
        createTableView(columns: columns, columnWidths: [], rows: rows, selectedRow: selectedRow, frame: frame, parent: parent)
    }

    /// Creates a native table-view child with explicit column widths.
    public func createTableView(columns: [String], columnWidths: [CGFloat], rows: [[String]], selectedRow: Int, frame: NSRect, parent: NativeHandle?) -> NativeHandle {
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
        installTableColumns(columns, widths: columnWidths, for: handle)
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
        invalidate(handle)
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
        _ = winInvalidateRect(hwnd, nil, 1)
        _ = winUpdateWindow(hwnd)
        if let parent = winGetParent(hwnd) {
            _ = winInvalidateRect(parent, nil, 1)
            _ = winUpdateWindow(parent)
        }
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

        let bitmap = withWideString(imagePath) { path in
            winLoadImageW(nil, path, imageBitmap, 0, 0, lrLoadFromFile | lrCreatedDIBSection)
        }

        guard let bitmap else {
            setText(description, for: handle)
            return
        }

        bitmaps[handle.rawValue] = bitmap
        _ = winSendMessageW(hwnd, stmSetImage, WPARAM(imageBitmap), LPARAM(bitPattern: bitmap))
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

    /// Reads native combo-box text.
    public func comboBoxText(for handle: NativeHandle) -> String {
        guard let hwnd = hwnd(from: handle) else {
            return ""
        }

        return text(from: hwnd)
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

    /// Updates native slider range.
    public func setSliderRange(minValue: Double, maxValue: Double, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        let lower = Int32(min(minValue, maxValue).rounded())
        let upper = Int32(max(minValue, maxValue).rounded())
        sliderRanges[handle.rawValue] = (Double(lower), Double(upper))
        _ = winSendMessageW(hwnd, sbmSetRange, WPARAM(lower), LPARAM(upper))
    }

    /// Updates native slider value.
    public func setSliderValue(_ value: Double, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        let range = sliderRanges[handle.rawValue] ?? (0, 1)
        let clampedValue = min(max(value, range.minValue), range.maxValue)
        _ = winSendMessageW(hwnd, sbmSetPos, WPARAM(Int32(clampedValue.rounded())), 1)
    }

    /// Reads native slider value.
    public func sliderValue(for handle: NativeHandle) -> Double {
        guard let hwnd = hwnd(from: handle) else {
            return 0
        }

        return Double(winSendMessageW(hwnd, sbmGetPos, 0, 0))
    }

    /// Updates native progress-indicator range.
    public func setProgressIndicatorRange(minValue: Double, maxValue: Double, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        let lower = Int32(min(minValue, maxValue).rounded())
        let upper = Int32(max(minValue, maxValue).rounded())
        _ = winSendMessageW(hwnd, pbmSetRange32, WPARAM(lower), LPARAM(upper))
    }

    /// Updates native progress-indicator value.
    public func setProgressIndicatorValue(_ value: Double, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winSendMessageW(hwnd, pbmSetPos, WPARAM(Int32(value.rounded())), 0)
    }

    /// Updates native scroller state.
    public func setScrollerValue(_ value: Double, knobProportion: Double, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        let clampedValue = min(max(value, 0), 1)
        let clampedProportion = min(max(knobProportion, 0), 1)
        sliderRanges[handle.rawValue] = (0, 100)
        var scrollInfo = SCROLLINFO(
            cbSize: UINT(MemoryLayout<SCROLLINFO>.size),
            fMask: sifRange | sifPage | sifPos,
            nMin: 0,
            nMax: 100,
            nPage: UINT(max(1, Int32((clampedProportion * 100).rounded()))),
            nPos: Int32((clampedValue * 100).rounded()),
            nTrackPos: 0
        )
        withUnsafePointer(to: &scrollInfo) { pointer in
            _ = winSendMessageW(hwnd, sbmSetScrollInfo, 1, LPARAM(bitPattern: pointer))
        }
    }

    /// Reads native scroller value.
    public func scrollerValue(for handle: NativeHandle) -> Double {
        guard let hwnd = hwnd(from: handle) else {
            return 0
        }

        var scrollInfo = SCROLLINFO(cbSize: UINT(MemoryLayout<SCROLLINFO>.size), fMask: sifAll)
        let result = withUnsafeMutablePointer(to: &scrollInfo) { pointer in
            winSendMessageW(hwnd, sbmGetScrollInfo, 0, LPARAM(bitPattern: pointer))
        }
        guard result != 0 else {
            return min(max(sliderValue(for: handle) / 100, 0), 1)
        }

        return min(max(Double(scrollInfo.nPos) / 100, 0), 1)
    }

    /// Updates native stepper range.
    public func setStepperRange(minValue: Double, maxValue: Double, increment: Double, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        let lower = Int32(min(minValue, maxValue).rounded())
        let upper = Int32(max(minValue, maxValue).rounded())
        let current = stepperRanges[handle.rawValue]?.value ?? Double(lower)
        stepperRanges[handle.rawValue] = (
            Double(lower),
            Double(upper),
            max(1, increment.rounded()),
            min(max(current, Double(lower)), Double(upper))
        )
        _ = winSendMessageW(hwnd, udmSetRange32, WPARAM(lower), LPARAM(upper))
    }

    /// Updates native stepper value.
    public func setStepperValue(_ value: Double, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        var range = stepperRanges[handle.rawValue] ?? (0, 100, 1, 0)
        range.value = min(max(value, range.minValue), range.maxValue)
        stepperRanges[handle.rawValue] = range
        _ = winSendMessageW(hwnd, udmSetPos32, 0, LPARAM(Int32(range.value.rounded())))
    }

    /// Reads native stepper value.
    public func stepperValue(for handle: NativeHandle) -> Double {
        stepperRanges[handle.rawValue]?.value ?? 0
    }

    /// Updates native date-picker state.
    public func setDatePickerDate(_ date: Date, minDate: Date?, maxDate: Date?, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        var systemTime = systemTime(from: date)
        withUnsafePointer(to: &systemTime) { pointer in
            _ = winSendMessageW(hwnd, dtmSetSystemTime, gdtValid, LPARAM(bitPattern: pointer))
        }
    }

    /// Reads native date-picker value.
    public func datePickerDate(for handle: NativeHandle) -> Date? {
        guard let hwnd = hwnd(from: handle) else {
            return nil
        }

        var systemTime = SYSTEMTIME()
        let result = withUnsafeMutablePointer(to: &systemTime) { pointer in
            winSendMessageW(hwnd, dtmGetSystemTime, 0, LPARAM(bitPattern: pointer))
        }
        guard WPARAM(result) == gdtValid else {
            return nil
        }

        return date(from: systemTime)
    }

    private func updateSliderPosition(from scrollParameter: WPARAM, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        let range = sliderRanges[handle.rawValue] ?? (0, 1)
        let current = Double(winSendMessageW(hwnd, sbmGetPos, 0, 0))
        let code = scrollParameter & 0xffff
        let thumb = Double((scrollParameter >> 16) & 0xffff)
        let pageStep = max(1, ((range.maxValue - range.minValue) / 10).rounded())
        let nextValue: Double

        switch code {
        case sbLineLeft:
            nextValue = current - 1
        case sbLineRight:
            nextValue = current + 1
        case sbPageLeft:
            nextValue = current - pageStep
        case sbPageRight:
            nextValue = current + pageStep
        case sbThumbPosition, sbThumbTrack:
            nextValue = thumb
        case sbTop:
            nextValue = range.minValue
        case sbBottom:
            nextValue = range.maxValue
        default:
            nextValue = current
        }

        setSliderValue(nextValue, for: handle)
    }

    private func updateScrollViewBars(for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle), let metrics = scrollViewMetrics[handle.rawValue] else {
            return
        }

        if metrics.hasHorizontalScroller {
            setWindowScrollInfo(
                hwnd: hwnd,
                bar: sbHorz,
                contentLength: metrics.contentSize.width,
                viewportLength: metrics.viewportSize.width,
                position: metrics.offset.x
            )
        }

        if metrics.hasVerticalScroller {
            setWindowScrollInfo(
                hwnd: hwnd,
                bar: sbVert,
                contentLength: metrics.contentSize.height,
                viewportLength: metrics.viewportSize.height,
                position: metrics.offset.y
            )
        }
    }

    private func setWindowScrollInfo(hwnd: HWND?, bar: Int32, contentLength: Double, viewportLength: Double, position: Double) {
        let content = max(0, Int32(contentLength.rounded()))
        let viewport = max(1, Int32(viewportLength.rounded()))
        let maximum = max(0, content - 1)
        let maxPosition = max(0, content - viewport)
        var scrollInfo = SCROLLINFO(
            cbSize: UINT(MemoryLayout<SCROLLINFO>.size),
            fMask: sifRange | sifPage | sifPos,
            nMin: 0,
            nMax: maximum,
            nPage: UINT(viewport),
            nPos: min(max(Int32(position.rounded()), 0), maxPosition),
            nTrackPos: 0
        )
        withUnsafePointer(to: &scrollInfo) { pointer in
            _ = winSetScrollInfo(hwnd, bar, pointer, 1)
        }
    }

    private func updateScrollViewPosition(from scrollParameter: WPARAM, message: UINT, for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle), var metrics = scrollViewMetrics[handle.rawValue] else {
            return
        }

        let isVertical = message == wmVScroll
        let bar = isVertical ? sbVert : sbHorz
        var scrollInfo = SCROLLINFO(cbSize: UINT(MemoryLayout<SCROLLINFO>.size), fMask: sifAll)
        guard withUnsafeMutablePointer(to: &scrollInfo, { pointer in winGetScrollInfo(hwnd, bar, pointer) }) != 0 else {
            return
        }

        let code = scrollParameter & 0xffff
        let current = Double(scrollInfo.nPos)
        let page = max(1, Double(scrollInfo.nPage))
        let line = max(1, page / 10)
        let maximum = max(0, Double(scrollInfo.nMax) - page + 1)
        let nextPosition: Double

        switch code {
        case sbLineLeft:
            nextPosition = current - line
        case sbLineRight:
            nextPosition = current + line
        case sbPageLeft:
            nextPosition = current - page
        case sbPageRight:
            nextPosition = current + page
        case sbThumbPosition, sbThumbTrack:
            nextPosition = Double(scrollInfo.nTrackPos)
        case sbTop:
            nextPosition = 0
        case sbBottom:
            nextPosition = maximum
        default:
            nextPosition = current
        }

        let clampedPosition = min(max(nextPosition, 0), maximum)
        if isVertical {
            metrics.offset = NSPoint(x: metrics.offset.x, y: clampedPosition)
        } else {
            metrics.offset = NSPoint(x: clampedPosition, y: metrics.offset.y)
        }
        scrollViewMetrics[handle.rawValue] = metrics
        updateScrollViewBars(for: handle)
    }

    private func updateStepperPosition(from scrollParameter: WPARAM, for handle: NativeHandle) {
        guard stepperRanges[handle.rawValue] != nil else {
            return
        }

        let range = stepperRanges[handle.rawValue] ?? (0, 100, 1, 0)
        let code = scrollParameter & 0xffff
        let thumb = Double((scrollParameter >> 16) & 0xffff)
        let nextValue: Double

        switch code {
        case sbLineLeft:
            nextValue = range.value + range.increment
        case sbLineRight:
            nextValue = range.value - range.increment
        case sbPageLeft:
            nextValue = range.value + range.increment
        case sbPageRight:
            nextValue = range.value - range.increment
        case sbThumbPosition, sbThumbTrack:
            nextValue = thumb
        case sbTop:
            nextValue = range.maxValue
        case sbBottom:
            nextValue = range.minValue
        default:
            nextValue = range.value
        }

        setStepperValue(nextValue, for: handle)
    }

    private func updateStepperPosition(position: Int32, delta: Int32, for handle: NativeHandle) {
        guard let range = stepperRanges[handle.rawValue], delta != 0 else {
            return
        }

        let direction = delta > 0 ? 1.0 : -1.0
        let nativePosition = Double(position)
        let baseValue = min(max(nativePosition, range.minValue), range.maxValue)
        setStepperValue(baseValue + (direction * range.increment), for: handle)
    }

    private func updateStepperPosition(fromClickAt point: NSPoint, hwnd: HWND, for handle: NativeHandle) {
        guard let range = stepperRanges[handle.rawValue] else {
            return
        }

        var rectangle = RECT()
        let height: Double
        if winGetClientRect(hwnd, &rectangle) != 0 {
            height = Double(max(1, rectangle.bottom - rectangle.top))
        } else {
            height = 1
        }

        let direction = point.y < height / 2 ? 1.0 : -1.0
        setStepperValue(range.value + (direction * range.increment), for: handle)
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

    /// Scrolls a native table row into view.
    public func scrollTableRowToVisible(_ row: Int, for handle: NativeHandle) {
        guard row >= 0,
              let hwnd = hwnd(from: handle) else {
            return
        }

        _ = winSendMessageW(hwnd, lvmEnsureVisible, WPARAM(row), 0)
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
        case wmWinChocolateAsync:
            runAsyncActions()
            return 0
        case wmSize:
            guard let hwnd else {
                return nil
            }

            let handle = nativeHandle(from: hwnd)
            guard windowHandles.contains(handle), let action = windowResizeActions[handle.rawValue] else {
                return nil
            }

            var rectangle = RECT()
            guard winGetClientRect(hwnd, &rectangle) != 0 else {
                return nil
            }

            action(NSSize(width: CGFloat(max(0, rectangle.right - rectangle.left)), height: CGFloat(max(0, rectangle.bottom - rectangle.top))))
            return 0
        case wmHScroll, wmVScroll:
            guard lParam != 0, let scrollHwnd = HWND(bitPattern: lParam) else {
                guard let hwnd else {
                    return nil
                }

                let handle = nativeHandle(from: hwnd)
                guard scrollViewMetrics[handle.rawValue] != nil else {
                    return nil
                }

                updateScrollViewPosition(from: wParam, message: message, for: handle)
                controlActions[handle.rawValue]?()
                return 0
            }

            let handle = nativeHandle(from: scrollHwnd)
            guard stepperRanges[handle.rawValue] == nil else {
                return 0
            }

            updateSliderPosition(from: wParam, for: handle)
            guard let action = controlActions[handle.rawValue] else {
                return nil
            }

            action()
            return 0
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
            guard let hwnd else {
                return nil
            }

            let handle = nativeHandle(from: hwnd)
            if (wParam & mkLButton) != 0, let action = mouseDraggedActions[handle.rawValue] {
                action(NSEvent(type: .leftMouseDragged, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
                return 0
            }

            guard let action = mouseMovedActions[handle.rawValue] else {
                return nil
            }

            action(NSEvent(type: .mouseMoved, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
            return 0
        case wmLButtonDown:
            guard let hwnd, let action = mouseDownActions[nativeHandle(from: hwnd).rawValue] else {
                return nil
            }

            _ = winSetCapture(hwnd)
            _ = winSetFocus(hwnd)
            action(NSEvent(type: .leftMouseDown, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
            return 0
        case wmLButtonUp:
            guard let hwnd, let action = mouseUpActions[nativeHandle(from: hwnd).rawValue] else {
                return nil
            }

            action(NSEvent(type: .leftMouseUp, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
            _ = winReleaseCapture()
            return 0
        case wmPaint:
            guard let hwnd else {
                return nil
            }

            let handle = nativeHandle(from: hwnd)
            guard customViewHandles.contains(handle.rawValue) else {
                return nil
            }

            drawCustomView(hwnd: hwnd, handle: handle)
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
                tableSuppressedColumnClicks[handle.rawValue] = clickedColumn
                action()
                return 0
            }

            if header.code == udnDeltapos {
                guard let source = header.hwndFrom else {
                    return nil
                }

                let handle = nativeHandle(from: source)
                guard stepperRanges[handle.rawValue] != nil else {
                    return nil
                }

                return 1
            }

            if header.code == tcnSelChange {
                guard let source = header.hwndFrom else {
                    return nil
                }

                let handle = nativeHandle(from: source)
                guard let action = controlActions[handle.rawValue] else {
                    return nil
                }

                action()
                return 0
            }

            if header.code == dtnDateTimeChange {
                guard let source = header.hwndFrom else {
                    return nil
                }

                let handle = nativeHandle(from: source)
                guard let action = controlActions[handle.rawValue] else {
                    return nil
                }

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
                if let headerHwnd,
                   tableHeaderOwners[UInt(bitPattern: headerHwnd)] == handle {
                    tableSuppressedColumnClicks.removeValue(forKey: handle.rawValue)
                    return 0
                }

                let hitColumn = headerHitTestAtCursor(hwnd: headerHwnd)
                let clickedColumn = hitColumn >= 0 ? hitColumn : Int(notification.iSubItem)
                if tableSuppressedColumnClicks[handle.rawValue] == clickedColumn {
                    tableSuppressedColumnClicks.removeValue(forKey: handle.rawValue)
                    return 0
                }

                tableClickedRows[handle.rawValue] = -1
                tableClickedColumns[handle.rawValue] = clickedColumn
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

            if lParam != 0, notificationCode == cbnEditChange, let action = textChangeActions[UInt(bitPattern: lParam)] {
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
            if let hwnd {
                let handle = nativeHandle(from: hwnd)
                guard windowHandles.contains(handle) else {
                    return 0
                }

                let shouldTerminate = mainMenuWindowHandles.contains(handle)
                windowHandles.remove(handle)
                mainMenuWindowHandles.remove(handle)
                windowResizeActions.removeValue(forKey: handle.rawValue)
                windowCloseActions.removeValue(forKey: handle.rawValue)?()

                if shouldTerminate {
                    winPostQuitMessage(0)
                }
            }
            return 0
        default:
            return nil
        }
    }

    private func runAsyncActions() {
        let pendingActions = asyncActions
        asyncActions.removeAll()
        for action in pendingActions {
            action()
        }
    }

    private func dispatchControlMessage(hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT? {
        switch message {
        case wmMouseMove:
            guard let hwnd else {
                return nil
            }

            let handle = actionHandle(from: hwnd)
            if (wParam & mkLButton) != 0, let action = mouseDraggedActions[handle.rawValue] {
                action(NSEvent(type: .leftMouseDragged, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
                return nil
            }

            guard let action = mouseMovedActions[handle.rawValue] else {
                return nil
            }

            action(NSEvent(type: .mouseMoved, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
            return nil
        case wmGetDlgCode:
            let original = callOriginalControlProcedure(hwnd: hwnd, message: message, wParam: wParam, lParam: lParam)
            return original | dlgcWantTab
        case wmKeyDown, wmSysKeyDown:
            guard UInt16(wParam & 0xffff) == UInt16(vkTab),
                  let hwnd,
                  let action = keyDownActions[actionHandle(from: hwnd).rawValue] else {
                return nil
            }

            action(keyEvent(type: .keyDown, wParam: wParam))
            return 0
        case wmKeyUp, wmSysKeyUp:
            guard UInt16(wParam & 0xffff) == UInt16(vkTab),
                  let hwnd,
                  let action = keyUpActions[actionHandle(from: hwnd).rawValue] else {
                return nil
            }

            action(keyEvent(type: .keyUp, wParam: wParam))
            return 0
        case wmLButtonDown:
            guard let hwnd else {
                return nil
            }

            let handle = actionHandle(from: hwnd)
            if stepperRanges[handle.rawValue] != nil,
               let action = controlActions[handle.rawValue] {
                updateStepperPosition(fromClickAt: point(from: lParam), hwnd: hwnd, for: handle)
                _ = winSetCapture(hwnd)
                _ = winSetFocus(hwnd)
                action()
                return 0
            }

            guard let action = mouseDownActions[handle.rawValue] else {
                return nil
            }

            _ = winSetCapture(hwnd)
            _ = winSetFocus(hwnd)
            action(NSEvent(type: .leftMouseDown, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
            return nil
        case wmLButtonUp:
            guard let hwnd,
                  let action = mouseUpActions[actionHandle(from: hwnd).rawValue] else {
                return nil
            }

            action(NSEvent(type: .leftMouseUp, locationInWindow: mouseLocation(from: lParam, in: hwnd), modifierFlags: currentModifierFlags()))
            _ = winReleaseCapture()
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

    private func initializeToolbarControls() {
        var initControls = INITCOMMONCONTROLSEX()
        initControls.dwSize = DWORD(MemoryLayout<INITCOMMONCONTROLSEX>.size)
        initControls.dwICC = iccBarClasses
        withUnsafePointer(to: initControls) { pointer in
            _ = winInitCommonControlsEx(pointer)
        }
    }

    private func initializeTabControls() {
        var initControls = INITCOMMONCONTROLSEX()
        initControls.dwSize = DWORD(MemoryLayout<INITCOMMONCONTROLSEX>.size)
        initControls.dwICC = iccTabClasses
        withUnsafePointer(to: initControls) { pointer in
            _ = winInitCommonControlsEx(pointer)
        }
    }

    private func initializeUpDownControls() {
        var initControls = INITCOMMONCONTROLSEX()
        initControls.dwSize = DWORD(MemoryLayout<INITCOMMONCONTROLSEX>.size)
        initControls.dwICC = iccUpDownClass
        withUnsafePointer(to: initControls) { pointer in
            _ = winInitCommonControlsEx(pointer)
        }
    }

    private func initializeProgressControls() {
        var initControls = INITCOMMONCONTROLSEX()
        initControls.dwSize = DWORD(MemoryLayout<INITCOMMONCONTROLSEX>.size)
        initControls.dwICC = iccProgressClass
        withUnsafePointer(to: initControls) { pointer in
            _ = winInitCommonControlsEx(pointer)
        }
    }

    private func initializeDateControls() {
        var initControls = INITCOMMONCONTROLSEX()
        initControls.dwSize = DWORD(MemoryLayout<INITCOMMONCONTROLSEX>.size)
        initControls.dwICC = iccDateClasses
        withUnsafePointer(to: initControls) { pointer in
            _ = winInitCommonControlsEx(pointer)
        }
    }

    private func installTableColumns(_ columns: [String], widths: [CGFloat], for handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        let fallbackWidth = max(80, Int32(frameWidth(for: handle) / CGFloat(max(columns.count, 1))))
        for (index, titleText) in columns.enumerated() {
            withWideString(titleText.isEmpty ? "Column \(index + 1)" : titleText) { title in
                var column = LVCOLUMNW()
                column.mask = lvcfText | lvcfWidth | lvcfSubItem
                let requestedWidth = widths.indices.contains(index) ? Int32(widths[index]) : fallbackWidth
                column.cx = max(24, requestedWidth)
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

    private func clearToolbarButtons(hwnd: HWND?) {
        guard let hwnd else {
            return
        }

        while winSendMessageW(hwnd, tbButtonCount, 0, 0) > 0 {
            _ = winSendMessageW(hwnd, tbDeleteButton, 0, 0)
        }
    }

    private func clearToolbarCommands(for handle: NativeHandle) {
        guard let commandIdentifiers = toolbarCommandIdentifiers.removeValue(forKey: handle.rawValue) else {
            return
        }

        for commandIdentifier in commandIdentifiers {
            commandActions.removeValue(forKey: commandIdentifier)
        }
    }

    private func clearToolbarFlexibleCovers(for handle: NativeHandle) {
        guard let coverHandles = toolbarFlexibleCoverHandles.removeValue(forKey: handle.rawValue) else {
            return
        }

        for coverHandle in coverHandles {
            if let coverHwnd = hwnd(from: coverHandle) {
                _ = winDestroyWindow(coverHwnd)
            }
            clearAppearance(for: coverHandle)
        }
    }

    private func installToolbarItems(_ items: [NativeToolbarItem], hwnd: HWND?, handle: NativeHandle) -> [Int] {
        guard let hwnd else {
            return []
        }

        var buttons: [TBBUTTON] = []
        var commandIdentifiers: [UInt] = []
        var flexibleButtonIndexes: [Int] = []
        let flexibleSpaceWidth = toolbarFlexibleSpaceWidth(for: items, handle: handle)

        for item in items {
            if item.isFlexibleSpace {
                flexibleButtonIndexes.append(buttons.count)
                buttons.append(TBBUTTON(
                    iBitmap: flexibleSpaceWidth,
                    idCommand: 0,
                    fsState: 0,
                    fsStyle: tbStyleSep,
                    bReserved0: 0,
                    bReserved1: 0,
                    dwData: 0,
                    iString: 0
                ))
                continue
            }

            if item.isSeparator {
                buttons.append(TBBUTTON(
                    iBitmap: 8,
                    idCommand: 0,
                    fsState: 0,
                    fsStyle: tbStyleSep,
                    bReserved0: 0,
                    bReserved1: 0,
                    dwData: 0,
                    iString: 0
                ))
                continue
            }

            let labelIndex = toolbarStringIndex(for: item.label, hwnd: hwnd)
            let imageIndex = toolbarImageIndex(for: item.imageName)
            let commandIdentifier = nextCommandID()
            commandIdentifiers.append(commandIdentifier)
            commandActions[commandIdentifier] = { [weak self] in
                self?.toolbarActions[handle.rawValue]?(item.identifier)
            }

            buttons.append(TBBUTTON(
                iBitmap: imageIndex,
                idCommand: Int32(commandIdentifier),
                fsState: item.isEnabled ? tbStateEnabled : 0,
                fsStyle: tbStyleButton | btnsAutosize | btnsShowText,
                bReserved0: 0,
                bReserved1: 0,
                dwData: 0,
                iString: labelIndex
            ))
        }

        toolbarCommandIdentifiers[handle.rawValue] = commandIdentifiers

        guard !buttons.isEmpty else {
            return flexibleButtonIndexes
        }

        buttons.withUnsafeBufferPointer { buttonPointer in
            _ = winSendMessageW(hwnd, tbAddButtonsW, WPARAM(buttons.count), Int(bitPattern: buttonPointer.baseAddress))
        }

        return flexibleButtonIndexes
    }

    private func installToolbarFlexibleCovers(at indexes: [Int], hwnd toolbarHwnd: HWND?, handle: NativeHandle) {
        guard let toolbarHwnd, !indexes.isEmpty else {
            return
        }

        var coverHandles: [NativeHandle] = []
        for index in indexes {
            var rectangle = RECT()
            let result = withUnsafeMutablePointer(to: &rectangle) { rectanglePointer in
                winSendMessageW(toolbarHwnd, tbGetItemRect, WPARAM(index), Int(bitPattern: rectanglePointer))
            }
            guard result != 0 else {
                continue
            }

            let centerX = rectangle.left + ((rectangle.right - rectangle.left) / 2)
            let coverWidth: Int32 = 24
            let coverFrame = NSMakeRect(Double(centerX - (coverWidth / 2)), 0, Double(coverWidth), Double(max(1, rectangle.bottom - rectangle.top)))
            let coverHandle = createChildWindow(
                className: "STATIC",
                text: "",
                frame: coverFrame,
                parent: handle,
                commandIdentifier: nil,
                style: wsChild | wsVisible | ssWhiteRect
            )
            if let coverHwnd = hwnd(from: coverHandle) {
                _ = winSetWindowPos(
                    coverHwnd,
                    nil,
                    centerX - (coverWidth / 2),
                    0,
                    coverWidth,
                    max(1, rectangle.bottom - rectangle.top),
                    swpNoActivate | swpShowWindow
                )
                _ = winInvalidateRect(coverHwnd, nil, 1)
                _ = winUpdateWindow(coverHwnd)
            }
            coverHandles.append(coverHandle)
        }

        if !coverHandles.isEmpty {
            toolbarFlexibleCoverHandles[handle.rawValue] = coverHandles
        }
    }

    private func toolbarFlexibleSpaceWidth(for items: [NativeToolbarItem], handle: NativeHandle) -> Int32 {
        let flexibleCount = items.filter(\.isFlexibleSpace).count
        guard flexibleCount > 0 else {
            return 8
        }

        let fixedWidth = items.reduce(CGFloat(0)) { width, item in
            if item.isFlexibleSpace {
                return width
            }

            if item.isSeparator {
                return width + 8
            }

            let iconWidth: CGFloat = item.imageName == nil ? 0 : 24
            let labelWidth = CGFloat(max(28, item.label.count * 6))
            return width + max(iconWidth, labelWidth) + 20
        }
        let availableWidth = frameWidth(for: handle) - fixedWidth - 8
        let perSpaceWidth = availableWidth / CGFloat(flexibleCount)
        return Int32(max(16, perSpaceWidth.rounded(.down)))
    }

    private func toolbarStringIndex(for label: String, hwnd: HWND?) -> Int {
        guard !label.isEmpty else {
            return 0
        }

        let result = withWideString(label) { title in
            winSendMessageW(hwnd, tbAddStringW, 0, Int(bitPattern: title))
        }

        guard result >= 0 else {
            return 0
        }

        return result
    }

    private func toolbarImageIndex(for imageName: String?) -> Int32 {
        guard let imageName else {
            return iImageNone
        }

        switch imageName.lowercased() {
        case "new", "document", "doc", "filenew", "square.and.pencil":
            return stdFileNew
        case "open", "folder", "folder.open", "fileopen":
            return stdFileOpen
        case "save", "filesave", "square.and.arrow.down", "tray.and.arrow.down":
            return stdFileSave
        case "print", "printer":
            return stdPrint
        case "properties", "info", "info.circle", "gear", "gearshape":
            return stdProperties
        case "help", "questionmark", "questionmark.circle":
            return stdHelp
        default:
            return iImageNone
        }
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

        originalControlProcedures[UInt(bitPattern: hwnd)] = unsafeBitCast(previous, to: WNDPROC.self)
        controlHandleAliases[UInt(bitPattern: hwnd)] = handle
    }

    private func subclassControlForTabKey(_ handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle) else {
            return
        }

        subclassChildControl(hwnd, handle: handle)
    }

    private func subclassFirstChildControlForTabKey(_ handle: NativeHandle) {
        guard let hwnd = hwnd(from: handle),
              let child = winGetWindow(hwnd, gwChild) else {
            return
        }

        subclassChildControl(child, handle: handle)
    }

    private func callOriginalControlProcedure(hwnd: HWND?, message: UINT, wParam: WPARAM, lParam: LPARAM) -> LRESULT {
        guard let hwnd,
              let originalProcedure = originalControlProcedures[UInt(bitPattern: hwnd)] else {
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

    private func drawCustomView(hwnd: HWND?, handle: NativeHandle) {
        var paint = PAINTSTRUCT()
        guard let deviceContext = winBeginPaint(hwnd, &paint) else {
            return
        }
        defer {
            withUnsafePointer(to: paint) { paintPointer in
                _ = winEndPaint(hwnd, paintPointer)
            }
        }

        var rectangle = RECT()
        _ = winGetClientRect(hwnd, &rectangle)
        if let brush = backgroundBrushes[handle.rawValue] {
            withUnsafePointer(to: rectangle) { rectanglePointer in
                _ = winFillRect(deviceContext, rectanglePointer, brush)
            }
        }

        let preview = toolbarPreview(from: text(from: hwnd))
        guard !preview.label.isEmpty else {
            return
        }

        if let textColor = textColors[handle.rawValue] {
            _ = winSetTextColor(deviceContext, textColor)
        }
        let backgroundColor = backgroundColors[handle.rawValue] ?? colorRef(red: 0.94, green: 0.94, blue: 0.94)
        _ = winSetBkColor(deviceContext, backgroundColor)
        _ = winSetBkMode(deviceContext, transparentBkMode)

        drawToolbarItemGlyph(preview: preview, in: rectangle, deviceContext: deviceContext, parentWindow: hwnd)

        var textRectangle = rectangle
        textRectangle.left += 2
        textRectangle.top = max(rectangle.top + 18, rectangle.bottom - 13)
        textRectangle.right -= 2
        withWideString(preview.label) { textPointer in
            withUnsafeMutablePointer(to: &textRectangle) { rectanglePointer in
                _ = winDrawTextW(deviceContext, textPointer, -1, rectanglePointer, dtCenter | dtVCenter | dtSingleLine | dtEndEllipsis)
            }
        }
    }

    private func toolbarPreview(from text: String) -> (label: String, imageName: String) {
        let parts = text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        let label = parts.first.map(String.init) ?? text
        let imageName = parts.count > 1 ? String(parts[1]) : label
        return (label, imageName)
    }

    private func drawToolbarItemGlyph(preview: (label: String, imageName: String), in rectangle: RECT, deviceContext: HDC?, parentWindow: HWND?) {
        let width = rectangle.right - rectangle.left
        let height = rectangle.bottom - rectangle.top
        let glyphSize = max(12, min(18, height - 14))
        let glyphLeft = rectangle.left + max((width - glyphSize) / 2, 2)
        let glyphTop = rectangle.top + 3
        let kind = preview.imageName.lowercased()

        if kind.contains("separator") {
            drawSeparatorGlyph(left: glyphLeft, top: glyphTop, size: glyphSize, deviceContext: deviceContext)
            return
        }
        if kind.contains("flexiblespace") {
            drawFlexibleSpaceGlyph(left: glyphLeft, top: glyphTop, size: glyphSize, deviceContext: deviceContext)
            return
        }
        if kind == "space" || kind.contains("fixedspace") {
            drawSpaceGlyph(left: glyphLeft, top: glyphTop, size: glyphSize, deviceContext: deviceContext)
            return
        }

        let imageIndex = toolbarImageIndex(for: preview.imageName)
        if imageIndex != iImageNone, let imageList = standardToolbarImages(parentWindow: parentWindow) {
            let imageLeft = rectangle.left + max((width - 16) / 2, 2)
            _ = winImageListDraw(imageList, imageIndex, deviceContext, imageLeft, glyphTop, ildNormal)
            return
        }

        drawDocumentGlyph(left: glyphLeft, top: glyphTop, size: glyphSize, accent: toolbarGlyphColor(for: preview.imageName), deviceContext: deviceContext)
    }

    private func standardToolbarImages(parentWindow: HWND?) -> HIMAGELIST? {
        if let standardToolbarImageList, winIsWindow(standardToolbarImageOwner) != 0 {
            return standardToolbarImageList
        }
        standardToolbarImageOwner = nil
        standardToolbarImageList = nil

        let toolbarHwnd = withWideString(toolbarClassName) { className in
            withWideString("") { title in
                winCreateWindowExW(
                    0,
                    className,
                    title,
                    wsChild,
                    -32_000,
                    -32_000,
                    1,
                    1,
                    parentWindow,
                    nil,
                    winGetModuleHandleW(nil),
                    nil
                )
            }
        }
        guard let toolbarHwnd else {
            return nil
        }

        _ = winSendMessageW(toolbarHwnd, tbButtonStructSize, WPARAM(MemoryLayout<TBBUTTON>.size), 0)
        _ = winSendMessageW(toolbarHwnd, tbLoadImages, idbStdSmallColor, hinstCommctrl)
        let imageList = HIMAGELIST(bitPattern: winSendMessageW(toolbarHwnd, tbGetImageList, 0, 0))
        standardToolbarImageOwner = toolbarHwnd
        standardToolbarImageList = imageList
        return imageList
    }

    private func drawDocumentGlyph(left glyphLeft: Int32, top glyphTop: Int32, size glyphSize: Int32, accent: DWORD, deviceContext: HDC?) {
        let shadow = colorRef(red: 0.50, green: 0.52, blue: 0.55)
        let paper = colorRef(red: 0.98, green: 0.98, blue: 0.96)
        let shine = colorRef(red: 1.0, green: 1.0, blue: 1.0)

        fillRect(
            RECT(left: glyphLeft + 1, top: glyphTop + 1, right: glyphLeft + glyphSize + 1, bottom: glyphTop + glyphSize + 1),
            color: shadow,
            deviceContext: deviceContext
        )
        fillRect(
            RECT(left: glyphLeft, top: glyphTop, right: glyphLeft + glyphSize, bottom: glyphTop + glyphSize),
            color: paper,
            deviceContext: deviceContext
        )
        fillRect(
            RECT(left: glyphLeft + 3, top: glyphTop + 4, right: glyphLeft + glyphSize - 3, bottom: glyphTop + glyphSize - 2),
            color: accent,
            deviceContext: deviceContext
        )
        fillRect(
            RECT(left: glyphLeft + 4, top: glyphTop + 5, right: glyphLeft + glyphSize - 4, bottom: glyphTop + 7),
            color: shine,
            deviceContext: deviceContext
        )
        fillRect(
            RECT(left: glyphLeft + glyphSize - 5, top: glyphTop, right: glyphLeft + glyphSize, bottom: glyphTop + 5),
            color: colorRef(red: 0.88, green: 0.90, blue: 0.92),
            deviceContext: deviceContext
        )
    }

    private func drawFolderGlyph(left glyphLeft: Int32, top glyphTop: Int32, size glyphSize: Int32, deviceContext: HDC?) {
        let edge = colorRef(red: 0.61, green: 0.43, blue: 0.16)
        let tab = colorRef(red: 0.94, green: 0.68, blue: 0.22)
        let body = colorRef(red: 0.98, green: 0.78, blue: 0.30)
        let shine = colorRef(red: 1.0, green: 0.90, blue: 0.48)
        fillRect(RECT(left: glyphLeft + 1, top: glyphTop + 5, right: glyphLeft + glyphSize, bottom: glyphTop + glyphSize - 1), color: edge, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 2, top: glyphTop + 3, right: glyphLeft + glyphSize / 2 + 2, bottom: glyphTop + 7), color: tab, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 2, top: glyphTop + 7, right: glyphLeft + glyphSize - 1, bottom: glyphTop + glyphSize - 2), color: body, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 4, top: glyphTop + 8, right: glyphLeft + glyphSize - 3, bottom: glyphTop + 10), color: shine, deviceContext: deviceContext)
    }

    private func drawSaveGlyph(left glyphLeft: Int32, top glyphTop: Int32, size glyphSize: Int32, deviceContext: HDC?) {
        let body = colorRef(red: 0.11, green: 0.28, blue: 0.58)
        let edge = colorRef(red: 0.05, green: 0.12, blue: 0.30)
        let label = colorRef(red: 0.94, green: 0.94, blue: 0.90)
        let metal = colorRef(red: 0.78, green: 0.81, blue: 0.84)
        fillRect(RECT(left: glyphLeft + 1, top: glyphTop + 1, right: glyphLeft + glyphSize, bottom: glyphTop + glyphSize), color: edge, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 2, top: glyphTop + 2, right: glyphLeft + glyphSize - 1, bottom: glyphTop + glyphSize - 1), color: body, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 4, top: glyphTop + 3, right: glyphLeft + glyphSize - 4, bottom: glyphTop + 7), color: metal, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + glyphSize - 6, top: glyphTop + 4, right: glyphLeft + glyphSize - 4, bottom: glyphTop + 6), color: edge, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 4, top: glyphTop + glyphSize - 7, right: glyphLeft + glyphSize - 4, bottom: glyphTop + glyphSize - 2), color: label, deviceContext: deviceContext)
    }

    private func drawPrintGlyph(left glyphLeft: Int32, top glyphTop: Int32, size glyphSize: Int32, deviceContext: HDC?) {
        fillRect(RECT(left: glyphLeft + 4, top: glyphTop + 1, right: glyphLeft + glyphSize - 4, bottom: glyphTop + 6), color: colorRef(red: 0.95, green: 0.95, blue: 0.92), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 2, top: glyphTop + 6, right: glyphLeft + glyphSize - 2, bottom: glyphTop + glyphSize - 4), color: colorRef(red: 0.30, green: 0.32, blue: 0.35), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 4, top: glyphTop + glyphSize - 8, right: glyphLeft + glyphSize - 4, bottom: glyphTop + glyphSize - 1), color: colorRef(red: 0.97, green: 0.97, blue: 0.94), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + glyphSize - 5, top: glyphTop + 8, right: glyphLeft + glyphSize - 3, bottom: glyphTop + 10), color: colorRef(red: 0.30, green: 0.62, blue: 0.86), deviceContext: deviceContext)
    }

    private func drawPropertiesGlyph(left glyphLeft: Int32, top glyphTop: Int32, size glyphSize: Int32, deviceContext: HDC?) {
        let edge = colorRef(red: 0.35, green: 0.40, blue: 0.48)
        let sheet = colorRef(red: 0.91, green: 0.94, blue: 0.97)
        let header = colorRef(red: 0.36, green: 0.55, blue: 0.75)
        let line = colorRef(red: 0.50, green: 0.56, blue: 0.62)
        fillRect(RECT(left: glyphLeft + 3, top: glyphTop + 1, right: glyphLeft + glyphSize - 3, bottom: glyphTop + glyphSize), color: edge, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 4, top: glyphTop + 2, right: glyphLeft + glyphSize - 4, bottom: glyphTop + glyphSize - 1), color: sheet, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 5, top: glyphTop + 4, right: glyphLeft + glyphSize - 5, bottom: glyphTop + 7), color: header, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 6, top: glyphTop + 9, right: glyphLeft + glyphSize - 6, bottom: glyphTop + 10), color: line, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 6, top: glyphTop + 12, right: glyphLeft + glyphSize - 8, bottom: glyphTop + 13), color: line, deviceContext: deviceContext)
    }

    private func drawTrashGlyph(left glyphLeft: Int32, top glyphTop: Int32, size glyphSize: Int32, deviceContext: HDC?) {
        fillRect(RECT(left: glyphLeft + 5, top: glyphTop + 2, right: glyphLeft + glyphSize - 5, bottom: glyphTop + 4), color: colorRef(red: 0.35, green: 0.37, blue: 0.40), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 3, top: glyphTop + 5, right: glyphLeft + glyphSize - 3, bottom: glyphTop + 7), color: colorRef(red: 0.45, green: 0.47, blue: 0.50), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 4, top: glyphTop + 7, right: glyphLeft + glyphSize - 4, bottom: glyphTop + glyphSize - 1), color: colorRef(red: 0.76, green: 0.78, blue: 0.80), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 7, top: glyphTop + 8, right: glyphLeft + 8, bottom: glyphTop + glyphSize - 2), color: colorRef(red: 0.50, green: 0.52, blue: 0.55), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + glyphSize - 8, top: glyphTop + 8, right: glyphLeft + glyphSize - 7, bottom: glyphTop + glyphSize - 2), color: colorRef(red: 0.50, green: 0.52, blue: 0.55), deviceContext: deviceContext)
    }

    private func drawSearchGlyph(left glyphLeft: Int32, top glyphTop: Int32, size glyphSize: Int32, deviceContext: HDC?) {
        let glass = colorRef(red: 0.45, green: 0.68, blue: 0.88)
        let rim = colorRef(red: 0.18, green: 0.32, blue: 0.48)
        fillRect(RECT(left: glyphLeft + 3, top: glyphTop + 3, right: glyphLeft + glyphSize - 6, bottom: glyphTop + glyphSize - 6), color: rim, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 5, top: glyphTop + 5, right: glyphLeft + glyphSize - 8, bottom: glyphTop + glyphSize - 8), color: glass, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + glyphSize - 7, top: glyphTop + glyphSize - 7, right: glyphLeft + glyphSize - 2, bottom: glyphTop + glyphSize - 4), color: rim, deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + glyphSize - 5, top: glyphTop + glyphSize - 5, right: glyphLeft + glyphSize - 2, bottom: glyphTop + glyphSize - 2), color: rim, deviceContext: deviceContext)
    }

    private func drawPlusGlyph(left glyphLeft: Int32, top glyphTop: Int32, size glyphSize: Int32, deviceContext: HDC?) {
        drawDocumentGlyph(left: glyphLeft, top: glyphTop, size: glyphSize, accent: colorRef(red: 0.31, green: 0.62, blue: 0.36), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + glyphSize - 7, top: glyphTop + glyphSize - 10, right: glyphLeft + glyphSize - 4, bottom: glyphTop + glyphSize - 3), color: colorRef(red: 0.16, green: 0.56, blue: 0.20), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + glyphSize - 9, top: glyphTop + glyphSize - 8, right: glyphLeft + glyphSize - 2, bottom: glyphTop + glyphSize - 5), color: colorRef(red: 0.16, green: 0.56, blue: 0.20), deviceContext: deviceContext)
    }

    private func drawSeparatorGlyph(left glyphLeft: Int32, top glyphTop: Int32, size glyphSize: Int32, deviceContext: HDC?) {
        let center = glyphLeft + glyphSize / 2
        fillRect(RECT(left: center - 1, top: glyphTop + 1, right: center, bottom: glyphTop + glyphSize - 1), color: colorRef(red: 0.52, green: 0.55, blue: 0.58), deviceContext: deviceContext)
        fillRect(RECT(left: center, top: glyphTop + 1, right: center + 1, bottom: glyphTop + glyphSize - 1), color: colorRef(red: 1.0, green: 1.0, blue: 1.0), deviceContext: deviceContext)
    }

    private func drawSpaceGlyph(left glyphLeft: Int32, top glyphTop: Int32, size glyphSize: Int32, deviceContext: HDC?) {
        let y = glyphTop + glyphSize / 2
        fillRect(RECT(left: glyphLeft + 3, top: y, right: glyphLeft + glyphSize - 3, bottom: y + 1), color: colorRef(red: 0.62, green: 0.65, blue: 0.68), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 3, top: y - 3, right: glyphLeft + 4, bottom: y + 4), color: colorRef(red: 0.62, green: 0.65, blue: 0.68), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + glyphSize - 4, top: y - 3, right: glyphLeft + glyphSize - 3, bottom: y + 4), color: colorRef(red: 0.62, green: 0.65, blue: 0.68), deviceContext: deviceContext)
    }

    private func drawFlexibleSpaceGlyph(left glyphLeft: Int32, top glyphTop: Int32, size glyphSize: Int32, deviceContext: HDC?) {
        let y = glyphTop + glyphSize / 2
        fillRect(RECT(left: glyphLeft + 2, top: y, right: glyphLeft + glyphSize - 2, bottom: y + 1), color: colorRef(red: 0.35, green: 0.45, blue: 0.58), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 2, top: y - 2, right: glyphLeft + 5, bottom: y + 3), color: colorRef(red: 0.35, green: 0.45, blue: 0.58), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + glyphSize - 5, top: y - 2, right: glyphLeft + glyphSize - 2, bottom: y + 3), color: colorRef(red: 0.35, green: 0.45, blue: 0.58), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + 6, top: y - 1, right: glyphLeft + 8, bottom: y + 2), color: colorRef(red: 0.82, green: 0.87, blue: 0.94), deviceContext: deviceContext)
        fillRect(RECT(left: glyphLeft + glyphSize - 8, top: y - 1, right: glyphLeft + glyphSize - 6, bottom: y + 2), color: colorRef(red: 0.82, green: 0.87, blue: 0.94), deviceContext: deviceContext)
    }

    private func fillRect(_ rectangle: RECT, color: DWORD, deviceContext: HDC?) {
        guard let brush = winCreateSolidBrush(color) else {
            return
        }
        defer {
            _ = winDeleteObject(brush)
        }

        withUnsafePointer(to: rectangle) { rectanglePointer in
            _ = winFillRect(deviceContext, rectanglePointer, brush)
        }
    }

    private func toolbarGlyphColor(for label: String) -> DWORD {
        let palette: [DWORD] = [
            colorRef(red: 0.24, green: 0.48, blue: 0.82),
            colorRef(red: 0.25, green: 0.58, blue: 0.43),
            colorRef(red: 0.68, green: 0.39, blue: 0.22),
            colorRef(red: 0.54, green: 0.42, blue: 0.72),
            colorRef(red: 0.63, green: 0.47, blue: 0.20),
            colorRef(red: 0.30, green: 0.55, blue: 0.64)
        ]
        let value = label.unicodeScalars.reduce(0) { partial, scalar in
            partial &+ Int(scalar.value)
        }
        return palette[value % palette.count]
    }

    private func colorRef(from color: NSColor) -> DWORD {
        colorRef(red: color.redComponent, green: color.greenComponent, blue: color.blueComponent)
    }

    private func colorRef(red redComponent: CGFloat, green greenComponent: CGFloat, blue blueComponent: CGFloat) -> DWORD {
        let red = DWORD((min(max(redComponent, 0), 1) * 255).rounded()) & 0xff
        let green = DWORD((min(max(greenComponent, 0), 1) * 255).rounded()) & 0xff
        let blue = DWORD((min(max(blueComponent, 0), 1) * 255).rounded()) & 0xff
        return red | (green << 8) | (blue << 16)
    }

    private func systemTime(from date: Date) -> SYSTEMTIME {
        let components = dateComponents(from: date)
        return SYSTEMTIME(
            wYear: UInt16(components.year),
            wMonth: UInt16(components.month),
            wDayOfWeek: 0,
            wDay: UInt16(components.day),
            wHour: 0,
            wMinute: 0,
            wSecond: 0,
            wMilliseconds: 0
        )
    }

    private func date(from systemTime: SYSTEMTIME) -> Date {
        let days = daysFromCivil(
            year: Int(systemTime.wYear),
            month: Int(systemTime.wMonth),
            day: Int(systemTime.wDay)
        )
        let seconds = Double(days) * 86_400.0
        return Date(timeIntervalSince1970: seconds)
    }

    private func dateComponents(from date: Date) -> (year: Int, month: Int, day: Int) {
        let days = Int((date.timeIntervalSince1970 / 86_400.0).rounded(.down))
        let z = days + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365
        var year = yoe + era * 400
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let day = doy - (153 * mp + 2) / 5 + 1
        let month = mp + (mp < 10 ? 3 : -9)
        year += month <= 2 ? 1 : 0
        return (year, month, day)
    }

    private func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        var adjustedYear = year
        adjustedYear -= month <= 2 ? 1 : 0
        let era = (adjustedYear >= 0 ? adjustedYear : adjustedYear - 399) / 400
        let yoe = adjustedYear - era * 400
        let adjustedMonth = month + (month > 2 ? -3 : 9)
        let doy = (153 * adjustedMonth + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
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
        if let bitmap = bitmaps.removeValue(forKey: handle.rawValue) {
            if let hwnd = hwnd(from: handle) {
                _ = winSendMessageW(hwnd, stmSetImage, WPARAM(imageBitmap), 0)
            }
            _ = winDeleteObject(bitmap)
        }
    }

    private func point(from lParam: LPARAM) -> NSPoint {
        let x = Int16(bitPattern: UInt16(lParam & 0xffff))
        let y = Int16(bitPattern: UInt16((lParam >> 16) & 0xffff))
        return NSMakePoint(CGFloat(x), CGFloat(y))
    }

    private func mouseLocation(from lParam: LPARAM, in hwnd: HWND?) -> NSPoint {
        let localPoint = point(from: lParam)
        guard let hwnd else {
            return localPoint
        }

        var screenPoint = POINT(x: Int32(localPoint.x), y: Int32(localPoint.y))
        _ = winClientToScreen(hwnd, &screenPoint)

        if let rootWindow = rootWindow(for: hwnd) {
            _ = winScreenToClient(rootWindow, &screenPoint)
        }

        return NSMakePoint(CGFloat(screenPoint.x), CGFloat(screenPoint.y))
    }

    private func rootWindow(for hwnd: HWND) -> HWND? {
        var candidate: HWND? = hwnd
        while let current = candidate {
            guard let parent = winGetParent(current) else {
                return current
            }
            candidate = parent
        }
        return nil
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

    private func actionHandle(from hwnd: HWND) -> NativeHandle {
        controlHandleAliases[UInt(bitPattern: hwnd)] ?? nativeHandle(from: hwnd)
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
