#if os(Windows)
let wmDestroy: UINT = 0x0002
let wmClose: UINT = 0x0010
let wmSize: UINT = 0x0005
let wmNotify: UINT = 0x004e
let wmPaint: UINT = 0x000f
let wmEraseBackground: UINT = 0x0014
let wmSetFont: UINT = 0x0030
let wmGetFont: UINT = 0x0031
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
let dtRight: UINT = 0x00000002
let dtVCenter: UINT = 0x00000004
let dtWordBreak: UINT = 0x00000010
let dtSingleLine: UINT = 0x00000020
let dtNoPrefix: UINT = 0x00000800
let dtCalcRect: UINT = 0x00000400
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
let pbmSetBkColor: UINT = 0x2001 // CCM_SETBKCOLOR
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
let lvmGetItemState: UINT = lvmFirst + 44
let lvmSubItemHitTest: UINT = lvmFirst + 57
let lvmInsertItemW: UINT = lvmFirst + 77
let lvmInsertColumnW: UINT = lvmFirst + 97
let lvmSetItemTextW: UINT = lvmFirst + 116
let lvmSetExtendedListViewStyle: UINT = lvmFirst + 54
/// List-view color messages (the dark row background/text under dark).
let lvmSetBkColor: UINT = lvmFirst + 1
let lvmSetTextColor: UINT = lvmFirst + 36
let lvmSetTextBkColor: UINT = lvmFirst + 38
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
/// NM_DBLCLK = NM_FIRST(0) - 3.
let nmDblclk: UINT = 0xfffffffd
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
let hdmGetItemCount: UINT = hdmFirst + 0
let hdmGetItemRect: UINT = hdmFirst + 7
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
let dtmSetRange: UINT = dtmFirst + 4
let dtmSetFormatW: UINT = dtmFirst + 50
let gdtValid: WPARAM = 0
/// `GDTR_MIN`/`GDTR_MAX` — which halves of a `DTM_SETRANGE` pair are set.
let gdtrMin: WPARAM = 0x0001
let gdtrMax: WPARAM = 0x0002
/// `DTS_UPDOWN` — the field carries a stepper instead of a drop-down calendar,
/// which is AppKit's `.textFieldAndStepper`.
let dtsUpDown: DWORD = 0x0001
let mcmFirst: UINT = 0x1000
let mcmGetCurSel: UINT = mcmFirst + 1
let mcmSetCurSel: UINT = mcmFirst + 2
let mcmSetRange: UINT = mcmFirst + 7
let mcmGetMinReqRect: UINT = mcmFirst + 9
/// `MCM_SETCOLOR` and its color-part indexes (dark calendar palette).
let mcmSetColor: UINT = mcmFirst + 10
let mcscBackground: Int = 0
let mcscText: Int = 1
let mcscTitleBk: Int = 2
let mcscTitleText: Int = 3
let mcscMonthBk: Int = 4
let mcscTrailingText: Int = 5
/// `DTM_SETMCCOLOR` (the date-time picker's drop-down calendar palette).
let dtmSetMCColor: UINT = 0x1006
/// `DTM_GETMONTHCAL`: the live drop-down calendar's window, while dropped.
let dtmGetMonthCal: UINT = 0x1008
/// `DTN_DROPDOWN`: the picker's calendar is about to appear.
let dtnDropDown: UINT = UInt32(bitPattern: -754)
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
/// For a window that is not `WS_CHILD` this sets the window's *owner*, not its
/// parent — which is how Win32 spells AppKit's panel-to-owner relationship.
let gwlpHwndParent: Int32 = -8
let gwChild: UINT = 5
let gwHwndNext: UINT = 2
let wmSettingChange: UINT = 0x001A
/// WM_DPICHANGED: a window moved to a display with a different DPI (10.7).
let wmDpiChanged: UINT = 0x02E0
let rdwFrame: UINT = 0x0400
let clrDefault: DWORD = 0xFF00_0000
let gclpHbrBackground: Int32 = -10

@_silgen_name("GetClassNameW")
func winGetClassNameW(_ hwnd: HWND?, _ buffer: UnsafeMutablePointer<UInt16>, _ maxCount: Int32) -> Int32

@_silgen_name("SetClassLongPtrW")
func winSetClassLongPtrW(_ hwnd: HWND?, _ index: Int32, _ value: LONG_PTR) -> LONG_PTR

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
