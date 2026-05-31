/// A lightweight file URL value used while Foundation import is unavailable on
/// the current Windows Swift toolchain.
public struct URL: Equatable, Sendable {
    /// The file-system path.
    public var path: String

    /// Creates a file URL from a path.
    public init(fileURLWithPath path: String) {
        self.path = path
    }

    /// Path components split on Windows or POSIX separators.
    public var pathComponents: [String] {
        path.split { character in
            character == "\\" || character == "/"
        }.map(String.init)
    }
}
