extension FileManager {
    /// Errors thrown by file operations.
    ///
    /// Foundation reports these through `NSError`; the shim uses a Swift
    /// error enum carrying the path involved.
    public enum FileError: Error, Equatable {
        /// The path does not exist.
        case fileNotFound(String)

        /// The destination already exists.
        case alreadyExists(String)

        /// The underlying system call failed.
        case operationFailed(String)
    }

    /// Known directory locations for `urls(for:in:)`.
    public enum SearchPathDirectory: Sendable {
        /// The user's Documents folder.
        case documentDirectory

        /// The user's Desktop folder.
        case desktopDirectory

        /// Per-user application support data (roaming AppData on Windows).
        case applicationSupportDirectory

        /// Per-user cache data (local AppData on Windows).
        case cachesDirectory

        /// The user's home profile folder.
        case userDirectory
    }

    /// Domain masks for `urls(for:in:)`; only the user domain is meaningful
    /// on Windows.
    public struct SearchPathDomainMask: OptionSet, Sendable {
        /// The raw option value.
        public let rawValue: UInt

        /// Creates a mask from a raw value.
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// The current user's domain.
        public static let userDomainMask = SearchPathDomainMask(rawValue: 1)

        /// Every domain; treated as the user domain on Windows.
        public static let allDomainsMask = SearchPathDomainMask(rawValue: 0x0fff)
    }
}
