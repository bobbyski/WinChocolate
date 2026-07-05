/// A progress indicator control.
///
/// This first slice supports the determinate bar style used by many AppKit
/// apps. The native Windows backend maps it to a progress bar control.
open class NSProgressIndicator: NSControl {
    /// Progress indicator visual style.
    public enum Style: Sendable {
        /// Horizontal bar progress indicator.
        case bar

        /// Spinning progress indicator placeholder.
        case spinning
    }

    /// The indicator's minimum value.
    open var minValue: Double {
        didSet {
            if maxValue < minValue {
                maxValue = minValue
            }
            doubleValue = clamped(doubleValue)
            syncRangeToNative()
        }
    }

    /// The indicator's maximum value.
    open var maxValue: Double {
        didSet {
            if minValue > maxValue {
                minValue = maxValue
            }
            doubleValue = clamped(doubleValue)
            syncRangeToNative()
        }
    }

    /// The indicator's current value.
    open var doubleValue: Double {
        didSet {
            doubleValue = clamped(doubleValue)
            objectValue = doubleValue
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setProgressIndicatorValue(doubleValue, for: nativeHandle)
        }
    }

    /// Whether the indicator is indeterminate.
    open var isIndeterminate: Bool {
        didSet {
            syncIndeterminateToNative()
        }
    }

    /// Visual style requested by the app.
    ///
    /// An indicator created with `.spinning` renders a framework-drawn spinner
    /// (twelve dots sweeping around the center). Switching style after the
    /// native peer exists keeps the realized peer and renders indeterminately.
    open var style: Style {
        didSet {
            syncIndeterminateToNative()
        }
    }

    /// Whether a stopped spinner stays visible, matching AppKit.
    open var isDisplayedWhenStopped: Bool = true {
        didSet {
            needsDisplay = true
        }
    }

    /// Whether the indicator is currently animating.
    open private(set) var isAnimating: Bool

    /// Whether this indicator realized the framework-drawn spinner view.
    private var usesSpinnerPeer = false

    /// The animation phase (leading dot index) for the spinner.
    private var spinnerPhase = 0

    /// The run-loop timer driving the spinner sweep while animating.
    private var spinnerTimer: Timer?

    /// Creates a progress indicator with a frame.
    public override init(frame frameRect: NSRect) {
        self.minValue = 0
        self.maxValue = 100
        self.doubleValue = 0
        self.isIndeterminate = false
        self.style = .bar
        self.isAnimating = false
        super.init(frame: frameRect)
        self.objectValue = doubleValue
    }

    /// Starts the indicator animation.
    open func startAnimation(_ sender: Any?) {
        isAnimating = true
        syncIndeterminateToNative()
        startSpinnerTimerIfNeeded()
    }

    /// Stops the indicator animation.
    open func stopAnimation(_ sender: Any?) {
        isAnimating = false
        syncIndeterminateToNative()
        spinnerTimer?.invalidate()
        spinnerTimer = nil
        needsDisplay = true
    }

    /// Advances the spinner sweep on a run-loop timer while animating.
    private func startSpinnerTimerIfNeeded() {
        guard usesSpinnerPeer, spinnerTimer == nil else {
            return
        }

        spinnerTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
            guard let self, self.isAnimating else {
                return
            }
            self.spinnerPhase = (self.spinnerPhase + 1) % 12
            self.needsDisplay = true
        }
    }

    /// Increments the current value.
    open func increment(by delta: Double) {
        doubleValue += delta
    }

    /// Creates the native progress peer.
    ///
    /// A `.spinning` indicator realizes a plain view and draws the spinner
    /// itself, the same framework-drawn pattern as the rating level indicator.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        if style == .spinning {
            usesSpinnerPeer = true
            return backend.createView(frame: frame, parent: parent)
        }
        return backend.createProgressIndicator(value: doubleValue, minValue: minValue, maxValue: maxValue, frame: frame, parent: parent)
    }

    /// Ensures range and value are synced after realization.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        if usesSpinnerPeer {
            needsDisplay = true
            startSpinnerTimerIfNeeded()
            return handle
        }
        backend.setProgressIndicatorRange(minValue: minValue, maxValue: maxValue, for: handle)
        backend.setProgressIndicatorValue(doubleValue, for: handle)
        backend.setProgressIndicatorIndeterminate(rendersIndeterminate, animating: isAnimating, for: handle)
        return handle
    }

    /// Unit directions for the twelve spinner dots, clockwise from 12 o'clock.
    private static let spinnerDirections: [(dx: CGFloat, dy: CGFloat)] = [
        (0, -1), (0.5, -0.8660254), (0.8660254, -0.5), (1, 0),
        (0.8660254, 0.5), (0.5, 0.8660254), (0, 1), (-0.5, 0.8660254),
        (-0.8660254, 0.5), (-1, 0), (-0.8660254, -0.5), (-0.5, -0.8660254),
    ]

    /// Draws the spinner: twelve dots around the center whose opacity fades
    /// behind the leading dot, sweeping clockwise while animating.
    open override func draw(_ dirtyRect: NSRect) {
        guard usesSpinnerPeer else {
            super.draw(dirtyRect)
            return
        }
        if !isAnimating && !isDisplayedWhenStopped {
            return
        }

        let width = frame.size.width
        let height = frame.size.height
        let center = NSPoint(x: width / 2, y: height / 2)
        let radius = min(width, height) / 2 - 2
        guard radius > 2 else {
            return
        }
        let dotRadius = max(1.5, radius * 0.18)
        let orbit = radius - dotRadius

        for (index, direction) in Self.spinnerDirections.enumerated() {
            // GDI fills are opaque, so the sweep is shown with solid gray shades
            // (and a slightly larger leading dot) rather than alpha fading: the
            // leading dot is darkest, trailing dots lighten around the ring.
            let age = (index - spinnerPhase + 12) % 12
            let shade = isAnimating ? (0.15 + CGFloat(age) / 11 * 0.72) : 0.6
            NSColor(white: shade, alpha: 1).setFill()
            let size = isAnimating ? dotRadius * (1.15 - CGFloat(age) / 11 * 0.35) : dotRadius
            let dotCenter = NSPoint(x: center.x + direction.dx * orbit, y: center.y + direction.dy * orbit)
            NSBezierPath(ovalIn: NSMakeRect(dotCenter.x - size, dotCenter.y - size, size * 2, size * 2)).fill()
        }
    }

    /// Whether the native peer should render the indeterminate style.
    private var rendersIndeterminate: Bool {
        isIndeterminate || style == .spinning
    }

    private func syncIndeterminateToNative() {
        guard let nativeHandle else {
            return
        }

        realizedBackend?.setProgressIndicatorIndeterminate(rendersIndeterminate, animating: isAnimating, for: nativeHandle)
    }

    private func syncRangeToNative() {
        guard let nativeHandle else {
            return
        }

        realizedBackend?.setProgressIndicatorRange(minValue: minValue, maxValue: maxValue, for: nativeHandle)
        realizedBackend?.setProgressIndicatorValue(doubleValue, for: nativeHandle)
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, minValue), maxValue)
    }

    deinit {
        spinnerTimer?.invalidate()
    }
}
