/// A framework-drawn segmented control.
///
/// WinChocolate draws the segmented control itself — like the drawn table, level
/// indicator, token field, and disclosure button — rather than composing native
/// push buttons. Only a framework-drawn control can render AppKit's segment
/// shapes (the `.capsule` pill, `.rounded` strip, `.separated` pills, and the
/// square/textured families), which have no native Win32 form. The public
/// surface follows AppKit's segment model: labels, per-segment
/// width/enabled/image/tag/menu, tracking mode, and keyboard selection.
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
        var menu: NSMenu?
    }

    private var segments: [SegmentState]
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
    open var segmentStyle: Style = .automatic {
        didSet {
            needsDisplay = true
        }
    }

    // MARK: - Style geometry (pure/testable)

    /// The gap drawn between segments for a given style. The `.separated` style
    /// stands its segments apart as individual pills (the macOS separated look,
    /// which also reads as the modern Win11 split-button style); every other
    /// style keeps them joined into one continuous strip. Pure/testable.
    public static func winSegmentSpacing(for style: Style) -> CGFloat {
        switch style {
        case .separated:
            return 4
        default:
            return 0
        }
    }

    /// The outer corner radius of the control (or of each pill, for
    /// `.separated`) for a given style and height: a full half-height pill for
    /// `.capsule`, a modest rounding for the rounded family, and square corners
    /// for the textured/small-square family. Pure/testable.
    public static func winSegmentCornerRadius(for style: Style, height: CGFloat) -> CGFloat {
        switch style {
        case .capsule:
            return height / 2
        case .rounded, .texturedRounded, .automatic, .separated:
            return min(6, height / 2)
        case .roundRect:
            return 4
        case .texturedSquare, .smallSquare:
            return 0
        }
    }

    /// The frame of each segment inside the control, in the control's own
    /// coordinates. Fixed-width segments keep their width; the rest split the
    /// remaining space (minus the inter-segment gaps) equally. Exposed for tests.
    public func winSegmentFrames() -> [NSRect] {
        guard !segments.isEmpty else {
            return []
        }

        let spacing = NSSegmentedControl.winSegmentSpacing(for: segmentStyle)
        let totalSpacing = spacing * CGFloat(max(segments.count - 1, 0))
        let requestedWidth = segments.reduce(CGFloat(0)) { $0 + $1.width }
        let automaticCount = segments.filter { $0.width == 0 }.count
        let remainingWidth = max(0, frame.size.width - requestedWidth - totalSpacing)
        let automaticWidth = automaticCount == 0 ? 0 : remainingWidth / CGFloat(automaticCount)

        var x: CGFloat = 0
        var rects: [NSRect] = []
        for segment in segments {
            let width = segment.width == 0 ? automaticWidth : segment.width
            rects.append(NSMakeRect(x, 0, width, frame.size.height))
            x += width + spacing
        }
        return rects
    }

    // MARK: - Init

    /// Creates an empty segmented control.
    public required init(frame frameRect: NSRect) {
        self.segments = []
        super.init(frame: frameRect)
    }

    /// Creates a segmented control with labels.
    init(labels: [String], frame frameRect: NSRect) {
        self.segments = labels.map { SegmentState(label: $0, width: 0, isEnabled: true, isSelected: false, image: nil, tag: 0, menu: nil) }
        super.init(frame: frameRect)
    }

    /// Creates a segmented control from labels, matching AppKit's
    /// convenience shape. The action selector dispatches to the target on
    /// segment clicks, as in AppKit.
    public convenience init(labels: [String], trackingMode: TrackingMode, target: AnyObject?, action: Selector?) {
        self.init(labels: labels, frame: .zero)
        self.trackingMode = trackingMode
        self.target = target
        self.action = action
    }

    /// Segmented controls take focus so arrow keys can move the selection.
    open override var acceptsFirstResponder: Bool {
        trackingMode != .momentary
    }

    // MARK: - Keyboard

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

    // MARK: - Peer

    /// Creates the native container peer the control draws into.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createView(frame: frame, parent: parent)
    }

    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        needsDisplay = true
        return handle
    }

    // MARK: - Segment accessors

    /// Sets the label for a segment.
    open func setLabel(_ label: String, forSegment segment: Int) {
        guard segments.indices.contains(segment) else {
            return
        }

        segments[segment].label = label
        needsDisplay = true
    }

    /// Returns the label for a segment.
    open func label(forSegment segment: Int) -> String? {
        guard segments.indices.contains(segment) else {
            return nil
        }

        return segments[segment].label
    }

    /// The control's natural size (9.2): each segment's label measured with the
    /// current font plus per-segment padding, at the standard control height, so
    /// a layout-created segmented control (e.g. a tab bar) isn't measured 0×0.
    open override var intrinsicContentSize: NSSize {
        let font = self.font ?? NSFont.systemFont(ofSize: 13)
        var width: CGFloat = 0
        for index in 0..<segmentCount {
            let text = label(forSegment: index) ?? ""
            let measured = (text.isEmpty ? " " : text).size(withAttributes: [.font: font])
            width += measured.width + 20
        }
        return NSSize(width: max(width, 30), height: 24)
    }

    /// Sets the image for a segment. File-backed images render in the drawn
    /// control (image left of the label when both are present, else centered);
    /// template images tint to the label color. Named/symbol images without a
    /// file path fall back to the label until in-memory decoding lands.
    open func setImage(_ image: NSImage?, forSegment segment: Int) {
        guard segments.indices.contains(segment) else {
            return
        }

        segments[segment].image = image
        needsDisplay = true
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

    /// Attaches a pop-up menu to a segment. Clicking that segment shows the menu.
    open func setMenu(_ menu: NSMenu?, forSegment segment: Int) {
        guard segments.indices.contains(segment) else {
            return
        }

        segments[segment].menu = menu
    }

    /// Returns the pop-up menu attached to a segment, if any.
    open func menu(forSegment segment: Int) -> NSMenu? {
        guard segments.indices.contains(segment) else {
            return nil
        }

        return segments[segment].menu
    }

    /// Sets a fixed width for a segment. Pass `0` for automatic equal width.
    open func setWidth(_ width: CGFloat, forSegment segment: Int) {
        guard segments.indices.contains(segment) else {
            return
        }

        segments[segment].width = max(0, width)
        needsDisplay = true
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
        needsDisplay = true
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
            needsDisplay = true
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

    // MARK: - Interaction

    /// A click selects (or, in `.selectAny`, toggles) the segment under the
    /// cursor, or pops that segment's menu.
    open override func mouseDown(with event: NSEvent) {
        let localX = event.locationInWindow.x - frameInWindow().origin.x
        if let index = segmentIndex(atX: localX) {
            activateSegment(at: index)
        } else {
            super.mouseDown(with: event)
        }
    }

    /// Activates a segment as if clicked (respecting its menu and the tracking
    /// mode). Exposed for tests and scripted/programmatic interaction.
    public func winSelectSegment(byClickAt index: Int) {
        activateSegment(at: index)
    }

    private func segmentIndex(atX x: CGFloat) -> Int? {
        for (index, rect) in winSegmentFrames().enumerated() where x >= rect.origin.x && x < rect.origin.x + rect.size.width {
            return index
        }
        return nil
    }

    private func activateSegment(at index: Int) {
        guard segments.indices.contains(index), segments[index].isEnabled else {
            return
        }

        // A segment with an attached menu pops it up under the segment instead
        // of acting as a plain selection.
        if let menu = segments[index].menu {
            let frames = winSegmentFrames()
            let origin = frames.indices.contains(index) ? frames[index].origin : NSMakePoint(0, 0)
            _ = menu.popUp(positioning: nil, at: origin, in: self)
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

    // MARK: - Drawing

    /// Off-curve control distance for approximating a quarter circle.
    private static let cornerControl: CGFloat = 0.5522847498

    /// A rectangle path that rounds only its left and/or right corners. Used for
    /// the selection band in a joined control: only the outer end of an end
    /// segment is rounded (matching the control's outer shape), while inner
    /// segment edges stay square, so the rounding lands only where segments meet
    /// the outside — never between connected segments.
    private static func winSegmentPath(rect: NSRect, radius: CGFloat, roundLeft: Bool, roundRight: Bool) -> NSBezierPath {
        let cap = min(radius, rect.size.width / 2, rect.size.height / 2)
        let rL = roundLeft ? cap : 0
        let rR = roundRight ? cap : 0
        let control = cornerControl
        let left = rect.origin.x
        let right = rect.origin.x + rect.size.width
        let top = rect.origin.y
        let bottom = rect.origin.y + rect.size.height

        let path = NSBezierPath()
        path.move(to: NSMakePoint(left + rL, top))
        path.line(to: NSMakePoint(right - rR, top))
        if rR > 0 {
            path.curve(to: NSMakePoint(right, top + rR),
                       controlPoint1: NSMakePoint(right - rR + rR * control, top),
                       controlPoint2: NSMakePoint(right, top + rR - rR * control))
        } else {
            path.line(to: NSMakePoint(right, top))
        }
        path.line(to: NSMakePoint(right, bottom - rR))
        if rR > 0 {
            path.curve(to: NSMakePoint(right - rR, bottom),
                       controlPoint1: NSMakePoint(right, bottom - rR + rR * control),
                       controlPoint2: NSMakePoint(right - rR + rR * control, bottom))
        } else {
            path.line(to: NSMakePoint(right, bottom))
        }
        path.line(to: NSMakePoint(left + rL, bottom))
        if rL > 0 {
            path.curve(to: NSMakePoint(left, bottom - rL),
                       controlPoint1: NSMakePoint(left + rL - rL * control, bottom),
                       controlPoint2: NSMakePoint(left, bottom - rL + rL * control))
        } else {
            path.line(to: NSMakePoint(left, bottom))
        }
        path.line(to: NSMakePoint(left, top + rL))
        if rL > 0 {
            path.curve(to: NSMakePoint(left + rL, top),
                       controlPoint1: NSMakePoint(left, top + rL - rL * control),
                       controlPoint2: NSMakePoint(left + rL - rL * control, top))
        } else {
            path.line(to: NSMakePoint(left, top))
        }
        path.close()
        return path
    }

    open override func draw(_ dirtyRect: NSRect) {
        guard !segments.isEmpty else {
            return
        }

        // The border, dividers, and selection highlight all use the accent color:
        // AppKit exposes no border toggle on NSSegmentedControl, and on the dark
        // Windows surface a neutral hairline had too little contrast — an accent
        // frame reads cleanly. Unselected segments stay transparent (just the
        // label); the selected segment fills; dividers run the full height to
        // connect to the border.
        let rects = winSegmentFrames()
        let accent = NSColor.controlAccentColor
        let spacing = NSSegmentedControl.winSegmentSpacing(for: segmentStyle)
        let lastIndex = rects.count - 1
        // Inset the whole drawing so the 1px accent border and its rounded
        // corners sit fully inside the view — a border stroked at the very edge
        // gets its outer half (and the corner curve) clipped by the view bounds.
        let margin: CGFloat = 1.5
        let top = margin
        let bottom = max(frame.size.height - margin, top)
        let radius = NSSegmentedControl.winSegmentCornerRadius(for: segmentStyle, height: bottom - top)

        if spacing > 0 {
            // Separated: each segment is an accent-outlined pill; selected ones
            // are also accent-filled.
            for (index, rect) in rects.enumerated() {
                let path = NSBezierPath(roundedRect: rect.insetBy(dx: margin, dy: margin), xRadius: radius, yRadius: radius)
                if isSegmentHighlighted(index) {
                    accent.setFill()
                    path.fill()
                }
                accent.setStroke()
                path.stroke()
                drawSegmentLabel(index, in: rect)
            }
            return
        }

        // Joined: an accent outer border with full-height accent dividers, the
        // selected segment filled (rounding only the outer corner of an end
        // segment; inner edges between connected segments stay square).
        let outerLeft = margin
        let outerRight = max(frame.size.width - margin, outerLeft)
        let outerPath = NSBezierPath(
            roundedRect: NSMakeRect(outerLeft, top, outerRight - outerLeft, bottom - top),
            xRadius: radius,
            yRadius: radius
        )

        accent.setFill()
        for index in rects.indices where isSegmentHighlighted(index) {
            let leftEdge = index == 0 ? outerLeft : rects[index].origin.x
            let rightEdge = index == lastIndex ? outerRight : rects[index].origin.x + rects[index].size.width
            let band = NSMakeRect(leftEdge, top, max(rightEdge - leftEdge, 0), bottom - top)
            NSSegmentedControl.winSegmentPath(rect: band, radius: radius, roundLeft: index == 0, roundRight: index == lastIndex).fill()
        }

        accent.setStroke()
        for rect in rects.dropLast() {
            let x = rect.origin.x + rect.size.width
            let divider = NSBezierPath()
            divider.move(to: NSMakePoint(x, top))
            divider.line(to: NSMakePoint(x, bottom))
            divider.stroke()
        }
        outerPath.stroke()

        for index in rects.indices {
            drawSegmentLabel(index, in: rects[index])
        }
    }

    /// Whether a segment reads as selected (the single selection, or any of the
    /// `.selectAny` flags).
    private func isSegmentHighlighted(_ index: Int) -> Bool {
        index == selectedSegment || segments[index].isSelected
    }

    private func drawSegmentLabel(_ index: Int, in rect: NSRect) {
        let segment = segments[index]
        let hasLabel = !segment.label.isEmpty
        // Only file-backed images draw (named/symbol images are a no-op until
        // in-memory bitmap decoding lands), so an undrawable image reserves no
        // space and the segment falls back to its label.
        let drawableImage = segment.image?.filePath != nil ? segment.image : nil
        guard hasLabel || drawableImage != nil else {
            return
        }

        let color: NSColor = !segment.isEnabled
            ? .tertiaryLabelColor
            : (isSegmentHighlighted(index) ? .white : .labelColor)
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: color,
            .font: font ?? NSFont.systemFont(ofSize: 12)
        ]
        let labelSize = hasLabel ? segment.label.size(withAttributes: attributes) : .zero

        // The image glyph fits the segment height (leaving vertical padding),
        // keeping its natural aspect ratio when known, else a square.
        var imageSize = NSSize.zero
        if let image = drawableImage {
            let side = min(max(rect.size.height - 8, 0), 16)
            if image.size.width > 0 && image.size.height > 0 {
                imageSize = NSSize(width: image.size.width * (side / image.size.height), height: side)
            } else {
                imageSize = NSSize(width: side, height: side)
            }
        }

        // Image and label sit side by side, the pair centered in the segment
        // (AppKit's image-left layout); either alone is centered on its own.
        let gap: CGFloat = (imageSize.width > 0 && hasLabel) ? 4 : 0
        let contentWidth = imageSize.width + gap + labelSize.width
        var cursorX = rect.origin.x + (rect.size.width - contentWidth) / 2

        if let image = drawableImage, imageSize.width > 0 {
            let imageRect = NSRect(
                x: cursorX,
                y: rect.origin.y + (rect.size.height - imageSize.height) / 2,
                width: imageSize.width,
                height: imageSize.height
            )
            // Template segment images tint to the label color, matching AppKit.
            if image.isTemplate {
                color.setFill()
            }
            image.draw(in: imageRect)
            cursorX += imageSize.width + gap
        }

        if hasLabel {
            let origin = NSPoint(
                x: cursorX,
                y: rect.origin.y + (rect.size.height - labelSize.height) / 2
            )
            segment.label.draw(at: origin, withAttributes: attributes)
        }
    }

    /// This view's origin in window coordinates (for click hit mapping).
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

    // MARK: - Model maintenance

    private func resizeSegments(to count: Int) {
        if count < segments.count {
            segments.removeLast(segments.count - count)
        } else if count > segments.count {
            for _ in segments.count..<count {
                segments.append(SegmentState(label: "", width: 0, isEnabled: true, isSelected: false, image: nil, tag: 0, menu: nil))
            }
        }

        selectedSegment = normalizedSelection(selectedSegment)
        needsDisplay = true
    }

    private func syncSegmentSelection() {
        isUpdatingSelection = true
        defer {
            isUpdatingSelection = false
        }

        for index in segments.indices {
            segments[index].isSelected = index == selectedSegment
        }
        needsDisplay = true
    }

    private func normalizedSelection(_ selection: Int) -> Int {
        segments.indices.contains(selection) ? selection : -1
    }
}
