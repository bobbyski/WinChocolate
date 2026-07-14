/// A titled container view.
///
/// `NSBox` currently maps to a native Windows group box. It gives AppKit-shaped
/// code a familiar framed grouping surface while leaving future modern
/// rendering choices behind the backend.
open class NSBox: NSView {
    /// Box appearance kinds, matching AppKit's names.
    public enum BoxType: Sendable {
        /// The standard titled group box.
        case primary

        /// A thin separator line, rendered by the thin frame callers give it.
        case separator

        /// A custom-drawn box.
        case custom
    }

    /// The box appearance. Separator boxes are laid out as hairlines by
    /// their owners; the group-box chrome comes from the native peer.
    open var boxType: BoxType = .primary

    /// Title placement, matching AppKit's names (the slice the native
    /// group box supports: hidden, or on the top edge).
    public enum TitlePosition: Sendable {
        /// No title is shown.
        case noTitle

        /// The title sits on the top edge of the border.
        case atTop
    }

    /// Where the title shows. `.noTitle` blanks the native caption.
    open var titlePosition: TitlePosition = .atTop {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setText(titlePosition == .noTitle ? "" : title, for: nativeHandle)
        }
    }

    /// Padding between the box border and the content view.
    open var contentViewMargins: NSSize = NSSize(width: 5, height: 5)

    /// The view hosted inside the box, laid out inset by the title band
    /// and `contentViewMargins` on the box's layout pass.
    open var contentView: NSView? {
        didSet {
            if let oldValue, oldValue !== contentView {
                oldValue.removeFromSuperview()
            }
            if let contentView, contentView.superview !== self {
                addSubview(contentView)
            }
            needsLayout = true
        }
    }

    /// The vertical space the top title band occupies when a title shows.
    private var winTitleBandHeight: CGFloat {
        (titlePosition == .noTitle || title.isEmpty) ? 0 : 16
    }

    /// The box's natural size (9.2): its content view's size plus the margins on
    /// each edge and the title band, so a box wrapping laid-out content isn't
    /// measured 0×0.
    open override var intrinsicContentSize: NSSize {
        var contentSize = NSSize.zero
        if let contentView {
            let intrinsic = contentView.intrinsicContentSize
            contentSize.width = intrinsic.width == NSView.noIntrinsicMetric ? contentView.frame.size.width : intrinsic.width
            contentSize.height = intrinsic.height == NSView.noIntrinsicMetric ? contentView.frame.size.height : intrinsic.height
        }
        let width = contentSize.width + contentViewMargins.width * 2
        let height = contentSize.height + contentViewMargins.height * 2 + winTitleBandHeight
        return NSSize(width: max(width, 24), height: max(height, winTitleBandHeight + 8))
    }

    /// Places the content view within the border and margins (top-left
    /// origin; the title band sits at the top).
    open override func layout() {
        super.layout()
        guard let contentView else {
            return
        }

        contentView.frame = NSRect(
            x: contentViewMargins.width,
            y: winTitleBandHeight + contentViewMargins.height,
            width: max(0, bounds.width - contentViewMargins.width * 2),
            height: max(0, bounds.height - winTitleBandHeight - contentViewMargins.height * 2)
        )
    }

    /// The box title.
    open var title: String {
        didSet {
            guard let nativeHandle else {
                return
            }

            realizedBackend?.setText(titlePosition == .noTitle ? "" : title, for: nativeHandle)
        }
    }

    /// Creates a box with a frame.
    public required init(frame frameRect: NSRect) {
        self.title = ""
        super.init(frame: frameRect)
    }

    /// Creates a titled box with a frame.
    init(title: String, frame frameRect: NSRect) {
        self.title = title
        super.init(frame: frameRect)
    }

    /// Creates the native Windows group box peer.
    open override func createNativePeer(in backend: NativeControlBackend, parent: NativeHandle?) -> NativeHandle {
        backend.createBox(title: title, frame: frame, parent: parent)
    }
}
