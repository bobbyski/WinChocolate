/// A standalone AppKit-style scroller.
///
/// This first slice preserves the familiar `doubleValue` and
/// `knobProportion` surface while the classic backend maps it to a native
/// Windows scrollbar.
open class NSScroller: NSControl {
    private var isUpdatingValueFromNative = false

    /// Parts of a scroller that AppKit can report.
    public enum Part: Sendable {
        case noPart
        case decrementPage
        case knob
        case incrementPage
        case decrementLine
        case incrementLine
        case knobSlot
    }

    /// Arrow placement style.
    public enum ArrowPosition: Sendable {
        case noArrow
        case minEnd
        case maxEnd
        case defaultSetting
    }

    /// Which scroller parts are usable.
    public enum UsableParts: Sendable {
        case noParts
        case onlyScrollerArrows
        case allParts
    }

    /// Scroller appearance style.
    public enum Style: Sendable {
        case legacy
        case overlay
    }

    /// Scroller knob appearance.
    public enum KnobStyle: Sendable {
        case `default`
        case dark
        case light
    }

    /// Current normalized scroll position.
    open var doubleValue: Double {
        didSet {
            doubleValue = clamped(doubleValue)
            objectValue = doubleValue
            guard !isUpdatingValueFromNative, let nativeHandle else {
                return
            }

            realizedBackend?.setScrollerValue(doubleValue, knobProportion: knobProportion, for: nativeHandle)
        }
    }

    /// Normalized knob size.
    open var knobProportion: Double {
        didSet {
            knobProportion = clamped(knobProportion)
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setScrollerValue(doubleValue, knobProportion: knobProportion, for: nativeHandle)
        }
    }

    /// Current hit-test part. The first slice records only a coarse value.
    open var hitPart: Part

    /// Arrow placement style.
    open var arrowsPosition: ArrowPosition

    /// Usable parts.
    open var usableParts: UsableParts

    /// Appearance style.
    open var scrollerStyle: Style {
        didSet {
            pushAppearanceToNative()
        }
    }

    /// Knob appearance.
    open var knobStyle: KnobStyle {
        didSet {
            pushAppearanceToNative()
        }
    }

    /// Creates a scroller with a frame.
    public required init(frame frameRect: NSRect) {
        self.doubleValue = 0
        self.knobProportion = 0.1
        self.hitPart = .noPart
        self.arrowsPosition = .defaultSetting
        self.usableParts = .allParts
        self.scrollerStyle = .legacy
        self.knobStyle = .default
        super.init(frame: frameRect)
        self.objectValue = doubleValue
    }

    /// Standalone scrollers do not join the key-view loop by default.
    open override var acceptsFirstResponder: Bool {
        false
    }

    /// Sets the normalized scroll position and knob size.
    open func setFloatValue(_ value: Double, knobProportion proportion: Double) {
        doubleValue = value
        knobProportion = proportion
    }

    /// Returns whether the scroller should be vertical.
    open var isVertical: Bool {
        frame.size.height >= frame.size.width
    }

    /// Creates the native scroller peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createScroller(
            value: doubleValue,
            knobProportion: knobProportion,
            isVertical: isVertical,
            frame: frame,
            parent: parent
        )
    }

    /// Ensures native actions update the Swift-side value.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        backend.setScrollerValue(doubleValue, knobProportion: knobProportion, for: handle)
        backend.setScrollerAppearance(
            overlay: scrollerStyle == .overlay,
            knobStyle: NSScroller.nativeKnobStyle(from: knobStyle),
            for: handle
        )
        backend.registerAction(for: handle) { [weak self, weak backend] in
            guard let self, let backend, let nativeHandle = self.nativeHandle else {
                return
            }

            self.updateValueFromNative(backend.scrollerValue(for: nativeHandle))
            self.hitPart = NSScroller.part(from: backend.scrollerPart(for: nativeHandle))
            self.sendAction()
        }
        return handle
    }

    /// Maps a backend-neutral scroller part to the AppKit `Part`.
    static func part(from native: NativeScrollerPart) -> Part {
        switch native {
        case .none:
            return .noPart
        case .decrementLine:
            return .decrementLine
        case .decrementPage:
            return .decrementPage
        case .knob:
            return .knob
        case .incrementPage:
            return .incrementPage
        case .incrementLine:
            return .incrementLine
        }
    }

    /// Maps the AppKit knob style onto the backend-neutral one.
    static func nativeKnobStyle(from style: KnobStyle) -> NativeScrollerKnobStyle {
        switch style {
        case .default:
            return .default
        case .dark:
            return .dark
        case .light:
            return .light
        }
    }

    /// Pushes the current appearance to a realized peer (a no-op before realize
    /// — `realizeNativePeer` applies the initial appearance).
    private func pushAppearanceToNative() {
        guard let nativeHandle else {
            return
        }

        realizedBackend?.setScrollerAppearance(
            overlay: scrollerStyle == .overlay,
            knobStyle: NSScroller.nativeKnobStyle(from: knobStyle),
            for: nativeHandle
        )
    }

    private func updateValueFromNative(_ value: Double) {
        isUpdatingValueFromNative = true
        doubleValue = value
        isUpdatingValueFromNative = false
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
