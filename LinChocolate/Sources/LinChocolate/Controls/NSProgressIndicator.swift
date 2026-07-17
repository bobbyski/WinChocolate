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

    /// Bar vs spinner (accepted for parity; native control picks its look).
    public var style: NSProgressIndicatorStyle = .bar

    /// Indeterminate (barber-pole / spinner) vs determinate.
    public var isIndeterminate: Bool = false
    public var usesThreadedAnimation: Bool = true
    public var isDisplayedWhenStopped: Bool = true

    /// Starts/stops indeterminate animation (accepted for parity).
    public func startAnimation(_ sender: Any?) {}
    public func stopAnimation(_ sender: Any?) {}
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
