/// A Foundation-compatible URL subset for Windows Swift toolchains where
/// `import Foundation` is temporarily unavailable.
public struct URL: Equatable, Hashable, Sendable, CustomStringConvertible {
    private let storage: String
    private let fileURL: Bool
    private let directoryHint: Bool

    /// Creates a URL from a string.
    public init?(string: String) {
        guard !string.isEmpty else {
            return nil
        }

        if string.hasPrefix("file://") {
            self.storage = URL.pathFromFileURLString(string)
            self.fileURL = true
            self.directoryHint = URL.hasTrailingSeparator(string)
        } else {
            self.storage = string
            self.fileURL = false
            self.directoryHint = URL.hasTrailingSeparator(string)
        }
    }

    /// Creates a file URL from a file-system path.
    public init(fileURLWithPath path: String) {
        self.init(fileURLWithPath: path, isDirectory: URL.hasTrailingSeparator(path))
    }

    /// Creates a file URL from a file-system path and directory hint.
    public init(fileURLWithPath path: String, isDirectory: Bool) {
        self.storage = URL.normalizedFilePath(path, keepTrailingSeparator: isDirectory)
        self.fileURL = true
        self.directoryHint = isDirectory
    }

    /// Whether this URL represents a file-system URL.
    public var isFileURL: Bool {
        fileURL
    }

    /// The file-system path represented by this URL.
    public var path: String {
        storage
    }

    /// Path components split on Windows or POSIX separators.
    public var pathComponents: [String] {
        path.split { character in
            character == "\\" || character == "/"
        }.map(String.init)
    }

    /// A string form suitable for diagnostics and common source compatibility.
    public var absoluteString: String {
        guard isFileURL else {
            return storage
        }

        let slashPath = URL.replacingSeparators(in: storage, with: "/")
        if slashPath.hasPrefix("/") {
            return "file://" + slashPath
        }
        return "file:///" + slashPath
    }

    /// Foundation exposes `relativeString`; without base URL support it matches
    /// `absoluteString`.
    public var relativeString: String {
        absoluteString
    }

    /// A display string for diagnostics.
    public var description: String {
        absoluteString
    }

    /// Returns whether the URL path is directory-like.
    public var hasDirectoryPath: Bool {
        directoryHint || URL.hasTrailingSeparator(storage)
    }

    /// Returns the final path component.
    public var lastPathComponent: String {
        pathComponents.last ?? ""
    }

    /// Returns the path extension of the final path component.
    public var pathExtension: String {
        let component = lastPathComponent
        guard let dotIndex = component.lastIndex(of: "."), dotIndex != component.startIndex else {
            return ""
        }
        return String(component[component.index(after: dotIndex)...])
    }

    /// Returns a URL with an additional path component.
    public func appendingPathComponent(_ pathComponent: String) -> URL {
        appendingPathComponent(pathComponent, isDirectory: false)
    }

    /// Returns a URL with an additional path component and directory hint.
    public func appendingPathComponent(_ pathComponent: String, isDirectory: Bool) -> URL {
        let separator = preferredSeparator
        let base = URL.trimTrailingSeparators(storage)
        let combined = base.isEmpty ? pathComponent : base + separator + pathComponent
        return URL(fileURLWithPath: combined, isDirectory: isDirectory)
    }

    /// Returns a URL by deleting the final path component.
    public func deletingLastPathComponent() -> URL {
        let trimmed = URL.trimTrailingSeparators(storage)
        guard let separatorIndex = trimmed.lastIndex(where: { $0 == "\\" || $0 == "/" }) else {
            return URL(fileURLWithPath: "", isDirectory: true)
        }

        let prefix = String(trimmed[..<separatorIndex])
        if URL.isWindowsDriveRoot(prefix) {
            return URL(fileURLWithPath: prefix + preferredSeparator, isDirectory: true)
        }
        return URL(fileURLWithPath: prefix, isDirectory: true)
    }

    /// Returns a URL by appending a path extension.
    public func appendingPathExtension(_ pathExtension: String) -> URL {
        guard !pathExtension.isEmpty else {
            return self
        }

        let extensionText = pathExtension.hasPrefix(".") ? String(pathExtension.dropFirst()) : pathExtension
        return URL(fileURLWithPath: URL.trimTrailingSeparators(storage) + "." + extensionText, isDirectory: false)
    }

    /// Returns a URL by deleting the path extension from the final component.
    public func deletingPathExtension() -> URL {
        let trimmed = URL.trimTrailingSeparators(storage)
        guard let separatorIndex = trimmed.lastIndex(where: { $0 == "\\" || $0 == "/" }) else {
            return URL(fileURLWithPath: URL.removingExtension(from: trimmed), isDirectory: hasDirectoryPath)
        }

        let parent = String(trimmed[...separatorIndex])
        let component = String(trimmed[trimmed.index(after: separatorIndex)...])
        return URL(fileURLWithPath: parent + URL.removingExtension(from: component), isDirectory: hasDirectoryPath)
    }

    private var preferredSeparator: String {
        storage.contains("\\") ? "\\" : "/"
    }

    private static func normalizedFilePath(_ path: String, keepTrailingSeparator: Bool) -> String {
        guard path.count > 1 else {
            return path
        }

        var result = path
        while result.count > 3 && hasTrailingSeparator(result) {
            result.removeLast()
        }

        if keepTrailingSeparator && !hasTrailingSeparator(result) {
            result += result.contains("\\") ? "\\" : "/"
        }

        return result
    }

    private static func trimTrailingSeparators(_ path: String) -> String {
        normalizedFilePath(path, keepTrailingSeparator: false)
    }

    private static func hasTrailingSeparator(_ text: String) -> Bool {
        text.hasSuffix("\\") || text.hasSuffix("/")
    }

    private static func isWindowsDriveRoot(_ path: String) -> Bool {
        path.count == 2 && path.last == ":"
    }

    private static func removingExtension(from component: String) -> String {
        guard let dotIndex = component.lastIndex(of: "."), dotIndex != component.startIndex else {
            return component
        }
        return String(component[..<dotIndex])
    }

    private static func pathFromFileURLString(_ string: String) -> String {
        var path = String(string.dropFirst("file://".count))
        while path.hasPrefix("/") && path.dropFirst().first?.isLetter == true && path.dropFirst().dropFirst().first == ":" {
            path.removeFirst()
        }
        return replacingSeparators(in: path, with: "\\")
    }

    private static func replacingSeparators(in text: String, with separator: Character) -> String {
        String(text.map { character in
            character == "\\" || character == "/" ? separator : character
        })
    }
}
