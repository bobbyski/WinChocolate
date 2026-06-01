/// A Foundation-compatible URL subset for Windows Swift toolchains where
/// `import Foundation` is temporarily unavailable.
public struct URL: Equatable, Hashable, Sendable, CustomStringConvertible {
    private let storage: String
    private let fileURL: Bool
    private let directoryHint: Bool
    private let baseStorage: String?

    /// Creates a URL from a string.
    public init?(string: String) {
        self.init(string: string, relativeTo: nil)
    }

    /// Creates a URL from a string relative to a base URL.
    public init?(string: String, relativeTo baseURL: URL?) {
        guard !string.isEmpty else {
            return nil
        }

        if string.hasPrefix("file://") {
            self.storage = URL.percentDecoded(URL.pathFromFileURLString(string))
            self.fileURL = true
            self.directoryHint = URL.hasTrailingSeparator(string)
        } else {
            self.storage = URL.percentDecoded(string)
            self.fileURL = false
            self.directoryHint = URL.hasTrailingSeparator(string)
        }
        self.baseStorage = baseURL?.absoluteString
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
        self.baseStorage = nil
    }

    /// Whether this URL represents a file-system URL.
    public var isFileURL: Bool {
        fileURL
    }

    /// The file-system path represented by this URL.
    public var path: String {
        guard !isFileURL else {
            return storage
        }
        return URL.parsedURL(storage).path
    }

    /// The URL scheme, such as `file` or `https`.
    public var scheme: String? {
        isFileURL ? "file" : URL.parsedURL(storage).scheme
    }

    /// The URL host, when present.
    public var host: String? {
        guard !isFileURL else {
            let normalized = URL.replacingSeparators(in: storage, with: "/")
            guard normalized.hasPrefix("//") else {
                return nil
            }
            return String(normalized.dropFirst(2).split(separator: "/", maxSplits: 1).first ?? "")
        }
        return URL.parsedURL(storage).host
    }

    /// The URL query string, without the leading `?`.
    public var query: String? {
        isFileURL ? nil : URL.parsedURL(storage).query
    }

    /// The URL fragment string, without the leading `#`.
    public var fragment: String? {
        isFileURL ? nil : URL.parsedURL(storage).fragment
    }

    /// The path as it appears in the URL string.
    public var percentEncodedPath: String {
        guard !isFileURL else {
            return URL.percentEncodedPath(URL.replacingSeparators(in: path, with: "/"))
        }
        return URL.percentEncodedPath(URL.parsedURL(storage).path)
    }

    /// The query as it appears in the URL string.
    public var percentEncodedQuery: String? {
        guard let query else {
            return nil
        }
        return URL.percentEncodedQueryOrFragment(query)
    }

    /// The fragment as it appears in the URL string.
    public var percentEncodedFragment: String? {
        guard let fragment else {
            return nil
        }
        return URL.percentEncodedQueryOrFragment(fragment)
    }

    /// The whole URL string after percent-encoding components that require it.
    public var percentEncodedString: String {
        absoluteString
    }

    /// The original stored string for relative URLs, or the URL path for file URLs.
    public var relativeString: String {
        guard !isFileURL else {
            return absoluteString
        }
        return storage
    }

    /// The base URL used for relative URL construction, when available.
    public var baseURL: URL? {
        guard let baseStorage else {
            return nil
        }
        return URL(string: baseStorage)
    }

    /// The relative path portion. Without a base URL, this matches `path`.
    public var relativePath: String {
        URL.parsedURL(storage).path
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
            guard let baseStorage, !URL.hasScheme(storage) else {
                return URL.percentEncodedURLString(storage)
            }
            return URL.joinURLString(baseStorage, storage)
        }

        let slashPath = URL.replacingSeparators(in: storage, with: "/")
        let encodedPath = URL.percentEncodedPath(slashPath)
        if encodedPath.hasPrefix("//") {
            return "file:" + encodedPath
        }
        if encodedPath.hasPrefix("/") {
            return "file://" + encodedPath
        }
        return "file:///" + encodedPath
    }

    /// A URL with its base resolved when enough information is available.
    public var absoluteURL: URL {
        guard !isFileURL, let baseStorage, !URL.hasScheme(storage), let resolved = URL(string: URL.joinURLString(baseStorage, storage)) else {
            return self
        }
        return resolved
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

    /// Returns a file URL with `.` and `..` path components collapsed.
    public var standardizedFileURL: URL {
        guard isFileURL else {
            return self
        }
        return URL(fileURLWithPath: URL.standardizedPath(storage), isDirectory: hasDirectoryPath)
    }

    /// Returns a URL with standard path components collapsed when possible.
    public var standardized: URL {
        isFileURL ? standardizedFileURL : absoluteURL
    }

    private var preferredSeparator: String {
        storage.contains("\\") ? "\\" : "/"
    }

    private struct ParsedURL {
        var scheme: String?
        var host: String?
        var path: String
        var query: String?
        var fragment: String?
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

    private static func hasScheme(_ text: String) -> Bool {
        guard let colon = text.firstIndex(of: ":") else {
            return false
        }
        return isValidSchemeName(String(text[..<colon]))
    }

    private static func isValidSchemeName(_ text: String) -> Bool {
        !text.isEmpty && text.allSatisfy { character in
            character.isLetter || character.isNumber || character == "+" || character == "-" || character == "."
        }
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
        if !path.hasPrefix("/") && !(path.dropFirst().first == ":") {
            return "\\\\" + replacingSeparators(in: path, with: "\\")
        }
        while path.hasPrefix("/") && path.dropFirst().first?.isLetter == true && path.dropFirst().dropFirst().first == ":" {
            path.removeFirst()
        }
        return replacingSeparators(in: path, with: "\\")
    }

    private static func joinURLString(_ base: String, _ relative: String) -> String {
        let encodedRelative = percentEncodedURLString(relative)
        if base.hasSuffix("/") {
            return base + encodedRelative
        }
        return base + "/" + encodedRelative
    }

    private static func parsedURL(_ text: String) -> ParsedURL {
        var remainder = text
        var scheme: String?
        var host: String?
        var query: String?
        var fragment: String?

        if let hashIndex = remainder.firstIndex(of: "#") {
            fragment = String(remainder[remainder.index(after: hashIndex)...])
            remainder = String(remainder[..<hashIndex])
        }

        if let queryIndex = remainder.firstIndex(of: "?") {
            query = String(remainder[remainder.index(after: queryIndex)...])
            remainder = String(remainder[..<queryIndex])
        }

        if let colonIndex = remainder.firstIndex(of: ":"), isValidSchemeName(String(remainder[..<colonIndex])) {
            scheme = String(remainder[..<colonIndex])
            remainder = String(remainder[remainder.index(after: colonIndex)...])
        }

        if remainder.hasPrefix("//") {
            let afterSlashes = String(remainder.dropFirst(2))
            if let slashIndex = afterSlashes.firstIndex(of: "/") {
                host = String(afterSlashes[..<slashIndex])
                remainder = String(afterSlashes[slashIndex...])
            } else {
                host = afterSlashes.isEmpty ? nil : afterSlashes
                remainder = ""
            }
        }

        return ParsedURL(
            scheme: scheme,
            host: host,
            path: percentDecoded(remainder),
            query: query.map(percentDecoded),
            fragment: fragment.map(percentDecoded)
        )
    }

    private static func percentEncodedURLString(_ text: String) -> String {
        let parsed = parsedURL(text)
        var result = ""
        if let scheme = parsed.scheme {
            result += scheme + ":"
        }
        if let host = parsed.host {
            result += "//" + host
        }
        result += percentEncodedPath(parsed.path)
        if let query = parsed.query {
            result += "?" + percentEncodedQueryOrFragment(query)
        }
        if let fragment = parsed.fragment {
            result += "#" + percentEncodedQueryOrFragment(fragment)
        }
        return result
    }

    private static func standardizedPath(_ path: String) -> String {
        let separator = path.contains("\\") ? "\\" : "/"
        let isUNC = path.hasPrefix("\\\\") || path.hasPrefix("//")
        let hasRoot = isUNC || path.hasPrefix("\\") || path.hasPrefix("/") || isWindowsAbsolutePath(path)
        let keepTrailing = hasTrailingSeparator(path)
        let components = path.split { character in
            character == "\\" || character == "/"
        }.map(String.init)

        var output: [String] = []
        for component in components {
            if component == "." {
                continue
            }
            if component == ".." {
                if !output.isEmpty && output.last != ".." {
                    output.removeLast()
                } else if !hasRoot {
                    output.append(component)
                }
                continue
            }
            output.append(component)
        }

        var result = output.joined(separator: separator)
        if isUNC {
            result = separator + separator + result
        } else if path.hasPrefix("\\") || path.hasPrefix("/") {
            result = separator + result
        }
        if keepTrailing && !result.isEmpty && !hasTrailingSeparator(result) {
            result += separator
        }
        return result
    }

    private static func isWindowsAbsolutePath(_ path: String) -> Bool {
        path.count >= 3 && path.dropFirst().first == ":" && (path.dropFirst(2).first == "\\" || path.dropFirst(2).first == "/")
    }

    private static func percentEncodedPath(_ text: String) -> String {
        percentEncoded(text, allowing: isUnreservedOrPathSeparator)
    }

    private static func percentEncodedQueryOrFragment(_ text: String) -> String {
        percentEncoded(text, allowing: isUnreservedOrQueryFragmentCharacter)
    }

    private static func percentEncoded(_ text: String, allowing isAllowed: (Unicode.Scalar) -> Bool) -> String {
        var result = ""
        for scalar in text.unicodeScalars {
            if isAllowed(scalar) {
                result.unicodeScalars.append(scalar)
            } else {
                for byte in String(scalar).utf8 {
                    result += "%"
                    result += hexDigit(Int(byte >> 4))
                    result += hexDigit(Int(byte & 0x0F))
                }
            }
        }
        return result
    }

    private static func percentDecoded(_ text: String) -> String {
        let bytes = Array(text.utf8)
        var output: [UInt8] = []
        var index = 0
        while index < bytes.count {
            if bytes[index] == 37, index + 2 < bytes.count, let high = hexValue(bytes[index + 1]), let low = hexValue(bytes[index + 2]) {
                output.append(UInt8(high * 16 + low))
                index += 3
            } else {
                output.append(bytes[index])
                index += 1
            }
        }
        return String(decoding: output, as: UTF8.self)
    }

    private static func isUnreservedOrPathSeparator(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 45, 46, 47, 58, 95, 126:
            return true
        case 48...57, 65...90, 97...122:
            return true
        default:
            return false
        }
    }

    private static func isUnreservedOrQueryFragmentCharacter(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 33, 36, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 58, 59, 61, 63, 64, 95, 126:
            return true
        case 48...57, 65...90, 97...122:
            return true
        default:
            return false
        }
    }

    private static func hexDigit(_ value: Int) -> String {
        String("0123456789ABCDEF"["0123456789ABCDEF".index("0123456789ABCDEF".startIndex, offsetBy: value)])
    }

    private static func hexValue(_ byte: UInt8) -> Int? {
        switch byte {
        case 48...57:
            return Int(byte - 48)
        case 65...70:
            return Int(byte - 55)
        case 97...102:
            return Int(byte - 87)
        default:
            return nil
        }
    }

    private static func replacingSeparators(in text: String, with separator: Character) -> String {
        String(text.map { character in
            character == "\\" || character == "/" ? separator : character
        })
    }
}
