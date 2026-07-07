/// A small sorted integer-index set compatible with common Foundation `IndexSet`
/// usage.
public struct IndexSet: Equatable, Hashable, Sendable, Sequence {
    private var storage: Set<Int>

    /// Creates an empty index set.
    public init() {
        self.storage = []
    }

    /// Creates a set containing one index.
    public init(integer: Int) {
        self.storage = [integer]
    }

    /// Creates a set from any sequence of indexes (e.g. a `Set<Int>` or array).
    public init<S: Sequence>(_ indexes: S) where S.Element == Int {
        self.storage = Set(indexes)
    }

    /// Creates a set containing a range of indexes.
    public init(integersIn range: Range<Int>) {
        self.storage = Set(range)
    }

    /// Creates a set containing a closed range of indexes.
    public init(integersIn range: ClosedRange<Int>) {
        self.storage = Set(range)
    }

    /// Inserts an index.
    public mutating func insert(_ integer: Int) {
        storage.insert(integer)
    }

    /// Inserts a range of indexes.
    public mutating func insert(integersIn range: Range<Int>) {
        storage.formUnion(range)
    }

    /// Inserts a closed range of indexes.
    public mutating func insert(integersIn range: ClosedRange<Int>) {
        storage.formUnion(range)
    }

    /// Removes an index.
    public mutating func remove(_ integer: Int) {
        storage.remove(integer)
    }

    /// Removes a range of indexes.
    public mutating func remove(integersIn range: Range<Int>) {
        storage.subtract(range)
    }

    /// Removes a closed range of indexes.
    public mutating func remove(integersIn range: ClosedRange<Int>) {
        storage.subtract(range)
    }

    /// Returns whether the index is present.
    public func contains(_ integer: Int) -> Bool {
        storage.contains(integer)
    }

    /// Returns whether all indexes in the range are present.
    public func contains(integersIn range: Range<Int>) -> Bool {
        range.allSatisfy(storage.contains)
    }

    /// Returns whether all indexes in the closed range are present.
    public func contains(integersIn range: ClosedRange<Int>) -> Bool {
        range.allSatisfy(storage.contains)
    }

    /// Returns whether any index in the range is present.
    public func intersects(integersIn range: Range<Int>) -> Bool {
        range.contains { storage.contains($0) }
    }

    /// Returns whether any index in the closed range is present.
    public func intersects(integersIn range: ClosedRange<Int>) -> Bool {
        range.contains { storage.contains($0) }
    }

    /// Returns a new index set containing this set and another set.
    public func union(_ other: IndexSet) -> IndexSet {
        IndexSet(storage: storage.union(other.storage))
    }

    /// Adds the indexes from another set.
    public mutating func formUnion(_ other: IndexSet) {
        storage.formUnion(other.storage)
    }

    /// Returns a new index set containing indexes present in both sets.
    public func intersection(_ other: IndexSet) -> IndexSet {
        IndexSet(storage: storage.intersection(other.storage))
    }

    /// Keeps only indexes present in both sets.
    public mutating func formIntersection(_ other: IndexSet) {
        storage.formIntersection(other.storage)
    }

    /// Returns a new index set with another set removed.
    public func subtracting(_ other: IndexSet) -> IndexSet {
        IndexSet(storage: storage.subtracting(other.storage))
    }

    /// Removes indexes present in another set.
    public mutating func subtract(_ other: IndexSet) {
        storage.subtract(other.storage)
    }

    /// The smallest contained index.
    public var first: Int? {
        storage.min()
    }

    /// The largest contained index.
    public var last: Int? {
        storage.max()
    }

    /// Returns the smallest contained index greater than the given index.
    public func integerGreaterThan(_ integer: Int) -> Int? {
        storage.filter { $0 > integer }.min()
    }

    /// Returns the smallest contained index greater than or equal to the given index.
    public func integerGreaterThanOrEqualTo(_ integer: Int) -> Int? {
        storage.filter { $0 >= integer }.min()
    }

    /// Returns the largest contained index less than the given index.
    public func integerLessThan(_ integer: Int) -> Int? {
        storage.filter { $0 < integer }.max()
    }

    /// Returns the largest contained index less than or equal to the given index.
    public func integerLessThanOrEqualTo(_ integer: Int) -> Int? {
        storage.filter { $0 <= integer }.max()
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

    private init(storage: Set<Int>) {
        self.storage = storage
    }
}
