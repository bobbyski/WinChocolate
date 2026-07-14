/// The shared color panel.
///
/// The panel is a floating utility window composed of framework controls: a
/// live preview, preset swatches, a mode switch (RGB / HSB), component sliders,
/// and an optional opacity slider. Every change applies immediately — the
/// attached color well, the `changeColor(_:)` responder-chain action, and the
/// `winColorDidChange` closure all fire as the selection moves, matching
/// AppKit's continuous color panel. Closing the panel hides it; the shared
/// instance stays alive for the next presentation.
open class NSColorPanel: NSPanel {
    /// The color-picker mode, matching AppKit's `NSColorPanel.Mode`.
    ///
    /// The composed panel renders RGB and HSB component sliders directly; the
    /// other Apple modes (gray/CMYK/wheel/…) fall back to RGB sliders while the
    /// selected mode value is stored, so call sites stay source-compatible.
    public enum Mode: Int, Sendable {
        case gray = 0
        case RGB = 1
        case CMYK = 2
        case HSB = 3
        case customPalette = 4
        case colorList = 5
        case wheel = 6
        case crayon = 7
    }

    nonisolated(unsafe) private static var sharedPanel: NSColorPanel?

    /// The shared color panel instance.
    open class var shared: NSColorPanel {
        if let sharedPanel {
            return sharedPanel
        }

        let panel = NSColorPanel()
        sharedPanel = panel
        return panel
    }

    /// Whether the shared color panel has been created.
    open class var sharedColorPanelExists: Bool {
        sharedPanel != nil
    }

    /// Sets the shared panel's picker mode, matching AppKit's class method.
    open class func setPickerMode(_ mode: Mode) {
        shared.mode = mode
    }

    /// The currently selected color.
    ///
    /// Setting the color syncs the panel controls and notifies the active
    /// color well, the responder chain, and the change closure.
    open var color: NSColor = .white {
        didSet {
            guard color != oldValue else {
                return
            }

            colorDidChange()
        }
    }

    /// The active picker mode. Switching between RGB and HSB relabels the
    /// component sliders and rescales them to the new color space.
    open var mode: Mode = .RGB {
        didSet {
            guard mode != oldValue else {
                return
            }

            modeControl?.selectedSegment = (mode == .HSB) ? 1 : 0
            reconfigureComponents()
        }
    }

    /// Whether the panel shows an opacity (alpha) slider.
    ///
    /// Off by default, matching AppKit. Turning it on reveals an opacity row and
    /// grows the panel; edits then carry the chosen alpha into `color`.
    open var showsAlpha: Bool = false {
        didSet {
            guard showsAlpha != oldValue else {
                return
            }

            applyAlphaVisibility()
        }
    }

    /// The current opacity, or `1` when the alpha slider is hidden.
    open var alpha: CGFloat {
        showsAlpha ? color.alphaComponent : 1
    }

    /// Whether changes apply while dragging; the composed panel always
    /// applies live, so this is stored for AppKit API compatibility.
    open var isContinuous = true

    /// The color well the panel currently feeds, when any.
    weak var winActiveColorWell: NSColorWell?

    /// The stored action target consulted before the responder chain.
    open private(set) weak var winTarget: AnyObject?

    /// The stored action selector sent to the target on color changes.
    open private(set) var winAction: Selector?

    private var previewView: NSView?
    private var modeControl: NSSegmentedControl?
    private var componentNameLabels: [NSTextField] = []
    private var componentSliders: [NSSlider] = []
    private var componentValueLabels: [NSTextField] = []
    private var alphaNameLabel: NSTextField?
    private var alphaSlider: NSSlider?
    private var alphaValueLabel: NSTextField?

    private static let contentWidth: CGFloat = 248
    private static let baseContentHeight: CGFloat = 246
    private static let alphaContentHeight: CGFloat = 280
    private static let alphaRowTop: CGFloat = 244

    /// Creates a color panel against an explicit backend.
    public init(nativeBackend: NativeControlBackend) {
        super.init(
            contentRect: NSMakeRect(820, 120, Self.contentWidth, Self.baseContentHeight),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false,
            nativeBackend: nativeBackend
        )
        configurePanel()
    }

    /// Creates a color panel on the application's backend.
    public convenience init() {
        self.init(nativeBackend: NSApplication.shared.nativeBackend)
    }

    /// Stores the target notified about color changes.
    open func setTarget(_ target: AnyObject?) {
        winTarget = target
    }

    /// Stores the action selector sent on color changes, matching AppKit's
    /// `setAction(_:)`.
    open func setAction(_ selector: Selector?) {
        winAction = selector
    }

    private func configurePanel() {
        title = "Colors"
        isFloatingPanel = true
        hidesOnDeactivate = true
        delegate = self
        buildContent()
    }

    private func buildContent() {
        let content = NSView(frame: NSRect(origin: NSPoint(x: 0, y: 0), size: NSSize(width: Self.contentWidth, height: Self.baseContentHeight)))

        let preview = NSView(frame: NSMakeRect(16, 16, 216, 40))
        preview.winBackgroundColor = color
        content.addSubview(preview)
        previewView = preview

        // Mode switch: RGB or HSB component sliders.
        let modeSwitch = NSSegmentedControl(labels: ["RGB", "HSB"], frame: NSMakeRect(16, 64, 120, 24))
        modeSwitch.selectedSegment = 0
        modeSwitch.winInternalAction = { [weak self] control in
            guard let segmented = control as? NSSegmentedControl else {
                return
            }
            self?.mode = segmented.selectedSegment == 1 ? .HSB : .RGB
        }
        content.addSubview(modeSwitch)
        modeControl = modeSwitch

        let presets: [NSColor] = [
            .black, .darkGray, .gray, .lightGray, .white, .red, .orange, .yellow,
            .green, .cyan, .blue, .purple, .magenta, .brown,
            NSColor(calibratedRed: 0.5, green: 0, blue: 0, alpha: 1),
            NSColor(calibratedRed: 0, green: 0.2, blue: 0.6, alpha: 1),
        ]
        for (index, preset) in presets.enumerated() {
            let column = CGFloat(index % 8)
            let row = CGFloat(index / 8)
            let swatch = WinColorSwatchView(frame: NSMakeRect(16 + column * 27, 96 + row * 23, 24, 20))
            swatch.winBackgroundColor = preset
            swatch.onPick = { [weak self] in
                self?.color = preset
            }
            content.addSubview(swatch)
        }

        for index in 0..<3 {
            let rowTop = 152 + CGFloat(index) * 30

            let label = NSTextField(string: ["R", "G", "B"][index], frame: NSMakeRect(16, rowTop, 22, 20))
            label.isBordered = false
            content.addSubview(label)
            componentNameLabels.append(label)

            let slider = NSSlider(frame: NSMakeRect(40, rowTop - 2, 152, 24))
            slider.minValue = 0
            slider.maxValue = 255
            slider.winInternalAction = { [weak self] _ in
                self?.updateColorFromSliders()
            }
            content.addSubview(slider)
            componentSliders.append(slider)

            let valueLabel = NSTextField(string: "255", frame: NSMakeRect(198, rowTop, 34, 20))
            valueLabel.isBordered = false
            content.addSubview(valueLabel)
            componentValueLabels.append(valueLabel)
        }

        contentView = content
        syncControls()
    }

    /// Builds the opacity row on demand the first time alpha is enabled, so a
    /// panel that never shows alpha realizes only its three component sliders.
    private func buildAlphaRowIfNeeded() {
        guard alphaSlider == nil, let content = contentView else {
            return
        }

        let alphaName = NSTextField(string: "α", frame: NSMakeRect(16, Self.alphaRowTop, 22, 20))
        alphaName.isBordered = false
        content.addSubview(alphaName)
        alphaNameLabel = alphaName

        let alpha = NSSlider(frame: NSMakeRect(40, Self.alphaRowTop - 2, 152, 24))
        alpha.minValue = 0
        alpha.maxValue = 100
        alpha.winInternalAction = { [weak self] _ in
            self?.updateColorFromSliders()
        }
        content.addSubview(alpha)
        alphaSlider = alpha

        let alphaValue = NSTextField(string: "100", frame: NSMakeRect(198, Self.alphaRowTop, 34, 20))
        alphaValue.isBordered = false
        content.addSubview(alphaValue)
        alphaValueLabel = alphaValue
    }

    /// Reads the current color out of the component sliders in the active mode.
    private func updateColorFromSliders() {
        guard componentSliders.count == 3 else {
            return
        }

        let a = showsAlpha ? CGFloat(alphaSlider?.doubleValue ?? 100) / 100 : 1
        let c0 = CGFloat(componentSliders[0].doubleValue)
        let c1 = CGFloat(componentSliders[1].doubleValue)
        let c2 = CGFloat(componentSliders[2].doubleValue)

        switch mode {
        case .HSB:
            color = NSColor(hue: c0 / 360, saturation: c1 / 100, brightness: c2 / 100, alpha: a)
        default:
            color = NSColor(calibratedRed: c0 / 255, green: c1 / 255, blue: c2 / 255, alpha: a)
        }
    }

    private func colorDidChange() {
        syncControls()
        // Update the active well's swatch, then dispatch as AppKit does: a
        // target/action pair set through `setTarget`/`setAction` receives the
        // action selector; otherwise `changeColor(_:)` walks the responder
        // chain of the panel-action window.
        winActiveColorWell?.color = color

        if let winAction, winTarget != nil {
            _ = NSApplication.shared.sendAction(winAction, to: winTarget, from: self)
            return
        }

        let responder = (winTarget as? NSResponder)
            ?? NSApplication.shared.panelActionWindow?.firstResponder
            ?? NSApplication.shared.panelActionWindow
        // Walks the chain to the first NSColorChanging adopter (Apple: changeColor:
        // is a chain action, not an NSResponder method since 10.14).
        responder?.tryToPerform(Selector("changeColor:"), with: self)
    }

    /// Relabels and rescales the component sliders when the mode changes.
    private func reconfigureComponents() {
        let names = mode == .HSB ? ["H", "S", "B"] : ["R", "G", "B"]
        let maxes: [Double] = mode == .HSB ? [360, 100, 100] : [255, 255, 255]
        for index in 0..<componentSliders.count {
            componentNameLabels[index].stringValue = names[index]
            componentSliders[index].maxValue = maxes[index]
        }
        syncControls()
    }

    /// Shows or hides the opacity row and resizes the panel to match.
    private func applyAlphaVisibility() {
        if showsAlpha {
            buildAlphaRowIfNeeded()
        }
        alphaNameLabel?.isHidden = !showsAlpha
        alphaSlider?.isHidden = !showsAlpha
        alphaValueLabel?.isHidden = !showsAlpha
        setContentSize(NSSize(width: Self.contentWidth, height: showsAlpha ? Self.alphaContentHeight : Self.baseContentHeight))
        syncControls()
    }

    private func syncControls() {
        previewView?.winBackgroundColor = color

        let values: [Double]
        switch mode {
        case .HSB:
            values = [color.hueComponent * 360, color.saturationComponent * 100, color.brightnessComponent * 100]
        default:
            values = [color.redComponent * 255, color.greenComponent * 255, color.blueComponent * 255]
        }
        for (index, value) in values.enumerated() where index < componentSliders.count {
            let rounded = value.rounded()
            componentSliders[index].doubleValue = rounded
            componentValueLabels[index].stringValue = "\(Int(rounded))"
        }

        if showsAlpha {
            let rounded = (color.alphaComponent * 100).rounded()
            alphaSlider?.doubleValue = rounded
            alphaValueLabel?.stringValue = "\(Int(rounded))"
        }
    }
}

extension NSColorPanel: NSWindowDelegate {
    /// The shared panel hides on a title-bar close instead of destroying its peer.
    public func windowShouldClose(_ sender: NSWindow) -> Bool {
        orderOut(nil)
        return false
    }
}

/// A clickable preset color swatch inside the color panel.
private final class WinColorSwatchView: NSView {
    /// Called when the swatch is clicked.
    var onPick: (() -> Void)?

    override func mouseDown(with event: NSEvent) {
        onPick?()
    }
}
