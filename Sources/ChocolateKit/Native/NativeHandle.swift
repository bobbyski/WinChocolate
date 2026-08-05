/// Opaque identity for a native Windows object.
///
/// Public controls keep their AppKit-compatible API, while the backend stores
/// real platform handles behind this stable value. Tests and non-windowed code
/// can use synthetic identifiers without opening a native window.
public struct NativeHandle: Equatable, Hashable, Sendable {
    /// Backend-owned raw value.
    public let rawValue: UInt

    /// Creates a handle from a backend-owned raw value.
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
}
