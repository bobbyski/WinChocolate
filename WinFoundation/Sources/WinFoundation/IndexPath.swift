/// A Foundation-shaped path of integer indexes.
///
/// This lightweight WinFoundation slice covers the collection/table selection
/// use cases WinChocolate needs while the real Windows Foundation import is
/// unavailable.
public struct IndexPath: Hashable, Sendable, ExpressibleByArrayLiteral, RandomAccessCollection {
    public typealias Element = Int
    public typealias Index = Int

    private var indexes: [Int]

    /// Creates an empty index path.
    public init() {
        self.indexes = []
    }

    /// Creates an index path from a sequence of indexes.
    public init(indexes: [Int]) {
        self.indexes = indexes
    }

    /// Creates an AppKit collection-view item/section index path.
    public init(item: Int, section: Int) {
        self.indexes = [section, item]
    }

    /// Creates an index path from an array literal.
    public init(arrayLiteral elements: Int...) {
        self.indexes = elements
    }

    /// Number of indexes in the path.
    public var count: Int {
        indexes.count
    }

    /// Start collection index.
    public var startIndex: Int {
        indexes.startIndex
    }

    /// End collection index.
    public var endIndex: Int {
        indexes.endIndex
    }

    /// Accesses an index component.
    public subscript(position: Int) -> Int {
        indexes[position]
    }

    /// Collection-view item component.
    public var item: Int {
        indexes.count > 1 ? indexes[1] : (indexes.first ?? 0)
    }

    /// Collection-view section component.
    public var section: Int {
        indexes.first ?? 0
    }

    /// Returns a path with one more index appended.
    public func appending(_ index: Int) -> IndexPath {
        var copy = indexes
        copy.append(index)
        return IndexPath(indexes: copy)
    }
}

extension IndexPath: Comparable {
    /// Lexicographic ordering, matching Foundation: compare component by
    /// component, and a shorter prefix sorts before its longer extension.
    public static func < (lhs: IndexPath, rhs: IndexPath) -> Bool {
        for (left, right) in zip(lhs.indexes, rhs.indexes) where left != right {
            return left < right
        }
        return lhs.indexes.count < rhs.indexes.count
    }
}

extension IndexPath: Codable {
    /// Decodes an index path from an unkeyed sequence of integers.
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var decoded: [Int] = []
        while !container.isAtEnd {
            decoded.append(try container.decode(Int.self))
        }
        self.init(indexes: decoded)
    }

    /// Encodes an index path as an unkeyed sequence of integers.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for index in indexes {
            try container.encode(index)
        }
    }
}
