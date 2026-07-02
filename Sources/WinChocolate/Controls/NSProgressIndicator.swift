/// A progress indicator control.
///
/// This first slice supports the determinate bar style used by many AppKit
/// apps. The native Windows backend maps it to a progress bar control.
open class NSProgressIndicator: NSControl {
    /// Progress indicator visual style.
    public enum Style: Sendable {
        /// Horizontal bar progress indicator.
        case bar

        /// Spinning progress indicator placeholder.
        case spinning
    }

    /// The indicator's minimum value.
    open var minValue: Double {
        didSet {
            if maxValue < minValue {
                maxValue = minValue
            }
            doubleValue = clamped(doubleValue)
            syncRangeToNative()
        }
    }

    /// The indicator's maximum value.
    open var maxValue: Double {
        didSet {
            if minValue > maxValue {
                minValue = maxValue
            }
            doubleValue = clamped(doubleValue)
            syncRangeToNative()
        }
    }

    /// The indicator's current value.
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

    /// Whether the indicator is indeterminate.
    open var isIndeterminate: Bool {
        didSet {
            syncIndeterminateToNative()
        }
    }

    /// Visual style requested by the app.
    ///
    /// The classic backend renders `.spinning` as an indeterminate marquee
    /// bar; the modern appearance will add a true spinner.
    open var style: Style {
        didSet {
            syncIndeterminateToNative()
        }
    }

    /// Whether the indicator is currently animating.
    open private(set) var isAnimating: Bool

    /// Creates a progress indicator with a frame.
    public override init(frame frameRect: NSRect) {
        self.minValue = 0
        self.maxValue = 100
        self.doubleValue = 0
        self.isIndeterminate = false
        self.style = .bar
        self.isAnimating = false
        super.init(frame: frameRect)
        self.objectValue = doubleValue
    }

    /// Starts the indicator animation.
    open func startAnimation(_ sender: Any?) {
        isAnimating = true
        syncIndeterminateToNative()
    }

    /// Stops the indicator animation.
    open func stopAnimation(_ sender: Any?) {
        isAnimating = false
        syncIndeterminateToNative()
    }

    /// Increments the current value.
    open func increment(by delta: Double) {
        doubleValue += delta
    }

    /// Creates the native progress peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createProgressIndicator(value: doubleValue, minValue: minValue, maxValue: maxValue, frame: frame, parent: parent)
    }

    /// Ensures range and value are synced after realization.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        backend.setProgressIndicatorRange(minValue: minValue, maxValue: maxValue, for: handle)
        backend.setProgressIndicatorValue(doubleValue, for: handle)
        backend.setProgressIndicatorIndeterminate(rendersIndeterminate, animating: isAnimating, for: handle)
        return handle
    }

    /// Whether the native peer should render the indeterminate style.
    private var rendersIndeterminate: Bool {
        isIndeterminate || style == .spinning
    }

    private func syncIndeterminateToNative() {
        guard let nativeHandle else {
            return
        }

        realizedBackend?.setProgressIndicatorIndeterminate(rendersIndeterminate, animating: isAnimating, for: nativeHandle)
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
