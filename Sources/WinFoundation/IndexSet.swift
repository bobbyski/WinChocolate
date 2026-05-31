/// A small sorted integer-index set compatible with common Foundation `IndexSet`
/// usage.
public struct IndexSet: Equatable, Sendable, Sequence {
    private var storage: Set<Int>

    /// Creates an empty index set.
    public init() {
        self.storage = []
    }

    /// Creates a set containing one index.
    public init(integer: Int) {
        self.storage = [integer]
    }

    /// Creates a set containing a range of indexes.
    public init(integersIn range: Range<Int>) {
        self.storage = Set(range)
    }

    /// Inserts an index.
    public mutating func insert(_ integer: Int) {
        storage.insert(integer)
    }

    /// Removes an index.
    public mutating func remove(_ integer: Int) {
        storage.remove(integer)
    }

    /// Returns whether the index is present.
    public func contains(_ integer: Int) -> Bool {
        storage.contains(integer)
    }

    /// Number of indexes.
    public var count: Int {
        storage.count
    }

    /// Whether the set is empty.
    public var isEmpty: Bool {
        storage.isEmpty
    }

    public func makeIterator() -> IndexingIterator<[Int]> {
        storage.sorted().makeIterator()
    }
}
