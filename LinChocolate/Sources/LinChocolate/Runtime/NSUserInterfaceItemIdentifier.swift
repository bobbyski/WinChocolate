import Foundation

/// A view/item identifier, matching Apple's declaration exactly.
///
/// AppKit types this as a distinct `RawRepresentable` wrapper around `String`
/// rather than a bare `String`, so APIs that take one (`NSCollectionView`'s
/// `register`/`makeSupplementaryView`, `NSTableView`'s `makeView`) can't be
/// passed an arbitrary string by mistake. It is `ExpressibleByStringLiteral`,
/// so `let id: NSUserInterfaceItemIdentifier = "header"` still works.
///
/// `NSView.identifier` is still `String?` here — migrating it is tracked as
/// Issue E in `Docs/AppKitFaithfulnessIssues.md`.
public struct NSUserInterfaceItemIdentifier: RawRepresentable, Hashable, Sendable,
                                             ExpressibleByStringLiteral {
    /// The underlying string type.
    public typealias RawValue = String
    /// The literal type accepted for string-literal initialization.
    public typealias StringLiteralType = String

    /// The identifier's string value.
    public var rawValue: String

    /// Creates an identifier from a string.
    public init(_ rawValue: String) { self.rawValue = rawValue }
    /// Creates an identifier from a raw string value.
    public init(rawValue: String) { self.rawValue = rawValue }
    /// Creates an identifier from a string literal.
    public init(stringLiteral value: String) { self.rawValue = value }
}
