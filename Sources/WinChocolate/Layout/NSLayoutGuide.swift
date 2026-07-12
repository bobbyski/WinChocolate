/// An invisible rectangle that takes part in Auto Layout, matching AppKit's
/// `NSLayoutGuide`.
///
/// A guide is used to reserve space or to align views without an extra dummy
/// view. WinChocolate backs each guide with a hidden, non-drawing spacer
/// `NSView` added to the owning view, so the existing solver treats the guide
/// exactly like a sibling subview: the guide's anchors are the backing view's
/// anchors, and its `layoutFrame` is the backing view's solved frame. Because
/// the backing view has `translatesAutoresizingMaskIntoConstraints == false`,
/// it is a solved participant, not a fixed input.
public class NSLayoutGuide {
    /// A debugging identifier, matching AppKit.
    public var identifier: String = ""

    /// The view that owns the guide (set by `NSView.addLayoutGuide`).
    public internal(set) weak var owningView: NSView?

    /// The hidden spacer view the guide's geometry rides on. Never drawn or
    /// hit-tested; it exists only to give the solver a rectangle to place.
    let backing: NSView

    /// Creates an unattached layout guide.
    public init() {
        backing = NSView(frame: .zero)
        backing.isHidden = true
        backing.translatesAutoresizingMaskIntoConstraints = false
    }

    /// The guide's rectangle in the owning view's coordinates, once laid out.
    public var layoutFrame: NSRect { backing.frame }

    /// Alias AppKit code sometimes reads; same rectangle as `layoutFrame`.
    public var frame: NSRect { backing.frame }

    // MARK: - Anchors (proxied to the backing view)

    /// The guide's leading-edge anchor.
    public var leadingAnchor: NSLayoutXAxisAnchor { backing.leadingAnchor }

    /// The guide's trailing-edge anchor.
    public var trailingAnchor: NSLayoutXAxisAnchor { backing.trailingAnchor }

    /// The guide's left-edge anchor.
    public var leftAnchor: NSLayoutXAxisAnchor { backing.leftAnchor }

    /// The guide's right-edge anchor.
    public var rightAnchor: NSLayoutXAxisAnchor { backing.rightAnchor }

    /// The guide's top-edge anchor.
    public var topAnchor: NSLayoutYAxisAnchor { backing.topAnchor }

    /// The guide's bottom-edge anchor.
    public var bottomAnchor: NSLayoutYAxisAnchor { backing.bottomAnchor }

    /// The guide's width anchor.
    public var widthAnchor: NSLayoutDimension { backing.widthAnchor }

    /// The guide's height anchor.
    public var heightAnchor: NSLayoutDimension { backing.heightAnchor }

    /// The guide's horizontal-center anchor.
    public var centerXAnchor: NSLayoutXAxisAnchor { backing.centerXAnchor }

    /// The guide's vertical-center anchor.
    public var centerYAnchor: NSLayoutYAxisAnchor { backing.centerYAnchor }
}
