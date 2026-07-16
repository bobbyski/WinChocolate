/// NSString-shaped bridging for code written against Foundation's string
/// surface.
///
/// Swift on Apple platforms bridges `String` to `NSString` for UTF-16
/// range work (`length`, `range(of:options:range:)`); Windows has no
/// NSString, so the alias makes `text as NSString` a no-op and the
/// extension supplies the UTF-16 members ported code reaches for.
public typealias NSString = String

/// Returns the position one past a range's end, matching Foundation.
public func NSMaxRange(_ range: NSRange) -> Int {
    range.location + range.length
}

extension String {
    /// String comparison options, matching Foundation's names. This slice
    /// carries the search options ported UI code uses.
    public struct CompareOptions: OptionSet, Sendable {
        public let rawValue: UInt

        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// Case-insensitive comparison.
        public static let caseInsensitive = CompareOptions(rawValue: 1)

        /// Search from the end of the range.
        public static let backwards = CompareOptions(rawValue: 4)
    }

    /// The length in UTF-16 units, matching `NSString.length`.
    public var length: Int {
        utf16.count
    }

    /// Returns the string with every occurrence of `target` replaced, matching
    /// Foundation's `replacingOccurrences(of:with:)`.
    ///
    /// Only the literal, whole-string form is provided; the `options:`/`range:`
    /// overloads are future parity work. An empty `target` returns the string
    /// unchanged rather than looping forever.
    public func replacingOccurrences(of target: String, with replacement: String) -> String {
        guard !target.isEmpty else {
            return self
        }
        var result = ""
        var index = startIndex
        while index < endIndex {
            if self[index...].hasPrefix(target), let next = self.index(index, offsetBy: target.count, limitedBy: endIndex) {
                result += replacement
                index = next
                continue
            }
            result.append(self[index])
            index = self.index(after: index)
        }
        return result
    }

    /// Whether the string contains another, compared case-insensitively —
    /// matching Foundation's name (locale-specific folding is out of scope
    /// for this slice; `lowercased()` folding applies).
    public func localizedCaseInsensitiveContains(_ other: String) -> Bool {
        range(of: other, options: .caseInsensitive).location != NSNotFound
    }

    /// Finds a substring within a UTF-16 range, returning its range or
    /// `NSNotFound`, matching `NSString.range(of:options:range:)`.
    ///
    /// Case folding uses `lowercased()`, whose rare length-changing case
    /// mappings are out of scope for this slice.
    public func range(of searchString: String, options: CompareOptions = [], range searchRange: NSRange? = nil) -> NSRange {
        let haystackUnits = Array(utf16)
        let bounds = searchRange ?? NSRange(location: 0, length: haystackUnits.count)
        let lower = max(0, min(bounds.location, haystackUnits.count))
        let upper = max(lower, min(bounds.location + bounds.length, haystackUnits.count))

        var needleSource = searchString
        var regionSource = String(decoding: haystackUnits[lower..<upper], as: UTF16.self)
        if options.contains(.caseInsensitive) {
            needleSource = needleSource.lowercased()
            regionSource = regionSource.lowercased()
        }
        let needle = Array(needleSource.utf16)
        let region = Array(regionSource.utf16)
        guard !needle.isEmpty, needle.count <= region.count else {
            return NSRange(location: NSNotFound, length: 0)
        }

        let starts = 0...(region.count - needle.count)
        let ordered = options.contains(.backwards) ? Array(starts.reversed()) : Array(starts)
        for start in ordered where Array(region[start..<(start + needle.count)]) == needle {
            return NSRange(location: lower + start, length: needle.count)
        }
        return NSRange(location: NSNotFound, length: 0)
    }
}
