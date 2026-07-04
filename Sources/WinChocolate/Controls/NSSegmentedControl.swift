/// A segmented control made from AppKit-shaped segment state.
///
/// The first WinChocolate slice composes native push buttons inside a view
/// container. This keeps application code pointed at `NSSegmentedControl`
/// while the backend can later swap in a custom or modern renderer.
open class NSSegmentedControl: NSControl {
    /// Segment selection behavior.
    public enum TrackingMode: Sendable {
        case selectOne
        case selectAny
        case momentary
    }

    /// Segment visual style.
    public enum Style: Sendable {
        case automatic
        case rounded
        case texturedRounded
        case roundRect
        case texturedSquare
        case capsule
        case smallSquare
        case separated
    }

    private struct SegmentState {
        var label: String
        var width: CGFloat
        var isEnabled: Bool
        var isSelected: Bool
        var image: NSImage?
        var tag: Int
    }

    private var segments: [SegmentState]
    private var segmentButtons: [NSButton] = []
    private var isUpdatingSelection = false

    /// Number of segments.
    open var segmentCount: Int {
        get {
            segments.count
        }
        set {
            resizeSegments(to: max(0, newValue))
        }
    }

    /// Currently selected segment, or `-1` when none is selected.
    open var selectedSegment: Int = -1 {
        didSet {
            guard !isUpdatingSelection else {
                return
            }

            selectedSegment = normalizedSelection(selectedSegment)
            syncSegmentSelection()
        }
    }

    /// Segment tracking mode.
    open var trackingMode: TrackingMode = .selectOne

    /// Segment visual style request.
    open var segmentStyle: Style = .automatic

    /// Creates an empty segmented control.
    public override init(frame frameRect: NSRect) {
        self.segments = []
        super.init(frame: frameRect)
    }

    /// Creates a segmented control with labels.
    public init(labels: [String], frame frameRect: NSRect) {
        self.segments = labels.map { SegmentState(label: $0, width: 0, isEnabled: true, isSelected: false, image: nil, tag: 0) }
        super.init(frame: frameRect)
        rebuildSegmentButtons()
    }

    /// Segmented controls take focus so arrow keys can move the selection.
    open override var acceptsFirstResponder: Bool {
        trackingMode != .momentary
    }

    /// Moves the selection with the arrow keys in selection tracking modes.
    open override func keyDown(with event: NSEvent) {
        guard trackingMode != .momentary, let keyCode = event.keyCode else {
            super.keyDown(with: event)
            return
        }

        switch keyCode {
        case 0x25: // Left arrow
            moveSelection(by: -1)
        case 0x27: // Right arrow
            moveSelection(by: 1)
        default:
            super.keyDown(with: event)
        }
    }

    /// Moves the selection to the next enabled segment in a direction.
    private func moveSelection(by delta: Int) {
        guard !segments.isEmpty else {
            return
        }

        let start = selectedSegment < 0 ? (delta > 0 ? -1 : segments.count) : selectedSegment
        var index = start
        for _ in 0..<segments.count {
            index += delta
            guard segments.indices.contains(index) else {
                return
            }
            if segments[index].isEnabled {
                selectedSegment = index
                sendAction()
                return
            }
        }
    }

    /// Creates the native container peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createView(frame: frame, parent: parent)
    }

    /// Ensures the composed segment buttons exist before native realization.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        rebuildSegmentButtons()
        return super.realizeNativePeer(in: backend, parent: parent)
    }

    /// Sets the label for a segment.
    open func setLabel(_ label: String, forSegment segment: Int) {
        guard segments.indices.contains(segment) else {
            return
        }

        segments[segment].label = label
        if segmentButtons.indices.contains(segment) {
            segmentButtons[segment].title = label
            applyImage(to: segmentButtons[segment], segment: segment)
        }
    }

    /// Returns the label for a segment.
    open func label(forSegment segment: Int) -> String? {
        guard segments.indices.contains(segment) else {
            return nil
        }

        return segments[segment].label
    }

    /// Sets the image for a segment.
    open func setImage(_ image: NSImage?, forSegment segment: Int) {
        guard segments.indices.contains(segment) else {
            return
        }

        segments[segment].image = image
        if segmentButtons.indices.contains(segment) {
            applyImage(to: segmentButtons[segment], segment: segment)
        }
    }

    /// Returns the image for a segment.
    open func image(forSegment segment: Int) -> NSImage? {
        guard segments.indices.contains(segment) else {
            return nil
        }

        return segments[segment].image
    }

    /// Sets the tag for a segment.
    open func setTag(_ tag: Int, forSegment segment: Int) {
        guard segments.indices.contains(segment) else {
            return
        }

        segments[segment].tag = tag
    }

    /// Returns the tag for a segment, or `0` when absent.
    open func tag(forSegment segment: Int) -> Int {
        guard segments.indices.contains(segment) else {
            return 0
        }

        return segments[segment].tag
    }

    /// Returns the tag of the selected segment, or `0` when none is selected.
    open func selectedSegmentTag() -> Int {
        segments.indices.contains(selectedSegment) ? segments[selectedSegment].tag : 0
    }

    /// Sets a fixed width for a segment. Pass `0` for automatic equal width.
    open func setWidth(_ width: CGFloat, forSegment segment: Int) {
        guard segments.indices.contains(segment) else {
            return
        }

        segments[segment].width = max(0, width)
        layoutSegments()
    }

    /// Returns the requested width for a segment.
    open func width(forSegment segment: Int) -> CGFloat {
        guard segments.indices.contains(segment) else {
            return 0
        }

        return segments[segment].width
    }

    /// Sets whether an individual segment is enabled.
    open func setEnabled(_ enabled: Bool, forSegment segment: Int) {
        guard segments.indices.contains(segment) else {
            return
        }

        segments[segment].isEnabled = enabled
        if segmentButtons.indices.contains(segment) {
            segmentButtons[segment].isEnabled = enabled
        }
    }

    /// Returns whether an individual segment is enabled.
    open func isEnabled(forSegment segment: Int) -> Bool {
        guard segments.indices.contains(segment) else {
            return false
        }

        return segments[segment].isEnabled
    }

    /// Sets selected state for a segment.
    open func setSelected(_ selected: Bool, forSegment segment: Int) {
        guard segments.indices.contains(segment) else {
            return
        }

        switch trackingMode {
        case .selectOne:
            selectedSegment = selected ? segment : -1
        case .selectAny:
            segments[segment].isSelected = selected
            if segmentButtons.indices.contains(segment) {
                segmentButtons[segment].state = selected ? .on : .off
            }
        case .momentary:
            selectedSegment = selected ? segment : -1
        }
    }

    /// Returns whether a segment is selected.
    open func isSelected(forSegment segment: Int) -> Bool {
        guard segments.indices.contains(segment) else {
            return false
        }

        return segments[segment].isSelected
    }

    private func resizeSegments(to count: Int) {
        if count < segments.count {
            segments.removeLast(segments.count - count)
        } else if count > segments.count {
            for _ in segments.count..<count {
                segments.append(SegmentState(label: "", width: 0, isEnabled: true, isSelected: false, image: nil, tag: 0))
            }
        }

        selectedSegment = normalizedSelection(selectedSegment)
        rebuildSegmentButtons()
    }

    private func rebuildSegmentButtons() {
        for button in segmentButtons {
            button.removeFromSuperview()
        }
        segmentButtons.removeAll()

        for index in segments.indices {
            let button = NSButton(title: segments[index].label, frame: NSZeroRect)
            button.state = segments[index].isSelected ? .on : .off
            button.isEnabled = segments[index].isEnabled
            applyImage(to: button, segment: index)
            button.onAction = { [weak self] _ in
                self?.activateSegment(at: index)
            }
            addSubview(button)
            segmentButtons.append(button)
        }

        layoutSegments()
    }

    private func layoutSegments() {
        guard !segments.isEmpty else {
            return
        }

        let requestedWidth = segments.reduce(CGFloat(0)) { total, segment in
            total + segment.width
        }
        let automaticCount = segments.filter { $0.width == 0 }.count
        let remainingWidth = max(0, frame.size.width - requestedWidth)
        let automaticWidth = automaticCount == 0 ? 0 : remainingWidth / CGFloat(automaticCount)
        var x = CGFloat(0)

        for index in segments.indices {
            let width = segments[index].width == 0 ? automaticWidth : segments[index].width
            if segmentButtons.indices.contains(index) {
                segmentButtons[index].frame = NSMakeRect(x, 0, width, frame.size.height)
            }
            x += width
        }
    }

    /// Applies a segment's image (and the matching image position) to its button.
    private func applyImage(to button: NSButton, segment: Int) {
        let state = segments[segment]
        button.image = state.image
        if state.image == nil {
            button.imagePosition = .noImage
        } else {
            button.imagePosition = state.label.isEmpty ? .imageOnly : .imageLeft
        }
    }

    private func activateSegment(at index: Int) {
        guard segments.indices.contains(index), segments[index].isEnabled else {
            return
        }

        switch trackingMode {
        case .selectOne:
            selectedSegment = index
        case .selectAny:
            setSelected(!segments[index].isSelected, forSegment: index)
            selectedSegment = index
        case .momentary:
            selectedSegment = index
            syncSegmentSelection()
            selectedSegment = -1
        }

        sendAction()
    }

    private func syncSegmentSelection() {
        isUpdatingSelection = true
        defer {
            isUpdatingSelection = false
        }

        for index in segments.indices {
            let selected = index == selectedSegment
            segments[index].isSelected = selected
            if segmentButtons.indices.contains(index) {
                segmentButtons[index].state = selected ? .on : .off
            }
        }
    }

    private func normalizedSelection(_ selection: Int) -> Int {
        segments.indices.contains(selection) ? selection : -1
    }
}
