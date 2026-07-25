import Foundation

/// AppKit-shaped determinate progress indicator (GtkProgressBar). Set
/// `doubleValue` within `[minValue, maxValue]` to fill the bar.
open class NSProgressIndicator: NSView {

    /// The minimum value of the progress range.
    public var minValue: Double
    /// The maximum value of the progress range.
    public var maxValue: Double

    private var backingValue: Double

    /// The current value; the bar fills to `(value - min) / (max - min)`.
    public var doubleValue: Double {
        get { backingValue }
        set {
            backingValue = newValue
            backend.setDoubleValue(newValue, for: handle)
        }
    }

    /// Bar vs spinner (AppKit's `style`); the spinner is a rotating indicator.
    public var style: NSProgressIndicatorStyle = .bar {
        didSet { backend.setProgressSpinning(style == .spinning, for: handle) }
    }

    /// Indeterminate (barber-pole) vs determinate.
    public var isIndeterminate: Bool = false {
        didSet { backend.setProgressIndeterminate(isIndeterminate, for: handle) }
    }
    /// Whether the indeterminate animation runs on a background thread (accepted for API parity).
    public var usesThreadedAnimation: Bool = true
    /// Whether the indicator is visible while stopped (accepted for API parity).
    public var isDisplayedWhenStopped: Bool = true

    /// Starts/stops the indeterminate animation (AppKit's start/stopAnimation).
    public func startAnimation(_ sender: Any?) {
        backend.setProgressAnimating(true, for: handle)
    }
    /// Stops the indeterminate animation.
    public func stopAnimation(_ sender: Any?) {
        backend.setProgressAnimating(false, for: handle)
    }
    /// Increments the current value by `delta`.
    public func incrementBy(_ delta: Double) { doubleValue += delta }
    /// Resizes the indicator to fit its content. Not supported on the LinChocolate backend.
    public func sizeToFit() {}

    /// Creates a progress indicator over `[minValue, maxValue]` starting at `value`.
    public init(value: Double, minValue: Double, maxValue: Double, frame: NSRect) {
        self.minValue = minValue
        self.maxValue = maxValue
        self.backingValue = value
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createProgressIndicator(value: value, minValue: minValue, maxValue: maxValue, frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
    }

    /// AppKit's frame-only initializer: a `0…100` determinate bar at 0.
    public required convenience init(frame: NSRect) {
        self.init(value: 0, minValue: 0, maxValue: 100, frame: frame)
    }
}
