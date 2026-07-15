/// A color well control.
///
/// This implementation provides AppKit-compatible color state and a clickable
/// native swatch. Activating the well attaches it to the shared
/// `NSColorPanel`, so colors confirmed in the panel's chooser flow back into
/// the well's `color`.
open class NSColorWell: NSControl {
    /// The visual presentation style of a color well.
    public enum Style: Equatable, Sendable {
        /// The standard bordered swatch.
        case `default`

        /// A compact borderless swatch.
        case minimal

        /// A swatch with a dropdown affordance.
        case expanded
    }

    /// The control's natural size (9.2): AppKit's standard color-well metrics,
    /// so a layout-created well isn't measured 0×0.
    open override var intrinsicContentSize: NSSize {
        NSSize(width: 44, height: 23)
    }

    /// The color well's presentation style.
    open var colorWellStyle: Style = .default

    /// Whether the color well draws a border.
    open var isBordered: Bool = true

    /// The selected color.
    open var color: NSColor {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setBackgroundColor(color, for: nativeHandle)
        }
    }

    /// Whether the color well is active.
    open private(set) var isActive: Bool

    /// The preset colors offered by an expanded well's swatch palette.
    public static let swatchColors: [NSColor] = [
        .black, .gray, .white, .red, .orange, .yellow,
        .green, .cyan, .blue, .purple, .magenta, .brown
    ]

    /// The swatch-palette popover shown by an expanded well, when open.
    public private(set) var winSwatchPopover: NSPopover?

    private var swatchViews: [ColorSwatchView] = []

    /// Test hook: picks the swatch at an index as if the user clicked it.
    public func winSimulateSwatchPick(at index: Int) {
        guard swatchViews.indices.contains(index) else {
            return
        }

        swatchViews[index].winSimulatePick()
    }

    /// Creates a color well with a frame.
    public required init(frame frameRect: NSRect) {
        self.color = .white
        self.isActive = false
        super.init(frame: frameRect)
        self.objectValue = color
    }

    /// Activates the color well and attaches it to the shared color panel.
    open func activate(_ exclusive: Bool) {
        isActive = true
        let panel = NSColorPanel.shared
        panel.winActiveColorWell = self
        panel.color = color
    }

    /// Deactivates the color well and detaches it from the shared color panel.
    open func deactivate() {
        isActive = false
        if NSColorPanel.shared.winActiveColorWell === self {
            NSColorPanel.shared.winActiveColorWell = nil
        }
    }

    /// Creates the native swatch peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createImageView(description: "", imagePath: nil, frame: frame, parent: parent)
    }

    /// Ensures the swatch color is synced after realization.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        backend.setBackgroundColor(color, for: handle)
        return handle
    }

    /// Applies a color chosen in the shared color panel: updates the swatch and
    /// **sends the action** — AppKit's contract is that a well fires when its
    /// color CHANGES (a panel pick), not when it is clicked. Programmatic
    /// `color` assignment does not send.
    package func winApplyPanelColor(_ newColor: NSColor) {
        color = newColor
        objectValue = newColor
        sendAction()
    }

    open override func mouseDown(with event: NSEvent) {
        // Clicking a well presents the panel/palette; it does NOT send the
        // action (that happens when the color changes — see winApplyPanelColor).
        if colorWellStyle == .expanded {
            // The expanded style drops down a swatch palette instead of jumping
            // straight to the color panel.
            winShowSwatchPalette()
        } else {
            activate(true)
            // Clicking a color well also brings up the shared color panel,
            // matching AppKit; panel picks then flow back into this well live.
            NSColorPanel.shared.makeKeyAndOrderFront(self)
        }
        super.mouseDown(with: event)
    }

    /// Shows the expanded well's swatch palette in a transient popover.
    ///
    /// Picking a swatch sets `color` and closes the palette; a "Show Colors…"
    /// button opens the shared color panel for a full chooser.
    public func winShowSwatchPalette() {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false

        let cell: CGFloat = 30, gap: CGFloat = 8, columns = 6
        let rows = (NSColorWell.swatchColors.count + columns - 1) / columns
        let width = gap + CGFloat(columns) * (cell + gap)
        let gridHeight = gap + CGFloat(rows) * (cell + gap)
        let height = gridHeight + 30 + gap

        let content = NSView(frame: NSMakeRect(0, 0, width, height))
        content.winBackgroundColor = .windowBackgroundColor
        swatchViews = []
        for (index, swatchColor) in NSColorWell.swatchColors.enumerated() {
            let column = index % columns, row = index / columns
            let swatch = ColorSwatchView(
                color: swatchColor,
                frame: NSMakeRect(gap + CGFloat(column) * (cell + gap), gap + CGFloat(row) * (cell + gap), cell, cell)
            ) { [weak self, weak popover] picked in
                self?.color = picked
                self?.objectValue = picked
                self?.sendAction()
                popover?.performClose(nil)
            }
            swatchViews.append(swatch)
            content.addSubview(swatch)
        }

        let moreButton = NSButton(title: "Show Colors…", frame: NSMakeRect(gap, gridHeight, width - 2 * gap, 28))
        moreButton.winInternalAction = { [weak self, weak popover] _ in
            popover?.performClose(nil)
            guard let self else {
                return
            }
            self.activate(true)
            NSColorPanel.shared.makeKeyAndOrderFront(self)
        }
        content.addSubview(moreButton)

        popover.contentSize = NSMakeSize(width, height)
        popover.contentViewController = NSViewController(view: content)
        winSwatchPopover = popover
        popover.show(relativeTo: bounds, of: self, preferredEdge: .maxY)
    }
}

/// A clickable filled color square used by the expanded color well's palette.
final class ColorSwatchView: NSView {
    private let swatchColor: NSColor
    private let onPick: (NSColor) -> Void

    init(color: NSColor, frame: NSRect, onPick: @escaping (NSColor) -> Void) {
        self.swatchColor = color
        self.onPick = onPick
        super.init(frame: frame)
        winBackgroundColor = color
    }

    /// Inherited from `NSView.init(frame:)` being `required`. A swatch has no
    /// meaning without a color and a pick handler, and it is never registered
    /// with a collection view, so the frame-only path is unsupported.
    required init(frame frameRect: NSRect) {
        fatalError("ColorSwatchView requires init(color:frame:onPick:)")
    }

    override func draw(_ dirtyRect: NSRect) {
        swatchColor.setFill()
        NSBezierPath(rect: bounds).fill()
        NSColor.gray.setStroke()
        NSBezierPath(rect: bounds).stroke()
    }

    override func mouseDown(with event: NSEvent) {
        onPick(swatchColor)
    }

    /// Test hook: invokes the pick as if the swatch were clicked.
    func winSimulatePick() {
        onPick(swatchColor)
    }
}
