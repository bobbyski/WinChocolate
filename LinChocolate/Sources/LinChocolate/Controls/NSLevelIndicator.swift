import Foundation

/// AppKit-shaped level indicator.
///
/// `.continuousCapacity`/`.discreteCapacity` render a fill bar that turns
/// warning- then critical-coloured past `warningValue`/`criticalValue`;
/// `.rating` renders `maxValue - minValue` stars, filled to the value, and is
/// clickable when `isEditable`.
open class NSLevelIndicator: NSControl {

    /// The value range. For `.rating` the span is the number of stars.
    public var minValue: Double {
        didSet { pushRange() }
    }
    public var maxValue: Double {
        didSet { pushRange() }
    }

    private var backingValue: Double

    /// The current level.
    public var doubleValue: Double {
        get { backingValue }
        set {
            backingValue = newValue
            backend.setDoubleValue(newValue, for: handle)
        }
    }

    /// The presentation style (AppKit's `levelIndicatorStyle`).
    public var levelIndicatorStyle: NSLevelIndicatorStyle = .continuousCapacity {
        didSet { backend.setLevelIndicatorStyle(levelIndicatorStyle.rawValue, for: handle) }
    }

    /// Whether the user can set the level by clicking (AppKit's `isEditable`).
    /// A rating indicator is the usual case.
    public var isEditable: Bool = false {
        didSet { backend.setLevelIndicatorEditable(isEditable, for: handle) }
    }

    /// The value at which the fill turns warning-coloured; 0 = none.
    public var warningValue: Double = 0 {
        didSet { pushThresholds() }
    }
    /// The value at which the fill turns critical-coloured; 0 = none.
    public var criticalValue: Double = 0 {
        didSet { pushThresholds() }
    }

    /// Fired when the user sets an editable indicator's level.
    public var onAction: ((NSLevelIndicator) -> Void)?

    private func pushRange() {
        backend.setLevelIndicatorRange(min: minValue, max: maxValue, for: handle)
    }
    private func pushThresholds() {
        backend.setLevelThresholds(warning: warningValue, critical: criticalValue, for: handle)
    }

    /// Creates a level indicator over `[minValue, maxValue]` starting at `value`.
    public init(value: Double, minValue: Double, maxValue: Double, frame: NSRect) {
        self.minValue = minValue
        self.maxValue = maxValue
        self.backingValue = value
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createLevelIndicator(value: value, minValue: minValue, maxValue: maxValue, frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
        backend.setLevelChangeAction(for: handle) { [weak self] value in
            guard let self else { return }
            self.backingValue = value      // sync silently — this came from a click
            self.onAction?(self)
            self.sendAction()
        }
    }

    /// AppKit's frame-only initializer: a `0…10` indicator at 0.
    public required convenience init(frame: NSRect) {
        self.init(value: 0, minValue: 0, maxValue: 10, frame: frame)
    }
}
