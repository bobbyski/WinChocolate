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

        /// Mouse movement.
        case mouseMoved

        /// A key press.
        case keyDown

        /// A key release.
        case keyUp
    }

    /// The event category.
    public var type: EventType

    /// The event location in window coordinates.
    public var locationInWindow: NSPoint

    /// Native key code for keyboard events, when available.
    public var keyCode: UInt16?

    /// Characters represented by a keyboard event, when available.
    public var characters: String?

    /// Modifier keys active during the event.
    public var modifierFlags: ModifierFlags

    /// Keyboard modifier flags.
    public struct ModifierFlags: OptionSet, Sendable {
        /// Raw option value.
        public let rawValue: UInt

        /// Creates modifier flags from a raw value.
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// Shift key.
        public static let shift = ModifierFlags(rawValue: 1 << 0)

        /// Control key.
        public static let control = ModifierFlags(rawValue: 1 << 1)

        /// Option/Alt key.
        public static let option = ModifierFlags(rawValue: 1 << 2)

        /// Command/Windows key.
        public static let command = ModifierFlags(rawValue: 1 << 3)
    }

    /// Creates an event.
    public init(
        type: EventType,
        locationInWindow: NSPoint,
        keyCode: UInt16? = nil,
        characters: String? = nil,
        modifierFlags: ModifierFlags = []
    ) {
        self.type = type
        self.locationInWindow = locationInWindow
        self.keyCode = keyCode
        self.characters = characters
        self.modifierFlags = modifierFlags
    }
}
