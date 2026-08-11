//  Win32FFI.swift
//
//  The manually-declared Win32 FFI surface for the WinChocolate native backend.
//  The toolchain cannot import WinSDK, so the Win32 typealiases, C struct
//  layouts, function declarations, and message/style constants used by
//  Win32NativeControlBackend are declared by hand here, along with the
//  wide-string bridging helpers.

#if os(Windows)
@_exported import CWin32Compat
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

struct WinUInt16Buffer32 {
    var v00: UInt16 = 0
    var v01: UInt16 = 0
    var v02: UInt16 = 0
    var v03: UInt16 = 0
    var v04: UInt16 = 0
    var v05: UInt16 = 0
    var v06: UInt16 = 0
    var v07: UInt16 = 0
    var v08: UInt16 = 0
    var v09: UInt16 = 0
    var v10: UInt16 = 0
    var v11: UInt16 = 0
    var v12: UInt16 = 0
    var v13: UInt16 = 0
    var v14: UInt16 = 0
    var v15: UInt16 = 0
    var v16: UInt16 = 0
    var v17: UInt16 = 0
    var v18: UInt16 = 0
    var v19: UInt16 = 0
    var v20: UInt16 = 0
    var v21: UInt16 = 0
    var v22: UInt16 = 0
    var v23: UInt16 = 0
    var v24: UInt16 = 0
    var v25: UInt16 = 0
    var v26: UInt16 = 0
    var v27: UInt16 = 0
    var v28: UInt16 = 0
    var v29: UInt16 = 0
    var v30: UInt16 = 0
    var v31: UInt16 = 0
}

struct WinInt32Buffer32 {
    var v00: Int32 = 0
    var v01: Int32 = 0
    var v02: Int32 = 0
    var v03: Int32 = 0
    var v04: Int32 = 0
    var v05: Int32 = 0
    var v06: Int32 = 0
    var v07: Int32 = 0
    var v08: Int32 = 0
    var v09: Int32 = 0
    var v10: Int32 = 0
    var v11: Int32 = 0
    var v12: Int32 = 0
    var v13: Int32 = 0
    var v14: Int32 = 0
    var v15: Int32 = 0
    var v16: Int32 = 0
    var v17: Int32 = 0
    var v18: Int32 = 0
    var v19: Int32 = 0
    var v20: Int32 = 0
    var v21: Int32 = 0
    var v22: Int32 = 0
    var v23: Int32 = 0
    var v24: Int32 = 0
    var v25: Int32 = 0
    var v26: Int32 = 0
    var v27: Int32 = 0
    var v28: Int32 = 0
    var v29: Int32 = 0
    var v30: Int32 = 0
    var v31: Int32 = 0
}

struct WinUInt8Buffer32 {
    var v00: UInt8 = 0
    var v01: UInt8 = 0
    var v02: UInt8 = 0
    var v03: UInt8 = 0
    var v04: UInt8 = 0
    var v05: UInt8 = 0
    var v06: UInt8 = 0
    var v07: UInt8 = 0
    var v08: UInt8 = 0
    var v09: UInt8 = 0
    var v10: UInt8 = 0
    var v11: UInt8 = 0
    var v12: UInt8 = 0
    var v13: UInt8 = 0
    var v14: UInt8 = 0
    var v15: UInt8 = 0
    var v16: UInt8 = 0
    var v17: UInt8 = 0
    var v18: UInt8 = 0
    var v19: UInt8 = 0
    var v20: UInt8 = 0
    var v21: UInt8 = 0
    var v22: UInt8 = 0
    var v23: UInt8 = 0
    var v24: UInt8 = 0
    var v25: UInt8 = 0
    var v26: UInt8 = 0
    var v27: UInt8 = 0
    var v28: UInt8 = 0
    var v29: UInt8 = 0
    var v30: UInt8 = 0
    var v31: UInt8 = 0
}

struct WinUInt8Buffer8: Equatable {
    var v00: UInt8 = 0
    var v01: UInt8 = 0
    var v02: UInt8 = 0
    var v03: UInt8 = 0
    var v04: UInt8 = 0
    var v05: UInt8 = 0
    var v06: UInt8 = 0
    var v07: UInt8 = 0
}

struct WinDWORDBuffer8 {
    var v00: DWORD = 0
    var v01: DWORD = 0
    var v02: DWORD = 0
    var v03: DWORD = 0
    var v04: DWORD = 0
    var v05: DWORD = 0
    var v06: DWORD = 0
    var v07: DWORD = 0
}

struct WinDWORDBuffer4 {
    var v00: DWORD = 0
    var v01: DWORD = 0
    var v02: DWORD = 0
    var v03: DWORD = 0
}

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
    var szFaceName = WinUInt16Buffer32()
}

#endif
