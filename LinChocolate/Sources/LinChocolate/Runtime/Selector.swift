/// A lightweight selector value used by AppKit-compatible control APIs — the
/// LinChocolate port of WinChocolate's `Selector`, so the shared demo's
/// `control.action?.name` reads the same on both.
///
/// Swift on Linux/GTK does not use Objective-C selectors; this preserves the
/// shape of `NSControl.action` while native dispatch runs through the control
/// event bridge.
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
