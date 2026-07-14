import Foundation

/// AppKit-shaped horizontal slider (GtkScale). Reports live value changes
/// through `onValueChange`; `doubleValue` reflects the current position.
public final class NSSlider: NSView {

    public var minValue: Double
    public var maxValue: Double

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

    /// Whether the slider is oriented vertically (AppKit's `isVertical`).
    public var isVertical: Bool = false {
        didSet { backend.setSliderVertical(isVertical, for: handle) }
    }

    /// Creates a slider over `[minValue, maxValue]` starting at `value`.
    /// AppKit's target/action form (no frame); gets a default size.
    public convenience init(value: Double, minValue: Double, maxValue: Double, target: AnyObject?, action: String?) {
        self.init(value: value, minValue: minValue, maxValue: maxValue, frame: NSMakeRect(0, 0, 120, 24))
    }

    /// AppKit's frame-only initializer: a `0…100` slider at 0.
    public override convenience init(frame: NSRect) {
        self.init(value: 0, minValue: 0, maxValue: 100, frame: frame)
    }

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
