// Frame/content conversion, and the window notifications that go with it.
//
// Two AppKit facilities that only look like conveniences until an app tries to
// remember where its window was. A saved *frame* includes the chrome; a saved
// *content size* does not, and the two differ by a title bar and possibly a
// toolbar — so restoring one as the other grows or shrinks the window a little
// on every launch. AppKit answers that with `frameRect(forContentRect:)` and
// its inverse, and tells you when to save with the window notifications.

import Foundation

extension NSWindow {
    /// Posted after the window's size changes.
    public static let didResizeNotification = Notification.Name("NSWindowDidResizeNotification")

    /// Posted after the window is moved.
    public static let didMoveNotification = Notification.Name("NSWindowDidMoveNotification")

    /// Posted when a live resize finishes.
    ///
    /// A backend with no distinct live-resize phase posts it with the resize,
    /// so a listener that saves here saves once per gesture rather than never.
    public static let didEndLiveResizeNotification =
        Notification.Name("NSWindowDidEndLiveResizeNotification")

    /// Posted as the window closes.
    public static let willCloseNotification = Notification.Name("NSWindowWillCloseNotification")

    /// The chrome this window adds around its content.
    ///
    /// The title bar's thickness is the backend's business; the toolbar's is
    /// ours, and it only counts when the toolbar is actually shown.
    private var winChromeHeight: CGFloat {
        let titleBar: CGFloat = styleMask.contains(.titled) ? 28 : 0
        let toolbarStrip: CGFloat = toolbar?.isVisible == true ? resolvedToolbarHeight : 0
        return titleBar + toolbarStrip
    }

    /// The window frame that would give this content rectangle.
    public func frameRect(forContentRect contentRect: NSRect) -> NSRect {
        NSRect(x: contentRect.origin.x,
               y: contentRect.origin.y,
               width: contentRect.size.width,
               height: contentRect.size.height + winChromeHeight)
    }

    /// The content rectangle inside this window frame.
    ///
    /// Clamped at zero: a frame smaller than its own chrome describes a window
    /// with negative content, and handing that back would put a negative size
    /// into whatever the caller does next.
    public func contentRect(forFrameRect frameRect: NSRect) -> NSRect {
        NSRect(x: frameRect.origin.x,
               y: frameRect.origin.y,
               width: frameRect.size.width,
               height: max(0, frameRect.size.height - winChromeHeight))
    }

    /// Posts a window notification to the default center.
    ///
    /// The delegate calls and these notifications are the same event told
    /// twice, because AppKit tells it twice: a window's own delegate hears
    /// about it, and so does anything that registered an observer. An app that
    /// is not the window's delegate — a frame store watching every window —
    /// only has the second.
    internal func winPost(_ name: Notification.Name) {
        NotificationCenter.default.post(name: name, object: self)
    }
}

extension NSApplication {
    /// Posted as the application is about to exit.
    public static let willTerminateNotification =
        Notification.Name("NSApplicationWillTerminateNotification")

    /// Posted once the application has finished launching.
    public static let didFinishLaunchingNotification =
        Notification.Name("NSApplicationDidFinishLaunchingNotification")
}
