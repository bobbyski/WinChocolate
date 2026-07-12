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

    /// The control's natural size (9.2): a standard-height indicator with
    /// flexible width so constraints/frame decide how wide it runs.
    open override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 18)
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

            if usesCustomRendering {
                needsDisplay = true
                return
            }

            realizedBackend?.setProgressIndicatorValue(doubleValue, for: nativeHandle)
            updateBarColor()
        }
    }

    /// Whether this style is drawn by the framework (stars/segments/bars)
    /// rather than a native progress bar.
    private var usesCustomRendering: Bool {
        levelIndicatorStyle != .continuousCapacity
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
        if usesCustomRendering {
            // Rating/discrete/relevancy are framework-drawn on a plain view.
            return backend.createView(frame: frame, parent: parent)
        }
        return backend.createProgressIndicator(value: doubleValue, minValue: minValue, maxValue: maxValue, frame: frame, parent: parent)
    }

    /// Ensures range and value are synced after realization.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        if usesCustomRendering {
            needsDisplay = true
            return handle
        }
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

    /// The number of discrete items (stars/segments) drawn.
    private var itemCount: Int {
        min(max(Int(maxValue.rounded()) - Int(minValue.rounded()), 1), 20)
    }

    /// How many items are "on" for the current value.
    private var filledCount: Int {
        min(max(Int(doubleValue.rounded()) - Int(minValue.rounded()), 0), itemCount)
    }

    /// Appearance-aware fill colors for the framework-drawn styles (rating
    /// stars, discrete-capacity segments, relevancy bars). The empty-slot track
    /// lifts under dark so filled and unfilled items stay legible against the
    /// dark control surface; rating and discrete capacity fill with the user's
    /// Windows accent (the Fluent look, plan 8.3), while relevancy keeps the
    /// Mac's neutral graphite. Pure and `isDark`-parameterized for testing.
    /// Continuous capacity uses the native progress bar, so it isn't covered.
    public static func winFillColors(for style: Style, isDark: Bool) -> (on: NSColor, off: NSColor) {
        let off = isDark ? NSColor(white: 0.32, alpha: 1) : NSColor(white: 0.80, alpha: 1)
        switch style {
        case .relevancy:
            let on = isDark ? NSColor(white: 0.78, alpha: 1) : NSColor(white: 0.40, alpha: 1)
            return (on, off)
        default:
            return (.controlAccentColor, off)
        }
    }

    /// Draws the rating/discrete/relevancy representation.
    open override func draw(_ dirtyRect: NSRect) {
        guard usesCustomRendering else {
            super.draw(dirtyRect)
            return
        }

        let count = itemCount
        let filled = filledCount
        let colors = NSLevelIndicator.winFillColors(for: levelIndicatorStyle, isDark: effectiveAppearance.winIsDark)
        let onColor = colors.on
        let offColor = colors.off
        let slot = bounds.size.width / CGFloat(count)
        let size = min(slot - 4, bounds.size.height - 4)
        let midY = bounds.size.height / 2

        for index in 0..<count {
            let cx = slot * CGFloat(index) + slot / 2
            let isOn = index < filled
            (isOn ? onColor : offColor).setFill()
            switch levelIndicatorStyle {
            case .rating:
                starPath(centerX: cx, centerY: midY, radius: size / 2).fill()
            case .relevancy:
                // Graduated bar heights from short to tall.
                let height = (bounds.size.height - 4) * CGFloat(index + 1) / CGFloat(count)
                NSBezierPath(rect: NSRect(x: cx - slot / 4, y: midY - height / 2, width: slot / 2, height: height)).fill()
            default: // discrete capacity: rounded segments
                NSBezierPath(rect: NSRect(x: cx - size / 2, y: midY - size / 2, width: size, height: size)).fill()
            }
        }
    }

    /// Unit direction vectors for a five-pointed star's 10 points
    /// (outer/inner alternating), avoiding a runtime trig dependency.
    private static let starDirections: [(CGFloat, CGFloat)] = [
        (0, -1), (0.5878, -0.8090), (0.9511, -0.3090), (0.9511, 0.3090), (0.5878, 0.8090),
        (0, 1), (-0.5878, 0.8090), (-0.9511, 0.3090), (-0.9511, -0.3090), (-0.5878, -0.8090)
    ]

    /// A five-pointed star path centered at a point.
    private func starPath(centerX: CGFloat, centerY: CGFloat, radius: CGFloat) -> NSBezierPath {
        let path = NSBezierPath()
        let inner = radius * 0.4
        for point in 0..<10 {
            let r = point % 2 == 0 ? radius : inner
            let direction = NSLevelIndicator.starDirections[point]
            let position = NSPoint(x: centerX + r * direction.0, y: centerY + r * direction.1)
            if point == 0 {
                path.move(to: position)
            } else {
                path.line(to: position)
            }
        }
        path.close()
        return path
    }

    /// A click on the Nth item sets the value to N when editable.
    open override func mouseDown(with event: NSEvent) {
        guard usesCustomRendering, isEditable, bounds.size.width > 0 else {
            super.mouseDown(with: event)
            return
        }

        let location = event.locationInWindow
        let localX = location.x - frameInWindow().origin.x
        let slot = bounds.size.width / CGFloat(itemCount)
        let index = min(max(Int(localX / slot), 0), itemCount - 1)
        doubleValue = Double(Int(minValue.rounded()) + index + 1)
        _ = window?.makeFirstResponder(self)
        sendAction()
    }

    /// This view's origin in window coordinates (for hit mapping).
    private func frameInWindow() -> NSRect {
        var origin = frame.origin
        var parent = superview
        while let current = parent {
            origin.x += current.frame.origin.x
            origin.y += current.frame.origin.y
            parent = current.superview
        }
        return NSRect(origin: origin, size: frame.size)
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, minValue), maxValue)
    }
}
