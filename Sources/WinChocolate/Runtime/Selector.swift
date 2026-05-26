/// A lightweight selector value used by AppKit-compatible control APIs.
///
/// Swift on Windows does not provide Objective-C selectors. This type preserves
/// the shape of properties such as `NSControl.action` while native dispatch is
/// handled by WinChocolate's control event bridge.
public struct Selector: Equatable, Hashable, Sendable, ExpressibleByStringLiteral {
    /// The textual selector name.
    public let name: String

    /// Creates a selector from a textual name.
    public init(_ name: String) {
        self.name = name
    }

    /// Creates a selector from a string literal.
    public init(stringLiteral value: String) {
        self.name = value
    }
}
