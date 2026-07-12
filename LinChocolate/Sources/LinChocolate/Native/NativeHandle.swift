/// Opaque identity for a native Linux (GTK) object.
///
/// Public controls keep their AppKit-compatible API, while the backend stores
/// real platform handles (GTK widget pointers) behind this stable value. Tests
/// and non-windowed code can use synthetic identifiers without opening a window.
///
/// This mirrors WinChocolate's `NativeHandle` byte-for-byte so the two siblings
/// can converge onto a shared core later (LinChocolatePlan Phase L6).
public struct NativeHandle: Equatable, Hashable, Sendable {
    /// Backend-owned raw value.
    public let rawValue: UInt

    /// Creates a handle from a backend-owned raw value.
    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }
}
