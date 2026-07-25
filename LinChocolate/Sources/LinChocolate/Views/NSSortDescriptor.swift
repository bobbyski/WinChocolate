import Foundation

/// AppKit-shaped sort descriptor: a key plus a direction. Attached to a table
/// column via `sortDescriptorPrototype`; the active descriptor is delivered to
/// the data source's `tableView(_:sortDescriptorsDidChange:)` when a header is
/// clicked, and the data source re-sorts its own model.
///
/// LinChocolate defines its own (rather than reusing Foundation's) because
/// swift-corelibs-foundation deprecated `NSSortDescriptor(key:ascending:)` —
/// KVC isn't available on Linux — so the AppKit `key:` API needs this type.
/// Client code importing both modules should qualify it as
/// `LinChocolate.NSSortDescriptor` to avoid ambiguity with Foundation's.
public final class NSSortDescriptor: Equatable {
    /// The sort key (a column identifier chosen by the data source).
    public let key: String?
    /// The sort direction (`true` for ascending).
    public let ascending: Bool

    /// Creates a sort descriptor with the given key and direction.
    public init(key: String?, ascending: Bool) {
        self.key = key
        self.ascending = ascending
    }

    /// The same descriptor with the opposite direction.
    public var reversedSortDescriptor: NSSortDescriptor {
        NSSortDescriptor(key: key, ascending: !ascending)
    }

    /// Two descriptors are equal when their key and direction match.
    public static func == (lhs: NSSortDescriptor, rhs: NSSortDescriptor) -> Bool {
        lhs.key == rhs.key && lhs.ascending == rhs.ascending
    }
}
