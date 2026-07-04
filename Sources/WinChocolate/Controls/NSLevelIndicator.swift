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
            updateBarColor()
        }
    }

    /// Warning threshold, or 0 for none. Values at or above it turn the bar amber.
    open var warningValue: Double {
        didSet {
            updateBarColor()
        }
    }

    /// Critical threshold, or 0 for none. Values at or above it turn the bar red.
    open var criticalValue: Double {
        didSet {
            updateBarColor()
        }
    }

    /// Requested AppKit style.
    open var levelIndicatorStyle: Style

    /// Whether the user can click or drag the bar to set its value.
    open var isEditable: Bool = false {
        didSet {
            applyEditable()
        }
    }

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
        // AppKit defaults both thresholds to 0 (no threshold coloring).
        self.warningValue = 0
        self.criticalValue = 0
        self.levelIndicatorStyle = .continuousCapacity
        super.init(frame: frameRect)
        self.objectValue = doubleValue
    }

    /// Recolors the bar when the value crosses a threshold.
    private func updateBarColor() {
        guard let nativeHandle else {
            return
        }

        let color: NSColor?
        if criticalValue > minValue && doubleValue >= criticalValue {
            color = .red
        } else if warningValue > minValue && doubleValue >= warningValue {
            color = NSColor(calibratedRed: 0.95, green: 0.6, blue: 0.1, alpha: 1)
        } else {
            color = nil
        }
        realizedBackend?.setProgressBarColor(color, for: nativeHandle)
    }

    /// Editable level indicators take focus; display-only ones skip traversal.
    open override var acceptsFirstResponder: Bool {
        isEditable
    }

    /// Pushes the editable state (and range) to the native bar.
    private func applyEditable() {
        guard let nativeHandle else {
            return
        }

        realizedBackend?.setLevelIndicatorEditable(isEditable, minValue: minValue, maxValue: maxValue, for: nativeHandle)
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
        updateBarColor()
        if isEditable {
            backend.setLevelIndicatorEditable(true, minValue: minValue, maxValue: maxValue, for: handle)
            backend.registerAction(for: handle) { [weak self, weak backend] in
                guard let self, let backend, let nativeHandle = self.nativeHandle else {
                    return
                }

                self.doubleValue = backend.levelIndicatorValue(for: nativeHandle)
                _ = self.window?.makeFirstResponder(self)
                self.sendAction()
            }
        }
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
