/// A small Foundation-compatible byte buffer subset.
public struct Data: Equatable, Hashable, Sendable, Sequence {
    public typealias Element = UInt8

    private var bytes: [UInt8]

    /// Creates empty data.
    public init() {
        self.bytes = []
    }

    /// Creates data from a byte sequence.
    public init<S>(_ elements: S) where S: Sequence, S.Element == UInt8 {
        self.bytes = Array(elements)
    }

    /// Number of bytes.
    public var count: Int {
        bytes.count
    }

    /// Whether the buffer is empty.
    public var isEmpty: Bool {
        bytes.isEmpty
    }

    /// Returns the bytes as an array.
    public var array: [UInt8] {
        bytes
    }

    public func makeIterator() -> IndexingIterator<[UInt8]> {
        bytes.makeIterator()
    }
}
