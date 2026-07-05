/// Paragraph-level text attributes, matching AppKit's `NSParagraphStyle`.
///
/// This slice carries the paragraph properties real ports set — alignment,
/// spacing, and indents. Alignment applies natively to rich text views and
/// round-trips through the RTF writer/reader; the spacing and indent values
/// are stored so styles survive copy/edit cycles.
open class NSParagraphStyle: NSObject {
    // Backing storage shared with the mutable subclass.
    var storedAlignment: NSTextAlignment = .natural
    var storedLineSpacing: CGFloat = 0
    var storedParagraphSpacing: CGFloat = 0
    var storedHeadIndent: CGFloat = 0
    var storedTailIndent: CGFloat = 0
    var storedFirstLineHeadIndent: CGFloat = 0

    /// The default paragraph style (natural alignment, zero spacing).
    open class var `default`: NSParagraphStyle {
        NSParagraphStyle()
    }

    /// The text alignment of the paragraph.
    open var alignment: NSTextAlignment { storedAlignment }

    /// The distance in points between the bottom of one line and the top of the next.
    open var lineSpacing: CGFloat { storedLineSpacing }

    /// The space after the end of the paragraph.
    open var paragraphSpacing: CGFloat { storedParagraphSpacing }

    /// The indentation of lines other than the first.
    open var headIndent: CGFloat { storedHeadIndent }

    /// The trailing indentation.
    open var tailIndent: CGFloat { storedTailIndent }

    /// The indentation of the first line.
    open var firstLineHeadIndent: CGFloat { storedFirstLineHeadIndent }

    /// Creates a default paragraph style.
    public override init() {
        super.init()
    }

    /// Returns a mutable copy carrying the same values.
    open func mutableCopy() -> NSMutableParagraphStyle {
        let copy = NSMutableParagraphStyle()
        copy.storedAlignment = storedAlignment
        copy.storedLineSpacing = storedLineSpacing
        copy.storedParagraphSpacing = storedParagraphSpacing
        copy.storedHeadIndent = storedHeadIndent
        copy.storedTailIndent = storedTailIndent
        copy.storedFirstLineHeadIndent = storedFirstLineHeadIndent
        return copy
    }

    /// Value equality over the stored paragraph properties.
    public static func == (lhs: NSParagraphStyle, rhs: NSParagraphStyle) -> Bool {
        lhs.storedAlignment == rhs.storedAlignment
            && lhs.storedLineSpacing == rhs.storedLineSpacing
            && lhs.storedParagraphSpacing == rhs.storedParagraphSpacing
            && lhs.storedHeadIndent == rhs.storedHeadIndent
            && lhs.storedTailIndent == rhs.storedTailIndent
            && lhs.storedFirstLineHeadIndent == rhs.storedFirstLineHeadIndent
    }
}

/// A paragraph style whose properties can be changed, matching AppKit.
open class NSMutableParagraphStyle: NSParagraphStyle {
    open override var alignment: NSTextAlignment {
        get { storedAlignment }
        set { storedAlignment = newValue }
    }

    open override var lineSpacing: CGFloat {
        get { storedLineSpacing }
        set { storedLineSpacing = newValue }
    }

    open override var paragraphSpacing: CGFloat {
        get { storedParagraphSpacing }
        set { storedParagraphSpacing = newValue }
    }

    open override var headIndent: CGFloat {
        get { storedHeadIndent }
        set { storedHeadIndent = newValue }
    }

    open override var tailIndent: CGFloat {
        get { storedTailIndent }
        set { storedTailIndent = newValue }
    }

    open override var firstLineHeadIndent: CGFloat {
        get { storedFirstLineHeadIndent }
        set { storedFirstLineHeadIndent = newValue }
    }

    /// Copies every property from another paragraph style.
    open func setParagraphStyle(_ style: NSParagraphStyle) {
        storedAlignment = style.storedAlignment
        storedLineSpacing = style.storedLineSpacing
        storedParagraphSpacing = style.storedParagraphSpacing
        storedHeadIndent = style.storedHeadIndent
        storedTailIndent = style.storedTailIndent
        storedFirstLineHeadIndent = style.storedFirstLineHeadIndent
    }
}
