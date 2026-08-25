// The two text-system objects AppKit-shaped editors reach through (R25).
//
// AppKit's text stack is four objects: an `NSTextStorage` holds the characters,
// an `NSLayoutManager` turns them into glyphs, an `NSTextContainer` describes
// the shape they flow into, and an `NSTextView` draws the result. ChocolateKit
// has the storage and the view; editors reach for the middle two constantly —
// almost always to set the container's inset or line-fragment padding, or to
// ask the layout manager to invalidate.
//
// So these are real objects with the properties that matter, wired to the view
// they belong to. What they are *not* is a second line-breaking engine: the
// native control lays its own text out, and asking the layout manager to
// re-glyph something is a request the view honours by re-laying out itself.

/// The shape text flows into, as AppKit's `NSTextContainer`.
open class NSTextContainer: NSObject {
    /// The area available for text, in the text view's coordinates.
    open var size: NSSize = .zero {
        didSet { textView?.needsLayout = true }
    }

    /// Extra space at each end of a line fragment.
    ///
    /// AppKit defaults to 5 points and editors routinely zero it to align text
    /// with a ruler or a gutter — which is exactly why it has to be settable
    /// rather than assumed.
    open var lineFragmentPadding: CGFloat = 5 {
        didSet { textView?.needsLayout = true }
    }

    /// Whether the container's width tracks the view's.
    open var widthTracksTextView: Bool = true

    /// Whether the container's height tracks the view's.
    open var heightTracksTextView: Bool = false

    /// The view this container belongs to.
    open weak var textView: NSTextView?

    /// The layout manager driving this container.
    open weak var layoutManager: NSLayoutManager?

    /// Creates a container of a given size.
    public init(containerSize: NSSize = .zero) {
        self.size = containerSize
        super.init()
    }
}

/// Glyph layout, as AppKit's `NSLayoutManager`.
///
/// The native control owns the real layout, so the invalidation calls here mark
/// the view rather than re-running a line breaker this framework does not have.
/// That is the honest mapping: a caller asking for a re-layout gets one.
open class NSLayoutManager: NSObject {
    /// The containers text flows through.
    open private(set) var textContainers: [NSTextContainer] = []

    /// The storage being laid out.
    open weak var textStorage: NSTextStorage?

    /// The view this manager lays out for.
    open weak var textView: NSTextView?

    /// Creates an empty layout manager.
    public override init() {
        super.init()
    }

    /// Adds a container to the end of the chain.
    open func addTextContainer(_ container: NSTextContainer) {
        container.layoutManager = self
        textContainers.append(container)
    }

    /// Marks a character range as needing re-layout.
    open func invalidateLayout(forCharacterRange range: NSRange, actualCharacterRange: NSRangePointer?) {
        textView?.needsLayout = true
    }

    /// Marks a glyph range as needing redraw.
    open func invalidateDisplay(forGlyphRange range: NSRange) {
        textView?.needsDisplay = true
    }

    /// Ensures layout is up to date for a container.
    ///
    /// The native control lays its own text out as part of the view's layout
    /// pass, so this asks for that pass rather than running a line breaker this
    /// framework does not have.
    open func ensureLayout(for container: NSTextContainer) {
        textView?.layout()
    }

    /// The number of glyphs, which off Apple is the number of characters: no
    /// backend here does glyph substitution or ligature composition, so one
    /// character is one glyph and saying otherwise would be a guess.
    open var numberOfGlyphs: Int {
        textStorage?.string.count ?? 0
    }
}
