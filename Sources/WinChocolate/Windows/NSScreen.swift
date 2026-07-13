/// A display attached to the computer, matching AppKit's `NSScreen`.
///
/// Frames come from the backend's monitor enumeration. `frame` is the full
/// display rectangle; `visibleFrame` excludes the taskbar and docked bars.
/// WinChocolate uses top-left screen coordinates throughout, matching the
/// platform, so `frame.origin` for the primary screen is `(0, 0)`.
open class NSScreen: NSObject {
    /// The display's full frame.
    public let frame: NSRect

    /// The display's frame excluding the taskbar and docked bars.
    public let visibleFrame: NSRect

    /// The display's pixel-per-point scale.
    ///
    /// The classic backend enumerates monitors in logical (DPI-virtualized)
    /// coordinates, so points are the working unit and the factor is 1.
    /// Per-monitor DPI awareness would surface real scales here.
    open var backingScaleFactor: CGFloat { 1 }

    /// The real device scale factor of the primary display (device pixels per
    /// logical point) read from the system DPI — 1.0 at 96 DPI, 1.5 at 144 DPI
    /// (10.7). This surfaces the physical scale even while the process runs
    /// DPI-virtualized; the coordinated point→device-pixel scaling and
    /// per-monitor-v2 declaration are tracked on plan item 10.7.
    open var winDisplayScale: CGFloat {
        NSApplication.shared.nativeBackend.winDisplayScale()
    }

    init(frame: NSRect, visibleFrame: NSRect) {
        self.frame = frame
        self.visibleFrame = visibleFrame
        super.init()
    }

    /// All attached displays, the primary display first.
    open class var screens: [NSScreen] {
        NSApplication.shared.nativeBackend.screenDescriptions().map {
            NSScreen(frame: $0.frame, visibleFrame: $0.visibleFrame)
        }
    }

    /// The screen containing the key window, approximated by the primary
    /// display (the classic backend does not yet track per-window monitors).
    open class var main: NSScreen? {
        screens.first
    }

    /// The primary display (whose origin is the coordinate origin).
    open class var primary: NSScreen? {
        screens.first
    }
}
