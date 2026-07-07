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

struct CHARFORMATW {
    var cbSize: UINT = 0
    var dwMask: DWORD = 0
    var dwEffects: DWORD = 0
    var yHeight: Int32 = 0
    var yOffset: Int32 = 0
    var crTextColor: DWORD = 0
    var bCharSet: UInt8 = 0
    var bPitchAndFamily: UInt8 = 0
    var szFaceName: (
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

// MARK: - Printing

/// The print-dialog request/result (`PRINTDLGW`).
struct PRINTDLGW {
    var lStructSize: DWORD = 0
    var padding: UInt32 = 0
    var hwndOwner: HWND?
    var hDevMode: UnsafeMutableRawPointer?
    var hDevNames: UnsafeMutableRawPointer?
    var hDC: HDC?
    var flags: DWORD = 0
    var nFromPage: UInt16 = 0
    var nToPage: UInt16 = 0
    var nMinPage: UInt16 = 0
    var nMaxPage: UInt16 = 0
    var nCopies: UInt16 = 0
    var padding2: UInt16 = 0
    var hInstance: UnsafeMutableRawPointer?
    var lCustData: LPARAM = 0
    var lpfnPrintHook: UnsafeMutableRawPointer?
    var lpfnSetupHook: UnsafeMutableRawPointer?
    var lpPrintTemplateName: UnsafeMutableRawPointer?
    var lpSetupTemplateName: UnsafeMutableRawPointer?
    var hPrintTemplate: UnsafeMutableRawPointer?
    var hSetupTemplate: UnsafeMutableRawPointer?
}

/// PrintDlg flags: return a ready printer DC, no selection/page-range UI.
let pdReturnDC: DWORD = 0x0000_0100
let pdNoSelection: DWORD = 0x0000_0004
let pdNoPageNums: DWORD = 0x0000_0008
let pdUseDevModeCopies: DWORD = 0x0004_0000

/// The document descriptor for `StartDocW`.
struct DOCINFOW {
    var cbSize: Int32 = 0
    var padding: UInt32 = 0
    var lpszDocName: UnsafePointer<UInt16>?
    var lpszOutput: UnsafePointer<UInt16>?
    var lpszDatatype: UnsafePointer<UInt16>?
    var fwType: DWORD = 0
}

@_silgen_name("PrintDlgW")
func winPrintDlgW(_ printDialog: UnsafeMutablePointer<PRINTDLGW>?) -> Int32

@_silgen_name("StartDocW")
func winStartDocW(_ deviceContext: HDC?, _ documentInfo: UnsafePointer<DOCINFOW>?) -> Int32

@_silgen_name("StartPage")
func winStartPage(_ deviceContext: HDC?) -> Int32

@_silgen_name("EndPage")
func winEndPage(_ deviceContext: HDC?) -> Int32

@_silgen_name("EndDoc")
func winEndDoc(_ deviceContext: HDC?) -> Int32

@_silgen_name("AbortDoc")
func winAbortDoc(_ deviceContext: HDC?) -> Int32

@_silgen_name("GetDeviceCaps")
func winGetDeviceCaps(_ deviceContext: HDC?, _ index: Int32) -> Int32

/// GetDeviceCaps indexes: pixels per logical inch.
let logPixelsX: Int32 = 88
let logPixelsY: Int32 = 90

// MARK: - OLE drag and drop

/// A COM interface identifier (`IID`/`GUID`).
struct COMGUID: Equatable {
    var data1: UInt32 = 0
    var data2: UInt16 = 0
    var data3: UInt16 = 0
    var data4: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0, 0, 0, 0, 0)

    static func == (lhs: COMGUID, rhs: COMGUID) -> Bool {
        lhs.data1 == rhs.data1 && lhs.data2 == rhs.data2 && lhs.data3 == rhs.data3
            && lhs.data4.0 == rhs.data4.0 && lhs.data4.1 == rhs.data4.1
            && lhs.data4.2 == rhs.data4.2 && lhs.data4.3 == rhs.data4.3
            && lhs.data4.4 == rhs.data4.4 && lhs.data4.5 == rhs.data4.5
            && lhs.data4.6 == rhs.data4.6 && lhs.data4.7 == rhs.data4.7
    }
}

/// IID_IUnknown.
let iidIUnknown = COMGUID(data1: 0x0000_0000, data2: 0, data3: 0, data4: (0xC0, 0, 0, 0, 0, 0, 0, 0x46))
/// IID_IDropTarget.
let iidIDropTarget = COMGUID(data1: 0x0000_0122, data2: 0, data3: 0, data4: (0xC0, 0, 0, 0, 0, 0, 0, 0x46))
/// IID_IDropSource.
let iidIDropSource = COMGUID(data1: 0x0000_0121, data2: 0, data3: 0, data4: (0xC0, 0, 0, 0, 0, 0, 0, 0x46))
/// IID_IDataObject.
let iidIDataObject = COMGUID(data1: 0x0000_010E, data2: 0, data3: 0, data4: (0xC0, 0, 0, 0, 0, 0, 0, 0x46))

/// `FORMATETC`: which representation of an OLE data object to fetch.
struct FORMATETC {
    var cfFormat: UInt16 = 0
    var padding1: UInt16 = 0
    var padding2: UInt32 = 0
    var targetDevice: UnsafeMutableRawPointer?
    var dwAspect: DWORD = 0
    var lindex: Int32 = 0
    var tymed: DWORD = 0
    var padding3: UInt32 = 0
}

/// `STGMEDIUM`: the storage carrying a fetched representation.
struct STGMEDIUM {
    var tymed: DWORD = 0
    var padding: UInt32 = 0
    var handle: UnsafeMutableRawPointer?
    var pUnkForRelease: UnsafeMutableRawPointer?
}

/// COM/OLE result codes and constants.
let comSOk: Int32 = 0
let comENoInterface: Int32 = Int32(bitPattern: 0x8000_4002)
let comENotImpl: Int32 = Int32(bitPattern: 0x8000_4001)
let comDVEFormatEtc: Int32 = Int32(bitPattern: 0x8004_0064)
let comOleEAdviseNotSupported: Int32 = Int32(bitPattern: 0x8004_0003)
let comDragDropSDrop: Int32 = 0x0004_0100
let comDragDropSCancel: Int32 = 0x0004_0101
let comDragDropSUseDefaultCursors: Int32 = 0x0004_0102
let dropEffectNone: DWORD = 0
let dropEffectCopy: DWORD = 1
let dropEffectMove: DWORD = 2
let dropEffectLink: DWORD = 4
let tymedHGlobal: DWORD = 1
let dvAspectContent: DWORD = 1

@_silgen_name("OleInitialize")
func winOleInitialize(_ reserved: UnsafeMutableRawPointer?) -> Int32

@_silgen_name("RegisterDragDrop")
func winRegisterDragDrop(_ hwnd: HWND?, _ dropTarget: UnsafeMutableRawPointer?) -> Int32

@_silgen_name("RevokeDragDrop")
func winRevokeDragDrop(_ hwnd: HWND?) -> Int32

@_silgen_name("ReleaseStgMedium")
func winReleaseStgMedium(_ medium: UnsafeMutableRawPointer?)

@_silgen_name("DoDragDrop")
func winDoDragDrop(
    _ dataObject: UnsafeMutableRawPointer?,
    _ dropSource: UnsafeMutableRawPointer?,
    _ allowedEffects: DWORD,
    _ effect: UnsafeMutablePointer<DWORD>?
) -> Int32

@_silgen_name("SHCreateStdEnumFmtEtc")
func winSHCreateStdEnumFmtEtc(
    _ count: UINT,
    _ formats: UnsafeMutableRawPointer?,
    _ enumerator: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
) -> Int32

/// Mouse-tracking request (`TRACKMOUSEEVENT`), used for leave notifications.
struct TRACKMOUSEEVENTW {
    var cbSize: UINT = 0
    var dwFlags: DWORD = 0
    var hwndTrack: HWND?
    var dwHoverTime: DWORD = 0
}

/// TrackMouseEvent flag requesting a `WM_MOUSELEAVE` message.
let tmeLeave: DWORD = 0x0000_0002

@_silgen_name("TrackMouseEvent")
func winTrackMouseEvent(_ request: UnsafeMutablePointer<TRACKMOUSEEVENTW>?) -> Int32

/// Rich edit paragraph format (`PARAFORMAT`), used for alignment.
struct PARAFORMATW {
    var cbSize: UINT = 0
    var dwMask: DWORD = 0
    var wNumbering: UInt16 = 0
    var wReserved: UInt16 = 0
    var dxStartIndent: Int32 = 0
    var dxRightIndent: Int32 = 0
    var dxOffset: Int32 = 0
    var wAlignment: UInt16 = 0
    var cTabCount: Int16 = 0
    var rgxTabs: (
        Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32,
        Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32,
        Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32,
        Int32, Int32, Int32, Int32, Int32, Int32, Int32, Int32
    ) = (
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    )
}

struct XFORM {
    var eM11: Float = 1
    var eM12: Float = 0
    var eM21: Float = 0
    var eM22: Float = 1
    var eDx: Float = 0
    var eDy: Float = 0
}

struct MINMAXINFO {
    var ptReserved: POINT = POINT()
    var ptMaxSize: POINT = POINT()
    var ptMaxPosition: POINT = POINT()
    var ptMinTrackSize: POINT = POINT()
    var ptMaxTrackSize: POINT = POINT()
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

@_silgen_name("GetSystemMenu")
func winGetSystemMenu(_ hwnd: HWND?, _ revert: Int32) -> HMENU?

@_silgen_name("GetSystemMetrics")
func winGetSystemMetrics(_ index: Int32) -> Int32

// Registry read (Advapi32) — used for the system dark-theme preference.
@_silgen_name("RegGetValueW")
func winRegGetValueW(
    _ key: UnsafeMutableRawPointer?,
    _ subKey: UnsafePointer<UInt16>?,
    _ value: UnsafePointer<UInt16>?,
    _ flags: UInt32,
    _ type: UnsafeMutablePointer<UInt32>?,
    _ data: UnsafeMutableRawPointer?,
    _ dataSize: UnsafeMutablePointer<UInt32>?
) -> Int32

/// `HKEY_CURRENT_USER` — the 32-bit pseudo-handle sign-extends on 64-bit.
nonisolated(unsafe) let winHKEYCurrentUser = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: Int(Int32(bitPattern: 0x8000_0001))))

/// `RRF_RT_REG_DWORD` for `RegGetValueW`.
let winRRFRtRegDword: UInt32 = 0x0000_0010

// Window-attribute write (Dwmapi) — used for the dark title bar.
@_silgen_name("DwmSetWindowAttribute")
func winDwmSetWindowAttribute(
    _ hwnd: HWND?,
    _ attribute: DWORD,
    _ value: UnsafeRawPointer?,
    _ valueSize: DWORD
) -> Int32

/// `DWMWA_USE_IMMERSIVE_DARK_MODE` (Windows 10 20H1+).
let winDWMWAUseImmersiveDarkMode: DWORD = 20

// Visual-styles subclass selection (UxTheme) — used for dark control themes.
@_silgen_name("SetWindowTheme")
func winSetWindowTheme(
    _ hwnd: HWND?,
    _ subAppName: UnsafePointer<UInt16>?,
    _ subIdList: UnsafePointer<UInt16>?
) -> Int32

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

@_silgen_name("SetWorldTransform")
func winSetWorldTransform(_ deviceContext: HDC?, _ transform: UnsafePointer<XFORM>) -> Int32

@_silgen_name("ModifyWorldTransform")
func winModifyWorldTransform(_ deviceContext: HDC?, _ transform: UnsafePointer<XFORM>?, _ mode: DWORD) -> Int32

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

@_silgen_name("CreateCompatibleBitmap")
func winCreateCompatibleBitmap(_ deviceContext: HDC?, _ width: Int32, _ height: Int32) -> HBITMAP?

@_silgen_name("BitBlt")
func winBitBlt(
    _ destination: HDC?,
    _ destinationX: Int32,
    _ destinationY: Int32,
    _ width: Int32,
    _ height: Int32,
    _ source: HDC?,
    _ sourceX: Int32,
    _ sourceY: Int32,
    _ rasterOperation: DWORD
) -> Int32

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

/// GDI+ pixel unit for `GdipDrawImageRectRectI` source rectangles.
let gdiplusUnitPixel: Int32 = 2

/// GDI+ 32-bit ARGB pixel format (`PixelFormat32bppARGB`).
let gdiplusPixelFormat32bppARGB: Int32 = 0x26200A

@_silgen_name("GdipCreateImageAttributes")
func winGdipCreateImageAttributes(_ attributes: UnsafeMutablePointer<UnsafeMutableRawPointer?>?) -> Int32

@_silgen_name("GdipDisposeImageAttributes")
func winGdipDisposeImageAttributes(_ attributes: UnsafeMutableRawPointer?) -> Int32

// The color matrix parameter is 25 consecutive REALs (a row-major 5x5 matrix),
// so a Float buffer pointer matches the C `ColorMatrix*` layout exactly.
@_silgen_name("GdipSetImageAttributesColorMatrix")
func winGdipSetImageAttributesColorMatrix(
    _ attributes: UnsafeMutableRawPointer?,
    _ adjustType: Int32,
    _ enableFlag: Int32,
    _ colorMatrix: UnsafePointer<Float>?,
    _ grayMatrix: UnsafePointer<Float>?,
    _ flags: Int32
) -> Int32

@_silgen_name("GdipDrawImageRectRectI")
func winGdipDrawImageRectRectI(
    _ graphics: UnsafeMutableRawPointer?,
    _ image: UnsafeMutableRawPointer?,
    _ destinationX: Int32,
    _ destinationY: Int32,
    _ destinationWidth: Int32,
    _ destinationHeight: Int32,
    _ sourceX: Int32,
    _ sourceY: Int32,
    _ sourceWidth: Int32,
    _ sourceHeight: Int32,
    _ sourceUnit: Int32,
    _ imageAttributes: UnsafeMutableRawPointer?,
    _ abortCallback: UnsafeMutableRawPointer?,
    _ callbackData: UnsafeMutableRawPointer?
) -> Int32

@_silgen_name("GdipCreateBitmapFromScan0")
func winGdipCreateBitmapFromScan0(
    _ width: Int32,
    _ height: Int32,
    _ stride: Int32,
    _ format: Int32,
    _ scan0: UnsafeMutableRawPointer?,
    _ bitmap: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
) -> Int32

@_silgen_name("GdipGetImageGraphicsContext")
func winGdipGetImageGraphicsContext(
    _ image: UnsafeMutableRawPointer?,
    _ graphics: UnsafeMutablePointer<UnsafeMutableRawPointer?>?
) -> Int32

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
let swMinimize: Int32 = 6
let swRestore: Int32 = 9
let swMaximize: Int32 = 3
/// Window move message; the framework reads the window rect on receipt.
let wmMove: UINT = 0x0003
/// SetWindowPos z-order handle placing a window at the bottom.
var hwndBottom: HWND? { HWND(bitPattern: 1) }

@_silgen_name("IsIconic")
func winIsIconic(_ hwnd: HWND?) -> Int32

@_silgen_name("IsZoomed")
func winIsZoomed(_ hwnd: HWND?) -> Int32

/// Monitor description (`MONITORINFO`): full bounds plus the work area.
struct MONITORINFOW {
    var cbSize: DWORD = 0
    var rcMonitor: RECT = RECT()
    var rcWork: RECT = RECT()
    var dwFlags: DWORD = 0
}

// The monitor rect parameter stays a raw pointer: Swift structs (`RECT`) are
// not representable in a `@convention(c)` signature, and the callback reads
// the full `MONITORINFOW` via `GetMonitorInfoW` instead.
typealias MONITORENUMPROC = @convention(c) (UnsafeMutableRawPointer?, HDC?, UnsafeMutableRawPointer?, LPARAM) -> Int32

@_silgen_name("EnumDisplayMonitors")
func winEnumDisplayMonitors(
    _ deviceContext: HDC?,
    _ clip: UnsafeRawPointer?,
    _ callback: MONITORENUMPROC?,
    _ data: LPARAM
) -> Int32

@_silgen_name("GetMonitorInfoW")
func winGetMonitorInfoW(_ monitor: UnsafeMutableRawPointer?, _ info: UnsafeMutablePointer<MONITORINFOW>?) -> Int32
let gwlExStyle: Int32 = -20
let wsExClientEdge: DWORD = 0x0000_0200
let wsExToolWindow: DWORD = 0x0000_0080
let wsExNoActivate: DWORD = 0x0800_0000
let swpFrameChanged: UINT = 0x0020
let swpNoZOrder: UINT = 0x0004
let gwlStyle: Int32 = -16
let wmActivateApp: UINT = 0x001c
let wmMouseHWheel: UINT = 0x020e
let wmSetFocus: UINT = 0x0007
let wmKillFocus: UINT = 0x0008
let htCaption: Int = 2
/// Rich edit: EM_SETBKGNDCOLOR (WM_USER + 67).
let emSetBkgndColor: UINT = wmUser + 67
/// Rich edit: EM_SETCHARFORMAT (WM_USER + 68).
let emSetCharFormat: UINT = wmUser + 68
/// Rich edit: EM_SETEVENTMASK (WM_USER + 69).
let emSetEventMask: UINT = wmUser + 69
/// Rich edit: EM_SETPARAFORMAT (WM_USER + 71).
let emSetParaFormat: UINT = wmUser + 71
/// PARAFORMAT mask selecting the alignment field.
let pfmAlignment: DWORD = 0x0000_0008
/// PARAFORMAT alignments.
let pfaLeft: UInt16 = 1
let pfaRight: UInt16 = 2
let pfaCenter: UInt16 = 3
/// Rich edit event mask requesting EN_CHANGE notifications.
let enmChange: LPARAM = 0x0001
/// EM_SETCHARFORMAT target: the current selection.
let scfSelection: WPARAM = 0x0001
/// EM_SETCHARFORMAT target: all text.
let scfAll: WPARAM = 0x0004
/// Clipboard format: UTF-16 text.
let cfUnicodeText: UINT = 13
/// Clipboard format: file list (`CF_HDROP`).
let cfHDrop: UINT = 15
/// GlobalAlloc movable-memory flag required by SetClipboardData.
let gmemMoveable: UINT = 0x0002
let cfmBold: DWORD = 0x0000_0001
let cfeBold: DWORD = 0x0000_0001
let cfmItalic: DWORD = 0x0000_0002
let cfeItalic: DWORD = 0x0000_0002
let cfmUnderline: DWORD = 0x0000_0004
let cfeUnderline: DWORD = 0x0000_0004
let cfmStrikeOut: DWORD = 0x0000_0008
let cfeStrikeOut: DWORD = 0x0000_0008
let cfmColor: DWORD = 0x4000_0000
let cfmFace: DWORD = 0x2000_0000
let cfmSize: DWORD = 0x8000_0000
/// GDI graphics mode allowing world transforms.
let gmAdvanced: Int32 = 2
/// Default GDI graphics mode without world transforms.
let gmCompatible: Int32 = 1
/// ModifyWorldTransform mode resetting to the identity transform.
let mwtIdentity: DWORD = 1
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
/// Posted when the cursor leaves a window after `TrackMouseEvent`.
let wmMouseLeave: UINT = 0x02A3
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
let whMouse: Int32 = 7
let wmNCLButtonDown: UINT = 0x00a1
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
let tbmSetTicFreq: UINT = 0x0414
let tbsAutoTicks: DWORD = 0x0001
let tbsVert: DWORD = 0x0002
let tbsTop: DWORD = 0x0004
let tbsBoth: DWORD = 0x0008
let tbsNoTicks: DWORD = 0x0010
let esCenter: DWORD = 0x0001
let esRight: DWORD = 0x0002
let emSetCueBanner: UINT = 0x1501
let pbmSetBarColor: UINT = 0x0409
let wmGetMinMaxInfo: UINT = 0x0024
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
/// LVN_BEGINLABELEDITW = LVN_FIRST(-100) - 75.
let lvnBeginLabelEditW: UINT = 0xffffff51
/// LVN_ENDLABELEDITW = LVN_FIRST(-100) - 76.
let lvnEndLabelEditW: UINT = 0xffffff50
/// LVN_BEGINDRAG = LVN_FIRST(-100) - 9.
let lvnBeginDrag: UINT = 0xffffff93
/// LVS_EX_* / label editing.
let lvsEditLabels: DWORD = 0x0200
let lvmEditLabelW: UINT = lvmFirst + 118
/// Header control: get/set item and sort-indicator format bits.
let hdmGetItemW: UINT = hdmFirst + 11
let hdmSetItemW: UINT = hdmFirst + 12
let hdiFormat: UINT = 0x0004
let hdfSortUp: Int32 = 0x0400
let hdfSortDown: Int32 = 0x0200

/// Header item (`HDITEMW`); WinChocolate only touches the format field for the
/// sort indicator, but the full layout must match so `cxy`/`pszText` etc. stay
/// intact across a get/set round-trip.
struct HDITEMW {
    var mask: UINT = 0
    var cxy: Int32 = 0
    var pszText: UnsafeMutablePointer<UInt16>?
    var hbm: UnsafeMutableRawPointer?
    var cchTextMax: Int32 = 0
    var fmt: Int32 = 0
    var lParam: LPARAM = 0
    var iImage: Int32 = 0
    var iOrder: Int32 = 0
    var type: UINT = 0
    var pvFilter: UnsafeMutableRawPointer?
    var state: UINT = 0
}

/// Notification payload for list-view label editing (`NMLVDISPINFOW`).
struct NMLVDISPINFOW {
    var hdr: NMHDR = NMHDR()
    var item: LVITEMW = LVITEMW()
}
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
let dtmSetFormatW: UINT = dtmFirst + 50
let gdtValid: WPARAM = 0
let mcmFirst: UINT = 0x1000
let mcmGetCurSel: UINT = mcmFirst + 1
let mcmSetCurSel: UINT = mcmFirst + 2
let mcmGetMinReqRect: UINT = mcmFirst + 9
let bmSetImage: UINT = 0x00f7
let bsBitmap: DWORD = 0x0080
let udsWrap: DWORD = 0x0001
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

// MARK: - Activation contexts (ComCtl32 v6 visual styles, plan 8.2)

/// Activation-context descriptor for `CreateActCtxW`.
struct ACTCTXW {
    var cbSize: DWORD = 0
    var dwFlags: DWORD = 0
    var lpSource: UnsafePointer<UInt16>?
    var wProcessorArchitecture: UInt16 = 0
    var wLangId: UInt16 = 0
    var lpAssemblyDirectory: UnsafePointer<UInt16>?
    var lpResourceName: UnsafePointer<UInt16>?
    var lpApplicationName: UnsafePointer<UInt16>?
    var hModule: HINSTANCE?
}

@_silgen_name("CreateActCtxW")
func winCreateActCtxW(_ activationContext: UnsafePointer<ACTCTXW>) -> UnsafeMutableRawPointer?

@_silgen_name("ActivateActCtx")
func winActivateActCtx(_ activationContext: UnsafeMutableRawPointer?, _ cookie: UnsafeMutablePointer<UInt>) -> Int32
#endif
