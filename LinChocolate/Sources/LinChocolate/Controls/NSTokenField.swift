import Foundation

/// AppKit-shaped token field. A composed control (GTK has no peer): tokens
/// render as removable chips ahead of a text entry; typing text and pressing
/// Enter adds a token, clicking a chip removes it.
public final class NSTokenField: NSView {

    private var backingTokens: [String]

    /// The tokens, in order (AppKit's `objectValue` array-of-strings shape).
    /// Setting it replaces the chips; the user's own edits flow back in.
    public var objectValue: [String] {
        get { backingTokens }
        set {
            backingTokens = newValue
            backend.setTokens(newValue, for: handle)
        }
    }

    /// Called after the user adds or removes a token.
    public var onTokensChange: ((NSTokenField) -> Void)?

    /// Creates a token field with initial `tokens`.
    public init(tokens: [String] = [], frame: NSRect) {
        self.backingTokens = tokens
        let backend = NSApplication.shared.nativeBackend
        let handle = backend.createTokenField(tokens: tokens, frame: frame)
        super.init(frame: frame, handle: handle, backend: backend)
        backend.setTokensChangeAction(for: handle) { [weak self] tokens in
            guard let self else { return }
            self.backingTokens = tokens        // sync silently
            self.onTokensChange?(self)
        }
    }
}
