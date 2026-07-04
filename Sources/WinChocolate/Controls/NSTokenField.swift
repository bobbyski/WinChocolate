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

    /// Draws the tokens as rounded chips.
    open override func draw(_ dirtyRect: NSRect) {
        guard usesChipRendering else {
            super.draw(dirtyRect)
            return
        }

        let chipColor = NSColor(calibratedRed: 0.85, green: 0.91, blue: 1.0, alpha: 1)
        let borderColor = NSColor(calibratedRed: 0.40, green: 0.58, blue: 0.85, alpha: 1)
        let font = NSFont.systemFont(ofSize: 12)
        let height = min(bounds.size.height - 4, 22)
        let y = (bounds.size.height - height) / 2
        var x: CGFloat = 2

        for token in tokens {
            let width = CGFloat(token.count) * 7 + 20
            let chip = NSRect(x: x, y: y, width: width, height: height)
            let path = NSBezierPath(roundedRect: chip, xRadius: height / 2, yRadius: height / 2)
            chipColor.setFill()
            path.fill()
            borderColor.setStroke()
            path.stroke()
            token.draw(
                at: NSPoint(x: x + 10, y: y + (height - 14) / 2),
                withAttributes: [.foregroundColor: NSColor.black, .font: font]
            )
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
