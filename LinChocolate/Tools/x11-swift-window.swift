// x11-swift-window.swift — stage 2b: the same single X11 window, from SWIFT.
//
// Sits between the C window test (2a) and any GTK/LinChocolate app. It proves
// swiftc can build and run a binary that links a real C library and talks to
// the Windows-side X server — without SwiftPM, without GTK, without Foundation.
// If 2a maps and this does not, the problem is Swift's C interop or runtime
// under WSL1, not X11.
//
// Build:  swiftc -I/usr/include x11-swift-window.swift -lX11 -o /tmp/xswin
// Run:    DISPLAY=127.0.0.1:0 /tmp/xswin

#if canImport(Glibc)
import Glibc
#endif

// Declared by hand rather than via a module map: this is deliberately the
// smallest possible Swift-to-C surface, so a failure here cannot be blamed on
// SwiftPM's system-library plumbing (which is what CGTK uses).
typealias XDisplay = OpaquePointer
typealias XWindow = UInt

@_silgen_name("XOpenDisplay") func XOpenDisplay(_ name: UnsafePointer<CChar>?) -> XDisplay?
@_silgen_name("XDefaultScreen") func XDefaultScreen(_ d: XDisplay) -> Int32
@_silgen_name("XRootWindow") func XRootWindow(_ d: XDisplay, _ s: Int32) -> XWindow
@_silgen_name("XBlackPixel") func XBlackPixel(_ d: XDisplay, _ s: Int32) -> UInt
@_silgen_name("XWhitePixel") func XWhitePixel(_ d: XDisplay, _ s: Int32) -> UInt
@_silgen_name("XCreateSimpleWindow") func XCreateSimpleWindow(
    _ d: XDisplay, _ parent: XWindow, _ x: Int32, _ y: Int32,
    _ w: UInt32, _ h: UInt32, _ borderWidth: UInt32,
    _ border: UInt, _ background: UInt) -> XWindow
@_silgen_name("XStoreName") func XStoreName(_ d: XDisplay, _ w: XWindow, _ name: UnsafePointer<CChar>) -> Int32
@_silgen_name("XMapWindow") func XMapWindow(_ d: XDisplay, _ w: XWindow) -> Int32
@_silgen_name("XFlush") func XFlush(_ d: XDisplay) -> Int32
@_silgen_name("XCloseDisplay") func XCloseDisplay(_ d: XDisplay) -> Int32

guard let display = XOpenDisplay(nil) else {
    fputs("cannot open display\n", stderr)
    exit(2)
}

let screen = XDefaultScreen(display)
let window = XCreateSimpleWindow(
    display, XRootWindow(display, screen), 140, 140, 400, 240, 1,
    XBlackPixel(display, screen), XWhitePixel(display, screen))
_ = "wsl1-x11-swift-test".withCString { XStoreName(display, window, $0) }
_ = XMapWindow(display, window)
_ = XFlush(display)
print("mapped \(window)")
fflush(stdout)

sleep(30)
_ = XCloseDisplay(display)
