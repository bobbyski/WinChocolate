/// The methods a token-field delegate implements, matching AppKit's shape:
/// token fields report text changes through the text-field delegate surface.
public protocol NSTokenFieldDelegate: NSTextFieldDelegate {}

/// A tokenizing text field.
///
/// This first slice keeps AppKit's `NSTokenField` name and token/object-value
/// surface while using a normal editable text field as the classic Win32 peer.
open class NSTokenField: NSTextField {
    /// Token display style.
    public enum TokenStyle: Sendable {
        /// AppKit's default rounded token appearance.
        case rounded

        /// Plain text token appearance.
        case plain

        /// Square-cornered token appearance.
        case squared

        /// Square-cornered tokens without a filled background.
        case plainSquared
    }

    /// Callback for completion candidates.
    public typealias CompletionHandler = (NSTokenField, String, Int) -> [String]

    /// Character used to split the field string into tokens.
    open var tokenizingCharacter: Character = "," {
        didSet {
            updateTokensFromString()
        }
    }

    /// Current token strings.
    open private(set) var tokens: [String] = []

    /// Token visual style.
    open var tokenStyle: TokenStyle = .rounded

    /// Whether tokens are drawn as rounded chips (rather than a plain edit).
    private var usesChipRendering: Bool {
        tokenStyle == .rounded
    }

    /// Whether user editing is allowed.
    open var isTokenizingEditable: Bool {
        get {
            isEditable
        }
        set {
            isEditable = newValue
        }
    }

    /// Swift-native completion hook.
    open var completionHandler: CompletionHandler?

    /// Creates a token field with a frame.
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isEditable = true
        isSelectable = true
    }

    /// Creates a token field with a zero frame, matching AppKit's shape.
    public convenience init() {
        self.init(frame: .zero)
    }

    /// Creates a token field with an initial token list.
    public init(tokens: [String], frame frameRect: NSRect) {
        super.init(string: tokens.joined(separator: ", "), frame: frameRect)
        isEditable = true
        isSelectable = true
        self.tokens = tokens
        objectValue = tokens
    }

    /// Replaces all tokens and updates the visible text.
    open func setTokens(_ tokens: [String]) {
        self.tokens = tokens
        objectValue = tokens
        stringValue = tokens.joined(separator: "\(tokenizingCharacter) ")
        if usesChipRendering {
            needsDisplay = true
        }
    }

    /// A rounded token field draws its tokens as chips on a view peer; a plain
    /// one uses the native editable text field.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        if usesChipRendering {
            return backend.createView(frame: frame, parent: parent)
        }
        return super.createNativePeer(in: backend, parent: parent)
    }

    /// Appearance-aware chip fill/border/text colors. The capsule tints the
    /// user's Windows accent (the Fluent look, plan 8.3): a pale accent wash with
    /// dark text under light, a deep accent fill with light text under dark, so
    /// the chips read as tokens in either theme instead of a fixed light island.
    /// Pure and `isDark`-parameterized for testing.
    public static func winChipColors(isDark: Bool) -> (fill: NSColor, border: NSColor, text: NSColor) {
        let accent = NSColor.controlAccentColor
        if isDark {
            return (fill: accent.blended(withFraction: 0.55, of: .black) ?? accent,
                    border: accent,
                    text: .white)
        }
        return (fill: accent.blended(withFraction: 0.80, of: .white) ?? accent,
                border: accent.blended(withFraction: 0.35, of: .white) ?? accent,
                text: .black)
    }

    /// Draws the tokens as rounded chips.
    open override func draw(_ dirtyRect: NSRect) {
        guard usesChipRendering else {
            super.draw(dirtyRect)
            return
        }

        let colors = NSTokenField.winChipColors(isDark: effectiveAppearance.winIsDark)
        let chipColor = colors.fill
        let borderColor = colors.border
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: colors.text,
            .font: NSFont.systemFont(ofSize: 12)
        ]
        let horizontalPadding: CGFloat = 10
        let height = min(bounds.size.height - 4, 22)
        let y = (bounds.size.height - height) / 2
        var x: CGFloat = 2

        for token in tokens {
            // Size each chip to its measured text so nothing is clipped.
            let textSize = token.size(withAttributes: attributes)
            let width = textSize.width + horizontalPadding * 2
            let chip = NSRect(x: x, y: y, width: width, height: height)
            let path = NSBezierPath(roundedRect: chip, xRadius: height / 2, yRadius: height / 2)
            chipColor.setFill()
            path.fill()
            borderColor.setStroke()
            path.stroke()
            // Center the text within the chip using real text metrics.
            let textOrigin = NSPoint(x: x + horizontalPadding, y: y + (height - textSize.height) / 2)
            token.draw(at: textOrigin, withAttributes: attributes)
            x += width + 6
        }
    }

    /// Returns completion candidates for a substring.
    open func completions(for substring: String, indexOfToken tokenIndex: Int) -> [String] {
        completionHandler?(self, substring, tokenIndex) ?? []
    }

    /// Ensures native edits refresh the token list.
    override func nativeStringValueDidChange() {
        updateTokensFromString()
    }

    private func updateTokensFromString() {
        let pieces = stringValue.split(separator: tokenizingCharacter)
        tokens = pieces.map { piece in
            trimWhitespace(String(piece))
        }.filter { !$0.isEmpty }
        objectValue = tokens
    }

    private func trimWhitespace(_ string: String) -> String {
        var scalars = Array(string.unicodeScalars)
        while let first = scalars.first, first.value <= 32 {
            scalars.removeFirst()
        }
        while let last = scalars.last, last.value <= 32 {
            scalars.removeLast()
        }
        return String(String.UnicodeScalarView(scalars))
    }
}
