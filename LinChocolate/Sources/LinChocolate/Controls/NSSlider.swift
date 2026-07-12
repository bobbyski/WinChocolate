import Foundation

/// AppKit-shaped horizontal slider (GtkScale). Reports live value changes
/// through `onValueChange`; `doubleValue` reflects the current position.
public final class NSSlider: NSView {

    public let minValue: Double
    public let maxValue: Double

    private var backingValue: Double

    /// The slider's current value. Setting it moves the control; the user's own
    /// drags flow back in via the backend.
    public var doubleValue: Double {
        get { backingValue }
        set {
            backingValue = newValue
            backend.setDoubleValue(newValue, for: handle)
        }
    }

    /// Called as the user moves the slider.
    public var onValueChange: ((NSSlider) -> Void)?

    /// Creates a slider over `[minValue, maxValue]` starting at `value`.
    public init(value: Double, minValue: Double, maxValue: Double, frame: NSRect) {
        self.minValue = minValue
        self.maxValue = maxValue
        self.backingValue = value
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createSlider(value: value, minValue: minValue, maxValue: maxValue, frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
        backend.setValueChangeAction(for: handle) { [weak self] value in
            guard let self else { return }
            self.backingValue = value          // sync silently
            self.onValueChange?(self)
        }
    }
}
