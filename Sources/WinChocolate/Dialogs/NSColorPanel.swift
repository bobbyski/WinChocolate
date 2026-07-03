/// The shared color panel.
///
/// The panel is a floating utility window composed of framework controls: a
/// live preview, preset swatches, and RGB sliders. Every change applies
/// immediately — the attached color well, the `changeColor(_:)`
/// responder-chain action, and the `winColorDidChange` closure all fire as
/// the selection moves, matching AppKit's continuous color panel instead of
/// the earlier modal chooser. Closing the panel hides it; the shared
/// instance stays alive for the next presentation.
open class NSColorPanel: NSPanel {
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

    /// Whether changes apply while dragging; the composed panel always
    /// applies live, so this is stored for AppKit API compatibility.
    open var isContinuous = true

    /// The color well the panel currently feeds, when any.
    weak var winActiveColorWell: NSColorWell?

    /// The stored action target consulted before the responder chain.
    open private(set) weak var winTarget: AnyObject?

    /// The stored action selector name, kept for AppKit API compatibility.
    open private(set) var winAction: String?

    /// Called after every color change, alongside the responder-chain action.
    open var winColorDidChange: ((NSColor) -> Void)?

    private var previewView: NSView?
    private var componentSliders: [NSSlider] = []
    private var componentValueLabels: [NSTextField] = []

    /// Creates a color panel against an explicit backend.
    public init(nativeBackend: NativeControlBackend) {
        super.init(
            contentRect: NSMakeRect(820, 120, Self.contentSize.width, Self.contentSize.height),
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

    /// Stores the action selector name sent on color changes.
    open func setAction(_ action: String?) {
        winAction = action
    }

    private static let contentSize = NSSize(width: 248, height: 220)

    private func configurePanel() {
        title = "Colors"
        isFloatingPanel = true
        hidesOnDeactivate = true
        delegate = self
        buildContent()
    }

    private func buildContent() {
        let content = NSView(frame: NSRect(origin: NSPoint(x: 0, y: 0), size: Self.contentSize))

        let preview = NSView(frame: NSMakeRect(16, 16, 216, 40))
        preview.backgroundColor = color
        content.addSubview(preview)
        previewView = preview

        let presets: [NSColor] = [
            .black, .darkGray, .gray, .lightGray, .white, .red, .orange, .yellow,
            .green, .cyan, .blue, .purple, .magenta, .brown,
            NSColor(calibratedRed: 0.5, green: 0, blue: 0, alpha: 1),
            NSColor(calibratedRed: 0, green: 0.2, blue: 0.6, alpha: 1),
        ]
        for (index, preset) in presets.enumerated() {
            let column = CGFloat(index % 8)
            let row = CGFloat(index / 8)
            let swatch = WinColorSwatchView(frame: NSMakeRect(16 + column * 27, 64 + row * 23, 24, 20))
            swatch.backgroundColor = preset
            swatch.onPick = { [weak self] in
                self?.color = preset
            }
            content.addSubview(swatch)
        }

        for (index, name) in ["R", "G", "B"].enumerated() {
            let rowTop = 116 + CGFloat(index) * 32

            let label = NSTextField(string: name, frame: NSMakeRect(16, rowTop, 20, 20))
            label.isBordered = false
            content.addSubview(label)

            let slider = NSSlider(frame: NSMakeRect(40, rowTop - 2, 152, 24))
            slider.minValue = 0
            slider.maxValue = 255
            slider.onAction = { [weak self] _ in
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

    private func updateColorFromSliders() {
        guard componentSliders.count == 3 else {
            return
        }

        color = NSColor(
            calibratedRed: CGFloat(componentSliders[0].doubleValue) / 255,
            green: CGFloat(componentSliders[1].doubleValue) / 255,
            blue: CGFloat(componentSliders[2].doubleValue) / 255,
            alpha: 1
        )
    }

    private func colorDidChange() {
        syncControls()
        winActiveColorWell?.color = color
        winColorDidChange?(color)

        let responder = (winTarget as? NSResponder)
            ?? NSApplication.shared.panelActionWindow?.firstResponder
            ?? NSApplication.shared.panelActionWindow
        responder?.changeColor(self)
    }

    private func syncControls() {
        previewView?.backgroundColor = color

        let components = [color.redComponent, color.greenComponent, color.blueComponent]
        for (index, component) in components.enumerated() where index < componentSliders.count {
            let value = (component * 255).rounded()
            componentSliders[index].doubleValue = value
            componentValueLabels[index].stringValue = "\(Int(value))"
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
