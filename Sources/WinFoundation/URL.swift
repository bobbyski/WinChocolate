/// A Foundation-compatible file URL subset for Windows Swift toolchains where
/// `import Foundation` is temporarily unavailable.
public struct URL: Equatable, Hashable, Sendable, CustomStringConvertible {
    private let storage: String

    /// Creates a file URL from a file-system path.
    public init(fileURLWithPath path: String) {
        self.storage = URL.normalizedFilePath(path)
    }

    /// The file-system path represented by this URL.
    public var path: String {
        storage
    }

    /// Path components split on Windows or POSIX separators.
    public var pathComponents: [String] {
        storage.split { character in
            character == "\\" || character == "/"
        }.map(String.init)
    }

    /// A display string for diagnostics.
    public var description: String {
        storage
    }

    /// Returns the final path component.
    public var lastPathComponent: String {
        pathComponents.last ?? ""
    }

    /// Returns a URL with an additional path component.
    public func appendingPathComponent(_ pathComponent: String) -> URL {
        let separator = storage.contains("\\") ? "\\" : "/"
        let base = storage.hasSuffix("\\") || storage.hasSuffix("/") ? String(storage.dropLast()) : storage
        return URL(fileURLWithPath: base + separator + pathComponent)
    }

    private static func normalizedFilePath(_ path: String) -> String {
        guard path.count > 1 else {
            return path
        }

        var result = path
        while result.count > 3 && (result.hasSuffix("\\") || result.hasSuffix("/")) {
            result.removeLast()
        }
        return result
    }
}
