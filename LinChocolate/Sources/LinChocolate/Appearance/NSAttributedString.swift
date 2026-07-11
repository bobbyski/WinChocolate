import Foundation

// AppKit compatibility for attributed strings.
//
// `NSAttributedString`/`NSMutableAttributedString` come from Foundation (as on
// macOS); AppKit's contribution is the text attribute keys and rendering.
// This slice supports `.foregroundColor` (`NSColor`) and `.font` (`NSFont`),
// rendered natively as styled runs (Pango markup on GTK).

public extension NSAttributedString.Key {
    /// Text color attribute (an `NSColor`), as defined by AppKit.
    static let foregroundColor = NSAttributedString.Key(rawValue: "NSColor")
    /// Font attribute (an `NSFont`), as defined by AppKit.
    static let font = NSAttributedString.Key(rawValue: "NSFont")
}

extension NSAttributedString {
    /// Flattens the attributed string into contiguous styled runs for the
    /// backend seam. Public for the contract tests.
    public func nativeRuns() -> [NativeTextRun] {
        var runs: [NativeTextRun] = []
        enumerateAttributes(in: NSRange(location: 0, length: length), options: []) { attributes, range, _ in
            let text = (self.string as NSString).substring(with: range)
            runs.append(NativeTextRun(
                text: text,
                color: attributes[.foregroundColor] as? NSColor,
                font: (attributes[.font] as? NSFont)?.spec
            ))
        }
        return runs
    }
}
