#if os(Windows)
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

/// The page-setup dialog request/result (`PAGESETUPDLGW`).
///
/// Field order and the explicit padding follow the Win32 header: the struct is
/// passed by pointer to a C function, so a wrong layout is not a compile error
/// — it is a dialog that reads garbage. `padding` entries sit where the ABI
/// inserts alignment between a 32-bit field and the pointer that follows.
struct PAGESETUPDLGW {
    var lStructSize: DWORD = 0
    var padding: UInt32 = 0
    var hwndOwner: HWND?
    var hDevMode: UnsafeMutableRawPointer?
    var hDevNames: UnsafeMutableRawPointer?
    var flags: DWORD = 0
    var padding2: UInt32 = 0
    var ptPaperSize: POINT = POINT()
    var rtMinMargin: RECT = RECT()
    var rtMargin: RECT = RECT()
    var hInstance: UnsafeMutableRawPointer?
    var lCustData: LPARAM = 0
    var lpfnPageSetupHook: UnsafeMutableRawPointer?
    var lpfnPagePaintHook: UnsafeMutableRawPointer?
    var lpPageSetupTemplateName: UnsafePointer<UInt16>?
    var hPageSetupTemplate: UnsafeMutableRawPointer?
}

/// PageSetupDlg flags: honour the margins we pass in, and speak hundredths of
/// a millimetre so the numbers coming back need no locale guessing.
let psdMargins: DWORD = 0x0000_0002
let psdInHundredthsOfMillimeters: DWORD = 0x0000_0008

@_silgen_name("PageSetupDlgW")
func winPageSetupDlgW(_ pageSetup: UnsafeMutablePointer<PAGESETUPDLGW>?) -> Int32

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
    var data4 = WinUInt8Buffer8()

    static func == (lhs: COMGUID, rhs: COMGUID) -> Bool {
        lhs.data1 == rhs.data1 && lhs.data2 == rhs.data2 && lhs.data3 == rhs.data3
            && lhs.data4 == rhs.data4
    }
}

/// IID_IUnknown.
let iidIUnknown = COMGUID(data1: 0x0000_0000, data2: 0, data3: 0, data4: WinUInt8Buffer8(v00: 0xC0, v07: 0x46))
/// IID_IDropTarget.
let iidIDropTarget = COMGUID(data1: 0x0000_0122, data2: 0, data3: 0, data4: WinUInt8Buffer8(v00: 0xC0, v07: 0x46))
/// IID_IDropSource.
let iidIDropSource = COMGUID(data1: 0x0000_0121, data2: 0, data3: 0, data4: WinUInt8Buffer8(v00: 0xC0, v07: 0x46))
/// IID_IDataObject.
let iidIDataObject = COMGUID(data1: 0x0000_010E, data2: 0, data3: 0, data4: WinUInt8Buffer8(v00: 0xC0, v07: 0x46))

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
    var rgxTabs = WinInt32Buffer32()
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
    var lfFaceName = WinUInt16Buffer32()
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
    var rgbReserved = WinUInt8Buffer32()
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
    // C pads NMHDR to 24 bytes on 64-bit (alignment 8); Swift's layout stops
    // at 20 without this, shifting every field of the NM* structs that embed
    // NMHDR four bytes early (observed: NMUPDOWN.iDelta reading the real
    // iPos, which froze steppers).
    private var winTrailingPadding: UINT = 0
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

/// `NMCUSTOMDRAW` — the custom-draw notification payload (used to give the
/// dark list-view header light title text).
struct NMCUSTOMDRAW {
    var hdr: NMHDR = NMHDR()
    var dwDrawStage: DWORD = 0
    var hdc: HDC?
    var rc: RECT = RECT()
    var dwItemSpec: UInt = 0
    var uItemState: UINT = 0
    var lItemlParam: LPARAM = 0
}

/// `NMLVCUSTOMDRAW` — the list-view custom-draw payload. Only the leading
/// fields are declared (the color pair the framework rewrites); the C struct
/// continues with subitem/icon fields the framework never touches, and the
/// pointer received through `WM_NOTIFY` always references the full C struct.
struct NMLVCUSTOMDRAW {
    var nmcd: NMCUSTOMDRAW = NMCUSTOMDRAW()
    var clrText: DWORD = 0
    var clrTextBk: DWORD = 0
}

/// `NM_CUSTOMDRAW` (NM_FIRST − 12, as an unsigned notification code).
let nmCustomDraw: UINT = 0xFFFF_FFF4
let cddsPrePaint: DWORD = 0x0000_0001
let cddsItemPrePaint: DWORD = 0x0001_0001
let cdisSelected: UINT = 0x0001
let cdrfDoDefault: LRESULT = 0x0000_0000
let cdrfSkipDefault: LRESULT = 0x0000_0004
let cdrfNotifyItemDraw: LRESULT = 0x0000_0020

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

/// `DWMWA_WINDOW_CORNER_PREFERENCE` (Windows 11) and `DWMWCP_ROUND`.
let winDWMWAWindowCornerPreference: DWORD = 33
let winDWMWCPRound: Int32 = 2

// Visual-styles subclass selection (UxTheme) — used for dark control themes.
@_silgen_name("SetWindowTheme")
func winSetWindowTheme(
    _ hwnd: HWND?,
    _ subAppName: UnsafePointer<UInt16>?,
    _ subIdList: UnsafePointer<UInt16>?
) -> Int32

#endif
