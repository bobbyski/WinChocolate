/// Horizontal text alignment, matching AppKit names.
public enum NSTextAlignment: Sendable {
    /// Left-aligned text.
    case left

    /// Center-aligned text.
    case center

    /// Right-aligned text.
    case right

    /// Natural alignment for the writing direction (left here).
    case natural

    /// Fully-justified text. Native edit controls have no justified mode,
    /// so rendering falls back to the natural alignment.
    case justified
}

/// The methods a text field delegate uses to observe editing.
public protocol NSTextFieldDelegate: NSObjectProtocol {
    /// Tells the delegate that editing began in the control (focus gained).
    func controlTextDidBeginEditing(_ obj: NSNotification)

    /// Tells the delegate that the control's text changed.
    func controlTextDidChange(_ obj: NSNotification)

    /// Tells the delegate that editing ended in the control (focus lost).
    func controlTextDidEndEditing(_ obj: NSNotification)

    /// Asks the delegate to handle a field-editor command (AppKit's
    /// `control(_:textView:doCommandBy:)`). Return `true` to consume the
    /// command. The drawn table's cell editor uses this to intercept
    /// `insertTab:`/`insertBacktab:` and move editing to the next cell instead
    /// of letting focus leave the field.
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool
}

extension NSTextFieldDelegate {
    /// Default no-op so delegates only implement the callbacks they need.
    public func controlTextDidBeginEditing(_ obj: NSNotification) {}

    /// Default no-op so delegates only implement the callbacks they need.
    public func controlTextDidChange(_ obj: NSNotification) {}

    /// Default no-op so delegates only implement the callbacks they need.
    public func controlTextDidEndEditing(_ obj: NSNotification) {}

    /// Default: the delegate handles no field-editor commands.
    public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool { false }
}

/// A single-line text entry or label control.
///
/// `NSTextField` maps to a native Windows edit/static control depending on later
/// style support. This initial API preserves AppKit's `stringValue` property.
open class NSTextField: NSControl {
    /// Notification names posted by control text editing, matching AppKit.
    public static let textDidBeginEditingNotification = "NSControlTextDidBeginEditingNotification"

    /// Posted when the control's text changes during editing.
    public static let textDidChangeNotification = "NSControlTextDidChangeNotification"

    /// Posted when editing ends in the control.
    public static let textDidEndEditingNotification = "NSControlTextDidEndEditingNotification"

    /// The delegate notified about editing begin/change/end.
    open weak var delegate: NSTextFieldDelegate?
    private var isUpdatingFromNative = false

    /// The object value, rendered through `formatter` for display when set.
    open override var objectValue: Any? {
        get { super.objectValue }
        set {
            super.objectValue = newValue
            applyFormatterForDisplay()
        }
    }

    /// The formatter converting between `objectValue` and the field text.
    open override var formatter: Formatter? {
        get { super.formatter }
        set {
            super.formatter = newValue
            applyFormatterForDisplay()
        }
    }

    /// Renders `objectValue` through the formatter into the visible text.
    private func applyFormatterForDisplay() {
        guard let formatter, let objectValue = super.objectValue,
              let formatted = formatter.string(for: objectValue) else {
            return
        }

        stringValue = formatted
    }

    /// Parses the edited text back into `objectValue` and re-displays it.
    ///
    /// On a successful parse the field shows the canonical formatted string; on
    /// failure it reverts to the last valid `objectValue`.
    private func commitFormattedValue() {
        guard let numberFormatter = formatter as? NumberFormatter else {
            return
        }

        if let parsed = numberFormatter.number(from: stringValue) {
            super.objectValue = parsed
            if let formatted = numberFormatter.string(from: parsed) {
                stringValue = formatted
            }
        } else if let objectValue = super.objectValue,
                  let formatted = numberFormatter.string(for: objectValue) {
            stringValue = formatted
        }
    }

    /// The text field's current string value.
    open var stringValue: String {
        didSet {
            guard !isUpdatingFromNative else {
                return
            }

            // The text drives the field's intrinsic size (9.2), so a change
            // schedules a layout pass for any constraint layout hosting it.
            invalidateIntrinsicContentSize()

            guard let nativeHandle else {
                return
            }

            realizedBackend?.setText(stringValue, for: nativeHandle)
        }
    }

    /// Whether the text field accepts keyboard editing.
    open var isEditable: Bool = false

    /// Whether the text field accepts selection.
    open var isSelectable: Bool = false

    /// Text fields the user can edit or select from show the I-beam cursor over
    /// their content, like AppKit. A pure static label keeps the arrow.
    open override func resetCursorRects() {
        guard isEditable || isSelectable else { return }
        addCursorRect(bounds, cursor: .iBeam)
    }

    // MARK: Accessibility

    /// An editable field is a text field; a static (label) field is static text
    /// — matching AppKit, where a non-editable, non-selectable field reports
    /// `AXStaticText`.
    open override var winIntrinsicAccessibilityRole: NSAccessibilityRole {
        (isEditable || isSelectable) ? .textField : .staticText
    }

    /// The field's text is its accessibility value; the placeholder is its
    /// label when no explicit label was set.
    open override var winIntrinsicAccessibilityValue: Any? { stringValue }
    open override var winIntrinsicAccessibilityLabel: String? {
        let placeholder = placeholderString ?? ""
        return placeholder.isEmpty ? nil : placeholder
    }

    /// The field's background fill, matching AppKit's
    /// `NSTextField.backgroundColor` (one of the concrete types where Apple
    /// exposes a background color — plain `NSView` has none).
    open var backgroundColor: NSColor? {
        get { winBackgroundColor }
        set { winBackgroundColor = newValue }
    }

    /// Whether the text field draws a border.
    open var isBordered: Bool = true

    /// Bezel appearance for a bezeled text field.
    public enum BezelStyle: Sendable {
        /// Square-cornered bezel (default entry field).
        case squareBezel

        /// Rounded-corner bezel (search/rounded field look).
        case roundedBezel
    }

    /// Whether the field draws a sunken bezel around its editing area.
    ///
    /// A bezeled field gets a native sunken client-edge border; the rounded vs
    /// square distinction (`bezelStyle`) is appearance-phase polish.
    open var isBezeled: Bool = false {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setTextFieldBezeled(isBezeled, for: nativeHandle)
        }
    }

    /// The bezel style used when `isBezeled` is set.
    open var bezelStyle: BezelStyle = .squareBezel

    /// Whether the field forces a single line of text.
    ///
    /// When cleared together with a `maximumNumberOfLines` other than 1, AppKit
    /// wraps text; WinChocolate routes true multi-line entry through
    /// `NSTextView`, so this stores the intent for source compatibility.
    open var usesSingleLineMode: Bool = true

    /// The maximum number of lines the field lays out (0 means no limit).
    open var maximumNumberOfLines: Int = 1

    /// Whether the text field draws its background.
    open var drawsBackground: Bool = true {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setDrawsBackground(drawsBackground, for: nativeHandle)
        }
    }

    /// Placeholder text for editable fields.
    open var placeholderString: String? {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setTextPlaceholder(placeholderString, for: nativeHandle)
        }
    }

    /// Horizontal alignment of the field's text.
    open var alignment: NSTextAlignment = .natural {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setTextAlignment(alignment, for: nativeHandle)
        }
    }

    /// The text color, when explicitly set.
    open var textColor: NSColor? {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setTextColor(textColor, for: nativeHandle)
        }
    }

    /// The field's content as an attributed string.
    ///
    /// The classic peer renders plain text; the attributed form is stored so
    /// runs survive round-trips while the plain projection drives display.
    open var attributedStringValue: NSAttributedString {
        get { storedAttributedStringValue ?? NSAttributedString(string: stringValue) }
        set {
            storedAttributedStringValue = newValue
            stringValue = newValue.string
        }
    }
    private var storedAttributedStringValue: NSAttributedString?

    /// Framework-internal edit hook (form cells track their field's text).
    /// Not API: applications use `controlTextDidChange(_:)` on the delegate,
    /// as in AppKit.
    var winInternalTextChanged: ((NSTextField) -> Void)?

    /// Creates a text field with a frame.
    public override init(frame frameRect: NSRect) {
        self.stringValue = ""
        super.init(frame: frameRect)
    }

    /// The field's baseline sits above its bottom edge by the bezel/border
    /// padding plus an approximated font descent (~21% of the point size, the
    /// typical ratio for UI faces; exact per-font metrics are a refinement).
    open override var baselineOffsetFromBottom: CGFloat {
        let pad: CGFloat = isBezeled ? 3 : (isBordered ? 2 : 1)
        return pad + (font ?? NSFont.systemFont(ofSize: 12)).pointSize * 0.21
    }

    /// The field's natural size for Auto Layout (9.2): its text measured with
    /// the current font, plus padding for the bezel/border. A wrapping
    /// multi-line field reports no intrinsic width so constraints can widen it.
    open override var intrinsicContentSize: NSSize {
        let measured = (stringValue.isEmpty ? " " : stringValue)
            .size(withAttributes: [.font: font ?? NSFont.systemFont(ofSize: 12)])
        let horizontalPadding: CGFloat = isBezeled ? 8 : (isBordered ? 6 : 4)
        let verticalPadding: CGFloat = isBezeled ? 6 : (isBordered ? 4 : 2)
        let width = isMultiline ? NSView.noIntrinsicMetric : measured.width + horizontalPadding
        return NSSize(width: width, height: measured.height + verticalPadding)
    }

    /// Creates a text field with text and a frame.
    init(string stringValue: String, frame frameRect: NSRect) {
        self.stringValue = stringValue
        super.init(frame: frameRect)
    }

    /// Creates a text field with an initial string, matching AppKit's shape.
    public convenience init(string stringValue: String) {
        self.init(string: stringValue, frame: .zero)
    }

    /// Creates a non-editable label, matching AppKit's convenience shape.
    public convenience init(labelWithString stringValue: String) {
        self.init(string: stringValue, frame: .zero)
        isEditable = false
        isSelectable = false
        isBordered = false
        drawsBackground = false
    }

    /// Creates a wrapping non-editable label, matching AppKit's shape.
    public convenience init(wrappingLabelWithString stringValue: String) {
        self.init(labelWithString: stringValue)
    }

    /// Creates a non-editable label-style text field.
    public static func label(withString stringValue: String) -> NSTextField {
        let field = NSTextField(string: stringValue, frame: NSZeroRect)
        field.isEditable = false
        field.isSelectable = false
        field.isBordered = false
        field.drawsBackground = false
        return field
    }

    /// Creates a non-editable wrapping label-style text field.
    public static func wrappingLabel(withString stringValue: String) -> NSTextField {
        label(withString: stringValue)
    }

    /// Creates an editable text field with an initial string.
    public static func textField(withString stringValue: String) -> NSTextField {
        let field = NSTextField(string: stringValue, frame: NSZeroRect)
        field.isEditable = true
        field.isSelectable = true
        field.isBordered = true
        field.drawsBackground = true
        return field
    }

    /// Whether the field wraps onto multiple lines (a non-single-line mode with
    /// room for more than one line).
    var isMultiline: Bool {
        isEditable && !usesSingleLineMode && maximumNumberOfLines != 1
    }

    /// Creates the native Windows text field peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createTextField(text: stringValue, frame: frame, parent: parent, isEditable: isEditable, isBordered: isBordered, isMultiline: isMultiline)
    }

    /// Ensures the text field has a native peer and registers text change dispatch.
    @discardableResult
    open override func realizeNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        let handle = super.realizeNativePeer(in: backend, parent: parent)
        // Labels (non-editable, no explicit background color) show the window
        // color instead of an opaque control-face rectangle. Editable fields
        // and any field given a background color stay opaque.
        let showsBackground = (isEditable || winBackgroundColor != nil) && drawsBackground
        backend.setDrawsBackground(showsBackground, for: handle)
        if isBezeled {
            backend.setTextFieldBezeled(true, for: handle)
        }
        backend.setTextColor(textColor, for: handle)
        backend.setFont(font, for: handle)
        if let placeholderString {
            backend.setTextPlaceholder(placeholderString, for: handle)
        }
        if alignment != .natural {
            backend.setTextAlignment(alignment, for: handle)
        }
        backend.registerTextChangeAction(for: handle) { [weak self] text in
            guard let self else {
                return
            }

            _ = self.window?.makeFirstResponder(self)
            self.updateStringValueFromNative(text)
        }
        // Editable fields report begin/end editing on focus change so
        // `NSTextFieldDelegate` and the AppKit editing notifications fire.
        if isEditable {
            backend.registerFocusChangeAction(for: handle) { [weak self] gained in
                guard let self else {
                    return
                }

                if gained {
                    self.delegate?.controlTextDidBeginEditing(self.editingNotification(named: Self.textDidBeginEditingNotification))
                } else {
                    // Editing ended: parse the text through the formatter so
                    // objectValue and the displayed text settle to a valid value.
                    self.commitFormattedValue()
                    self.delegate?.controlTextDidEndEditing(self.editingNotification(named: Self.textDidEndEditingNotification))
                }
            }
        }
        return handle
    }

    func updateStringValueFromNative(_ text: String) {
        isUpdatingFromNative = true
        stringValue = text
        isUpdatingFromNative = false
        nativeStringValueDidChange()
        winInternalTextChanged?(self)
        delegate?.controlTextDidChange(editingNotification(named: Self.textDidChangeNotification))
    }

    func editingNotification(named name: String) -> NSNotification {
        NSNotification(name: name, object: self)
    }

    func nativeStringValueDidChange() {}
}
