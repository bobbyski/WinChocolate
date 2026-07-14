/// Stable identifier used by AppKit-style interface items, matching Apple's
/// `RawRepresentable` + `ExpressibleByStringLiteral` struct exactly.
public struct NSUserInterfaceItemIdentifier: RawRepresentable, Equatable, Hashable, Sendable, ExpressibleByStringLiteral {
    /// The raw identifier string.
    public var rawValue: String

    /// Creates an identifier from a raw string (Apple's `init(rawValue:)`).
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates an identifier from a raw string (Apple's unlabeled form).
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    /// Creates an identifier from a string literal.
    public init(stringLiteral value: String) {
        self.rawValue = value
    }
}
