/// Root class for WinChocolate objects.
///
/// AppKit's public API is class-heavy and often inherits from `NSObject`.
/// WinChocolate provides a small Swift-native root object so those inheritance
/// relationships can be represented on Windows without depending on Objective-C
/// runtime behavior.
open class NSObject {
    /// Creates a root object.
    public init() {}
}

extension NSObject: Equatable {
    /// Identity equality, matching `NSObject`'s default `isEqual(_:)`.
    public static func == (lhs: NSObject, rhs: NSObject) -> Bool {
        lhs === rhs
    }
}

extension NSObject: Hashable {
    /// Identity hash, matching `NSObject`'s default `hash`.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
