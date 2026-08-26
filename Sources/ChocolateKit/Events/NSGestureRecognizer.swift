/// Minimal AppKit-shaped gesture recognizers driven from view mouse events.
///
/// A view forwards its `mouseDown`/`mouseDragged`/`mouseUp` events to every
/// attached recognizer (see `NSView.addGestureRecognizer`); each subclass
/// turns the raw sequence into its gesture and dispatches the real
/// `target`/`action` selector on each state change, as AppKit does (see
/// `NSObject`'s selector-dispatch note).
///
/// The classic slice covers what ported UI reaches for: click, press-and-
/// hold, and pan. Magnification exists for API shape but never fires — the
/// classic Win32 mouse pipeline has no pinch source.
open class NSGestureRecognizer {
    /// The recognizer's lifecycle state, matching AppKit's names.
    public enum State: Sendable {
        case possible
        case began
        case changed
        case ended
        case cancelled
        case failed
    }

    /// The current lifecycle state.
    open var state: State = .possible

    /// The view the recognizer is attached to.
    open internal(set) weak var view: NSView?

    /// The object that receives the recognizer's action.
    open weak var target: AnyObject?

    /// The selector sent to `target` on every reported state change.
    open var action: Selector?

    /// The delegate consulted before and during recognition.
    open weak var delegate: NSGestureRecognizerDelegate?

    /// Whether a mouse-down that begins this gesture is also delivered to the
    /// view underneath.
    ///
    /// Stored: no backend here delays a press waiting to see whether a gesture
    /// claims it, so the press is always delivered. The property keeps a
    /// caller's intent rather than making it discover the difference.
    open var delaysPrimaryMouseButtonEvents: Bool = false

    /// Whether the recognizer participates in events.
    open var isEnabled: Bool = true

    // The last event location in window coordinates.
    var winLastLocationInWindow: NSPoint = .zero

    /// Creates a recognizer with AppKit's real target/action dispatch: the
    /// action selector is sent to the target on each state change.
    public init(target: AnyObject?, action: Selector?) {
        self.target = target
        self.action = action
    }

    /// Dispatches the recognizer's action selector to its target (or down
    /// the responder chain when the target is nil), as AppKit does.
    func winSendAction() {
        guard let action else {
            return
        }

        _ = NSApplication.shared.sendAction(action, to: target, from: self)
    }

    /// The last event location in a view's coordinate space (the window's
    /// space for `nil`).
    open func location(in view: NSView?) -> NSPoint {
        guard let view else {
            return winLastLocationInWindow
        }
        return view.convert(winLastLocationInWindow, from: nil)
    }

    /// Handles a press in the attached view. Subclasses override.
    open func mouseDown(with event: NSEvent) {}

    /// Handles a drag in the attached view. Subclasses override.
    open func mouseDragged(with event: NSEvent) {}

    /// Handles a release in the attached view. Subclasses override.
    open func mouseUp(with event: NSEvent) {}

    /// Handles a secondary press. Subclasses override.
    ///
    /// A recognizer sees the whole button set, not just the primary one:
    /// right-click context menus and middle-click-to-close are both built by
    /// overriding here, and a recognizer missing them would push that work back
    /// into every view.
    open func rightMouseDown(with event: NSEvent) {}

    /// Handles a secondary release. Subclasses override.
    open func rightMouseUp(with event: NSEvent) {}

    /// Handles a tertiary press. Subclasses override.
    open func otherMouseDown(with event: NSEvent) {}

    /// Handles a tertiary release. Subclasses override.
    open func otherMouseUp(with event: NSEvent) {}

    // Records the event location and dispatches the action.
    func winReport(_ state: State, event: NSEvent) {
        self.state = state
        winLastLocationInWindow = event.locationInWindow
        winSendAction()
    }
}

/// Recognizes a completed click within the view.
open class NSClickGestureRecognizer: NSGestureRecognizer {
    // Where the press started, to reject drags.
    private var downPoint: NSPoint?

    /// Records the initial press location for click recognition.
    open override func mouseDown(with event: NSEvent) {
        downPoint = event.locationInWindow
    }

    /// Completes recognition when the pointer is released without a drag.
    open override func mouseUp(with event: NSEvent) {
        guard isEnabled, let downPoint else {
            return
        }
        self.downPoint = nil

        // A click is a release near its press (a small slop, like AppKit).
        let dx = event.locationInWindow.x - downPoint.x
        let dy = event.locationInWindow.y - downPoint.y
        guard abs(dx) <= 4, abs(dy) <= 4 else {
            state = .failed
            return
        }
        winReport(.ended, event: event)
        state = .possible
    }
}

/// Recognizes a press held for `minimumPressDuration`.
open class NSPressGestureRecognizer: NSGestureRecognizer {
    /// How long the press must hold before recognition, in seconds.
    open var minimumPressDuration: TimeInterval = 0.5

    private var holdTimer: Timer?
    private var isPressed = false

    /// Starts press recognition and its minimum-duration timer.
    open override func mouseDown(with event: NSEvent) {
        guard isEnabled else {
            return
        }
        isPressed = true
        winLastLocationInWindow = event.locationInWindow
        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: minimumPressDuration, repeats: false) { [weak self] _ in
            guard let self, self.isPressed else {
                return
            }
            self.state = .began
            self.winSendAction()
        }
    }

    /// Finishes or cancels the active press recognition.
    open override func mouseUp(with event: NSEvent) {
        holdTimer?.invalidate()
        holdTimer = nil
        if state == .began {
            winReport(.ended, event: event)
        }
        isPressed = false
        state = .possible
    }
}

/// Recognizes a drag, reporting the translation from its start point.
open class NSPanGestureRecognizer: NSGestureRecognizer {
    private var startPoint: NSPoint?

    /// The drag's total translation in a view's coordinate space.
    ///
    /// The classic pipeline has no per-view transforms beyond origin
    /// offsets, so window-space deltas are view-space deltas.
    open func translation(in view: NSView?) -> NSPoint {
        guard let startPoint else {
            return .zero
        }
        return NSPoint(
            x: winLastLocationInWindow.x - startPoint.x,
            y: winLastLocationInWindow.y - startPoint.y
        )
    }

    /// Begins tracking a possible pan gesture.
    open override func mouseDown(with event: NSEvent) {
        guard isEnabled else {
            return
        }
        startPoint = event.locationInWindow
        winLastLocationInWindow = event.locationInWindow
    }

    /// Updates the pan gesture with the pointer's latest location.
    open override func mouseDragged(with event: NSEvent) {
        guard isEnabled, startPoint != nil else {
            return
        }
        if state == .possible {
            winReport(.began, event: event)
        } else {
            winReport(.changed, event: event)
        }
    }

    /// Ends the active pan gesture.
    open override func mouseUp(with event: NSEvent) {
        guard startPoint != nil else {
            return
        }
        if state == .began || state == .changed {
            winReport(.ended, event: event)
        }
        startPoint = nil
        state = .possible
    }
}

/// Magnification recognizer, for API shape.
///
/// The classic Win32 mouse pipeline carries no pinch input, so this
/// recognizer never fires; `magnification` stays 0.
open class NSMagnificationGestureRecognizer: NSGestureRecognizer {
    /// The accumulated magnification delta (0 = unchanged).
    open var magnification: CGFloat = 0
}

/// A two-finger rotation gesture.
///
/// No Chocolate backend reports a rotation yet — Win32 and GTK deliver wheel
/// and pointer events, and a browser reports pointers rather than gestures. The
/// recognizer exists so a view that wants rotation can attach one and read
/// `rotation` from its action; it stays `.possible` until a backend can drive
/// it, which is the state AppKit's own recognizer sits in when nothing rotates.
open class NSRotationGestureRecognizer: NSGestureRecognizer {
    /// The accumulated rotation in radians (0 = unchanged).
    open var rotation: CGFloat = 0

    /// The rotation in degrees, matching AppKit's convenience.
    open var rotationInDegrees: CGFloat {
        rotation * 180 / .pi
    }
}

/// What a recognizer asks its delegate, matching AppKit's protocol.
///
/// Every requirement has a default, as AppKit's does, so a delegate implements
/// only the questions it cares about.
@MainActor
public protocol NSGestureRecognizerDelegate: AnyObject {
    /// Whether the recognizer should attempt to recognize this event at all.
    func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer,
                           shouldAttemptToRecognizeWith event: NSEvent) -> Bool

    /// Whether the recognizer should begin interpreting the gesture.
    func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool

    /// Whether two recognizers may recognize at the same time.
    func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: NSGestureRecognizer) -> Bool
}

public extension NSGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer,
                           shouldAttemptToRecognizeWith event: NSEvent) -> Bool { true }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: NSGestureRecognizer) -> Bool { true }

    func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: NSGestureRecognizer) -> Bool { false }
}

extension NSView {
    /// The gesture recognizers attached to this view.
    public internal(set) var gestureRecognizers: [NSGestureRecognizer] {
        get { winGestureRecognizers }
        set { winGestureRecognizers = newValue }
    }

    /// Attaches a gesture recognizer, matching AppKit's shape. The view
    /// forwards its mouse events to every attached recognizer.
    public func addGestureRecognizer(_ gestureRecognizer: NSGestureRecognizer) {
        gestureRecognizer.view = self
        winGestureRecognizers.append(gestureRecognizer)
    }

    /// Detaches a gesture recognizer.
    public func removeGestureRecognizer(_ gestureRecognizer: NSGestureRecognizer) {
        winGestureRecognizers.removeAll { $0 === gestureRecognizer }
        if gestureRecognizer.view === self {
            gestureRecognizer.view = nil
        }
    }
}
