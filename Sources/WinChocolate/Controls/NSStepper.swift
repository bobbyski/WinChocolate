/// A stepper control.
///
/// `NSStepper` stores AppKit-shaped range, increment, wrapping, and action
/// behavior. The first Windows backend maps it to a small native up/down-style
/// control and keeps the public value model in Swift.
open class NSStepper: NSControl {
    private var isUpdatingValueFromNative = false

    /// The stepper's minimum value.
    open var minValue: Double {
        didSet {
            if maxValue < minValue {
                maxValue = minValue
            }
            doubleValue = normalized(doubleValue)
            syncRangeToNative()
        }
    }

    /// The stepper's maximum value.
    open var maxValue: Double {
        didSet {
            if minValue > maxValue {
                minValue = maxValue
            }
            doubleValue = normalized(doubleValue)
            syncRangeToNative()
        }
    }

    /// Amount added or subtracted for each step.
    open var increment: Double {
        didSet {
            if increment <= 0 {
                increment = 1
            }
            syncRangeToNative()
        }
    }

    /// Whether stepping past an edge wraps to the opposite edge.
    open var valueWraps: Bool {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setStepperWraps(valueWraps, for: nativeHandle)
        }
    }

    /// Whether holding the native control should repeatedly change value.
    open var autorepeat: Bool

    /// Current stepper value.
    open var doubleValue: Double {
        didSet {
            doubleValue = normalized(doubleValue)
            objectValue = doubleValue
            guard !isUpdatingValueFromNative, let nativeHandle else {
                return
            }

            realizedBackend?.setStepperValue(doubleValue, for: nativeHandle)
        }
    }

    /// Current stepper integer value.
    open var intValue: Int32 {
        get {
            Int32(doubleValue.rounded())
        }
        set {
            doubleValue = Double(newValue)
        }
    }

    /// Creates a stepper with a frame.
    public override init(frame frameRect: NSRect) {
        self.minValue = 0
        self.maxValue = 100
        self.increment = 1
        self.valueWraps = false
        self.autorepeat = true
        self.doubleValue = 0
        super.init(frame: frameRect)
        self.objectValue = doubleValue
    }

    /// Creates the native stepper peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createStepper(value: doubleValue, minValue: minValue, maxValue: maxValue, increment: increment, frame: frame, parent: parent)
    }

    /// Ensures native range, value, and action dispatch are synced.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        backend.setStepperRange(minValue: minValue, maxValue: maxValue, increment: increment, for: handle)
        backend.setStepperValue(doubleValue, for: handle)
        backend.setStepperWraps(valueWraps, for: handle)
        backend.registerAction(for: handle) { [weak self, weak backend] in
            guard let self, let backend, let nativeHandle = self.nativeHandle else {
                return
            }

            self.updateValueFromNative(backend.stepperValue(for: nativeHandle))
            _ = self.window?.makeFirstResponder(self)
            self.sendAction()
        }
        return handle
    }

    /// Steps upward by one increment.
    open func stepUp(_ sender: Any?) {
        step(by: increment)
    }

    /// Steps downward by one increment.
    open func stepDown(_ sender: Any?) {
        step(by: -increment)
    }

    private func step(by delta: Double) {
        let proposed = doubleValue + delta
        if valueWraps, proposed > maxValue {
            doubleValue = minValue
        } else if valueWraps, proposed < minValue {
            doubleValue = maxValue
        } else {
            doubleValue = proposed
        }
        sendAction()
    }

    private func syncRangeToNative() {
        guard let nativeHandle else {
            return
        }

        realizedBackend?.setStepperRange(minValue: minValue, maxValue: maxValue, increment: increment, for: nativeHandle)
        realizedBackend?.setStepperValue(doubleValue, for: nativeHandle)
    }

    private func updateValueFromNative(_ value: Double) {
        isUpdatingValueFromNative = true
        doubleValue = value
        isUpdatingValueFromNative = false
    }

    private func normalized(_ value: Double) -> Double {
        min(max(value, minValue), maxValue)
    }
}
