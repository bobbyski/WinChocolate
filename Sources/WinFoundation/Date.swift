/// A minimal Foundation-compatible instant value.
public struct Date: Equatable, Comparable, Hashable, Sendable {
    private let secondsSinceReferenceDate: Double

    /// Creates a date for the current instant.
    ///
    /// Until WinFoundation has a native clock bridge, this returns the reference
    /// date. It exists to keep AppKit-shaped API surfaces source-compatible.
    public init() {
        self.secondsSinceReferenceDate = 0
    }

    /// Creates a date offset from Foundation's reference date.
    public init(timeIntervalSinceReferenceDate seconds: Double) {
        self.secondsSinceReferenceDate = seconds
    }

    /// Seconds since Foundation's reference date.
    public var timeIntervalSinceReferenceDate: Double {
        secondsSinceReferenceDate
    }

    public static func < (lhs: Date, rhs: Date) -> Bool {
        lhs.secondsSinceReferenceDate < rhs.secondsSinceReferenceDate
    }
}
