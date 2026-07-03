//  Win32FFI.swift
//
//  The manually-declared Win32 FFI surface for the WinChocolate native backend.
//  The toolchain cannot import WinSDK, so the Win32 typealiases, C struct
//  layouts, function declarations, and message/style constants used by
//  Win32NativeControlBackend are declared by hand here, along with the
//  wide-string bridging helpers.

#if os(Windows)
typealias HWND = UnsafeMutableRawPointer
typealias HMENU = UnsafeMutableRawPointer
typealias HINSTANCE = UnsafeMutableRawPointer
typealias HBRUSH = UnsafeMutableRawPointer
typealias HCURSOR = UnsafeMutableRawPointer
typealias HDC = UnsafeMutableRawPointer
typealias HFONT = UnsafeMutableRawPointer
typealias HGDIOBJ = UnsafeMutableRawPointer
typealias HBITMAP = UnsafeMutableRawPointer
typealias HIMAGELIST = UnsafeMutableRawPointer
typealias UINT = UInt32
typealias DWORD = UInt32
typealias WPARAM = UInt
typealias LPARAM = Int
typealias LRESULT = Int
typealias LONG_PTR = Int
typealias WNDPROC = @convention(c) (HWND?, UINT, WPARAM, LPARAM) -> LRESULT

struct POINT {
    var x: Int32 = 0
    var y: Int32 = 0
}

struct MSG {
    var hwnd: HWND?
    var message: UINT = 0
    var wParam: WPARAM = 0
    var lParam: LPARAM = 0
    var time: DWORD = 0
    var pt: POINT = POINT()
}

struct OPENFILENAMEW {
    var lStructSize: DWORD = 0
    var hwndOwner: HWND? = nil
    var hInstance: HINSTANCE? = nil
    var lpstrFilter: UnsafePointer<UInt16>? = nil
    var lpstrCustomFilter: UnsafeMutablePointer<UInt16>? = nil
    var nMaxCustFilter: DWORD = 0
    var nFilterIndex: DWORD = 0
    var lpstrFile: UnsafeMutablePointer<UInt16>? = nil
    var nMaxFile: DWORD = 0
    var lpstrFileTitle: UnsafeMutablePointer<UInt16>? = nil
    var nMaxFileTitle: DWORD = 0
    var lpstrInitialDir: UnsafePointer<UInt16>? = nil
    var lpstrTitle: UnsafePointer<UInt16>? = nil
    var flags: DWORD = 0
    var nFileOffset: UInt16 = 0
    var nFileExtension: UInt16 = 0
    var lpstrDefExt: UnsafePointer<UInt16>? = nil
    var lCustData: LPARAM = 0
    var lpfnHook: UnsafeMutableRawPointer? = nil
    var lpTemplateName: UnsafePointer<UInt16>? = nil
    var pvReserved: UnsafeMutableRawPointer? = nil
    var dwReserved: DWORD = 0
    var flagsEx: DWORD = 0
}

struct CHOOSECOLORW {
    var lStructSize: DWORD = 0
    var hwndOwner: HWND? = nil
    var hInstance: UnsafeMutableRawPointer? = nil
    var rgbResult: DWORD = 0
    var lpCustColors: UnsafeMutablePointer<DWORD>? = nil
    var Flags: DWORD = 0
    var lCustData: LPARAM = 0
    var lpfnHook: UnsafeMutableRawPointer? = nil
    var lpTemplateName: UnsafePointer<UInt16>? = nil
}

struct LOGFONTW {
    var lfHeight: Int32 = 0
    var lfWidth: Int32 = 0
    var lfEscapement: Int32 = 0
    var lfOrientation: Int32 = 0
    var lfWeight: Int32 = 0
    var lfItalic: UInt8 = 0
    var lfUnderline: UInt8 = 0
    var lfStrikeOut: UInt8 = 0
    var lfCharSet: UInt8 = 0
    var lfOutPrecision: UInt8 = 0
    var lfClipPrecision: UInt8 = 0
    var lfQuality: UInt8 = 0
    var lfPitchAndFamily: UInt8 = 0
    var lfFaceName: (
        UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16,
        UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16,
        UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16,
        UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16
    ) = (
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    )
}

struct CHOOSEFONTW {
    var lStructSize: DWORD = 0
    var hwndOwner: HWND? = nil
    var hDC: HDC? = nil
    var lpLogFont: UnsafeMutablePointer<LOGFONTW>? = nil
    var iPointSize: Int32 = 0
    var Flags: DWORD = 0
    var rgbColors: DWORD = 0
    var lCustData: LPARAM = 0
    var lpfnHook: UnsafeMutableRawPointer? = nil
    var lpTemplateName: UnsafePointer<UInt16>? = nil
    var hInstance: HINSTANCE? = nil
    var lpszStyle: UnsafeMutablePointer<UInt16>? = nil
    var nFontType: UInt16 = 0
    var alignmentPadding: UInt16 = 0
    var nSizeMin: Int32 = 0
    var nSizeMax: Int32 = 0
}

struct BROWSEINFOW {
    var hwndOwner: HWND? = nil
    var pidlRoot: UnsafeMutableRawPointer? = nil
    var pszDisplayName: UnsafeMutablePointer<UInt16>? = nil
    var lpszTitle: UnsafePointer<UInt16>? = nil
    var ulFlags: UINT = 0
    var lpfn: UnsafeMutableRawPointer? = nil
    var lParam: LPARAM = 0
    var iImage: Int32 = 0
}

struct WNDCLASSW {
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

struct RECT {
    var left: Int32 = 0
    var top: Int32 = 0
    var right: Int32 = 0
    var bottom: Int32 = 0
}

struct PAINTSTRUCT {
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

struct SIZE {
    var cx: Int32 = 0
    var cy: Int32 = 0
}

struct INITCOMMONCONTROLSEX {
    var dwSize: DWORD = 0
    var dwICC: DWORD = 0
}

struct SYSTEMTIME {
    var wYear: UInt16 = 0
    var wMonth: UInt16 = 0
    var wDayOfWeek: UInt16 = 0
    var wDay: UInt16 = 0
    var wHour: UInt16 = 0
    var wMinute: UInt16 = 0
    var wSecond: UInt16 = 0
    var wMilliseconds: UInt16 = 0
}

struct SCROLLINFO {
    var cbSize: UINT = UINT(MemoryLayout<SCROLLINFO>.size)
    var fMask: UINT = 0
    var nMin: Int32 = 0
    var nMax: Int32 = 0
    var nPage: UINT = 0
    var nPos: Int32 = 0
    var nTrackPos: Int32 = 0
}

struct NMHDR {
    var hwndFrom: HWND?
    var idFrom: UInt = 0
    var code: UINT = 0
}

struct NMLISTVIEW {
    var hdr: NMHDR = NMHDR()
    var iItem: Int32 = 0
    var iSubItem: Int32 = 0
    var uNewState: UINT = 0
    var uOldState: UINT = 0
    var uChanged: UINT = 0
    var ptAction: POINT = POINT()
    var lParam: LPARAM = 0
}

struct NMHEADERW {
    var hdr: NMHDR = NMHDR()
    var iItem: Int32 = 0
    var iButton: Int32 = 0
    var pItem: UnsafeMutableRawPointer?
}

struct NMUPDOWN {
    var hdr: NMHDR = NMHDR()
    var iPos: Int32 = 0
    var iDelta: Int32 = 0
}

struct HDHITTESTINFO {
    var pt: POINT = POINT()
    var flags: UINT = 0
    var iItem: Int32 = 0
}

struct LVCOLUMNW {
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

struct LVITEMW {
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

struct LVHITTESTINFO {
    var pt: POINT = POINT()
    var flags: UINT = 0
    var iItem: Int32 = 0
    var iSubItem: Int32 = 0
    var iGroup: Int32 = 0
}

struct TCITEMW {
    var mask: UINT = 0
    var dwState: DWORD = 0
    var dwStateMask: DWORD = 0
    var pszText: UnsafeMutablePointer<UInt16>?
    var cchTextMax: Int32 = 0
    var iImage: Int32 = 0
    var lParam: LPARAM = 0
}

struct TBBUTTON {
    var iBitmap: Int32 = 0
    var idCommand: Int32 = 0
    var fsState: UInt8 = 0
    var fsStyle: UInt8 = 0
    var bReserved0: UInt8 = 0
    var bReserved1: UInt8 = 0
    var dwData: UInt = 0
    var iString: Int = 0
}

struct GdiplusStartupInput {
    // UINT32 followed by a pointer: Swift inserts the same 4 bytes of padding
    // the C layout has, so the struct stays ABI-compatible on 64-bit targets.
    var GdiplusVersion: UInt32 = 1
    var DebugEventCallback: UnsafeMutableRawPointer? = nil
    var SuppressBackgroundThread: Int32 = 0
    var SuppressExternalCodecs: Int32 = 0
}

struct TBBUTTONINFOW {
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

@_silgen_name("SetWindowsHookExW")
func winSetWindowsHookExW(_ hookType: Int32, _ hookProcedure: @convention(c) (Int32, WPARAM, LPARAM) -> LRESULT, _ module: HINSTANCE?, _ threadIdentifier: DWORD) -> UnsafeMutableRawPointer?

@_silgen_name("UnhookWindowsHookEx")
func winUnhookWindowsHookEx(_ hook: UnsafeMutableRawPointer?) -> Int32

@_silgen_name("CallNextHookEx")
func winCallNextHookEx(_ hook: UnsafeMutableRawPointer?, _ code: Int32, _ wParam: WPARAM, _ lParam: LPARAM) -> LRESULT

@_silgen_name("GetCurrentThreadId")
func winGetCurrentThreadId() -> DWORD

@_silgen_name("GetWindowRect")
func winGetWindowRect(_ hwnd: HWND?, _ rect: UnsafeMutablePointer<RECT>) -> Int32

@_silgen_name("EnableMenuItem")
func winEnableMenuItem(_ menu: HMENU?, _ identifier: UINT, _ flags: UINT) -> Int32

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

@_silgen_name("CreateFontW")
func winCreateFontW(
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
func winCreateWindowExW(
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

@_silgen_name("ImageList_Draw")
func winImageListDraw(_ imageList: HIMAGELIST?, _ index: Int32, _ deviceContext: HDC?, _ x: Int32, _ y: Int32, _ style: UINT) -> Int32

@_silgen_name("FillRect")
func winFillRect(_ deviceContext: HDC?, _ rectangle: UnsafePointer<RECT>?, _ brush: HBRUSH?) -> Int32

@_silgen_name("GetClientRect")
func winGetClientRect(_ hwnd: HWND?, _ rectangle: UnsafeMutablePointer<RECT>?) -> Int32

@_silgen_name("GetMessageW")
func winGetMessageW(_ message: UnsafeMutablePointer<MSG>, _ hwnd: HWND?, _ minimumMessage: UINT, _ maximumMessage: UINT) -> Int32

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

@_silgen_name("TrackPopupMenu")
func winTrackPopupMenu(
    _ menu: HMENU?,
    _ flags: UINT,
    _ x: Int32,
    _ y: Int32,
    _ reserved: Int32,
    _ hwnd: HWND?,
    _ rectangle: UnsafePointer<RECT>?
) -> Int32

@_silgen_name("DestroyMenu")
func winDestroyMenu(_ menu: HMENU?) -> Int32

@_silgen_name("LoadImageW")
func winLoadImageW(
    _ instance: HINSTANCE?,
    _ name: UnsafePointer<UInt16>?,
    _ type: UINT,
    _ width: Int32,
    _ height: Int32,
    _ loadFlags: UINT
) -> UnsafeMutableRawPointer?

@_silgen_name("MoveWindow")
func winMoveWindow(
    _ hwnd: HWND?,
    _ x: Int32,
    _ y: Int32,
    _ width: Int32,
    _ height: Int32,
    _ repaint: Int32
) -> Int32

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

@_silgen_name("SetWindowLongPtrW")
func winSetWindowLongPtrW(_ hwnd: HWND?, _ index: Int32, _ newLong: LONG_PTR) -> LONG_PTR

@_silgen_name("GetWindowLongPtrW")
func winGetWindowLongPtrW(_ hwnd: HWND?, _ index: Int32) -> LONG_PTR

@_silgen_name("IsWindowVisible")
func winIsWindowVisible(_ hwnd: HWND?) -> Int32

@_silgen_name("EnumFontFamiliesExW")
func winEnumFontFamiliesExW(
    _ deviceContext: HDC?,
    _ logFont: UnsafeMutablePointer<LOGFONTW>,
    _ callback: @convention(c) (UnsafeRawPointer?, UnsafeRawPointer?, DWORD, LPARAM) -> Int32,
    _ lParam: LPARAM,
    _ flags: DWORD
) -> Int32

@_silgen_name("SetWindowPos")
func winSetWindowPos(
    _ hwnd: HWND?,
    _ insertAfter: HWND?,
    _ x: Int32,
    _ y: Int32,
    _ width: Int32,
    _ height: Int32,
    _ flags: UINT
) -> Int32

@_silgen_name("SetWindowTextW")
func winSetWindowTextW(_ hwnd: HWND?, _ text: UnsafePointer<UInt16>?) -> Int32

@_silgen_name("ShowWindow")
func winShowWindow(_ hwnd: HWND?, _ commandShow: Int32) -> Int32

@_silgen_name("AdjustWindowRectEx")
func winAdjustWindowRectEx(
    _ rect: UnsafeMutablePointer<RECT>,
    _ style: DWORD,
    _ hasMenu: Int32,
    _ extendedStyle: DWORD
) -> Int32

@_silgen_name("RedrawWindow")
func winRedrawWindow(
    _ hwnd: HWND?,
    _ rect: UnsafePointer<RECT>?,
    _ region: UnsafeMutableRawPointer?,
    _ flags: UINT
) -> Int32

@_silgen_name("TextOutW")
func winTextOutW(_ deviceContext: HDC?, _ x: Int32, _ y: Int32, _ text: UnsafePointer<UInt16>?, _ count: Int32) -> Int32

@_silgen_name("CreateCompatibleDC")
func winCreateCompatibleDC(_ deviceContext: HDC?) -> HDC?

@_silgen_name("DeleteDC")
func winDeleteDC(_ deviceContext: HDC?) -> Int32

@_silgen_name("SetStretchBltMode")
func winSetStretchBltMode(_ deviceContext: HDC?, _ mode: Int32) -> Int32

@_silgen_name("StretchBlt")
func winStretchBlt(
    _ destinationContext: HDC?,
    _ x: Int32,
    _ y: Int32,
    _ width: Int32,
    _ height: Int32,
    _ sourceContext: HDC?,
    _ sourceX: Int32,
    _ sourceY: Int32,
    _ sourceWidth: Int32,
    _ sourceHeight: Int32,
    _ rasterOperation: DWORD
) -> Int32

@_silgen_name("GdiplusStartup")
func winGdiplusStartup(
    _ token: UnsafeMutablePointer<UInt>?,
    _ input: UnsafePointer<GdiplusStartupInput>?,
    _ output: UnsafeMutableRawPointer?
) -> Int32

@_silgen_name("GdipCreateBitmapFromFile")
func winGdipCreateBitmapFromFile(
    _ filename: UnsafePointer<UInt16>?,
    _ bitmap: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
) -> Int32

@_silgen_name("GdipCreateHBITMAPFromBitmap")
func winGdipCreateHBITMAPFromBitmap(
    _ bitmap: UnsafeMutableRawPointer?,
    _ hbitmap: UnsafeMutablePointer<HBITMAP?>?,
    _ background: UInt32
) -> Int32

@_silgen_name("GdipGetImageWidth")
func winGdipGetImageWidth(_ image: UnsafeMutableRawPointer?, _ width: UnsafeMutablePointer<UINT>?) -> Int32

@_silgen_name("GdipGetImageHeight")
func winGdipGetImageHeight(_ image: UnsafeMutableRawPointer?, _ height: UnsafeMutablePointer<UINT>?) -> Int32

@_silgen_name("GdipDisposeImage")
func winGdipDisposeImage(_ image: UnsafeMutableRawPointer?) -> Int32

/// GDI+ REAL rectangle used by line-gradient brushes.
struct GdipRectF {
    var x: Float = 0
    var y: Float = 0
    var width: Float = 0
    var height: Float = 0
}

@_silgen_name("GdipCreateFromHDC")
func winGdipCreateFromHDC(_ deviceContext: HDC?, _ graphics: UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> Int32

@_silgen_name("GdipDeleteGraphics")
func winGdipDeleteGraphics(_ graphics: UnsafeMutableRawPointer?) -> Int32

@_silgen_name("GdipCreateLineBrushFromRectWithAngle")
func winGdipCreateLineBrushFromRectWithAngle(
    _ rect: UnsafePointer<GdipRectF>?,
    _ color1: UInt32,
    _ color2: UInt32,
    _ angle: Float,
    _ isAngleScalable: Int32,
    _ wrapMode: Int32,
    _ lineGradient: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
) -> Int32

@_silgen_name("GdipSetLinePresetBlend")
func winGdipSetLinePresetBlend(
    _ brush: UnsafeMutableRawPointer?,
    _ blend: UnsafePointer<UInt32>?,
    _ positions: UnsafePointer<Float>?,
    _ count: Int32
) -> Int32

@_silgen_name("GdipFillRectangle")
func winGdipFillRectangle(
    _ graphics: UnsafeMutableRawPointer?,
    _ brush: UnsafeMutableRawPointer?,
    _ x: Float,
    _ y: Float,
    _ width: Float,
    _ height: Float
) -> Int32

@_silgen_name("GdipDeleteBrush")
func winGdipDeleteBrush(_ brush: UnsafeMutableRawPointer?) -> Int32

@_silgen_name("SaveDC")
func winSaveDC(_ deviceContext: HDC?) -> Int32

@_silgen_name("RestoreDC")
func winRestoreDC(_ deviceContext: HDC?, _ savedState: Int32) -> Int32

@_silgen_name("SelectClipPath")
func winSelectClipPath(_ deviceContext: HDC?, _ mode: Int32) -> Int32

@_silgen_name("TranslateMessage")
func winTranslateMessage(_ message: UnsafePointer<MSG>) -> Int32

@_silgen_name("UpdateWindow")
func winUpdateWindow(_ hwnd: HWND?) -> Int32

let winChocolateWindowClassName = "WinChocolateWindow"
let winChocolateViewClassName = "WinChocolateView"

let csVRedraw: UINT = 0x0001
let csHRedraw: UINT = 0x0002
let mfString: UINT = 0x0000
let mfGrayed: UINT = 0x0001
let mfChecked: UINT = 0x0008
let mfPopup: UINT = 0x0010
let mfSeparator: UINT = 0x0800
let tpmLeftAlign: UINT = 0x0000
let tpmReturnCmd: UINT = 0x0100
let mbOK: UINT = 0x00000000
let mbOKCancel: UINT = 0x00000001
let mbYesNo: UINT = 0x00000004
let mbIconInformation: UINT = 0x00000040
let mbIconWarning: UINT = 0x00000030
let mbIconError: UINT = 0x00000010
let swShow: Int32 = 5
let swHide: Int32 = 0
let swShowNoActivate: Int32 = 4
let gwlExStyle: Int32 = -20
let wsExToolWindow: DWORD = 0x0000_0080
let swpFrameChanged: UINT = 0x0020
let wmActivateApp: UINT = 0x001c
/// Special SetWindowPos z-order handle placing a window above non-topmost windows.
var hwndTopmost: HWND? { HWND(bitPattern: -1) }
/// Special SetWindowPos z-order handle returning a window to the normal band.
var hwndNoTopmost: HWND? { HWND(bitPattern: -2) }
let rdwInvalidate: UINT = 0x0001
let rdwErase: UINT = 0x0004
let rdwAllChildren: UINT = 0x0080
let rdwUpdateNow: UINT = 0x0100
let swpNoActivate: UINT = 0x0010
let swpShowWindow: UINT = 0x0040
let wmDestroy: UINT = 0x0002
let wmClose: UINT = 0x0010
let wmSize: UINT = 0x0005
let wmNotify: UINT = 0x004e
let wmPaint: UINT = 0x000f
let wmEraseBackground: UINT = 0x0014
let wmSetFont: UINT = 0x0030
let wmCommand: UINT = 0x0111
let wmUser: UINT = 0x0400
let stmSetImage: UINT = 0x0172
let wmHScroll: UINT = 0x0114
let wmVScroll: UINT = 0x0115
let wmCtlColorEdit: UINT = 0x0133
let wmCtlColorListBox: UINT = 0x0134
let wmCtlColorBtn: UINT = 0x0135
let wmCtlColorStatic: UINT = 0x0138
let wmKeyDown: UINT = 0x0100
let wmKeyUp: UINT = 0x0101
let wmSysKeyDown: UINT = 0x0104
let wmSysKeyUp: UINT = 0x0105
let wmGetDlgCode: UINT = 0x0087
let wmMouseMove: UINT = 0x0200
let wmLButtonDown: UINT = 0x0201
let wmLButtonUp: UINT = 0x0202
let wmLButtonDblClk: UINT = 0x0203
let wmRButtonDown: UINT = 0x0204
let wmRButtonUp: UINT = 0x0205
let wmMButtonDown: UINT = 0x0207
let wmMButtonUp: UINT = 0x0208
let wmMouseWheel: UINT = 0x020a
let wmSetCursor: UINT = 0x0020
let htClient: LPARAM = 1
let idcArrow = 32_512
let idcIBeam = 32_513
let idcCrosshair = 32_515
let idcSizeWE = 32_644
let idcSizeNS = 32_645
let idcHand = 32_649
let mkLButton: WPARAM = 0x0001
let csDblClks: UINT = 0x0008
let psSolid: Int32 = 0
let windingFillMode: Int32 = 2
let wmTimer: UINT = 0x0113
let wmInitMenuPopup: UINT = 0x0117
let mfEnabled: UINT = 0x0000
let mfUnchecked: UINT = 0x0000
let mfByPosition: UINT = 0x0400
let whCbt: Int32 = 5
let hcbtActivate: Int32 = 5
let transparentBkMode: Int32 = 1
let dtCenter: UINT = 0x00000001
let dtVCenter: UINT = 0x00000004
let dtSingleLine: UINT = 0x00000020
let dtEndEllipsis: UINT = 0x00008000
let wmApp: UINT = 0x8000
let wmWinChocolateAsync: UINT = wmApp + 1
let bmGetCheck: UINT = 0x00f0
let bmSetCheck: UINT = 0x00f1
let cbAddString: UINT = 0x0143
let cbGetCurSel: UINT = 0x0147
let cbResetContent: UINT = 0x014b
let cbSetCurSel: UINT = 0x014e
let cbShowDropDown: UINT = 0x014f
let sbmSetPos: UINT = 0x00e0
let sbmGetPos: UINT = 0x00e1
let sbmSetRange: UINT = 0x00e2
let tbmGetPos: UINT = 0x0400
let tbmSetPos: UINT = 0x0405
let tbmSetRangeMin: UINT = 0x0407
let tbmSetRangeMax: UINT = 0x0408
let sbmSetScrollInfo: UINT = 0x00e9
let sbmGetScrollInfo: UINT = 0x00ea
let pbmSetRange32: UINT = 0x0406
let pbmSetPos: UINT = 0x0402
let udmSetRange32: UINT = 0x046f
let udmSetPos32: UINT = 0x0471
let lbAddString: UINT = 0x0180
let lbSetCurSel: UINT = 0x0186
let lbGetCurSel: UINT = 0x0188
let lbResetContent: UINT = 0x0184
let hdmFirst: UINT = 0x1200
let hdmHitTest: UINT = hdmFirst + 6
let lvmFirst: UINT = 0x1000
let lvmDeleteAllItems: UINT = lvmFirst + 9
let lvmGetNextItem: UINT = lvmFirst + 12
let lvmEnsureVisible: UINT = lvmFirst + 19
let lvmGetHeader: UINT = lvmFirst + 31
let lvmSetItemState: UINT = lvmFirst + 43
let lvmSubItemHitTest: UINT = lvmFirst + 57
let lvmInsertItemW: UINT = lvmFirst + 77
let lvmInsertColumnW: UINT = lvmFirst + 97
let lvmSetItemTextW: UINT = lvmFirst + 116
let lvmSetExtendedListViewStyle: UINT = lvmFirst + 54
let tcmFirst: UINT = 0x1300
let tcmGetCurSel: UINT = tcmFirst + 11
let tcmSetCurSel: UINT = tcmFirst + 12
let tcmDeleteAllItems: UINT = tcmFirst + 9
let tcmInsertItemW: UINT = tcmFirst + 62
let tbAddButtonsW: UINT = wmUser + 68
let tbAddStringW: UINT = wmUser + 77
let tbAutosize: UINT = wmUser + 33
let tbButtonCount: UINT = wmUser + 24
let tbButtonStructSize: UINT = wmUser + 30
let tbDeleteButton: UINT = wmUser + 22
let tbGetImageList: UINT = wmUser + 49
let tbGetItemRect: UINT = wmUser + 29
let tbLoadImages: UINT = wmUser + 50
let tbSetButtonInfoW: UINT = wmUser + 64
let enChange: UInt = 0x0300
let lbnSelChange: UInt = 1
let nmClick: UINT = 0xfffffffe
let lvnItemChanged: UINT = 0xffffff9b
let lvnColumnClick: UINT = 0xffffff94
let hdnItemClickA: UINT = 0xfffffed2
let hdnItemClickW: UINT = 0xfffffebe
let udnDeltapos: UINT = 0xfffffd2e
let tcnSelChange: UINT = 0xffffffc9
let dtnDateTimeChange: UINT = 0xfffffd09
let bnClicked: UInt = 0
let cbnSelChange: UInt = 1
let cbnEditChange: UInt = 5
let iccListViewClasses: DWORD = 0x00000001
let iccBarClasses: DWORD = 0x00000004
let iccTabClasses: DWORD = 0x00000008
let iccUpDownClass: DWORD = 0x00000010
let iccProgressClass: DWORD = 0x00000020
let iccDateClasses: DWORD = 0x00000100
let dtmFirst: UINT = 0x1000
let dtmGetSystemTime: UINT = dtmFirst + 1
let dtmSetSystemTime: UINT = dtmFirst + 2
let gdtValid: WPARAM = 0
let bstUnchecked: WPARAM = 0
let bstChecked: WPARAM = 1
let bstIndeterminate: WPARAM = 2
let defaultCharset: DWORD = 1
let defaultPrecision: DWORD = 0
let defaultQuality: DWORD = 0
let defaultPitchAndFamily: DWORD = 0
let nullBrush: Int32 = 5
let vkBack: Int32 = 0x08
let vkTab: Int32 = 0x09
let vkReturn: Int32 = 0x0d
let vkShift: Int32 = 0x10
let vkControl: Int32 = 0x11
let vkMenu: Int32 = 0x12
let vkEscape: Int32 = 0x1b
let vkSpace: Int32 = 0x20
let vkLWin: Int32 = 0x5b
let vkRWin: Int32 = 0x5c
let vkLShift: Int32 = 0xa0
let vkRShift: Int32 = 0xa1
let vkLControl: Int32 = 0xa2
let vkRControl: Int32 = 0xa3
let vkLMenu: Int32 = 0xa4
let vkRMenu: Int32 = 0xa5
let gwlpWndProc: Int32 = -4
let gwChild: UINT = 5
let dlgcWantTab: LRESULT = 0x0002
let idOK: Int32 = 1
let idYes: Int32 = 6
let wsOverlapped: DWORD = 0x00000000
let wsPopup: DWORD = 0x80000000
let wsCaption: DWORD = 0x00c00000
let wsSysMenu: DWORD = 0x00080000
let wsThickFrame: DWORD = 0x00040000
let wsMinimizeBox: DWORD = 0x00020000
let wsMaximizeBox: DWORD = 0x00010000
let wsTabStop: DWORD = 0x00010000
let wsVisible: DWORD = 0x10000000
let wsVScroll: DWORD = 0x00200000
let wsHScroll: DWORD = 0x00100000
let wsChild: DWORD = 0x40000000
let wsClipChildren: DWORD = 0x02000000
let wsBorder: DWORD = 0x00800000
let ofnExplorer: DWORD = 0x00080000
let ofnAllowMultiSelect: DWORD = 0x00000200
let ofnFileMustExist: DWORD = 0x00001000
let ofnPathMustExist: DWORD = 0x00000800
let ofnOverwritePrompt: DWORD = 0x00000002
let ofnHideReadOnly: DWORD = 0x00000004
let ofnNoChangeDir: DWORD = 0x00000008
let ofnForceShowHidden: DWORD = 0x10000000
let ccRGBInit: DWORD = 0x00000001
let ccFullOpen: DWORD = 0x00000002
let cfScreenFonts: DWORD = 0x00000001
let cfInitToLogFontStruct: DWORD = 0x00000040
let bifReturnOnlyFSDirs: UINT = 0x0001
let bifNewDialogStyle: UINT = 0x0040
let coinitApartmentThreaded: DWORD = 0x2
let emGetSel: UINT = 0x00b0
let emSetSel: UINT = 0x00b1
let emScrollCaret: UINT = 0x00b7
let emReplaceSel: UINT = 0x00c2
let emSetReadOnly: UINT = 0x00cf
let esMultiline: DWORD = 0x0004
let esPassword: DWORD = 0x0020
let esAutoVScroll: DWORD = 0x0040
let esAutoHScroll: DWORD = 0x0080
let esWantReturn: DWORD = 0x1000
let esNoHideSel: DWORD = 0x0100
let lbsNotify: DWORD = 0x0001
let lvsReport: DWORD = 0x0001
let lvsSingleSel: DWORD = 0x0004
let lvsShowSelAlways: DWORD = 0x0008
let lvsExGridLines: DWORD = 0x00000001
let lvsExFullRowSelect: DWORD = 0x00000020
let lvifText: UINT = 0x0001
let lvifState: UINT = 0x0008
let lvcfWidth: UINT = 0x0002
let lvcfText: UINT = 0x0004
let lvcfSubItem: UINT = 0x0008
let lvisFocused: UINT = 0x0001
let lvisSelected: UINT = 0x0002
let lvniSelected: WPARAM = 0x0002
let bsAutoCheckBox: DWORD = 0x00000003
let bsAutoRadioButton: DWORD = 0x00000009
let bsGroupBox: DWORD = 0x00000007
let bsFlat: DWORD = 0x00008000
let ssWhiteRect: DWORD = 0x00000006
let tbStateEnabled: UInt8 = 0x04
let tbStyleButton: UInt8 = 0x00
let tbStyleSep: UInt8 = 0x01
let tbifSize: DWORD = 0x00000040
let btnsAutosize: UInt8 = 0x10
let btnsShowText: UInt8 = 0x40
let iImageNone: Int32 = -2
let iStringNone: Int = -1
let idbStdSmallColor: WPARAM = 0
let hinstCommctrl: LPARAM = -1
let stdFileNew: Int32 = 0
let stdFileOpen: Int32 = 1
let stdFileSave: Int32 = 2
let stdPrint: Int32 = 6
let stdProperties: Int32 = 10
let stdHelp: Int32 = 11
let ildNormal: UINT = 0x00000000
let toolbarClassName = "ToolbarWindow32"
let tbStyleFlat: DWORD = 0x00000800
let tbStyleList: DWORD = 0x00001000
let tbStyleTooltips: DWORD = 0x00000100
let ccsNoResize: DWORD = 0x00000004
let ccsNoDivider: DWORD = 0x00000040
let ssNotify: DWORD = 0x00000100
let ssBitmap: DWORD = 0x0000000e
let ssCenterImage: DWORD = 0x00000200
let cbsDropdown: DWORD = 0x0002
let cbsDropdownList: DWORD = 0x0003
let swpNoMove: UINT = 0x0002
let swpNoSize: UINT = 0x0001
let tciText: UINT = 0x0001
let sbsHorz: DWORD = 0x0000
let sbsVert: DWORD = 0x0001
let sbHorz: Int32 = 0
let sbVert: Int32 = 1
let sifRange: UINT = 0x0001
let sifPage: UINT = 0x0002
let sifPos: UINT = 0x0004
let sifTrackPos: UINT = 0x0010
let sifAll: UINT = sifRange | sifPage | sifPos | sifTrackPos
let udsArrowKeys: DWORD = 0x0020
let sbLineLeft: UInt = 0
let sbLineRight: UInt = 1
let sbPageLeft: UInt = 2
let sbPageRight: UInt = 3
let sbThumbPosition: UInt = 4
let sbThumbTrack: UInt = 5
let sbTop: UInt = 6
let sbBottom: UInt = 7
let imageBitmap: UINT = 0
let lrLoadFromFile: UINT = 0x00000010
let lrCreatedDIBSection: UINT = 0x00002000
let halftoneStretchMode: Int32 = 4
let srcCopyRasterOperation: DWORD = 0x00cc0020
let gdiplusOkStatus: Int32 = 0
let gdiplusWhiteBackground: UInt32 = 0xffffffff
let gdiplusWrapModeTileFlipXY: Int32 = 3
let rgnAnd: Int32 = 1

func withOptionalWideString<Result>(_ string: String?, _ body: (UnsafePointer<UInt16>?) -> Result) -> Result {
    guard let string else {
        return body(nil)
    }

    return withWideString(string, body)
}

func withWideString<Result>(_ string: String, _ body: (UnsafePointer<UInt16>?) -> Result) -> Result {
    var wideString = Array(string.utf16)
    wideString.append(0)
    return wideString.withUnsafeBufferPointer { buffer in
        body(buffer.baseAddress)
    }
}

func systemResourcePointer(_ identifier: Int) -> UnsafePointer<UInt16>? {
    UnsafePointer<UInt16>(bitPattern: identifier)
}
#endif
