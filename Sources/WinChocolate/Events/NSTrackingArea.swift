/// A region of a view that generates mouse-tracking events, matching AppKit's
/// `NSTrackingArea`.
///
/// Add areas with `NSView.addTrackingArea(_:)`; the view resolves hover state
/// from native mouse movement and sends `mouseEntered(with:)` /
/// `mouseExited(with:)` to the area's owner (or the view itself when the owner
/// is not a responder).
open class NSTrackingArea: NSObject {
    /// Tracking-area behavior flags. Raw values match AppKit's.
    public struct Options: OptionSet, Sendable {
        /// The raw option bits.
        public let rawValue: UInt

        /// Creates options from raw bits.
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// Send `mouseEntered`/`mouseExited` events.
        public static let mouseEnteredAndExited = Options(rawValue: 0x01)

        /// Send `mouseMoved` events (the view already receives these natively;
        /// stored for source compatibility).
        public static let mouseMoved = Options(rawValue: 0x02)

        /// Track only while the view's window is key.
        public static let activeInKeyWindow = Options(rawValue: 0x20)

        /// Track regardless of window state.
        public static let activeAlways = Options(rawValue: 0x80)

        /// Track the view's whole visible bounds instead of `rect`.
        public static let inVisibleRect = Options(rawValue: 0x200)
    }

    /// The tracked rectangle in the view's coordinate space.
    public private(set) var rect: NSRect

    /// The area's behavior options.
    public private(set) var options: Options

    /// The object that receives the tracking events.
    open private(set) weak var owner: AnyObject?

    /// Application data carried by the area.
    public private(set) var userInfo: [String: Any]?

    /// Creates a tracking area.
    public init(rect: NSRect, options: Options, owner: AnyObject?, userInfo: [String: Any]? = nil) {
        self.rect = rect
        self.options = options
        self.owner = owner
        self.userInfo = userInfo
        super.init()
    }
}
