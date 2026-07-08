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

    /// Whether this button is a framework-drawn disclosure triangle rather than a
    /// native push button. The triangle points right when closed (`.off`) and
    /// down when open (`.on`), toggling on each click — AppKit's disclosure
    /// control, which has no native Win32 form.
    var usesDisclosureRendering: Bool {
        switch bezelStyle {
        case .disclosure, .roundedDisclosure:
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
            if usesDisclosureRendering {
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
        if usesDisclosureRendering {
            // Disclosure triangles have no native Win32 form; draw them on a view.
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
        if usesDisclosureRendering {
            // The view peer carries no native button state or click action; the
            // triangle draws from `state` and toggles via mouseDown/performClick.
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
        if usesDisclosureRendering {
            state = (state == .on) ? .off : .on
        } else if buttonType == .switchButton {
            setNextState()
        } else if buttonType == .radioButton {
            state = .on
            clearSiblingRadioButtons()
        }

        sendAction()
    }

    /// A click on a disclosure triangle toggles it open/closed and fires the
    /// action; other bezel styles use their native button behavior.
    open override func mouseDown(with event: NSEvent) {
        guard usesDisclosureRendering, isEnabled else {
            super.mouseDown(with: event)
            return
        }

        state = (state == .on) ? .off : .on
        _ = window?.makeFirstResponder(self)
        sendAction()
    }

    /// Draws the disclosure triangle (right when closed, down when open); the
    /// rounded-disclosure variant frames it with a hairline bezel. Non-disclosure
    /// buttons render through their native peer, so this defers to `super`.
    open override func draw(_ dirtyRect: NSRect) {
        guard usesDisclosureRendering else {
            super.draw(dirtyRect)
            return
        }

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
