import WinFoundation

/// Text underline styles matching AppKit names.
public struct NSUnderlineStyle: OptionSet, Sendable {
    /// Raw option value.
    public let rawValue: Int

    /// Creates an underline style from a raw value.
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// A single underline.
    public static let single = NSUnderlineStyle(rawValue: 0x01)
}

/// A string with associated drawing attributes.
///
/// Attributes are stored as runs, so different character ranges carry
/// different attributes; `NSMutableAttributedString` edits both text and
/// runs. RTF writing is supported through `rtf(from:documentAttributes:)`;
/// RTF reading remains future work (plan item 3.16).
open class NSAttributedString: NSObject {
    /// Attribute names applied to an attributed string.
    public struct Key: RawRepresentable, Hashable, Sendable {
        /// The attribute's raw string name.
        public let rawValue: String

        /// Creates an attribute key from a raw string name.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        /// The font of the text (`NSFont`).
        public static let font = Key(rawValue: "NSFont")

        /// The color of the text (`NSColor`).
        public static let foregroundColor = Key(rawValue: "NSColor")

        /// The background color behind the text (`NSColor`).
        public static let backgroundColor = Key(rawValue: "NSBackgroundColor")

        /// The underline style (`Int`, see `NSUnderlineStyle`).
        public static let underlineStyle = Key(rawValue: "NSUnderline")

        /// The strikethrough style (`Int`, see `NSUnderlineStyle`).
        public static let strikethroughStyle = Key(rawValue: "NSStrikethrough")

        /// The paragraph style (`NSParagraphStyle`).
        public static let paragraphStyle = Key(rawValue: "NSParagraphStyle")
    }

    /// One contiguous stretch of characters sharing attributes.
    struct Run {
        var length: Int
        var attributes: [Key: Any]
    }

    /// The character contents in UTF-16 units.
    var units: [UInt16]

    /// Attribute runs covering `units` in order; lengths sum to `units.count`.
    var runs: [Run]

    /// The character contents.
    open var string: String {
        String(decoding: units, as: UTF16.self)
    }

    /// The length of the string in UTF-16 units.
    open var length: Int {
        units.count
    }

    /// The attributes at the start of the string.
    ///
    /// Kept for compatibility with the earlier whole-string slice; ranged
    /// access goes through `attributes(at:effectiveRange:)`.
    open var attributes: [Key: Any] {
        runs.first?.attributes ?? [:]
    }

    /// Creates an attributed string with no attributes.
    public init(string: String) {
        self.units = Array(string.utf16)
        self.runs = units.isEmpty ? [] : [Run(length: units.count, attributes: [:])]
        super.init()
    }

    /// Creates an attributed string with attributes covering the whole string.
    public init(string: String, attributes: [Key: Any]?) {
        self.units = Array(string.utf16)
        self.runs = units.isEmpty ? [] : [Run(length: units.count, attributes: attributes ?? [:])]
        super.init()
    }

    /// Creates an attributed string copying another's text and runs.
    public init(attributedString: NSAttributedString) {
        self.units = attributedString.units
        self.runs = attributedString.runs
        super.init()
    }

    /// The attributes at a character location.
    ///
    /// When `range` is provided it receives the run's full extent, matching
    /// AppKit's effective-range contract.
    open func attributes(at location: Int, effectiveRange range: UnsafeMutablePointer<NSRange>?) -> [Key: Any] {
        guard let (runIndex, runStart) = run(at: location) else {
            range?.pointee = NSRange(location: location, length: 0)
            return [:]
        }

        range?.pointee = NSRange(location: runStart, length: runs[runIndex].length)
        return runs[runIndex].attributes
    }

    /// The value of one attribute at a character location.
    open func attribute(_ attrName: Key, at location: Int, effectiveRange range: UnsafeMutablePointer<NSRange>?) -> Any? {
        attributes(at: location, effectiveRange: range)[attrName]
    }

    /// A new attributed string with the text and runs of a character range.
    open func attributedSubstring(from range: NSRange) -> NSAttributedString {
        let bounded = clamped(range)
        let substring = NSAttributedString(string: "")
        substring.units = Array(units[bounded.location..<(bounded.location + bounded.length)])

        var cursor = 0
        for run in runs {
            let runRange = NSRange(location: cursor, length: run.length)
            cursor += run.length
            let overlapStart = max(runRange.location, bounded.location)
            let overlapEnd = min(runRange.location + runRange.length, bounded.location + bounded.length)
            if overlapEnd > overlapStart {
                substring.runs.append(Run(length: overlapEnd - overlapStart, attributes: run.attributes))
            }
        }
        return substring
    }

    /// Options controlling attribute enumeration.
    public struct EnumerationOptions: OptionSet, Sendable {
        /// Raw option value.
        public let rawValue: UInt

        /// Creates enumeration options from a raw value.
        public init(rawValue: UInt) {
            self.rawValue = rawValue
        }

        /// Enumerate runs last to first.
        public static let reverse = EnumerationOptions(rawValue: 1 << 1)
    }

    /// Calls a block for each attribute run intersecting a range.
    open func enumerateAttributes(
        in enumerationRange: NSRange,
        options: EnumerationOptions = [],
        using block: ([Key: Any], NSRange, UnsafeMutablePointer<ObjCBool>) -> Void
    ) {
        let bounded = clamped(enumerationRange)
        var pieces: [(attributes: [Key: Any], range: NSRange)] = []
        var cursor = 0
        for run in runs {
            let runStart = cursor
            cursor += run.length
            let overlapStart = max(runStart, bounded.location)
            let overlapEnd = min(runStart + run.length, bounded.location + bounded.length)
            if overlapEnd > overlapStart {
                pieces.append((run.attributes, NSRange(location: overlapStart, length: overlapEnd - overlapStart)))
            }
        }
        if options.contains(.reverse) {
            pieces.reverse()
        }

        var stop = ObjCBool(false)
        for piece in pieces {
            withUnsafeMutablePointer(to: &stop) { stopPointer in
                block(piece.attributes, piece.range, stopPointer)
            }
            if stop.boolValue {
                return
            }
        }
    }

    /// Calls a block for each distinct value of one attribute in a range.
    open func enumerateAttribute(
        _ attrName: Key,
        in enumerationRange: NSRange,
        options: EnumerationOptions = [],
        using block: (Any?, NSRange, UnsafeMutablePointer<ObjCBool>) -> Void
    ) {
        enumerateAttributes(in: enumerationRange, options: options) { attributes, range, stop in
            block(attributes[attrName], range, stop)
        }
    }

    /// The run index and starting location containing a character location.
    func run(at location: Int) -> (index: Int, start: Int)? {
        guard location >= 0, location < units.count else {
            return nil
        }

        var cursor = 0
        for (index, run) in runs.enumerated() {
            if location < cursor + run.length {
                return (index, cursor)
            }
            cursor += run.length
        }
        return nil
    }

    /// A range clamped to the string bounds.
    func clamped(_ range: NSRange) -> NSRange {
        let location = min(max(0, range.location), units.count)
        let length = min(max(0, range.length), units.count - location)
        return NSRange(location: location, length: length)
    }
}

/// An attributed string whose text and attributes can change.
open class NSMutableAttributedString: NSAttributedString {
    private var editingDepth = 0
    private var hasPendingEdits = false

    /// Brackets a batch of edits; change notifications defer to `endEditing()`.
    open func beginEditing() {
        editingDepth += 1
    }

    /// Ends a batch of edits and delivers the deferred change notification.
    open func endEditing() {
        editingDepth = max(0, editingDepth - 1)
        if editingDepth == 0 && hasPendingEdits {
            hasPendingEdits = false
            didMutate()
        }
    }

    /// Called after any edit; `NSTextStorage` overrides to notify observers.
    func didMutate() {}

    private func noteEdit() {
        if editingDepth > 0 {
            hasPendingEdits = true
        } else {
            didMutate()
        }
    }

    /// Replaces a character range with a plain string.
    ///
    /// The replacement takes the attributes at the start of the replaced
    /// range, matching AppKit.
    open func replaceCharacters(in range: NSRange, with str: String) {
        let bounded = clamped(range)
        let inherited = inheritedAttributes(at: bounded.location)
        let replacement = NSAttributedString(string: str, attributes: inherited)
        performReplacement(bounded, with: replacement)
        noteEdit()
    }

    /// Replaces a character range with an attributed string.
    open func replaceCharacters(in range: NSRange, with attrString: NSAttributedString) {
        performReplacement(clamped(range), with: attrString)
        noteEdit()
    }

    /// Replaces the attributes of a range entirely.
    open func setAttributes(_ attrs: [Key: Any]?, range: NSRange) {
        let bounded = clamped(range)
        guard bounded.length > 0 else {
            return
        }

        splitRuns(at: bounded.location)
        splitRuns(at: bounded.location + bounded.length)
        replaceRuns(in: bounded, with: [Run(length: bounded.length, attributes: attrs ?? [:])])
        noteEdit()
    }

    /// Adds one attribute over a range.
    open func addAttribute(_ name: Key, value: Any, range: NSRange) {
        addAttributes([name: value], range: range)
    }

    /// Adds attributes over a range, keeping unrelated existing attributes.
    open func addAttributes(_ attrs: [Key: Any], range: NSRange) {
        mutateAttributes(in: range) { existing in
            existing.merging(attrs) { _, new in new }
        }
    }

    /// Removes one attribute from a range.
    open func removeAttribute(_ name: Key, range: NSRange) {
        mutateAttributes(in: range) { existing in
            var updated = existing
            updated.removeValue(forKey: name)
            return updated
        }
    }

    /// Appends an attributed string.
    open func append(_ attrString: NSAttributedString) {
        performReplacement(NSRange(location: units.count, length: 0), with: attrString)
        noteEdit()
    }

    /// Inserts an attributed string at a character location.
    open func insert(_ attrString: NSAttributedString, at loc: Int) {
        performReplacement(clamped(NSRange(location: loc, length: 0)), with: attrString)
        noteEdit()
    }

    /// Deletes a character range.
    open func deleteCharacters(in range: NSRange) {
        performReplacement(clamped(range), with: NSAttributedString(string: ""))
        noteEdit()
    }

    private func mutateAttributes(in range: NSRange, _ transform: ([Key: Any]) -> [Key: Any]) {
        let bounded = clamped(range)
        guard bounded.length > 0 else {
            return
        }

        splitRuns(at: bounded.location)
        splitRuns(at: bounded.location + bounded.length)

        var cursor = 0
        for index in runs.indices {
            let runStart = cursor
            cursor += runs[index].length
            if runStart >= bounded.location && cursor <= bounded.location + bounded.length {
                runs[index].attributes = transform(runs[index].attributes)
            }
        }
        noteEdit()
    }

    /// The attributes a plain-text replacement inherits at a location.
    private func inheritedAttributes(at location: Int) -> [Key: Any] {
        if let (index, _) = run(at: location) {
            return runs[index].attributes
        }
        // Insertions at the very end continue the final run's attributes.
        return runs.last?.attributes ?? [:]
    }

    private func performReplacement(_ range: NSRange, with attrString: NSAttributedString) {
        splitRuns(at: range.location)
        splitRuns(at: range.location + range.length)

        units.replaceSubrange(range.location..<(range.location + range.length), with: attrString.units)
        replaceRuns(in: range, with: attrString.runs)
    }

    /// Ensures a run boundary exists at a character location.
    private func splitRuns(at location: Int) {
        var cursor = 0
        for index in runs.indices {
            let runStart = cursor
            cursor += runs[index].length
            if location > runStart && location < cursor {
                let firstLength = location - runStart
                let secondLength = runs[index].length - firstLength
                let attributes = runs[index].attributes
                runs[index].length = firstLength
                runs.insert(Run(length: secondLength, attributes: attributes), at: index + 1)
                return
            }
        }
    }

    /// Replaces the runs covering a range (whose edges are run boundaries).
    private func replaceRuns(in range: NSRange, with newRuns: [Run]) {
        var result: [Run] = []
        var cursor = 0
        var inserted = false
        for run in runs {
            let runStart = cursor
            cursor += run.length
            if runStart >= range.location && cursor <= range.location + range.length {
                if !inserted {
                    result.append(contentsOf: newRuns)
                    inserted = true
                }
                continue
            }
            if runStart == range.location + range.length && !inserted {
                result.append(contentsOf: newRuns)
                inserted = true
            }
            result.append(run)
        }
        if !inserted {
            result.append(contentsOf: newRuns)
        }
        runs = result.filter { $0.length > 0 }
    }
}

extension String {
    /// Draws the string with its top-left corner at a point in the current
    /// graphics context.
    ///
    /// Resolves `.font` (`NSFont`) and `.foregroundColor` (`NSColor`) from the
    /// attributes; unspecified attributes fall back to 12-point Segoe UI in
    /// black, matching the backend's default control font.
    public func draw(at point: NSPoint, withAttributes attributes: [NSAttributedString.Key: Any]? = nil) {
        guard let context = NSGraphicsContext.current else {
            return
        }

        let font = attributes?[.font] as? NSFont
        let color = attributes?[.foregroundColor] as? NSColor ?? .black
        context.nativeContext.drawText(
            self,
            at: point,
            color: color,
            fontName: font?.fontName ?? "Segoe UI",
            fontSize: font?.pointSize ?? 12,
            weight: font?.weight.rawValue ?? NSFont.Weight.regular.rawValue,
            italic: font?.italic ?? false
        )
    }

    /// Returns the bounding size of the string with attributes.
    ///
    /// Measured with the backend's real text metrics (the in-memory test
    /// backend returns a deterministic estimate).
    public func size(withAttributes attributes: [NSAttributedString.Key: Any]? = nil) -> NSSize {
        let font = attributes?[.font] as? NSFont
        return NSApplication.shared.nativeBackend.measureText(
            self,
            fontName: font?.fontName ?? "Segoe UI",
            fontSize: font?.pointSize ?? 12,
            weight: font?.weight.rawValue ?? NSFont.Weight.regular.rawValue,
            italic: font?.italic ?? false
        )
    }
}
