/// Stable identifier used by AppKit-style interface items.
public struct NSUserInterfaceItemIdentifier: Equatable, Hashable, Sendable, ExpressibleByStringLiteral {
    /// The raw identifier string.
    public var rawValue: String

    /// Creates an identifier from a raw string.
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates an identifier from a string literal.
    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}
