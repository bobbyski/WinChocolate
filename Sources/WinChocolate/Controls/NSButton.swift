/// A push button control.
///
/// `NSButton` maps to the native Windows button control when realized by a
/// backend. The public surface follows AppKit's common title, target, and action
/// workflow.
open class NSButton: NSControl {
    /// Button rendering and behavior type, matching AppKit's case names
    /// (`.switch` and `.radio` — the pre-10.14 `switchButton`/`radioButton`
    /// spellings do not exist in Apple's Swift surface).
    public enum ButtonType: Sendable {
        /// Momentary push button.
        case momentaryPushIn

        /// Toggle checkbox button.
        case `switch`

        /// Mutually exclusive radio button.
        case radio
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

        /// Image on the leading edge of the title (left in LTR).
        case imageLeading

        /// Image on the trailing edge of the title (right in LTR).
        case imageTrailing
    }

    /// The button title.
    open var title: String {
        didSet {
            syncDisplayedTitle()
            invalidateIntrinsicContentSize()
        }
    }

    /// A sound played when the button is clicked.
    open var sound: NSSound?

    /// Visual bezel appearance of the button, using AppKit's modern case
    /// names (macOS 14). Apple's older spellings (`.rounded`,
    /// `.regularSquare`, `.recessed`, `.inline`, `.roundedDisclosure`,
    /// `.texturedRounded`) remain available as the same deprecated aliases
    /// Apple vends, so both generations of AppKit source compile.
    public enum BezelStyle: Sendable {
        /// Follows the button's context (treated as the standard push look).
        case automatic
        /// The standard push button (default; formerly `.rounded`).
        case push
        /// A push button of flexible height (formerly `.regularSquare`).
        case flexiblePush
        case shadowlessSquare
        case texturedSquare
        case smallSquare
        case circular
        /// The round help ("?") button.
        case helpButton
        /// A toolbar-item button (formerly `.texturedRounded`).
        case toolbar
        case disclosure
        /// A push-style disclosure (formerly `.roundedDisclosure`).
        case pushDisclosure
        /// An accessory-bar toggle (formerly `.recessed`).
        case accessoryBarAction
        /// An accessory-bar (scope) button (formerly `.roundRect`).
        case accessoryBar
        /// An inline badge (formerly `.inline`).
        case badge

        /// Apple's deprecated spelling for `.push`.
        public static var rounded: BezelStyle { .push }
        /// Apple's deprecated spelling for `.flexiblePush`.
        public static var regularSquare: BezelStyle { .flexiblePush }
        /// Apple's deprecated spelling for `.pushDisclosure`.
        public static var roundedDisclosure: BezelStyle { .pushDisclosure }
        /// Apple's deprecated spelling for `.accessoryBarAction`.
        public static var recessed: BezelStyle { .accessoryBarAction }
        /// Apple's deprecated spelling for `.accessoryBar`.
        public static var roundRect: BezelStyle { .accessoryBar }
        /// Apple's deprecated spelling for `.badge`.
        public static var inline: BezelStyle { .badge }
        /// Apple's deprecated spelling for `.toolbar`.
        public static var texturedRounded: BezelStyle { .toolbar }
    }

    /// The button's bezel style. Square styles render flat; others use the
    /// standard themed push button (full themed bezels are appearance-phase work).
    open var bezelStyle: BezelStyle = .push {
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
        case .flexiblePush, .shadowlessSquare, .texturedSquare, .smallSquare:
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
        case .disclosure, .pushDisclosure, .circular, .helpButton, .accessoryBarAction, .badge:
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
        case .disclosure, .pushDisclosure, .accessoryBarAction:
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

    /// Modifier keys required with `keyEquivalent`. Stored for AppKit shape;
    /// the key-equivalent match currently compares characters only.
    open var keyEquivalentModifierMask: NSEvent.ModifierFlags = []

    /// Whether the button draws a border.
    open var isBordered: Bool = true

    /// The button's natural size for Auto Layout (9.2): its title measured with
    /// the current font, padded for the bezel, and widened/heightened for an
    /// image when one is shown. A bordered push button also keeps a minimum
    /// height so it matches AppKit's standard control metrics.
    open override var intrinsicContentSize: NSSize {
        let text = displayedTitle
        let measured = text.isEmpty
            ? NSSize(width: 0, height: (font ?? NSFont.systemFont(ofSize: 12)).pointSize + 4)
            : text.size(withAttributes: [.font: font ?? NSFont.systemFont(ofSize: 12)])
        let hPad: CGFloat = isBordered ? 28 : 8
        let vPad: CGFloat = isBordered ? 10 : 4
        var width = measured.width + hPad
        var height = measured.height + vPad
        if let image, imagePosition != .noImage {
            let imageSize = image.size
            switch imagePosition {
            case .imageOnly:
                width = imageSize.width + 8
                height = imageSize.height + 8
            case .imageLeft, .imageRight, .imageLeading, .imageTrailing:
                width += imageSize.width + 6
                height = max(height, imageSize.height + vPad)
            case .imageAbove, .imageBelow:
                width = max(width, imageSize.width + hPad)
                height += imageSize.height + 6
            case .noImage:
                break
            }
        }
        if isBordered {
            height = max(height, 22)
        }
        return NSSize(width: width, height: height)
    }

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

    // MARK: Accessibility

    /// A checkbox reports `.checkBox`, a radio button `.radioButton`, and a
    /// push button `.button` — exactly as AppKit maps `buttonType`.
    open override var winIntrinsicAccessibilityRole: NSAccessibilityRole {
        switch buttonType {
        case .switch: return .checkBox
        case .radio: return .radioButton
        case .momentaryPushIn: return .button
        }
    }

    /// The button's title is both its title and its label for assistive tech.
    open override var winIntrinsicAccessibilityTitle: String? {
        displayedTitle.isEmpty ? nil : displayedTitle
    }
    open override var winIntrinsicAccessibilityLabel: String? {
        winIntrinsicAccessibilityTitle
    }

    /// Toggle buttons report their state as the AppKit value (1 on, 0 off,
    /// 2 mixed); a push button has no persistent value.
    open override var winIntrinsicAccessibilityValue: Any? {
        switch buttonType {
        case .switch, .radio:
            return state == .mixed ? 2 : state.rawValue
        case .momentaryPushIn:
            return nil
        }
    }

    /// Creates a button with a frame.
    public override init(frame frameRect: NSRect) {
        self.title = ""
        super.init(frame: frameRect)
    }

    /// Creates a titled button with a frame.
    init(title: String, frame frameRect: NSRect) {
        self.title = title
        super.init(frame: frameRect)
    }

    /// Creates a standard push button, matching AppKit's convenience shape.
    /// The action selector dispatches to the target on click, as in AppKit.
    public convenience init(title: String, target: AnyObject?, action: Selector?) {
        self.init(title: title, frame: .zero)
        self.target = target
        self.action = action
    }

    /// Creates a checkbox, matching AppKit's convenience shape.
    public convenience init(checkboxWithTitle title: String, target: AnyObject?, action: Selector?) {
        self.init(title: title, frame: .zero)
        setButtonType(.switch)
        self.target = target
        self.action = action
    }

    /// Creates a radio button, matching AppKit's convenience shape.
    public convenience init(radioButtonWithTitle title: String, target: AnyObject?, action: Selector?) {
        self.init(title: title, frame: .zero)
        setButtonType(.radio)
        self.target = target
        self.action = action
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
        case .switch:
            return backend.createCheckbox(title: title, frame: frame, parent: parent)
        case .radio:
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

            if self.buttonType == .switch, let backend, let nativeHandle = self.nativeHandle {
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
        } else if buttonType == .switch {
            setNextState()
        } else if buttonType == .radio {
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

        if buttonType == .radio, state == .on {
            clearSiblingRadioButtons()
        }
    }

    private func clearSiblingRadioButtons() {
        guard let superview else {
            return
        }

        for case let button as NSButton in superview.subviews where button !== self && button.buttonType == .radio {
            button.state = .off
        }
    }
}
