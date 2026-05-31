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
