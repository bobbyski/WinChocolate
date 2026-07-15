import Foundation

/// AppKit-shaped stepper (GtkSpinButton). Reports value changes through
/// `onValueChange`; `doubleValue` reflects the current value.
open class NSStepper: NSControl {

    public var minValue: Double
    public var maxValue: Double
    public var increment: Double

    private var backingValue: Double

    /// The stepper's current value. Setting it updates the control; the user's
    /// own increments flow back in via the backend.
    public var doubleValue: Double {
        get { backingValue }
        set {
            backingValue = newValue
            backend.setDoubleValue(newValue, for: handle)
        }
    }

    /// Called as the user steps the value.
    public var onValueChange: ((NSStepper) -> Void)?

    /// AppKit-shaped alias for `onValueChange`.
    public var onAction: ((NSStepper) -> Void)? {
        get { onValueChange }
        set { onValueChange = newValue }
    }

    /// AppKit's frame-only initializer: a `0…100` stepper (step 1) at 0.
    public required convenience init(frame: NSRect) {
        self.init(value: 0, minValue: 0, maxValue: 100, increment: 1, frame: frame)
    }

    /// Creates a stepper over `[minValue, maxValue]` starting at `value`.
    public init(value: Double, minValue: Double, maxValue: Double, increment: Double = 1, frame: NSRect) {
        self.minValue = minValue
        self.maxValue = maxValue
        self.increment = increment
        self.backingValue = value
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createStepper(value: value, minValue: minValue, maxValue: maxValue, stepSize: increment, frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
        backend.setValueChangeAction(for: handle) { [weak self] value in
            guard let self else { return }
            self.backingValue = value          // sync silently
            self.onValueChange?(self)
            self.sendAction()
        }
    }
}
