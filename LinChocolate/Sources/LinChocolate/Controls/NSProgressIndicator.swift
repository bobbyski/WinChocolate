import Foundation

/// AppKit-shaped determinate progress indicator (GtkProgressBar). Set
/// `doubleValue` within `[minValue, maxValue]` to fill the bar.
public final class NSProgressIndicator: NSView {

    public let minValue: Double
    public let maxValue: Double

    private var backingValue: Double

    /// The current value; the bar fills to `(value - min) / (max - min)`.
    public var doubleValue: Double {
        get { backingValue }
        set {
            backingValue = newValue
            backend.setDoubleValue(newValue, for: handle)
        }
    }

    /// Creates a progress indicator over `[minValue, maxValue]` starting at `value`.
    public init(value: Double, minValue: Double, maxValue: Double, frame: NSRect) {
        self.minValue = minValue
        self.maxValue = maxValue
        self.backingValue = value
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createProgressIndicator(value: value, minValue: minValue, maxValue: maxValue, frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
    }
}
