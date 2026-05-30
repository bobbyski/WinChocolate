/// A level indicator control.
///
/// WinChocolate starts with AppKit-compatible value/range state and maps the
/// classic backend to a determinate progress-style native control.
open class NSLevelIndicator: NSControl {
    /// Level indicator style.
    public enum Style: Sendable {
        case continuousCapacity
        case discreteCapacity
        case rating
        case relevancy
    }

    /// Minimum represented value.
    open var minValue: Double {
        didSet {
            if maxValue < minValue {
                maxValue = minValue
            }
            doubleValue = clamped(doubleValue)
            syncRangeToNative()
        }
    }

    /// Maximum represented value.
    open var maxValue: Double {
        didSet {
            if minValue > maxValue {
                minValue = maxValue
            }
            doubleValue = clamped(doubleValue)
            syncRangeToNative()
        }
    }

    /// Current level value.
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

    /// Warning threshold.
    open var warningValue: Double

    /// Critical threshold.
    open var criticalValue: Double

    /// Requested AppKit style.
    open var levelIndicatorStyle: Style

    /// Integer view of the current value.
    open var intValue: Int {
        get {
            Int(doubleValue.rounded())
        }
        set {
            doubleValue = Double(newValue)
        }
    }

    /// Creates a level indicator with a frame.
    public override init(frame frameRect: NSRect) {
        self.minValue = 0
        self.maxValue = 100
        self.doubleValue = 0
        self.warningValue = 70
        self.criticalValue = 90
        self.levelIndicatorStyle = .continuousCapacity
        super.init(frame: frameRect)
        self.objectValue = doubleValue
    }

    /// Level indicators are display controls and skip normal key-view traversal.
    open override var acceptsFirstResponder: Bool {
        false
    }

    /// Creates the native level peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createProgressIndicator(value: doubleValue, minValue: minValue, maxValue: maxValue, frame: frame, parent: parent)
    }

    /// Ensures range and value are synced after realization.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        backend.setProgressIndicatorRange(minValue: minValue, maxValue: maxValue, for: handle)
        backend.setProgressIndicatorValue(doubleValue, for: handle)
        return handle
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
}
