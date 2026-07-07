/// A lightweight notification object for AppKit-compatible lifecycle callbacks.
public final class NSNotification: NSObject {
    /// The notification name.
    public let name: String

    /// The object associated with the notification.
    public let object: AnyObject?

    /// Extra notification data (e.g. the toolbar item behind AppKit's
    /// `toolbarWillAddItem` under the `"item"` key).
    public let userInfo: [AnyHashable: Any]?

    /// Creates a notification.
    public init(name: String, object: AnyObject?, userInfo: [AnyHashable: Any]? = nil) {
        self.name = name
        self.object = object
        self.userInfo = userInfo
        super.init()
    }
}
