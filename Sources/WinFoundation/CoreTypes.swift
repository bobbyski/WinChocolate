/// Foundation's standard time interval type.
public typealias TimeInterval = Double

/// Foundation's sentinel for a missing location or index.
public let NSNotFound: Int = Int.max

/// A Foundation-compatible description of a portion of a series, such as
/// characters in a string.
public struct NSRange: Equatable, Hashable, Sendable {
    /// The start index of the range.
    public var location: Int

    /// The number of items in the range.
    public var length: Int

    /// Creates an empty range at location zero.
    public init() {
        self.location = 0
        self.length = 0
    }

    /// Creates a range with a start location and length.
    public init(location: Int, length: Int) {
        self.location = location
        self.length = length
    }

    /// The sum of the location and length.
    public var upperBound: Int {
        location + length
    }

    /// The range location.
    public var lowerBound: Int {
        location
    }

    /// Returns whether an index lies inside the range.
    public func contains(_ index: Int) -> Bool {
        index >= location && index < upperBound
    }
}

/// Creates a range from a location and length, matching Foundation's helper.
public func NSMakeRange(_ location: Int, _ length: Int) -> NSRange {
    NSRange(location: location, length: length)
}

/// Objective-C's boolean bridge type, kept so `FileManager` call sites that
/// pass `&isDirectory` compile unchanged on Windows.
public struct ObjCBool: ExpressibleByBooleanLiteral, Sendable {
    /// The wrapped boolean value.
    public var boolValue: Bool

    /// Creates a value wrapping a boolean.
    public init(_ value: Bool) {
        self.boolValue = value
    }

    /// Creates a value from a boolean literal.
    public init(booleanLiteral value: Bool) {
        self.boolValue = value
    }
}
