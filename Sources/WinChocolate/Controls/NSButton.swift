/// A push button control.
///
/// `NSButton` maps to the native Windows button control when realized by a
/// backend. The public surface follows AppKit's common title, target, and action
/// workflow.
open class NSButton: NSControl {
    /// Button rendering and behavior type.
    public enum ButtonType: Sendable {
        /// Momentary push button.
        case momentaryPushIn

        /// Toggle checkbox button.
        case switchButton

        /// Mutually exclusive radio button.
        case radioButton
    }

    /// Image position relative to the title.
    public enum ImagePosition: Sendable {
        /// No image.
        case noImage

        /// Image only, no title.
        case imageOnly

        /// Image to the left of the title.
        case imageLeft

        /// Image to the right of the title.
        case imageRight

        /// Image above the title.
        case imageAbove

        /// Image below the title.
        case imageBelow
    }

    /// The button title.
    open var title: String {
        didSet {
            syncDisplayedTitle()
        }
    }

    /// A sound played when the button is clicked.
    open var sound: NSSound?

    /// Visual bezel appearance of the button.
    public enum BezelStyle: Sendable {
        /// The standard rounded push button (default).
        case rounded
        /// A flat square-edged bezel (regular/shadowless/textured square).
        case regularSquare
        case shadowlessSquare
        case texturedSquare
        case smallSquare
        /// Other AppKit bezels fall back to the standard rounded look.
        case circular
        case disclosure
        case roundedDisclosure
        case recessed
        case inline
    }

    /// The button's bezel style. Square styles render flat; others use the
    /// standard themed push button (full themed bezels are appearance-phase work).
    open var bezelStyle: BezelStyle = .rounded {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setButtonBezelFlat(isFlatBezel, for: nativeHandle)
        }
    }

    /// Whether the bezel style renders as a flat square button.
    private var isFlatBezel: Bool {
        switch bezelStyle {
        case .regularSquare, .shadowlessSquare, .texturedSquare, .smallSquare:
            return true
        default:
            return false
        }
    }

    /// Whether this bezel style is drawn by the framework on a view peer rather
    /// than mapped to a native push button. These AppKit bezels — disclosure
    /// triangles, circular buttons, recessed toggles, and inline pills — have no
    /// native Win32 form, so WinChocolate draws them (matching the drawn-control
    /// pattern used by the level indicator and token chips).
    var usesFrameworkDrawnBezel: Bool {
        switch bezelStyle {
        case .disclosure, .roundedDisclosure, .circular, .recessed, .inline:
            return true
        default:
            return false
        }
    }

    /// Whether clicking this framework-drawn bezel toggles its on/off state
    /// (disclosure triangles and recessed toggles) versus firing momentarily
    /// (circular and inline).
    private var bezelTogglesState: Bool {
        switch bezelStyle {
        case .disclosure, .roundedDisclosure, .recessed:
            return true
        default:
            return false
        }
    }

    /// The three vertices of the disclosure triangle inside `bounds`: a
    /// right-pointing glyph when closed (vertical base, apex at max-x), a
    /// down-pointing glyph when open (horizontal base, single apex in y). Pure
    /// and orientation-testable.
    public static func winDisclosureTriangle(in bounds: NSRect, isOpen: Bool) -> [NSPoint] {
        let side = min(bounds.size.width, bounds.size.height) * 0.5
        let half = side / 2
        let cx = bounds.origin.x + bounds.size.width / 2
        let cy = bounds.origin.y + bounds.size.height / 2
        if isOpen {
            // Down-pointing: horizontal base across the top, apex at the bottom.
            return [
                NSPoint(x: cx - half, y: cy + half),
                NSPoint(x: cx + half, y: cy + half),
                NSPoint(x: cx, y: cy - half)
            ]
        }
        // Right-pointing: vertical base on the left, apex on the right.
        return [
            NSPoint(x: cx - half, y: cy - half),
            NSPoint(x: cx - half, y: cy + half),
            NSPoint(x: cx + half, y: cy)
        ]
    }

    /// The title shown while the button is in its alternate (on) state.
    open var alternateTitle: String = "" {
        didSet {
            syncDisplayedTitle()
        }
    }

    /// The button image, when any.
    open var image: NSImage? {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setButtonImage(imagePath: image?.filePath, for: nativeHandle)
        }
    }

    /// The image position relative to the title.
    open var imagePosition: ImagePosition = .noImage

    /// The title currently shown: the alternate title while on, else the title.
    private var displayedTitle: String {
        (state == .on && !alternateTitle.isEmpty) ? alternateTitle : title
    }

    private func syncDisplayedTitle() {
        guard let nativeHandle else {
            return
        }

        realizedBackend?.setText(displayedTitle, for: nativeHandle)
    }

    /// Button type.
    open private(set) var buttonType: ButtonType = .momentaryPushIn

    /// Button state for switch-like buttons.
    private var isUpdatingStateFromNative = false

    /// Keyboard equivalent for button activation.
    open var keyEquivalent: String = ""

    /// Whether the button draws a border.
    open var isBordered: Bool = true

    /// Whether switch-style buttons can enter the mixed state.
    open var allowsMixedState: Bool = false

    /// Button state for switch-like buttons.
    open var state: StateValue = .off {
        didSet {
            if usesFrameworkDrawnBezel {
                needsDisplay = true
            } else if !isUpdatingStateFromNative, let nativeHandle {
                realizedBackend?.setButtonState(state, for: nativeHandle)
            }
            // The alternate title swaps in on the "on" state, whether the
            // change came from code or the native toggle.
            if !alternateTitle.isEmpty {
                syncDisplayedTitle()
            }
        }
    }

    /// Creates a button with a frame.
    public override init(frame frameRect: NSRect) {
        self.title = ""
        super.init(frame: frameRect)
    }

    /// Creates a titled button with a frame.
    public init(title: String, frame frameRect: NSRect) {
        self.title = title
        super.init(frame: frameRect)
    }

    /// Creates the native Windows button peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        if usesFrameworkDrawnBezel {
            // These bezels have no native Win32 form; draw them on a view.
            return backend.createView(frame: frame, parent: parent)
        }
        switch buttonType {
        case .momentaryPushIn:
            return backend.createButton(title: title, frame: frame, parent: parent, isBordered: isBordered)
        case .switchButton:
            return backend.createCheckbox(title: title, frame: frame, parent: parent)
        case .radioButton:
            return backend.createRadioButton(title: title, frame: frame, parent: parent)
        }
    }

    /// Ensures the button has a native peer and syncs button state.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        if usesFrameworkDrawnBezel {
            // The view peer carries no native button state or click action; the
            // bezel draws from `state` and interacts via mouseDown/performClick.
            needsDisplay = true
            return handle
        }
        backend.setButtonState(state, for: handle)
        if isFlatBezel {
            backend.setButtonBezelFlat(true, for: handle)
        }
        if let image {
            backend.setButtonImage(imagePath: image.filePath, for: handle)
        }
        if !alternateTitle.isEmpty {
            backend.setText(displayedTitle, for: handle)
        }
        backend.registerAction(for: handle) { [weak self, weak backend] in
            guard let self else {
                return
            }

            if self.buttonType == .switchButton, let backend, let nativeHandle = self.nativeHandle {
                self.updateStateFromNative(backend.buttonState(for: nativeHandle))
            }

            self.sound?.play()
            _ = self.window?.makeFirstResponder(self)
            self.sendAction()
        }
        return handle
    }

    /// Fires the button when a key event matches its key equivalent.
    ///
    /// `\r`/`\n` both match Return (the default-button convention) and
    /// `\u{1b}` matches Escape; other equivalents compare directly against the
    /// event characters.
    open override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard !keyEquivalent.isEmpty, isEnabled, !isHidden, let characters = event.characters else {
            return false
        }

        let matches: Bool
        switch keyEquivalent {
        case "\r", "\n":
            matches = characters == "\r" || characters == "\n"
        default:
            matches = characters == keyEquivalent
        }
        guard matches else {
            return false
        }

        performClick(nil)
        return true
    }

    /// Programmatically performs the button action.
    open func performClick(_ sender: Any?) {
        if usesFrameworkDrawnBezel {
            if bezelTogglesState {
                state = (state == .on) ? .off : .on
            }
        } else if buttonType == .switchButton {
            setNextState()
        } else if buttonType == .radioButton {
            state = .on
            clearSiblingRadioButtons()
        }

        sendAction()
    }

    /// A click on a framework-drawn bezel toggles it (disclosure/recessed) or
    /// fires momentarily (circular/inline); native bezels use their peer.
    open override func mouseDown(with event: NSEvent) {
        guard usesFrameworkDrawnBezel, isEnabled else {
            super.mouseDown(with: event)
            return
        }

        if bezelTogglesState {
            state = (state == .on) ? .off : .on
        }
        _ = window?.makeFirstResponder(self)
        sendAction()
    }

    /// Draws the framework-only bezels; native bezels render through their peer,
    /// so this defers to `super` for them.
    open override func draw(_ dirtyRect: NSRect) {
        guard usesFrameworkDrawnBezel else {
            super.draw(dirtyRect)
            return
        }

        switch bezelStyle {
        case .disclosure, .roundedDisclosure:
            drawDisclosureBezel()
        case .circular:
            drawCircularBezel()
        case .recessed:
            drawRecessedBezel()
        case .inline:
            drawInlineBezel()
        default:
            break
        }
    }

    /// A disclosure triangle (right closed / down open), optionally framed.
    private func drawDisclosureBezel() {
        if bezelStyle == .roundedDisclosure {
            let bezel = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 3, yRadius: 3)
            NSColor.separatorColor.setStroke()
            bezel.stroke()
        }

        let vertices = NSButton.winDisclosureTriangle(in: bounds, isOpen: state == .on)
        let triangle = NSBezierPath()
        triangle.move(to: vertices[0])
        triangle.line(to: vertices[1])
        triangle.line(to: vertices[2])
        triangle.close()
        (isEnabled ? NSColor.labelColor : NSColor.tertiaryLabelColor).setFill()
        triangle.fill()
    }

    /// A round button: a filled disc with a hairline ring and centered title.
    private func drawCircularBezel() {
        let diameter = min(bounds.size.width, bounds.size.height) - 2
        let disc = NSRect(
            x: bounds.origin.x + (bounds.size.width - diameter) / 2,
            y: bounds.origin.y + (bounds.size.height - diameter) / 2,
            width: diameter,
            height: diameter
        )
        let path = NSBezierPath(ovalIn: disc)
        NSButton.winBezelFaceColor(isDark: effectiveAppearance.winIsDark).setFill()
        path.fill()
        NSColor.separatorColor.setStroke()
        path.stroke()
        drawCenteredBezelTitle(color: isEnabled ? .labelColor : .tertiaryLabelColor)
    }

    /// A recessed toggle: subtle when off, accent-filled with light text when on.
    private func drawRecessedBezel() {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
        if state == .on {
            NSColor.controlAccentColor.setFill()
            path.fill()
            drawCenteredBezelTitle(color: .white)
        } else {
            NSButton.winBezelFaceColor(isDark: effectiveAppearance.winIsDark).setFill()
            path.fill()
            drawCenteredBezelTitle(color: isEnabled ? .labelColor : .tertiaryLabelColor)
        }
    }

    /// An inline pill: a filled capsule badge with centered text.
    private func drawInlineBezel() {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let radius = rect.size.height / 2
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        NSButton.winInlineBadgeColor(isDark: effectiveAppearance.winIsDark).setFill()
        path.fill()
        drawCenteredBezelTitle(color: isEnabled ? .labelColor : .tertiaryLabelColor)
    }

    /// Draws the button's displayed title centered in its bounds.
    private func drawCenteredBezelTitle(color: NSColor) {
        let text = displayedTitle
        guard !text.isEmpty else {
            return
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: color,
            .font: font ?? NSFont.systemFont(ofSize: 12)
        ]
        let size = text.size(withAttributes: attributes)
        let origin = NSPoint(
            x: bounds.origin.x + (bounds.size.width - size.width) / 2,
            y: bounds.origin.y + (bounds.size.height - size.height) / 2
        )
        text.draw(at: origin, withAttributes: attributes)
    }

    /// The neutral face fill of a framework-drawn button, light or dark. Pure/testable.
    public static func winBezelFaceColor(isDark: Bool) -> NSColor {
        isDark ? NSColor(white: 0.24, alpha: 1) : NSColor(white: 0.96, alpha: 1)
    }

    /// The badge fill of an inline pill, light or dark. Pure/testable.
    public static func winInlineBadgeColor(isDark: Bool) -> NSColor {
        isDark ? NSColor(white: 0.32, alpha: 1) : NSColor(white: 0.90, alpha: 1)
    }

    /// Advances the button to its next state.
    open func setNextState() {
        if allowsMixedState {
            switch state {
            case .off:
                state = .on
            case .on:
                state = .mixed
            case .mixed:
                state = .off
            }
        } else {
            state = state == .on ? .off : .on
        }
    }

    /// Sets the button type.
    open func setButtonType(_ type: ButtonType) {
        buttonType = type
    }

    private func updateStateFromNative(_ state: StateValue) {
        isUpdatingStateFromNative = true
        self.state = state
        isUpdatingStateFromNative = false

        if buttonType == .radioButton, state == .on {
            clearSiblingRadioButtons()
        }
    }

    private func clearSiblingRadioButtons() {
        guard let superview else {
            return
        }

        for case let button as NSButton in superview.subviews where button !== self && button.buttonType == .radioButton {
            button.state = .off
        }
    }
}
