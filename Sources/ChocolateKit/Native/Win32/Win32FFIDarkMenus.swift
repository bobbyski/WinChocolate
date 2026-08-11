#if os(Windows)
// MARK: - Dark menu-bar owner draw (undocumented UAH messages)

/// `WM_UAHDRAWMENU`: sent to draw the menu-bar background.
let wmUAHDrawMenu: UINT = 0x0091
/// `WM_UAHDRAWMENUITEM`: sent to draw one menu-bar item.
let wmUAHDrawMenuItem: UINT = 0x0092

/// The `DRAWITEMSTRUCT` layout embedded in `UAHDRAWMENUITEM`.
struct DRAWITEMSTRUCT {
    var CtlType: UINT = 0
    var CtlID: UINT = 0
    var itemID: UINT = 0
    var itemAction: UINT = 0
    var itemState: UINT = 0
    var hwndItem: HWND?
    var hDC: HDC?
    var rcItem: RECT = RECT()
    var itemData: UInt = 0
}

/// `UAHMENU` (undocumented): the menu and DC for a UAH draw message.
///
/// The trailing padding field is load-bearing: C sizes this struct to 24
/// bytes (8-byte alignment), but Swift lays out an embedded struct by its
/// 20-byte *size*, which would shift every `UAHMENUITEM` field that follows
/// it in `UAHDRAWMENUITEM` by 4 bytes (the "every menu item draws the first
/// title" bug).
struct UAHMENU {
    var hmenu: HMENU?
    var hdc: HDC?
    var dwFlags: DWORD = 0
    var winTailPadding: DWORD = 0
}

/// `UAHMENUITEMMETRICS` (undocumented): four size pairs.
struct UAHMENUITEMMETRICS {
    var rgSizes = WinDWORDBuffer8()
}

/// `UAHMENUPOPUPMETRICS` (undocumented).
struct UAHMENUPOPUPMETRICS {
    var rgcx = WinDWORDBuffer4()
    var fUpdateMaxWidths: DWORD = 0
}

/// `UAHMENUITEM` (undocumented): the item position and metrics.
struct UAHMENUITEM {
    var iPosition: Int32 = 0
    var umim = UAHMENUITEMMETRICS()
    var umpm = UAHMENUPOPUPMETRICS()
}

/// `UAHDRAWMENUITEM` (undocumented): the `WM_UAHDRAWMENUITEM` payload.
struct UAHDRAWMENUITEM {
    var dis = DRAWITEMSTRUCT()
    var um = UAHMENU()
    var umi = UAHMENUITEM()
}

/// `MENUBARINFO` for `GetMenuBarInfo`.
struct MENUBARINFO {
    var cbSize: DWORD = 0
    var rcBar: RECT = RECT()
    var hMenu: HMENU?
    var hwndMenu: HWND?
    var fFlags: DWORD = 0
}

/// `OBJID_MENU` for `GetMenuBarInfo`.
let winObjIdMenu: Int32 = -3

@_silgen_name("GetMenuBarInfo")
func winGetMenuBarInfo(_ hwnd: HWND?, _ idObject: Int32, _ idItem: Int32, _ info: UnsafeMutablePointer<MENUBARINFO>) -> Int32

@_silgen_name("GetMenuStringW")
func winGetMenuStringW(_ menu: HMENU?, _ item: UINT, _ buffer: UnsafeMutablePointer<UInt16>?, _ maxCount: Int32, _ flags: UINT) -> Int32

@_silgen_name("GetWindowDC")
func winGetWindowDC(_ hwnd: HWND?) -> HDC?

// Owner-draw item states used by the dark menu bar.
let odsSelected: UINT = 0x0001
let odsGrayed: UINT = 0x0002
let odsHotlight: UINT = 0x0040
let odsInactive: UINT = 0x0080
let odsNoAccel: UINT = 0x0100

/// `DT_HIDEPREFIX` for `DrawTextW`.
let dtHidePrefix: UINT = 0x0010_0000

/// `WM_NCPAINT` / `WM_NCACTIVATE` — intercepted under dark to cover the
/// light line the non-client paint leaves under the owner-drawn menu bar.
let wmNcPaint: UINT = 0x0085
let wmNcActivate: UINT = 0x0086

@_silgen_name("MapWindowPoints")
func winMapWindowPoints(_ from: HWND?, _ to: HWND?, _ points: UnsafeMutableRawPointer?, _ count: UINT) -> Int32

let smCxScreen: Int32 = 0
let smCyScreen: Int32 = 1

let scClose: UINT = 0xF060
let mfByCommand: UINT = 0x0000

@_silgen_name("CheckMenuItem")
func winCheckMenuItem(_ menu: HMENU?, _ identifier: UINT, _ flags: UINT) -> DWORD

@_silgen_name("GetDC")
func winGetDC(_ hwnd: HWND?) -> HDC?

@_silgen_name("ReleaseDC")
func winReleaseDC(_ hwnd: HWND?, _ deviceContext: HDC?) -> Int32

@_silgen_name("GetTextExtentPoint32W")
func winGetTextExtentPoint32W(_ deviceContext: HDC?, _ text: UnsafePointer<UInt16>?, _ count: Int32, _ size: UnsafeMutablePointer<SIZE>) -> Int32

@_silgen_name("InitCommonControlsEx")
func winInitCommonControlsEx(_ initControls: UnsafePointer<INITCOMMONCONTROLSEX>) -> Int32

@_silgen_name("AppendMenuW")
func winAppendMenuW(_ menu: HMENU?, _ flags: UINT, _ identifier: UInt, _ title: UnsafePointer<UInt16>?) -> Int32

@_silgen_name("CreateMenu")
func winCreateMenu() -> HMENU?

@_silgen_name("GetMenuItemCount")
func winGetMenuItemCount(_ menu: HMENU?) -> Int32

@_silgen_name("GetSubMenu")
func winGetSubMenu(_ menu: HMENU?, _ position: Int32) -> HMENU?

@_silgen_name("DeleteMenu")
func winDeleteMenu(_ menu: HMENU?, _ position: UINT, _ flags: UINT) -> Int32

@_silgen_name("CreatePopupMenu")
func winCreatePopupMenu() -> HMENU?

@_silgen_name("CreateSolidBrush")
func winCreateSolidBrush(_ color: DWORD) -> HBRUSH?

@_silgen_name("CreatePen")
func winCreatePen(_ style: Int32, _ width: Int32, _ color: DWORD) -> HGDIOBJ?

@_silgen_name("BeginPath")
func winBeginPath(_ deviceContext: HDC?) -> Int32

@_silgen_name("EndPath")
func winEndPath(_ deviceContext: HDC?) -> Int32

@_silgen_name("FillPath")
func winFillPath(_ deviceContext: HDC?) -> Int32

@_silgen_name("StrokePath")
func winStrokePath(_ deviceContext: HDC?) -> Int32

@_silgen_name("CloseFigure")
func winCloseFigure(_ deviceContext: HDC?) -> Int32

@_silgen_name("MoveToEx")
func winMoveToEx(_ deviceContext: HDC?, _ x: Int32, _ y: Int32, _ previousPoint: UnsafeMutablePointer<POINT>?) -> Int32

@_silgen_name("LineTo")
func winLineTo(_ deviceContext: HDC?, _ x: Int32, _ y: Int32) -> Int32

@_silgen_name("PolyBezierTo")
func winPolyBezierTo(_ deviceContext: HDC?, _ points: UnsafePointer<POINT>?, _ count: DWORD) -> Int32

@_silgen_name("SetPolyFillMode")
func winSetPolyFillMode(_ deviceContext: HDC?, _ mode: Int32) -> Int32

@_silgen_name("WindowFromPoint")
func winWindowFromPoint(_ point: POINT) -> HWND?

@_silgen_name("SetTimer")
func winSetTimer(_ hwnd: HWND?, _ identifier: UInt, _ elapseMilliseconds: UINT, _ timerProc: UnsafeMutableRawPointer?) -> UInt

@_silgen_name("SetTimer")
func winSetTimerWithProcedure(_ hwnd: HWND?, _ identifier: UInt, _ elapseMilliseconds: UINT, _ timerProc: @convention(c) (HWND?, UINT, UInt, DWORD) -> Void) -> UInt

@_silgen_name("KillTimer")
func winKillTimer(_ hwnd: HWND?, _ identifier: UInt) -> Int32


@_silgen_name("CallWindowProcW")
func winCallWindowProcW(_ previousProcedure: WNDPROC?, _ hwnd: HWND?, _ message: UINT, _ wParam: WPARAM, _ lParam: LPARAM) -> LRESULT

@_silgen_name("SendMessageW")
func winSendMessageW(_ hwnd: HWND?, _ message: UINT, _ wParam: WPARAM, _ lParam: LPARAM) -> LRESULT

@_silgen_name("SelectObject")
func winSelectObject(_ deviceContext: HDC?, _ object: HGDIOBJ?) -> HGDIOBJ?

@_silgen_name("SetScrollInfo")
func winSetScrollInfo(_ hwnd: HWND?, _ bar: Int32, _ scrollInfo: UnsafePointer<SCROLLINFO>, _ redraw: Int32) -> Int32

@_silgen_name("GetScrollInfo")
func winGetScrollInfo(_ hwnd: HWND?, _ bar: Int32, _ scrollInfo: UnsafeMutablePointer<SCROLLINFO>) -> Int32

@_silgen_name("DefWindowProcW")
func winDefWindowProcW(_ hwnd: HWND?, _ message: UINT, _ wParam: WPARAM, _ lParam: LPARAM) -> LRESULT

@_silgen_name("DestroyWindow")
func winDestroyWindow(_ hwnd: HWND?) -> Int32

@_silgen_name("DeleteObject")
func winDeleteObject(_ object: HGDIOBJ?) -> Int32

@_silgen_name("EnableWindow")
func winEnableWindow(_ hwnd: HWND?, _ enable: Int32) -> Int32

@_silgen_name("AnimateWindow")
func winAnimateWindow(_ hwnd: HWND?, _ time: UInt32, _ flags: UInt32) -> Int32

/// Fade the window using an alpha blend.
let awBlend: UInt32 = 0x0008_0000
/// Hide the window as the animation finishes.
let awHide: UInt32 = 0x0001_0000

@_silgen_name("DispatchMessageW")
func winDispatchMessageW(_ message: UnsafePointer<MSG>) -> LRESULT

@_silgen_name("DrawMenuBar")
func winDrawMenuBar(_ hwnd: HWND?) -> Int32

@_silgen_name("ClientToScreen")
func winClientToScreen(_ hwnd: HWND?, _ point: UnsafeMutablePointer<POINT>?) -> Int32

@_silgen_name("BeginPaint")
func winBeginPaint(_ hwnd: HWND?, _ paint: UnsafeMutablePointer<PAINTSTRUCT>?) -> HDC?

@_silgen_name("EndPaint")
func winEndPaint(_ hwnd: HWND?, _ paint: UnsafePointer<PAINTSTRUCT>?) -> Int32

@_silgen_name("DrawTextW")
func winDrawTextW(_ deviceContext: HDC?, _ text: UnsafePointer<UInt16>?, _ count: Int32, _ rectangle: UnsafeMutablePointer<RECT>?, _ format: UINT) -> Int32


@_silgen_name("FillRect")
func winFillRect(_ deviceContext: HDC?, _ rectangle: UnsafePointer<RECT>?, _ brush: HBRUSH?) -> Int32

@_silgen_name("GetClientRect")
func winGetClientRect(_ hwnd: HWND?, _ rectangle: UnsafeMutablePointer<RECT>?) -> Int32

@_silgen_name("GetMessageW")
func winGetMessageW(_ message: UnsafeMutablePointer<MSG>, _ hwnd: HWND?, _ minimumMessage: UINT, _ maximumMessage: UINT) -> Int32

@_silgen_name("PeekMessageW")
func winPeekMessageW(_ message: UnsafeMutablePointer<MSG>, _ hwnd: HWND?, _ minimumMessage: UINT, _ maximumMessage: UINT, _ removeMessage: UINT) -> Int32

@_silgen_name("MsgWaitForMultipleObjects")
func winMsgWaitForMultipleObjects(_ count: DWORD, _ handles: UnsafePointer<UnsafeMutableRawPointer?>?, _ waitAll: Int32, _ milliseconds: DWORD, _ wakeMask: DWORD) -> DWORD

@_silgen_name("PostThreadMessageW")
func winPostThreadMessageW(_ threadId: DWORD, _ message: UINT, _ wParam: WPARAM, _ lParam: LPARAM) -> Int32

/// `PM_REMOVE` — dequeue the peeked message.
let pmRemove: UINT = 0x0001
/// `QS_ALLINPUT` — wake on any queued input.
let qsAllInput: DWORD = 0x04FF
/// Wait-forever timeout for `MsgWaitForMultipleObjects`.
let infiniteTimeout: DWORD = 0xFFFF_FFFF
/// `WM_QUIT` / `WM_NULL`.
let wmQuit: UINT = 0x0012
let wmNull: UINT = 0x0000

@_silgen_name("GetParent")
func winGetParent(_ hwnd: HWND?) -> HWND?

@_silgen_name("GetStockObject")
func winGetStockObject(_ object: Int32) -> HGDIOBJ?

@_silgen_name("GetModuleHandleW")
func winGetModuleHandleW(_ moduleName: UnsafePointer<UInt16>?) -> HINSTANCE?

@_silgen_name("GetLastError")
func winGetLastError() -> DWORD

@_silgen_name("GetKeyState")
func winGetKeyState(_ virtualKey: Int32) -> Int16

@_silgen_name("GetCursorPos")
func winGetCursorPos(_ point: UnsafeMutablePointer<POINT>?) -> Int32

@_silgen_name("GetWindowTextLengthW")
func winGetWindowTextLengthW(_ hwnd: HWND?) -> Int32

@_silgen_name("GetWindowTextW")
func winGetWindowTextW(_ hwnd: HWND?, _ text: UnsafeMutablePointer<UInt16>?, _ maximumCount: Int32) -> Int32

@_silgen_name("GetWindow")
func winGetWindow(_ hwnd: HWND?, _ command: UINT) -> HWND?

@_silgen_name("IsWindow")
func winIsWindow(_ hwnd: HWND?) -> Int32

@_silgen_name("InvalidateRect")
func winInvalidateRect(_ hwnd: HWND?, _ rectangle: UnsafePointer<RECT>?, _ erase: Int32) -> Int32

@_silgen_name("LoadCursorW")
func winLoadCursorW(_ instance: HINSTANCE?, _ cursorName: UnsafePointer<UInt16>?) -> HCURSOR?

@_silgen_name("SetCursor")
func winSetCursor(_ cursor: HCURSOR?) -> HCURSOR?


@_silgen_name("DestroyMenu")
func winDestroyMenu(_ menu: HMENU?) -> Int32


@_silgen_name("MessageBoxW")
func winMessageBoxW(
    _ hwnd: HWND?,
    _ text: UnsafePointer<UInt16>?,
    _ caption: UnsafePointer<UInt16>?,
    _ type: UINT
) -> Int32

@_silgen_name("GetOpenFileNameW")
func winGetOpenFileNameW(_ descriptor: UnsafeMutablePointer<OPENFILENAMEW>) -> Int32

@_silgen_name("GetSaveFileNameW")
func winGetSaveFileNameW(_ descriptor: UnsafeMutablePointer<OPENFILENAMEW>) -> Int32

@_silgen_name("ChooseColorW")
func winChooseColorW(_ descriptor: UnsafeMutablePointer<CHOOSECOLORW>) -> Int32

@_silgen_name("ChooseFontW")
func winChooseFontW(_ descriptor: UnsafeMutablePointer<CHOOSEFONTW>) -> Int32

@_silgen_name("SHBrowseForFolderW")
func winSHBrowseForFolderW(_ browseInfo: UnsafeMutablePointer<BROWSEINFOW>) -> UnsafeMutableRawPointer?

@_silgen_name("SHGetPathFromIDListW")
func winSHGetPathFromIDListW(
    _ itemIDList: UnsafeMutableRawPointer?,
    _ path: UnsafeMutablePointer<UInt16>?
) -> Int32

@_silgen_name("CoTaskMemFree")
func winCoTaskMemFree(_ pointer: UnsafeMutableRawPointer?)

@_silgen_name("CoInitializeEx")
func winCoInitializeEx(_ reserved: UnsafeMutableRawPointer?, _ concurrencyModel: DWORD) -> Int32

@_silgen_name("PostQuitMessage")
func winPostQuitMessage(_ exitCode: Int32)

@_silgen_name("PostMessageW")
func winPostMessageW(_ hwnd: HWND?, _ message: UINT, _ wParam: WPARAM, _ lParam: LPARAM) -> Int32

@_silgen_name("RegisterClassW")
func winRegisterClassW(_ windowClass: UnsafePointer<WNDCLASSW>) -> UInt16

@_silgen_name("SetMenu")
func winSetMenu(_ hwnd: HWND?, _ menu: HMENU?) -> Int32

@_silgen_name("SetBkColor")
func winSetBkColor(_ deviceContext: HDC?, _ color: DWORD) -> DWORD

@_silgen_name("SetBkMode")
func winSetBkMode(_ deviceContext: HDC?, _ backgroundMode: Int32) -> Int32

@_silgen_name("ScreenToClient")
func winScreenToClient(_ hwnd: HWND?, _ point: UnsafeMutablePointer<POINT>?) -> Int32

@_silgen_name("SetCapture")
func winSetCapture(_ hwnd: HWND?) -> HWND?

@_silgen_name("ReleaseCapture")
func winReleaseCapture() -> Int32

@_silgen_name("SetTextColor")
func winSetTextColor(_ deviceContext: HDC?, _ color: DWORD) -> DWORD

@_silgen_name("SetFocus")
func winSetFocus(_ hwnd: HWND?) -> HWND?

@_silgen_name("GetFocus")
func winGetFocus() -> HWND?

@_silgen_name("SetWindowLongPtrW")
func winSetWindowLongPtrW(_ hwnd: HWND?, _ index: Int32, _ newLong: LONG_PTR) -> LONG_PTR

@_silgen_name("GetWindowLongPtrW")
func winGetWindowLongPtrW(_ hwnd: HWND?, _ index: Int32) -> LONG_PTR

@_silgen_name("IsWindowVisible")
func winIsWindowVisible(_ hwnd: HWND?) -> Int32

@_silgen_name("LoadLibraryW")
func winLoadLibraryW(_ name: UnsafePointer<UInt16>?) -> UnsafeMutableRawPointer?

@_silgen_name("GetProcAddress")
func winGetProcAddress(_ module: UnsafeMutableRawPointer?, _ name: UnsafePointer<CChar>?) -> UnsafeMutableRawPointer?

@_silgen_name("OpenClipboard")
func winOpenClipboard(_ owner: HWND?) -> Int32

@_silgen_name("CloseClipboard")
func winCloseClipboard() -> Int32

@_silgen_name("EmptyClipboard")
func winEmptyClipboard() -> Int32

@_silgen_name("SetClipboardData")
func winSetClipboardData(_ format: UINT, _ data: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?

@_silgen_name("GetClipboardData")
func winGetClipboardData(_ format: UINT) -> UnsafeMutableRawPointer?

@_silgen_name("IsClipboardFormatAvailable")
func winIsClipboardFormatAvailable(_ format: UINT) -> Int32

@_silgen_name("GetClipboardSequenceNumber")
func winGetClipboardSequenceNumber() -> DWORD

@_silgen_name("RegisterClipboardFormatW")
func winRegisterClipboardFormatW(_ name: UnsafePointer<UInt16>?) -> UINT

@_silgen_name("GlobalSize")
func winGlobalSize(_ memory: UnsafeMutableRawPointer?) -> UInt

@_silgen_name("GlobalAlloc")
func winGlobalAlloc(_ flags: UINT, _ bytes: UInt) -> UnsafeMutableRawPointer?

@_silgen_name("GlobalLock")
func winGlobalLock(_ memory: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?

@_silgen_name("GlobalUnlock")
func winGlobalUnlock(_ memory: UnsafeMutableRawPointer?) -> Int32

@_silgen_name("GlobalFree")
func winGlobalFree(_ memory: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?

@_silgen_name("SetGraphicsMode")
func winSetGraphicsMode(_ deviceContext: HDC?, _ mode: Int32) -> Int32

#endif
