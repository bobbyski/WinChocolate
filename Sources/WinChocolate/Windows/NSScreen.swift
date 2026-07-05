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
