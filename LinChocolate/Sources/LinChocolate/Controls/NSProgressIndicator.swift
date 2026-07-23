import Foundation

/// AppKit-shaped determinate progress indicator (GtkProgressBar). Set
/// `doubleValue` within `[minValue, maxValue]` to fill the bar.
open class NSProgressIndicator: NSView {

    public var minValue: Double
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
    public var usesThreadedAnimation: Bool = true
    public var isDisplayedWhenStopped: Bool = true

    /// Starts/stops the indeterminate animation (AppKit's start/stopAnimation).
    public func startAnimation(_ sender: Any?) {
        backend.setProgressAnimating(true, for: handle)
    }
    public func stopAnimation(_ sender: Any?) {
        backend.setProgressAnimating(false, for: handle)
    }
    public func incrementBy(_ delta: Double) { doubleValue += delta }
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
