/// Base event value used for future input dispatch.
///
/// Native keyboard and mouse messages enter WinChocolate at the backend layer
/// and are translated into `NSEvent` instances before reaching views.
public struct NSEvent: Equatable {
    /// Supported event categories.
    public enum EventType: Equatable, Sendable {
        /// A left mouse button press.
        case leftMouseDown

        /// A left mouse button release.
        case leftMouseUp

        /// Mouse movement.
        case mouseMoved

        /// Mouse movement while the left mouse button is down.
        case leftMouseDragged

        /// A right mouse button press.
        case rightMouseDown

        /// A right mouse button release.
        case rightMouseUp

        /// A tertiary (middle) mouse button press.
        case otherMouseDown

        /// A tertiary (middle) mouse button release.
        case otherMouseUp

        /// A scroll wheel movement.
        case scrollWheel

        /// A key press.
        case keyDown

        /// A key release.
        case keyUp

        /// The cursor entered a tracking area.
        case mouseEntered

        /// The cursor left a tracking area.
        case mouseExited
    }

    /// The event category.
    public var type: EventType

    /// The event location in window coordinates.
    public var locationInWindow: NSPoint

    /// Native key code for keyboard events. Matching AppKit, this is a plain
    /// `UInt16` that reads `0` for events that carry no key code.
    public var keyCode: UInt16

    /// Characters represented by a keyboard event, when available.
    public var characters: String?

    /// Modifier keys active during the event.
    public var modifierFlags: ModifierFlags

    /// The number of rapid clicks for mouse button events.
    public var clickCount: Int

    /// Horizontal scroll amount in wheel lines for scroll events.
    public var scrollingDeltaX: CGFloat

    /// Vertical scroll amount in wheel lines for scroll events.
    public var scrollingDeltaY: CGFloat

    /// Legacy horizontal scroll delta, aliasing `scrollingDeltaX`.
    public var deltaX: CGFloat { scrollingDeltaX }

    /// Legacy vertical scroll delta, aliasing `scrollingDeltaY`.
    public var deltaY: CGFloat { scrollingDeltaY }

    /// Which mouse button an `otherMouse*` event carries.
    ///
    /// Derived rather than stored: AppKit numbers the buttons 0 left, 1 right,
    /// 2 and up for the rest, and the event type already says which it was.
    public var buttonNumber: Int {
        switch type {
        case .leftMouseDown, .leftMouseUp, .leftMouseDragged:
            return 0
        case .rightMouseDown, .rightMouseUp:
            return 1
        case .otherMouseDown, .otherMouseUp:
            return 2
        default:
            return 0
        }
    }

    /// The gesture phase of a scroll or gesture event.
    ///
    /// Empty by default, which is exactly what AppKit reports for a scroll from
    /// a wheel mouse — phases come from a trackpad, and no Chocolate backend
    /// has one to report from yet. Code that switches on the phase therefore
    /// takes the same branch it takes on a Mac with a mouse plugged in, rather
    /// than a branch that does not exist.
    public var phase: Phase = []

    /// The momentum phase of a scroll event, after the fingers have lifted.
    public var momentumPhase: Phase = []

    /// A timeout meaning "until the tracking loop is told to stop".
    public static let foreverDuration: TimeInterval = .greatestFiniteMagnitude

    /// Gesture phases, matching AppKit's names.
    public struct Phase: OptionSet, Sendable {
        /// Raw option value.
        public let rawValue: UInt

        /// Creates a phase from a raw value.
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// The gesture may be about to begin.
        public static let mayBegin = Phase(rawValue: 1 << 0)
        /// The gesture began.
        public static let began = Phase(rawValue: 1 << 1)
        /// The gesture moved.
        public static let changed = Phase(rawValue: 1 << 2)
        /// The gesture paused with the fingers still down.
        public static let stationary = Phase(rawValue: 1 << 3)
        /// The gesture ended.
        public static let ended = Phase(rawValue: 1 << 4)
        /// The gesture was cancelled.
        public static let cancelled = Phase(rawValue: 1 << 5)
    }

    /// Event categories as a set, for the APIs that match against several.
    public struct EventTypeMask: OptionSet, Sendable {
        /// Raw option value.
        public let rawValue: UInt64

        /// Creates a mask from a raw value.
        public init(rawValue: UInt64) {
            self.rawValue = rawValue
        }

        /// A left mouse button press.
        public static let leftMouseDown = EventTypeMask(rawValue: 1 << 1)
        /// A left mouse button release.
        public static let leftMouseUp = EventTypeMask(rawValue: 1 << 2)
        /// A right mouse button press.
        public static let rightMouseDown = EventTypeMask(rawValue: 1 << 3)
        /// A right mouse button release.
        public static let rightMouseUp = EventTypeMask(rawValue: 1 << 4)
        /// Mouse movement.
        public static let mouseMoved = EventTypeMask(rawValue: 1 << 5)
        /// Movement with the left button down.
        public static let leftMouseDragged = EventTypeMask(rawValue: 1 << 6)
        /// A key press.
        public static let keyDown = EventTypeMask(rawValue: 1 << 10)
        /// A key release.
        public static let keyUp = EventTypeMask(rawValue: 1 << 11)
        /// A scroll wheel movement.
        public static let scrollWheel = EventTypeMask(rawValue: 1 << 22)

        /// Whether this mask matches an event's category.
        public func winMatches(_ type: EventType) -> Bool {
            switch type {
            case .leftMouseDown: return contains(.leftMouseDown)
            case .leftMouseUp: return contains(.leftMouseUp)
            case .rightMouseDown: return contains(.rightMouseDown)
            case .rightMouseUp: return contains(.rightMouseUp)
            case .mouseMoved: return contains(.mouseMoved)
            case .leftMouseDragged: return contains(.leftMouseDragged)
            case .keyDown: return contains(.keyDown)
            case .keyUp: return contains(.keyUp)
            case .scrollWheel: return contains(.scrollWheel)
            default: return false
            }
        }
    }

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
        keyCode: UInt16 = 0,
        characters: String? = nil,
        modifierFlags: ModifierFlags = [],
        clickCount: Int = 1,
        scrollingDeltaX: CGFloat = 0,
        scrollingDeltaY: CGFloat = 0
    ) {
        self.type = type
        self.locationInWindow = locationInWindow
        self.keyCode = keyCode
        self.characters = characters
        self.modifierFlags = modifierFlags
        self.clickCount = clickCount
        self.scrollingDeltaX = scrollingDeltaX
        self.scrollingDeltaY = scrollingDeltaY
    }
}
