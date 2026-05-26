/// A lightweight notification object for AppKit-compatible lifecycle callbacks.
public final class NSNotification: NSObject {
    /// The notification name.
    public let name: String

    /// The object associated with the notification.
    public let object: AnyObject?

    /// Creates a notification.
    public init(name: String, object: AnyObject?) {
        self.name = name
        self.object = object
        super.init()
    }
}
