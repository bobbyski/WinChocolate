import Foundation

/// AppKit-shaped level indicator (GtkLevelBar). A read-only gauge; set
/// `doubleValue` within `[minValue, maxValue]` to fill it.
open class NSLevelIndicator: NSControl {

    public var minValue: Double
    public var maxValue: Double

    private var backingValue: Double

    /// The current level.
    public var doubleValue: Double {
        get { backingValue }
        set {
            backingValue = newValue
            backend.setDoubleValue(newValue, for: handle)
        }
    }

    /// Fired when the user changes an editable level indicator (accepted for
    /// parity; native editing wiring is a later item).
    public var onAction: ((NSLevelIndicator) -> Void)?

    /// Creates a level indicator over `[minValue, maxValue]` starting at `value`.
    public init(value: Double, minValue: Double, maxValue: Double, frame: NSRect) {
        self.minValue = minValue
        self.maxValue = maxValue
        self.backingValue = value
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createLevelIndicator(value: value, minValue: minValue, maxValue: maxValue, frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
    }

    /// AppKit's frame-only initializer: a `0…10` indicator at 0.
    public required convenience init(frame: NSRect) {
        self.init(value: 0, minValue: 0, maxValue: 10, frame: frame)
    }
}
