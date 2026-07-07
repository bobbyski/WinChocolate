/// A small Foundation-compatible bundle subset for resource lookup.
public final class Bundle: Equatable, Hashable, Sendable {
    private let rootPath: String

    /// The bundle representing the running executable location.
    public static let main = Bundle(path: Bundle.mainBundlePath()) ?? Bundle(path: ".")!

    /// Creates a bundle rooted at a filesystem path.
    public init?(path: String) {
        let normalized = Bundle.normalizedDirectoryPath(path)
        guard !normalized.isEmpty else {
            return nil
        }
        self.rootPath = normalized
    }

    /// Creates a bundle rooted at a file URL.
    public convenience init?(url: URL) {
        guard url.isFileURL else {
            return nil
        }
        self.init(path: url.path)
    }

    /// The root URL of the bundle.
    public var bundleURL: URL {
        URL(fileURLWithPath: rootPath, isDirectory: true)
    }

    /// The root path of the bundle.
    public var bundlePath: String {
        rootPath
    }

    /// The resource URL.
    public var resourceURL: URL? {
        URL(fileURLWithPath: resourceSearchRoots.first ?? rootPath, isDirectory: true)
    }

    /// The resource path.
    public var resourcePath: String? {
        resourceSearchRoots.first ?? rootPath
    }

    /// The executable URL when this is `Bundle.main`.
    public var executableURL: URL? {
        let path = Bundle.mainExecutablePath()
        return path.isEmpty ? nil : URL(fileURLWithPath: path)
    }

    /// The executable path when this is `Bundle.main`.
    public var executablePath: String? {
        executableURL?.path
    }

    /// Returns the path for a resource, if it exists.
    public func path(forResource name: String?, ofType extensionName: String?) -> String? {
        path(forResource: name, ofType: extensionName, inDirectory: nil)
    }

    /// Returns the path for a resource in a subdirectory, if it exists.
    public func path(forResource name: String?, ofType extensionName: String?, inDirectory subpath: String?) -> String? {
        for candidate in resourcePathCandidates(name: name, extensionName: extensionName, subpath: subpath) {
            if Bundle.pathExists(candidate) {
                return candidate
            }
        }
        return nil
    }

    /// Returns the URL for a resource, if it exists.
    public func url(forResource name: String?, withExtension extensionName: String?) -> URL? {
        url(forResource: name, withExtension: extensionName, subdirectory: nil)
    }

    /// Returns the URL for a resource in a subdirectory, if it exists.
    public func url(forResource name: String?, withExtension extensionName: String?, subdirectory subpath: String?) -> URL? {
        guard let path = path(forResource: name, ofType: extensionName, inDirectory: subpath) else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }

    public static func == (lhs: Bundle, rhs: Bundle) -> Bool {
        lhs.rootPath.lowercased() == rhs.rootPath.lowercased()
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(rootPath.lowercased())
    }

    private var resourceSearchRoots: [String] {
        let candidates = [
            rootPath,
            Bundle.joinPathComponents([rootPath, "Resources"]),
            Bundle.joinPathComponents([rootPath, "WinChocolateDemo_WinChocolateDemo.resources"]),
            Bundle.joinPathComponents([rootPath, "WinChocolateDemo.resources"])
        ]

        var unique: [String] = []
        for candidate in candidates where !unique.contains(candidate) && Bundle.pathExists(candidate) {
            unique.append(candidate)
        }
        return unique.isEmpty ? [rootPath] : unique
    }

    private func resourcePathCandidates(name: String?, extensionName: String?, subpath: String?) -> [String] {
        guard let name, !name.isEmpty else {
            return []
        }

        var fileName = name
        if let extensionName, !extensionName.isEmpty {
            fileName += extensionName.hasPrefix(".") ? extensionName : "." + extensionName
        }

        return resourceSearchRoots.map { root in
            var components = [root]
            if let subpath, !subpath.isEmpty {
                components.append(Bundle.trimSeparators(subpath))
            }
            components.append(fileName)
            return Bundle.joinPathComponents(components)
        }
    }

    private static func normalizedDirectoryPath(_ path: String) -> String {
        let trimmed = trimTrailingSeparators(replacingSlashes(in: path))
        return trimmed.isEmpty ? path : trimmed
    }

    private static func trimSeparators(_ path: String) -> String {
        var result = replacingSlashes(in: path)
        while result.hasPrefix("\\") {
            result.removeFirst()
        }
        return trimTrailingSeparators(result)
    }

    private static func trimTrailingSeparators(_ path: String) -> String {
        var result = path
        while result.count > 1, result.hasSuffix("\\") || result.hasSuffix("/") {
            result.removeLast()
        }
        return result
    }

    private static func joinPathComponents(_ components: [String]) -> String {
        components.filter { !$0.isEmpty }.reduce("") { partial, component in
            guard !partial.isEmpty else {
                return component
            }
            return partial + "\\" + component
        }
    }

    private static func mainBundlePath() -> String {
        let executable = mainExecutablePath()
        guard !executable.isEmpty else {
            return "."
        }

        let normalized = replacingSlashes(in: executable)
        guard let separator = normalized.lastIndex(of: "\\") else {
            return "."
        }
        return String(normalized[..<separator])
    }

    private static func mainExecutablePath() -> String {
        #if os(Windows)
        var buffer = Array<UInt16>(repeating: 0, count: 32_768)
        let length = buffer.withUnsafeMutableBufferPointer { pointer in
            WinFoundationGetModuleFileNameW(nil, pointer.baseAddress, UInt32(pointer.count))
        }
        guard length > 0 else {
            return ""
        }
        return String(decoding: buffer.prefix(Int(length)), as: UTF16.self)
        #else
        return ""
        #endif
    }

    private static func pathExists(_ path: String) -> Bool {
        #if os(Windows)
        var wide = Array(path.utf16)
        wide.append(0)
        let attributes = wide.withUnsafeBufferPointer { pointer in
            WinFoundationGetFileAttributesW(pointer.baseAddress!)
        }
        return attributes != UInt32.max
        #else
        return false
        #endif
    }

    private static func replacingSlashes(in path: String) -> String {
        String(path.map { $0 == "/" ? "\\" : $0 })
    }
}

#if os(Windows)
@_silgen_name("GetModuleFileNameW")
private func WinFoundationGetModuleFileNameW(_ module: UnsafeRawPointer?, _ filename: UnsafeMutablePointer<UInt16>?, _ size: UInt32) -> UInt32

@_silgen_name("GetFileAttributesW")
private func WinFoundationGetFileAttributesW(_ filename: UnsafePointer<UInt16>) -> UInt32
#endif
