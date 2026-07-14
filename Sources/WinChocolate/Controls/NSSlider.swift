/// A slider control.
///
/// `NSSlider` maps to the native Windows trackbar while preserving AppKit's
/// common value, range, target, and action shape.
open class NSSlider: NSControl {
    private var isUpdatingValueFromNative = false

    /// The slider's minimum value.
    open var minValue: Double {
        didSet {
            if maxValue < minValue {
                maxValue = minValue
            }
            doubleValue = clamped(doubleValue)
            syncRangeToNative()
        }
    }

    /// The slider's maximum value.
    open var maxValue: Double {
        didSet {
            if minValue > maxValue {
                minValue = maxValue
            }
            doubleValue = clamped(doubleValue)
            syncRangeToNative()
        }
    }

    /// The slider's current floating-point value.
    open var doubleValue: Double {
        didSet {
            doubleValue = clamped(doubleValue)
            objectValue = doubleValue
            guard !isUpdatingValueFromNative, let nativeHandle else {
                return
            }

            realizedBackend?.setSliderValue(doubleValue, for: nativeHandle)
        }
    }

    // MARK: Accessibility

    /// A slider reports `.slider`; its accessibility value is its current value.
    open override var winIntrinsicAccessibilityRole: NSAccessibilityRole { .slider }
    open override var winIntrinsicAccessibilityValue: Any? { doubleValue }

    /// The slider's current integer value.
    open var intValue: Int32 {
        get {
            Int32(doubleValue.rounded())
        }
        set {
            doubleValue = Double(newValue)
        }
    }

    /// The number of tick marks shown along the slider (0 for none).
    open var numberOfTickMarks: Int = 0 {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setSliderTickMarks(count: numberOfTickMarks, for: nativeHandle)
        }
    }

    /// Whether the slider only allows values that fall on a tick mark.
    open var allowsTickMarkValuesOnly: Bool = false

    /// Where tick marks are drawn relative to the slider track.
    public enum TickMarkPosition: Sendable {
        /// Below a horizontal slider (default).
        case below
        /// Above a horizontal slider.
        case above
        /// Leading (left) side of a vertical slider.
        case leading
        /// Trailing (right) side of a vertical slider.
        case trailing
    }

    /// The side the tick marks are drawn on.
    open var tickMarkPosition: TickMarkPosition = .below {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setSliderTickMarkPosition(aboveOrLeading: ticksAboveOrLeading, for: nativeHandle)
        }
    }

    /// Whether ticks sit on the top (horizontal) or left (vertical) edge.
    private var ticksAboveOrLeading: Bool {
        tickMarkPosition == .above || tickMarkPosition == .leading
    }

    /// The increment used for Option-modified keyboard/drag steps.
    ///
    /// Stored for source compatibility; the native trackbar owns its own
    /// keyboard stepping, so honoring this during Option-drag is future work.
    open var altIncrementValue: Double = -1

    /// Whether the slider is drawn vertically.
    ///
    /// AppKit also infers orientation from the frame; setting this explicitly
    /// takes precedence.
    open var isVertical: Bool = false {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setSliderVertical(isVertical, for: nativeHandle)
        }
    }

    /// The slider's natural size for Auto Layout (9.2): a fixed thickness across
    /// its axis (matching AppKit's control metric), and no intrinsic length
    /// along it so constraints stretch it. Tick marks add thickness, as in AppKit.
    open override var intrinsicContentSize: NSSize {
        let thickness: CGFloat = numberOfTickMarks > 0 ? 24 : 21
        return isVertical
            ? NSSize(width: thickness, height: NSView.noIntrinsicMetric)
            : NSSize(width: NSView.noIntrinsicMetric, height: thickness)
    }

    /// The value of the tick mark closest to a value.
    open func closestTickMarkValue(toValue value: Double) -> Double {
        guard numberOfTickMarks > 1 else {
            return clamped(value)
        }

        let step = (maxValue - minValue) / Double(numberOfTickMarks - 1)
        guard step > 0 else {
            return clamped(value)
        }

        let index = ((value - minValue) / step).rounded()
        return clamped(minValue + index * step)
    }

    /// Creates a slider with a frame.
    public override init(frame frameRect: NSRect) {
        self.minValue = 0
        self.maxValue = 1
        self.doubleValue = 0
        super.init(frame: frameRect)
        self.objectValue = doubleValue
    }

    /// Creates a slider with a value and range.
    public init(value: Double, minValue: Double, maxValue: Double, target: AnyObject?, action: Selector?) {
        self.minValue = min(minValue, maxValue)
        self.maxValue = max(minValue, maxValue)
        self.doubleValue = min(max(value, self.minValue), self.maxValue)
        super.init(frame: NSMakeRect(0, 0, 100, 24))
        self.target = target
        self.action = action
        self.objectValue = doubleValue
    }

    /// Creates the native Windows slider peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createSlider(value: doubleValue, minValue: minValue, maxValue: maxValue, frame: frame, parent: parent)
    }

    /// Ensures the slider has a native peer and syncs value tracking.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        if isVertical {
            backend.setSliderVertical(true, for: handle)
        }
        backend.setSliderRange(minValue: minValue, maxValue: maxValue, for: handle)
        backend.setSliderValue(doubleValue, for: handle)
        if numberOfTickMarks > 0 {
            backend.setSliderTickMarks(count: numberOfTickMarks, for: handle)
        }
        if ticksAboveOrLeading {
            backend.setSliderTickMarkPosition(aboveOrLeading: true, for: handle)
        }
        backend.registerAction(for: handle) { [weak self, weak backend] in
            guard let self, let backend, let nativeHandle = self.nativeHandle else {
                return
            }

            var value = backend.sliderValue(for: nativeHandle)
            if self.allowsTickMarkValuesOnly {
                value = self.closestTickMarkValue(toValue: value)
                backend.setSliderValue(value, for: nativeHandle)
            }
            self.updateValueFromNative(value)
            _ = self.window?.makeFirstResponder(self)
            self.sendAction()
        }
        return handle
    }

    private func syncRangeToNative() {
        guard let nativeHandle else {
            return
        }

        realizedBackend?.setSliderRange(minValue: minValue, maxValue: maxValue, for: nativeHandle)
        realizedBackend?.setSliderValue(doubleValue, for: nativeHandle)
    }

    private func updateValueFromNative(_ value: Double) {
        isUpdatingValueFromNative = true
        doubleValue = value
        isUpdatingValueFromNative = false
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, minValue), maxValue)
    }
}
