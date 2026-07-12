/// Minimal AppKit-shaped gesture recognizers driven from view mouse events.
///
/// A view forwards its `mouseDown`/`mouseDragged`/`mouseUp` events to every
/// attached recognizer (see `NSView.addGestureRecognizer`); each subclass
/// turns the raw sequence into its gesture and reports through the
/// Swift-native `onAction` closure (the stored `target`/`action` pair is
/// AppKit shape only — there is no ObjC dispatch here).
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

    /// Stored for AppKit shape; dispatch runs through `onAction`.
    open weak var target: AnyObject?

    /// Stored for AppKit shape; dispatch runs through `onAction`.
    open var action: Selector?

    /// Swift-native callback fired on every reported state change.
    open var onAction: ((NSGestureRecognizer) -> Void)?

    /// Whether the recognizer participates in events.
    open var isEnabled: Bool = true

    // The last event location in window coordinates.
    var winLastLocationInWindow: NSPoint = .zero

    /// Creates a recognizer. The target/action pair is stored for AppKit
    /// shape; wire `onAction` for dispatch.
    public init(target: AnyObject?, action: Selector?) {
        self.target = target
        self.action = action
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

    // Records the event location and fires the callback.
    func winReport(_ state: State, event: NSEvent) {
        self.state = state
        winLastLocationInWindow = event.locationInWindow
        onAction?(self)
    }
}

/// Recognizes a completed click within the view.
open class NSClickGestureRecognizer: NSGestureRecognizer {
    // Where the press started, to reject drags.
    private var downPoint: NSPoint?

    open override func mouseDown(with event: NSEvent) {
        downPoint = event.locationInWindow
    }

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
            self.onAction?(self)
        }
    }

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

    open override func mouseDown(with event: NSEvent) {
        guard isEnabled else {
            return
        }
        startPoint = event.locationInWindow
        winLastLocationInWindow = event.locationInWindow
    }

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
