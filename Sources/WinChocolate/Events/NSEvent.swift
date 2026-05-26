/// Base event value used for future input dispatch.
///
/// Native keyboard and mouse messages enter WinChocolate at the backend layer
/// and are translated into `NSEvent` instances before reaching views.
public struct NSEvent: Equatable, Sendable {
    /// Supported event categories.
    public enum EventType: Equatable, Sendable {
        /// A left mouse button press.
        case leftMouseDown

        /// A left mouse button release.
        case leftMouseUp

        /// A key press.
        case keyDown

        /// A key release.
        case keyUp
    }

    /// The event category.
    public var type: EventType

    /// The event location in window coordinates.
    public var locationInWindow: NSPoint

    /// Creates an event.
    public init(type: EventType, locationInWindow: NSPoint) {
        self.type = type
        self.locationInWindow = locationInWindow
    }
}
