#if os(Windows)
// MARK: - Per-monitor DPI awareness (10.7)

/// DPI_AWARENESS_CONTEXT is an opaque handle passed by value; the well-known
/// per-monitor-v2 handle is -4 (as a pointer-sized sentinel), system-aware -2.
let winDpiAwarenessPerMonitorV2 = UnsafeMutableRawPointer(bitPattern: Int(bitPattern: UInt(bitPattern: -4)))
let winDpiAwarenessSystem = UnsafeMutableRawPointer(bitPattern: Int(bitPattern: UInt(bitPattern: -2)))

/// Opts the process into a DPI-awareness mode (Windows 10 1703+). Returns
/// nonzero on success.
@_silgen_name("SetProcessDpiAwarenessContext")
func winSetProcessDpiAwarenessContext(_ context: UnsafeMutableRawPointer?) -> Int32

/// Legacy fallback: system-DPI awareness (Vista+).
@_silgen_name("SetProcessDPIAware")
func winSetProcessDPIAware() -> Int32

/// The DPI of the display that a window is on (Windows 10 1607+). 96 = 100%.
@_silgen_name("GetDpiForWindow")
func winGetDpiForWindow(_ hwnd: HWND?) -> UINT

/// The system DPI (Windows 10 1607+). 96 = 100%.
@_silgen_name("GetDpiForSystem")
func winGetDpiForSystem() -> UINT

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


@_silgen_name("SetWindowTextW")
func winSetWindowTextW(_ hwnd: HWND?, _ text: UnsafePointer<UInt16>?) -> Int32

@_silgen_name("GetWindowTextW")
func winGetWindowTextW(_ hwnd: HWND?, _ text: UnsafeMutablePointer<UInt16>?, _ maxCount: Int32) -> Int32

@_silgen_name("GetWindowTextLengthW")
func winGetWindowTextLengthW(_ hwnd: HWND?) -> Int32

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


@_silgen_name("DeleteDC")
func winDeleteDC(_ deviceContext: HDC?) -> Int32

@_silgen_name("SetStretchBltMode")
func winSetStretchBltMode(_ deviceContext: HDC?, _ mode: Int32) -> Int32


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


@_silgen_name("GdipSetLinePresetBlend")
func winGdipSetLinePresetBlend(
    _ brush: UnsafeMutableRawPointer?,
    _ blend: UnsafePointer<UInt32>?,
    _ positions: UnsafePointer<Float>?,
    _ count: Int32
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

@_silgen_name("MonitorFromWindow")
func winMonitorFromWindow(_ hwnd: HWND?, _ flags: DWORD) -> UnsafeMutableRawPointer?

/// `MonitorFromWindow` flag: return the display nearest the window.
let monitorDefaultToNearest: DWORD = 0x0000_0002
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
/// Rich edit: EM_GETCHARFORMAT (WM_USER + 58).
let emGetCharFormat: UINT = wmUser + 58
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

#endif
