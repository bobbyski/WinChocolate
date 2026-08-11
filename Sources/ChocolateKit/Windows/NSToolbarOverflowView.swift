final class NSToolbarOverflowChevronView: NSView {
    /// Opens the overflow menu; installed by the toolbar renderer.
    var onOpenMenu: ((NSToolbarOverflowChevronView) -> Void)?

    /// Metallic chrome slice (see `NSToolbarCompositeItemView.metallicSlice`).
    var metallicSlice: (stripHeight: CGFloat, y: CGFloat)?

    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        toolTip = "More toolbar items"
        winBackgroundColor = nil
    }

    override var acceptsFirstResponder: Bool {
        false
    }

    override func draw(_ dirtyRect: NSRect) {
        if let metallicSlice {
            NSToolbarView.winMetallicChromeGradient()?.draw(
                in: NSMakeRect(0, -metallicSlice.y, frame.size.width, metallicSlice.stripHeight),
                angle: -90
            )
        }
        let onDarkStrip = metallicSlice == nil && NSApplication.shared.effectiveAppearance.winIsDark
        let chevronColor = onDarkStrip
            ? NSColor(calibratedWhite: 0.85, alpha: 1)
            : NSColor(calibratedRed: 0.25, green: 0.27, blue: 0.30, alpha: 1.0)
        "»".draw(at: NSMakePoint(max((frame.size.width - 10) / 2, 0), max((frame.size.height - 18) / 2, 0)), withAttributes: [
            .font: NSFont.boldSystemFont(ofSize: 13),
            .foregroundColor: chevronColor,
        ])
    }

    override func mouseUp(with event: NSEvent) {
        onOpenMenu?(self)
    }
}

/// Separator line used by composed toolbar rendering.
