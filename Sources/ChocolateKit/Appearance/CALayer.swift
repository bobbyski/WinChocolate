// The slice of Core Animation AppKit-shaped view code actually reaches for.
//
// **This is not an animation engine.** AppKit code touches `view.layer` for one
// thing far more often than any other: clipping. `wantsLayer = true` followed by
// a corner radius and `masksToBounds` is how a rounded box gets rounded corners
// that its own fill does not square off again — the classic "rounded box with
// sharp corners" that reads as a rendering fault rather than a style.
//
// So the properties here are the ones the backends can honour: geometry and
// clipping, pushed onto the native view. The animation surface is deliberately
// absent rather than stubbed, because a `CABasicAnimation` that silently did
// nothing would be worse than one that does not compile — the caller would
// think the animation ran (`Documents/Animation` on the Apple side; the ports
// have no Core Animation and say so).

/// The backing layer of a view, as Core Animation's `CALayer`.
open class CALayer: NSObject {
    /// The view this layer backs, so property changes reach the screen.
    internal weak var winView: NSView?

    /// The radius applied to the layer's corners.
    open var cornerRadius: CGFloat = 0 {
        didSet { winApply() }
    }

    /// Whether sublayers and content are clipped to the layer's bounds.
    ///
    /// The one that matters: without it a corner radius rounds the *border* and
    /// leaves the fill square.
    open var masksToBounds: Bool = false {
        didSet { winApply() }
    }

    /// The layer's fill colour.
    open var backgroundColor: CGColor? {
        didSet { winApply() }
    }

    /// The width of the layer's border.
    open var borderWidth: CGFloat = 0 {
        didSet { winApply() }
    }

    /// The colour of the layer's border.
    open var borderColor: CGColor? {
        didSet { winApply() }
    }

    /// The layer's opacity, 0 to 1.
    open var opacity: Float = 1 {
        didSet { winApply() }
    }

    /// Whether the layer is drawn at all.
    open var isHidden: Bool = false {
        didSet { winView?.isHidden = isHidden }
    }

    /// Marks the layer as needing redraw.
    open func setNeedsDisplay() {
        winView?.needsDisplay = true
    }

    // Pushes what the backends understand onto the view.
    //
    // Clipping goes through the seam that already exists. **The corner radius
    // does not**: no backend carries one, so it is stored and redrawn against
    // rather than quietly discarded — a themed control asking for rounded
    // corners keeps the request, and gains them the day a backend can.
    private func winApply() {
        guard let winView else { return }
        if let handle = winView.nativeHandle {
            winView.realizedBackend?.setClipsToBounds(masksToBounds || cornerRadius > 0, for: handle)
        }
        winView.needsDisplay = true
    }
}

extension NSView {
    /// The view's backing layer, created once `wantsLayer` is set.
    ///
    /// Optional, as AppKit's is: a view that never asked for a layer does not
    /// have one, and code that checks before using it is behaving correctly on
    /// every platform.
    public var layer: CALayer? {
        get {
            guard wantsLayer else { return winBackingLayer }
            if let winBackingLayer { return winBackingLayer }
            let created = CALayer()
            created.winView = self
            winBackingLayer = created
            return created
        }
        set {
            newValue?.winView = self
            winBackingLayer = newValue
        }
    }
}
