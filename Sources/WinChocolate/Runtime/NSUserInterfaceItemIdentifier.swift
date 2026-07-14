/// Stable identifier used by AppKit-style interface items, matching Apple's
/// `RawRepresentable` struct exactly. Deliberately NOT
/// `ExpressibleByStringLiteral` — Apple's isn't, so string literals must go
/// through the explicit initializers, exactly as on macOS (18.12 round 2).
public struct NSUserInterfaceItemIdentifier: RawRepresentable, Equatable, Hashable, Sendable {
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
}
